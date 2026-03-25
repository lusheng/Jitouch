import AppKit
import SwiftUI

struct ShortcutRecorderField: View {
    @Binding var keyCode: Int
    @Binding var modifierFlags: Int

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggleRecording) {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                        .foregroundStyle(isRecording ? .orange : .blue)

                    Text(isRecording ? "Press Shortcut" : ShortcutFormatter.displayName(keyCode: keyCode, modifierFlags: modifierFlags))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(minWidth: 220, alignment: .leading)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isRecording ? Color.orange : Color.secondary.opacity(0.25), lineWidth: 1)
            )

            if keyCode != 0 || modifierFlags != 0 {
                Button("Clear") {
                    keyCode = 0
                    modifierFlags = 0
                }
                .buttonStyle(.bordered)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if !isRecording {
                return event
            }

            switch event.type {
            case .flagsChanged:
                return nil
            case .keyDown:
                let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

                if event.keyCode == 53 {
                    stopRecording()
                    return nil
                }

                if event.keyCode == 51 && modifiers.isEmpty {
                    keyCode = 0
                    modifierFlags = 0
                    stopRecording()
                    return nil
                }

                keyCode = Int(event.keyCode)
                modifierFlags = Int(modifiers.rawValue)
                stopRecording()
                return nil
            default:
                return event
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

private enum ShortcutFormatter {
    static func displayName(keyCode: Int, modifierFlags: Int) -> String {
        guard keyCode != 0 || modifierFlags != 0 else {
            return "Record Shortcut"
        }

        let modifiers = modifierSymbols(flags: modifierFlags)
        let key = keyName(for: keyCode)
        return modifiers + key
    }

    private static func modifierSymbols(flags: Int) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(flags))
        var result = ""
        if flags.contains(.command) { result += "⌘" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.control) { result += "⌃" }
        return result
    }

    private static func keyName(for keyCode: Int) -> String {
        let knownKeys: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Esc", 55: "⌘", 56: "⇧", 57: "Caps",
            58: "⌥", 59: "⌃", 60: "Right ⇧", 61: "Right ⌥", 62: "Right ⌃",
            63: "Fn", 64: "F17", 65: ".", 67: "*", 69: "+", 71: "Clear",
            72: "Volume Up", 73: "Volume Down", 74: "Mute", 75: "/", 76: "Enter",
            78: "-", 79: "F18", 80: "F19", 81: "=", 82: "0", 83: "1", 84: "2",
            85: "3", 86: "4", 87: "5", 88: "6", 89: "7", 91: "8", 92: "9",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
            111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "PgUp",
            117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
            121: "PgDn", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]

        return knownKeys[keyCode] ?? "Key \(keyCode)"
    }
}
