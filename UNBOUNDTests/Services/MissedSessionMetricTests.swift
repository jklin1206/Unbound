import XCTest
@testable import UNBOUND

final class MissedSessionMetricTests: XCTestCase {
    func testThreeDayUserMissingTwoInSevenDaysSoftChecksIn() {
        let now = Date(timeIntervalSince1970: 7 * 86_400)
        let sessions = [
            attendance(daysAgo: 6, now: now, completed: false),
            attendance(daysAgo: 4, now: now, completed: true),
            attendance(daysAgo: 2, now: now, completed: false)
        ]

        let result = MissedSessionMetric.evaluate(sessions: sessions, now: now, calendar: .fixedGMT)

        XCTAssertEqual(result.scheduledCount, 3)
        XCTAssertEqual(result.missedCount, 2)
        XCTAssertEqual(result.missedRatio, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(result.state, .softCheckIn)
    }

    func testSixDayUserMissingFiveOffersRampWeek() {
        let now = Date(timeIntervalSince1970: 7 * 86_400)
        let sessions = (1...6).map { index in
            attendance(daysAgo: index, now: now, completed: index == 6)
        }

        let result = MissedSessionMetric.evaluate(sessions: sessions, now: now, calendar: .fixedGMT)

        XCTAssertEqual(result.state, .rampWeekOffered)
    }

    func testSustainedHighMissForFourteenDaysRecommendsRecalibration() {
        let now = Date(timeIntervalSince1970: 14 * 86_400)
        let sessions = (1...14).map { day in
            attendance(daysAgo: day, now: now, completed: day == 7 || day == 14)
        }

        let result = MissedSessionMetric.evaluate(sessions: sessions, now: now, calendar: .fixedGMT)

        XCTAssertEqual(result.state, .staleRecalibrationRecommended)
    }

    func testZeroScheduledSessionsIsNormal() {
        let result = MissedSessionMetric.evaluate(
            sessions: [],
            now: Date(timeIntervalSince1970: 0),
            calendar: .fixedGMT
        )

        XCTAssertEqual(result.state, .normal)
        XCTAssertEqual(result.missedRatio, 0)
    }

    private func attendance(daysAgo: Int, now: Date, completed: Bool) -> ScheduledSessionAttendance {
        let scheduled = Calendar.fixedGMT.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        return ScheduledSessionAttendance(
            scheduledAt: scheduled,
            completedAt: completed ? scheduled.addingTimeInterval(3_600) : nil
        )
    }
}
