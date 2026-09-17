#if canImport(Sodium)
import Foundation
import Testing
@testable import VaultCore

@Test func sodiumArgon2IDDerivesStable32ByteKeyForFixedInputs() throws {
    let kdf = SodiumArgon2IDKDF()
    let salt = Data((0..<16).map(UInt8.init))
    let password = Data("correct horse battery staple".utf8)
    let first = try kdf.deriveKey(password: password, salt: salt, outputLength: 32, opsLimit: 2, memLimit: 67_108_864)
    let second = try kdf.deriveKey(password: password, salt: salt, outputLength: 32, opsLimit: 2, memLimit: 67_108_864)
    #expect(first.count == 32)
    #expect(first == second)
    #expect(first != Data(repeating: 0, count: 32))
}

@Test func sodiumArgon2IDDifferentPasswordProducesDifferentKey() throws {
    let kdf = SodiumArgon2IDKDF()
    let salt = Data((0..<16).map(UInt8.init))
    let first = try kdf.deriveKey(password: Data("password-a".utf8), salt: salt, outputLength: 32, opsLimit: 2, memLimit: 67_108_864)
    let second = try kdf.deriveKey(password: Data("password-b".utf8), salt: salt, outputLength: 32, opsLimit: 2, memLimit: 67_108_864)
    #expect(first != second)
}

@Test func sodiumArgon2IDGeneratesRequiredSaltLength() throws {
    let kdf = SodiumArgon2IDKDF()
    let first = try kdf.generateSalt(length: 16)
    let second = try kdf.generateSalt(length: 16)
    #expect(first.count == 16)
    #expect(second.count == 16)
    #expect(first != second)
}

#if canImport(CryptoKit)
@Test func productionRecoveryRoundTripUsesArgon2IDAndAESGCM() throws {
    let parameters = RecoveryKDFParameters(algorithm: "argon2id13", opsLimit: 2, memLimit: 67_108_864, outputLength: 32, saltLength: 16)
    let service = RecoveryService(kdf: SodiumArgon2IDKDF(), cipher: AESGCMVaultCipher(), minimumParameters: parameters)
    let vaultKey = Data((0..<32).map(UInt8.init))
    let envelope = try service.createRecoveryEnvelope(vaultKey: vaultKey, masterPassword: "test-master-password", parameters: parameters)
    #expect(envelope.ciphertext != vaultKey)
    #expect(try service.recoverVaultKey(from: envelope, masterPassword: "test-master-password") == vaultKey)
    #expect(throws: RecoveryError.authenticationFailed) { _ = try service.recoverVaultKey(from: envelope, masterPassword: "wrong") }
}
#endif
#endif
