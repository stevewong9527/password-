import CryptoKit
import Foundation
import VaultCore

public enum VaultCipher {
    public static func seal(_ document: VaultDocument, using key: VaultKey) throws -> Data {
        let plaintext = try JSONEncoder().encode(document)
        let sealedBox = try AES.GCM.seal(plaintext, using: key.symmetricKey)
        let nonce = sealedBox.nonce.withUnsafeBytes { Data($0) }

        let envelope = EncryptedVaultEnvelope(
            nonce: nonce,
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag
        )
        return try JSONEncoder().encode(envelope)
    }

    public static func open(_ encryptedData: Data, using key: VaultKey) throws -> VaultDocument {
        let envelope: EncryptedVaultEnvelope
        do {
            envelope = try JSONDecoder().decode(EncryptedVaultEnvelope.self, from: encryptedData)
        } catch {
            throw VaultCryptoError.invalidEnvelope
        }

        guard envelope.formatVersion == EncryptedVaultEnvelope.currentFormatVersion else {
            throw VaultCryptoError.unsupportedFormatVersion(envelope.formatVersion)
        }
        guard envelope.algorithm == EncryptedVaultEnvelope.aes256GCMAlgorithm else {
            throw VaultCryptoError.unsupportedAlgorithm(envelope.algorithm)
        }

        let nonce: AES.GCM.Nonce
        let sealedBox: AES.GCM.SealedBox
        do {
            nonce = try AES.GCM.Nonce(data: envelope.nonce)
            sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: envelope.ciphertext,
                tag: envelope.tag
            )
        } catch {
            throw VaultCryptoError.invalidEnvelope
        }

        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(sealedBox, using: key.symmetricKey)
        } catch {
            throw VaultCryptoError.authenticationFailed
        }

        let document: VaultDocument
        do {
            document = try JSONDecoder().decode(VaultDocument.self, from: plaintext)
        } catch {
            throw VaultCryptoError.invalidVaultPayload
        }

        guard document.version == VaultDocument.currentVersion else {
            throw VaultCryptoError.unsupportedDocumentVersion(document.version)
        }
        return document
    }
}
