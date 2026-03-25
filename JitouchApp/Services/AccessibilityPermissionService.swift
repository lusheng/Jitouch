import AppKit
import ApplicationServices

struct AccessibilityPermissionService {
    // The SDK imports kAXTrustedCheckOptionPrompt as a mutable global, which trips
    // Swift 6's concurrency checks. The raw key is stable and matches the CFString.
    private let promptOptionKey = "AXTrustedCheckOptionPrompt"

    func isTrusted(prompt: Bool) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted()
        }

        let options = [promptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
