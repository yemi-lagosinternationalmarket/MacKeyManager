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

        // Check for .env file
        let envURL = url.appendingPathComponent(".env")
        let name = url.lastPathComponent

        // Don't add duplicates
        guard !projects.contains(where: { $0.path == url }) else { return }

        let project = Project(name: name, path: url, envFilePath: envURL)
        projects.append(project)
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
