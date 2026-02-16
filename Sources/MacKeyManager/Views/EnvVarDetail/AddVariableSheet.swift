import SwiftUI
import MacKeyManagerLib

struct AddVariableSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var value = ""
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Variable")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                TextField("Variable Name (e.g. API_KEY)", text: $name)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _, newValue in
                        // Auto-uppercase and sanitize
                        let cleaned = newValue.uppercased()
                            .replacingOccurrences(of: " ", with: "_")
                        if cleaned != newValue {
                            name = cleaned
                        }
                        validateName()
                    }

                TextField("Value", text: $value)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                LabeledContent("Scope") {
                    switch appState.envVarListVM.activeSource {
                    case .global:
                        Text("Global (.zshrc)")
                    case .project(_, let projectName):
                        Text("Project: \(projectName)")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    addVariable()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 300)
    }

    private var isValid: Bool {
        !name.isEmpty && validationError == nil
    }

    private func validateName() {
        if name.isEmpty {
            validationError = nil
            return
        }

        if !ShellParser.isValidVariableName(name) {
            validationError = "Invalid name. Use letters, numbers, and underscores only. Must start with a letter or underscore."
            return
        }

        // Check for duplicates
        if appState.envVarListVM.allVariables.contains(where: { $0.name == name }) {
            validationError = "A variable named '\(name)' already exists."
            return
        }

        validationError = nil
    }

    private func addVariable() {
        guard isValid else { return }
        appState.envVarListVM.addVariable(name: name, value: value)
        dismiss()
    }
}
