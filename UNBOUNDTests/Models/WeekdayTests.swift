import XCTest
@testable import UNBOUND

final class WeekdayTests: XCTestCase {
    func testOrdering() {
        XCTAssertEqual(Weekday.allCases.first, .monday)
        XCTAssertEqual(Weekday.allCases.last, .sunday)
        XCTAssertEqual(Weekday.allCases.count, 7)
    }

    func testShortLabels() {
        XCTAssertEqual(Weekday.monday.short, "Mon")
        XCTAssertEqual(Weekday.sunday.short, "Sun")
    }

    func testCalendarConversionFromSaturday() {
        // Jan 3, 2026 is a Saturday (Gregorian: weekday component == 7).
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 3
        let d = Calendar(identifier: .gregorian).date(from: comps)!
        XCTAssertEqual(Weekday(from: d, calendar: Calendar(identifier: .gregorian)), .saturday)
    }

    func testCalendarConversionFromMonday() {
        // Jan 5, 2026 is a Monday.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 5
        let d = Calendar(identifier: .gregorian).date(from: comps)!
        XCTAssertEqual(Weekday(from: d, calendar: Calendar(identifier: .gregorian)), .monday)
    }

    func testCodableRoundtrip() throws {
        let set: Set<Weekday> = [.monday, .wednesday, .friday]
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(Set<Weekday>.self, from: data)
        XCTAssertEqual(decoded, set)
    }
}
