import Foundation

@Observable
public final class KeyVaultService {
    public private(set) var storedKeys: [StoredKey] = []
    private let storageURL: URL

    public init(storageURL: URL? = nil) {
        if let url = storageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("MacKeyManager")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("vault.json")
        }
    }

    // MARK: - Persistence

    public func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            storedKeys = try JSONDecoder().decode([StoredKey].self, from: data)
        } catch {
            print("Failed to load vault: \(error)")
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(storedKeys)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save vault: \(error)")
        }
    }

    // MARK: - CRUD

    public func addKey(name: String, key: String, value: String, notes: String? = nil, tags: [String] = [], expiryDate: Date? = nil) {
        let storedKey = StoredKey(
            name: name,
            key: key,
            value: value,
            notes: notes,
            tags: tags,
            expiryDate: expiryDate
        )
        storedKeys.append(storedKey)
        persist()
    }

    public func updateKey(id: UUID, name: String? = nil, key: String? = nil, value: String? = nil, notes: String? = nil, tags: [String]? = nil, expiryDate: Date?? = nil) {
        guard let index = storedKeys.firstIndex(where: { $0.id == id }) else { return }
        if let name { storedKeys[index].name = name }
        if let key { storedKeys[index].key = key }
        if let value { storedKeys[index].value = value }
        if let notes { storedKeys[index].notes = notes }
        if let tags { storedKeys[index].tags = tags }
        if let expiryDate { storedKeys[index].expiryDate = expiryDate }
        persist()
    }

    public func removeKey(id: UUID) {
        storedKeys.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Search

    public func search(query: String) -> [StoredKey] {
        guard !query.isEmpty else { return storedKeys }
        let lowered = query.lowercased()
        return storedKeys.filter {
            $0.name.lowercased().contains(lowered) ||
            $0.key.lowercased().contains(lowered) ||
            ($0.notes?.lowercased().contains(lowered) ?? false) ||
            $0.tags.contains { $0.lowercased().contains(lowered) }
        }
    }

    public func allKeys() -> [StoredKey] {
        storedKeys.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Import / Store

    public func importKey(storedKeyID: UUID, into service: any EnvFileServiceProtocol) {
        guard let index = storedKeys.firstIndex(where: { $0.id == storedKeyID }) else { return }
        let key = storedKeys[index]
        do {
            try service.add(name: key.key, value: key.value)
            storedKeys[index].lastUsedDate = .now
            persist()
        } catch {
            print("Failed to import key: \(error)")
        }
    }

    public func storeFromVariable(_ variable: EnvironmentVariable, name: String, tags: [String]) {
        addKey(
            name: name,
            key: variable.name,
            value: variable.value,
            tags: tags
        )
    }
}
