import Foundation
import Testing
@testable import VaultCore

private actor StubVaultKeyProvider: VaultKeyProvider {
    private let key: Data
    private(set) var loadCount = 0

    init(key: Data) {
        self.key = key
    }

    func loadVaultKey(reason: String) async throws -> Data {
        loadCount += 1
        return key
    }
}

@Test func lockedSessionCannotReleaseVaultKey() async {
    let provider = StubVaultKeyProvider(key: Data(repeating: 1, count: 32))
    let session = VaultSession(provider: provider)

    do {
        _ = try await session.withVaultKey { $0.count }
        Issue.record("locked session unexpectedly released key material")
    } catch let error as VaultSessionError {
        #expect(error == .locked)
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}

@Test func unlockCachesValidatedVaultKeyUntilExplicitLock() async throws {
    let expected = Data(repeating: 7, count: 32)
    let provider = StubVaultKeyProvider(key: expected)
    let session = VaultSession(provider: provider)

    try await session.unlock(reason: "Unlock synthetic test vault")
    #expect(try await session.withVaultKey { $0 } == expected)
    #expect(try await session.withVaultKey { $0 } == expected)
    #expect(await provider.loadCount == 1)

    await session.lock()
    #expect(await session.isUnlocked == false)

    do {
        _ = try await session.withVaultKey { $0.count }
        Issue.record("locked session unexpectedly retained usable key material")
    } catch let error as VaultSessionError {
        #expect(error == .locked)
    }
}

@Test func unlockRejectsUnexpectedKeyLength() async {
    let provider = StubVaultKeyProvider(key: Data(repeating: 0, count: 16))
    let session = VaultSession(provider: provider)

    do {
        try await session.unlock(reason: "Unlock synthetic test vault")
        Issue.record("session accepted an invalid vault key length")
    } catch let error as VaultSessionError {
        #expect(error == .invalidKeyLength(16))
    } catch {
        Issue.record("unexpected error: \(error)")
    }

    #expect(await session.isUnlocked == false)
}

#if os(macOS)
@Test func keychainProviderRejectsInvalidKeyLengthBeforeKeychainAccess() {
    let provider = KeychainVaultKeyProvider(service: "com.example.password-manager.tests")
    #expect(throws: KeychainVaultKeyProviderError.invalidKeyLength(16)) {
        try provider.installNewVaultKey(Data(repeating: 0, count: 16))
    }
}
#endif
