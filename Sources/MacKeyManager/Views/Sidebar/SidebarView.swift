import SwiftUI
import MacKeyManagerLib

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedSection: SidebarSection?
    @State private var renamingProjectID: UUID?
    @State private var renameText = ""
    @State private var collapsedProjects: Set<UUID> = []

    var body: some View {
        List(selection: $selectedSection) {
            Section("Key Vault") {
                Label("Vault", systemImage: "lock.shield")
                    .tag(SidebarSection.vault)
                    .badge(appState.keyVaultService.storedKeys.count)
            }

            Section("Environment") {
                Label("Global (.zshrc)", systemImage: "globe")
                    .tag(SidebarSection.global)
                    .badge(appState.zshrcService.variables.count)
            }

            // Each project is its own collapsible Section.
            // Section headers are NOT selectable rows, so they
            // can't break the List's selection binding.
            ForEach(appState.projectVM.projects) { project in
                if renamingProjectID == project.id {
                    Section(project.name) {
                        TextField("Project name", text: $renameText, onCommit: {
                            appState.projectVM.rename(projectID: project.id, newName: renameText)
                            renamingProjectID = nil
                        })
                        .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Section(isExpanded: expandedBinding(for: project.id)) {
                        ForEach(project.envFiles, id: \.self) { envURL in
                            Label {
                                Text(Project.envDisplayName(for: envURL))
                                Text("(\(envURL.lastPathComponent))")
                                    .foregroundStyle(.tertiary)
                                    .font(.caption)
                            } icon: {
                                Image(systemName: "doc.text")
                            }
                            .tag(SidebarSection.projectEnv(project.id, envURL))
                        }
                    } header: {
                        Label(project.name, systemImage: "folder")
                            .contextMenu {
                                Button("Rename...") {
                                    renameText = project.name
                                    renamingProjectID = project.id
                                }
                                Button("Refresh Environments") {
                                    appState.projectVM.refreshEnvFiles(projectID: project.id)
                                }
                                Divider()
                                Button("Remove", role: .destructive) {
                                    let projectID = project.id
                                    appState.projectVM.remove(projectID: projectID)
                                    if case .projectEnv(let id, _) = selectedSection, id == projectID {
                                        selectedSection = .global
                                    }
                                }
                            }
                    }
                }
            }

            if appState.projectVM.projects.isEmpty {
                Section("Projects") {
                    Text("No projects added")
                        .foregroundStyle(.tertiary)
                        .font(.callout)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            addProjectButton
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .onChange(of: selectedSection) { _, newValue in
            handleSectionChange(newValue)
        }
    }

    private func expandedBinding(for projectID: UUID) -> Binding<Bool> {
        Binding(
            get: { !collapsedProjects.contains(projectID) },
            set: { isExpanded in
                if isExpanded {
                    collapsedProjects.remove(projectID)
                } else {
                    collapsedProjects.insert(projectID)
                }
            }
        )
    }

    private var addProjectButton: some View {
        Button {
            appState.projectVM.importProject()
        } label: {
            Label("Add Project", systemImage: "plus.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func handleSectionChange(_ section: SidebarSection?) {
        guard let section else { return }
        let vm = appState.envVarListVM

        switch section {
        case .vault:
            break
        case .global:
            vm.activeSource = .global
            vm.loadGlobalVariables()
        case .projectEnv(let projectID, let envURL):
            if let project = appState.projectVM.projects.first(where: { $0.id == projectID }) {
                let displayName = "\(project.name) — \(Project.envDisplayName(for: envURL))"
                vm.activeSource = .project(envURL, displayName)
                vm.loadProjectVariables(fileURL: envURL, projectName: project.name)
                appState.fileWatcher.watch(url: envURL)
            }
        }
    }
}
