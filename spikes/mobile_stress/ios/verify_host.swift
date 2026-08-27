// SPDX-License-Identifier: MPL-2.0
import Foundation

let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("localhold-mobile-stress-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

var recordKey = Data((0..<32).map { UInt8($0 + 11) })
var attachmentKey = Data((0..<32).map { UInt8($0 + 101) })
defer {
    recordKey.resetBytes(in: recordKey.startIndex..<recordKey.endIndex)
    attachmentKey.resetBytes(in: attachmentKey.startIndex..<attachmentKey.endIndex)
}

let recordURL = directory.appendingPathComponent("records.bin")
let recordNonceState = IOSAtomicNonceStateStore()
let recordNonceAllocator = IOSNonceAllocatorProtocol(
    store: recordNonceState,
    secureBytes: { count in Data((0..<count).map { _ in UInt8.random(in: .min ... .max) }) }
)
_ = try recordNonceAllocator.initializeForNewKey(
    keyGenerationID: Data(repeating: 0x31, count: 16)
)
let recordStore = try IOSEncryptedRecordBlobStore(
    storageURL: recordURL,
    keyBytes: recordKey,
    nonceAllocator: recordNonceAllocator
)
let priorWrite = try recordStore.writeSynthetic(recordCount: 1)
precondition(priorWrite.recordCount == 1)
let write = try recordStore.writeSynthetic(recordCount: 10_000)
precondition(write.recordCount == 10_000)
precondition(write.uniqueNonceCount == 10_000)
precondition(recordNonceState.snapshot()?.nextCounter == 10_001)
let containsPlaintextSentinel = try recordStore.containsPlaintextSentinel()
precondition(!containsPlaintextSentinel)
let unlocked = try recordStore.unlockAndBuildIndex()
precondition(unlocked.indexedRecordCount == 10_000)
let initialQuery = try recordStore.query(unlocked.session, token: "needle9999")
precondition(initialQuery == Set(["record-09999"]))
try recordStore.corruptCiphertext(recordIndex: 5_000)
do {
    _ = try recordStore.unlockAndBuildIndex()
    fatalError("corrupted record must not authenticate")
} catch {
    let queryAfterCorruption = try recordStore.query(unlocked.session, token: "needle9999")
    precondition(queryAfterCorruption == Set(["record-09999"]))
}
recordStore.lock()
do {
    _ = try recordStore.query(unlocked.session, token: "needle9999")
    fatalError("stale record session must fail")
} catch IOSMobileStressError.staleSession {
    // Expected.
}

let attachmentNonceState = IOSAtomicNonceStateStore()
let attachmentNonceAllocator = IOSNonceAllocatorProtocol(
    store: attachmentNonceState,
    secureBytes: { count in Data((0..<count).map { _ in UInt8.random(in: .min ... .max) }) }
)
_ = try attachmentNonceAllocator.initializeForNewKey(
    keyGenerationID: Data(repeating: 0x41, count: 16)
)
let attachment = try IOSAttachmentStreamHarness(
    keyBytes: attachmentKey,
    nonceAllocator: attachmentNonceAllocator
)
let target = IOSDiagnosticTransactionalTarget()
let streamed = try attachment.encryptSynthetic(
    totalPlaintextBytes: 10 * 1_024 * 1_024,
    target: target
)
precondition(streamed.chunkCount == 10)
precondition(streamed.uniqueNonceCount == streamed.chunkCount)
precondition(target.promoted)

let empty = IOSDiagnosticTransactionalTarget()
let emptyResult = try attachment.encryptSynthetic(totalPlaintextBytes: 0, target: empty)
precondition(emptyResult.chunkCount == 0)
precondition(empty.promoted)

let short = IOSDiagnosticTransactionalTarget()
let shortResult = try attachment.encryptSynthetic(
    totalPlaintextBytes: 1_024 * 1_024 + 123,
    target: short
)
precondition(shortResult.finalChunkBytes == 123)

let cancelled = IOSDiagnosticTransactionalTarget()
do {
    _ = try attachment.encryptSynthetic(
        totalPlaintextBytes: 3 * 1_024 * 1_024,
        target: cancelled,
        cancelAfterChunks: 1
    )
    fatalError("cancellation must fail")
} catch IOSMobileStressError.syntheticCancellation {
    precondition(cancelled.currentVersion == "previous-valid")
    precondition(!cancelled.promoted)
}

let full = IOSDiagnosticTransactionalTarget(failAfterBytes: 1_024 * 1_024)
do {
    _ = try attachment.encryptSynthetic(
        totalPlaintextBytes: 2 * 1_024 * 1_024,
        target: full
    )
    fatalError("synthetic storage-full must fail")
} catch IOSMobileStressError.syntheticStorageFull {
    precondition(full.currentVersion == "previous-valid")
    precondition(!full.promoted)
}
let corruptedChunkRejected = try attachment.corruptedChunkFailsAuthentication()
precondition(corruptedChunkRejected)
precondition(attachmentNonceState.snapshot()?.nextCounter == 15)

print("iOS/macOS mobile-stress host verifier passed")
