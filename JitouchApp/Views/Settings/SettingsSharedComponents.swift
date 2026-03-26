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
