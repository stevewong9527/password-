import Foundation
import Testing
@testable import VaultCore
@testable import VaultCrypto

private func fixtureDocument() -> VaultDocument {
    VaultDocument(
        version: 1,
        records: [
            CredentialRecord(
                title: "Example",
                serviceURL: "https://example.com",
                normalizedHost: "example.com",
                username: "alice@example.test",
                password: "KnownPlaintextMarker123!",
                notes: "synthetic fixture",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        ]
    )
}

@Test func generatedVaultKeyContains256Bits() throws {
    let key = VaultKey.generate()
    #expect(key.rawRepresentation.count == 32)
}

@Test func sealedVaultRoundTrips() throws {
    let key = VaultKey.generate()
    let document = fixtureDocument()

    let encrypted = try VaultCipher.seal(document, using: key)
    let opened = try VaultCipher.open(encrypted, using: key)

    #expect(opened == document)
}

@Test func persistedEnvelopeDoesNotContainKnownPlaintext() throws {
    let key = VaultKey.generate()
    let encrypted = try VaultCipher.seal(fixtureDocument(), using: key)
    let bytes = String(decoding: encrypted, as: UTF8.self)

    #expect(!bytes.contains("KnownPlaintextMarker123!"))
    #expect(!bytes.contains("alice@example.test"))
    #expect(!bytes.contains("example.com"))
}

@Test func repeatedSealsUseDifferentNoncesAndCiphertext() throws {
    let key = VaultKey.generate()
    let document = fixtureDocument()

    let first = try VaultCipher.seal(document, using: key)
    let second = try VaultCipher.seal(document, using: key)

    #expect(first != second)
}

@Test func tamperedCiphertextFailsClosed() throws {
    let key = VaultKey.generate()
    let encrypted = try VaultCipher.seal(fixtureDocument(), using: key)
    var envelope = try JSONDecoder().decode(EncryptedVaultEnvelope.self, from: encrypted)
    var ciphertext = envelope.ciphertext
    #require(!ciphertext.isEmpty)
    ciphertext[0] ^= 0x01
    envelope = EncryptedVaultEnvelope(
        formatVersion: envelope.formatVersion,
        algorithm: envelope.algorithm,
        nonce: envelope.nonce,
        ciphertext: ciphertext,
        tag: envelope.tag
    )
    let tampered = try JSONEncoder().encode(envelope)

    #expect(throws: VaultCryptoError.authenticationFailed) {
        try VaultCipher.open(tampered, using: key)
    }
}

@Test func wrongKeyFailsClosed() throws {
    let encrypted = try VaultCipher.seal(fixtureDocument(), using: .generate())

    #expect(throws: VaultCryptoError.authenticationFailed) {
        try VaultCipher.open(encrypted, using: .generate())
    }
}

@Test func unsupportedEnvelopeVersionIsRejectedBeforeDecryption() throws {
    let key = VaultKey.generate()
    let encrypted = try VaultCipher.seal(fixtureDocument(), using: key)
    let decoded = try JSONDecoder().decode(EncryptedVaultEnvelope.self, from: encrypted)
    let unsupported = EncryptedVaultEnvelope(
        formatVersion: 999,
        algorithm: decoded.algorithm,
        nonce: decoded.nonce,
        ciphertext: decoded.ciphertext,
        tag: decoded.tag
    )

    let data = try JSONEncoder().encode(unsupported)
    #expect(throws: VaultCryptoError.unsupportedFormatVersion(999)) {
        try VaultCipher.open(data, using: key)
    }
}
