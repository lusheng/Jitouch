import SwiftUI

struct OverviewSettingsTab: View {
    let hero: AnyView
    let metrics: AnyView
    let quickActions: AnyView
    let onboardingGuide: AnyView
    let setupChecklist: AnyView
    let generalSettings: AnyView
    let commandCoverage: AnyView
    let lastErrorView: AnyView?

    var body: some View {
        SettingsPageScaffold(
            title: JitouchSettingsPane.overview.title,
            subtitle: JitouchSettingsPane.overview.subtitle
        ) {
            hero
            metrics
            quickActions
            onboardingGuide
            setupChecklist
            generalSettings
            commandCoverage

            if let lastErrorView {
                lastErrorView
            }
        }
    }
}
