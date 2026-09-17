import Foundation
import Testing
@testable import VaultCore

private struct FakeCipher: VaultCipher {
    let marker: UInt8

    func seal(_ plaintext: Data, key: Data) throws -> VaultSealedBox {
        VaultSealedBox(
            nonce: Data([marker]),
            ciphertext: Data(plaintext.reversed()),
            tag: Data([marker, 0xAA])
        )
    }

    func open(_ box: VaultSealedBox, key: Data) throws -> Data {
        guard box.tag == Data([marker, 0xAA]) else {
            throw VaultCryptoError.authenticationFailed
        }
        return Data(box.ciphertext.reversed())
    }
}

private func record(password: String = "SecretMarker-42") -> CredentialRecord {
    CredentialRecord(
        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        title: "Example",
        serviceURL: "https://example.com",
        normalizedHost: "example.com",
        username: "alice@example.test",
        password: password,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

@Test func vaultDocumentRoundTripsThroughStoreWithoutPlaintextOnDisk() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("vault.vault")
    let store = VaultFileStore(cipher: FakeCipher(marker: 7))
    let document = VaultDocument(records: [record()])

    try store.save(document, to: url, key: Data(repeating: 1, count: 32))

    let persisted = try Data(contentsOf: url)
    #expect(!String(decoding: persisted, as: UTF8.self).contains("SecretMarker-42"))
    #expect(try store.load(from: url, key: Data(repeating: 1, count: 32)) == document)
}

@Test func tamperedEnvelopeFailsClosed() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("vault.vault")
    let store = VaultFileStore(cipher: FakeCipher(marker: 9))

    try store.save(
        VaultDocument(records: [record()]),
        to: url,
        key: Data(repeating: 2, count: 32)
    )

    var envelope = try JSONDecoder().decode(VaultEnvelope.self, from: Data(contentsOf: url))
    envelope.tag = Data([0x00])
    try JSONEncoder().encode(envelope).write(to: url)

    #expect(throws: VaultCryptoError.authenticationFailed) {
        _ = try store.load(from: url, key: Data(repeating: 2, count: 32))
    }
}

@Test func failedReplacementPreservesPreviousVault() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("vault.vault")
    let store = VaultFileStore(cipher: FakeCipher(marker: 3))
    let key = Data(repeating: 3, count: 32)
    let original = VaultDocument(records: [record(password: "Original-Secret")])

    try store.save(original, to: url, key: key)
    try FileManager.default.createDirectory(
        at: url.appendingPathExtension("tmp"),
        withIntermediateDirectories: true
    )

    #expect(throws: VaultStorageError.temporaryPathIsDirectory) {
        try store.save(
            VaultDocument(records: [record(password: "New-Secret")]),
            to: url,
            key: key
        )
    }
    #expect(try store.load(from: url, key: key) == original)
}

@Test func unsupportedEnvelopeVersionFailsBeforeDecryption() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("vault.vault")
    let envelope = VaultEnvelope(
        formatVersion: 99,
        nonce: Data([1]),
        ciphertext: Data([2]),
        tag: Data([3])
    )
    try JSONEncoder().encode(envelope).write(to: url)
    let store = VaultFileStore(cipher: FakeCipher(marker: 3))

    #expect(throws: VaultCryptoError.unsupportedEnvelopeVersion(99)) {
        _ = try store.load(from: url, key: Data(repeating: 0, count: 32))
    }
}

#if canImport(CryptoKit)
@Test func aesGCMRoundTripUsesFreshNonceAndRejectsTampering() throws {
    let cipher = AESGCMVaultCipher()
    let key = VaultKey.generate()
    #expect(key.count == 32)

    let plaintext = Data("Sensitive payload".utf8)
    let first = try cipher.seal(plaintext, key: key)
    let second = try cipher.seal(plaintext, key: key)

    #expect(first.nonce != second.nonce)
    #expect(first.ciphertext != plaintext)
    #expect(try cipher.open(first, key: key) == plaintext)

    let tampered = VaultSealedBox(
        nonce: first.nonce,
        ciphertext: first.ciphertext,
        tag: Data(repeating: 0, count: first.tag.count)
    )
    #expect(throws: VaultCryptoError.authenticationFailed) {
        _ = try cipher.open(tampered, key: key)
    }
}

@Test func aesGCMRejectsWrongKeyLength() {
    let cipher = AESGCMVaultCipher()
    #expect(throws: VaultCryptoError.invalidKeyLength) {
        _ = try cipher.seal(Data("x".utf8), key: Data(repeating: 0, count: 16))
    }
}
#endif
