import Foundation
import VaultCore

public enum VaultAppState: Equatable, Sendable {
    case needsSetup
    case locked
    case unlocked(recordCount: Int)
}

public enum VaultAppUserError: Equatable, Sendable {
    case unableToCreateVault
    case unableToUnlock
    case recoveryPasswordNotAccepted
    case vaultUnavailable
}

public enum VaultAppCoordinatorError: Error, Equatable, Sendable {
    case invalidPasswordConfirmation
    case invalidVaultKeyLength(Int)
    case unableToCreateVault
    case unableToUnlock
    case recoveryTemporarilyBlocked(TimeInterval)
}

public protocol SetupStatusStoring: Sendable {
    func isSetupComplete() async throws -> Bool
    func hasPendingSetup() async -> Bool
    func beginSetup() async throws
    func clearPendingSetup() async
    func markSetupComplete(_ metadata: SetupMetadata) async throws
}

public protocol RecoveryEnvelopeStoring: Sendable {
    func hasRecoveryEnvelope() async -> Bool
    func save(_ envelope: Data) async throws
    func load() async throws -> Data
    func removeIncompleteRecovery() async
}

public protocol EncryptedVaultStoring: Sendable {
    func hasVault() async -> Bool
    func createEmptyVault(using key: Data) async throws
    func recordCount(using key: Data) async throws -> Int
    func removeIncompleteVault() async
}

public protocol DeviceVaultKeyStoring: Sendable {
    func install(_ key: Data) async throws
    func removeIncompleteKey() async
}

public extension DeviceVaultKeyStoring {
    func removeIncompleteKey() async {}
}

public protocol MasterPasswordRecovering: Sendable {
    func createEnvelope(vaultKey: Data, masterPassword: String) async throws -> Data
    func recoverVaultKey(envelope: Data, masterPassword: String) async throws -> Data
}

public protocol VaultKeyGenerating: Sendable {
    func generateVaultKey() throws -> Data
}

public protocol VaultSessionAccessing: Sendable {
    func unlockWithDeviceAuthentication(reason: String) async throws
    func installVerifiedVaultKey(_ key: Data) async throws
    func lock() async
    func currentVaultKey() async throws -> Data
}

public protocol VaultAppClock: Sendable {
    func currentDate() -> Date
}

public struct SystemVaultAppClock: VaultAppClock {
    public init() {}
    public func currentDate() -> Date { Date() }
}

public struct VaultAppDependencies: Sendable {
    public let setupStore: any SetupStatusStoring
    public let recoveryStore: any RecoveryEnvelopeStoring
    public let vaultStore: any EncryptedVaultStoring
    public let deviceKeyStore: any DeviceVaultKeyStoring
    public let recovery: any MasterPasswordRecovering
    public let keyGenerator: any VaultKeyGenerating
    public let session: any VaultSessionAccessing
    public let clock: any VaultAppClock

    public init(
        setupStore: any SetupStatusStoring,
        recoveryStore: any RecoveryEnvelopeStoring,
        vaultStore: any EncryptedVaultStoring,
        deviceKeyStore: any DeviceVaultKeyStoring,
        recovery: any MasterPasswordRecovering,
        keyGenerator: any VaultKeyGenerating,
        session: any VaultSessionAccessing,
        clock: any VaultAppClock
    ) {
        self.setupStore = setupStore
        self.recoveryStore = recoveryStore
        self.vaultStore = vaultStore
        self.deviceKeyStore = deviceKeyStore
        self.recovery = recovery
        self.keyGenerator = keyGenerator
        self.session = session
        self.clock = clock
    }
}

public actor VaultAppCoordinator {
    private let dependencies: VaultAppDependencies
    private var limiter: RecoveryAttemptLimiter

    public private(set) var state: VaultAppState = .needsSetup
    public private(set) var lastError: VaultAppUserError?

    public init(
        dependencies: VaultAppDependencies,
        recoveryBackoffPolicy: RecoveryBackoffPolicy = .default
    ) {
        self.dependencies = dependencies
        self.limiter = RecoveryAttemptLimiter(policy: recoveryBackoffPolicy)
    }

    public var recoveryFailureCount: Int { limiter.failureCount }

    public func recoveryRemainingDelay() -> TimeInterval {
        limiter.remainingDelay(at: dependencies.clock.currentDate())
    }

    public func bootstrap() async {
        lastError = nil
        do {
            if try await dependencies.setupStore.isSetupComplete() {
                await dependencies.setupStore.clearPendingSetup()
                state = .locked
                return
            }

            if await dependencies.setupStore.hasPendingSetup() {
                await cleanupIncompleteSetup()
                state = .needsSetup
                return
            }

            let hasRecovery = await dependencies.recoveryStore.hasRecoveryEnvelope()
            let hasVault = await dependencies.vaultStore.hasVault()
            if hasRecovery || hasVault {
                state = .needsSetup
                lastError = .vaultUnavailable
                return
            }

            state = .needsSetup
        } catch {
            state = .needsSetup
            lastError = .vaultUnavailable
        }
    }

    public func createVault(masterPassword: String, confirmation: String) async throws {
        guard !masterPassword.isEmpty, masterPassword == confirmation else {
            throw VaultAppCoordinatorError.invalidPasswordConfirmation
        }

        if try await dependencies.setupStore.isSetupComplete() {
            lastError = .unableToCreateVault
            throw VaultAppCoordinatorError.unableToCreateVault
        }

        if await dependencies.setupStore.hasPendingSetup() {
            await cleanupIncompleteSetup()
        } else {
            let hasRecovery = await dependencies.recoveryStore.hasRecoveryEnvelope()
            let hasVault = await dependencies.vaultStore.hasVault()
            if hasRecovery || hasVault {
                lastError = .vaultUnavailable
                throw VaultAppCoordinatorError.unableToCreateVault
            }
        }

        try await dependencies.setupStore.beginSetup()

        var key = try dependencies.keyGenerator.generateVaultKey()
        defer { key.resetBytes(in: 0..<key.count) }
        guard key.count == 32 else {
            throw VaultAppCoordinatorError.invalidVaultKeyLength(key.count)
        }

        var deviceKeyInstalled = false
        do {
            let recoveryEnvelope = try await dependencies.recovery.createEnvelope(
                vaultKey: key,
                masterPassword: masterPassword
            )
            try await dependencies.recoveryStore.save(recoveryEnvelope)
            try await dependencies.vaultStore.createEmptyVault(using: key)
            try await dependencies.deviceKeyStore.install(key)
            deviceKeyInstalled = true
            try await dependencies.setupStore.markSetupComplete(SetupMetadata())
            await dependencies.setupStore.clearPendingSetup()

            do {
                try await dependencies.session.installVerifiedVaultKey(key)
                let count = try await dependencies.vaultStore.recordCount(using: key)
                state = .unlocked(recordCount: count)
            } catch {
                await dependencies.session.lock()
                state = .locked
            }
            lastError = nil
        } catch {
            await dependencies.recoveryStore.removeIncompleteRecovery()
            await dependencies.vaultStore.removeIncompleteVault()
            if deviceKeyInstalled {
                await dependencies.deviceKeyStore.removeIncompleteKey()
            }
            await dependencies.setupStore.clearPendingSetup()
            state = .needsSetup
            lastError = .unableToCreateVault
            throw VaultAppCoordinatorError.unableToCreateVault
        }
    }

    public func unlockWithDeviceAuthentication(reason: String) async throws {
        do {
            try await dependencies.session.unlockWithDeviceAuthentication(reason: reason)
            let key = try await dependencies.session.currentVaultKey()
            let count = try await dependencies.vaultStore.recordCount(using: key)
            state = .unlocked(recordCount: count)
            lastError = nil
        } catch {
            await dependencies.session.lock()
            state = .locked
            lastError = .unableToUnlock
            throw VaultAppCoordinatorError.unableToUnlock
        }
    }

    public func unlockWithMasterPassword(_ masterPassword: String) async throws {
        let now = dependencies.clock.currentDate()
        guard limiter.canAttempt(at: now) else {
            throw VaultAppCoordinatorError.recoveryTemporarilyBlocked(limiter.remainingDelay(at: now))
        }

        do {
            let envelope = try await dependencies.recoveryStore.load()
            var key = try await dependencies.recovery.recoverVaultKey(
                envelope: envelope,
                masterPassword: masterPassword
            )
            defer { key.resetBytes(in: 0..<key.count) }
            guard key.count == 32 else {
                throw VaultAppCoordinatorError.invalidVaultKeyLength(key.count)
            }
            let count = try await dependencies.vaultStore.recordCount(using: key)
            try await dependencies.session.installVerifiedVaultKey(key)
            limiter.recordSuccess()
            state = .unlocked(recordCount: count)
            lastError = nil
        } catch let error as VaultAppCoordinatorError {
            if case .recoveryTemporarilyBlocked = error { throw error }
            limiter.recordFailure(at: now)
            await dependencies.session.lock()
            state = .locked
            lastError = .recoveryPasswordNotAccepted
            throw VaultAppCoordinatorError.unableToUnlock
        } catch {
            limiter.recordFailure(at: now)
            await dependencies.session.lock()
            state = .locked
            lastError = .recoveryPasswordNotAccepted
            throw VaultAppCoordinatorError.unableToUnlock
        }
    }

    private func cleanupIncompleteSetup() async {
        await dependencies.recoveryStore.removeIncompleteRecovery()
        await dependencies.vaultStore.removeIncompleteVault()
        await dependencies.deviceKeyStore.removeIncompleteKey()
        await dependencies.setupStore.clearPendingSetup()
    }

    public func lock() async {
        await dependencies.session.lock()
        state = .locked
        lastError = nil
    }
}
