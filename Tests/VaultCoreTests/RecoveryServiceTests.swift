import Foundation
import Testing
@testable import VaultCore

private struct DeterministicKDF: PasswordKeyDeriver {
    let algorithmIdentifier = "argon2id13"
    let salt: Data
    func generateSalt(length: Int) throws -> Data { Data(salt.prefix(length)) }
    func deriveKey(password: Data, salt: Data, outputLength: Int, opsLimit: UInt64, memLimit: UInt64) throws -> Data {
        var seed = Array(repeating: UInt8(0), count: outputLength)
        let material = Array(password + salt)
        for (index, byte) in material.enumerated() { seed[index % outputLength] &+= byte }
        seed[0] &+= UInt8(truncatingIfNeeded: opsLimit)
        seed[1] &+= UInt8(truncatingIfNeeded: memLimit >> 20)
        return Data(seed)
    }
}

private struct KeyedFakeCipher: VaultCipher {
    func seal(_ plaintext: Data, key: Data) throws -> VaultSealedBox {
        guard key.count == 32 else { throw VaultCryptoError.invalidKeyLength }
        let keyByte = key.reduce(0, ^)
        return VaultSealedBox(nonce: Data([0xA5]), ciphertext: Data(plaintext.map { $0 ^ keyByte }), tag: Data(key.prefix(8)))
    }
    func open(_ box: VaultSealedBox, key: Data) throws -> Data {
        guard key.count == 32 else { throw VaultCryptoError.invalidKeyLength }
        guard box.tag == Data(key.prefix(8)) else { throw VaultCryptoError.authenticationFailed }
        let keyByte = key.reduce(0, ^)
        return Data(box.ciphertext.map { $0 ^ keyByte })
    }
}

private let recoveryParameters = RecoveryKDFParameters(algorithm: "argon2id13", opsLimit: 3, memLimit: 268_435_456, outputLength: 32, saltLength: 16)
private func recoveryService() -> RecoveryService<DeterministicKDF, KeyedFakeCipher> {
    RecoveryService(kdf: DeterministicKDF(salt: Data(repeating: 7, count: 16)), cipher: KeyedFakeCipher(), minimumParameters: recoveryParameters)
}

@Test func recoveryWrapsAndRecoversSameVaultKey() throws {
    let service = recoveryService()
    let vaultKey = Data((0..<32).map(UInt8.init))
    let envelope = try service.createRecoveryEnvelope(vaultKey: vaultKey, masterPassword: "Correct Horse Battery Staple", parameters: recoveryParameters)
    #expect(envelope.formatVersion == 1)
    #expect(envelope.kdf == recoveryParameters)
    #expect(envelope.ciphertext != vaultKey)
    #expect(try service.recoverVaultKey(from: envelope, masterPassword: "Correct Horse Battery Staple") == vaultKey)
}

@Test func wrongMasterPasswordFailsClosed() throws {
    let service = recoveryService()
    let envelope = try service.createRecoveryEnvelope(vaultKey: Data(repeating: 9, count: 32), masterPassword: "correct-password", parameters: recoveryParameters)
    #expect(throws: RecoveryError.authenticationFailed) { _ = try service.recoverVaultKey(from: envelope, masterPassword: "wrong-password") }
}

@Test func tamperedRecoveryEnvelopeFailsClosed() throws {
    let service = recoveryService()
    var envelope = try service.createRecoveryEnvelope(vaultKey: Data(repeating: 3, count: 32), masterPassword: "correct-password", parameters: recoveryParameters)
    envelope.tag = Data([0, 0])
    #expect(throws: RecoveryError.authenticationFailed) { _ = try service.recoverVaultKey(from: envelope, masterPassword: "correct-password") }
}

@Test func recoveryRejectsDowngradedKDFParametersBeforeDerivation() throws {
    let service = recoveryService()
    var envelope = try service.createRecoveryEnvelope(vaultKey: Data(repeating: 4, count: 32), masterPassword: "correct-password", parameters: recoveryParameters)
    envelope.kdf = RecoveryKDFParameters(algorithm: "argon2id13", opsLimit: 2, memLimit: 67_108_864, outputLength: 32, saltLength: 16)
    #expect(throws: RecoveryError.kdfParametersBelowMinimum) { _ = try service.recoverVaultKey(from: envelope, masterPassword: "correct-password") }
}

@Test func recoveryRejectsUnsupportedKDFAlgorithm() throws {
    let service = recoveryService()
    var envelope = try service.createRecoveryEnvelope(vaultKey: Data(repeating: 5, count: 32), masterPassword: "correct-password", parameters: recoveryParameters)
    envelope.kdf.algorithm = "argon2i13"
    #expect(throws: RecoveryError.unsupportedKDF("argon2i13")) { _ = try service.recoverVaultKey(from: envelope, masterPassword: "correct-password") }
}

@Test func recoveryRejectsUnsupportedEnvelopeVersion() throws {
    let service = recoveryService()
    var envelope = try service.createRecoveryEnvelope(vaultKey: Data(repeating: 6, count: 32), masterPassword: "correct-password", parameters: recoveryParameters)
    envelope.formatVersion = 99
    #expect(throws: RecoveryError.unsupportedEnvelopeVersion(99)) { _ = try service.recoverVaultKey(from: envelope, masterPassword: "correct-password") }
}
