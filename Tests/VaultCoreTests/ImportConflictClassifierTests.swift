import Foundation
import Testing
@testable import VaultCore

private func record(host: String, username: String, password: String) -> CredentialRecord {
    CredentialRecord(
        id: UUID(),
        title: "Fixture",
        serviceURL: "https://\(host)",
        normalizedHost: host,
        username: username,
        password: password,
        notes: nil,
        createdAt: .distantPast,
        updatedAt: .distantPast
    )
}

@Test func classifierMarksSameKeyAndPasswordDuplicate() {
    let existing = record(host: "example.com", username: " Alice@Example.Test ", password: "same")
    let imported = record(host: "example.com", username: "alice@example.test", password: "same")
    #expect(ImportConflictClassifier.classify(existing: existing, imported: imported) == .duplicate)
}

@Test func classifierMarksSameKeyDifferentPasswordConflict() {
    let existing = record(host: "example.com", username: "alice", password: "old")
    let imported = record(host: "example.com", username: "ALICE", password: "new")
    #expect(ImportConflictClassifier.classify(existing: existing, imported: imported) == .conflict)
}

@Test func classifierKeepsDifferentHostOrUsernameDistinct() {
    let existing = record(host: "accounts.example.com", username: "alice", password: "same")
    let differentHost = record(host: "example.com", username: "alice", password: "same")
    let differentUser = record(host: "accounts.example.com", username: "bob", password: "same")

    #expect(ImportConflictClassifier.classify(existing: existing, imported: differentHost) == .distinct)
    #expect(ImportConflictClassifier.classify(existing: existing, imported: differentUser) == .distinct)
}
