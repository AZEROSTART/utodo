import Foundation

public struct Todo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let createdAt: Date
    public let completedAt: Date?

    public var isCompleted: Bool { completedAt != nil }

    public init(id: UUID, title: String, createdAt: Date, completedAt: Date?) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public enum TodoStoreError: Error, Equatable {
    case notFound
    case ambiguousPrefix
    case database(String)
}
