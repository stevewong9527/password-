import Foundation

public struct CredentialRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var serviceURL: String
    public var normalizedHost: String
    public var username: String
    public var password: String
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        serviceURL: String,
        normalizedHost: String,
        username: String,
        password: String,
        notes: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.serviceURL = serviceURL
        self.normalizedHost = normalizedHost
        self.username = username
        self.password = password
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
