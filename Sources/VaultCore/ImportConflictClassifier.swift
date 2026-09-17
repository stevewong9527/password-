import Foundation

public enum ImportConflictClassification: Equatable, Sendable {
    case duplicate
    case conflict
    case distinct
}

public enum ImportConflictClassifier {
    public static func classify(
        existing: CredentialRecord,
        imported: CredentialRecord
    ) -> ImportConflictClassification {
        guard existing.normalizedHost == imported.normalizedHost else { return .distinct }

        let existingUsername = normalizeUsername(existing.username)
        let importedUsername = normalizeUsername(imported.username)
        guard existingUsername == importedUsername else { return .distinct }

        return existing.password == imported.password ? .duplicate : .conflict
    }

    private static func normalizeUsername(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
