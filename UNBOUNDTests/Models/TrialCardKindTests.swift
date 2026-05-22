import XCTest
@testable import UNBOUND

final class WeeklyVowKindTests: XCTestCase {
    func testAllCases() {
        XCTAssertEqual(WeeklyVowKind.allCases.count, 3)
        XCTAssertTrue(WeeklyVowKind.allCases.contains(.ember))
        XCTAssertTrue(WeeklyVowKind.allCases.contains(.overdrive))
        XCTAssertTrue(WeeklyVowKind.allCases.contains(.apex))
    }

    func testRawValuesStable() {
        XCTAssertEqual(WeeklyVowKind.ember.rawValue, "ember")
        XCTAssertEqual(WeeklyVowKind.overdrive.rawValue, "overdrive")
        XCTAssertEqual(WeeklyVowKind.apex.rawValue, "apex")
    }

    func testCodableRoundtrip() throws {
        for kind in WeeklyVowKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(WeeklyVowKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testLegacyTrialKindRawValuesDecode() throws {
        XCTAssertEqual(try JSONDecoder().decode(WeeklyVowKind.self, from: Data(#""aligned""#.utf8)), .ember)
        XCTAssertEqual(try JSONDecoder().decode(WeeklyVowKind.self, from: Data(#""growth""#.utf8)), .overdrive)
        XCTAssertEqual(try JSONDecoder().decode(WeeklyVowKind.self, from: Data(#""prestige""#.utf8)), .apex)
    }

    func testCompatibilityAliases() {
        XCTAssertEqual(TrialCardKind.aligned, .ember)
        XCTAssertEqual(TrialCardKind.growth, .overdrive)
        XCTAssertEqual(TrialCardKind.prestige, .apex)
    }
}
