import Foundation

public struct VaultFileStore<Cipher: VaultCipher>: Sendable {
    public let url: URL
    public let codec: VaultCodec<Cipher>

    public init(url: URL, codec: VaultCodec<Cipher>) {
        self.url = url
        self.codec = codec
    }

    public var previousURL: URL {
        url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".previous")
    }

    public func save(_ document: VaultDocument) throws {
        let encrypted = try codec.encode(document)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: url.path) {
            if FileManager.default.fileExists(atPath: previousURL.path) {
                try FileManager.default.removeItem(at: previousURL)
            }
            try FileManager.default.copyItem(at: url, to: previousURL)
        }

        try encrypted.write(to: url, options: .atomic)
        #if canImport(Darwin)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        if FileManager.default.fileExists(atPath: previousURL.path) {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: previousURL.path)
        }
        #endif
    }

    public func load() throws -> VaultDocument {
        try codec.decode(Data(contentsOf: url))
    }
}
