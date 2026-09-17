import Foundation

public struct VaultDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var records: [CredentialRecord]

    public init(
        version: Int = VaultDocument.currentVersion,
        records: [CredentialRecord]
    ) {
        self.version = version
        self.records = records
    }
}
