import XCTest
@testable import UNBOUND

final class HomeLoadDerivationsTests: XCTestCase {

    private func cal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        let c = cal()
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func test_weekSessionDays_mapsCurrentWeekToMondayIndex() {
        let now = date(2026, 5, 13)            // Wednesday
        let starts = [
            date(2026, 5, 11),                 // Mon  -> 1
            date(2026, 5, 13),                 // Wed  -> 3
            date(2026, 5, 17),                 // Sun  -> 7
            date(2026, 5, 8)                   // prev week -> excluded
        ]
        let days = HomeLoadDerivations.weekSessionDays(starts, now: now, calendar: cal())
        XCTAssertEqual(days, [1, 3, 7])
    }

    func test_weekSessionDays_empty() {
        XCTAssertEqual(
            HomeLoadDerivations.weekSessionDays([], now: date(2026, 5, 13), calendar: cal()),
            [])
    }

    func test_lastLog_and_hasLogged() {
        let logs: [WorkoutLog] = []
        XCTAssertNil(HomeLoadDerivations.lastLog(logs))
        XCTAssertFalse(HomeLoadDerivations.hasLogged(logs))
    }
}
