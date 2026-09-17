import Foundation

public struct VaultDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public let formatVersion: Int
    public var records: [CredentialRecord]

    public init(formatVersion: Int = Self.currentVersion, records: [CredentialRecord]) {
        self.formatVersion = formatVersion
        self.records = records
    }
}

public struct VaultEnvelope: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let algorithm: String
    public let sealedPayload: Data

    public init(formatVersion: Int, algorithm: String, sealedPayload: Data) {
        self.formatVersion = formatVersion
        self.algorithm = algorithm
        self.sealedPayload = sealedPayload
    }
}
