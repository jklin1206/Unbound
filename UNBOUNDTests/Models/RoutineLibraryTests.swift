import XCTest
@testable import UNBOUND

final class RoutineLibraryTests: XCTestCase {

    func testTwentyRoutinesAllWellFormed() {
        let routines = RoutineLibrary.placeholderRoutines
        XCTAssertEqual(routines.count, 20)
        XCTAssertEqual(Set(routines.map(\.id)).count, 20, "duplicate routine id")

        for r in routines {
            let (run, _) = RoutineRun.build(r.steps)
            XCTAssertFalse(run.isEmpty, "\(r.id): empty run")
            for s in run {
                switch s.kind {
                case .timed(_, let secs, _):
                    XCTAssertGreaterThan(secs, 0, "\(r.id): non-positive timed")
                case .interval(_, let rounds, let segs):
                    XCTAssertGreaterThan(rounds, 0, "\(r.id): interval rounds")
                    XCTAssertFalse(segs.isEmpty, "\(r.id): interval no segments")
                    for seg in segs {
                        XCTAssertGreaterThan(seg.seconds, 0, "\(r.id): interval seg")
                    }
                case .repTarget(_, let target, _):
                    if let t = target {
                        XCTAssertGreaterThan(t, 0, "\(r.id): repTarget target")
                    }
                case .note:
                    XCTFail("\(r.id): .note leaked into run")
                case .circuit:
                    XCTFail("\(r.id): .circuit not expanded")
                case .instruction:
                    break
                }
            }
        }
    }

    func testCategoriesCoverAllFour() {
        let cats = Set(RoutineLibrary.placeholderRoutines.map(\.category))
        XCTAssertEqual(cats, [.cardio, .mobility, .challenge, .altCircuit])
    }

    func testRepTargetRoutinesPresent() {
        let ids = RoutineLibrary.placeholderRoutines
            .filter { $0.steps.contains {
                if case .repTarget = $0 { return true }; return false } }
            .map(\.id)
        XCTAssertTrue(ids.contains("100-pushup"))
    }
}
