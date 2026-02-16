import SwiftUI

@Observable
public final class ProjectViewModel {
    public private(set) var projects: [Project] = []

    private let userDefaultsKey = "MacKeyManager.projects"

    public init() {
        loadFromDefaults()
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            projects = try JSONDecoder().decode([Project].self, from: data)
        } catch {
            print("Failed to decode projects: \(error)")
        }
    }

    private func saveToDefaults() {
        do {
            let data = try JSONEncoder().encode(projects)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to encode projects: \(error)")
        }
    }

    // MARK: - CRUD

    /// Import a project folder using NSOpenPanel.
    public func importProject() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let name = url.lastPathComponent

        // Don't add duplicates
        guard !projects.contains(where: { $0.path == url }) else { return }

        let envFiles = Project.detectEnvFiles(in: url)
        let project = Project(name: name, path: url, envFiles: envFiles.isEmpty ? nil : envFiles)
        projects.append(project)
        saveToDefaults()
    }

    public func refreshEnvFiles(projectID: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].refreshEnvFiles()
        saveToDefaults()
    }

    public func rename(projectID: UUID, newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        projects[index].name = newName
        saveToDefaults()
    }

    public func remove(projectID: UUID) {
        projects.removeAll { $0.id == projectID }
        saveToDefaults()
    }
}
