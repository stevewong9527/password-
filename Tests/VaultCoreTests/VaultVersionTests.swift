import Foundation
import Testing
@testable import VaultCore

private struct VersionTestCipher: VaultCipher {
    func seal(_ plaintext: Data, key: Data) throws -> VaultSealedBox {
        VaultSealedBox(nonce: Data([1]), ciphertext: plaintext, tag: Data([2]))
    }

    func open(_ box: VaultSealedBox, key: Data) throws -> Data {
        box.ciphertext
    }
}

@Test func unsupportedDocumentVersionFailsAfterAuthentication() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let url = dir.appendingPathComponent("vault.vault")
    let store = VaultFileStore(cipher: VersionTestCipher())
    try store.save(VaultDocument(version: 99, records: []), to: url, key: Data(repeating: 1, count: 32))

    #expect(throws: VaultCryptoError.unsupportedDocumentVersion(99)) {
        _ = try store.load(from: url, key: Data(repeating: 1, count: 32))
    }
}
