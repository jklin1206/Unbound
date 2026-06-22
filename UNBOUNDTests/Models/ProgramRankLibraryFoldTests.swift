import XCTest
@testable import UNBOUND

/// Locks the rank-library "one row per movement" fold: a movement that is also
/// represented by a shown skill (as a drill, a target, or a same-art exercise)
/// must collapse into that skill row, while a genuinely different movement that
/// merely *associates* with the skill must keep its own row.
final class ProgramRankLibraryFoldTests: XCTestCase {

    private let hollowSkillId = "cl.hollow-body-30"
    private lazy var hollowAsset = ExerciseVisualAsset
        .existingAssetName(forMovementId: "skill.\(hollowSkillId)")

    private func shownHollowSkill() -> (ids: Set<String>, names: Set<String>, assets: Set<String>) {
        let asset = try? XCTUnwrap(hollowAsset)
        return (
            ids: [hollowSkillId],
            names: [],                                  // isolate the id/asset signals
            assets: Set([asset].compactMap { $0 })
        )
    }

    func testSkillDrillFoldsIntoItsOwningSkill() {
        let shown = shownHollowSkill()
        XCTAssertTrue(
            ProgramRankLibraryView.movementFoldsIntoShownSkill(
                title: "Hollow Body Hold",
                sourceId: "skill-drill.hollow-body-hold",
                visualAssetName: ExerciseVisualAsset.existingAssetName(forMovementId: "skill-drill.hollow-body-hold"),
                shownSkillIds: shown.ids,
                shownSkillNames: shown.names,
                shownSkillAssets: shown.assets
            ),
            "The Hollow Body Hold drill should fold into the Hollow Body skill"
        )
    }

    func testSameArtExerciseFoldsIntoTheSkill() {
        let shown = shownHollowSkill()
        XCTAssertTrue(
            ProgramRankLibraryView.movementFoldsIntoShownSkill(
                title: "Hollow Hold",
                sourceId: "exercise.hollow-hold",
                visualAssetName: ExerciseVisualAsset.existingAssetName(forMovementId: "exercise.hollow-hold"),
                shownSkillIds: shown.ids,
                shownSkillNames: shown.names,
                shownSkillAssets: shown.assets
            ),
            "The Hollow Hold exercise shares the skill's art + link, so it should fold"
        )
    }

    func testDifferentMovementThatMerelyAssociatesStaysVisible() {
        let shown = shownHollowSkill()
        // Hollow Rock associates with cl.hollow-body-30 but is a distinct
        // (dynamic, rep-based) movement with its own art — it must NOT fold.
        XCTAssertFalse(
            ProgramRankLibraryView.movementFoldsIntoShownSkill(
                title: "Hollow Rock",
                sourceId: "exercise.hollow-rock",
                visualAssetName: ExerciseVisualAsset.existingAssetName(forMovementId: "exercise.hollow-rock"),
                shownSkillIds: shown.ids,
                shownSkillNames: shown.names,
                shownSkillAssets: shown.assets
            ),
            "Hollow Rock only associates with the skill — it must keep its own row"
        )
    }

    func testDistinctSkillAssociatedExercisesStayVisible() {
        let shown = shownHollowSkill()
        // These all carry skillAssociations:[cl.hollow-body-30] but are distinct
        // movements with their own art — over-folding would wrongly hide them.
        for (title, id) in [("Hanging Knee Raise", "exercise.hanging-knee-raise"),
                            ("Hanging Leg Raise", "exercise.hanging-leg-raise")] {
            XCTAssertFalse(
                ProgramRankLibraryView.movementFoldsIntoShownSkill(
                    title: title,
                    sourceId: id,
                    visualAssetName: ExerciseVisualAsset.existingAssetName(forMovementId: id),
                    shownSkillIds: shown.ids,
                    shownSkillNames: shown.names,
                    shownSkillAssets: shown.assets
                ),
                "\(title) associates with the hollow skill but is a distinct movement — must stay visible"
            )
        }
    }

    func testExactNameTwinFolds() {
        // Push-Up exercise vs a Push-Up skill row: normalized-name twin.
        XCTAssertTrue(
            ProgramRankLibraryView.movementFoldsIntoShownSkill(
                title: "Push-Up",
                sourceId: "exercise.pushup",
                visualAssetName: nil,
                shownSkillIds: [],
                shownSkillNames: ["pushup"],
                shownSkillAssets: []
            )
        )
    }

    func testUnrelatedExerciseDoesNotFold() {
        XCTAssertFalse(
            ProgramRankLibraryView.movementFoldsIntoShownSkill(
                title: "Bench Press",
                sourceId: "exercise.bench-press",
                visualAssetName: ExerciseVisualAsset.existingAssetName(forMovementId: "exercise.bench-press"),
                shownSkillIds: ["cl.hollow-body-30"],
                shownSkillNames: ["hollowbody"],
                shownSkillAssets: ["exercise_visual_exercise_hollow-hold"]
            )
        )
    }
}
