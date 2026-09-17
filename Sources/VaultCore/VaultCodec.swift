import Foundation

public struct VaultCodec<Cipher: VaultCipher>: Sendable {
    public let cipher: Cipher

    public init(cipher: Cipher) { self.cipher = cipher }

    public func encode(_ document: VaultDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let plaintext = try encoder.encode(document)
        let sealed = try cipher.seal(plaintext)
        let envelope = VaultEnvelope(
            formatVersion: VaultDocument.currentVersion,
            algorithm: cipher.algorithmIdentifier,
            sealedPayload: sealed
        )
        return try encoder.encode(envelope)
    }

    public func decode(_ data: Data) throws -> VaultDocument {
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(VaultEnvelope.self, from: data)
        guard envelope.formatVersion == VaultDocument.currentVersion else {
            throw VaultCodecError.unsupportedVersion(envelope.formatVersion)
        }
        guard envelope.algorithm == cipher.algorithmIdentifier else {
            throw VaultCipherError.unsupportedAlgorithm(envelope.algorithm)
        }
        let plaintext = try cipher.open(envelope.sealedPayload)
        let document = try decoder.decode(VaultDocument.self, from: plaintext)
        guard document.formatVersion == VaultDocument.currentVersion else {
            throw VaultCodecError.unsupportedVersion(document.formatVersion)
        }
        return document
    }
}

public enum VaultCodecError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
}
