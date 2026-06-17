import XCTest
@testable import UNBOUND

final class VowSigilTests: XCTestCase {
    func testSealedSegmentsEqualKeptVows() {
        XCTAssertEqual(VowSigil(keptVows: 0, breakKeptSnapshots: []).sealedSegments, 0)
        XCTAssertEqual(VowSigil(keptVows: 7, breakKeptSnapshots: []).sealedSegments, 7)
    }

    func testFractureShowsThenHealsAfterSubsequentKeeps() {
        // A vow broken at 0 prior keeps is an active fracture until healAfterKept
        // further keeps accrue.
        XCTAssertEqual(VowSigil(keptVows: 0, breakKeptSnapshots: [0]).activeFractures, 1)
        XCTAssertEqual(VowSigil(keptVows: VowSigil.healAfterKept - 1, breakKeptSnapshots: [0]).activeFractures, 1)
        XCTAssertEqual(VowSigil(keptVows: VowSigil.healAfterKept, breakKeptSnapshots: [0]).activeFractures, 0)
    }

    /// Regression: healing is measured from the break, not from lifetime keeps.
    /// A seasoned user (many lifetime keeps) who breaks a vow must still see the
    /// fracture — it can't be instantly healed by past keeps.
    func testNewBreakIsNotInstantlyHealedByPriorKeeps() {
        // Break happened at 10 keeps; still at 10 → 0 keeps since break → fractured.
        XCTAssertEqual(VowSigil(keptVows: 10, breakKeptSnapshots: [10]).activeFractures, 1)
        // Two more keeps → still mending (2 < 3).
        XCTAssertEqual(VowSigil(keptVows: 12, breakKeptSnapshots: [10]).activeFractures, 1)
        // Three keeps after the break → healed.
        XCTAssertEqual(VowSigil(keptVows: 13, breakKeptSnapshots: [10]).activeFractures, 0)
    }

    func testFracturesHealIndependentlyPerBreak() {
        // Break A at 0 keeps (healed by keptVows 9), break B at 8 keeps (1 since → fractured).
        XCTAssertEqual(VowSigil(keptVows: 9, breakKeptSnapshots: [0, 8]).activeFractures, 1)
    }

    func testSegmentsNeverNegative() {
        XCTAssertEqual(VowSigil(keptVows: -4, breakKeptSnapshots: []).sealedSegments, 0)
    }
}
