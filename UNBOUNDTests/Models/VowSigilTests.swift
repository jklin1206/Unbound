import XCTest
@testable import UNBOUND

final class VowSigilTests: XCTestCase {
    func testSealedSegmentsEqualKeptVows() {
        XCTAssertEqual(VowSigil(keptVows: 0, brokenVows: 0).sealedSegments, 0)
        XCTAssertEqual(VowSigil(keptVows: 7, brokenVows: 0).sealedSegments, 7)
    }

    func testFractureSelfHeals() {
        // 0 kept, 1 broken -> 1 active fracture.
        XCTAssertEqual(VowSigil(keptVows: 0, brokenVows: 1).activeFractures, 1)
        // healAfterKept kept, 1 broken -> the fracture has healed.
        XCTAssertEqual(
            VowSigil(keptVows: VowSigil.healAfterKept, brokenVows: 1).activeFractures,
            0
        )
    }

    func testActiveFracturesNeverNegative() {
        // Many keeps, no breaks -> never dips below zero.
        XCTAssertEqual(VowSigil(keptVows: 30, brokenVows: 0).activeFractures, 0)
        // More healing capacity than breaks -> floored at zero.
        XCTAssertEqual(VowSigil(keptVows: 9, brokenVows: 1).activeFractures, 0)
    }

    func testSegmentsNeverNegative() {
        XCTAssertEqual(VowSigil(keptVows: -4, brokenVows: 0).sealedSegments, 0)
    }
}
