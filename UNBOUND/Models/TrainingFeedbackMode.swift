// UNBOUND/Models/TrainingFeedbackMode.swift
import Foundation

enum TrainingFeedbackMode: String, Codable, CaseIterable, Identifiable {
    case silent
    case quick
    case detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .silent: return "Silent"
        case .quick: return "Quick check"
        case .detailed: return "Detailed"
        }
    }

    var description: String {
        switch self {
        case .silent: return "No feedback taps. Just log reps and weight."
        case .quick: return "One tap per exercise after your top set."
        case .detailed: return "Tap after every set. For serious lifters."
        }
    }

    /// Used by the progression engine. Silent returns 0 so `hitTargetRPE` always passes.
    var defaultTargetRPE: Int {
        switch self {
        case .silent: return 0
        case .quick, .detailed: return 7
        }
    }

    /// Defaults based on the user's self-reported training experience.
    /// `.never` and `.tried` → `.silent` (can't accurately rate difficulty)
    /// `.used` and `.current` → `.quick` (can self-assess, but don't force detailed tracking)
    /// Users can promote themselves to `.detailed` in Settings.
    static func `default`(for experience: Experience) -> TrainingFeedbackMode {
        switch experience {
        case .never, .tried: return .silent
        case .used, .current: return .quick
        }
    }
}
