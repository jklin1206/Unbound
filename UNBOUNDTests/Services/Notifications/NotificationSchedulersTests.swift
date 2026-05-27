import XCTest
@testable import UNBOUND

final class NotificationSchedulersTests: XCTestCase {
    func testTrainTimePlanBuildsStableIdentifiersAndDateComponents() {
        let preferences = NotificationPreferences(
            workoutReminders: WorkoutReminderNotificationPreferences(
                isEnabled: true,
                workoutTime: .evening,
                trainingDays: [.thursday, .monday],
                minute: 10
            )
        )

        let plan = TrainTimeNotificationScheduler().plan(preferences: preferences)

        XCTAssertEqual(
            plan.identifiersToCancel,
            Weekday.allCases.map(TrainTimeNotificationScheduler.identifier(for:))
        )
        XCTAssertEqual(
            plan.requests.map(\.identifier),
            [
                "com.unbound.workout.monday",
                "com.unbound.workout.thursday"
            ]
        )

        guard case .calendar(let monday, let mondayRepeats) = plan.requests[0].trigger else {
            return XCTFail("Expected Monday calendar trigger")
        }
        XCTAssertTrue(mondayRepeats)
        XCTAssertEqual(monday.weekday, 2)
        XCTAssertEqual(monday.hour, 18)
        XCTAssertEqual(monday.minute, 10)

        guard case .calendar(let thursday, let thursdayRepeats) = plan.requests[1].trigger else {
            return XCTFail("Expected Thursday calendar trigger")
        }
        XCTAssertTrue(thursdayRepeats)
        XCTAssertEqual(thursday.weekday, 5)
        XCTAssertEqual(thursday.hour, 18)
        XCTAssertEqual(thursday.minute, 10)
    }

    func testTrainTimePlanCancelsWithoutRequestsWhenDisabled() {
        let preferences = NotificationPreferences(
            workoutReminders: WorkoutReminderNotificationPreferences(
                isEnabled: false,
                workoutTime: .morning,
                trainingDays: [.monday]
            )
        )

        let plan = TrainTimeNotificationScheduler().plan(preferences: preferences)

        XCTAssertEqual(
            plan.identifiersToCancel,
            Weekday.allCases.map(TrainTimeNotificationScheduler.identifier(for:))
        )
        XCTAssertTrue(plan.requests.isEmpty)
    }

    func testRetentionPlanBuildsCalendarDateComponentsAndStableIdentifier() throws {
        let calendar = Calendar.fixedGMT
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 31,
            hour: 10,
            minute: 30
        )))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 1,
            hour: 8
        )))
        let preferences = NotificationPreferences(
            retentionNudges: RetentionNudgeNotificationPreferences(
                isEnabled: true,
                anchorDate: anchor,
                daysAfterAnchor: 30,
                hour: 9,
                minute: 15
            )
        )

        let plan = RetentionNudgeScheduler(calendar: calendar).plan(
            preferences: preferences,
            now: now
        )

        XCTAssertEqual(plan.identifiersToCancel, ["com.unbound.rescan"])
        XCTAssertEqual(plan.requests.map(\.identifier), ["com.unbound.rescan"])

        guard case .calendar(let components, let repeats) = plan.requests[0].trigger else {
            return XCTFail("Expected retention calendar trigger")
        }
        XCTAssertFalse(repeats)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 2)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 15)
    }

    func testRetentionPlanSkipsPastNudgesButStillCancelsOldIdentifier() throws {
        let calendar = Calendar.fixedGMT
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 1
        )))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 2,
            day: 15
        )))
        let preferences = NotificationPreferences(
            retentionNudges: RetentionNudgeNotificationPreferences(
                isEnabled: true,
                anchorDate: anchor,
                daysAfterAnchor: 30
            )
        )

        let plan = RetentionNudgeScheduler(calendar: calendar).plan(
            preferences: preferences,
            now: now
        )

        XCTAssertEqual(plan.identifiersToCancel, ["com.unbound.rescan"])
        XCTAssertTrue(plan.requests.isEmpty)
    }
}
