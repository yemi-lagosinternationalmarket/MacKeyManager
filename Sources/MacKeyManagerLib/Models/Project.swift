import Foundation

public struct Project: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var path: URL
    public var envFilePath: URL

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        envFilePath: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.envFilePath = envFilePath ?? path.appendingPathComponent(".env")
    }
}
