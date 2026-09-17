import Foundation

public struct SetupMetadata: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let vaultFormatVersion: Int
    public let recoveryFormatVersion: Int

    public init(
        formatVersion: Int = 1,
        vaultFormatVersion: Int = 1,
        recoveryFormatVersion: Int = 1
    ) {
        self.formatVersion = formatVersion
        self.vaultFormatVersion = vaultFormatVersion
        self.recoveryFormatVersion = recoveryFormatVersion
    }
}
