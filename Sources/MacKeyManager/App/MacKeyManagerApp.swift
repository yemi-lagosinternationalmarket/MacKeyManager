import SwiftUI
import MacKeyManagerLib

@main
struct MacKeyManagerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Variable") {
                    appState.envVarListVM.showingAddSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .toolbar) {
                Button("Save Changes") {
                    appState.envVarListVM.prepareSave()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!appState.envVarListVM.isDirty)

                Button("Find") {
                    // Focus will be handled by the search bar
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        MenuBarExtra("MacKeyManager", systemImage: "key.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsPlaceholderView()
        }
    }
}
