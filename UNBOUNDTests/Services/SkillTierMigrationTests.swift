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
