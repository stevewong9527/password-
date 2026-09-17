import Foundation

public enum AppFileStoreError: Error, Equatable, Sendable {
    case unsupportedSetupVersion(Int)
}

public actor AppFileStore: SetupStatusStoring, RecoveryEnvelopeStoring {
    private let configuration: VaultAppConfiguration
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(configuration: VaultAppConfiguration) {
        self.configuration = configuration
    }

    public func isSetupComplete() async throws -> Bool {
        guard FileManager.default.fileExists(atPath: configuration.setupURL.path) else {
            return false
        }
        let data = try Data(contentsOf: configuration.setupURL)
        let metadata = try decoder.decode(SetupMetadata.self, from: data)
        guard metadata.formatVersion == 1 else {
            throw AppFileStoreError.unsupportedSetupVersion(metadata.formatVersion)
        }
        return true
    }

    public func markSetupComplete(_ metadata: SetupMetadata) async throws {
        try ensureDirectory()
        let data = try encoder.encode(metadata)
        try data.write(to: configuration.setupURL, options: [.atomic])
    }

    public func save(_ envelope: Data) async throws {
        try ensureDirectory()
        try envelope.write(to: configuration.recoveryURL, options: [.atomic])
    }

    public func load() async throws -> Data {
        try Data(contentsOf: configuration.recoveryURL)
    }

    public func removeIncompleteRecovery() async {
        try? FileManager.default.removeItem(at: configuration.recoveryURL)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: configuration.applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }
}
