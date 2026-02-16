import Foundation

public struct StoredKey: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var key: String
    public var value: String
    public var notes: String?
    public var tags: [String]
    public var createdDate: Date
    public var lastUsedDate: Date?
    public var expiryDate: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        key: String,
        value: String,
        notes: String? = nil,
        tags: [String] = [],
        createdDate: Date = .now,
        lastUsedDate: Date? = nil,
        expiryDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.key = key
        self.value = value
        self.notes = notes
        self.tags = tags
        self.createdDate = createdDate
        self.lastUsedDate = lastUsedDate
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
