import Foundation
import Testing
@testable import VaultAppCore

private actor FakeSetupStore: SetupStatusStoring {
    var completed = false
    func isSetupComplete() async throws -> Bool { completed }
    func markSetupComplete(_ metadata: SetupMetadata) async throws { completed = true }
}

private struct NoopKeyGenerator: VaultKeyGenerating {
    func generateVaultKey() throws -> Data { Data(repeating: 1, count: 32) }
}

private actor NoopSession: VaultSessionAccessing {
    var unlocked = false
    func unlockWithDeviceAuthentication(reason: String) async throws { unlocked = true }
    func installVerifiedVaultKey(_ key: Data) async throws { unlocked = true }
    func lock() async { unlocked = false }
    func currentVaultKey() async throws -> Data {
        guard unlocked else { throw VaultAppCoordinatorError.unableToUnlock }
        return Data(repeating: 1, count: 32)
    }
}

private struct NoopVaultStore: EncryptedVaultStoring {
    func createEmptyVault(using key: Data) async throws {}
    func recordCount(using key: Data) async throws -> Int { 0 }
    func removeIncompleteVault() async {}
}

private actor NoopRecoveryStore: RecoveryEnvelopeStoring {
    func save(_ envelope: Data) async throws {}
    func load() async throws -> Data { Data() }
    func removeIncompleteRecovery() async {}
}

private struct NoopRecoveryService: MasterPasswordRecovering {
    func createEnvelope(vaultKey: Data, masterPassword: String) async throws -> Data { Data([1]) }
    func recoverVaultKey(envelope: Data, masterPassword: String) async throws -> Data { Data(repeating: 1, count: 32) }
}

private actor NoopDeviceKeyStore: DeviceVaultKeyStoring {
    func install(_ key: Data) async throws {}
}

private struct FixedClock: VaultAppClock {
    let now: Date
    func currentDate() -> Date { now }
}

private func dependencies(setup: FakeSetupStore) -> VaultAppDependencies {
    VaultAppDependencies(
        setupStore: setup,
        recoveryStore: NoopRecoveryStore(),
        vaultStore: NoopVaultStore(),
        deviceKeyStore: NoopDeviceKeyStore(),
        recovery: NoopRecoveryService(),
        keyGenerator: NoopKeyGenerator(),
        session: NoopSession(),
        clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000))
    )
}

@Test func cleanInstallStartsInSetup() async throws {
    let setup = FakeSetupStore()
    let coordinator = VaultAppCoordinator(dependencies: dependencies(setup: setup))
    await coordinator.bootstrap()
    #expect(await coordinator.state == .needsSetup)
}

@Test func completedSetupStartsLocked() async throws {
    let setup = FakeSetupStore()
    try await setup.markSetupComplete(SetupMetadata())
    let coordinator = VaultAppCoordinator(dependencies: dependencies(setup: setup))
    await coordinator.bootstrap()
    #expect(await coordinator.state == .locked)
}
