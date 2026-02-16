import Foundation

/// Parser for `.env` files.
/// Format: `KEY=VALUE` with optional `export` prefix, quoted values, comments, blank lines.
public struct EnvFileParser {

    /// Parse the contents of a `.env` file.
    /// Returns an array of `ParsedLine` preserving every line for reconstruction.
    public static func parse(_ contents: String) -> [ParsedLine] {
        let lines = contents.components(separatedBy: "\n")
        return lines.map { parseLine($0) }
    }

    /// Parse a single `.env` line.
    /// Recognizes: `KEY=VALUE`, `export KEY=VALUE`, comments (#), blank lines.
    private static func parseLine(_ line: String) -> ParsedLine {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip blank lines and comments
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
            return .other(line)
        }

        var workingLine = trimmed

        // Strip optional `export` prefix
        if workingLine.hasPrefix("export ") {
            workingLine = String(workingLine.dropFirst("export ".count))
                .trimmingCharacters(in: .whitespaces)
        }

        // Find the = separator
        guard let equalsIndex = workingLine.firstIndex(of: "=") else {
            return .other(line)
        }

        let name = String(workingLine[workingLine.startIndex..<equalsIndex])
            .trimmingCharacters(in: .whitespaces)

        // Validate variable name
        guard !name.isEmpty, ShellParser.isValidVariableName(name) else {
            return .other(line)
        }

        var rawValue = String(workingLine[workingLine.index(after: equalsIndex)...])

        // Strip inline comment (not inside quotes)
        rawValue = stripInlineComment(rawValue)
        rawValue = rawValue.trimmingCharacters(in: .whitespaces)

        // Unquote
        let value = ShellParser.unquote(rawValue)

        return .export(name: name, value: value, originalLine: line)
    }

    /// Strip inline comment outside quotes — same logic as ShellParser but kept
    /// separate for clarity.
    private static func stripInlineComment(_ value: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        var prevChar: Character?

        for (i, char) in value.enumerated() {
            if char == "'" && !inDoubleQuote && prevChar != "\\" {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote && prevChar != "\\" {
                inDoubleQuote.toggle()
            } else if char == "#" && !inSingleQuote && !inDoubleQuote {
                if let prev = prevChar, prev == " " || prev == "\t" {
                    let endIndex = value.index(value.startIndex, offsetBy: i - 1)
                    return String(value[value.startIndex...endIndex])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            prevChar = char
        }

        return value
    }

    // MARK: - Reconstruction

    /// Reconstruct file contents from parsed lines.
    public static func reconstruct(_ lines: [ParsedLine]) -> String {
        return lines.map { line in
            switch line {
            case .export(_, _, let original):
                return original
            case .other(let original):
                return original
            }
        }.joined(separator: "\n")
    }

    /// Build a new `KEY=VALUE` line (no `export` prefix, double-quoted if needed).
    public static func buildLine(name: String, value: String) -> String {
        let needsQuoting = value.isEmpty ||
            value.contains(" ") ||
            value.contains("\t") ||
            value.contains("$") ||
            value.contains("#") ||
            value.contains("\"") ||
            value.contains("'") ||
            value.contains("\\")

        if needsQuoting {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            return "\(name)=\"\(escaped)\""
        }
        return "\(name)=\(value)"
    }

    /// Extract only the environment variables from parsed lines.
    public static func extractVariables(from lines: [ParsedLine], sourceFile: URL, projectName: String? = nil) -> [EnvironmentVariable] {
        var variables: [EnvironmentVariable] = []
        for (index, line) in lines.enumerated() {
            if case .export(let name, let value, _) = line {
                variables.append(EnvironmentVariable(
                    name: name,
                    value: value,
                    scope: .project,
                    sourceFile: sourceFile,
                    lineNumber: index + 1
                ))
            }
        }
        return variables
    }
}
