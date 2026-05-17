import Foundation

/// User-facing effort the lifter taps after a set. Maps to the Int RPE the
/// existing ProgressionEngine consumes via SetLog.rpe.
enum Effort: String, CaseIterable, Codable, Sendable {
    case easy, solid, hard

    var rpe: Int {
        switch self {
        case .easy: return 6
        case .solid: return 8
        case .hard: return 9
        }
    }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .solid: return "Solid"
        case .hard: return "Hard"
        }
    }

    /// Reverse-bucket a stored RPE back to an effort (for resumed drafts /
    /// prefill display). nil RPE → nil effort.
    init?(rpe: Int?) {
        guard let rpe else { return nil }
        switch rpe {
        case ..<7: self = .easy
        case 7...8: self = .solid
        default: self = .hard
        }
    }
}
