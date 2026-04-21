import Foundation

// MARK: - MuscleGroupTier
//
// E/D/C/B/A/S tier for each muscle group. Mirrors the RankBadge visual
// language. Threshold bands are applied to a 0-100 scalar (the
// MuscleGroupAssessment.currentScore, optionally boosted by recent logs).
//
// NOTE (Chunk 2 scope): tier compute is deterministic from scan + logs.
// Tier changes fire a `muscleGroupTierChanged` notification so views can
// celebrate a rank-up (future: shareable card). Not wired in Chunk 2 —
// flagged as a seam for Chunk 6 (badges / rank-up bloom).

enum MuscleGroupTier: String, CaseIterable, Codable, Sendable {
    case e, d, c, b, a, s

    var letter: String {
        rawValue.uppercased()
    }

    /// Ordered rank (S = 5, E = 0) — used for "did tier go up?" comparisons.
    var rank: Int {
        switch self {
        case .e: return 0
        case .d: return 1
        case .c: return 2
        case .b: return 3
        case .a: return 4
        case .s: return 5
        }
    }

    /// Human-readable descriptor shown in secondary UI.
    var caption: String {
        switch self {
        case .e: return "Beginning"
        case .d: return "Developing"
        case .c: return "Competent"
        case .b: return "Strong"
        case .a: return "Advanced"
        case .s: return "Elite"
        }
    }

    /// Derive a tier from a 0–100 scalar. Bands chosen so ~mid-50s reads
    /// as a clear "C" (average-intermediate), which matches how most
    /// first-time scans come in. S is rare on purpose.
    static func from(score: Int) -> MuscleGroupTier {
        switch score {
        case ..<30:  return .e
        case ..<50:  return .d
        case ..<65:  return .c
        case ..<80:  return .b
        case ..<90:  return .a
        default:     return .s
        }
    }
}

extension Notification.Name {
    static let muscleGroupTierChanged = Notification.Name("unbound.muscleGroupTierChanged")
}
