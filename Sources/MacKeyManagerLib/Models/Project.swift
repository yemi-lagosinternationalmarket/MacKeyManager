import Foundation

public struct Project: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var path: URL
    public var envFiles: [URL]

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        envFiles: [URL]? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.envFiles = envFiles ?? [path.appendingPathComponent(".env")]
    }

    // MARK: - Env File Detection

    public static func detectEnvFiles(in directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        // Also check hidden files since .env files start with a dot
        let allContents: [URL]
        if let hidden = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]
        ) {
            allContents = hidden
        } else {
            allContents = contents
        }

        let envFiles = allContents.filter { url in
            let name = url.lastPathComponent
            return name == ".env" || name.hasPrefix(".env.")
        }

        return envFiles.sorted { a, b in
            let nameA = a.lastPathComponent
            let nameB = b.lastPathComponent
            // .env always comes first
            if nameA == ".env" { return true }
            if nameB == ".env" { return false }
            return nameA.localizedCaseInsensitiveCompare(nameB) == .orderedAscending
        }
    }

    public static func envDisplayName(for url: URL) -> String {
        let filename = url.lastPathComponent
        if filename == ".env" {
            return "Default"
        }
        // .env.local → "Local", .env.production → "Production"
        let suffix = String(filename.dropFirst(".env.".count))
        return suffix.prefix(1).uppercased() + suffix.dropFirst()
    }

    public mutating func refreshEnvFiles() {
        envFiles = Project.detectEnvFiles(in: path)
    }
}

// MARK: - Codable (backward compatible)

extension Project: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, path, envFiles, envFilePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(URL.self, forKey: .path)

        // Try new format first, fall back to old single envFilePath
        if let files = try container.decodeIfPresent([URL].self, forKey: .envFiles) {
            envFiles = files
        } else if let singlePath = try container.decodeIfPresent(URL.self, forKey: .envFilePath) {
            envFiles = [singlePath]
        } else {
            envFiles = [path.appendingPathComponent(".env")]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(envFiles, forKey: .envFiles)
    }
}
