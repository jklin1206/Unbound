import XCTest
@testable import UNBOUND

/// Liftoff-style streak rule: day-based, program-agnostic. Counts the days
/// between logged sessions (rest days credited), breaks only after 3 missed days.
final class ProgramAwareStreakPolicyTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    private func decide(_ from: String, _ to: String, streak: Int = 5) -> (streak: Int, extended: Bool, broken: Bool) {
        ProgramAwareStreakPolicy.shouldExtendStreak(
            from: date(from), to: date(to), currentStreak: streak, calendar: calendar
        )
    }

    func test_sameDayDoesNotExtendOrBreak() {
        let d = decide("2026-05-04", "2026-05-04")
        XCTAssertEqual(d.streak, 5)
        XCTAssertFalse(d.extended)
        XCTAssertFalse(d.broken)
    }

    func test_outOfOrderSessionDoesNotExtendOrBreak() {
        let d = decide("2026-05-06", "2026-05-04")
        XCTAssertEqual(d.streak, 5)
        XCTAssertFalse(d.extended)
        XCTAssertFalse(d.broken)
    }

    func test_consecutiveDayAddsOne() {
        let d = decide("2026-05-04", "2026-05-05")
        XCTAssertEqual(d.streak, 6)
        XCTAssertTrue(d.extended)
        XCTAssertFalse(d.broken)
    }

    func test_oneRestDayCreditsTheGap() {
        // The Liftoff example: post Monday then Wednesday → +2 (Tuesday credited).
        let d = decide("2026-05-04", "2026-05-06")
        XCTAssertEqual(d.streak, 7)
        XCTAssertTrue(d.extended)
        XCTAssertFalse(d.broken)
    }

    func test_threeDayGapIsTheLastValidDay() {
        // Mon → Thu (gap 3) still extends, crediting the 3 days.
        let d = decide("2026-05-04", "2026-05-07")
        XCTAssertEqual(d.streak, 8)
        XCTAssertTrue(d.extended)
        XCTAssertFalse(d.broken)
    }

    func test_fourDayGapBreaksAndRestartsAtOne() {
        // Mon → Fri (3 missed days) → broken, fresh run at 1.
        let d = decide("2026-05-04", "2026-05-08")
        XCTAssertEqual(d.streak, 1)
        XCTAssertFalse(d.extended)
        XCTAssertTrue(d.broken)
    }

    func test_ruleIsProgramAgnostic() {
        // No program context at all — a 4-day gap breaks regardless.
        let d = ProgramAwareStreakPolicy.shouldExtendStreak(
            from: date("2026-05-04"), to: date("2026-05-09"), currentStreak: 12, calendar: calendar
        )
        XCTAssertEqual(d.streak, 1)
        XCTAssertTrue(d.broken)
    }

    private func date(_ yyyyMMdd: String) -> Date {
        var components = DateComponents()
        let parts = yyyyMMdd.split(separator: "-").compactMap { Int($0) }
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return components.date!
    }
}
