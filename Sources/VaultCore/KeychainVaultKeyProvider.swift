#if os(macOS) && canImport(Security) && canImport(LocalAuthentication)
import Foundation
import LocalAuthentication
import Security

public enum KeychainVaultKeyProviderError: Error, Equatable, Sendable {
    case invalidKeyLength(Int)
    case accessControlCreationFailed
    case itemAlreadyExists
    case itemNotFound
    case unexpectedData
    case keychainStatus(OSStatus)
}

public struct KeychainVaultKeyProvider: VaultKeyProvider, Sendable {
    public let service: String
    public let account: String

    public init(service: String, account: String = "primary-vault-key") {
        self.service = service
        self.account = account
    }

    public func installNewVaultKey(_ key: Data) throws {
        guard key.count == 32 else {
            throw KeychainVaultKeyProviderError.invalidKeyLength(key.count)
        }

        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &accessError
        ) else {
            throw KeychainVaultKeyProviderError.accessControlCreationFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: accessControl,
            kSecValueData as String: key
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            throw KeychainVaultKeyProviderError.itemAlreadyExists
        }
        guard status == errSecSuccess else {
            throw KeychainVaultKeyProviderError.keychainStatus(status)
        }
    }

    public func loadVaultKey(reason: String) async throws -> Data {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            throw KeychainVaultKeyProviderError.itemNotFound
        }
        guard status == errSecSuccess else {
            throw KeychainVaultKeyProviderError.keychainStatus(status)
        }
        guard let key = result as? Data else {
            throw KeychainVaultKeyProviderError.unexpectedData
        }
        guard key.count == 32 else {
            throw KeychainVaultKeyProviderError.invalidKeyLength(key.count)
        }
        return key
    }
}
#endif
