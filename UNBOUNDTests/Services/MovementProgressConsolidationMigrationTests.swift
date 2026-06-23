import XCTest
@testable import UNBOUND

/// P3: the one-time merge that folds a retired `movement_progress` row (split XP
/// from before rank-standard unification) into its canonical row without losing
/// or double-counting progress.
@MainActor
final class MovementProgressConsolidationMigrationTests: XCTestCase {

    private let retiredId = "skill-drill.hollow-body-hold"
    private let canonicalId = "exercise.hollow-hold"
    private let userId = "u1"

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "consolidation-test-\(UUID().uuidString)")!
    }

    private func state(
        _ standardId: String,
        totalAP: Double,
        hold: Int?,
        processed: [String]
    ) -> MovementProgressState {
        MovementProgressState(
            userId: userId,
            rankStandardMovementId: standardId,
            displayName: "Hollow Body Hold",
            rankTemplate: .holdControl,
            totalAP: totalAP,
            bestHoldSeconds: hold,
            processedSourceLogIds: processed
        )
    }

    private func docId(_ standardId: String) -> String { "\(userId):\(standardId)" }

    func testMergesRetiredRowIntoCanonical() async throws {
        let db = MockDatabaseService()
        try await db.create(state(retiredId, totalAP: 10, hold: 30, processed: ["a"]),
                            collection: "movement_progress", documentId: docId(retiredId))
        try await db.create(state(canonicalId, totalAP: 5, hold: 20, processed: ["b"]),
                            collection: "movement_progress", documentId: docId(canonicalId))

        let didMerge = await MovementProgressConsolidationMigration.migrateIfNeeded(
            userId: userId, database: db, defaults: makeDefaults()
        )
        XCTAssertTrue(didMerge)

        let merged: MovementProgressState = try await db.read(
            collection: "movement_progress", documentId: docId(canonicalId)
        )
        XCTAssertEqual(merged.totalAP, 15, "AP should sum")
        XCTAssertEqual(merged.bestHoldSeconds, 30, "best metric should be the max")
        XCTAssertEqual(Set(merged.processedSourceLogIds), ["a", "b"], "dedupe sets should union")

        // retired row is gone
        do {
            let _: MovementProgressState = try await db.read(
                collection: "movement_progress", documentId: docId(retiredId)
            )
            XCTFail("retired row should be deleted")
        } catch { /* expected */ }
    }

    func testCreatesCanonicalWhenOnlyRetiredExists() async throws {
        let db = MockDatabaseService()
        try await db.create(state(retiredId, totalAP: 8, hold: 25, processed: ["x"]),
                            collection: "movement_progress", documentId: docId(retiredId))

        let didMerge = await MovementProgressConsolidationMigration.migrateIfNeeded(
            userId: userId, database: db, defaults: makeDefaults()
        )
        XCTAssertTrue(didMerge)

        let merged: MovementProgressState = try await db.read(
            collection: "movement_progress", documentId: docId(canonicalId)
        )
        XCTAssertEqual(merged.totalAP, 8)
        XCTAssertEqual(merged.bestHoldSeconds, 25)
        XCTAssertEqual(merged.rankStandardMovementId, canonicalId)
    }

    func testNoOpWhenNothingToMerge() async throws {
        let db = MockDatabaseService()
        let didMerge = await MovementProgressConsolidationMigration.migrateIfNeeded(
            userId: userId, database: db, defaults: makeDefaults()
        )
        XCTAssertFalse(didMerge)
    }

    func testIdempotentAndSelfHealing() async throws {
        let db = MockDatabaseService()
        let defaults = makeDefaults()
        try await db.create(state(retiredId, totalAP: 10, hold: 30, processed: ["a"]),
                            collection: "movement_progress", documentId: docId(retiredId))
        try await db.create(state(canonicalId, totalAP: 5, hold: 20, processed: ["b"]),
                            collection: "movement_progress", documentId: docId(canonicalId))

        _ = await MovementProgressConsolidationMigration.migrateIfNeeded(userId: userId, database: db, defaults: defaults)
        // Second run with the SAME defaults: flag is set, so it is a no-op.
        let second = await MovementProgressConsolidationMigration.migrateIfNeeded(userId: userId, database: db, defaults: defaults)
        XCTAssertFalse(second)
        // Third run with FRESH defaults (flag unset): still no double-count, because
        // the retired row was already deleted.
        let third = await MovementProgressConsolidationMigration.migrateIfNeeded(userId: userId, database: db, defaults: makeDefaults())
        XCTAssertFalse(third)

        let merged: MovementProgressState = try await db.read(
            collection: "movement_progress", documentId: docId(canonicalId)
        )
        XCTAssertEqual(merged.totalAP, 15, "AP must not double-count across reruns")
    }
}
