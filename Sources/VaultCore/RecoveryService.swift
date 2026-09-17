import Foundation

public struct RecoveryKDFParameters: Codable, Equatable, Sendable {
    public var algorithm: String
    public var opsLimit: UInt64
    public var memLimit: UInt64
    public var outputLength: Int
    public var saltLength: Int

    public init(
        algorithm: String,
        opsLimit: UInt64,
        memLimit: UInt64,
        outputLength: Int,
        saltLength: Int
    ) {
        self.algorithm = algorithm
        self.opsLimit = opsLimit
        self.memLimit = memLimit
        self.outputLength = outputLength
        self.saltLength = saltLength
    }

    public static let moderateArgon2id = RecoveryKDFParameters(
        algorithm: "argon2id13",
        opsLimit: 3,
        memLimit: 268_435_456,
        outputLength: 32,
        saltLength: 16
    )
}

public struct RecoveryEnvelope: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var kdf: RecoveryKDFParameters
    public var salt: Data
    public var nonce: Data
    public var ciphertext: Data
    public var tag: Data

    public init(
        formatVersion: Int = 1,
        kdf: RecoveryKDFParameters,
        salt: Data,
        nonce: Data,
        ciphertext: Data,
        tag: Data
    ) {
        self.formatVersion = formatVersion
        self.kdf = kdf
        self.salt = salt
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }
}

public protocol PasswordKeyDeriver: Sendable {
    var algorithmIdentifier: String { get }
    func generateSalt(length: Int) throws -> Data
    func deriveKey(
        password: Data,
        salt: Data,
        outputLength: Int,
        opsLimit: UInt64,
        memLimit: UInt64
    ) throws -> Data
}

public enum RecoveryError: Error, Equatable, Sendable {
    case unsupportedEnvelopeVersion(Int)
    case unsupportedKDF(String)
    case kdfParametersBelowMinimum
    case invalidSaltLength(Int)
    case invalidVaultKeyLength(Int)
    case invalidDerivedKeyLength(Int)
    case authenticationFailed
    case kdfParametersOutOfRange
    case kdfFailed
}

public struct RecoveryService<KDF: PasswordKeyDeriver, Cipher: VaultCipher>: Sendable {
    private let kdf: KDF
    private let cipher: Cipher
    private let minimumParameters: RecoveryKDFParameters

    public init(
        kdf: KDF,
        cipher: Cipher,
        minimumParameters: RecoveryKDFParameters = .moderateArgon2id
    ) {
        self.kdf = kdf
        self.cipher = cipher
        self.minimumParameters = minimumParameters
    }

    public func createRecoveryEnvelope(
        vaultKey: Data,
        masterPassword: String,
        parameters: RecoveryKDFParameters = .moderateArgon2id
    ) throws -> RecoveryEnvelope {
        guard vaultKey.count == 32 else {
            throw RecoveryError.invalidVaultKeyLength(vaultKey.count)
        }
        try validate(parameters: parameters)

        let salt = try kdf.generateSalt(length: parameters.saltLength)
        guard salt.count == parameters.saltLength else {
            throw RecoveryError.invalidSaltLength(salt.count)
        }

        var passwordBytes = Data(masterPassword.utf8)
        defer { passwordBytes.resetBytes(in: 0..<passwordBytes.count) }

        var wrappingKey = try kdf.deriveKey(
            password: passwordBytes,
            salt: salt,
            outputLength: parameters.outputLength,
            opsLimit: parameters.opsLimit,
            memLimit: parameters.memLimit
        )
        defer { wrappingKey.resetBytes(in: 0..<wrappingKey.count) }

        guard wrappingKey.count == 32 else {
            throw RecoveryError.invalidDerivedKeyLength(wrappingKey.count)
        }

        let sealed = try cipher.seal(vaultKey, key: wrappingKey)
        return RecoveryEnvelope(
            kdf: parameters,
            salt: salt,
            nonce: sealed.nonce,
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )
    }

    public func recoverVaultKey(
        from envelope: RecoveryEnvelope,
        masterPassword: String
    ) throws -> Data {
        guard envelope.formatVersion == 1 else {
            throw RecoveryError.unsupportedEnvelopeVersion(envelope.formatVersion)
        }
        try validate(parameters: envelope.kdf)
        guard envelope.salt.count == envelope.kdf.saltLength else {
            throw RecoveryError.invalidSaltLength(envelope.salt.count)
        }

        var passwordBytes = Data(masterPassword.utf8)
        defer { passwordBytes.resetBytes(in: 0..<passwordBytes.count) }

        var wrappingKey = try kdf.deriveKey(
            password: passwordBytes,
            salt: envelope.salt,
            outputLength: envelope.kdf.outputLength,
            opsLimit: envelope.kdf.opsLimit,
            memLimit: envelope.kdf.memLimit
        )
        defer { wrappingKey.resetBytes(in: 0..<wrappingKey.count) }

        guard wrappingKey.count == 32 else {
            throw RecoveryError.invalidDerivedKeyLength(wrappingKey.count)
        }

        do {
            let vaultKey = try cipher.open(
                VaultSealedBox(
                    nonce: envelope.nonce,
                    ciphertext: envelope.ciphertext,
                    tag: envelope.tag
                ),
                key: wrappingKey
            )
            guard vaultKey.count == 32 else {
                throw RecoveryError.invalidVaultKeyLength(vaultKey.count)
            }
            return vaultKey
        } catch VaultCryptoError.authenticationFailed {
            throw RecoveryError.authenticationFailed
        }
    }

    private func validate(parameters: RecoveryKDFParameters) throws {
        guard parameters.algorithm == kdf.algorithmIdentifier else {
            throw RecoveryError.unsupportedKDF(parameters.algorithm)
        }
        guard parameters.algorithm == minimumParameters.algorithm else {
            throw RecoveryError.unsupportedKDF(parameters.algorithm)
        }
        guard parameters.opsLimit >= minimumParameters.opsLimit,
              parameters.memLimit >= minimumParameters.memLimit,
              parameters.outputLength >= minimumParameters.outputLength,
              parameters.saltLength >= minimumParameters.saltLength else {
            throw RecoveryError.kdfParametersBelowMinimum
        }
    }
}
