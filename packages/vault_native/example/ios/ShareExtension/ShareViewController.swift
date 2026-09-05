// SPDX-License-Identifier: MPL-2.0

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private var importStarted = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !importStarted else { return }
    importStarted = true
    let providers = (extensionContext?.inputItems ?? [])
      .compactMap { ($0 as? NSExtensionItem)?.attachments }
      .flatMap { $0 }
    importFirstSupported(providers, at: 0)
  }

  private func importFirstSupported(_ providers: [NSItemProvider], at index: Int) {
    guard index < providers.count else {
      finish(success: false)
      return
    }
    let provider = providers[index]
    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      stageFile(provider, type: UTType.image.identifier, kind: .image, providers: providers, index: index)
    } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
      stageFile(provider, type: UTType.data.identifier, kind: .file, providers: providers, index: index)
    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      stageInline(provider, type: UTType.url.identifier, kind: .url, providers: providers, index: index)
    } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      stageInline(provider, type: UTType.plainText.identifier, kind: .text, providers: providers, index: index)
    } else {
      importFirstSupported(providers, at: index + 1)
    }
  }

  private func stageFile(
    _ provider: NSItemProvider,
    type: String,
    kind: IOSInboundShareInputKind,
    providers: [NSItemProvider],
    index: Int
  ) {
    provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
      guard let self else { return }
      let success = url.map { IOSInboundShareStager.stageFile(at: $0, kind: kind) } ?? false
      success ? self.finish(success: true) : self.importFirstSupported(providers, at: index + 1)
    }
  }

  private func stageInline(
    _ provider: NSItemProvider,
    type: String,
    kind: IOSInboundShareInputKind,
    providers: [NSItemProvider],
    index: Int
  ) {
    provider.loadItem(forTypeIdentifier: type) { [weak self] item, _ in
      guard let self else { return }
      let data: Data? = switch item {
      case let value as URL: Data(value.absoluteString.utf8)
      case let value as String: Data(value.utf8)
      case let value as Data: value
      default: nil
      }
      let success = data.map { IOSInboundShareStager.stageData($0, kind: kind) } ?? false
      success ? self.finish(success: true) : self.importFirstSupported(providers, at: index + 1)
    }
  }

  private func finish(success: Bool) {
    DispatchQueue.main.async { [weak self] in
      guard let context = self?.extensionContext else { return }
      if success {
        context.completeRequest(returningItems: nil)
      } else {
        context.cancelRequest(
          withError: NSError(domain: "LocalholdShareExtension", code: 1)
        )
      }
    }
  }
}
