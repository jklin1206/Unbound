import XCTest
@testable import UNBOUND

final class VitalityRewardPolicyTests: XCTestCase {
    func testRestDayTitleAloneDoesNotAwardVitality() async throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let database = VitalityRewardPolicyDatabase(records: [])
        let log = PerformanceLog(
            id: "rest-title-only",
            userId: "user-vitality",
            source: .routine,
            title: "Rest Day Recovery",
            startedAt: date.addingTimeInterval(-300),
            completedAt: date,
            blocks: [
                PerformanceBlock(
                    kind: .routine,
                    title: "Recovery Summary",
                    exercises: [],
                    durationSeconds: 300,
                    notes: nil
                )
            ],
            notes: nil
        )

        let award = await VitalityRewardPolicy.award(for: log, database: database)

        XCTAssertEqual(award.totalXP, 0, accuracy: 0.001)
        XCTAssertTrue(award.signals.isEmpty)
    }

    func testHealthRecoverySnapshotDerivesVitalitySignals() {
        let snapshot = HealthRecoverySnapshot(
            date: Date(),
            steps: 3_200,
            walkingRunningDistanceMeters: 1_100,
            asleepSeconds: 7.25 * 3_600
        )

        XCTAssertEqual(snapshot.vitalitySignals, [.easyWalkOrMobility, .sleep])
    }

    func testDailySignalCapLimitsStackedRecoverySignals() async throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let database = VitalityRewardPolicyDatabase(records: [
            record(
                id: "existing",
                date: date,
                signalXP: 10
            )
        ])
        let log = performanceLog(
            id: "current",
            date: date,
            signals: [.easyWalkOrMobility, .sleep, .hydrationProtein]
        )

        let award = await VitalityRewardPolicy.award(for: log, database: database)

        XCTAssertEqual(award.signalXP, 2, accuracy: 0.001)
        XCTAssertEqual(award.weeklyBonusXP, 0, accuracy: 0.001)
        XCTAssertEqual(award.totalXP, 2, accuracy: 0.001)
    }

    func testWeeklyConsistencyBonusAwardsOnFourthSupportDay() async throws {
        let start = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 25, hour: 12)))
        let dates = (0..<4).map { start.addingTimeInterval(TimeInterval($0 * 86_400)) }
        let database = VitalityRewardPolicyDatabase(records: [
            record(id: "d1", date: dates[0], signalXP: 4),
            record(id: "d2", date: dates[1], signalXP: 4),
            record(id: "d3", date: dates[2], signalXP: 4)
        ])
        let log = performanceLog(
            id: "d4",
            date: dates[3],
            signals: [.easyWalkOrMobility]
        )

        let award = await VitalityRewardPolicy.award(for: log, database: database)

        XCTAssertEqual(award.signalXP, 4, accuracy: 0.001)
        XCTAssertEqual(award.weeklyBonusXP, 15, accuracy: 0.001)
        XCTAssertEqual(award.totalXP, 19, accuracy: 0.001)
    }

    func testWeeklyConsistencyBonusDoesNotRepeat() async throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 28, hour: 12)))
        let database = VitalityRewardPolicyDatabase(records: [
            record(id: "bonus", date: date.addingTimeInterval(-86_400), signalXP: 4, weeklyBonusXP: 15)
        ])
        let log = performanceLog(
            id: "later",
            date: date,
            signals: [.sleep]
        )

        let award = await VitalityRewardPolicy.award(for: log, database: database)

        XCTAssertEqual(award.signalXP, 3, accuracy: 0.001)
        XCTAssertEqual(award.weeklyBonusXP, 0, accuracy: 0.001)
    }

    private func performanceLog(
        id: String,
        date: Date,
        signals: [VitalityCheckInSignal]
    ) -> PerformanceLog {
        let notes = signals.map(\.token).joined(separator: " ")
        return PerformanceLog(
            id: id,
            userId: "user-vitality",
            source: .routine,
            title: "Recovery Support",
            startedAt: date.addingTimeInterval(-300),
            completedAt: date,
            blocks: [
                PerformanceBlock(
                    kind: .routine,
                    title: "Recovery Support",
                    exercises: [],
                    durationSeconds: 300,
                    notes: notes
                )
            ],
            notes: notes
        )
    }

    private func record(
        id: String,
        date: Date,
        signalXP: Double,
        weeklyBonusXP: Double = 0
    ) -> VitalityRewardRecord {
        VitalityRewardRecord(
            id: id,
            userId: "user-vitality",
            sourceLogId: id,
            awardedAt: date,
            localDay: VitalityRewardPolicy.localDayKey(for: date),
            localWeek: VitalityRewardPolicy.localWeekKey(for: date),
            signals: [.easyWalkOrMobility],
            signalXP: signalXP,
            weeklyBonusXP: weeklyBonusXP
        )
    }
}

private final class VitalityRewardPolicyDatabase: DatabaseServiceProtocol, @unchecked Sendable {
    private var records: [VitalityRewardRecord]

    init(records: [VitalityRewardRecord]) {
        self.records = records
    }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        if let record = object as? VitalityRewardRecord {
            records.append(record)
        }
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        throw AppError.databaseReadFailed(underlying: NSError(domain: "VitalityRewardPolicyDatabase", code: 404))
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
        guard collection == "vitality_reward_records",
              field == "userId",
              let userId = value as? String,
              T.self == VitalityRewardRecord.self else {
            return []
        }
        let filtered = records.filter { $0.userId == userId }
        return filtered as? [T] ?? []
    }
}
