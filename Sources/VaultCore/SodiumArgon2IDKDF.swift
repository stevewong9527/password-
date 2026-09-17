#if canImport(Sodium)
import Foundation
import Sodium

public struct SodiumArgon2IDKDF: PasswordKeyDeriver {
    public let algorithmIdentifier = "argon2id13"

    public init() {}

    public func generateSalt(length: Int) throws -> Data {
        let sodium = Sodium()
        guard length == sodium.pwHash.SaltBytes,
              let bytes = sodium.randomBytes.buf(length: length) else {
            throw RecoveryError.invalidSaltLength(length)
        }
        return Data(bytes)
    }

    public func deriveKey(
        password: Data,
        salt: Data,
        outputLength: Int,
        opsLimit: UInt64,
        memLimit: UInt64
    ) throws -> Data {
        let sodium = Sodium()
        guard salt.count == sodium.pwHash.SaltBytes else {
            throw RecoveryError.invalidSaltLength(salt.count)
        }
        guard opsLimit <= UInt64(Int.max), memLimit <= UInt64(Int.max) else {
            throw RecoveryError.kdfParametersOutOfRange
        }
        guard let bytes = sodium.pwHash.hash(
            outputLength: outputLength,
            passwd: Array(password),
            salt: Array(salt),
            opsLimit: Int(opsLimit),
            memLimit: Int(memLimit),
            alg: .Argon2ID13
        ) else {
            throw RecoveryError.kdfFailed
        }
        return Data(bytes)
    }
}
#endif
