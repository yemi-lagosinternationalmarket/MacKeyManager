import Foundation

public enum SortOrder: String, CaseIterable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case lineNumber = "File Order"
}

@Observable
public final class EnvVarListViewModel {
    // MARK: - State

    public var searchText = ""
    public var sortOrder: SortOrder = .nameAscending
    public var errorMessage: String?
    public var showingDiffPreview = false
    public var pendingDiff = ""
    public var showingAddSheet = false
    public var selectedVariableID: UUID?

    // MARK: - Services

    private let zshrcService: ZshrcService
    private let catalogService: CatalogService
    private var dotEnvServices: [URL: DotEnvService] = [:]

    // MARK: - Active source

    public var activeSource: ActiveSource = .global

    public enum ActiveSource: Equatable {
        case global
        case project(URL, String)
    }

    public init(zshrcService: ZshrcService, catalogService: CatalogService) {
        self.zshrcService = zshrcService
        self.catalogService = catalogService
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
            // Show diff preview for .zshrc
            do {
                pendingDiff = try zshrcService.generateDiff()
                showingDiffPreview = true
            } catch {
                errorMessage = error.localizedDescription
            }
        case .project(let url, _):
            // Direct save for .env files
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

    /// Reload the active source (e.g., after external file change).
    public func reloadActiveSource() {
        switch activeSource {
        case .global:
            loadGlobalVariables()
        case .project(let url, let name):
            loadProjectVariables(fileURL: url, projectName: name)
        }
    }

    /// Get or create a DotEnvService for a project.
    public func dotEnvService(for url: URL, projectName: String) -> DotEnvService {
        if let existing = dotEnvServices[url] {
            return existing
        }
        let service = DotEnvService(fileURL: url, projectName: projectName)
        dotEnvServices[url] = service
        return service
    }
}
