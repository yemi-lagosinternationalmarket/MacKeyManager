import Foundation

public enum SortOrder: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case lineNumber = "File Order"
}

public enum ExpiryFilter: String, CaseIterable {
    case all = "All"
    case expiringSoon = "Expiring Soon"
    case expired = "Expired"
    case noExpiry = "No Expiry"
}

@Observable
public final class EnvVarListViewModel {
    // MARK: - State

    public var searchText = ""
    public var sortOrder: SortOrder = .nameAscending
    public var expiryFilter: ExpiryFilter = .all
    public var errorMessage: String?
    public var showingDiffPreview = false
    public var pendingDiff = ""
    public var showingAddSheet = false
    public var showingAddFromVaultSheet = false
    public var selectedVariableID: UUID?

    // MARK: - Services

    private let zshrcService: ZshrcService
    private let catalogService: CatalogService
    private let keyVaultService: KeyVaultService
    private var dotEnvServices: [URL: DotEnvService] = [:]

    // MARK: - Active source

    public var activeSource: ActiveSource = .global

    public enum ActiveSource: Equatable {
        case global
        case project(URL, String)
    }

    public init(zshrcService: ZshrcService, catalogService: CatalogService, keyVaultService: KeyVaultService) {
        self.zshrcService = zshrcService
        self.catalogService = catalogService
        self.keyVaultService = keyVaultService
    }

    // MARK: - Computed

    public var allVariables: [EnvironmentVariable] {
        switch activeSource {
        case .global:
            return zshrcService.variables
        case .project(let url, _):
            return dotEnvServices[url]?.variables ?? []
        }
    }

    public var filteredVariables: [EnvironmentVariable] {
        var result = allVariables

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.value.lowercased().contains(query)
            }
        }

        if expiryFilter != .all {
            result = result.filter { variable in
                let entry = catalogEntry(for: variable)
                let status = entry?.expiryStatus ?? .noExpiry
                switch expiryFilter {
                case .all:
                    return true
                case .expiringSoon:
                    return status == .expiringSoon
                case .expired:
                    return status == .expired
                case .noExpiry:
                    return status == .noExpiry
                }
            }
        }

        switch sortOrder {
        case .nameAscending:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .lineNumber:
            result.sort { ($0.lineNumber ?? 0) < ($1.lineNumber ?? 0) }
        }

        return result
    }

    public var selectedVariable: EnvironmentVariable? {
        guard let id = selectedVariableID else { return nil }
        return allVariables.first { $0.id == id }
    }

    public var isDirty: Bool {
        switch activeSource {
        case .global:
            return zshrcService.isDirty
        case .project(let url, _):
            return dotEnvServices[url]?.isDirty ?? false
        }
    }

    public var activeService: (any EnvFileServiceProtocol)? {
        switch activeSource {
        case .global:
            return zshrcService
        case .project(let url, _):
            return dotEnvServices[url]
        }
    }

    // MARK: - Expiry

    public func catalogEntry(for variable: EnvironmentVariable) -> CatalogEntry? {
        let key = catalogService.catalogKey(for: variable)
        return catalogService.entries.first { $0.variableKey == key }
    }

    public func setExpiryDate(for variableID: UUID, date: Date?) {
        guard let variable = allVariables.first(where: { $0.id == variableID }) else { return }
        let key = catalogService.catalogKey(for: variable)
        guard let entry = catalogService.entries.first(where: { $0.variableKey == key }) else { return }
        catalogService.setExpiryDate(entryID: entry.id, date: date)
    }

    public var expiryFilterCounts: [ExpiryFilter: Int] {
        var counts: [ExpiryFilter: Int] = [:]
        for variable in allVariables {
            let entry = catalogEntry(for: variable)
            let status = entry?.expiryStatus ?? .noExpiry
            switch status {
            case .expired:
                counts[.expired, default: 0] += 1
            case .expiringSoon:
                counts[.expiringSoon, default: 0] += 1
            case .noExpiry:
                counts[.noExpiry, default: 0] += 1
            case .valid:
                break
            }
        }
        return counts
    }

    public var hasAnyExpiry: Bool {
        allVariables.contains { variable in
            let entry = catalogEntry(for: variable)
            return entry?.expiryDate != nil
        }
    }

    // MARK: - Vault

    public func saveToVault(variable: EnvironmentVariable, name: String, tags: [String]) {
        keyVaultService.storeFromVariable(variable, name: name, tags: tags)
    }

    // MARK: - Actions

    public func loadGlobalVariables() {
        do {
            try zshrcService.load()
            catalogService.sync(variables: zshrcService.variables)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadProjectVariables(fileURL: URL, projectName: String) {
        let service: DotEnvService
        if let existing = dotEnvServices[fileURL] {
            service = existing
        } else {
            service = DotEnvService(fileURL: fileURL, projectName: projectName)
            dotEnvServices[fileURL] = service
        }

        do {
            try service.load()
            catalogService.sync(variables: service.variables, projectName: projectName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addVariable(name: String, value: String) {
        do {
            switch activeSource {
            case .global:
                try zshrcService.add(name: name, value: value)
                catalogService.sync(variables: zshrcService.variables)
            case .project(let url, let projectName):
                try dotEnvServices[url]?.add(name: name, value: value)
                if let vars = dotEnvServices[url]?.variables {
                    catalogService.sync(variables: vars, projectName: projectName)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func updateVariable(id: UUID, name: String, value: String) {
        do {
            switch activeSource {
            case .global:
                try zshrcService.update(variableID: id, name: name, value: value)
            case .project(let url, _):
                try dotEnvServices[url]?.update(variableID: id, name: name, value: value)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteVariable(id: UUID) {
        do {
            switch activeSource {
            case .global:
                try zshrcService.remove(variableID: id)
            case .project(let url, _):
                try dotEnvServices[url]?.remove(variableID: id)
            }
            if selectedVariableID == id {
                selectedVariableID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func prepareSave() {
        switch activeSource {
        case .global:
            do {
                pendingDiff = try zshrcService.generateDiff()
                showingDiffPreview = true
            } catch {
                errorMessage = error.localizedDescription
            }
        case .project(let url, _):
            do {
                try dotEnvServices[url]?.save()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    public func confirmSave() {
        do {
            try zshrcService.save()
            showingDiffPreview = false
            pendingDiff = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func cancelSave() {
        showingDiffPreview = false
        pendingDiff = ""
    }

    public func reloadActiveSource() {
        switch activeSource {
        case .global:
            loadGlobalVariables()
        case .project(let url, let name):
            loadProjectVariables(fileURL: url, projectName: name)
        }
    }

    public func dotEnvService(for url: URL, projectName: String) -> DotEnvService {
        if let existing = dotEnvServices[url] {
            return existing
        }
        let service = DotEnvService(fileURL: url, projectName: projectName)
        dotEnvServices[url] = service
        return service
    }
}
