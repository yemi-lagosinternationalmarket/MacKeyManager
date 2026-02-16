import SwiftUI
import MacKeyManagerLib

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedSection: SidebarSection?
    @State private var renamingProjectID: UUID?
    @State private var renameText = ""

    var body: some View {
        List(selection: $selectedSection) {
            Section("Environment") {
                Label("Global (.zshrc)", systemImage: "globe")
                    .tag(SidebarSection.global)
                    .badge(appState.zshrcService.variables.count)
            }

            Section("Projects") {
                ForEach(appState.projectVM.projects) { project in
                    projectRow(project)
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

    // MARK: - Project Row

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        if renamingProjectID == project.id {
            TextField("Project name", text: $renameText, onCommit: {
                appState.projectVM.rename(projectID: project.id, newName: renameText)
                renamingProjectID = nil
            })
            .textFieldStyle(.roundedBorder)
        } else {
            Label(project.name, systemImage: "folder")
                .tag(SidebarSection.project(project.id))
                .contextMenu {
                    Button("Rename...") {
                        renameText = project.name
                        renamingProjectID = project.id
                    }
                    Divider()
                    Button("Remove", role: .destructive) {
                        appState.projectVM.remove(projectID: project.id)
                        if case .project(let id) = selectedSection, id == project.id {
                            selectedSection = .global
                        }
                    }
                }
        }
    }

    // MARK: - Add Project Button

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

    // MARK: - Section Change

    private func handleSectionChange(_ section: SidebarSection?) {
        guard let section else { return }
        let vm = appState.envVarListVM

        switch section {
        case .global:
            vm.activeSource = .global
            vm.loadGlobalVariables()
        case .project(let projectID):
            if let project = appState.projectVM.projects.first(where: { $0.id == projectID }) {
                vm.activeSource = .project(project.envFilePath, project.name)
                vm.loadProjectVariables(fileURL: project.envFilePath, projectName: project.name)
                appState.fileWatcher.watch(url: project.envFilePath)
            }
        }
    }
}
