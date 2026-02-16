import SwiftUI
import MacKeyManagerLib

struct DiffPreviewSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Review Changes to .zshrc")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Diff content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(diffLines, id: \.self) { line in
                        diffLineView(line)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(.background.secondary)

            Divider()

            // Actions
            HStack {
                Text("This will modify ~/.zshrc. A backup will be created.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    appState.envVarListVM.cancelSave()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply Changes") {
                    appState.envVarListVM.confirmSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 600, height: 450)
    }

    private var diffLines: [String] {
        appState.envVarListVM.pendingDiff
            .components(separatedBy: "\n")
    }

    @ViewBuilder
    private func diffLineView(_ line: String) -> some View {
        HStack(spacing: 0) {
            Text(line)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(colorForLine(line))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.horizontal, 8)
        }
        .background(backgroundForLine(line))
    }

    private func colorForLine(_ line: String) -> Color {
        if line.hasPrefix("+ ") { return .green }
        if line.hasPrefix("- ") { return .red }
        return .primary
    }

    private func backgroundForLine(_ line: String) -> Color {
        if line.hasPrefix("+ ") { return .green.opacity(0.1) }
        if line.hasPrefix("- ") { return .red.opacity(0.1) }
        return .clear
    }
}
