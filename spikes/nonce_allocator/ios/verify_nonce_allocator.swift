// SPDX-License-Identifier: MPL-2.0
import Foundation

private func state(epoch: Data, counter: UInt64) throws -> IOSNonceDomainState {
    try IOSNonceDomainState(
        keyGenerationID: Data(repeating: 0x11, count: 16),
        epoch: epoch,
        nextCounter: counter
    )
}

private func unexpectedRandom(_ count: Int) throws -> Data {
    fatalError("unexpected random request for \(count) bytes")
}

let missingStore = IOSAtomicNonceStateStore()
let missing = IOSNonceAllocatorProtocol(
    store: missingStore,
    secureBytes: { count in
        precondition(count == 4)
        return Data([0x01, 0x02, 0x03, 0x04])
    }
)
do {
    _ = try missing.reserve()
    fatalError("missing nonce state was silently recreated")
} catch IOSNonceProtocolError.missingState {}
_ = try missing.initializeForNewKey(keyGenerationID: Data(repeating: 0x22, count: 16))
precondition(missingStore.snapshot()?.nextCounter == 0)
let initializedNonce = try missing.reserve().nonce
precondition(initializedNonce.hex == "010203040000000000000000")
do {
    _ = try missing.initializeForNewKey(keyGenerationID: Data(repeating: 0x33, count: 16))
    fatalError("existing nonce state was reinitialized")
} catch IOSNonceProtocolError.alreadyInitialized {}

let layoutStore = IOSAtomicNonceStateStore(
    initialState: try state(epoch: Data([0x01, 0x02, 0x03, 0x04]), counter: 0)
)
let layout = IOSNonceAllocatorProtocol(store: layoutStore, secureBytes: unexpectedRandom)
let layoutFirst = try layout.reserve().nonce
let layoutSecond = try layout.reserve().nonce
precondition(layoutFirst.hex == "010203040000000000000000")
precondition(layoutSecond.hex == "010203040000000000000001")

let concurrentStore = IOSAtomicNonceStateStore(
    initialState: try state(epoch: Data([0x11, 0x22, 0x33, 0x44]), counter: 0)
)
let concurrent = IOSNonceAllocatorProtocol(store: concurrentStore, secureBytes: unexpectedRandom)
let resultLock = NSLock()
var nonces = Set<Data>()
DispatchQueue.concurrentPerform(iterations: 16) { _ in
    for _ in 0..<2_000 {
        let nonce = try! concurrent.reserve().nonce
        resultLock.lock()
        precondition(nonces.insert(nonce).inserted)
        resultLock.unlock()
    }
}
precondition(nonces.count == 32_000)
precondition(concurrentStore.snapshot()?.nextCounter == 32_000)

let faultStore = IOSAtomicNonceStateStore(
    initialState: try state(epoch: Data([0x01, 0x02, 0x03, 0x04]), counter: 41)
)
let fault = IOSNonceAllocatorProtocol(store: faultStore, secureBytes: unexpectedRandom)
do {
    _ = try fault.reserve(fault: .beforeCommit)
    fatalError("before-commit fault returned a nonce")
} catch IOSNonceProtocolError.syntheticCommitFailure {}
precondition(faultStore.snapshot()?.nextCounter == 41)
do {
    _ = try fault.reserve(fault: .afterCommitBeforeReturn)
    fatalError("after-commit fault returned a nonce")
} catch IOSNonceProtocolError.syntheticCommitFailure {}
precondition(faultStore.snapshot()?.nextCounter == 42)
let faultRecoveryNonce = try fault.reserve().nonce
precondition(faultRecoveryNonce.hex == "01020304000000000000002a")

let exhaustedStore = IOSAtomicNonceStateStore(
    initialState: try state(epoch: Data([0x01, 0x02, 0x03, 0x04]), counter: .max)
)
let exhausted = IOSNonceAllocatorProtocol(store: exhaustedStore, secureBytes: unexpectedRandom)
do {
    _ = try exhausted.reserve()
    fatalError("exhausted counter wrapped")
} catch IOSNonceProtocolError.exhausted {}
precondition(exhaustedStore.snapshot()?.nextCounter == .max)

let clonedState = try state(epoch: Data([0x01, 0x02, 0x03, 0x04]), counter: 7)
let original = IOSNonceAllocatorProtocol(
    store: IOSAtomicNonceStateStore(initialState: clonedState),
    secureBytes: unexpectedRandom
)
var replacements = [Data([0xaa, 0xbb, 0xcc, 0xdd])]
let cloneStore = IOSAtomicNonceStateStore(initialState: clonedState)
let clone = IOSNonceAllocatorProtocol(
    store: cloneStore,
    secureBytes: { count in
        let next = replacements.removeFirst()
        precondition(next.count == count)
        return next
    }
)
let originalNonce = try original.reserve().nonce
do {
    _ = try clone.rotateAfterKeyChange(newKeyGenerationID: Data(repeating: 0x11, count: 16))
    fatalError("clone accepted the previous key generation")
} catch IOSNonceProtocolError.keyGenerationNotChanged {}
precondition(cloneStore.snapshot()?.nextCounter == 7)
let cloneGeneration = try clone.rotateAfterKeyChange(
    newKeyGenerationID: Data(repeating: 0x22, count: 16)
)
precondition(cloneGeneration == Data(repeating: 0x22, count: 16))
let cloneNonce = try clone.reserve().nonce
precondition(originalNonce.hex == "010203040000000000000007")
precondition(cloneNonce.hex == "aabbccdd0000000000000000")

print("Swift nonce allocation layout, concurrency, fault and rotation checks passed")

private extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
