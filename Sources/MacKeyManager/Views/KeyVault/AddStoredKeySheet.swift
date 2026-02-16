import SwiftUI
import MacKeyManagerLib

struct AddStoredKeySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var key = ""
    @State private var value = ""
    @State private var notes = ""
    @State private var tags = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Key to Vault")
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

            Form {
                TextField("Display Name (e.g. Stripe API Key)", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Variable Key (e.g. STRIPE_API_KEY)", text: $key)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: key) { _, newValue in
                        let cleaned = newValue.uppercased()
                            .replacingOccurrences(of: " ", with: "_")
                        if cleaned != newValue {
                            key = cleaned
                        }
                        validateKey()
                    }

                SecureField("Value", text: $value)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                TextField("Notes (optional)", text: $notes)
                    .textFieldStyle(.roundedBorder)

                TextField("Tags (comma-separated)", text: $tags)
                    .textFieldStyle(.roundedBorder)

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

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
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save to Vault") {
                    addKey()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: hasExpiry ? 480 : 430)
    }

    private var isValid: Bool {
        !name.isEmpty && !key.isEmpty && !value.isEmpty && validationError == nil
    }

    private func validateKey() {
        if key.isEmpty {
            validationError = nil
            return
        }
        if !ShellParser.isValidVariableName(key) {
            validationError = "Invalid key name. Use letters, numbers, and underscores only."
            return
        }
        validationError = nil
    }

    private func addKey() {
        guard isValid else { return }
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let expiry: Date? = hasExpiry ? expiryDate : nil
        appState.keyVaultService.addKey(
            name: name,
            key: key,
            value: value,
            notes: notes.isEmpty ? nil : notes,
            tags: tagList,
            expiryDate: expiry
        )
        dismiss()
    }
}
