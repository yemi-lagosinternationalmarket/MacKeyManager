import SwiftUI
import MacKeyManagerLib

struct MenuBarEntryRow: View {
    let entry: CatalogEntry
    var expiryStatus: ExpiryStatus? = nil
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .lineLimit(1)

                    if let expiryStatus, expiryStatus == .expired || expiryStatus == .expiringSoon {
                        Circle()
                            .fill(expiryStatus == .expired ? Color.red : Color.orange)
                            .frame(width: 6, height: 6)
                    }
                }

                HStack(spacing: 4) {
                    Text(entry.scope == "global" ? "Global" : entry.projectName ?? "Project")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let expiryDate = entry.expiryDate {
                        Text(expiryDateLabel(expiryDate))
                            .font(.caption2)
                            .foregroundStyle(entry.expiryStatus == .expired ? .red : entry.expiryStatus == .expiringSoon ? .orange : .secondary)
                    }
                }
            }

            Spacer()

            Button {
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

    private func expiryDateLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Expires \(formatter.localizedString(for: date, relativeTo: .now))"
    }
}
