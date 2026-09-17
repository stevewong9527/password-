import Foundation

public struct EncryptedVaultEnvelope: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1
    public static let aes256GCMAlgorithm = "AES-256-GCM"

    public let formatVersion: Int
    public let algorithm: String
    public let nonce: Data
    public let ciphertext: Data
    public let tag: Data

    public init(
        formatVersion: Int = EncryptedVaultEnvelope.currentFormatVersion,
        algorithm: String = EncryptedVaultEnvelope.aes256GCMAlgorithm,
        nonce: Data,
        ciphertext: Data,
        tag: Data
    ) {
        self.formatVersion = formatVersion
        self.algorithm = algorithm
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }
}
