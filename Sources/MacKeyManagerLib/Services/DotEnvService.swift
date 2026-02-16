import Foundation

@Observable
public final class DotEnvService: EnvFileServiceProtocol {
    public let fileURL: URL
    public private(set) var parsedLines: [ParsedLine] = []
    public private(set) var variables: [EnvironmentVariable] = []
    public private(set) var isDirty = false
    public var errorMessage: String?

    private let projectName: String?

    public init(fileURL: URL, projectName: String? = nil) {
        self.fileURL = fileURL
        self.projectName = projectName
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            parsedLines = []
            variables = []
            isDirty = false
            return
        }

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        parsedLines = EnvFileParser.parse(contents)
        variables = EnvFileParser.extractVariables(from: parsedLines, sourceFile: fileURL, projectName: projectName)
        isDirty = false
    }

    public func add(name: String, value: String) throws {
        guard !variables.contains(where: { $0.name == name }) else {
            throw MacKeyManagerError.duplicateVariable(name)
        }

        let line = EnvFileParser.buildLine(name: name, value: value)
        parsedLines.append(.export(name: name, value: value, originalLine: line))

        let newVar = EnvironmentVariable(
            name: name,
            value: value,
            scope: .project,
            sourceFile: fileURL,
            lineNumber: parsedLines.count,
            isNew: true
        )
        variables.append(newVar)
        isDirty = true
    }

    public func update(variableID: UUID, name: String, value: String) throws {
        guard let varIndex = variables.firstIndex(where: { $0.id == variableID }) else {
            throw MacKeyManagerError.variableNotFound
        }

        let variable = variables[varIndex]

        guard let lineIndex = parsedLines.firstIndex(where: {
            if case .export(let n, _, _) = $0 { return n == variable.name }
            return false
        }) else {
            throw MacKeyManagerError.variableNotFound
        }

        let newLine = EnvFileParser.buildLine(name: name, value: value)
        parsedLines[lineIndex] = .export(name: name, value: value, originalLine: newLine)

        variables[varIndex] = EnvironmentVariable(
            id: variableID,
            name: name,
            value: value,
            scope: .project,
            sourceFile: fileURL,
            lineNumber: lineIndex + 1
        )
        isDirty = true
    }

    public func remove(variableID: UUID) throws {
        guard let varIndex = variables.firstIndex(where: { $0.id == variableID }) else {
            throw MacKeyManagerError.variableNotFound
        }

        let variable = variables[varIndex]

        if let lineIndex = parsedLines.firstIndex(where: {
            if case .export(let n, _, _) = $0 { return n == variable.name }
            return false
        }) {
            parsedLines.remove(at: lineIndex)
        }

        variables.remove(at: varIndex)
        isDirty = true
    }

    /// Save changes to disk. No backup for .env files (typically git-controlled).
    public func save() throws {
        let newContents = EnvFileParser.reconstruct(parsedLines)
        try newContents.write(to: fileURL, atomically: true, encoding: .utf8)
        isDirty = false
    }
}
