import XCTest
@testable import UNBOUND

final class VowSigilTests: XCTestCase {
    func testSealedSegmentsEqualKeptVows() {
        XCTAssertEqual(VowSigil(keptVows: 0).sealedSegments, 0)
        XCTAssertEqual(VowSigil(keptVows: 7).sealedSegments, 7)
    }

    func testSegmentsNeverNegative() {
        XCTAssertEqual(VowSigil(keptVows: -4).sealedSegments, 0)
    }
}
