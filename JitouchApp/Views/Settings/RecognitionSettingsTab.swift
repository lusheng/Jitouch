import SwiftUI

struct RecognitionSettingsTab<
    RecognitionSummaryContent: View,
    CharacterRecognitionSettingsContent: View,
    ProfileSelectionContent: View,
    GestureSearchContent: View,
    GestureEditorContent: View
>: View {
    let recognitionSummary: RecognitionSummaryContent
    let characterRecognitionSettings: CharacterRecognitionSettingsContent
    let profileSelection: ProfileSelectionContent
    let gestureSearch: GestureSearchContent
    let gestureEditor: GestureEditorContent

    init(
        @ViewBuilder recognitionSummary: () -> RecognitionSummaryContent,
        @ViewBuilder characterRecognitionSettings: () -> CharacterRecognitionSettingsContent,
        @ViewBuilder profileSelection: () -> ProfileSelectionContent,
        @ViewBuilder gestureSearch: () -> GestureSearchContent,
        @ViewBuilder gestureEditor: () -> GestureEditorContent
    ) {
        self.recognitionSummary = recognitionSummary()
        self.characterRecognitionSettings = characterRecognitionSettings()
        self.profileSelection = profileSelection()
        self.gestureSearch = gestureSearch()
        self.gestureEditor = gestureEditor()
    }

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.recognition.title,
            subtitle: JitouchSettingsPane.recognition.subtitle
        ) {
            recognitionSummary
            characterRecognitionSettings
            profileSelection
            gestureSearch
            gestureEditor
        }
    }
}
