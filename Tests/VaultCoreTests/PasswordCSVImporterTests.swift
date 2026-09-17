import Foundation
import Testing
@testable import VaultCore

@Test func importerAcceptsGoogleCompatibleHeadersAndExtraColumns() throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let csv = "name,url,username,password,note\nExample,https://www.Example.com/login,alice@example.test,ExampleValue123!,hello"

    let preview = try PasswordCSVImporter.importCSV(csv, now: now)

    #expect(preview.issues.isEmpty)
    #expect(preview.credentials.count == 1)
    let record = try #require(preview.credentials.first?.credential)
    #expect(record.title == "Example")
    #expect(record.normalizedHost == "example.com")
    #expect(record.username == "alice@example.test")
    #expect(record.password == "ExampleValue123!")
    #expect(record.notes == "hello")
    #expect(record.createdAt == now)
}

@Test func importerNormalizesHeaderCaseAndWhitespace() throws {
    let csv = " URL , UserName , PASSWORD \nhttps://example.com,alice,ExampleValue123!"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.count == 1)
    #expect(preview.issues.isEmpty)
}

@Test func importerAcceptsSupportedWebsiteAndLoginAliases() throws {
    let csv = "Title,Website,Login,Password,Notes\nExample,https://example.com,alice,ExampleValue123!,fixture"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.count == 1)
    #expect(preview.issues.isEmpty)
    #expect(preview.credentials[0].credential.title == "Example")
}

@Test func importerAcceptsCurrentApplePasswordsHeaders() throws {
    let csv = "Title,URL,Username,Password,Notes,OTPAuth\nExample,https://example.com,alice,ExampleValue123!,fixture,"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.count == 1)
    #expect(preview.issues.isEmpty)
    #expect(preview.credentials[0].credential.title == "Example")
    #expect(preview.credentials[0].credential.normalizedHost == "example.com")
    #expect(preview.credentials[0].credential.notes == "fixture")
}

@Test func importerRejectsMissingRequiredHeaderWithoutIncludingSecrets() {
    let csv = "url,username\nhttps://example.com,alice"
    #expect(throws: PasswordCSVImportError.missingRequiredHeaders(["password"])) {
        try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    }
}

@Test func importerReturnsRowLevelIssueForInvalidURLWithoutSecretContent() throws {
    let marker = "PrivateMarker99!"
    let csv = "url,username,password\nnot a host value,alice,\(marker)"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.isEmpty)
    #expect(preview.issues.count == 1)
    #expect(preview.issues[0].reason == .invalidURL)
    #expect(!String(describing: preview.issues[0]).contains(marker))
}

@Test func importerAcceptsUTF8BOMOnFirstHeader() throws {
    let csv = "\u{FEFF}url,username,password\nhttps://example.com,alice,ExampleValue123!"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.count == 1)
    #expect(preview.issues.isEmpty)
}

@Test func importerFlagsMissingPasswordWithoutEchoingRow() throws {
    let csv = "url,username,password\nhttps://example.com,alice,"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.isEmpty)
    #expect(preview.issues == [ImportRowIssue(rowNumber: 2, reason: .missingPassword)])
}

@Test func importerFlagsExtraColumnsAsMalformedRow() throws {
    let csv = "url,username,password\nhttps://example.com,alice,ExampleValue123!,unexpected"
    let preview = try PasswordCSVImporter.importCSV(csv, now: .distantPast)
    #expect(preview.credentials.isEmpty)
    #expect(preview.issues == [ImportRowIssue(rowNumber: 2, reason: .columnCountMismatch)])
}
