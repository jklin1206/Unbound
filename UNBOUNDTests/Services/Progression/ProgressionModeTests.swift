import XCTest
@testable import UNBOUND

final class ProgressionModeTests: XCTestCase {
    func testCasesExist() {
        _ = ProgressionMode.advance
        _ = ProgressionMode.preserve
    }

    func testEquatability() {
        XCTAssertEqual(ProgressionMode.advance, .advance)
        XCTAssertNotEqual(ProgressionMode.advance, .preserve)
    }
}
