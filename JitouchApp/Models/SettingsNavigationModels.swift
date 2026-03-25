import Foundation

enum JitouchSettingsPane: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case permissions
    case trackpad
    case magicMouse
    case recognition
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .permissions:
            "Permissions & Startup"
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
            "Core status, controls, and migration progress."
        case .permissions:
            "Accessibility access, login items, and runtime readiness."
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
        case .permissions:
            "lock.shield"
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
