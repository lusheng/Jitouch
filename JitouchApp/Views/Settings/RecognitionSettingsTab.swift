import SwiftUI

struct RecognitionSettingsTab: View {
    let recognitionSummary: AnyView
    let characterRecognitionSettings: AnyView
    let profileSelection: AnyView
    let gestureSearch: AnyView
    let gestureEditor: AnyView

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
