import Foundation
import Testing
@testable import VaultAppCore

@Test func appFileStoreStartsIncompleteAndPersistsSetupMarker() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configuration = VaultAppConfiguration(
        applicationSupportDirectory: root,
        keychainService: "com.example.synthetic"
    )
    let store = AppFileStore(configuration: configuration)

    #expect(try await store.isSetupComplete() == false)
    try await store.markSetupComplete(SetupMetadata())
    #expect(try await store.isSetupComplete() == true)
}

@Test func appFileStoreRecoveryEnvelopeRoundTripsAndCanBeRemoved() async throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let configuration = VaultAppConfiguration(
        applicationSupportDirectory: root,
        keychainService: "com.example.synthetic"
    )
    let store = AppFileStore(configuration: configuration)
    let envelope = Data("synthetic-envelope".utf8)

    try await store.save(envelope)
    #expect(try await store.load() == envelope)
    await store.removeIncompleteRecovery()
    #expect(!FileManager.default.fileExists(atPath: configuration.recoveryURL.path))
}
