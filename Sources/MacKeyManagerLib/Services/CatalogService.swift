import Foundation

@Observable
public final class CatalogService {
    public private(set) var entries: [CatalogEntry] = []
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MacKeyManager")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("catalog.json")
        }
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([CatalogEntry].self, from: data)
        } catch {
            print("Failed to load catalog: \(error)")
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save catalog: \(error)")
        }
    }

    // MARK: - Sync

    /// Sync catalog with currently loaded variables.
    /// Adds new entries, updates lastSeenDate for existing, preserves pins.
    public func sync(variables: [EnvironmentVariable], projectName: String? = nil) {
        for variable in variables {
            let key = catalogKey(for: variable)
            if let index = entries.firstIndex(where: { $0.variableKey == key }) {
                entries[index].lastSeenDate = .now
                entries[index].name = variable.name
            } else {
                let entry = CatalogEntry(
                    variableKey: key,
                    name: variable.name,
                    scope: variable.scope.rawValue,
                    sourceFilePath: variable.sourceFile.path,
                    projectName: projectName
                )
                entries.append(entry)
            }
        }
        persist()
    }

    // MARK: - Search

    /// Search catalog entries by name (case-insensitive).
    public func search(query: String) -> [CatalogEntry] {
        guard !query.isEmpty else { return entries }
        let lowered = query.lowercased()
        return entries.filter {
            $0.name.lowercased().contains(lowered) ||
            ($0.notes?.lowercased().contains(lowered) ?? false)
        }
    }

    // MARK: - Pinning

    public func pinnedEntries() -> [CatalogEntry] {
        entries.filter(\.isPinned)
    }

    public func togglePin(entryID: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].isPinned.toggle()
        persist()
    }

    // MARK: - Prune

    /// Remove entries not seen in the given number of days.
    public func pruneStale(olderThanDays days: Int = 30) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        entries.removeAll { !$0.isPinned && $0.lastSeenDate < cutoff }
        persist()
    }

    // MARK: - Recent

    public func recentEntries(limit: Int = 10) -> [CatalogEntry] {
        Array(entries.sorted { $0.lastSeenDate > $1.lastSeenDate }.prefix(limit))
    }

    // MARK: - Expiry

    public func setExpiryDate(entryID: UUID, date: Date?) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].expiryDate = date
        persist()
    }

    public func expiredEntries() -> [CatalogEntry] {
        entries.filter { $0.expiryStatus == .expired }
    }

    public func expiringSoonEntries(withinDays days: Int = 7) -> [CatalogEntry] {
        let now = Date.now
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: now)!
        return entries.filter { entry in
            guard let expiry = entry.expiryDate else { return false }
            return expiry >= now && expiry <= cutoff
        }
    }

    // MARK: - Helpers

    public func catalogKey(for variable: EnvironmentVariable) -> String {
        "\(variable.scope.rawValue):\(variable.sourceFile.path):\(variable.name)"
    }
}
