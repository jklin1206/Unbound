import XCTest
@testable import UNBOUND

/// Locks the rank-library "one row per movement" fold, now driven by the
/// authoritative owning-skill join (`MovementCatalog.owningSkillId`) instead of
/// the old name/art heuristic: a movement row folds into a skill row iff it
/// resolves to a shown skill. True twins + regression drills collapse; a
/// genuinely different movement keeps its own row.
final class ProgramRankLibraryFoldTests: XCTestCase {

    private let shownSkillIds = Set(SkillGraph.shared.nodes.map(\.id))

    /// Mirrors the `loadRanks` filter: a movement row folds away when its owning
    /// skill is one of the shown skill rows.
    private func folds(_ movementId: String) -> Bool {
        guard let owning = MovementCatalog.owningSkillId(forMovementId: movementId) else { return false }
        return shownSkillIds.contains(owning)
    }

    func testTrueTwinExerciseAndDrillFoldIntoTheirSkill() {
        XCTAssertTrue(folds("exercise.hollow-hold"), "the Hollow Body Hold exercise folds into its skill")
        XCTAssertTrue(folds("skill-drill.hollow-body-hold"), "the Hollow Body Hold drill folds into its skill")
        XCTAssertEqual(MovementCatalog.owningSkillId(forMovementId: "exercise.hollow-hold"), "cl.hollow-body-30")
    }

    func testExactNameTwinFolds() {
        XCTAssertTrue(folds("exercise.pushup"))
        XCTAssertEqual(MovementCatalog.owningSkillId(forMovementId: "exercise.pushup"), "cal.pushup")
    }

    func testRegressionDrillFoldsIntoItsSkill() {
        // Tuck L-Sit is an easier regression, not the L-Sit movement itself, but
        // it still belongs under the L-Sit skill row.
        XCTAssertTrue(folds("skill-drill.tuck-l-sit"))
        XCTAssertEqual(MovementCatalog.owningSkillId(forMovementId: "skill-drill.tuck-l-sit"), "cal.l-sit-10")
    }

    func testDistinctMovementsKeepTheirOwnRow() {
        // Hollow Rock associates with the hollow skill but is a distinct movement.
        XCTAssertFalse(folds("exercise.hollow-rock"))
        XCTAssertNil(MovementCatalog.owningSkillId(forMovementId: "exercise.hollow-rock"))
        // An unrelated barbell lift never folds.
        XCTAssertFalse(folds("exercise.bench-press"))
    }

    func testAssociatedExerciseResolvesToItsOwnSkillNotAnAssociatedOne() {
        // Hanging Knee Raise IS its own skill; it must resolve there, never into
        // the hollow skill it merely associates with.
        XCTAssertEqual(
            MovementCatalog.owningSkillId(forMovementId: "exercise.hanging-knee-raise"),
            "cl.hanging-knee-raise"
        )
    }
}
