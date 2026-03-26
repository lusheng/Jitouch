import SwiftUI

struct DeviceSettingsTab: View {
    let title: String
    let subtitle: String
    let summary: AnyView
    let profileSelection: AnyView
    let overrideManager: AnyView
    let gestureSearch: AnyView
    let gestureEditor: AnyView

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
