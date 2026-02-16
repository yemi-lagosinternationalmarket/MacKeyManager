import Foundation

public enum MacKeyManagerError: LocalizedError {
    case fileNotFound(URL)
    case fileNotReadable(URL)
    case fileNotWritable(URL)
    case parseError(String)
    case variableNotFound
    case duplicateVariable(String)
    case invalidVariableName(String)
    case backupFailed(URL)
    case externalFileChange(URL)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileNotReadable(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        case .fileNotWritable(let url):
            return "Cannot write to file: \(url.lastPathComponent)"
        case .parseError(let detail):
            return "Parse error: \(detail)"
        case .variableNotFound:
            return "Variable not found"
        case .duplicateVariable(let name):
            return "Variable '\(name)' already exists"
        case .invalidVariableName(let name):
            return "Invalid variable name: '\(name)'"
        case .backupFailed(let url):
            return "Failed to create backup of \(url.lastPathComponent)"
        case .externalFileChange(let url):
            return "\(url.lastPathComponent) was modified externally"
        }
    }
}
