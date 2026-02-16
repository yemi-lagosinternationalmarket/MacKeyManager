import SwiftUI
import MacKeyManagerLib

struct KeyVaultListView: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedStoredKeyID: UUID?
    @State private var searchText = ""
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchBar(text: $searchText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if filteredKeys.isEmpty {
                emptyState
            } else {
                List(selection: $selectedStoredKeyID) {
                    ForEach(filteredKeys) { key in
                        StoredKeyRowView(
                            storedKey: key,
                            isSelected: selectedStoredKeyID == key.id
                        )
                        .tag(key.id)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Key", systemImage: "plus")
                }

                Spacer()

                Text("\(filteredKeys.count) keys")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 380)
        .sheet(isPresented: $showingAddSheet) {
            AddStoredKeySheet()
                .environment(appState)
        }
    }

    private var filteredKeys: [StoredKey] {
        if searchText.isEmpty {
            return appState.keyVaultService.allKeys()
        }
        return appState.keyVaultService.search(query: searchText)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            if searchText.isEmpty {
                Image(systemName: "lock.shield")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No Keys Stored")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Add keys to your vault to manage and import them into projects.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No Results")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("No keys match \"\(searchText)\"")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
