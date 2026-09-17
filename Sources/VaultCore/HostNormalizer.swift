import Foundation

public enum HostNormalizerError: Error, Equatable, Sendable {
    case invalidURL
    case missingHost
}

public enum HostNormalizer {
    public static func normalize(_ rawValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HostNormalizerError.invalidURL }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate) else {
            throw HostNormalizerError.invalidURL
        }
        guard var host = components.host, !host.isEmpty else {
            throw HostNormalizerError.missingHost
        }
        guard !host.contains(where: { $0.isWhitespace }) else {
            throw HostNormalizerError.invalidURL
        }

        host = host.lowercased()
        while host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host.removeFirst(4) }

        guard !host.isEmpty else { throw HostNormalizerError.missingHost }
        return host
    }
}
