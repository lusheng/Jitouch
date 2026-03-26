import AppKit
import SwiftUI

struct SettingsProfileSelectionSection: View {
    let device: CommandDevice
    let sets: [ApplicationCommandSet]
    @Binding var selectedSetID: String

    var body: some View {
        SettingsProfileSelectionCard(
            device: device,
            sets: sets,
            selectedSet: selectedSet,
            selectedSetID: $selectedSetID,
            profileTitle: { set in
                set.path.isEmpty ? set.application : "\(set.application) Override"
            },
            profileDescription: { set in
                set.path.isEmpty
                    ? "Changes here apply when no app-specific override matches."
                    : set.path
            }
        )
    }

    private var selectedSet: ApplicationCommandSet? {
        sets.first(where: { $0.id == selectedSetID }) ?? sets.first
    }
}

struct SettingsOverrideManagerSection: View {
    let device: CommandDevice
    let commandSets: [ApplicationCommandSet]
    let currentSelectedSetID: String
    let differenceCount: (ApplicationCommandSet) -> Int
    let onAddOverride: () -> Void
    let onSelectOverride: (String) -> Void
    let onResetOverride: (String) -> Void
    let onOpenApp: (String) -> Void
    let onReveal: (String) -> Void
    let onRemoveOverride: (String) -> Void

    var body: some View {
        SettingsOverrideManagerCard(
            device: device,
            overrides: overrides,
            currentSelectedSetID: currentSelectedSetID,
            differenceCount: differenceCount,
            onAddOverride: onAddOverride,
            onSelectOverride: onSelectOverride,
            onResetOverride: onResetOverride,
            onOpenApp: onOpenApp,
            onReveal: onReveal,
            onRemoveOverride: onRemoveOverride
        )
    }

    private var overrides: [ApplicationCommandSet] {
        commandSets
            .filter { !$0.path.isEmpty }
            .sorted {
                $0.application.localizedCaseInsensitiveCompare($1.application) == .orderedAscending
            }
    }
}

struct SettingsProfileSelectionCard: View {
    let device: CommandDevice
    let sets: [ApplicationCommandSet]
    let selectedSet: ApplicationCommandSet?
    @Binding var selectedSetID: String
    let profileTitle: (ApplicationCommandSet) -> String
    let profileDescription: (ApplicationCommandSet) -> String

    var body: some View {
        JitouchSurfaceCard(
            title: device == .recognition ? "Recognition Profile" : "Profiles",
            subtitle: device == .recognition
                ? "Character mappings usually stay global, but they still use the same profile storage model."
                : "Choose which profile you are actively editing. App-specific override management lives in its own section below.",
            symbol: device == .recognition ? "text.badge.star" : "square.on.square",
            tint: device == .recognition ? .purple : .blue,
            accessory: {
                SettingsCountBadge(count: sets.count, singularLabel: "profile")
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if sets.isEmpty {
                    SettingsSecondaryPlaceholderText(text: "No profiles available yet.")
                } else {
                    Picker("Editing Profile", selection: $selectedSetID) {
                        ForEach(sets) { set in
                            Text(profileTitle(set)).tag(set.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if let selectedSet {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selectedSet.path.isEmpty ? "Default profile" : "App-specific override")
                                .font(.subheadline.weight(.semibold))

                            Text(profileDescription(selectedSet))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }

                    if device == .recognition {
                        SettingsFootnoteText(
                            text: "Character mappings reuse the same profile model, but usually stay global to keep recognition predictable."
                        )
                    } else {
                        SettingsFootnoteText(
                            text: "Use App Overrides below to add app-specific profiles, switch to them, reveal the target app, or remove them."
                        )
                    }
                }
            }
        }
    }
}

struct SettingsOverrideManagerCard: View {
    let device: CommandDevice
    let overrides: [ApplicationCommandSet]
    let currentSelectedSetID: String
    let differenceCount: (ApplicationCommandSet) -> Int
    let onAddOverride: () -> Void
    let onSelectOverride: (String) -> Void
    let onResetOverride: (String) -> Void
    let onOpenApp: (String) -> Void
    let onReveal: (String) -> Void
    let onRemoveOverride: (String) -> Void

    var body: some View {
        JitouchSurfaceCard(
            title: "App Overrides",
            subtitle: "App-specific profiles override the default mappings whenever the matching application is frontmost.",
            symbol: "app.badge",
            tint: .teal,
            accessory: {
                SettingsCountBadge(count: overrides.count, singularLabel: "override")
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsActionRow {
                    Button("Add App Override…", action: onAddOverride)
                        .buttonStyle(.borderedProminent)
                }

                if overrides.isEmpty {
                    SettingsEmptyStateView(
                        title: "No App Overrides Yet",
                        systemImage: "square.on.square.dashed",
                        description: "Create one to give a specific app its own gesture behavior without changing your default profile."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(overrides) { set in
                            SettingsOverrideRow(
                                set: set,
                                isSelected: currentSelectedSetID == set.id,
                                differenceCount: differenceCount(set),
                                onSelect: { onSelectOverride(set.id) },
                                onReset: { onResetOverride(set.id) },
                                onOpenApp: { onOpenApp(set.path) },
                                onReveal: { onReveal(set.path) },
                                onRemove: { onRemoveOverride(set.id) }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct SettingsProfileEditingContextView: View {
    let device: CommandDevice
    let set: ApplicationCommandSet
    let enabledCount: Int
    let overrideCount: Int
    let differenceCount: Int
    let onBackToDefault: () -> Void
    let onResetToDefault: () -> Void
    let onOpenApp: () -> Void
    let onReveal: () -> Void
    let onRemoveOverride: () -> Void

    var body: some View {
        let tint = set.path.isEmpty ? Color.blue : Color.teal

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SettingsApplicationIconBadge(
                    application: set.application,
                    path: set.path,
                    tint: tint,
                    isSelected: true
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(set.path.isEmpty ? "Editing All Applications" : "Editing \(set.application) Override")
                        .font(.subheadline.weight(.semibold))

                    SettingsFootnoteText(
                        text: set.path.isEmpty
                            ? "These mappings apply whenever no app-specific override matches the frontmost app."
                            : "These mappings are only used when \(set.application) is frontmost."
                    )

                    if !set.path.isEmpty {
                        Text(set.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Spacer(minLength: 12)

                JitouchStatusBadge(
                    title: "\(enabledCount) enabled",
                    tint: tint
                )
            }

            if !set.path.isEmpty {
                SettingsFootnoteText(
                    text: differenceCount == 0
                        ? "This override currently matches the All Applications profile."
                        : "\(differenceCount) gesture\(differenceCount == 1 ? "" : "s") currently differ from All Applications."
                )
            }

            SettingsActionRow(spacing: 10) {
                if set.path.isEmpty {
                    SettingsFootnoteText(
                        text: overrideCount == 0
                            ? "No app-specific overrides are configured for this device yet."
                            : "\(overrideCount) app override\(overrideCount == 1 ? "" : "s") currently branch from this default profile."
                    )
                } else {
                    Button("Back to Default", action: onBackToDefault)
                        .buttonStyle(.bordered)

                    Button("Reset to Default", action: onResetToDefault)
                        .buttonStyle(.bordered)

                    Button("Open App", action: onOpenApp)
                        .buttonStyle(.bordered)

                    Button("Reveal", action: onReveal)
                        .buttonStyle(.bordered)

                    Button("Remove Override", role: .destructive, action: onRemoveOverride)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
        )
    }
}

struct SettingsGestureSearchCard: View {
    let device: CommandDevice
    @Binding var searchText: String

    var body: some View {
        JitouchSurfaceCard(
            title: "Find a Gesture",
            subtitle: "Filter by gesture name or current command so you can jump straight to the binding you want.",
            symbol: "magnifyingglass",
            tint: .cyan
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(
                    searchPlaceholder,
                    text: $searchText
                )
                .textFieldStyle(.roundedBorder)

                SettingsFootnoteText(
                    text: "Search matches gesture names and currently assigned commands, so you can jump straight to one mapping instead of scrolling through the whole profile."
                )
            }
        }
    }

    private var searchPlaceholder: String {
        switch device {
        case .trackpad:
            "Search trackpad gestures or commands"
        case .magicMouse:
            "Search Magic Mouse gestures or commands"
        case .recognition:
            "Search characters or recognition commands"
        }
    }
}

private struct SettingsOverrideRow: View {
    let set: ApplicationCommandSet
    let isSelected: Bool
    let differenceCount: Int
    let onSelect: () -> Void
    let onReset: () -> Void
    let onOpenApp: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let enabledCount = set.gestures.filter(\.isEnabled).count
        let totalCount = set.gestures.count

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                SettingsApplicationIconBadge(
                    application: set.application,
                    path: set.path,
                    tint: isSelected ? .blue : .teal,
                    isSelected: isSelected
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(set.application)
                            .font(.subheadline.weight(.semibold))

                        if isSelected {
                            SettingsCardStatusBadge(title: "Editing", tint: .blue)
                        }
                    }

                    Text(set.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Text("\(enabledCount) enabled gestures · \(totalCount) stored mappings · \(differenceCount) changed from default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)
            }

            SettingsActionRow(spacing: 10) {
                if isSelected {
                    Button("Currently Editing", action: onSelect)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Edit Override", action: onSelect)
                        .buttonStyle(.bordered)
                }

                Button("Open App", action: onOpenApp)
                    .buttonStyle(.bordered)

                Button("Reset", action: onReset)
                    .buttonStyle(.bordered)

                Button("Reveal", action: onReveal)
                    .buttonStyle(.bordered)

                Button("Remove", role: .destructive, action: onRemove)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.blue.opacity(0.28) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct SettingsApplicationIconBadge: View {
    let application: String
    let path: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(isSelected ? 0.16 : 0.12))

            if let icon = applicationIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            } else {
                Image(systemName: path.isEmpty ? "square.on.square" : "app")
                    .foregroundStyle(tint)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityLabel(Text(application))
    }

    private var applicationIcon: NSImage? {
        guard !path.isEmpty else { return nil }

        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        guard FileManager.default.fileExists(atPath: standardizedPath) else { return nil }

        let icon = NSWorkspace.shared.icon(forFile: standardizedPath)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }
}
