import XCTest
@testable import UNBOUND

@MainActor
final class ArcRecapBuilderTests: XCTestCase {
    private let windowStart = Date(timeIntervalSince1970: 1_000_000)

    func testBuildsLevelClimbAndHighlightsFromWindow() async throws {
        let userId = "arc-recap-\(UUID().uuidString)"
        let database = ArcRecapFakeDatabase()

        // One receipt before the window pins the starting XP; one inside
        // carries the post-session running total.
        database.records = [
            try record(userId: userId, at: windowStart.addingTimeInterval(-3_600), currentXP: 500, streak: 2),
            try record(userId: userId, at: windowStart.addingTimeInterval(86_400), currentXP: 2_400, streak: 6)
        ]
        database.logs = [
            performanceLog(
                userId: userId,
                at: windowStart.addingTimeInterval(86_400),
                exercises: [
                    ("Barbell Bench Press", 60, 8),
                    ("Push-Up", 0, 8)
                ]
            ),
            performanceLog(
                userId: userId,
                at: windowStart.addingTimeInterval(20 * 86_400),
                exercises: [
                    ("Barbell Bench Press", 70, 8),
                    ("Push-Up", 0, 12)
                ]
            )
        ]

        let summary = await ArcRecapBuilder.build(
            userId: userId,
            program: ProgramTestFactory.makeProgram(days: [], createdAt: windowStart),
            database: database
        )

        let recap = try XCTUnwrap(summary)
        XCTAssertEqual(recap.xpGained, 1_900, accuracy: 0.01)
        XCTAssertEqual(recap.trainedSessions, 2)
        XCTAssertEqual(recap.totalVolumeKg, 60 * 8 + 70 * 8, accuracy: 0.01)
        XCTAssertEqual(recap.nextArcNumber, recap.blockNumber + 1)
        XCTAssertNil(recap.beforePhotoPath, "No photos seeded, so no before pane")

        let kinds = recap.highlights.map(\.kind)
        XCTAssertTrue(kinds.contains(.loadUp), "10 kg bench climb is notable")
        XCTAssertTrue(kinds.contains(.repUp), "8 -> 12 push-up climb is notable")
        XCTAssertTrue(kinds.contains(.streak), "6-day streak is notable")
        XCTAssertTrue(
            recap.highlights.contains { $0.kind == .loadUp && $0.title == "Barbell Bench Press" }
        )
    }

    func testTrivialClimbsStayOutOfHighlights() async throws {
        let userId = "arc-recap-\(UUID().uuidString)"
        let database = ArcRecapFakeDatabase()
        database.logs = [
            performanceLog(
                userId: userId,
                at: windowStart.addingTimeInterval(86_400),
                exercises: [("Barbell Bench Press", 60, 8), ("Push-Up", 0, 8)]
            ),
            performanceLog(
                userId: userId,
                at: windowStart.addingTimeInterval(10 * 86_400),
                exercises: [("Barbell Bench Press", 61, 8), ("Push-Up", 0, 9)]
            )
        ]

        let summary = await ArcRecapBuilder.build(
            userId: userId,
            program: ProgramTestFactory.makeProgram(days: [], createdAt: windowStart),
            database: database
        )

        XCTAssertEqual(try XCTUnwrap(summary).highlights, [])
    }

    /// Empty Arc: no completion records at/before the window and none inside,
    /// yet the live overall_level_progress carries a lifetime total. The delta
    /// must be 0 - never render lifetime XP as gained this Arc.
    func testEmptyArcReportsNoXPGained() async throws {
        let userId = "arc-recap-\(UUID().uuidString)"
        let database = ArcRecapFakeDatabase()
        database.progress = OverallLevelProgress(userId: userId, totalXP: 5_000)

        let summary = await ArcRecapBuilder.build(
            userId: userId,
            program: ProgramTestFactory.makeProgram(days: [], createdAt: windowStart),
            database: database
        )

        let recap = try XCTUnwrap(summary)
        XCTAssertEqual(recap.xpGained, 0, accuracy: 0.01)
        XCTAssertEqual(recap.trainedSessions, 0)
    }

    // MARK: - Fixtures

    private func performanceLog(
        userId: String,
        at date: Date,
        exercises: [(name: String, weightKg: Double, reps: Int)]
    ) -> PerformanceLog {
        PerformanceLog(
            id: UUID().uuidString,
            userId: userId,
            source: .program,
            title: "Session",
            startedAt: date,
            completedAt: date.addingTimeInterval(2_400),
            blocks: [
                PerformanceBlock(
                    id: UUID().uuidString,
                    kind: .strength,
                    title: "Main",
                    exercises: exercises.map { entry in
                        PerformanceExercise(
                            name: entry.name,
                            plannedSets: 1,
                            plannedTarget: "\(entry.reps)",
                            sets: [
                                PerformanceSet(
                                    setNumber: 1,
                                    reps: entry.reps,
                                    weightKg: entry.weightKg > 0 ? entry.weightKg : nil,
                                    isWarmup: false
                                )
                            ]
                        )
                    }
                )
            ]
        )
    }

    /// TrainingCompletionRecord has no memberwise init (it is built from a
    /// live completion result), so fixtures decode from JSON.
    private func record(
        userId: String,
        at date: Date,
        currentXP: Double,
        streak: Int
    ) throws -> TrainingCompletionRecord {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "performanceLogId": UUID().uuidString,
            "userId": userId,
            "completedAt": date.timeIntervalSince1970,
            "sessionLogIds": [String](),
            "replay": [
                "movementAPGains": [Any](),
                "movementProgressStates": [Any](),
                "movementProgressPriorStates": [String: Any](),
                "updatedMovementProgressIds": [Any](),
                "attributeRewards": [Any](),
                "attributeRankUpEventCount": 0,
                "bodyMapNoveltyMultiplier": 1,
                "bodyMapRegionRewards": [Any](),
                "overallLevelReward": [
                    "xpGained": 100,
                    "noveltyMultiplier": 1,
                    "previousXP": max(0, currentXP - 100),
                    "currentXP": currentXP,
                    "previousLevel": OverallLevelCurve.level(forXP: max(0, currentXP - 100)),
                    "currentLevel": OverallLevelCurve.level(forXP: currentXP),
                    "previousProgressToNextLevel": 0,
                    "currentProgressToNextLevel": 0
                ],
                "overallLevelXPGained": 100,
                "skillXPGained": 0,
                "streakCount": streak,
                "streakExtended": true,
                "unlockedSkins": [Any](),
                "bodyweightKg": 80
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(TrainingCompletionRecord.self, from: data)
    }
}

private final class ArcRecapFakeDatabase: DatabaseServiceProtocol, @unchecked Sendable {
    var records: [TrainingCompletionRecord] = []
    var logs: [PerformanceLog] = []
    var progress: OverallLevelProgress?

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {}

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        if collection == "overall_level_progress", let progress, let typed = progress as? T {
            return typed
        }
        throw AppError.databaseReadFailed(underlying: NSError(domain: "ArcRecapFakeDatabase", code: 404))
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {}

    func delete(collection: String, documentId: String) async throws {}

    func query<T: Codable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        orderBy: String?,
        descending: Bool,
        limit: Int?
    ) async throws -> [T] {
        guard field == "userId", let userId = value as? String else { return [] }
        switch collection {
        case "training_completion_records":
            return (records.filter { $0.userId == userId } as? [T]) ?? []
        case "performanceLogs":
            return (logs.filter { $0.userId == userId } as? [T]) ?? []
        default:
            return []
        }
    }
}
