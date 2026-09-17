import Foundation
import Testing
@testable import VaultAppCore

private actor EventRecorder {
    private var values: [String] = []
    func record(_ value: String) { values.append(value) }
    func snapshot() -> [String] { values }
}

private enum SyntheticError: Error { case failed }

private actor TransactionSetupStore: SetupStatusStoring {
    private let recorder: EventRecorder
    private(set) var completed = false
    private(set) var pending = false
    init(recorder: EventRecorder) { self.recorder = recorder }
    func isSetupComplete() async throws -> Bool { completed }
    func hasPendingSetup() async -> Bool { pending }
    func beginSetup() async throws { pending = true }
    func clearPendingSetup() async { pending = false }
    func markSetupComplete(_ metadata: SetupMetadata) async throws {
        await recorder.record("setup")
        completed = true
    }
}

private actor TransactionRecoveryStore: RecoveryEnvelopeStoring {
    private let recorder: EventRecorder
    private(set) var removed = false
    var envelope = Data([8])
    init(recorder: EventRecorder) { self.recorder = recorder }
    func hasRecoveryEnvelope() async -> Bool { false }
    func save(_ envelope: Data) async throws {
        await recorder.record("recovery")
        self.envelope = envelope
    }
    func load() async throws -> Data { envelope }
    func removeIncompleteRecovery() async { removed = true }
}

private actor TransactionVaultStore: EncryptedVaultStoring {
    private let recorder: EventRecorder
    private(set) var removed = false
    var count = 0
    init(recorder: EventRecorder, count: Int = 0) {
        self.recorder = recorder
        self.count = count
    }
    func hasVault() async -> Bool { false }
    func createEmptyVault(using key: Data) async throws {
        await recorder.record("vault")
    }
    func recordCount(using key: Data) async throws -> Int { count }
    func removeIncompleteVault() async { removed = true }
}

private actor TransactionDeviceKeyStore: DeviceVaultKeyStoring {
    private let recorder: EventRecorder
    private let failInstall: Bool
    private(set) var removed = false
    init(recorder: EventRecorder, failInstall: Bool = false) {
        self.recorder = recorder
        self.failInstall = failInstall
    }
    func install(_ key: Data) async throws {
        await recorder.record("keychain")
        if failInstall { throw SyntheticError.failed }
    }
    func removeIncompleteKey() async { removed = true }
}

private struct TransactionRecovery: MasterPasswordRecovering {
    let failPassword: String?
    init(failPassword: String? = nil) { self.failPassword = failPassword }
    func createEnvelope(vaultKey: Data, masterPassword: String) async throws -> Data {
        Data([4, 2])
    }
    func recoverVaultKey(envelope: Data, masterPassword: String) async throws -> Data {
        if masterPassword == failPassword { throw SyntheticError.failed }
        return Data(repeating: 7, count: 32)
    }
}

private struct TransactionKeyGenerator: VaultKeyGenerating {
    func generateVaultKey() throws -> Data { Data(repeating: 7, count: 32) }
}

private actor TransactionSession: VaultSessionAccessing {
    private(set) var key: Data?
    func unlockWithDeviceAuthentication(reason: String) async throws {
        key = Data(repeating: 7, count: 32)
    }
    func installVerifiedVaultKey(_ key: Data) async throws { self.key = key }
    func lock() async { key = nil }
    func currentVaultKey() async throws -> Data {
        guard let key else { throw SyntheticError.failed }
        return key
    }
    func hasKey() -> Bool { key != nil }
}

private final class MutableClock: VaultAppClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ value: Date) { self.value = value }
    func currentDate() -> Date {
        lock.lock(); defer { lock.unlock() }
        return value
    }
    func advance(_ seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        value = value.addingTimeInterval(seconds)
    }
}

private func transactionDependencies(
    recorder: EventRecorder,
    setup: TransactionSetupStore,
    recoveryStore: TransactionRecoveryStore,
    vaultStore: TransactionVaultStore,
    deviceStore: TransactionDeviceKeyStore,
    recovery: TransactionRecovery,
    session: TransactionSession,
    clock: MutableClock
) -> VaultAppDependencies {
    VaultAppDependencies(
        setupStore: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceKeyStore: deviceStore,
        recovery: recovery,
        keyGenerator: TransactionKeyGenerator(),
        session: session,
        clock: clock
    )
}

@Test func setupMarkerIsWrittenLast() async throws {
    let recorder = EventRecorder()
    let setup = TransactionSetupStore(recorder: recorder)
    let recoveryStore = TransactionRecoveryStore(recorder: recorder)
    let vaultStore = TransactionVaultStore(recorder: recorder)
    let deviceStore = TransactionDeviceKeyStore(recorder: recorder)
    let session = TransactionSession()
    let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
    let coordinator = VaultAppCoordinator(dependencies: transactionDependencies(
        recorder: recorder,
        setup: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceStore: deviceStore,
        recovery: TransactionRecovery(),
        session: session,
        clock: clock
    ))

    try await coordinator.createVault(masterPassword: "synthetic-master", confirmation: "synthetic-master")

    #expect(await recorder.snapshot() == ["recovery", "vault", "keychain", "setup"])
    #expect(await setup.completed)
    #expect(await coordinator.state == .unlocked(recordCount: 0))
}

@Test func failedKeychainInstallDoesNotCreateSetupMarker() async {
    let recorder = EventRecorder()
    let setup = TransactionSetupStore(recorder: recorder)
    let recoveryStore = TransactionRecoveryStore(recorder: recorder)
    let vaultStore = TransactionVaultStore(recorder: recorder)
    let deviceStore = TransactionDeviceKeyStore(recorder: recorder, failInstall: true)
    let session = TransactionSession()
    let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
    let coordinator = VaultAppCoordinator(dependencies: transactionDependencies(
        recorder: recorder,
        setup: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceStore: deviceStore,
        recovery: TransactionRecovery(),
        session: session,
        clock: clock
    ))

    do {
        try await coordinator.createVault(masterPassword: "synthetic-master", confirmation: "synthetic-master")
        Issue.record("setup unexpectedly succeeded")
    } catch let error as VaultAppCoordinatorError {
        #expect(error == .unableToCreateVault)
    } catch {
        Issue.record("unexpected error: \(error)")
    }

    #expect(!(await setup.completed))
    #expect(await recorder.snapshot() == ["recovery", "vault", "keychain"])
    #expect(await recoveryStore.removed)
    #expect(await vaultStore.removed)
    #expect(await coordinator.state == .needsSetup)
}

@Test func wrongRecoveryStaysLockedAndSuccessfulRetryResetsBackoff() async throws {
    let recorder = EventRecorder()
    let setup = TransactionSetupStore(recorder: recorder)
    try await setup.markSetupComplete(SetupMetadata())
    let recoveryStore = TransactionRecoveryStore(recorder: recorder)
    let vaultStore = TransactionVaultStore(recorder: recorder, count: 4)
    let deviceStore = TransactionDeviceKeyStore(recorder: recorder)
    let session = TransactionSession()
    let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
    let coordinator = VaultAppCoordinator(dependencies: transactionDependencies(
        recorder: recorder,
        setup: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceStore: deviceStore,
        recovery: TransactionRecovery(failPassword: "wrong"),
        session: session,
        clock: clock
    ))
    await coordinator.bootstrap()

    do {
        try await coordinator.unlockWithMasterPassword("wrong")
        Issue.record("wrong recovery password unexpectedly unlocked")
    } catch {}

    #expect(await coordinator.state == .locked)
    #expect(await coordinator.recoveryFailureCount == 1)
    #expect(!(await session.hasKey()))

    clock.advance(1)
    try await coordinator.unlockWithMasterPassword("correct")

    #expect(await coordinator.state == .unlocked(recordCount: 4))
    #expect(await coordinator.recoveryFailureCount == 0)
    #expect(await session.hasKey())
}

@Test func explicitLockClearsUnlockedPresentationAndSession() async throws {
    let recorder = EventRecorder()
    let setup = TransactionSetupStore(recorder: recorder)
    let recoveryStore = TransactionRecoveryStore(recorder: recorder)
    let vaultStore = TransactionVaultStore(recorder: recorder, count: 3)
    let deviceStore = TransactionDeviceKeyStore(recorder: recorder)
    let session = TransactionSession()
    let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
    let coordinator = VaultAppCoordinator(dependencies: transactionDependencies(
        recorder: recorder,
        setup: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceStore: deviceStore,
        recovery: TransactionRecovery(),
        session: session,
        clock: clock
    ))

    try await coordinator.createVault(masterPassword: "synthetic-master", confirmation: "synthetic-master")
    #expect(await coordinator.state == .unlocked(recordCount: 3))

    await coordinator.lock()

    #expect(await coordinator.state == .locked)
    #expect(!(await session.hasKey()))
}
