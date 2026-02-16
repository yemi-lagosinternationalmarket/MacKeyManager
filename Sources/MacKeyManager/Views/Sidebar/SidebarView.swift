import SwiftUI
import MacKeyManagerLib

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedSection: SidebarSection?
    @State private var renamingProjectID: UUID?
    @State private var renameText = ""
    @State private var expandedProjects: Set<UUID> = []

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

            Section("Projects") {
                ForEach(appState.projectVM.projects) { project in
                    projectRows(project)
                }

                if appState.projectVM.projects.isEmpty {
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

    @ViewBuilder
    private func projectRows(_ project: Project) -> some View {
        if renamingProjectID == project.id {
            TextField("Project name", text: $renameText, onCommit: {
                appState.projectVM.rename(projectID: project.id, newName: renameText)
                renamingProjectID = nil
            })
            .textFieldStyle(.roundedBorder)
        } else {
            // Project header — toggles expand/collapse, not selectable
            HStack(spacing: 4) {
                Image(systemName: expandedProjects.contains(project.id) ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Label(project.name, systemImage: "folder")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedProjects.contains(project.id) {
                        expandedProjects.remove(project.id)
                    } else {
                        expandedProjects.insert(project.id)
                    }
                }
            }
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

            // Env file rows — each is a direct tagged child of the List
            if expandedProjects.contains(project.id) {
                ForEach(project.envFiles, id: \.self) { envURL in
                    Label {
                        Text(Project.envDisplayName(for: envURL))
                        Text("(\(envURL.lastPathComponent))")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                    .padding(.leading, 16)
                    .tag(SidebarSection.projectEnv(project.id, envURL))
                }
            }
        }
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
