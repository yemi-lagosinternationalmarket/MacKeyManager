import SwiftUI
import MacKeyManagerLib

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedSection: SidebarSection?
    @State private var renamingProjectID: UUID?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var collapsedProjects: Set<UUID> = []

    var body: some View {
        List {
            Section("Key Vault") {
                sidebarRow(
                    label: "Vault",
                    icon: "lock.shield",
                    section: .vault,
                    badge: appState.keyVaultService.storedKeys.count
                )
            }

            Section("Environment") {
                sidebarRow(
                    label: "Global (.zshrc)",
                    icon: "globe",
                    section: .global,
                    badge: appState.zshrcService.variables.count
                )
            }

            Section("Projects") {
                ForEach(appState.projectVM.projects) { project in
                    if project.envFiles.count == 1, let envURL = project.envFiles.first {
                        // Single env file — show as flat row
                        sidebarRow(
                            label: project.name,
                            icon: "folder",
                            section: .projectEnv(project.id, envURL)
                        )
                        .contextMenu {
                            projectContextMenu(project: project)
                        }
                    } else {
                        // Multiple env files — show folder header + children
                        projectFolderHeader(project: project)
                            .contextMenu {
                                projectContextMenu(project: project)
                            }

                        if !collapsedProjects.contains(project.id) {
                            ForEach(project.envFiles, id: \.self) { envURL in
                                sidebarRow(
                                    label: Project.envDisplayName(for: envURL),
                                    icon: "doc.text",
                                    section: .projectEnv(project.id, envURL),
                                    indented: true
                                )
                                .contextMenu {
                                    projectContextMenu(project: project)
                                }
                            }
                        }
                    }
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
        .alert("Rename Project", isPresented: $showRenameAlert) {
            TextField("Project name", text: $renameText)
            Button("Rename") {
                if let id = renamingProjectID {
                    appState.projectVM.rename(projectID: id, newName: renameText)
                }
                renamingProjectID = nil
            }
            Button("Cancel", role: .cancel) {
                renamingProjectID = nil
            }
        }
    }

    private func projectFolderHeader(project: Project) -> some View {
        let isCollapsed = collapsedProjects.contains(project.id)
        return HStack(spacing: 6) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 10)
            Label(project.name, systemImage: "folder")
            Spacer()
            Text("\(project.envFiles.count)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isCollapsed {
                    collapsedProjects.remove(project.id)
                } else {
                    collapsedProjects.insert(project.id)
                }
            }
        }
    }

    @ViewBuilder
    private func projectContextMenu(project: Project) -> some View {
        Button("Rename...") {
            renameText = project.name
            renamingProjectID = project.id
            showRenameAlert = true
        }
        Button("Refresh Environments") {
            appState.projectVM.refreshEnvFiles(projectID: project.id)
        }
        Divider()
        Button("Remove", role: .destructive) {
            appState.projectVM.remove(projectID: project.id)
            if case .projectEnv(let id, _) = selectedSection, id == project.id {
                selectedSection = .global
            }
        }
    }

    private func sidebarRow(
        label: String,
        icon: String,
        section: SidebarSection,
        badge: Int? = nil,
        indented: Bool = false
    ) -> some View {
        HStack {
            if indented {
                Spacer().frame(width: 16)
            }
            Label(label, systemImage: icon)
            Spacer()
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSection = section
            handleSectionChange(section)
        }
        .listRowBackground(
            selectedSection == section
                ? Color.accentColor.opacity(0.2)
                : Color.clear
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

    private func handleSectionChange(_ section: SidebarSection) {
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
