import Foundation

@Observable
public final class ZshrcService: EnvFileServiceProtocol {
    public let fileURL: URL
    public private(set) var parsedLines: [ParsedLine] = []
    public private(set) var variables: [EnvironmentVariable] = []
    public private(set) var isDirty = false
    public var errorMessage: String?

    private let backupDirectory: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".zshrc")
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.backupDirectory = appSupport.appendingPathComponent("MacKeyManager/backups")
        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    public func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            parsedLines = []
            variables = []
            isDirty = false
            return
        }

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        parsedLines = ShellParser.parse(contents)
        variables = ShellParser.extractVariables(from: parsedLines, sourceFile: fileURL)
        isDirty = false
    }

    public func add(name: String, value: String) throws {
        // Check for duplicate
        guard !variables.contains(where: { $0.name == name }) else {
            throw MacKeyManagerError.duplicateVariable(name)
        }

        let exportLine = ShellParser.buildExportLine(name: name, value: value)
        parsedLines.append(.export(name: name, value: value, originalLine: exportLine))

        let newVar = EnvironmentVariable(
            name: name,
            value: value,
            scope: .global,
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

        // Find the corresponding parsed line by matching the old name
        guard let lineIndex = parsedLines.firstIndex(where: {
            if case .export(let n, _, _) = $0 { return n == variable.name }
            return false
        }) else {
            throw MacKeyManagerError.variableNotFound
        }

        let newLine = ShellParser.buildExportLine(name: name, value: value)
        parsedLines[lineIndex] = .export(name: name, value: value, originalLine: newLine)

        variables[varIndex] = EnvironmentVariable(
            id: variableID,
            name: name,
            value: value,
            scope: .global,
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

        // Find and remove the corresponding parsed line
        if let lineIndex = parsedLines.firstIndex(where: {
            if case .export(let n, _, _) = $0 { return n == variable.name }
            return false
        }) {
            parsedLines.remove(at: lineIndex)
        }

        variables.remove(at: varIndex)
        isDirty = true
    }

    // MARK: - Diff & Save

    /// Generate a unified-style diff between the current file and pending changes.
    public func generateDiff() throws -> String {
        let currentContents: String
        if FileManager.default.fileExists(atPath: fileURL.path) {
            currentContents = try String(contentsOf: fileURL, encoding: .utf8)
        } else {
            currentContents = ""
        }
        let newContents = ShellParser.reconstruct(parsedLines)

        let currentLines = currentContents.components(separatedBy: "\n")
        let newLines = newContents.components(separatedBy: "\n")

        var diff = ""
        let maxLines = max(currentLines.count, newLines.count)

        for i in 0..<maxLines {
            let oldLine = i < currentLines.count ? currentLines[i] : nil
            let newLine = i < newLines.count ? newLines[i] : nil

            if oldLine == newLine {
                if let line = oldLine {
                    diff += "  \(line)\n"
                }
            } else {
                if let old = oldLine {
                    diff += "- \(old)\n"
                }
                if let new = newLine {
                    diff += "+ \(new)\n"
                }
            }
        }

        return diff
    }

    /// Save changes to disk. Creates a timestamped backup first.
    public func save() throws {
        // Create backup of current file
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let timestamp = formatter.string(from: Date())
            let backupName = "\(fileURL.lastPathComponent).backup.\(timestamp)"
            let backupURL = backupDirectory.appendingPathComponent(backupName)
            try FileManager.default.copyItem(at: fileURL, to: backupURL)
        }

        // Atomic write
        let newContents = ShellParser.reconstruct(parsedLines)
        try newContents.write(to: fileURL, atomically: true, encoding: .utf8)
        isDirty = false
    }
}
