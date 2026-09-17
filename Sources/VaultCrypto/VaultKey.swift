import CryptoKit
import Foundation

public struct VaultKey: Equatable, Sendable {
    public static let byteCount = 32

    public let rawRepresentation: Data

    public init(rawRepresentation: Data) throws {
        guard rawRepresentation.count == Self.byteCount else {
            throw VaultCryptoError.invalidKeyLength
        }
        self.rawRepresentation = rawRepresentation
    }

    public static func generate() -> VaultKey {
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        return VaultKey(uncheckedRawRepresentation: data)
    }

    internal var symmetricKey: SymmetricKey {
        SymmetricKey(data: rawRepresentation)
    }

    private init(uncheckedRawRepresentation: Data) {
        self.rawRepresentation = uncheckedRawRepresentation
    }
}
