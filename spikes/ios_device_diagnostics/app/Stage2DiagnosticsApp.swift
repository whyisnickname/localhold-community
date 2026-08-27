// SPDX-License-Identifier: MPL-2.0
import Foundation
import os
import UIKit

@main
final class Stage2DiagnosticsAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(
            rootViewController: Stage2DiagnosticsViewController()
        )
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class Stage2DiagnosticsViewController: UIViewController {
    private static let profiles: [(memoryKiB: Int, operations: UInt64)] = [
        (65_536, 2), (65_536, 3), (65_536, 4),
        (98_304, 2), (98_304, 3), (98_304, 4),
        (131_072, 2), (131_072, 3), (131_072, 4),
    ]
    private let logger = Logger(
        subsystem: "dev.localhold.stage2.iosdiagnostics",
        category: "physical-evidence"
    )
    private let runButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let evidenceView = UITextView()
    private var evidenceLines: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Localhold Stage 2"
        view.backgroundColor = .systemBackground

        let explanation = UILabel()
        explanation.numberOfLines = 0
        explanation.font = .preferredFont(forTextStyle: .body)
        explanation.text = "Synthetic physical-device diagnostics only. No account, network, payment, or user vault data is used. Keep the app in the foreground until completion."

        runButton.configuration = .filled()
        runButton.configuration?.title = "Run all physical diagnostics"
        runButton.accessibilityHint = "Runs the fixed Argon2 grid, 10,000 records, and 1 and 5 GiB attachment streams"
        runButton.addTarget(self, action: #selector(runAllDiagnostics), for: .touchUpInside)

        copyButton.configuration = .bordered()
        copyButton.configuration?.title = "Copy synthetic evidence"
        copyButton.isEnabled = false
        copyButton.addTarget(self, action: #selector(copyEvidence), for: .touchUpInside)

        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.text = "Ready — press Run only after Selectel logs are recording."

        evidenceView.isEditable = false
        evidenceView.isSelectable = true
        evidenceView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        evidenceView.backgroundColor = .secondarySystemBackground
        evidenceView.layer.cornerRadius = 8
        evidenceView.text = "Evidence will appear here and in the iOS unified log with prefix LOCALHOLD_STAGE2_EVIDENCE."

        let stack = UIStackView(arrangedSubviews: [
            explanation, runButton, copyButton, statusLabel, evidenceView,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            evidenceView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])
    }

    @objc private func runAllDiagnostics() {
        runButton.isEnabled = false
        copyButton.isEnabled = false
        evidenceLines.removeAll(keepingCapacity: true)
        evidenceView.text = ""
        UIApplication.shared.isIdleTimerDisabled = true
        setStatus("Running Argon2id grid (0/9)…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let revision = try self.buildRevision()
                for (index, profile) in Self.profiles.enumerated() {
                    let json = try IOSArgon2EvidenceCollector.collectReleaseEvidence(
                        buildRevision: revision,
                        memoryKiB: profile.memoryKiB,
                        operations: profile.operations
                    )
                    self.emit(json)
                    self.setStatus("Running Argon2id grid (\(index + 1)/9)…")
                }

                let workingDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("localhold-stage2-device", isDirectory: true)
                try? FileManager.default.removeItem(at: workingDirectory)
                try FileManager.default.createDirectory(
                    at: workingDirectory,
                    withIntermediateDirectories: true
                )
                defer { try? FileManager.default.removeItem(at: workingDirectory) }

                for attachmentGiB in [1, 5] {
                    self.setStatus("Running 10,000 records + \(attachmentGiB) GiB stream…")
                    let evidence = try IOSMobileStressEvidenceCollector.collectReleaseEvidence(
                        buildRevision: revision,
                        attachmentGiB: attachmentGiB,
                        workingDirectory: workingDirectory
                    )
                    self.emit(evidence.recordJSON)
                    self.emit(evidence.attachmentJSON)
                }
                self.finish(status: "PASS — 13 synthetic evidence records emitted. Copy them and keep the Selectel logs.")
            } catch {
                let failure = "LOCALHOLD_STAGE2_FAILURE type=\(String(describing: type(of: error)))"
                self.logger.fault("\(failure, privacy: .public)")
                self.finish(status: "FAILED CLOSED — \(String(describing: type(of: error))). Do not rerun until Codex reviews the logs.")
            }
        }
    }

    @objc private func copyEvidence() {
        UIPasteboard.general.string = evidenceLines.joined(separator: "\n")
        setStatus("Synthetic evidence copied. No user or vault data is included.")
    }

    private func buildRevision() throws -> String {
        guard let revision = Bundle.main.object(
            forInfoDictionaryKey: "LocalholdBuildRevision"
        ) as? String,
              revision.range(of: "^[0-9a-fA-F]{7,64}$", options: .regularExpression) != nil
        else {
            throw IOSArgon2EvidenceError.invalidRevision
        }
        return revision
    }

    private func emit(_ json: String) {
        let line = "LOCALHOLD_STAGE2_EVIDENCE \(json)"
        logger.notice("\(line, privacy: .public)")
        DispatchQueue.main.sync {
            evidenceLines.append(json)
            evidenceView.text = evidenceLines.joined(separator: "\n")
            let end = NSRange(location: evidenceView.text.utf16.count, length: 0)
            evidenceView.scrollRangeToVisible(end)
        }
    }

    private func setStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in self?.statusLabel.text = text }
    }

    private func finish(status: String) {
        DispatchQueue.main.async { [weak self] in
            UIApplication.shared.isIdleTimerDisabled = false
            self?.statusLabel.text = status
            self?.copyButton.isEnabled = !(self?.evidenceLines.isEmpty ?? true)
        }
    }
}
