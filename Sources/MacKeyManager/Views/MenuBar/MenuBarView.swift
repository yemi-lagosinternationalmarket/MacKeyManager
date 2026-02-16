import SwiftUI
import MacKeyManagerLib

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
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
                    if !expiringEntries.isEmpty {
                        sectionHeader("Expiring Soon")
                        ForEach(expiringEntries) { entry in
                            MenuBarEntryRow(entry: entry, expiryStatus: entry.expiryStatus) {
                                appState.catalogService.togglePin(entryID: entry.id)
                            }
                            Divider().padding(.leading, 8)
                        }
                    }

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

                    if pinnedEntries.isEmpty && displayEntries.isEmpty && expiringEntries.isEmpty {
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

            HStack {
                Button("Open MacKeyManager") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
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

    private var expiringEntries: [CatalogEntry] {
        let expiring = appState.catalogService.expiringSoonEntries() + appState.catalogService.expiredEntries()
        if searchText.isEmpty { return expiring }
        let query = searchText.lowercased()
        return expiring.filter { $0.name.lowercased().contains(query) }
    }

    private var pinnedEntries: [CatalogEntry] {
        let pinned = appState.catalogService.pinnedEntries()
        let expiringIDs = Set(expiringEntries.map(\.id))
        let filtered = pinned.filter { !expiringIDs.contains($0.id) }
        if searchText.isEmpty { return filtered }
        let query = searchText.lowercased()
        return filtered.filter { $0.name.lowercased().contains(query) }
    }

    private var displayEntries: [CatalogEntry] {
        let expiringIDs = Set(expiringEntries.map(\.id))
        if searchText.isEmpty {
            return appState.catalogService.recentEntries(limit: 10)
                .filter { !$0.isPinned && !expiringIDs.contains($0.id) }
        }
        return appState.catalogService.search(query: searchText)
            .filter { !$0.isPinned && !expiringIDs.contains($0.id) }
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
