import XCTest
@testable import UNBOUND

@MainActor
final class SkillTierMigrationTests: XCTestCase {
    func testBackfillsTuckBackLeverForExistingStraddleBackLeverUser() {
        let userId = "back-lever-v2"
        let suiteName = "SkillTierMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserSkillTierStore(defaults: defaults)
        var state = UserSkillTierState.empty
        state.perSkill["cl.straddle-back-lever"] = .veteran
        state.rankUpsEarned = SkillTier.veteran.rawValue
        store.save(state, userId: userId)
        defaults.set(true, forKey: "unbound.skillTier.migratedV1.\(userId)")

        let didRun = SkillTierMigration.migrateIfNeeded(
            userId: userId,
            history: [],
            bodyweightKg: 70,
            rankService: StubRankService(),
            store: store,
            defaults: defaults
        )

        let migrated = store.load(userId: userId)
        XCTAssertTrue(didRun)
        XCTAssertEqual(migrated.perSkill["cl.tuck-back-lever"], .veteran)
        XCTAssertEqual(migrated.rankUpsEarned, SkillTier.veteran.rawValue * 2)
        XCTAssertTrue(defaults.bool(forKey: "unbound.skillTier.migratedV2.tuckBackLever.\(userId)"))
    }

    // MARK: - Reinstall restore path
    //
    // A signed-in user who reinstalls the app gets their workout logs back via
    // SyncEngine.restore, but UserDefaults is wiped — including the
    // "unbound.skillTier.migratedV1.<userId>" guard flag and the tier store
    // itself. The migration re-running against the restored history IS the
    // intended reinstall restore for skill tiers, so this test pre-sets
    // NOTHING and asserts the full replay happens.
    func testReinstallWithWipedDefaultsReplaysHistoryAndIsIdempotent() {
        let userId = "reinstall-user"
        let suiteName = "SkillTierMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Fresh suite = wiped device: no flags, empty tier store. Only the
        // synced log history survives the reinstall.
        let store = UserSkillTierStore(defaults: defaults)

        // Two real graph skills the restored history "satisfies". The
        // back-lever chain is excluded so the tuck-back-lever backfill cannot
        // add extra perSkill entries and muddy the ordinal-sum assertion.
        let backLeverChain: Set<String> = [
            "cl.tuck-back-lever", "cl.straddle-back-lever", "cl.full-back-lever"
        ]
        let nodeIds = SkillGraph.shared.nodes.map(\.id).filter { !backLeverChain.contains($0) }
        let forgedSkillId = nodeIds[0]
        let unboundSkillId = nodeIds[1]

        let rankService = MappingRankService(tiersBySkillId: [
            forgedSkillId: .forged,
            unboundSkillId: .unbound
        ])

        let history = [
            ExerciseLogEntry(
                id: "e1", exerciseName: "Pull-Up",
                plannedSets: 3, plannedReps: "5",
                sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 5, rpe: 8, isWarmup: false)],
                skipped: false, notes: nil
            )
        ]

        let didRun = SkillTierMigration.migrateIfNeeded(
            userId: userId,
            history: history,
            bodyweightKg: 70,
            rankService: rankService,
            store: store,
            defaults: defaults
        )

        XCTAssertTrue(didRun, "Wiped defaults must re-run the migration — this IS the reinstall restore path")
        XCTAssertEqual(
            rankService.computeTierCallCount, SkillGraph.shared.nodes.count,
            "Migration must consult every graph skill against the restored history"
        )

        let migrated = store.load(userId: userId)
        XCTAssertEqual(migrated.perSkill[forgedSkillId], .forged)
        XCTAssertEqual(migrated.perSkill[unboundSkillId], .unbound)
        XCTAssertTrue(migrated.ascendantSkills.contains(unboundSkillId))
        // Skills the history does not satisfy stay initiate and are not stored.
        XCTAssertEqual(migrated.perSkill.count, 2)
        XCTAssertEqual(
            migrated.rankUpsEarned,
            SkillTier.forged.rawValue + SkillTier.unbound.rawValue,
            "rankUpsEarned must be the sum of tier ordinals across seeded skills"
        )
        XCTAssertTrue(defaults.bool(forKey: "unbound.skillTier.migratedV1.\(userId)"))

        // Second launch on the same install: the flag is now set, so the
        // migration must not touch the store or recompute anything.
        let callsAfterFirstRun = rankService.computeTierCallCount
        let didRunAgain = SkillTierMigration.migrateIfNeeded(
            userId: userId,
            history: history,
            bodyweightKg: 70,
            rankService: rankService,
            store: store,
            defaults: defaults
        )
        XCTAssertFalse(didRunAgain)
        XCTAssertEqual(rankService.computeTierCallCount, callsAfterFirstRun)
        XCTAssertEqual(store.load(userId: userId), migrated)
    }

    func testBackfillDoesNotOverwriteHigherTuckBackLeverTier() {
        let userId = "back-lever-existing-high"
        let suiteName = "SkillTierMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserSkillTierStore(defaults: defaults)
        var state = UserSkillTierState.empty
        state.perSkill["cl.tuck-back-lever"] = .master
        state.perSkill["cl.straddle-back-lever"] = .forged
        state.rankUpsEarned = SkillTier.master.rawValue + SkillTier.forged.rawValue
        store.save(state, userId: userId)
        defaults.set(true, forKey: "unbound.skillTier.migratedV1.\(userId)")

        let didRun = SkillTierMigration.migrateIfNeeded(
            userId: userId,
            history: [],
            bodyweightKg: 70,
            rankService: StubRankService(),
            store: store,
            defaults: defaults
        )

        let migrated = store.load(userId: userId)
        XCTAssertFalse(didRun)
        XCTAssertEqual(migrated.perSkill["cl.tuck-back-lever"], .master)
        XCTAssertEqual(migrated.rankUpsEarned, state.rankUpsEarned)
    }
}

/// Stub that maps skill ids to tiers only when a non-empty history is
/// supplied, so tests can prove the restored log history is actually threaded
/// through to the per-skill tier computation (not just that something ran).
private final class MappingRankService: RankServiceProtocol {
    private let tiersBySkillId: [String: SkillTier]
    private(set) var computeTierCallCount = 0

    init(tiersBySkillId: [String: SkillTier]) {
        self.tiersBySkillId = tiersBySkillId
    }

    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier {
        computeTierCallCount += 1
        guard !history.isEmpty else { return .initiate }
        return tiersBySkillId[skill.id] ?? .initiate
    }

    func evaluateTierCrossings(log: WorkoutLog, userId: String) async -> [SkillTierAdvance] {
        []
    }

    func state(userId: String) -> UserSkillTierState {
        .empty
    }

    func aggregateTier(userId: String) async -> SkillTier {
        .initiate
    }

    func computeLiftRank(
        entry: ExerciseLogEntry,
        bodyweightKg: Double,
        sex: BiologicalSex?
    ) -> RankTier? {
        nil
    }

    func evaluate(log: WorkoutLog, bodyweightKg: Double, sex: BiologicalSex?) async {}

    func aggregateRank(userId: String) async -> RankTier {
        .initiate
    }
}

private final class StubRankService: RankServiceProtocol {
    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier {
        .initiate
    }

    func evaluateTierCrossings(log: WorkoutLog, userId: String) async -> [SkillTierAdvance] {
        []
    }

    func state(userId: String) -> UserSkillTierState {
        .empty
    }

    func aggregateTier(userId: String) async -> SkillTier {
        .initiate
    }

    func computeLiftRank(
        entry: ExerciseLogEntry,
        bodyweightKg: Double,
        sex: BiologicalSex?
    ) -> RankTier? {
        nil
    }

    func evaluate(log: WorkoutLog, bodyweightKg: Double, sex: BiologicalSex?) async {}

    func aggregateRank(userId: String) async -> RankTier {
        .initiate
    }
}
