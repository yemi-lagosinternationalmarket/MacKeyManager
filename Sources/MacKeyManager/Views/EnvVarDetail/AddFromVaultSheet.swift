import SwiftUI
import MacKeyManagerLib

struct AddFromVaultSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedKeyID: UUID?
    @State private var errorMessage: String?

    private var filteredKeys: [StoredKey] {
        let keys = appState.keyVaultService.allKeys()
        if searchText.isEmpty { return keys }
        let query = searchText.lowercased()
        return keys.filter {
            $0.name.lowercased().contains(query) ||
            $0.key.lowercased().contains(query) ||
            $0.tags.contains { $0.lowercased().contains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add from Vault")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search vault keys...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if filteredKeys.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No keys in vault" : "No matching keys")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(filteredKeys, selection: $selectedKeyID) { key in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.name)
                                .font(.body.weight(.medium))
                            Text(key.key)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fontDesign(.monospaced)
                        }
                        Spacer()
                        if !key.tags.isEmpty {
                            Text(key.tags.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tag(key.id)
                    .contentShape(Rectangle())
                }
                .listStyle(.inset)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            HStack {
                LabeledContent("Destination") {
                    switch appState.envVarListVM.activeSource {
                    case .global:
                        Text("Global (.zshrc)")
                            .foregroundStyle(.secondary)
                    case .project(_, let projectName):
                        Text(projectName)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { addFromVault() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedKeyID == nil)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }

    private func addFromVault() {
        guard let keyID = selectedKeyID else { return }
        guard let service = appState.envVarListVM.activeService else { return }

        // Check for duplicate
        guard let key = appState.keyVaultService.storedKeys.first(where: { $0.id == keyID }) else { return }
        if appState.envVarListVM.allVariables.contains(where: { $0.name == key.key }) {
            errorMessage = "A variable named '\(key.key)' already exists."
            return
        }

        appState.keyVaultService.importKey(storedKeyID: keyID, into: service)

        // Sync catalog
        switch appState.envVarListVM.activeSource {
        case .global:
            appState.envVarListVM.loadGlobalVariables()
        case .project(let url, let name):
            appState.envVarListVM.loadProjectVariables(fileURL: url, projectName: name)
        }

        dismiss()
    }
}
