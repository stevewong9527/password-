import Foundation
import Testing
@testable import VaultCore

private struct ScaleTestCipher: VaultCipher {
    private let marker = Data([0x44])

    func seal(_ plaintext: Data, key: Data) throws -> VaultSealedBox {
        VaultSealedBox(
            nonce: marker,
            ciphertext: Data(plaintext.reversed()),
            tag: Data([0x55])
        )
    }

    func open(_ box: VaultSealedBox, key: Data) throws -> Data {
        guard box.tag == Data([0x55]) else {
            throw VaultCryptoError.authenticationFailed
        }
        return Data(box.ciphertext.reversed())
    }
}

private func scaleRecord(index: Int) -> CredentialRecord {
    CredentialRecord(
        id: UUID(),
        title: "Synthetic \(index)",
        serviceURL: "https://host\(index).example.test/login",
        normalizedHost: "host\(index).example.test",
        username: "user\(index)@example.test",
        password: "SyntheticPassword-\(index)!",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
}

@Test func emptyVaultRoundTrips() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("vault.vault")
    let store = VaultFileStore(cipher: ScaleTestCipher())
    let document = VaultDocument(records: [])

    try store.save(document, to: url, key: Data(repeating: 1, count: 32))

    #expect(try store.load(from: url, key: Data(repeating: 1, count: 32)) == document)
}

@Test func largeSyntheticVaultRoundTrips() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("vault.vault")
    let store = VaultFileStore(cipher: ScaleTestCipher())
    let document = VaultDocument(records: (0..<5_000).map(scaleRecord))

    try store.save(document, to: url, key: Data(repeating: 2, count: 32))

    let loaded = try store.load(from: url, key: Data(repeating: 2, count: 32))
    #expect(loaded.records.count == 5_000)
    #expect(loaded == document)
}

#if canImport(CryptoKit)
@Test func repeatedEncryptedSavesOfSameDocumentUseDifferentNonceAndCiphertext() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let firstURL = directory.appendingPathComponent("first.vault")
    let secondURL = directory.appendingPathComponent("second.vault")
    let store = VaultFileStore(cipher: AESGCMVaultCipher())
    let key = VaultKey.generate()
    let document = VaultDocument(records: [scaleRecord(index: 1)])

    try store.save(document, to: firstURL, key: key)
    try store.save(document, to: secondURL, key: key)

    let decoder = JSONDecoder()
    let first = try decoder.decode(VaultEnvelope.self, from: Data(contentsOf: firstURL))
    let second = try decoder.decode(VaultEnvelope.self, from: Data(contentsOf: secondURL))

    #expect(first.nonce != second.nonce)
    #expect(first.ciphertext != second.ciphertext)
}
#endif
