import SwiftUI

struct DiagnosticsSettingsTab: View {
    let diagnosticsSummary: AnyView
    let calibration: AnyView
    let deviceDiagnostics: AnyView
    let compatibilityNotes: AnyView

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.diagnostics.title,
            subtitle: JitouchSettingsPane.diagnostics.subtitle
        ) {
            diagnosticsSummary
            calibration
            deviceDiagnostics
            compatibilityNotes
        }
    }
}
