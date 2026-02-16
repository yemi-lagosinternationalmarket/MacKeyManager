import SwiftUI
import MacKeyManagerLib

struct MenuBarEntryRow: View {
    let entry: CatalogEntry
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(entry.scope == "global" ? "Global" : entry.projectName ?? "Project")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                // Copy the variable name — the value isn't stored in the catalog
                ClipboardManager.copy(entry.name)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Copy name")

            Button {
                onTogglePin()
            } label: {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundStyle(entry.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(entry.isPinned ? "Unpin" : "Pin")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}
