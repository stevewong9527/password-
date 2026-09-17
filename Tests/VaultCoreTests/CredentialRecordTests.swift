import Foundation
import Testing
@testable import VaultCore

@Test func credentialRecordCodableRoundTrip() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let original = CredentialRecord(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Example",
        serviceURL: "https://example.com/login",
        normalizedHost: "example.com",
        username: "alice@example.test",
        password: "Synthetic-Only-Password-1!",
        notes: "fixture",
        createdAt: now,
        updatedAt: now
    )

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CredentialRecord.self, from: data)

    #expect(decoded == original)
}
