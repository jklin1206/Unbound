import XCTest
import UIKit
@testable import UNBOUND

final class RoutineLibraryTests: XCTestCase {

    func testRoutinesAllWellFormed() {
        let routines = RoutineLibrary.placeholderRoutines
        XCTAssertEqual(routines.count, 29)
        XCTAssertEqual(Set(routines.map(\.id)).count, 29, "duplicate routine id")

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

    func testRoutinesUseNamedDifficultyTiers() {
        let routines = RoutineLibrary.placeholderRoutines
        XCTAssertEqual(Set(routines.map(\.difficultyTier)), Set(SkillTier.allCases))

        for routine in routines {
            XCTAssertFalse(routine.difficultyTier.displayName.isEmpty, "\(routine.id): missing difficulty title")
            XCTAssertTrue(
                UIImage(named: routine.difficultyTier.assetName) != nil,
                "\(routine.id): missing difficulty badge \(routine.difficultyTier.assetName)"
            )
        }
    }

    func testRoutinesSortEasiestToHardest() {
        assertSortedByDifficulty(RoutineLibrary.routinesSortedByDifficulty, context: "all routines")

        for category in RoutineCategory.allCases {
            assertSortedByDifficulty(RoutineLibrary.routines(category: category), context: category.label)
        }
    }

    func testRoutineCopyDoesNotUseLegacyLetterRanks() {
        let bannedTerms = [
            "e-rank", "d-rank", "c-rank", "b-rank", "a-rank", "s-rank",
            "e rank", "d rank", "c rank", "b rank", "a rank", "s rank"
        ]

        for routine in RoutineLibrary.placeholderRoutines {
            let searchable = routineSearchText(routine)
            for term in bannedTerms {
                XCTAssertFalse(
                    searchable.contains(term),
                    "\(routine.id): routine copy still references legacy letter rank term \(term)"
                )
            }
        }
    }

    func testRoutineCoverAssetsAreBundled() {
        for routine in RoutineLibrary.placeholderRoutines {
            let assetName = "routine_challenge_\(routine.id)"
            XCTAssertNotNil(
                UIImage(named: assetName),
                "\(routine.id): missing bundled routine cover asset \(assetName)"
            )
        }
    }

    func testMobilityLibraryCoversMajorRegions() {
        let mobility = RoutineLibrary.placeholderRoutines.filter { $0.category == .mobility }
        XCTAssertEqual(mobility.count, 9)
        XCTAssertTrue(mobility.map(\.id).contains("shoulder-spine-12"))
        XCTAssertTrue(mobility.map(\.id).contains("ankle-squat-10"))
        XCTAssertTrue(mobility.map(\.id).contains("posterior-chain-12"))
        XCTAssertTrue(mobility.map(\.id).contains("full-body-unlock-20"))
    }

    func testMobilityReferencesUsePoseAssetStandard() {
        for reference in MobilityReferenceLibrary.all {
            XCTAssertFalse(reference.cameraAngle.isEmpty, "\(reference.id): missing camera angle")
            XCTAssertFalse(reference.primaryPose.isEmpty, "\(reference.id): missing primary pose")

            switch reference.visualType {
            case .singlePose:
                XCTAssertNil(reference.secondaryPose, "\(reference.id): static stretches should use one pose")
                XCTAssertEqual(reference.expectedAssetNames, ["mobility_reference_\(reference.id)"])
            case .startEnd:
                XCTAssertNotNil(reference.secondaryPose, "\(reference.id): dynamic drills need an end pose")
                XCTAssertEqual(
                    reference.expectedAssetNames,
                    ["mobility_reference_\(reference.id)_start", "mobility_reference_\(reference.id)_end"]
                )
            }
        }
    }

    func testMobilityReferenceAssetsAreBundled() {
        for reference in MobilityReferenceLibrary.all {
            for assetName in reference.expectedAssetNames {
                XCTAssertNotNil(
                    UIImage(named: assetName),
                    "\(reference.id): missing bundled mobility asset \(assetName)"
                )
            }
        }
    }

    func testMobilityRoutineStepsResolveReferenceVisuals() {
        let mobility = RoutineLibrary.placeholderRoutines.filter { $0.category == .mobility }

        for routine in mobility {
            let (run, _) = RoutineRun.build(routine.steps)
            for step in run {
                switch step.kind {
                case .instruction(let text, let cue):
                    XCTAssertNotNil(
                        MobilityReferenceLibrary.reference(for: "\(text) \(cue ?? "")"),
                        "\(routine.id): missing mobility reference for \(text)"
                    )
                case .timed(let label, _, let style):
                    guard style == .work else { continue }
                    XCTAssertNotNil(
                        MobilityReferenceLibrary.reference(for: label),
                        "\(routine.id): missing mobility reference for \(label)"
                    )
                case .interval, .repTarget, .note, .circuit:
                    break
                }
            }
        }
    }

    func testSideQuestMobilityExercisesResolveReferenceVisuals() {
        let mobility = SideQuestLibrary.all.filter { $0.category == .mobility }
        XCTAssertGreaterThanOrEqual(mobility.count, 5)

        for quest in mobility {
            for exercise in quest.exercises {
                XCTAssertNotNil(
                    MobilityReferenceLibrary.reference(for: "\(exercise.name) \(exercise.cue ?? "")"),
                    "\(quest.id): missing mobility reference for \(exercise.name)"
                )
            }
        }
    }

    func testRepTargetRoutinesPresent() {
        let ids = RoutineLibrary.placeholderRoutines
            .filter { $0.steps.contains {
                if case .repTarget = $0 { return true }; return false } }
            .map(\.id)
        XCTAssertTrue(ids.contains("100-pushup"))
    }

    func testFullBodyRoutineLibraryHasEasyOptions() {
        let ids = Set(
            RoutineLibrary.placeholderRoutines
                .filter { $0.category == .altCircuit }
                .map(\.id)
        )

        XCTAssertTrue(ids.contains("bw-full-30"))
        XCTAssertTrue(ids.contains("db-full-25"))
        XCTAssertTrue(ids.contains("hotel-full-20"))
        XCTAssertTrue(ids.contains("gym-full-45"))
        XCTAssertTrue(ids.contains("athletic-full-28"))
    }

    func testRoutineStepVisualAssetsAreBundled() {
        for assetName in RoutineStepVisualLibrary.expectedAssetNames {
            XCTAssertNotNil(
                UIImage(named: assetName),
                "missing bundled routine step visual \(assetName)"
            )
        }
    }

    func testFullBodyRoutinesResolveSomeExerciseVisuals() {
        let fullBodyIds: Set<String> = [
            "bw-full-30",
            "db-full-25",
            "hotel-full-20",
            "gym-full-45",
            "athletic-full-28"
        ]
        let routines = RoutineLibrary.placeholderRoutines.filter { fullBodyIds.contains($0.id) }

        for routine in routines {
            let (run, _) = RoutineRun.build(routine.steps)
            let visualCount = run.filter { step in
                switch step.kind {
                case .instruction(let text, let cue):
                    return RoutineStepVisualLibrary.assetName(for: "\(text) \(cue ?? "")") != nil
                case .timed(let label, _, let style):
                    return style == .work && RoutineStepVisualLibrary.assetName(for: label) != nil
                case .repTarget(let name, _, let cue):
                    return RoutineStepVisualLibrary.assetName(for: "\(name) \(cue ?? "")") != nil
                case .interval(let label, _, _):
                    return RoutineStepVisualLibrary.assetName(for: label) != nil
                case .note, .circuit:
                    return false
                }
            }.count

            XCTAssertGreaterThanOrEqual(visualCount, 4, "\(routine.id): expected several exercise visuals")
        }
    }

    private func assertSortedByDifficulty(_ routines: [RoutineDef], context: String) {
        let sorted = RoutineLibrary.sortedByDifficulty(routines)
        XCTAssertEqual(routines.map(\.id), sorted.map(\.id), "\(context) not sorted easiest-to-hardest")
    }

    private func routineSearchText(_ routine: RoutineDef) -> String {
        ([routine.title, routine.subtitle, routine.durationLabel] + routine.steps.flatMap(stepSearchText))
            .joined(separator: " ")
            .lowercased()
    }

    private func stepSearchText(_ step: RoutineStep) -> [String] {
        switch step {
        case .instruction(let text, let cue):
            return [text, cue].compactMap { $0 }
        case .timed(let label, _, _):
            return [label]
        case .interval(let label, _, let segments):
            return [label] + segments.map(\.label)
        case .repTarget(let name, _, let cue):
            return [name, cue].compactMap { $0 }
        case .circuit(_, _, let steps):
            return steps.flatMap(stepSearchText)
        case .note(let text):
            return [text]
        }
    }
}
