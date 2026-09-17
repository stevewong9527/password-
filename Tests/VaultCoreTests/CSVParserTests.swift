import Testing
@testable import VaultCore

@Test func csvParserParsesSimpleRows() throws {
    let rows = try CSVParser.parse("url,username,password\nhttps://example.com,alice,pw")
    #expect(rows == [["url", "username", "password"], ["https://example.com", "alice", "pw"]])
}

@Test func csvParserHandlesQuotedCommaAndEscapedQuote() throws {
    let rows = try CSVParser.parse("name,note\n\"Example, Inc.\",\"said \"\"hello\"\"\"")
    #expect(rows == [["name", "note"], ["Example, Inc.", "said \"hello\""]])
}

@Test func csvParserHandlesCRLFAndMultilineField() throws {
    let input = "name,note\r\nExample,\"line one\r\nline two\"\r\n"
    let rows = try CSVParser.parse(input)
    #expect(rows == [["name", "note"], ["Example", "line one\r\nline two"]])
}

@Test func csvParserRejectsUnterminatedQuotedField() {
    #expect(throws: CSVParserError.unterminatedQuotedField) {
        try CSVParser.parse("name,note\nExample,\"secret")
    }
}
