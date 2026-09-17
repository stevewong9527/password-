import Foundation

public struct VaultDocument: Codable, Equatable, Sendable {
    public var version: Int
    public var records: [CredentialRecord]

    public init(version: Int = 1, records: [CredentialRecord]) {
        self.version = version
        self.records = records
    }
}

public struct VaultSealedBox: Codable, Equatable, Sendable {
    public let nonce: Data
    public let ciphertext: Data
    public var tag: Data

    public init(nonce: Data, ciphertext: Data, tag: Data) {
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }
}

public struct VaultEnvelope: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let nonce: Data
    public let ciphertext: Data
    public var tag: Data

    public init(formatVersion: Int = 1, nonce: Data, ciphertext: Data, tag: Data) {
        self.formatVersion = formatVersion
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }
}

public enum VaultCryptoError: Error, Equatable, Sendable {
    case authenticationFailed
    case invalidKeyLength
    case unsupportedEnvelopeVersion(Int)
}

public enum VaultStorageError: Error, Equatable, Sendable {
    case temporaryPathIsDirectory
}

public protocol VaultCipher: Sendable {
    func seal(_ plaintext: Data, key: Data) throws -> VaultSealedBox
    func open(_ box: VaultSealedBox, key: Data) throws -> Data
}

public struct VaultFileStore<Cipher: VaultCipher>: Sendable {
    private let cipher: Cipher
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(cipher: Cipher) {
        self.cipher = cipher
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func save(_ document: VaultDocument, to url: URL, key: Data) throws {
        let plaintext = try encoder.encode(document)
        let sealed = try cipher.seal(plaintext, key: key)
        let envelope = VaultEnvelope(nonce: sealed.nonce, ciphertext: sealed.ciphertext, tag: sealed.tag)
        let encodedEnvelope = try encoder.encode(envelope)

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = url.appendingPathExtension("tmp")
        let backupURL = url.appendingPathExtension("bak")

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: temporaryURL.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else { throw VaultStorageError.temporaryPathIsDirectory }
            try FileManager.default.removeItem(at: temporaryURL)
        }
        try encodedEnvelope.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.moveItem(at: url, to: backupURL)
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: url)
            } catch {
                try? FileManager.default.moveItem(at: backupURL, to: url)
                throw error
            }
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: url)
        }
    }

    public func load(from url: URL, key: Data) throws -> VaultDocument {
        let data = try Data(contentsOf: url)
        let envelope = try decoder.decode(VaultEnvelope.self, from: data)
        guard envelope.formatVersion == 1 else {
            throw VaultCryptoError.unsupportedEnvelopeVersion(envelope.formatVersion)
        }
        let plaintext = try cipher.open(
            VaultSealedBox(nonce: envelope.nonce, ciphertext: envelope.ciphertext, tag: envelope.tag),
            key: key
        )
        return try decoder.decode(VaultDocument.self, from: plaintext)
    }
}
