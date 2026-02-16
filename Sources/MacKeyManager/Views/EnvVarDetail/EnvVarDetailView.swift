import SwiftUI
import MacKeyManagerLib

struct EnvVarDetailView: View {
    @Environment(AppState.self) private var appState
    let variable: EnvironmentVariable

    @State private var editName: String = ""
    @State private var editValue: String = ""
    @State private var isValueRevealed = false
    @State private var showDeleteConfirm = false
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    @State private var showSaveToVaultSheet = false
    @State private var vaultName = ""
    @State private var vaultTags = ""

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

            Section("Expiry") {
                Toggle("Set expiry date", isOn: $hasExpiry)
                    .onChange(of: hasExpiry) { _, newValue in
                        if !newValue {
                            appState.envVarListVM.setExpiryDate(for: variable.id, date: nil)
                        } else {
                            appState.envVarListVM.setExpiryDate(for: variable.id, date: expiryDate)
                        }
                    }

                if hasExpiry {
                    DatePicker(
                        "Expiry date",
                        selection: $expiryDate,
                        in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                        displayedComponents: .date
                    )
                    .onChange(of: expiryDate) { _, newDate in
                        appState.envVarListVM.setExpiryDate(for: variable.id, date: newDate)
                    }

                    if let entry = appState.envVarListVM.catalogEntry(for: variable) {
                        LabeledContent("Status") {
                            expiryStatusLabel(entry.expiryStatus)
                        }
                    }

                    Button("Clear Expiry") {
                        hasExpiry = false
                        appState.envVarListVM.setExpiryDate(for: variable.id, date: nil)
                    }
                }
            }

            Section("Actions") {
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

                    Button("Save to Vault") {
                        vaultName = variable.name
                        vaultTags = ""
                        showSaveToVaultSheet = true
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
        .sheet(isPresented: $showSaveToVaultSheet) {
            saveToVaultSheet
        }
    }

    private var hasChanges: Bool {
        editName != variable.name || editValue != variable.value
    }

    private func resetFields() {
        editName = variable.name
        editValue = variable.value
        isValueRevealed = false

        if let entry = appState.envVarListVM.catalogEntry(for: variable),
           let date = entry.expiryDate {
            hasExpiry = true
            expiryDate = date
        } else {
            hasExpiry = false
            expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        }
    }

    @ViewBuilder
    private func expiryStatusLabel(_ status: ExpiryStatus) -> some View {
        switch status {
        case .expired:
            Text("Expired")
                .foregroundStyle(.red)
                .fontWeight(.medium)
        case .expiringSoon:
            Text("Expires soon")
                .foregroundStyle(.orange)
                .fontWeight(.medium)
        case .valid:
            Text("Valid")
                .foregroundStyle(.green)
                .fontWeight(.medium)
        case .noExpiry:
            Text("No expiry")
                .foregroundStyle(.secondary)
        }
    }

    private var saveToVaultSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save to Vault")
                    .font(.headline)
                Spacer()
                Button {
                    showSaveToVaultSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                TextField("Display Name", text: $vaultName)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("Key") {
                    Text(variable.name)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                TextField("Tags (comma-separated)", text: $vaultTags)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    showSaveToVaultSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Save to Vault") {
                    let tags = vaultTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    appState.envVarListVM.saveToVault(variable: variable, name: vaultName, tags: tags)
                    showSaveToVaultSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(vaultName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
}
