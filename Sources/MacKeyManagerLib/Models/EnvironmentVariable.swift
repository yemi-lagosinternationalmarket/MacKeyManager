import Foundation

public enum VariableScope: String, Codable, Hashable, CaseIterable {
    case global
    case project
}

public struct EnvironmentVariable: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var value: String
    public var scope: VariableScope
    public var sourceFile: URL
    public var lineNumber: Int?
    public var isNew: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        value: String,
        scope: VariableScope,
        sourceFile: URL,
        lineNumber: Int? = nil,
        isNew: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.scope = scope
        self.sourceFile = sourceFile
        self.lineNumber = lineNumber
        self.isNew = isNew
    }
}
