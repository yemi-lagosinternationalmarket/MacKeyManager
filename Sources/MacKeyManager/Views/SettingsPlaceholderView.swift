import SwiftUI
import MacKeyManagerLib

struct SettingsPlaceholderView: View {
    var body: some View {
        Form {
            Section("General") {
                Text("Settings will be available in a future update.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
