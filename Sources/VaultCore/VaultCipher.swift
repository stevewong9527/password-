import Foundation

public protocol VaultCipher: Sendable {
    var algorithmIdentifier: String { get }
    func seal(_ plaintext: Data) throws -> Data
    func open(_ sealed: Data) throws -> Data
}

public extension VaultCipher {
    var algorithmIdentifier: String { "TEST-OR-PLATFORM-CIPHER" }
}

public enum VaultCipherError: Error, Equatable, Sendable {
    case authenticationFailed
    case invalidKey
    case unsupportedAlgorithm(String)
}
