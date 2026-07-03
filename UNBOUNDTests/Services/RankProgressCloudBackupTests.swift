import XCTest
@testable import UNBOUND

/// Covers the cloud-restore seam for the trial-confirmed rank + per-lift tiers:
/// seeding the local stores from a server profile when local is empty, and the
/// conservative never-regress merge when local already carries rank progress.
@MainActor
final class RankProgressCloudBackupTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var trialStore: OverallRankTrialStore!
    private var liftTierStore: LiftTierService!
    private let backup = RankProgressCloudBackup()

    override func setUp() {
        super.setUp()
        suiteName = "RankProgressCloudBackupTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        // No backup wired: seeding must never fire a cloud write of its own.
        trialStore = OverallRankTrialStore(defaults: defaults)
        liftTierStore = LiftTierService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func attempt(
        id: String,
        targetRank: RankTitle,
        passed: Bool,
        completedAt: Date
    ) -> OverallRankTrialAttempt {
        OverallRankTrialAttempt(
            id: id,
            userId: "u1",
            definitionId: "gate",
            targetRank: targetRank,
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt,
            performanceLogId: id,
            passed: passed,
            movementAPGained: 12.5,
            overallLevelXPGained: 30
        )
    }

    private func profile(
        overallRankTrials: OverallRankTrialProgress?,
        liftTiers: [String: SkillTier]?
    ) -> UserProfile {
        var profile = UserProfile(
            id: "u1",
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0
        )
        profile.overallRankTrials = overallRankTrials
        profile.liftTiers = liftTiers
        return profile
    }

    // MARK: - (a) server-seed-when-local-empty

    func test_seed_adopts_server_copy_when_local_stores_are_empty() {
        let serverAttempt = attempt(
            id: "a1",
            targetRank: .forged,
            passed: true,
            completedAt: Date(timeIntervalSince1970: 1_000)
        )
        let serverProfile = profile(
            overallRankTrials: OverallRankTrialProgress(highestPassedRank: .forged, attempts: [serverAttempt]),
            liftTiers: ["bench press": .veteran, "deadlift": .novice]
        )

        // Precondition: local is empty.
        XCTAssertEqual(trialStore.load(userId: "u1").currentRank, .initiate)
        XCTAssertEqual(liftTierStore.tier(lift: "bench press", userId: "u1"), .initiate)

        backup.seedLocalStores(
            from: serverProfile,
            userId: "u1",
            trialStore: trialStore,
            liftTierStore: liftTierStore
        )

        let restored = trialStore.load(userId: "u1")
        XCTAssertEqual(restored.currentRank, .forged)
        XCTAssertEqual(restored.attempts.map(\.id), ["a1"])
        XCTAssertEqual(liftTierStore.tier(lift: "bench press", userId: "u1"), .veteran)
        XCTAssertEqual(liftTierStore.tier(lift: "deadlift", userId: "u1"), .novice)
    }

    func test_seed_is_noop_when_profile_carries_no_rank_progress() {
        trialStore.save(
            OverallRankTrialProgress(highestPassedRank: .master, attempts: []),
            userId: "u1"
        )
        backup.seedLocalStores(
            from: profile(overallRankTrials: nil, liftTiers: nil),
            userId: "u1",
            trialStore: trialStore,
            liftTierStore: liftTierStore
        )
        XCTAssertEqual(trialStore.load(userId: "u1").currentRank, .master)
    }

    // MARK: - (b) never-regress merge

    func test_seed_never_lowers_a_local_rank_or_tier() {
        let localAttempt = attempt(
            id: "local",
            targetRank: .master,
            passed: true,
            completedAt: Date(timeIntervalSince1970: 5_000)
        )
        trialStore.save(
            OverallRankTrialProgress(highestPassedRank: .master, attempts: [localAttempt]),
            userId: "u1"
        )
        liftTierStore.save(tier: .master, lift: "bench press", userId: "u1")
        liftTierStore.save(tier: .novice, lift: "deadlift", userId: "u1")

        // Stale server copy: lower overall rank, a server-only attempt, and a mix
        // of a lower ("bench press") and a higher ("deadlift") lift tier.
        let serverAttempt = attempt(
            id: "server",
            targetRank: .forged,
            passed: true,
            completedAt: Date(timeIntervalSince1970: 2_000)
        )
        let serverProfile = profile(
            overallRankTrials: OverallRankTrialProgress(highestPassedRank: .forged, attempts: [serverAttempt]),
            liftTiers: ["bench press": .veteran, "deadlift": .forged]
        )

        backup.seedLocalStores(
            from: serverProfile,
            userId: "u1",
            trialStore: trialStore,
            liftTierStore: liftTierStore
        )

        let merged = trialStore.load(userId: "u1")
        XCTAssertEqual(merged.currentRank, .master, "server copy must never lower the local rank")
        XCTAssertEqual(Set(merged.attempts.map(\.id)), ["local", "server"], "attempts are the union")
        XCTAssertEqual(liftTierStore.tier(lift: "bench press", userId: "u1"), .master, "server must not lower a lift tier")
        XCTAssertEqual(liftTierStore.tier(lift: "deadlift", userId: "u1"), .forged, "server may raise a lift tier")
    }

    func test_mergedNeverRegressing_takes_higher_rank_and_unions_attempts() {
        let a = OverallRankTrialProgress(
            highestPassedRank: .master,
            attempts: [attempt(id: "x", targetRank: .master, passed: true, completedAt: Date(timeIntervalSince1970: 3_000))]
        )
        let b = OverallRankTrialProgress(
            highestPassedRank: .forged,
            attempts: [attempt(id: "y", targetRank: .forged, passed: true, completedAt: Date(timeIntervalSince1970: 1_000))]
        )

        let mergedFromLow = b.mergedNeverRegressing(with: a)
        XCTAssertEqual(mergedFromLow.highestPassedRank, .master)
        XCTAssertEqual(mergedFromLow.attempts.map(\.id), ["y", "x"], "sorted by completedAt ascending")

        // Symmetric on rank regardless of receiver.
        XCTAssertEqual(a.mergedNeverRegressing(with: b).highestPassedRank, .master)
    }
}
