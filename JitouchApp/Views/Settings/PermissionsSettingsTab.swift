import SwiftUI

struct PermissionsSettingsTab: View {
    let permissionsAndStartup: AnyView

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.permissions.title,
            subtitle: JitouchSettingsPane.permissions.subtitle
        ) {
            permissionsAndStartup
        }
    }
}
