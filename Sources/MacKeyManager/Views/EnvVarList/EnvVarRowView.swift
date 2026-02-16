import SwiftUI
import MacKeyManagerLib

struct EnvVarRowView: View {
    let variable: EnvironmentVariable
    let isSelected: Bool
    var expiryStatus: ExpiryStatus? = nil
    var onSaveToVault: (() -> Void)? = nil
    @State private var isValueRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Text(variable.name)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("=")
                .foregroundStyle(.tertiary)

            Group {
                if isValueRevealed {
                    Text(variable.value)
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text(maskedValue)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer()

            Button {
                isValueRevealed.toggle()
            } label: {
                Image(systemName: isValueRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(isValueRevealed ? "Hide value" : "Show value")

            scopeBadge

            if let expiryStatus, expiryStatus == .expired || expiryStatus == .expiringSoon {
                expiryBadge(expiryStatus)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Name") {
                ClipboardManager.copy(variable.name)
            }
            Button("Copy Value") {
                ClipboardManager.copy(variable.value)
            }
            Button("Copy as Export") {
                ClipboardManager.copy("export \(variable.name)=\(variable.value)")
            }
            Divider()
            if let onSaveToVault {
                Button("Save to Vault") {
                    onSaveToVault()
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                NotificationCenter.default.post(
                    name: .deleteVariable,
                    object: variable.id
                )
            }
        }
    }

    private var maskedValue: String {
        if variable.value.isEmpty { return "(empty)" }
        let len = min(variable.value.count, 20)
        return String(repeating: "\u{2022}", count: len)
    }

    private var scopeBadge: some View {
        Text(variable.scope == .global ? "G" : "P")
            .font(.caption2.weight(.bold))
            .foregroundStyle(variable.scope == .global ? .blue : .green)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                (variable.scope == .global ? Color.blue : Color.green).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    @ViewBuilder
    private func expiryBadge(_ status: ExpiryStatus) -> some View {
        let color: Color = status == .expired ? .red : .orange
        let label = status == .expired ? "Expired" : "Expires soon"
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .help(label)
    }
}

extension Notification.Name {
    static let deleteVariable = Notification.Name("MacKeyManager.deleteVariable")
}
