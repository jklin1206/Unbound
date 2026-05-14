import XCTest
@testable import UNBOUND

final class TrialThemeTests: XCTestCase {
    func testAxisRoundtrip() throws {
        let theme: TrialTheme = .axis(.power)
        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(TrialTheme.self, from: data)
        XCTAssertEqual(decoded, theme)
    }

    func testWildcardRoundtrip() throws {
        let theme: TrialTheme = .wildcard
        let data = try JSONEncoder().encode(theme)
        let decoded = try JSONDecoder().decode(TrialTheme.self, from: data)
        XCTAssertEqual(decoded, theme)
    }

    func testEquality() {
        XCTAssertEqual(TrialTheme.axis(.power), TrialTheme.axis(.power))
        XCTAssertNotEqual(TrialTheme.axis(.power), TrialTheme.axis(.endurance))
        XCTAssertNotEqual(TrialTheme.axis(.power), TrialTheme.wildcard)
    }
}
