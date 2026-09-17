import Foundation

public protocol VaultKeyProvider: Sendable {
    func loadVaultKey(reason: String) async throws -> Data
}

public enum VaultSessionError: Error, Equatable, Sendable {
    case locked
    case invalidKeyLength(Int)
}

public actor VaultSession {
    private let provider: any VaultKeyProvider
    private var cachedKey: Data?

    public init(provider: any VaultKeyProvider) {
        self.provider = provider
    }

    public var isUnlocked: Bool {
        cachedKey != nil
    }

    public func unlock(reason: String) async throws {
        let key = try await provider.loadVaultKey(reason: reason)
        guard key.count == 32 else {
            throw VaultSessionError.invalidKeyLength(key.count)
        }
        cachedKey = key
    }

    public func unlock(withVaultKey key: Data) throws {
        guard key.count == 32 else {
            throw VaultSessionError.invalidKeyLength(key.count)
        }
        cachedKey = key
    }

    public func withVaultKey<Result: Sendable>(
        _ operation: @Sendable (Data) throws -> Result
    ) throws -> Result {
        guard let cachedKey else {
            throw VaultSessionError.locked
        }
        return try operation(cachedKey)
    }

    public func lock() {
        if let count = cachedKey?.count {
            cachedKey?.resetBytes(in: 0..<count)
        }
        cachedKey = nil
    }
}
