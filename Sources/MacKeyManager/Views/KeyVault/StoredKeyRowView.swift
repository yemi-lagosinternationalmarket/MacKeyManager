import SwiftUI
import MacKeyManagerLib

struct StoredKeyRowView: View {
    let storedKey: StoredKey
    let isSelected: Bool
    @State private var isValueRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(storedKey.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                Text(storedKey.key)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !storedKey.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(storedKey.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button {
                isValueRevealed.toggle()
            } label: {
                Image(systemName: isValueRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(isValueRevealed ? "Hide value" : "Show value")

            if isValueRevealed {
                Text(storedKey.value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            }

            if storedKey.expiryStatus == .expired || storedKey.expiryStatus == .expiringSoon {
                Circle()
                    .fill(storedKey.expiryStatus == .expired ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)
                    .help(storedKey.expiryStatus == .expired ? "Expired" : "Expires soon")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value") {
                ClipboardManager.copy(storedKey.value)
            }
            Button("Copy Key Name") {
                ClipboardManager.copy(storedKey.key)
            }
        }
    }
}
