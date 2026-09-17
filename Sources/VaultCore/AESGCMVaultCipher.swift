#if canImport(CryptoKit)
import CryptoKit
import Foundation

public struct AESGCMVaultCipher: VaultCipher {
    public init() {}

    public func seal(_ plaintext: Data, key: Data) throws -> VaultSealedBox {
        guard key.count == 32 else { throw VaultCryptoError.invalidKeyLength }
        let symmetricKey = SymmetricKey(data: key)
        let sealed = try AES.GCM.seal(plaintext, using: symmetricKey)
        return VaultSealedBox(
            nonce: Data(sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )
    }

    public func open(_ box: VaultSealedBox, key: Data) throws -> Data {
        guard key.count == 32 else { throw VaultCryptoError.invalidKeyLength }
        let symmetricKey = SymmetricKey(data: key)
        do {
            let nonce = try AES.GCM.Nonce(data: box.nonce)
            let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: box.ciphertext, tag: box.tag)
            return try AES.GCM.open(sealed, using: symmetricKey)
        } catch {
            throw VaultCryptoError.authenticationFailed
        }
    }
}

public enum VaultKey {
    public static func generate() -> Data {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }
}
#endif
