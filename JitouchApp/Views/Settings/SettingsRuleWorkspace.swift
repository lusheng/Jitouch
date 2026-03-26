import SwiftUI

struct SettingsProfileRuleItem: Identifiable, Hashable {
    let set: ApplicationCommandSet
    let differenceCount: Int

    var id: String { self.set.id }

    var enabledCount: Int {
        self.set.gestures.filter(\.isEnabled).count
    }
}

enum SettingsGestureRuleState: Hashable {
    case enabled
    case inherited
    case disabled

    var title: String {
        switch self {
        case .enabled:
            "Enabled"
        case .inherited:
            "Inherited"
        case .disabled:
            "Disabled"
        }
    }

    var tint: Color {
        switch self {
        case .enabled:
            .green
        case .inherited:
            .orange
        case .disabled:
            .secondary
        }
    }
}

struct SettingsGestureRuleItem: Identifiable, Hashable {
    let gesture: String
    let state: SettingsGestureRuleState
    let currentCommand: GestureCommand
    let displayCommand: GestureCommand
    let canAdd: Bool
    let canRemove: Bool

    var id: String { gesture }
}

struct SettingsRuleWorkspace<InspectorContent: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let showsProfileRules: Bool
    let profileItems: [SettingsProfileRuleItem]
    let selectedProfileID: String
    let onSelectProfile: (String) -> Void
    let onAddProfile: (() -> Void)?
    let onRemoveProfile: (() -> Void)?
    @Binding var searchText: String
    let searchPlaceholder: String
    let enabledGestureItems: [SettingsGestureRuleItem]
    let availableGestureItems: [SettingsGestureRuleItem]
    let selectedGestureItem: SettingsGestureRuleItem?
    let onSelectGesture: (String) -> Void
    let addGestureOptions: [String]
    let onAddGesture: (String) -> Void
    let onRemoveGesture: () -> Void
    let inspector: InspectorContent

    init(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        showsProfileRules: Bool,
        profileItems: [SettingsProfileRuleItem] = [],
        selectedProfileID: String = "",
        onSelectProfile: @escaping (String) -> Void = { _ in },
        onAddProfile: (() -> Void)? = nil,
        onRemoveProfile: (() -> Void)? = nil,
        searchText: Binding<String>,
        searchPlaceholder: String,
        enabledGestureItems: [SettingsGestureRuleItem],
        availableGestureItems: [SettingsGestureRuleItem],
        selectedGestureItem: SettingsGestureRuleItem?,
        onSelectGesture: @escaping (String) -> Void,
        addGestureOptions: [String],
        onAddGesture: @escaping (String) -> Void,
        onRemoveGesture: @escaping () -> Void,
        @ViewBuilder inspector: () -> InspectorContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.tint = tint
        self.showsProfileRules = showsProfileRules
        self.profileItems = profileItems
        self.selectedProfileID = selectedProfileID
        self.onSelectProfile = onSelectProfile
        self.onAddProfile = onAddProfile
        self.onRemoveProfile = onRemoveProfile
        self._searchText = searchText
        self.searchPlaceholder = searchPlaceholder
        self.enabledGestureItems = enabledGestureItems
        self.availableGestureItems = availableGestureItems
        self.selectedGestureItem = selectedGestureItem
        self.onSelectGesture = onSelectGesture
        self.addGestureOptions = addGestureOptions
        self.onAddGesture = onAddGesture
        self.onRemoveGesture = onRemoveGesture
        self.inspector = inspector()
    }

    var body: some View {
        JitouchSurfaceCard(
            title: title,
            subtitle: subtitle,
            symbol: symbol,
            tint: tint
        ) {
            HStack(alignment: .top, spacing: 16) {
                if showsProfileRules {
                    profileRulesPanel
                        .frame(width: 260)
                }

                gestureRulesPanel
                    .frame(width: showsProfileRules ? 320 : 360)

                inspectorPanel
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var profileRulesPanel: some View {
        SettingsWorkspacePanel(
            title: "Profile / App Rules",
            subtitle: "Select the default profile or an app override, then use +/- below to manage them."
        ) {
            if profileItems.isEmpty {
                SettingsEmptyStateView(
                    title: "No Profiles Available",
                    systemImage: "square.on.square.dashed",
                    description: "Profiles will appear here once command mappings are loaded."
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(profileItems) { item in
                        SettingsWorkspaceProfileRow(
                            item: item,
                            isSelected: item.id == selectedProfileID,
                            onSelect: { onSelectProfile(item.id) }
                        )
                    }
                }
            }

            SettingsWorkspaceToolbar {
                if let onAddProfile {
                    Button(action: onAddProfile) {
                        Image(systemName: "plus")
                    }
                    .help("Add App Override")
                }

                if let onRemoveProfile {
                    Button(action: onRemoveProfile) {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedProfileID.isEmpty || selectedProfileID == "All Applications")
                    .help("Remove Selected Override")
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var gestureRulesPanel: some View {
        SettingsWorkspacePanel(
            title: "Gesture Rules",
            subtitle: "Select a rule to inspect, filter the list, or use +/- to add and remove active mappings."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField(searchPlaceholder, text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if enabledGestureItems.isEmpty && availableGestureItems.isEmpty {
                    SettingsEmptyStateView(
                        title: "No Matching Rules",
                        systemImage: "magnifyingglass",
                        description: "Try a different search term or clear the filter."
                    )
                } else {
                    if !enabledGestureItems.isEmpty {
                        SettingsWorkspaceSectionHeader(
                            title: "Enabled",
                            count: enabledGestureItems.count
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(enabledGestureItems) { item in
                                SettingsWorkspaceGestureRow(
                                    item: item,
                                    isSelected: selectedGestureItem?.gesture == item.gesture,
                                    onSelect: { onSelectGesture(item.gesture) }
                                )
                            }
                        }
                    }

                    if !availableGestureItems.isEmpty {
                        if !enabledGestureItems.isEmpty {
                            Divider()
                        }

                        SettingsWorkspaceSectionHeader(
                            title: availableSectionTitle,
                            count: availableGestureItems.count
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(availableGestureItems) { item in
                                SettingsWorkspaceGestureRow(
                                    item: item,
                                    isSelected: selectedGestureItem?.gesture == item.gesture,
                                    onSelect: { onSelectGesture(item.gesture) }
                                )
                            }
                        }
                    }
                }
            }

            SettingsWorkspaceToolbar {
                Menu {
                    if addGestureOptions.isEmpty {
                        Text("No rules available to add")
                    } else {
                        ForEach(addGestureOptions, id: \.self) { gesture in
                            Button(gesture) {
                                onAddGesture(gesture)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(addGestureOptions.isEmpty)

                Button(action: onRemoveGesture) {
                    Image(systemName: "minus")
                }
                .disabled(!(selectedGestureItem?.canRemove ?? false))

                Spacer(minLength: 0)

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var inspectorPanel: some View {
        SettingsWorkspacePanel(
            title: "Inspector",
            subtitle: "Use the selected profile and rule context to fine-tune actions, shortcuts, URLs, or files."
        ) {
            inspector
        }
    }

    private var availableSectionTitle: String {
        availableGestureItems.contains(where: { $0.state == .inherited })
            ? "Disabled / Inherited"
            : "Disabled"
    }
}

private struct SettingsWorkspacePanel<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

private struct SettingsWorkspaceToolbar<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.top, 4)
    }
}

private struct SettingsWorkspaceSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            SettingsCountBadge(count: count, singularLabel: "rule")
        }
    }
}

private struct SettingsWorkspaceProfileRow: View {
    let item: SettingsProfileRuleItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                SettingsApplicationIconBadge(
                    application: item.set.application,
                    path: item.set.path,
                    tint: isSelected ? .blue : .teal,
                    isSelected: isSelected
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.set.application)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if item.set.path.isEmpty {
                        SettingsFootnoteText(
                            text: "Base profile used whenever no app-specific override matches.",
                            tint: .secondary
                        )
                    } else {
                        Text(item.set.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    SettingsFootnoteText(
                        text: item.set.path.isEmpty
                            ? "\(item.enabledCount) enabled rules"
                            : "\(item.enabledCount) enabled rules · \(item.differenceCount) changed"
                    )
                }

                Spacer(minLength: 8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.10) : Color.white.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.blue.opacity(0.26) : Color.black.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsWorkspaceGestureRow: View {
    let item: SettingsGestureRuleItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.gesture)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    SettingsCardStatusBadge(
                        title: item.state.title,
                        tint: item.state.tint
                    )
                }

                SettingsFootnoteText(
                    text: settingsGestureRuleSummary(for: item),
                    tint: .secondary
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.indigo.opacity(0.10) : Color.white.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.indigo.opacity(0.26) : Color.black.opacity(0.04),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

func settingsGestureCommandSummary(_ command: GestureCommand) -> String {
    switch command.commandKind {
    case .action:
        return command.command == "-" ? "No action selected" : command.command
    case .shortcut:
        return ShortcutFormatter.displayName(keyCode: command.keyCode, modifierFlags: command.modifierFlags)
    case .openURL:
        return (command.openURL?.isEmpty == false) ? command.openURL! : "No URL selected"
    case .openFile:
        if let path = command.openFilePath, !path.isEmpty {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "No file selected"
    }
}

private func settingsGestureRuleSummary(for item: SettingsGestureRuleItem) -> String {
    let displaySummary = settingsGestureCommandSummary(item.displayCommand)

    switch item.state {
    case .enabled:
        return displaySummary
    case .inherited:
        return "Inherited from All Applications • \(displaySummary)"
    case .disabled:
        if item.canRemove && item.currentCommand.command != "-" {
            return "Disabled • \(settingsGestureCommandSummary(item.currentCommand))"
        }
        return "No active rule in this profile"
    }
}
