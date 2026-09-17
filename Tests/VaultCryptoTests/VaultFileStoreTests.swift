import Foundation
import Testing
@testable import VaultCore
@testable import VaultCrypto

private func storeFixtureDocument() -> VaultDocument {
    VaultDocument(
        version: 1,
        records: [
            CredentialRecord(
                title: "Store Fixture",
                serviceURL: "https://store.example.test",
                normalizedHost: "store.example.test",
                username: "store-user@example.test",
                password: "StorePlaintextMarker456!",
                createdAt: .distantPast,
                updatedAt: .distantPast
            )
        ]
    )
}

@Test func fileStoreSavesOnlyEncryptedBytesAndLoadsDocument() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("vault.enc")
    let key = VaultKey.generate()
    let document = storeFixtureDocument()

    try VaultFileStore.save(document, using: key, to: url)

    let bytes = try Data(contentsOf: url)
    #expect(!String(decoding: bytes, as: UTF8.self).contains("StorePlaintextMarker456!"))
    #expect(try VaultFileStore.load(using: key, from: url) == document)
}

@Test func secondSaveKeepsPreviousEncryptedCopy() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("vault.enc")
    let key = VaultKey.generate()
    var first = storeFixtureDocument()
    try VaultFileStore.save(first, using: key, to: url)
    let firstBytes = try Data(contentsOf: url)

    first.records[0].password = "ChangedSyntheticValue789!"
    try VaultFileStore.save(first, using: key, to: url)

    let previousURL = VaultFileStore.previousVersionURL(for: url)
    #expect(FileManager.default.fileExists(atPath: previousURL.path))
    #expect(try Data(contentsOf: previousURL) == firstBytes)
    #expect(try VaultFileStore.load(using: key, from: url) == first)
}

@Test func loadingTamperedFileFailsWithoutReturningPartialDocument() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("vault.enc")
    let key = VaultKey.generate()
    try VaultFileStore.save(storeFixtureDocument(), using: key, to: url)

    var envelope = try JSONDecoder().decode(EncryptedVaultEnvelope.self, from: Data(contentsOf: url))
    var tag = envelope.tag
    #require(!tag.isEmpty)
    tag[tag.startIndex] ^= 0x01
    envelope = EncryptedVaultEnvelope(
        formatVersion: envelope.formatVersion,
        algorithm: envelope.algorithm,
        nonce: envelope.nonce,
        ciphertext: envelope.ciphertext,
        tag: tag
    )
    try JSONEncoder().encode(envelope).write(to: url)

    #expect(throws: VaultCryptoError.authenticationFailed) {
        try VaultFileStore.load(using: key, from: url)
    }
}
