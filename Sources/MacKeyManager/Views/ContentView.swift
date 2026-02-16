import SwiftUI
import MacKeyManagerLib

enum SidebarSection: Hashable {
    case global
    case project(UUID)
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSection: SidebarSection? = .global

    var body: some View {
        @Bindable var vm = appState.envVarListVM

        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
                .environment(appState)
        } content: {
            EnvVarListView()
                .environment(appState)
        } detail: {
            detailPanel
        }
        .navigationTitle("MacKeyManager")
        .alert(
            "Error",
            isPresented: .init(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            if let msg = vm.errorMessage {
                Text(msg)
            }
        }
        .onAppear {
            appState.envVarListVM.loadGlobalVariables()
        }
        // Keyboard shortcuts
        .keyboardShortcut("n", modifiers: .command) // Cmd+N handled by Add button
        .onDeleteCommand {
            if let id = vm.selectedVariableID {
                vm.deleteVariable(id: id)
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let variable = appState.envVarListVM.selectedVariable {
            EnvVarDetailView(variable: variable)
                .environment(appState)
                .id(variable.id)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Select a variable to view details")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
