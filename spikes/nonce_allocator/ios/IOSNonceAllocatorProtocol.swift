// SPDX-License-Identifier: MPL-2.0
import Foundation

enum IOSNonceCommitFault {
    case none
    case beforeCommit
    case afterCommitBeforeReturn
}

enum IOSNonceProtocolError: Error {
    case invalidState
    case missingState
    case alreadyInitialized
    case keyGenerationNotChanged
    case exhausted
    case syntheticCommitFailure
}

struct IOSNonceDomainState {
    let keyGenerationID: Data
    let epoch: Data
    let nextCounter: UInt64

    init(keyGenerationID: Data, epoch: Data, nextCounter: UInt64) throws {
        guard keyGenerationID.count == 16, epoch.count == 4 else {
            throw IOSNonceProtocolError.invalidState
        }
        self.keyGenerationID = keyGenerationID
        self.epoch = epoch
        self.nextCounter = nextCounter
    }
}

struct IOSNonceReservation {
    let keyGenerationID: Data
    let nonce: Data
}

/// Diagnostic stand-in for the durable serialized transaction required in Stage 4.
final class IOSAtomicNonceStateStore {
    private let lock = NSLock()
    private var committedState: IOSNonceDomainState?

    init(initialState: IOSNonceDomainState? = nil) {
        committedState = initialState
    }

    func transact<T>(
        fault: IOSNonceCommitFault = .none,
        transition: (IOSNonceDomainState?) throws -> (IOSNonceDomainState, T)
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        let (next, result) = try transition(committedState)
        if fault == .beforeCommit { throw IOSNonceProtocolError.syntheticCommitFailure }
        committedState = next
        if fault == .afterCommitBeforeReturn {
            throw IOSNonceProtocolError.syntheticCommitFailure
        }
        return result
    }

    func snapshot() -> IOSNonceDomainState? {
        lock.lock()
        defer { lock.unlock() }
        return committedState
    }
}

/// Native-owned allocation protocol. Application callers never choose a nonce.
final class IOSNonceAllocatorProtocol {
    private let store: IOSAtomicNonceStateStore
    private let secureBytes: (Int) throws -> Data

    init(store: IOSAtomicNonceStateStore, secureBytes: @escaping (Int) throws -> Data) {
        self.store = store
        self.secureBytes = secureBytes
    }

    func reserve(fault: IOSNonceCommitFault = .none) throws -> IOSNonceReservation {
        return try store.transact(fault: fault) { existing in
            guard let state = existing else { throw IOSNonceProtocolError.missingState }
            guard state.nextCounter != UInt64.max else { throw IOSNonceProtocolError.exhausted }
            let reservation = IOSNonceReservation(
                keyGenerationID: state.keyGenerationID,
                nonce: Self.nonce(epoch: state.epoch, counter: state.nextCounter)
            )
            let next = try IOSNonceDomainState(
                keyGenerationID: state.keyGenerationID,
                epoch: state.epoch,
                nextCounter: state.nextCounter + 1
            )
            return (next, reservation)
        }
    }

    func initializeForNewKey(
        keyGenerationID: Data,
        fault: IOSNonceCommitFault = .none
    ) throws -> Data {
        guard keyGenerationID.count == 16 else {
            throw IOSNonceProtocolError.invalidState
        }
        return try store.transact(fault: fault) { existing in
            guard existing == nil else { throw IOSNonceProtocolError.alreadyInitialized }
            let epoch = try secureBytes(4)
            guard epoch.count == 4 else { throw IOSNonceProtocolError.invalidState }
            let state = try IOSNonceDomainState(
                keyGenerationID: keyGenerationID,
                epoch: epoch,
                nextCounter: 0
            )
            return (state, state.keyGenerationID)
        }
    }

    func rotateAfterKeyChange(
        newKeyGenerationID: Data,
        fault: IOSNonceCommitFault = .none
    ) throws -> Data {
        guard newKeyGenerationID.count == 16 else {
            throw IOSNonceProtocolError.invalidState
        }
        return try store.transact(fault: fault) { existing in
            guard let previous = existing else { throw IOSNonceProtocolError.missingState }
            if previous.keyGenerationID == newKeyGenerationID {
                throw IOSNonceProtocolError.keyGenerationNotChanged
            }
            var epoch = try secureBytes(4)
            guard epoch.count == 4 else { throw IOSNonceProtocolError.invalidState }
            while epoch == previous.epoch {
                epoch = try secureBytes(4)
                guard epoch.count == 4 else { throw IOSNonceProtocolError.invalidState }
            }
            let replacement = try IOSNonceDomainState(
                keyGenerationID: newKeyGenerationID,
                epoch: epoch,
                nextCounter: 0
            )
            return (replacement, replacement.keyGenerationID)
        }
    }

    private static func nonce(epoch: Data, counter: UInt64) -> Data {
        var value = epoch
        var bigEndian = counter.bigEndian
        withUnsafeBytes(of: &bigEndian) { value.append(contentsOf: $0) }
        return value
    }
}
