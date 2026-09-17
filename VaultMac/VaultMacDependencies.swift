import Foundation
import Security
import VaultAppCore
import VaultCore

private struct VaultKeyGeneratorAdapter: VaultKeyGenerating { func generateVaultKey() throws -> Data { VaultKey.generate() } }
private struct RecoveryAdapter: MasterPasswordRecovering {
    private let service = RecoveryService(kdf: SodiumArgon2IDKDF(), cipher: AESGCMVaultCipher())
    func createEnvelope(vaultKey: Data, masterPassword: String) async throws -> Data { try JSONEncoder().encode(service.createRecoveryEnvelope(vaultKey: vaultKey, masterPassword: masterPassword)) }
    func recoverVaultKey(envelope: Data, masterPassword: String) async throws -> Data { try service.recoverVaultKey(from: JSONDecoder().decode(RecoveryEnvelope.self, from: envelope), masterPassword: masterPassword) }
}
private struct EncryptedVaultStoreAdapter: EncryptedVaultStoring {
    let url: URL; private let store = VaultFileStore(cipher: AESGCMVaultCipher())
    func createEmptyVault(using key: Data) async throws { try store.save(VaultDocument(records: []), to: url, key: key) }
    func recordCount(using key: Data) async throws -> Int { try store.load(from: url, key: key).records.count }
    func removeIncompleteVault() async { let fm = FileManager.default; try? fm.removeItem(at: url); try? fm.removeItem(at: url.appendingPathExtension("tmp")); try? fm.removeItem(at: url.appendingPathExtension("bak")) }
}
private struct DeviceKeyStoreAdapter: DeviceVaultKeyStoring {
    let provider: KeychainVaultKeyProvider
    func install(_ key: Data) async throws { try provider.installNewVaultKey(key) }
    func removeIncompleteKey() async { let q: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:provider.service,kSecAttrAccount as String:provider.account]; SecItemDelete(q as CFDictionary) }
}
private struct VaultSessionAdapter: VaultSessionAccessing {
    let session: VaultSession
    func unlockWithDeviceAuthentication(reason: String) async throws { try await session.unlock(reason: reason) }
    func installVerifiedVaultKey(_ key: Data) async throws { try await session.unlock(withVaultKey: key) }
    func lock() async { await session.lock() }
    func currentVaultKey() async throws -> Data { try await session.withVaultKey { Data($0) } }
}
enum VaultMacDependencies {
    static func makeCoordinator() throws -> VaultAppCoordinator {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VaultMac", isDirectory: true)
        let config = VaultAppConfiguration(applicationSupportDirectory: base, keychainService: "com.stevewong.vaultmac")
        let files = AppFileStore(configuration: config)
        let keychain = KeychainVaultKeyProvider(service: config.keychainService, account: config.keychainAccount)
        let session = VaultSession(provider: keychain)
        return VaultAppCoordinator(dependencies: VaultAppDependencies(setupStore: files, recoveryStore: files, vaultStore: EncryptedVaultStoreAdapter(url: config.vaultURL), deviceKeyStore: DeviceKeyStoreAdapter(provider: keychain), recovery: RecoveryAdapter(), keyGenerator: VaultKeyGeneratorAdapter(), session: VaultSessionAdapter(session: session), clock: SystemVaultAppClock()))
    }
}
