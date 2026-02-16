import SwiftUI
import MacKeyManagerLib

struct EnvVarListView: View {
    @Environment(AppState.self) private var appState
    @State private var saveToVaultVariable: EnvironmentVariable?

    var body: some View {
        @Bindable var vm = appState.envVarListVM

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchBar(text: $vm.searchText)

                Picker("Sort", selection: $vm.sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                if vm.hasAnyExpiry {
                    Picker("Expiry", selection: $vm.expiryFilter) {
                        ForEach(ExpiryFilter.allCases, id: \.self) { filter in
                            let count = vm.expiryFilterCounts[filter] ?? 0
                            if filter == .all {
                                Text(filter.rawValue).tag(filter)
                            } else if count > 0 {
                                Text("\(filter.rawValue) (\(count))").tag(filter)
                            } else {
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if vm.filteredVariables.isEmpty {
                emptyState
            } else {
                List(selection: $vm.selectedVariableID) {
                    ForEach(vm.filteredVariables) { variable in
                        let entry = vm.catalogEntry(for: variable)
                        EnvVarRowView(
                            variable: variable,
                            isSelected: vm.selectedVariableID == variable.id,
                            expiryStatus: entry?.expiryStatus,
                            onSaveToVault: {
                                saveToVaultVariable = variable
                            }
                        )
                        .tag(variable.id)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Menu {
                    Button {
                        vm.showingAddSheet = true
                    } label: {
                        Label("Add Variable", systemImage: "plus.square")
                    }
                    Button {
                        vm.showingAddFromVaultSheet = true
                    } label: {
                        Label("Add from Vault", systemImage: "lock.shield")
                    }
                    .disabled(appState.keyVaultService.storedKeys.isEmpty)
                } label: {
                    Label("Add Variable", systemImage: "plus")
                }

                Spacer()

                if vm.isDirty {
                    Button("Save Changes") {
                        vm.prepareSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Text("\(vm.filteredVariables.count) variables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 380)
        .sheet(isPresented: $vm.showingAddSheet) {
            AddVariableSheet()
                .environment(appState)
        }
        .sheet(isPresented: $vm.showingAddFromVaultSheet) {
            AddFromVaultSheet()
                .environment(appState)
        }
        .sheet(isPresented: $vm.showingDiffPreview) {
            DiffPreviewSheet()
                .environment(appState)
        }
        .sheet(item: $saveToVaultVariable) { variable in
            SaveToVaultFromListSheet(variable: variable)
                .environment(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteVariable)) { notification in
            if let id = notification.object as? UUID {
                vm.deleteVariable(id: id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            if appState.envVarListVM.searchText.isEmpty {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No Variables")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Add a variable or import a project to get started.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No Results")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("No variables match \"\(appState.envVarListVM.searchText)\"")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SaveToVaultFromListSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let variable: EnvironmentVariable
    @State private var vaultName = ""
    @State private var vaultTags = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save to Vault")
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
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save to Vault") {
                    let tags = vaultTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    appState.envVarListVM.saveToVault(variable: variable, name: vaultName, tags: tags)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(vaultName.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
        .onAppear { vaultName = variable.name }
    }
}
