import Foundation
import Testing
@testable import VaultAppCore

private enum ProtectionSyntheticError: Error { case failed }

private actor ProtectionSetupStore: SetupStatusStoring {
    var completed: Bool
    var pending: Bool

    init(completed: Bool = false, pending: Bool = false) {
        self.completed = completed
        self.pending = pending
    }

    func isSetupComplete() async throws -> Bool { completed }
    func hasPendingSetup() async -> Bool { pending }
    func beginSetup() async throws { pending = true }
    func clearPendingSetup() async { pending = false }
    func markSetupComplete(_ metadata: SetupMetadata) async throws { completed = true }
}

private actor ProtectionRecoveryStore: RecoveryEnvelopeStoring {
    var exists: Bool
    private(set) var saveCount = 0
    private(set) var removeCount = 0

    init(exists: Bool) { self.exists = exists }

    func hasRecoveryEnvelope() async -> Bool { exists }
    func save(_ envelope: Data) async throws { exists = true; saveCount += 1 }
    func load() async throws -> Data { Data([1]) }
    func removeIncompleteRecovery() async { exists = false; removeCount += 1 }
}

private actor ProtectionVaultStore: EncryptedVaultStoring {
    var exists: Bool
    private(set) var createCount = 0
    private(set) var removeCount = 0

    init(exists: Bool) { self.exists = exists }

    func hasVault() async -> Bool { exists }
    func createEmptyVault(using key: Data) async throws { exists = true; createCount += 1 }
    func recordCount(using key: Data) async throws -> Int { 0 }
    func removeIncompleteVault() async { exists = false; removeCount += 1 }
}

private actor ProtectionDeviceKeyStore: DeviceVaultKeyStoring {
    private(set) var installCount = 0
    private(set) var removeCount = 0
    func install(_ key: Data) async throws { installCount += 1 }
    func removeIncompleteKey() async { removeCount += 1 }
}

private struct ProtectionRecovery: MasterPasswordRecovering {
    func createEnvelope(vaultKey: Data, masterPassword: String) async throws -> Data { Data([2]) }
    func recoverVaultKey(envelope: Data, masterPassword: String) async throws -> Data {
        Data(repeating: 3, count: 32)
    }
}

private struct ProtectionKeyGenerator: VaultKeyGenerating {
    func generateVaultKey() throws -> Data { Data(repeating: 3, count: 32) }
}

private actor ProtectionSession: VaultSessionAccessing {
    var key: Data?
    func unlockWithDeviceAuthentication(reason: String) async throws { throw ProtectionSyntheticError.failed }
    func installVerifiedVaultKey(_ key: Data) async throws { self.key = key }
    func lock() async { key = nil }
    func currentVaultKey() async throws -> Data {
        guard let key else { throw ProtectionSyntheticError.failed }
        return key
    }
}

private struct ProtectionClock: VaultAppClock {
    func currentDate() -> Date { Date(timeIntervalSince1970: 1_700_000_000) }
}

private func protectionDependencies(
    setup: ProtectionSetupStore,
    recoveryStore: ProtectionRecoveryStore,
    vaultStore: ProtectionVaultStore,
    deviceStore: ProtectionDeviceKeyStore
) -> VaultAppDependencies {
    VaultAppDependencies(
        setupStore: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceKeyStore: deviceStore,
        recovery: ProtectionRecovery(),
        keyGenerator: ProtectionKeyGenerator(),
        session: ProtectionSession(),
        clock: ProtectionClock()
    )
}

@Test func existingArtifactsWithoutPendingMarkerAreNeverOverwrittenOrRemoved() async {
    let setup = ProtectionSetupStore()
    let recoveryStore = ProtectionRecoveryStore(exists: true)
    let vaultStore = ProtectionVaultStore(exists: true)
    let deviceStore = ProtectionDeviceKeyStore()
    let coordinator = VaultAppCoordinator(dependencies: protectionDependencies(
        setup: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceStore: deviceStore
    ))

    await coordinator.bootstrap()
    #expect(await coordinator.state == .needsSetup)
    #expect(await coordinator.lastError == .vaultUnavailable)

    do {
        try await coordinator.createVault(masterPassword: "synthetic-master", confirmation: "synthetic-master")
        Issue.record("existing artifacts were unexpectedly overwritten")
    } catch let error as VaultAppCoordinatorError {
        #expect(error == .unableToCreateVault)
    } catch {
        Issue.record("unexpected error: \(error)")
    }

    #expect(await recoveryStore.saveCount == 0)
    #expect(await recoveryStore.removeCount == 0)
    #expect(await vaultStore.createCount == 0)
    #expect(await vaultStore.removeCount == 0)
    #expect(await deviceStore.installCount == 0)
    #expect(await deviceStore.removeCount == 0)
    #expect(await setup.hasPendingSetup() == false)
}

@Test func pendingMarkerAllowsInterruptedSetupCleanupAndFreshRetry() async throws {
    let setup = ProtectionSetupStore(pending: true)
    let recoveryStore = ProtectionRecoveryStore(exists: true)
    let vaultStore = ProtectionVaultStore(exists: true)
    let deviceStore = ProtectionDeviceKeyStore()
    let coordinator = VaultAppCoordinator(dependencies: protectionDependencies(
        setup: setup,
        recoveryStore: recoveryStore,
        vaultStore: vaultStore,
        deviceStore: deviceStore
    ))

    try await coordinator.createVault(masterPassword: "synthetic-master", confirmation: "synthetic-master")

    #expect(await recoveryStore.removeCount == 1)
    #expect(await vaultStore.removeCount == 1)
    #expect(await deviceStore.removeCount == 1)
    #expect(await recoveryStore.saveCount == 1)
    #expect(await vaultStore.createCount == 1)
    #expect(await deviceStore.installCount == 1)
    #expect(try await setup.isSetupComplete())
    #expect(await setup.hasPendingSetup() == false)
    #expect(await coordinator.state == .unlocked(recordCount: 0))
}
