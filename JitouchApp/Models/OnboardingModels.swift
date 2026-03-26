import Foundation

struct OnboardingChecklistItem: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let isComplete: Bool
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case accessibility
    case startup
    case devices
    case finish

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome:
            "Welcome"
        case .accessibility:
            "Accessibility"
        case .startup:
            "Startup"
        case .devices:
            "Devices"
        case .finish:
            "Finish"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "What is already ready in the standalone app."
        case .accessibility:
            "Grant the permission that unlocks runtime control."
        case .startup:
            "Choose how Jitouch should start with macOS."
        case .devices:
            "Check active devices and profile families."
        case .finish:
            "Wrap up and jump into daily use."
        }
    }

    var symbolName: String {
        switch self {
        case .welcome:
            "sparkles"
        case .accessibility:
            "lock.shield"
        case .startup:
            "power.circle"
        case .devices:
            "hand.tap"
        case .finish:
            "checkmark.circle"
        }
    }
}
