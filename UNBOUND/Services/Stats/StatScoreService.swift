import Foundation

// MARK: - StatScoreServiceProtocol

@MainActor
protocol StatScoreServiceProtocol: AnyObject {
    /// Computes the four home-dashboard axes for the given user.
    /// Pulls from RankService, SessionXPService, SkillProgressService +
    /// SkillGraph. Returns `.empty` on any critical failure — the UI
    /// renders zeros gracefully rather than spinning forever.
    func compute(userId: String, archetype: Archetype) async -> StatScore
}

// MARK: - StatScoreService

@MainActor
final class StatScoreService: StatScoreServiceProtocol {
    static let shared = StatScoreService(
        rank: RankService.shared,
        sessionXP: SessionXPService.shared
    )

    private let rank: RankServiceProtocol
    private let sessionXP: SessionXPServiceProtocol

    // Weekly target we expect a committed user to hit. Used to normalize
    // Stamina — anything under 3 sessions/week reads light, 5+ maxes the
    // density contribution.
    private let weeklyTarget: Double = 5.0

    // How many streak days we credit before the contribution plateaus.
    // Past this the user is "consistently in" — bumping further shouldn't
    // keep dragging Stamina higher.
    private let staminaStreakCeiling: Double = 30.0
    private let vitalityStreakCeiling: Double = 21.0

    // Days of inactivity before Vitality starts bleeding, and the point
    // at which it bottoms out.
    private let vitalityGraceDays: Double = 2.0
    private let vitalityZeroDays: Double = 14.0

    /// Designated initializer. Tests inject mocks; production goes through
    /// `.shared`, which wires the live singletons.
    init(rank: RankServiceProtocol, sessionXP: SessionXPServiceProtocol) {
        self.rank = rank
        self.sessionXP = sessionXP
    }

    func compute(userId: String, archetype: Archetype) async -> StatScore {
        let archetypeRank = await rank.archetypeRank(userId: userId, archetype: archetype)
        let xpRecord = sessionXP.record(userId: userId)

        let strength = strengthScore(from: archetypeRank)
        let stamina = staminaScore(from: xpRecord)
        let technique = techniqueScore()
        let vitality = vitalityScore(from: xpRecord)

        return StatScore(
            strength: strength,
            stamina: stamina,
            technique: technique,
            vitality: vitality,
            computedAt: Date()
        )
    }

    // MARK: - Strength
    //
    // Map the archetype-level sub-rank ordinal (0...17) onto 0...100.
    // A user pinned at E- reads 0. B-rank (ordinal 10) reads ~59. S+
    // (ordinal 17) saturates at 100.

    private func strengthScore(from rank: SubRank) -> Int {
        let fraction = Double(rank.ordinal) / 17.0
        return clampToPercent(fraction * 100.0)
    }

    // MARK: - Stamina
    //
    // 60% weekly density + 40% streak momentum. Both clamped so a 10-
    // session week or a 180-day streak doesn't exceed the ceiling.

    private func staminaScore(from xp: SessionXPRecord) -> Int {
        let weekly = min(Double(xp.weeklyCount) / weeklyTarget, 1.0)
        let streak = min(Double(xp.currentStreak) / staminaStreakCeiling, 1.0)
        return clampToPercent(weekly * 60.0 + streak * 40.0)
    }

    // MARK: - Technique
    //
    // Percent of SkillGraph nodes the user has pushed past .attempting.
    // `.achieved` and `.mastered` both count — they're the "I can do this"
    // states. Reads the live snapshot off SkillProgressService so no
    // duplicate computation.

    private func techniqueScore() -> Int {
        let graph = SkillGraph.shared
        guard !graph.nodes.isEmpty else { return 0 }

        let states = SkillProgressService.shared.nodeStates
        let cleared = states.values.reduce(into: 0) { acc, state in
            if state == .achieved || state == .mastered { acc += 1 }
        }
        let fraction = Double(cleared) / Double(graph.nodes.count)
        return clampToPercent(fraction * 100.0)
    }

    // MARK: - Vitality
    //
    // Readiness proxy: 50% streak momentum + 50% recency decay. A user
    // on a 21-day streak who trained today reads ~100. A user whose
    // last session was 14+ days ago reads 0 regardless of peak streak.
    // Until we wire HealthKit, this is the closest signal we have.

    private func vitalityScore(from xp: SessionXPRecord) -> Int {
        let streak = min(Double(xp.currentStreak) / vitalityStreakCeiling, 1.0)
        let recency = recencyScore(lastSession: xp.lastSessionDate)
        return clampToPercent(streak * 50.0 + recency * 50.0)
    }

    /// 1.0 if the user trained today, linearly decaying after the grace
    /// window, 0 at `vitalityZeroDays` and beyond.
    private func recencyScore(lastSession: Date?) -> Double {
        guard let last = lastSession else { return 0 }
        let days = Date().timeIntervalSince(last) / 86_400
        if days <= vitalityGraceDays { return 1.0 }
        if days >= vitalityZeroDays { return 0 }
        let span = vitalityZeroDays - vitalityGraceDays
        let elapsed = days - vitalityGraceDays
        return max(0, 1.0 - elapsed / span)
    }

    // MARK: - Helpers

    private func clampToPercent(_ value: Double) -> Int {
        Int(max(0, min(100, value.rounded())))
    }
}

// MARK: - MockStatScoreService

@MainActor
final class MockStatScoreService: StatScoreServiceProtocol {
    var override: StatScore = StatScore(
        strength: 78,
        stamina: 72,
        technique: 76,
        vitality: 68,
        computedAt: Date()
    )

    func compute(userId: String, archetype: Archetype) async -> StatScore {
        override
    }
}
