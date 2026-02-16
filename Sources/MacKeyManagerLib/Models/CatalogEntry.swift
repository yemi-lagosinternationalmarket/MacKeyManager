import Foundation

public enum ExpiryStatus: String, CaseIterable {
    case valid
    case expiringSoon
    case expired
    case noExpiry
}

public struct CatalogEntry: Identifiable, Codable, Hashable {
    public let id: UUID
    public var variableKey: String
    public var name: String
    public var scope: String
    public var sourceFilePath: String
    public var projectName: String?
    public var isPinned: Bool
    public var lastSeenDate: Date
    public var notes: String?
    public var expiryDate: Date?

    public init(
        id: UUID = UUID(),
        variableKey: String,
        name: String,
        scope: String,
        sourceFilePath: String,
        projectName: String? = nil,
        isPinned: Bool = false,
        lastSeenDate: Date = .now,
        notes: String? = nil,
        expiryDate: Date? = nil
    ) {
        self.id = id
        self.variableKey = variableKey
        self.name = name
        self.scope = scope
        self.sourceFilePath = sourceFilePath
        self.projectName = projectName
        self.isPinned = isPinned
        self.lastSeenDate = lastSeenDate
        self.notes = notes
        self.expiryDate = expiryDate
    }

    public var expiryStatus: ExpiryStatus {
        guard let expiryDate else { return .noExpiry }
        let now = Date.now
        if expiryDate < now {
            return .expired
        }
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        if expiryDate <= sevenDaysFromNow {
            return .expiringSoon
        }
        return .valid
    }
}
