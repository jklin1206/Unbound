import Foundation

// MARK: - LiftRank
//
// Per-user-per-lift persistent rank. Written by RankService whenever a
// logged session crosses a sub-rank threshold. `peakRank` floors decay so
// a user who once hit B+ can never drop below B+ — only `currentRank`
// moves during inactivity.

struct LiftRank: Codable, Identifiable, Sendable, Hashable {
    /// "{userId}:{exerciseKey}" — stable composite key for DatabaseService.
    let id: String
    let userId: String
    let exerciseKey: String
    let displayName: String
    var currentRank: SubRank
    var peakRank: SubRank
    var lastAdvanceAt: Date
    var lastActivityAt: Date

    init(
        userId: String,
        exerciseKey: String,
        displayName: String,
        currentRank: SubRank,
        peakRank: SubRank? = nil,
        lastAdvanceAt: Date = Date(),
        lastActivityAt: Date = Date()
    ) {
        let key = exerciseKey.trimmingCharacters(in: .whitespaces).lowercased()
        self.id = "\(userId):\(key)"
        self.userId = userId
        self.exerciseKey = key
        self.displayName = displayName
        self.currentRank = currentRank
        self.peakRank = peakRank ?? currentRank
        self.lastAdvanceAt = lastAdvanceAt
        self.lastActivityAt = lastActivityAt
    }
}

// MARK: - Archetype emphasis lifts
//
// Aggregate archetype rank = rounded average of sub-rank ordinals across
// these emphasis lifts. Missing lifts default to `.eMinus`.

extension Archetype {
    /// Lifts used to compute the archetype aggregate rank. Canonical
    /// exerciseKeys — matched case-insensitive in RankService.
    var emphasisLifts: [String] {
        switch self {
        case .heavyDuty:
            return ["back squat", "deadlift", "bench press", "overhead press"]
        case .leanCut:
            return ["pullup", "pushup", "dip"]
        case .vTaper:
            return ["overhead press", "weighted pullup", "bench press"]
        case .shredded:
            return ["pullup", "dip", "l-sit"]
        }
    }
}
