import AppKit
import SwiftUI

struct SettingsGestureEditingSection<GestureEditorContent: View>: View {
    let device: CommandDevice
    let selectedSet: ApplicationCommandSet?
    let overrideCount: Int
    let differenceCount: Int
    let searchText: String
    let activeGestures: [String]
    let inactiveGestures: [String]
    let onBackToDefault: () -> Void
    let onResetToDefault: () -> Void
    let onOpenApp: () -> Void
    let onReveal: () -> Void
    let onRemoveOverride: () -> Void
    let gestureEditor: (String) -> GestureEditorContent

    init(
        device: CommandDevice,
        selectedSet: ApplicationCommandSet?,
        overrideCount: Int,
        differenceCount: Int,
        searchText: String,
        activeGestures: [String],
        inactiveGestures: [String],
        onBackToDefault: @escaping () -> Void,
        onResetToDefault: @escaping () -> Void,
        onOpenApp: @escaping () -> Void,
        onReveal: @escaping () -> Void,
        onRemoveOverride: @escaping () -> Void,
        @ViewBuilder gestureEditor: @escaping (String) -> GestureEditorContent
    ) {
        self.device = device
        self.selectedSet = selectedSet
        self.overrideCount = overrideCount
        self.differenceCount = differenceCount
        self.searchText = searchText
        self.activeGestures = activeGestures
        self.inactiveGestures = inactiveGestures
        self.onBackToDefault = onBackToDefault
        self.onResetToDefault = onResetToDefault
        self.onOpenApp = onOpenApp
        self.onReveal = onReveal
        self.onRemoveOverride = onRemoveOverride
        self.gestureEditor = gestureEditor
    }

    var body: some View {
        JitouchSurfaceCard(
            title: "Gesture Mappings",
            subtitle: "Enable only the gestures you care about, then assign actions, shortcuts, URLs, or file launches.",
            symbol: "wand.and.stars",
            tint: .indigo
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let selectedSet {
                    SettingsProfileEditingContextView(
                        device: device,
                        set: selectedSet,
                        enabledCount: selectedSet.gestures.filter(\.isEnabled).count,
                        overrideCount: overrideCount,
                        differenceCount: differenceCount,
                        onBackToDefault: onBackToDefault,
                        onResetToDefault: onResetToDefault,
                        onOpenApp: onOpenApp,
                        onReveal: onReveal,
                        onRemoveOverride: onRemoveOverride
                    )

                    if isFiltering {
                        SettingsFootnoteText(
                            text: "Showing \(activeGestures.count + inactiveGestures.count) matching gestures for “\(searchText)”"
                        )
                    }

                    if activeGestures.isEmpty && !isFiltering {
                        Text("No enabled mappings in this profile yet. Open the list below and turn on the gestures you want.")
                            .foregroundStyle(.secondary)
                    } else if !activeGestures.isEmpty {
                        Text(isFiltering ? "Matching Enabled Gestures" : "Enabled")
                            .font(.headline)

                        ForEach(activeGestures, id: \.self) { gesture in
                            gestureEditor(gesture)
                        }
                    }

                    if !inactiveGestures.isEmpty && !isFiltering {
                        Divider()

                        DisclosureGroup("More Gestures (\(inactiveGestures.count))") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(inactiveGestures, id: \.self) { gesture in
                                    gestureEditor(gesture)
                                }
                            }
                            .padding(.top, 10)
                        }
                    } else if !inactiveGestures.isEmpty {
                        Divider()

                        Text("Matching Disabled Gestures")
                            .font(.headline)

                        ForEach(inactiveGestures, id: \.self) { gesture in
                            gestureEditor(gesture)
                        }
                    } else if activeGestures.isEmpty && isFiltering {
                        SettingsEmptyStateView(
                            title: "No Matching Gestures",
                            systemImage: "magnifyingglass",
                            description: "Try another search term or clear the filter."
                        )
                    }
                } else {
                    Text("Pick a profile to start editing gesture bindings.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct SettingsGestureEditorCard: View {
    let device: CommandDevice
    let gesture: String
    @Binding var command: GestureCommand
    let onRevealFilePath: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gesture)
                        .font(.headline)

                    Text(commandSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Enabled", isOn: isEnabledBinding)
                    .controlSize(.small)
            }

            Picker("Type", selection: commandKindBinding) {
                ForEach(GestureCommandKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            SettingsFootnoteText(text: commandKindDescription)

            commandConfiguration
        }
        .padding(14)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var commandConfiguration: some View {
        switch command.commandKind {
        case .action:
            VStack(alignment: .leading, spacing: 12) {
                if !recommendedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                            ForEach(recommendedActions, id: \.self) { action in
                                Button {
                                    actionBinding.wrappedValue = action
                                } label: {
                                    HStack {
                                        Image(systemName: action == command.command ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(action == command.command ? .blue : .secondary)
                                        Text(action)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(action == command.command ? Color.blue.opacity(0.10) : Color(nsColor: .windowBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(action == command.command ? Color.blue.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                Picker("All Actions", selection: actionBinding) {
                    ForEach(CommandCatalog.actionCommandGroups) { group in
                        Section(group.title) {
                            ForEach(group.commands, id: \.self) { action in
                                Text(action == "-" ? "No Action" : action).tag(action)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)

                if command.command != "-" {
                    SettingsFootnoteText(text: "Selected action: \(command.command)")
                }
            }
        case .shortcut:
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRecorderField(
                    keyCode: keyCodeBinding,
                    modifierFlags: modifierFlagsBinding
                )

                SettingsFootnoteText(
                    text: "Click the field, then press the shortcut you want. Press Escape to cancel or Delete to clear it."
                )
            }
        case .openURL:
            VStack(alignment: .leading, spacing: 8) {
                SettingsActionRow(spacing: 10) {
                    TextField(
                        "https://example.com",
                        text: openURLBinding
                    )
                    .textFieldStyle(.roundedBorder)

                    Button("Open Test URL", action: openURLPreview)
                        .buttonStyle(.bordered)
                        .disabled(!isOpenURLValid)
                }

                SettingsFootnoteText(
                    text: "Use a full URL including the scheme. This is useful for dashboards, docs, or deep links you want under a gesture."
                )
            }
        case .openFile:
            VStack(alignment: .leading, spacing: 8) {
                SettingsActionRow(spacing: 10) {
                    TextField(
                        "/Applications/Safari.app",
                        text: openFilePathBinding
                    )
                    .textFieldStyle(.roundedBorder)

                    Button("Browse…", action: chooseOpenFilePath)
                        .buttonStyle(.bordered)

                    if let path = command.openFilePath, !path.isEmpty {
                        Button("Reveal") {
                            onRevealFilePath(path)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingsFootnoteText(
                    text: "Point the gesture at an app, document, or script on disk. `Browse…` is usually faster than pasting full paths."
                )
            }
        }
    }

    private var recommendedActions: [String] {
        CommandCatalog.recommendedActions(for: device, gesture: gesture)
    }

    private var commandSummary: String {
        let summary: String

        switch command.commandKind {
        case .action:
            summary = command.command == "-" ? "No action selected" : command.command
        case .shortcut:
            summary = ShortcutFormatter.displayName(keyCode: command.keyCode, modifierFlags: command.modifierFlags)
        case .openURL:
            summary = (command.openURL?.isEmpty == false) ? command.openURL! : "No URL selected"
        case .openFile:
            if let path = command.openFilePath, !path.isEmpty {
                summary = URL(fileURLWithPath: path).lastPathComponent
            } else {
                summary = "No file selected"
            }
        }

        return command.isEnabled ? summary : "Disabled • \(summary)"
    }

    private var commandKindDescription: String {
        switch command.commandKind {
        case .action:
            "Run one of Jitouch's built-in actions like Mission Control, tab switching, clicks, or window management."
        case .shortcut:
            "Send a keyboard shortcut exactly as if you pressed it on the keyboard."
        case .openURL:
            "Open a web page or app deep link using a full URL."
        case .openFile:
            "Open an app, document, or script from disk."
        }
    }

    private var isOpenURLValid: Bool {
        guard let url = URL(string: command.openURL ?? ""), let scheme = url.scheme, !scheme.isEmpty else {
            return false
        }

        return true
    }

    private var isEnabledBinding: Binding<Bool> {
        Binding(
            get: { command.isEnabled },
            set: { command.isEnabled = $0 }
        )
    }

    private var commandKindBinding: Binding<GestureCommandKind> {
        Binding(
            get: { command.commandKind },
            set: { kind in
                switch kind {
                case .action:
                    command.isAction = true
                    command.command = CommandCatalog.supportedActionCommands.first(where: { $0 != "-" }) ?? "-"
                    command.openURL = nil
                    command.openFilePath = nil
                case .shortcut:
                    command.isAction = false
                    command.command = "Shortcut"
                    command.openURL = nil
                    command.openFilePath = nil
                case .openURL:
                    command.isAction = true
                    command.command = "Open URL"
                    command.openURL = command.openURL ?? ""
                    command.openFilePath = nil
                case .openFile:
                    command.isAction = true
                    command.command = "Open File"
                    command.openFilePath = command.openFilePath ?? ""
                    command.openURL = nil
                }
            }
        )
    }

    private var actionBinding: Binding<String> {
        Binding(
            get: { command.command },
            set: { action in
                command.isAction = true
                command.command = action
                command.openURL = nil
                command.openFilePath = nil
            }
        )
    }

    private var keyCodeBinding: Binding<Int> {
        Binding(
            get: { command.keyCode },
            set: { command.keyCode = max(0, $0) }
        )
    }

    private var modifierFlagsBinding: Binding<Int> {
        Binding(
            get: { command.modifierFlags },
            set: { command.modifierFlags = max(0, $0) }
        )
    }

    private var openURLBinding: Binding<String> {
        Binding(
            get: { command.openURL ?? "" },
            set: { url in
                command.isAction = true
                command.command = "Open URL"
                command.openURL = url
                command.openFilePath = nil
            }
        )
    }

    private var openFilePathBinding: Binding<String> {
        Binding(
            get: { command.openFilePath ?? "" },
            set: { path in
                command.isAction = true
                command.command = "Open File"
                command.openFilePath = path
                command.openURL = nil
            }
        )
    }

    private func openURLPreview() {
        guard let url = URL(string: command.openURL ?? "") else { return }
        NSWorkspace.shared.open(url)
    }

    private func chooseOpenFilePath() {
        guard let selectedPath = Self.chooseOpenFilePath(currentPath: command.openFilePath ?? "") else { return }
        openFilePathBinding.wrappedValue = selectedPath
    }

    private static func chooseOpenFilePath(currentPath: String) -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose File or Application"
        panel.prompt = "Use Path"
        panel.message = "Pick an app, document, or script to launch from this gesture."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if !currentPath.isEmpty {
            let currentURL = URL(fileURLWithPath: currentPath).standardizedFileURL
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: currentURL.path, isDirectory: &isDirectory) {
                panel.directoryURL = isDirectory.boolValue ? currentURL : currentURL.deletingLastPathComponent()
            }
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return url.standardizedFileURL.path
    }
}
