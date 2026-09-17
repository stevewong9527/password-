import Foundation

public enum ImportIssueReason: String, Equatable, Sendable {
    case columnCountMismatch
    case invalidURL
    case missingPassword
}

public struct ImportRowIssue: Equatable, Sendable {
    public let rowNumber: Int
    public let reason: ImportIssueReason

    public init(rowNumber: Int, reason: ImportIssueReason) {
        self.rowNumber = rowNumber
        self.reason = reason
    }
}

public struct ImportedCredential: Equatable, Sendable {
    public let rowNumber: Int
    public let credential: CredentialRecord

    public init(rowNumber: Int, credential: CredentialRecord) {
        self.rowNumber = rowNumber
        self.credential = credential
    }
}

public struct ImportPreview: Equatable, Sendable {
    public let credentials: [ImportedCredential]
    public let issues: [ImportRowIssue]

    public init(credentials: [ImportedCredential], issues: [ImportRowIssue]) {
        self.credentials = credentials
        self.issues = issues
    }
}

public enum PasswordCSVImportError: Error, Equatable, Sendable {
    case emptyFile
    case missingRequiredHeaders([String])
    case malformedCSV(CSVParserError)
}

public enum PasswordCSVImporter {
    private static let urlAliases = ["url", "website", "website address", "website url"]
    private static let usernameAliases = ["username", "user name", "login"]
    private static let passwordAliases = ["password"]
    private static let titleAliases = ["name", "title"]
    private static let notesAliases = ["note", "notes"]

    public static func importCSV(_ text: String, now: Date = Date()) throws -> ImportPreview {
        let rows: [[String]]
        do {
            rows = try CSVParser.parse(text)
        } catch let error as CSVParserError {
            throw PasswordCSVImportError.malformedCSV(error)
        }

        guard let rawHeaders = rows.first, !rawHeaders.isEmpty else {
            throw PasswordCSVImportError.emptyFile
        }

        let headers = rawHeaders.map(normalizeHeader)
        let urlIndex = firstIndex(in: headers, aliases: urlAliases)
        let usernameIndex = firstIndex(in: headers, aliases: usernameAliases)
        let passwordIndex = firstIndex(in: headers, aliases: passwordAliases)
        let titleIndex = firstIndex(in: headers, aliases: titleAliases)
        let notesIndex = firstIndex(in: headers, aliases: notesAliases)

        var missing: [String] = []
        if urlIndex == nil { missing.append("url") }
        if usernameIndex == nil { missing.append("username") }
        if passwordIndex == nil { missing.append("password") }
        guard missing.isEmpty else {
            throw PasswordCSVImportError.missingRequiredHeaders(missing)
        }

        let requiredURLIndex = urlIndex!
        let requiredUsernameIndex = usernameIndex!
        let requiredPasswordIndex = passwordIndex!

        var credentials: [ImportedCredential] = []
        var issues: [ImportRowIssue] = []

        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2
            if row.allSatisfy({ $0.isEmpty }) { continue }

            if row.count > headers.count ||
                requiredURLIndex >= row.count ||
                requiredUsernameIndex >= row.count ||
                requiredPasswordIndex >= row.count {
                issues.append(ImportRowIssue(rowNumber: rowNumber, reason: .columnCountMismatch))
                continue
            }

            let rawURL = row[requiredURLIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let username = row[requiredUsernameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let password = row[requiredPasswordIndex]

            guard !password.isEmpty else {
                issues.append(ImportRowIssue(rowNumber: rowNumber, reason: .missingPassword))
                continue
            }

            let normalizedHost: String
            do {
                normalizedHost = try HostNormalizer.normalize(rawURL)
            } catch {
                issues.append(ImportRowIssue(rowNumber: rowNumber, reason: .invalidURL))
                continue
            }

            let title = optionalValue(row, at: titleIndex)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = optionalValue(row, at: notesIndex)

            let credential = CredentialRecord(
                title: (title?.isEmpty == false ? title! : normalizedHost),
                serviceURL: rawURL,
                normalizedHost: normalizedHost,
                username: username,
                password: password,
                notes: notes?.isEmpty == false ? notes : nil,
                createdAt: now,
                updatedAt: now
            )
            credentials.append(ImportedCredential(rowNumber: rowNumber, credential: credential))
        }

        return ImportPreview(credentials: credentials, issues: issues)
    }

    private static func normalizeHeader(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}"))).lowercased()
    }

    private static func firstIndex(in headers: [String], aliases: [String]) -> Int? {
        for alias in aliases {
            if let index = headers.firstIndex(of: alias) { return index }
        }
        return nil
    }

    private static func optionalValue(_ row: [String], at index: Int?) -> String? {
        guard let index, index < row.count else { return nil }
        return row[index]
    }
}
