import Foundation

// MARK: - StatScore
//
// Four-axis summary of a user's physical state, surfaced on the home
// dashboard as a 2×2 readout. Each axis is a clamped 0...100 integer so
// the UI can render a consistent grid.
//
//   Strength   — peak output. Aggregated sub-rank ordinal of the user's
//                emphasis lifts (or calisthenic family state for bodyweight
//                archetypes). A B-rank lifter reads ~60, S-rank ~95.
//   Stamina    — sustained output. Weekly session density blended with
//                current streak momentum. Drops when training tapers.
//   Technique  — skill mastery. Percentage of `SkillGraph` nodes that the
//                user has pushed to `.achieved` or `.mastered`.
//   Vitality   — recovery / readiness proxy. Streak + recency composite
//                with a hard drop-off past 7 days of inactivity. (Future:
//                blend HealthKit HRV + sleep when integrated.)
//
// All four are directional signals — this is dashboard eye-candy backed
// by real data, not a clinical score. Re-derived on every home appear
// + on `.sessionXPUpdated`.

struct StatScore: Sendable, Equatable {
    let strength: Int
    let stamina: Int
    let technique: Int
    let vitality: Int
    let computedAt: Date

    static let empty = StatScore(
        strength: 0,
        stamina: 0,
        technique: 0,
        vitality: 0,
        computedAt: .distantPast
    )
}
