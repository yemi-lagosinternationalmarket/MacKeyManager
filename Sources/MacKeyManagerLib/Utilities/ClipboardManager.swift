import AppKit
import Foundation

public enum ClipboardManager {
    private static var clearTimer: DispatchWorkItem?

    /// Copy a string to the system clipboard with optional auto-clear after 60 seconds.
    public static func copy(_ string: String, autoClearSeconds: Int = 60) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)

        // Cancel any existing timer
        clearTimer?.cancel()

        // Schedule auto-clear
        if autoClearSeconds > 0 {
            let work = DispatchWorkItem {
                // Only clear if the clipboard still contains our string
                if let current = pasteboard.string(forType: .string), current == string {
                    pasteboard.clearContents()
                }
            }
            clearTimer = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + .seconds(autoClearSeconds),
                execute: work
            )
        }
    }
}
