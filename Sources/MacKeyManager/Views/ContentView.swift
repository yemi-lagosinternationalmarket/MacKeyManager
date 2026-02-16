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
    @State private var showError = false
    @State private var errorText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
                .environment(appState)
        } content: {
            contentPanel
        } detail: {
            detailPanel
        }
        .navigationTitle("MacKeyManager")
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorText)
        }
        .onAppear {
            appState.envVarListVM.loadGlobalVariables()
            if let err = appState.envVarListVM.errorMessage {
                errorText = err
                showError = true
                appState.envVarListVM.errorMessage = nil
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
