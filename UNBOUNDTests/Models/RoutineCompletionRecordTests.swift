import XCTest
@testable import UNBOUND

final class RoutineCompletionRecordTests: XCTestCase {
    private func roundTrip(_ r: RoutineCompletionRecord) throws -> RoutineCompletionRecord {
        let data = try JSONEncoder().encode(r)
        return try JSONDecoder().decode(RoutineCompletionRecord.self, from: data)
    }

    func testTimeMetricRoundTrips() throws {
        let r = RoutineCompletionRecord(
            id: "1", routineId: "z2-walk-20",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            elapsedSeconds: 1280, primaryMetric: .time(seconds: 1280), spAwarded: 25)
        XCTAssertEqual(try roundTrip(r), r)
    }

    func testRepCountMetricRoundTripsWithBursts() throws {
        let r = RoutineCompletionRecord(
            id: "2", routineId: "100-pushup",
            completedAt: Date(timeIntervalSince1970: 1_700_000_500),
            elapsedSeconds: 820,
            primaryMetric: .repCount(total: 100, bursts: [35, 30, 20, 15]),
            spAwarded: 50)
        let back = try roundTrip(r)
        XCTAssertEqual(back, r)
        if case .repCount(let total, let bursts) = back.primaryMetric {
            XCTAssertEqual(total, 100)
            XCTAssertEqual(bursts, [35, 30, 20, 15])
        } else { XCTFail("metric kind lost") }
    }

    func testStepsMetricRoundTrips() throws {
        let r = RoutineCompletionRecord(
            id: "3", routineId: "8-gates-protocol",
            completedAt: Date(timeIntervalSince1970: 1_700_001_000),
            elapsedSeconds: 2400,
            primaryMetric: .steps(done: 9, total: 9), spAwarded: 120)
        XCTAssertEqual(try roundTrip(r), r)
    }

    func testPerformanceEntriesRoundTripAndDefaultToEmptyForOldRecords() throws {
        let r = RoutineCompletionRecord(
            id: "4",
            routineId: "saitama-protocol",
            completedAt: Date(timeIntervalSince1970: 1_700_001_500),
            elapsedSeconds: 1800,
            primaryMetric: .repCount(total: 300, bursts: [100, 100, 100]),
            spAwarded: 200,
            performanceEntries: [
                RoutinePerformanceEntry(
                    id: "push",
                    stepId: 0,
                    source: .repTarget,
                    name: "Push-ups",
                    reps: 100,
                    bursts: [40, 30, 30]
                ),
                RoutinePerformanceEntry(
                    id: "run",
                    stepId: 3,
                    source: .instruction,
                    name: "10 km run — any pace, no stopping",
                    distanceMeters: 10_000
                )
            ]
        )

        XCTAssertEqual(try roundTrip(r), r)

        let legacyJSON = """
        {
          "id": "legacy",
          "routineId": "100-pushup",
          "completedAt": 1700001500,
          "elapsedSeconds": 900,
          "primaryMetric": { "repCount": { "total": 100, "bursts": [40, 30, 30] } },
          "spAwarded": 50
        }
        """.data(using: .utf8)!

        let legacy = try JSONDecoder().decode(RoutineCompletionRecord.self, from: legacyJSON)
        XCTAssertEqual(legacy.performanceEntries, [])
    }
}
