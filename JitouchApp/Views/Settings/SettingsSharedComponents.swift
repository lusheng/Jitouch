import SwiftUI

struct SettingsCardStatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        JitouchStatusBadge(title: title, tint: tint)
    }
}

struct SettingsCountBadge: View {
    let count: Int
    let singularLabel: String
    let pluralLabel: String
    let tint: Color

    init(
        count: Int,
        singularLabel: String,
        pluralLabel: String? = nil,
        tint: Color = .secondary
    ) {
        self.count = count
        self.singularLabel = singularLabel
        self.pluralLabel = pluralLabel ?? "\(singularLabel)s"
        self.tint = tint
    }

    var body: some View {
        SettingsCardStatusBadge(
            title: "\(count) \(count == 1 ? singularLabel : pluralLabel)",
            tint: tint
        )
    }
}

struct SettingsMetricsGrid<Content: View>: View {
    let minimumWidth: CGFloat
    let spacing: CGFloat
    let content: Content

    init(
        minimumWidth: CGFloat = 170,
        spacing: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.minimumWidth = minimumWidth
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing)],
            spacing: spacing
        ) {
            content
        }
    }
}

struct SettingsKeyValueItem: Identifiable {
    let label: String
    let value: String

    var id: String { "\(label)|\(value)" }
}

struct SettingsKeyValueGrid: View {
    let items: [SettingsKeyValueItem]
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(
        items: [SettingsKeyValueItem],
        horizontalSpacing: CGFloat = 24,
        verticalSpacing: CGFloat = 8
    ) {
        self.items = items
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing) {
            ForEach(items) { item in
                SettingsKeyValueRow(label: item.label, value: item.value)
            }
        }
    }
}

struct SettingsKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}

struct SettingsEmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
    }
}

struct SettingsSecondaryPlaceholderText: View {
    let text: String

    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
    }
}

struct SettingsBulletNoteRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            SettingsSecondaryPlaceholderText(text: text)
        }
    }
}

struct SettingsMonospacedReadoutSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(text)
                .font(.caption.monospaced())
        }
    }
}
