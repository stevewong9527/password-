import Foundation
import VaultCore

public enum VaultFileStore {
    public static func previousVersionURL(for url: URL) -> URL {
        url.appendingPathExtension("previous")
    }

    public static func save(_ document: VaultDocument, using key: VaultKey, to url: URL) throws {
        let encrypted = try VaultCipher.seal(document, using: key)
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let temporaryURL = directory.appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp"
        )
        defer {
            try? fileManager.removeItem(at: temporaryURL)
        }

        try encrypted.write(to: temporaryURL, options: [.atomic])

        if fileManager.fileExists(atPath: url.path) {
            let previousURL = previousVersionURL(for: url)
            if fileManager.fileExists(atPath: previousURL.path) {
                try fileManager.removeItem(at: previousURL)
            }

            _ = try fileManager.replaceItemAt(
                url,
                withItemAt: temporaryURL,
                backupItemName: previousURL.lastPathComponent,
                options: [.withoutDeletingBackupItem]
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: url)
        }
    }

    public static func load(using key: VaultKey, from url: URL) throws -> VaultDocument {
        let encrypted = try Data(contentsOf: url)
        return try VaultCipher.open(encrypted, using: key)
    }
}
