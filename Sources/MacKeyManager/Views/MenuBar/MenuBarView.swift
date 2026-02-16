import SwiftUI
import MacKeyManagerLib

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search variables...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.3))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !pinnedEntries.isEmpty {
                        sectionHeader("Pinned")
                        ForEach(pinnedEntries) { entry in
                            MenuBarEntryRow(entry: entry) {
                                appState.catalogService.togglePin(entryID: entry.id)
                            }
                            Divider().padding(.leading, 8)
                        }
                    }

                    if !displayEntries.isEmpty {
                        sectionHeader(searchText.isEmpty ? "Recent" : "Results")
                        ForEach(displayEntries) { entry in
                            MenuBarEntryRow(entry: entry) {
                                appState.catalogService.togglePin(entryID: entry.id)
                            }
                            Divider().padding(.leading, 8)
                        }
                    }

                    if pinnedEntries.isEmpty && displayEntries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text(searchText.isEmpty ? "No variables indexed" : "No results")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
            }
            .frame(maxHeight: 300)

            Divider()

            // Footer actions
            HStack {
                Button("Open MacKeyManager") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: {
                        $0.title.contains("MacKeyManager") || $0.isKeyWindow
                    }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.borderless)
                .font(.callout)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.callout)
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    // MARK: - Computed

    private var pinnedEntries: [CatalogEntry] {
        let pinned = appState.catalogService.pinnedEntries()
        if searchText.isEmpty { return pinned }
        let query = searchText.lowercased()
        return pinned.filter { $0.name.lowercased().contains(query) }
    }

    private var displayEntries: [CatalogEntry] {
        if searchText.isEmpty {
            return appState.catalogService.recentEntries(limit: 10)
                .filter { !$0.isPinned }
        }
        return appState.catalogService.search(query: searchText)
            .filter { !$0.isPinned }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}
