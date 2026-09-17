#if canImport(CryptoKit)
import CryptoKit
import Foundation

public struct AES256GCMVaultCipher: VaultCipher {
    public let algorithmIdentifier = "AES-256-GCM"
    private let key: SymmetricKey

    public init(keyData: Data) throws {
        guard keyData.count == 32 else { throw VaultCipherError.invalidKey }
        self.key = SymmetricKey(data: keyData)
    }

    public static func randomKeyData() -> Data {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    public func seal(_ plaintext: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else { throw VaultCipherError.authenticationFailed }
        return combined
    }

    public func open(_ sealed: Data) throws -> Data {
        do {
            return try AES.GCM.open(try AES.GCM.SealedBox(combined: sealed), using: key)
        } catch {
            throw VaultCipherError.authenticationFailed
        }
    }
}
#endif
