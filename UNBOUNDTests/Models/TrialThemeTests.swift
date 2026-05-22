import XCTest
@testable import UNBOUND

final class WeeklyVowThemeTests: XCTestCase {
    func testAxisRoundtrip() throws {
        let theme: WeeklyVowTheme = .axis(.power)
        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(WeeklyVowTheme.self, from: data)
        XCTAssertEqual(decoded, theme)
    }

    func testWildcardRoundtrip() throws {
        let theme: WeeklyVowTheme = .wildcard
        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(WeeklyVowTheme.self, from: data)
        XCTAssertEqual(decoded, theme)
    }

    func testEquality() {
        XCTAssertEqual(WeeklyVowTheme.axis(.power), WeeklyVowTheme.axis(.power))
        XCTAssertNotEqual(WeeklyVowTheme.axis(.power), WeeklyVowTheme.axis(.endurance))
        XCTAssertNotEqual(WeeklyVowTheme.axis(.power), WeeklyVowTheme.wildcard)
    }
}
