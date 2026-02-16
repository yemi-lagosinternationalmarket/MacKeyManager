import Foundation

/// Represents a single line from a shell config file, preserving the original text
/// for faithful whole-file reconstruction.
public enum ParsedLine {
    /// An export line: `export KEY=VALUE` or `export KEY="VALUE"`
    case export(name: String, value: String, originalLine: String)
    /// Any other line (comment, alias, function, blank, etc.)
    case other(String)
}

public struct ShellParser {

    /// Parse the contents of a `.zshrc` (or similar shell config) file.
    /// Returns an array of `ParsedLine` preserving every line for reconstruction.
    public static func parse(_ contents: String) -> [ParsedLine] {
        let lines = contents.components(separatedBy: "\n")
        return lines.map { parseLine($0) }
    }

    /// Parse a single line. Only `export KEY=VALUE` lines become `.export`;
    /// everything else (comments, aliases, functions, blank lines) becomes `.other`.
    private static func parseLine(_ line: String) -> ParsedLine {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip blank lines, comments, commented-out exports
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("#"),
              trimmed.hasPrefix("export ") else {
            return .other(line)
        }

        // Remove "export " prefix
        let afterExport = String(trimmed.dropFirst("export ".count))
            .trimmingCharacters(in: .whitespaces)

        // Find the = separator
        guard let equalsIndex = afterExport.firstIndex(of: "=") else {
            return .other(line)
        }

        let name = String(afterExport[afterExport.startIndex..<equalsIndex])
            .trimmingCharacters(in: .whitespaces)

        // Validate variable name (alphanumeric + underscore, not starting with digit)
        guard !name.isEmpty, isValidVariableName(name) else {
            return .other(line)
        }

        var rawValue = String(afterExport[afterExport.index(after: equalsIndex)...])

        // Strip inline comment (not inside quotes)
        rawValue = stripInlineComment(rawValue)
        rawValue = rawValue.trimmingCharacters(in: .whitespaces)

        // Unquote the value
        let value = unquote(rawValue)

        return .export(name: name, value: value, originalLine: line)
    }

    /// Validate that a variable name is [A-Za-z_][A-Za-z0-9_]*
    public static func isValidVariableName(_ name: String) -> Bool {
        let pattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    /// Strip an inline comment that is not inside quotes.
    /// e.g., `"hello" # comment` -> `"hello"`
    /// e.g., `hello # comment` -> `hello`
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
                // Check if preceded by whitespace
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

    /// Remove surrounding quotes (single or double) from a value.
    public static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2 {
            if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
               (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
                return String(trimmed.dropFirst().dropLast())
            }
        }
        return trimmed
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

    /// Build a new export line from a name and value.
    /// Uses double quotes if the value contains spaces, special characters, or is empty.
    public static func buildExportLine(name: String, value: String) -> String {
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
            return "export \(name)=\"\(escaped)\""
        }
        return "export \(name)=\(value)"
    }

    /// Extract only the environment variables from parsed lines.
    public static func extractVariables(from lines: [ParsedLine], sourceFile: URL) -> [EnvironmentVariable] {
        var variables: [EnvironmentVariable] = []
        for (index, line) in lines.enumerated() {
            if case .export(let name, let value, _) = line {
                variables.append(EnvironmentVariable(
                    name: name,
                    value: value,
                    scope: .global,
                    sourceFile: sourceFile,
                    lineNumber: index + 1
                ))
            }
        }
        return variables
    }
}
