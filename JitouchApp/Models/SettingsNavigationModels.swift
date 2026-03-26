import Foundation

enum JitouchSettingsPane: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case trackpad
    case magicMouse
    case recognition
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .trackpad:
            "Trackpad"
        case .magicMouse:
            "Magic Mouse"
        case .recognition:
            "Character Recognition"
        case .diagnostics:
            "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            "Controls, setup, and essential runtime status."
        case .trackpad:
            "Trackpad gesture profiles and per-app overrides."
        case .magicMouse:
            "Magic Mouse gesture profiles and per-app overrides."
        case .recognition:
            "Drawing recognition controls, mappings, and button behavior."
        case .diagnostics:
            "Calibration, device state, and debugging visibility."
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            "square.grid.2x2"
        case .trackpad:
            "rectangle.and.hand.point.up.left"
        case .magicMouse:
            "computermouse"
        case .recognition:
            "character.cursor.ibeam"
        case .diagnostics:
            "waveform.path.ecg"
        }
    }
}

enum JitouchSettingsSectionAnchor: String, Hashable, Sendable {
    case overviewGeneralControls
    case overviewPermissions
    case overviewQuickActions
    case overviewSetupGuide
    case diagnosticsRecentActivity
    case diagnosticsCoverage
    case diagnosticsCompatibility
}
