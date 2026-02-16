import SwiftUI
import MacKeyManagerLib

enum SidebarSection: Hashable {
    case vault
    case global
    case projectEnv(UUID, URL)
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSection: SidebarSection? = .global
    @State private var selectedStoredKeyID: UUID?

    var body: some View {
        @Bindable var vm = appState.envVarListVM

        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
                .environment(appState)
        } content: {
            contentPanel
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
        .keyboardShortcut("n", modifiers: .command)
        .onDeleteCommand {
            if let id = vm.selectedVariableID {
                vm.deleteVariable(id: id)
            }
        }
    }

    @ViewBuilder
    private var contentPanel: some View {
        switch selectedSection {
        case .vault:
            KeyVaultListView(selectedStoredKeyID: $selectedStoredKeyID)
                .environment(appState)
        default:
            EnvVarListView()
                .environment(appState)
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        switch selectedSection {
        case .vault:
            if let keyID = selectedStoredKeyID,
               let key = appState.keyVaultService.storedKeys.first(where: { $0.id == keyID }) {
                StoredKeyDetailView(storedKey: key)
                    .environment(appState)
                    .id(key.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a key to view details")
                        .foregroundStyle(.secondary)
                }
            }
        default:
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
}
