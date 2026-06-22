import XCTest
@testable import UNBOUND

/// Stage 0 reproduction + Stage 1 guard for "the rank you see should advance
/// when you log."
///
/// Today a skill's DISPLAYED tier lives in `UserSkillTierStore`, and the only
/// production writer from logged history is `SkillTierMigration`, which is
/// guarded to run exactly once per user (`migratedV1`). The intended live path,
/// `RankService.evaluateTierCrossings`, has no production caller. So after the
/// one-time backfill, logging more work never moves the stored tier — the rank
/// freezes. `testStoredTierFreezesAfterMigration` documents that bug.
@MainActor
final class LiveSkillRankAdvanceTests: XCTestCase {

    private let bodyweightKg = 70.0
    private let hollowNodeId = "cl.hollow-body-30"

    private func set(durationSeconds: Int) -> SetLog {
        SetLog(id: UUID().uuidString, setNumber: 1, weightKg: nil, reps: 0,
               rpe: 8, isWarmup: false, durationSeconds: durationSeconds)
    }

    private func hollowHistory(seconds: Int) -> [ExerciseLogEntry] {
        [ExerciseLogEntry(
            id: "entry-hollow", exerciseName: "hollow body hold", movementId: nil,
            rankStandardMovementId: hollowNodeId, plannedSets: 1, plannedReps: "—",
            sets: [set(durationSeconds: seconds)], skipped: false, notes: nil
        )]
    }

    private func isolatedStore() -> (UserSkillTierStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.live-rank.\(UUID().uuidString)")!
        return (UserSkillTierStore(defaults: defaults), defaults)
    }

    /// THE BUG: a user migrates with little/no history (tier = initiate), then
    /// logs a strong hollow hold. The history now computes to a high tier, but
    /// the stored tier the rank library reads is still initiate, because the
    /// once-guarded migration won't recompute and nothing else writes it.
    func testStoredTierFreezesAfterMigration() throws {
        let node = try XCTUnwrap(SkillGraph.shared.node(id: hollowNodeId))
        let (store, defaults) = isolatedStore()
        let userId = "freeze-user"

        // First launch: migrate on an empty history → initiate.
        SkillTierMigration.migrateIfNeeded(
            userId: userId, history: [], bodyweightKg: bodyweightKg,
            rankService: RankService.shared, store: store, defaults: defaults
        )
        XCTAssertEqual(store.load(userId: userId).tier(for: hollowNodeId), .initiate)

        // User now logs a strong 60s hollow hold.
        let history = hollowHistory(seconds: 60)
        let earnedTier = RankService.shared.computeTier(
            skill: node, history: history, bodyweightKg: bodyweightKg
        )
        XCTAssertGreaterThan(earnedTier.rawValue, SkillTier.initiate.rawValue,
                             "60s hollow hold should compute to a tier above initiate")

        // Migration is guarded → re-running with the rich history is a no-op.
        SkillTierMigration.migrateIfNeeded(
            userId: userId, history: history, bodyweightKg: bodyweightKg,
            rankService: RankService.shared, store: store, defaults: defaults
        )

        // BUG: the displayed/stored tier is still initiate even though the
        // logged work earns `earnedTier`.
        XCTAssertEqual(
            store.load(userId: userId).tier(for: hollowNodeId), .initiate,
            "Reproduction: stored tier is frozen at initiate despite earning \(earnedTier)"
        )
    }

    // MARK: - Stage 1: the live advance path

    /// THE FIX: the pure tier-advance computation (which the completion flow now
    /// calls via `evaluateTierCrossings`) takes the logged history forward and
    /// advances the stored tier to what the work actually earns.
    func testLoggingAdvancesStoredTier() throws {
        let node = try XCTUnwrap(SkillGraph.shared.node(id: hollowNodeId))
        let history = hollowHistory(seconds: 60)
        let earnedTier = RankService.shared.computeTier(
            skill: node, history: history, bodyweightKg: bodyweightKg
        )
        XCTAssertGreaterThan(earnedTier.rawValue, SkillTier.initiate.rawValue)

        let (advances, newState) = RankService.shared.tierAdvances(
            fullHistory: history,
            bodyweightKg: bodyweightKg,
            priorState: .empty
        )

        XCTAssertEqual(newState.tier(for: hollowNodeId), earnedTier,
                       "After logging, the stored hollow tier should equal the earned tier")
        XCTAssertTrue(advances.contains { $0.skillId == hollowNodeId && $0.to == earnedTier },
                      "An advance event for hollow should be emitted")
    }

    /// Re-running the advance with the already-advanced state is a no-op (never
    /// demotes, never double-advances) — safe for completion re-flushes.
    func testTierAdvanceIsIdempotentAndNeverDemotes() throws {
        let history = hollowHistory(seconds: 60)
        let (_, advancedState) = RankService.shared.tierAdvances(
            fullHistory: history, bodyweightKg: bodyweightKg, priorState: .empty
        )
        let (secondAdvances, secondState) = RankService.shared.tierAdvances(
            fullHistory: history, bodyweightKg: bodyweightKg, priorState: advancedState
        )
        XCTAssertTrue(secondAdvances.isEmpty, "Re-running on the same history must not advance again")
        XCTAssertEqual(secondState.tier(for: hollowNodeId), advancedState.tier(for: hollowNodeId))

        // A weaker later history must not pull the tier back down.
        let (weakAdvances, weakState) = RankService.shared.tierAdvances(
            fullHistory: hollowHistory(seconds: 10), bodyweightKg: bodyweightKg, priorState: advancedState
        )
        XCTAssertTrue(weakAdvances.isEmpty)
        XCTAssertEqual(weakState.tier(for: hollowNodeId), advancedState.tier(for: hollowNodeId),
                       "Never demotes")
    }

    // MARK: - Stage 2: cross-surface evidence

    private func entry(name: String, movementId: String?, seconds: Int) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: "entry-\(name)", exerciseName: name, movementId: movementId,
            rankStandardMovementId: movementId ?? name, plannedSets: 1, plannedReps: "—",
            sets: [set(durationSeconds: seconds)], skipped: false, notes: nil
        )
    }

    /// The criterion movement names the hold "hollow body hold". A log of the
    /// library "Hollow Hold" (the same movement) must satisfy it; a log of
    /// "Hollow Rock" (a different movement that merely associates) must not.
    func testProofMatcherCountsTheSkillsOwnMovementButNotAssociates() {
        XCTAssertTrue(
            MovementProofMatcher.entry(
                entry(name: "Hollow Hold", movementId: "exercise.hollow-hold", seconds: 60),
                satisfies: "hollow body hold"
            ),
            "Library 'Hollow Hold' is the hollow-body movement and must count"
        )
        XCTAssertFalse(
            MovementProofMatcher.entry(
                entry(name: "Hollow Rock", movementId: "exercise.hollow-rock", seconds: 60),
                satisfies: "hollow body hold"
            ),
            "'Hollow Rock' is a distinct movement and must NOT count toward the hollow-body hold"
        )
    }

    /// End-to-end: logging the library exercise now advances the skill rank
    /// (it never did before Stage 2), while logging the distinct Hollow Rock
    /// leaves the hollow-body skill untouched.
    func testLibraryExerciseAdvancesSkillButRockDoesNot() {
        let (libraryAdvances, libraryState) = RankService.shared.tierAdvances(
            fullHistory: [entry(name: "Hollow Hold", movementId: "exercise.hollow-hold", seconds: 60)],
            bodyweightKg: bodyweightKg, priorState: .empty
        )
        XCTAssertTrue(libraryAdvances.contains { $0.skillId == hollowNodeId },
                      "Logging the library Hollow Hold should advance Hollow Body")
        XCTAssertGreaterThan(libraryState.tier(for: hollowNodeId).rawValue, SkillTier.initiate.rawValue)

        let (rockAdvances, rockState) = RankService.shared.tierAdvances(
            fullHistory: [entry(name: "Hollow Rock", movementId: "exercise.hollow-rock", seconds: 60)],
            bodyweightKg: bodyweightKg, priorState: .empty
        )
        XCTAssertFalse(rockAdvances.contains { $0.skillId == hollowNodeId },
                       "Logging Hollow Rock must NOT advance Hollow Body")
        XCTAssertEqual(rockState.tier(for: hollowNodeId), .initiate)
    }
}
