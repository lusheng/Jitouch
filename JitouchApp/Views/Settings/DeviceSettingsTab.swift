import SwiftUI

struct DeviceSettingsTab<
    SummaryContent: View,
    ProfileSelectionContent: View,
    OverrideManagerContent: View,
    GestureSearchContent: View,
    GestureEditorContent: View
>: View {
    let title: String
    let subtitle: String
    let summary: SummaryContent
    let profileSelection: ProfileSelectionContent
    let overrideManager: OverrideManagerContent
    let gestureSearch: GestureSearchContent
    let gestureEditor: GestureEditorContent

    init(
        title: String,
        subtitle: String,
        @ViewBuilder summary: () -> SummaryContent,
        @ViewBuilder profileSelection: () -> ProfileSelectionContent,
        @ViewBuilder overrideManager: () -> OverrideManagerContent,
        @ViewBuilder gestureSearch: () -> GestureSearchContent,
        @ViewBuilder gestureEditor: () -> GestureEditorContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.summary = summary()
        self.profileSelection = profileSelection()
        self.overrideManager = overrideManager()
        self.gestureSearch = gestureSearch()
        self.gestureEditor = gestureEditor()
    }

    var body: some View {
        SettingsPageScaffold(title: title, subtitle: subtitle) {
            summary
            profileSelection
            overrideManager
            gestureSearch
            gestureEditor
        }
    }
}
