import SwiftUI
import MacKeyManagerLib

struct StoredKeyDetailView: View {
    @Environment(AppState.self) private var appState
    let storedKey: StoredKey

    @State private var editName: String = ""
    @State private var editKey: String = ""
    @State private var editValue: String = ""
    @State private var editNotes: String = ""
    @State private var editTags: String = ""
    @State private var isValueRevealed = false
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    @State private var showDeleteConfirm = false
    @State private var showImportSheet = false

    var body: some View {
        Form {
            Section("Key Details") {
                LabeledContent("Display Name") {
                    TextField("Name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Variable Key") {
                    TextField("KEY_NAME", text: $editKey)
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

                LabeledContent("Notes") {
                    TextField("Optional notes", text: $editNotes)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Tags") {
                    TextField("Comma-separated tags", text: $editTags)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Expiry") {
                Toggle("Set expiry date", isOn: $hasExpiry)

                if hasExpiry {
                    DatePicker(
                        "Expiry date",
                        selection: $expiryDate,
                        in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                        displayedComponents: .date
                    )
                }
            }

            Section("Info") {
                LabeledContent("Created") {
                    Text(storedKey.createdDate, style: .date)
                        .foregroundStyle(.secondary)
                }

                if let lastUsed = storedKey.lastUsedDate {
                    LabeledContent("Last Used") {
                        Text(lastUsed, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Actions") {
                HStack(spacing: 12) {
                    Button("Save") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!hasChanges)

                    Button("Copy Value") {
                        ClipboardManager.copy(editValue)
                    }

                    Button("Import into Project...") {
                        showImportSheet = true
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
        .onChange(of: storedKey.id) { _, _ in resetFields() }
        .alert("Delete Key", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                appState.keyVaultService.removeKey(id: storedKey.id)
            }
        } message: {
            Text("Are you sure you want to delete \"\(storedKey.name)\" from the vault?")
        }
        .sheet(isPresented: $showImportSheet) {
            ImportKeySheet(storedKey: storedKey)
                .environment(appState)
        }
    }

    private var hasChanges: Bool {
        editName != storedKey.name ||
        editKey != storedKey.key ||
        editValue != storedKey.value ||
        editNotes != (storedKey.notes ?? "") ||
        editTags != storedKey.tags.joined(separator: ", ") ||
        hasExpiry != (storedKey.expiryDate != nil) ||
        (hasExpiry && storedKey.expiryDate != nil && expiryDate != storedKey.expiryDate!)
    }

    private func resetFields() {
        editName = storedKey.name
        editKey = storedKey.key
        editValue = storedKey.value
        editNotes = storedKey.notes ?? ""
        editTags = storedKey.tags.joined(separator: ", ")
        isValueRevealed = false
        if let date = storedKey.expiryDate {
            hasExpiry = true
            expiryDate = date
        } else {
            hasExpiry = false
            expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        }
    }

    private func saveChanges() {
        let tags = editTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let expiry: Date? = hasExpiry ? expiryDate : nil
        appState.keyVaultService.updateKey(
            id: storedKey.id,
            name: editName,
            key: editKey,
            value: editValue,
            notes: editNotes.isEmpty ? nil : editNotes,
            tags: tags,
            expiryDate: expiry
        )
    }
}

struct ImportKeySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let storedKey: StoredKey

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import Key into Project")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            List {
                Button {
                    importIntoGlobal()
                    dismiss()
                } label: {
                    Label("Global (.zshrc)", systemImage: "globe")
                }

                ForEach(appState.projectVM.projects) { project in
                    Button {
                        importIntoProject(project)
                        dismiss()
                    } label: {
                        Label(project.name, systemImage: "folder")
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 350, height: 300)
    }

    private func importIntoGlobal() {
        appState.keyVaultService.importKey(storedKeyID: storedKey.id, into: appState.zshrcService)
    }

    private func importIntoProject(_ project: Project) {
        let service = appState.envVarListVM.dotEnvService(for: project.envFilePath, projectName: project.name)
        appState.keyVaultService.importKey(storedKeyID: storedKey.id, into: service)
    }
}
