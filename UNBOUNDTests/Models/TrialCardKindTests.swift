import XCTest
@testable import UNBOUND

final class TrialCardKindTests: XCTestCase {
    func testAllCases() {
        XCTAssertEqual(TrialCardKind.allCases.count, 3)
        XCTAssertTrue(TrialCardKind.allCases.contains(.aligned))
        XCTAssertTrue(TrialCardKind.allCases.contains(.growth))
        XCTAssertTrue(TrialCardKind.allCases.contains(.prestige))
    }

    func testRawValuesStable() {
        XCTAssertEqual(TrialCardKind.aligned.rawValue, "aligned")
        XCTAssertEqual(TrialCardKind.growth.rawValue, "growth")
        XCTAssertEqual(TrialCardKind.prestige.rawValue, "prestige")
    }

    func testCodableRoundtrip() throws {
        for kind in TrialCardKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(TrialCardKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }
}
