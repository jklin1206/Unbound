import XCTest
@testable import UNBOUND

/// Every exercise in the gym catalog must resolve to a real rank path —
/// compound table (directly or via alias), accessory family, weighted-pullup
/// anchors, or a bodyweight reps/hold ladder — or be EXPLICITLY listed in
/// `UnrankedMovements`. A movement in none of them silently renders the same
/// floor tier for any load, which is how 71 of the 2026-07 catalog additions
/// shipped rankless.
final class StandardsCoverageTests: XCTestCase {

    func testEveryCatalogExerciseHasARankPathOrIsExplicitlyUnranked() {
        var uncovered: [String] = []

        for exercise in ExerciseCatalog.allExercises {
            let name = exercise.name
            if StrengthStandards.isUnranked(exerciseKey: name) { continue }

            let resolved = MovementResolver.resolve(name)
            switch resolved.rankTemplate {
            case .bodyweightReps, .holdControl:
                // Bodyweight ladders always resolve (node criteria, named
                // fallback, or difficulty-generic anchors).
                continue
            case .weightedBodyweight:
                // Added-kg anchors from the weighted-pullup skill node.
                continue
            case .carrySled, .cardioPerformance, .mobilityDuration, .routineCompletion, .unranked:
                // Non-strength paths keep their own XP treatment.
                continue
            case .barbellStrength, .machineStrength:
                break
            }

            // Loaded path: a probe load must produce a tier. Any anchored
            // table returns a tier for any positive load, so nil == no
            // standards coverage at all.
            let ranked = StrengthStandards.rank(
                liftKg: 100,
                bodyweightKg: 80,
                exerciseKey: name,
                sex: .male
            )
            if ranked == nil {
                uncovered.append(name)
            }
        }

        XCTAssertTrue(
            uncovered.isEmpty,
            """
            \(uncovered.count) catalog exercises have NO rank path and are not \
            explicitly unranked — wire each into CompoundStandards (or an \
            alias), an AccessoryStandards family, or UnrankedMovements:
            \(uncovered.sorted().joined(separator: "\n"))
            """
        )
    }

    /// Every explicitly-unranked name should still be a real catalog / catalog-
    /// resolvable movement — a typo here silently un-unranks the intended one.
    func testUnrankedNamesResolveToKnownMovements() {
        for name in UnrankedMovements.names {
            XCTAssertNotNil(
                MovementCatalog.canonicalExercise(named: name),
                "UnrankedMovements entry '\(name)' does not resolve to a catalog exercise"
            )
        }
    }
}
