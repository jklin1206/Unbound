import Foundation

// MARK: - RewardComputer
//
// Central service for diffing user state across a training event and
// emitting a `RewardSummary`. Every caller (QuickLog, Session-end,
// future Scan-complete, etc.) hits this surface so reward semantics
// stay consistent.
//
// Pattern:
//   1. Caller takes a snapshot BEFORE writing the new log
//   2. Caller writes the new log + awards XP (existing path)
//   3. Caller calls `after(snapshot:...)` with the just-logged set
//      and the post-write context — service derives PR / rank-up /
//      badge unlocks / first-set and returns a summary
//   4. Caller adapts the summary into `WorkoutRewardSequenceView`
//
// Snapshot is pure data so it captures cleanly across async boundaries.

@MainActor
final class RewardComputer {

    static let shared = RewardComputer()
    private init() {}

    private let database = DatabaseService.shared
    private var logger: LoggingService { LoggingService.shared }

    // MARK: - Snapshot

    /// State captured before the user's new log lands. The diff against
    /// the post-write state is what powers PR / rank-up / first-set
    /// detection.
    struct Snapshot: Sendable {
        let userId: String
        let skillId: String
        let isHoldBased: Bool
        let derivedRank: RankTitle
        let unlockedBadgeIds: Set<String>
        let priorBest: Double           // dimension-aware: reps, kg, OR seconds
        let hadAnyPriorLog: Bool
    }

    /// Build a snapshot before the write. Reads:
    ///   - user's current EARNED tier for the skill (`UserSkillTierState.perSkill`)
    ///   - user's currently unlocked badge ids
    ///   - prior-best dimension value across all past logs for this skill
    ///   - whether ANY prior log exists (drives first-set detection)
    func before(
        skillId: String,
        isHoldBased: Bool,
        userId: String,
        badgeService: BadgeServiceProtocol
    ) async -> Snapshot {
        let derived = UserSkillTierStore.shared.load(userId: userId).perSkill[skillId] ?? .initiate

        let unlockedIds = Set(badgeService.unlockedBadges(userId: userId).map(\.id))

        let (best, hasPrior) = await fetchPriorBest(
            skillId: skillId,
            isHoldBased: isHoldBased,
            userId: userId
        )

        return Snapshot(
            userId: userId,
            skillId: skillId,
            isHoldBased: isHoldBased,
            derivedRank: derived,
            unlockedBadgeIds: unlockedIds,
            priorBest: best,
            hadAnyPriorLog: hasPrior
        )
    }

    // MARK: - Compute summary

    /// Evaluate everything earned by the just-completed event and
    /// return a `RewardSummary`. Caller decides whether to present.
    ///
    /// `bestSet` is the most-impressive set logged in the event — for
    /// QuickLog it's the only set; for a session it's chosen via
    /// `bestSet(from:isHoldBased:)`.
    func after(
        snapshot: Snapshot,
        skillTitle: String,
        bestSet: LoggedSet,
        xpGained: Int,
        unlockedBadges: [Badge]
    ) async -> RewardSummary {
        var summary = RewardSummary()
        summary.xpGained = xpGained
        summary.skillTitle = skillTitle

        // PR — diff dimension-aware
        if let pr = detectPR(
            snapshot: snapshot,
            currentSet: bestSet,
            skillTitle: skillTitle
        ) {
            summary.personalRecord = pr
        }

        // Rank-up — re-read the earned tier after the write (RankService /
        // tier evaluation persists `perSkill` from the logged proof).
        let after = UserSkillTierStore.shared.load(userId: snapshot.userId).perSkill[snapshot.skillId] ?? .initiate
        if after.ordinal > snapshot.derivedRank.ordinal {
            summary.rankUp = RankUp(
                skillId: snapshot.skillId,
                skillTitle: skillTitle,
                fromTier: snapshot.derivedRank,
                toTier: after
            )
        }

        // Badges — caller passes the result of BadgeService.evaluate(...).
        // We filter out anything that was ALREADY unlocked at snapshot
        // time, so we only celebrate true new unlocks.
        let trulyNew = unlockedBadges.filter { !snapshot.unlockedBadgeIds.contains($0.id) }
        summary.badgeUnlocks = trulyNew.map { badge in
            BadgeUnlock(
                id: badge.id,
                title: badge.displayName,
                subtitle: badge.description,
                assetName: badgeAssetName(for: badge.id)
            )
        }

        // First-set-ever — only when the user had ZERO prior logs on
        // this skill AND this is a real attempt (some reps or hold time).
        if !snapshot.hadAnyPriorLog && isMeaningfulSet(bestSet, isHoldBased: snapshot.isHoldBased) {
            summary.firstSet = FirstSet(
                skillId: snapshot.skillId,
                skillTitle: skillTitle
            )
        }

        return summary
    }

    // MARK: - Best-set picker (used by session-end)

    /// Pick the most-impressive set from a session's logged exercises.
    /// Policy:
    ///   - Hold-based skill → max(holdSeconds)
    ///   - Weighted set     → max(weightKg), tiebreak by reps
    ///   - Bodyweight       → max(reps)
    /// Returns nil when the session logged nothing.
    static func bestSet(from log: SessionLog, isHoldBased: Bool) -> LoggedSet? {
        let allSets = log.exercises.flatMap(\.sets)
        guard !allSets.isEmpty else { return nil }

        if isHoldBased {
            return allSets.max(by: { ($0.holdSeconds ?? 0) < ($1.holdSeconds ?? 0) })
        }

        let weighted = allSets.filter { ($0.weightKg ?? 0) > 0 }
        if !weighted.isEmpty {
            return weighted.max(by: { lhs, rhs in
                let lw = lhs.weightKg ?? 0
                let rw = rhs.weightKg ?? 0
                if lw != rw { return lw < rw }
                return lhs.reps < rhs.reps
            })
        }

        return allSets.max(by: { $0.reps < $1.reps })
    }

    // MARK: - PR detection

    private func detectPR(
        snapshot: Snapshot,
        currentSet: LoggedSet,
        skillTitle: String
    ) -> PersonalRecord? {
        // No prior data → no PR (first-set surface handles that case
        // via summary.firstSet instead).
        guard snapshot.priorBest > 0 else { return nil }

        if snapshot.isHoldBased {
            let secs = currentSet.holdSeconds ?? 0
            guard Double(secs) > snapshot.priorBest else { return nil }
            return PersonalRecord(
                kind: .maxHold,
                exerciseName: skillTitle,
                value: Double(secs),
                previousBest: snapshot.priorBest
            )
        }

        if let weight = currentSet.weightKg, weight > snapshot.priorBest {
            return PersonalRecord(
                kind: .maxWeight,
                exerciseName: skillTitle,
                value: weight,
                previousBest: snapshot.priorBest
            )
        }

        let reps = currentSet.reps
        if Double(reps) > snapshot.priorBest {
            return PersonalRecord(
                kind: .maxReps,
                exerciseName: skillTitle,
                value: Double(reps),
                previousBest: snapshot.priorBest
            )
        }

        return nil
    }

    private func isMeaningfulSet(_ set: LoggedSet, isHoldBased: Bool) -> Bool {
        if isHoldBased { return (set.holdSeconds ?? 0) > 0 }
        return set.reps > 0
    }

    // MARK: - Persistence reads

    /// Returns (priorBest, hadAnyPriorLog). For hold-based skills, best
    /// is `max(holdSeconds)`. For others, prefers max weight if any
    /// weighted set exists, else max reps. Returns 0 + false when no
    /// prior logs exist.
    private func fetchPriorBest(
        skillId: String,
        isHoldBased: Bool,
        userId: String
    ) async -> (best: Double, hasPrior: Bool) {
        do {
            let logs: [SessionLog] = try await database.query(
                collection: "sessionLogs",
                field: "skillId",
                isEqualTo: skillId,
                orderBy: "createdAt",
                descending: true,
                limit: 50
            )
            let mySets = logs
                .filter { $0.userId == userId }
                .flatMap { $0.exercises }
                .flatMap { $0.sets }

            guard !mySets.isEmpty else { return (0, false) }

            if isHoldBased {
                return (Double(mySets.compactMap(\.holdSeconds).max() ?? 0), true)
            }
            let weight = mySets.compactMap(\.weightKg).max() ?? 0
            if weight > 0 { return (weight, true) }
            return (Double(mySets.map(\.reps).max() ?? 0), true)
        } catch {
            logger.log(
                "RewardComputer: prior-best query failed: \(error.localizedDescription)",
                level: .warning
            )
            return (0, false)
        }
    }

    // MARK: - Badge asset mapping

    /// Maps `Badge.id` to the BadgeArt imageset name. Catalog ids use
    /// dot-separated keys (e.g. "session.10"); imageset names use
    /// underscores (e.g. "badge_art_sessions_10"). Mapping codifies the
    /// translation in one place.
    private func badgeAssetName(for badgeId: String) -> String {
        let normalized = badgeId
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return "badge_art_\(normalized)"
    }
}
