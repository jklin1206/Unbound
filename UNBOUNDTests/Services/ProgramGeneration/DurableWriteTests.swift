import XCTest
@testable import UNBOUND

final class DurableWriteTests: XCTestCase {

    private enum WriteError: Error { case boom }

    func testRunsWriteOnceWhenItSucceeds() async {
        var calls = 0
        let landed = await DurableWrite.attempt("t", attempts: 3) {
            calls += 1
        }
        XCTAssertTrue(landed)
        XCTAssertEqual(calls, 1, "A first-try success must not retry")
    }

    func testRetriesUntilAWriteLands() async {
        var calls = 0
        let landed = await DurableWrite.attempt("t", attempts: 3) {
            calls += 1
            if calls < 2 { throw WriteError.boom }
        }
        XCTAssertTrue(landed)
        XCTAssertEqual(calls, 2, "Must retry after a transient failure, then stop once it lands")
    }

    func testReturnsFalseAfterExhaustingEveryAttempt() async {
        var calls = 0
        let landed = await DurableWrite.attempt("t", attempts: 3) {
            calls += 1
            throw WriteError.boom
        }
        XCTAssertFalse(landed, "A write that never lands must report failure, not silent success")
        XCTAssertEqual(calls, 3, "Must exhaust exactly the requested number of attempts")
    }
}
