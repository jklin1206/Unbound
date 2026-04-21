import Foundation

// MARK: - MuscleGroupTierState
//
// Per-user, per-muscle-group tier snapshot. Parallel in shape to
// ProgressionFamilyState. Stored as one row per (userId, muscleGroup).
// The MuscleGroupTierCalculator writes this after each scan and on
// workout-log events that change recent-performance signals.

struct MuscleGroupTierState: Codable, Sendable, Identifiable {
    var id: String { "\(userId):\(muscleGroup.rawValue)" }

    let userId: String
    let muscleGroup: MuscleGroup

    /// Current tier derived from the combined score signal.
    var tier: MuscleGroupTier

    /// 0–100 scalar the tier was derived from. Stored for debugging and
    /// for animating progress within a tier (how close are you to the
    /// next rank).
    var score: Int

    /// Most recent scan contribution (0–100). Separated so the UI can
    /// show "scan says X, lifting says Y".
    var scanBaseline: Int

    /// Log-derived boost (can be negative). 0 when there's no recent
    /// signal for this muscle group.
    var logBoost: Int

    var updatedAt: Date
}

// MARK: - Rank-up event

struct MuscleGroupTierChange: Identifiable, Sendable {
    let id = UUID()
    let userId: String
    let muscleGroup: MuscleGroup
    let previousTier: MuscleGroupTier
    let newTier: MuscleGroupTier
    let at: Date

    var didRankUp: Bool { newTier.rank > previousTier.rank }
}
