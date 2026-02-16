import SwiftUI
import MacKeyManagerLib

struct EnvVarDetailView: View {
    @Environment(AppState.self) private var appState
    let variable: EnvironmentVariable

    @State private var editName: String = ""
    @State private var editValue: String = ""
    @State private var isValueRevealed = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section("Variable") {
                LabeledContent("Name") {
                    TextField("NAME", text: $editName)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Value") {
                    HStack {
                        if isValueRevealed {
                            TextField("value", text: $editValue)
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("value", text: $editValue)
                                .font(.system(.body, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            isValueRevealed.toggle()
                        } label: {
                            Image(systemName: isValueRevealed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section("Info") {
                LabeledContent("Scope") {
                    Text(variable.scope == .global ? "Global (.zshrc)" : "Project (.env)")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Source File") {
                    Text(variable.sourceFile.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                if let lineNumber = variable.lineNumber {
                    LabeledContent("Line") {
                        Text("\(lineNumber)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack(spacing: 12) {
                    Button("Save") {
                        appState.envVarListVM.updateVariable(
                            id: variable.id,
                            name: editName,
                            value: editValue
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)

                    Button("Copy Value") {
                        ClipboardManager.copy(editValue)
                    }

                    Button("Copy as Export") {
                        ClipboardManager.copy("export \(editName)=\(editValue)")
                    }

                    Spacer()

                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { resetFields() }
        .onChange(of: variable.id) { _, _ in resetFields() }
        .alert("Delete Variable", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                appState.envVarListVM.deleteVariable(id: variable.id)
            }
        } message: {
            Text("Are you sure you want to delete \"\(variable.name)\"? This change will be written when you save.")
        }
    }

    private var hasChanges: Bool {
        editName != variable.name || editValue != variable.value
    }

    private func resetFields() {
        editName = variable.name
        editValue = variable.value
        isValueRevealed = false
    }
}
