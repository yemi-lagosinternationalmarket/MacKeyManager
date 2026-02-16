import SwiftUI
import MacKeyManagerLib

struct EnvVarListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var vm = appState.envVarListVM

        VStack(spacing: 0) {
            // Toolbar area
            HStack(spacing: 12) {
                SearchBar(text: $vm.searchText)

                Picker("Sort", selection: $vm.sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Variable list
            if vm.filteredVariables.isEmpty {
                emptyState
            } else {
                List(selection: $vm.selectedVariableID) {
                    ForEach(vm.filteredVariables) { variable in
                        EnvVarRowView(
                            variable: variable,
                            isSelected: vm.selectedVariableID == variable.id
                        )
                        .tag(variable.id)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Bottom bar
            HStack {
                Button {
                    vm.showingAddSheet = true
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
        .sheet(isPresented: $vm.showingDiffPreview) {
            DiffPreviewSheet()
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
