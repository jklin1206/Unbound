import XCTest
@testable import UNBOUND

@MainActor
final class RoutineHistoryStoreTests: XCTestCase {

    private func freshSuite() -> (UserDefaults, URL) {
        let suiteName = "rhs.test.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (ud, dir)
    }

    private func routine(_ id: String, sp: Int = 25) -> RoutineDef {
        RoutineDef(id: id, title: id, subtitle: "", durationLabel: "~10 MIN",
                   category: .challenge, spReward: sp, steps: [])
    }

    func testCompleteAwardsThenCooldownBlocksWithin24h() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        XCTAssertTrue(store.canComplete(routineId: "r1"))
        XCTAssertTrue(store.complete(routine("r1", sp: 40)))
        XCTAssertEqual(ud.integer(forKey: "unbound.gains"), 40)
        XCTAssertFalse(store.canComplete(routineId: "r1"))
        XCTAssertFalse(store.complete(routine("r1", sp: 40)))
        XCTAssertEqual(ud.integer(forKey: "unbound.gains"), 40)
    }

    func testRecordRoundTripsAndSurvivesFreshStore() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        let rec = RoutineCompletionRecord(
            routineId: "100-pushup", elapsedSeconds: 800,
            primaryMetric: .repCount(total: 100, bursts: [40, 35, 25]),
            spAwarded: 50)
        store.record(rec)

        let reborn = RoutineHistoryStore(defaults: ud, directory: dir)
        XCTAssertEqual(reborn.history(routineId: "100-pushup").count, 1)
        XCTAssertEqual(reborn.history(routineId: "100-pushup").first?.id, rec.id)
        XCTAssertTrue(reborn.history(routineId: "other").isEmpty)
    }

    func testSummaryComputesCountAndBest() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        store.record(.init(routineId: "100-pushup", elapsedSeconds: 900,
                           primaryMetric: .repCount(total: 100, bursts: [50, 50]),
                           spAwarded: 50))
        store.record(.init(routineId: "100-pushup", elapsedSeconds: 700,
                           primaryMetric: .repCount(total: 100, bursts: [60, 40]),
                           spAwarded: 50))
        let s = store.summary(routineId: "100-pushup")
        XCTAssertEqual(s?.count, 2)
        if case .repCount(let total, _)? = s?.best { XCTAssertEqual(total, 100) }
        else { XCTFail("expected repCount best") }
        XCTAssertEqual(store.summary(routineId: "none")?.count ?? 0, 0)
    }

    func testTimeBestIsShortestElapsed() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        store.record(.init(routineId: "z2", elapsedSeconds: 1300,
                           primaryMetric: .time(seconds: 1300), spAwarded: 25))
        store.record(.init(routineId: "z2", elapsedSeconds: 1180,
                           primaryMetric: .time(seconds: 1180), spAwarded: 25))
        if case .time(let s)? = store.summary(routineId: "z2")?.best {
            XCTAssertEqual(s, 1180)
        } else { XCTFail("expected time best = shortest") }
    }
}
