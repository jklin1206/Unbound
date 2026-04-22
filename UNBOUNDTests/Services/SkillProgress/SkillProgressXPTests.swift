import XCTest
@testable import UNBOUND

// MARK: - SkillProgressXPTests
//
// Phase 1b verification. Exercises awardSessionXP end-to-end against an
// in-memory DatabaseServiceProtocol — no real disk or Auth state required.
//
// Node choice: "hs.wrist-conditioning" is a real SkillGraph.shared entry
// node with no prereqs. The XP API itself never consults the graph for
// gating (it trusts the caller), but pendingUnlock resolution needs the
// node to exist; we use a real one to keep the round-trip honest.

@MainActor
final class SkillProgressXPTests: XCTestCase {

    // MARK: - In-memory DB (mirrors MockDatabaseService, local to this target)

    final class InMemoryDB: DatabaseServiceProtocol, @unchecked Sendable {
        var store: [String: [String: Any]] = [:]

        func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
            let data = try JSONEncoder().encode(object)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            store["\(collection)/\(documentId)"] = dict
        }
        func read<T: Codable>(collection: String, documentId: String) async throws -> T {
            guard let dict = store["\(collection)/\(documentId)"] else {
                throw NSError(domain: "mem", code: 404)
            }
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(T.self, from: data)
        }
        func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
            var existing = store["\(collection)/\(documentId)"] ?? [:]
            for (k, v) in fields { existing[k] = v }
            store["\(collection)/\(documentId)"] = existing
        }
        func delete(collection: String, documentId: String) async throws {
            store.removeValue(forKey: "\(collection)/\(documentId)")
        }
        func query<T: Codable>(collection: String, field: String, isEqualTo value: Any, orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] {
            []
        }
    }

    private let realNodeId = "hs.wrist-conditioning"

    // MARK: - Helpers

    private func makeService() async -> (SkillProgressService, InMemoryDB) {
        let db = InMemoryDB()
        let svc = SkillProgressService(database: db)
        await svc.load(userId: "test-user")
        return (svc, db)
    }

    // MARK: - xpForLevel curve

    func test_xpForLevel_curve() {
        let svc = SkillProgressService(database: InMemoryDB())
        XCTAssertEqual(svc.xpForLevel(1), 0)
        XCTAssertEqual(svc.xpForLevel(2), 100)
        XCTAssertEqual(svc.xpForLevel(3), 125)
        XCTAssertEqual(svc.xpForLevel(4), 150)
        XCTAssertEqual(svc.xpForLevel(5), 175)
        XCTAssertEqual(svc.xpForLevel(6), 0)
    }

    // MARK: - 1. Default starter: 25 XP, no level-up

    func test_award25XP_onStarter_accruesWithoutLevelUp() async {
        let (svc, _) = await makeService()
        await svc.awardSessionXP(forNodeId: realNodeId)

        let sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 1)
        XCTAssertEqual(sp.xpInLevel, 25)
        XCTAssertEqual(sp.xpToNextLevel, 100)
        // Still locked/attempting — no Lv2 reached.
        XCTAssertNotEqual(svc.nodeStates[realNodeId], .achieved)
        XCTAssertNotEqual(svc.nodeStates[realNodeId], .mastered)
    }

    // MARK: - 2. Cross Lv1 → Lv2 with overflow

    func test_awardCrossingLv1ToLv2_rollsOverflow() async {
        let (svc, _) = await makeService()
        await svc.awardSessionXP(forNodeId: realNodeId, xpAmount: 120)

        let sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 2)
        XCTAssertEqual(sp.xpInLevel, 20)          // 120 - 100
        XCTAssertEqual(sp.xpToNextLevel, 125)     // Lv2 → Lv3
        // Promoted to .achieved on first level-up.
        XCTAssertEqual(svc.nodeStates[realNodeId], .achieved)
    }

    // MARK: - 3. Blow through multiple levels in one grant

    func test_award1000XP_jumpsStraightToMastered() async {
        let (svc, _) = await makeService()
        await svc.awardSessionXP(forNodeId: realNodeId, xpAmount: 1000)

        let sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 5)
        XCTAssertEqual(sp.xpInLevel, 175)         // capped at Lv5 bar
        XCTAssertEqual(sp.xpToNextLevel, 175)
        XCTAssertEqual(svc.nodeStates[realNodeId], .mastered)
    }

    // MARK: - 4. At Lv5 partial → fill → master, then cap

    func test_atLv5_partialXP_masteredOnceBarFills_thenCaps() async {
        let (svc, db) = await makeService()
        // Seed Lv5 partial manually — skipping the intermediate grants.
        var existing = (try? await db.read(collection: "skillProgress", documentId: "test-user")) as UserSkillProgress?
        XCTAssertNotNil(existing)
        existing?.skillProgress[realNodeId] = SkillProgress(currentLevel: 5, xpInLevel: 50, xpToNextLevel: 175)
        existing?.nodeStates[realNodeId] = .achieved
        try? await db.create(existing!, collection: "skillProgress", documentId: "test-user")
        await svc.load(userId: "test-user")

        // First +25: still not enough to master (75/175).
        await svc.awardSessionXP(forNodeId: realNodeId)
        var sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 5)
        XCTAssertEqual(sp.xpInLevel, 75)
        XCTAssertNotEqual(svc.nodeStates[realNodeId], .mastered)

        // Grant enough to fill the bar → mastered + capped.
        await svc.awardSessionXP(forNodeId: realNodeId, xpAmount: 200)
        sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 5)
        XCTAssertEqual(sp.xpInLevel, 175)
        XCTAssertEqual(svc.nodeStates[realNodeId], .mastered)

        // Further awards are no-ops — already mastered.
        await svc.awardSessionXP(forNodeId: realNodeId, xpAmount: 500)
        sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 5)
        XCTAssertEqual(sp.xpInLevel, 175)
        XCTAssertEqual(svc.nodeStates[realNodeId], .mastered)
    }

    // MARK: - 5. Mastered node → no-op

    func test_masteredNode_awardIsNoop() async {
        let (svc, db) = await makeService()
        var existing = (try? await db.read(collection: "skillProgress", documentId: "test-user")) as UserSkillProgress?
        existing?.skillProgress[realNodeId] = SkillProgress(currentLevel: 5, xpInLevel: 175, xpToNextLevel: 175)
        existing?.nodeStates[realNodeId] = .mastered
        try? await db.create(existing!, collection: "skillProgress", documentId: "test-user")
        await svc.load(userId: "test-user")

        await svc.awardSessionXP(forNodeId: realNodeId, xpAmount: 999)
        let sp = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(sp.currentLevel, 5)
        XCTAssertEqual(sp.xpInLevel, 175)
        XCTAssertEqual(svc.nodeStates[realNodeId], .mastered)
    }

    // MARK: - 6. Persistence round-trip

    func test_persistenceRoundTrip() async {
        let db = InMemoryDB()
        let svc = SkillProgressService(database: db)
        await svc.load(userId: "roundtrip-user")

        await svc.awardSessionXP(forNodeId: realNodeId, xpAmount: 150)
        let before = svc.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(before.currentLevel, 2)
        XCTAssertEqual(before.xpInLevel, 50)

        // Fresh service instance pointing at the same DB → should reload state.
        let reloaded = SkillProgressService(database: db)
        await reloaded.load(userId: "roundtrip-user")
        let after = reloaded.currentSkillProgress(for: realNodeId)
        XCTAssertEqual(after.currentLevel, before.currentLevel)
        XCTAssertEqual(after.xpInLevel, before.xpInLevel)
        XCTAssertEqual(after.xpToNextLevel, before.xpToNextLevel)
        XCTAssertEqual(reloaded.nodeStates[realNodeId], .achieved)
    }

    // MARK: - currentSkillProgress(for:) starter fallback

    func test_currentSkillProgress_unknownNode_returnsStarter() async {
        let (svc, _) = await makeService()
        let sp = svc.currentSkillProgress(for: "nonexistent.node.id")
        XCTAssertEqual(sp, SkillProgress.starter)
    }
}
