import Foundation

public struct VaultAppConfiguration: Equatable, Sendable {
    public let applicationSupportDirectory: URL
    public let keychainService: String
    public let keychainAccount: String

    public init(
        applicationSupportDirectory: URL,
        keychainService: String,
        keychainAccount: String = "primary-vault-key"
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
    }

    public var vaultURL: URL { applicationSupportDirectory.appendingPathComponent("vault.vault") }
    public var recoveryURL: URL { applicationSupportDirectory.appendingPathComponent("recovery.json") }
    public var setupURL: URL { applicationSupportDirectory.appendingPathComponent("setup.json") }
    public var pendingSetupURL: URL { applicationSupportDirectory.appendingPathComponent("setup.pending") }
}
