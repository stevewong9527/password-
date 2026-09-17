import Foundation

public enum VaultCryptoError: Error, Equatable, Sendable {
    case invalidKeyLength
    case invalidEnvelope
    case unsupportedFormatVersion(Int)
    case unsupportedAlgorithm(String)
    case authenticationFailed
    case invalidVaultPayload
    case unsupportedDocumentVersion(Int)
}
