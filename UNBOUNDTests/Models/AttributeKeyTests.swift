import XCTest
@testable import UNBOUND

final class AttributeKeyTests: XCTestCase {
    func testAllCasesHasExactlySixAxes() {
        XCTAssertEqual(AttributeKey.allCases.count, 6)
    }

    func testShortCodesAreThreeLetterUppercase() {
        let expected = ["POW", "VIT", "CTL", "END", "MOB", "EXP"]
        XCTAssertEqual(AttributeKey.allCases.map(\.shortCode), expected)
    }

    func testDisplayNamesAreTitleCased() {
        let expected = ["Power", "Vitality", "Control", "Endurance", "Mobility", "Explosiveness"]
        XCTAssertEqual(AttributeKey.allCases.map(\.displayName), expected)
    }

    func testRawValuesAreLowercaseStable() {
        let expected = ["power", "vitality", "control", "endurance", "mobility", "explosiveness"]
        XCTAssertEqual(AttributeKey.allCases.map(\.rawValue), expected)
    }

    func testLegacyAgilityDecodesAsVitality() throws {
        let data = try JSONEncoder().encode("agility")
        let decoded = try JSONDecoder().decode(AttributeKey.self, from: data)
        XCTAssertEqual(decoded, .vitality)
    }

    func testCodableRoundTripPreservesAllCases() throws {
        for key in AttributeKey.allCases {
            let data = try JSONEncoder().encode(key)
            let decoded = try JSONDecoder().decode(AttributeKey.self, from: data)
            XCTAssertEqual(decoded, key)
        }
    }
}
