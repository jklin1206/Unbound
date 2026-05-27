import XCTest
@testable import UNBOUND

final class RegionFatigueBudgetTests: XCTestCase {
    func testCrossRegionAddsDoNotCreateTrim() {
        let sources = [
            RegionFatigueSource(kind: .skillBlock, regionLoad: RegionLoad([.pull: 2])),
            RegionFatigueSource(kind: .weeklyVow, regionLoad: RegionLoad([.legs: 2]))
        ]
        let budget = RegionLoad([.pull: 3, .legs: 3])

        XCTAssertTrue(RegionFatigueBudget.trimRecommendations(sources: sources, budget: budget).isEmpty)
    }

    func testSameRegionOverBudgetTrimsOnlyThatRegion() throws {
        let sources = [
            RegionFatigueSource(kind: .plannedWorkout, regionLoad: RegionLoad([.pull: 3])),
            RegionFatigueSource(kind: .skillBlock, regionLoad: RegionLoad([.pull: 2]), protected: true),
            RegionFatigueSource(kind: .weeklyVow, regionLoad: RegionLoad([.legs: 1]))
        ]
        let budget = RegionLoad([.pull: 4, .legs: 3])

        let trims = RegionFatigueBudget.trimRecommendations(sources: sources, budget: budget)

        XCTAssertEqual(trims.map(\.region), [.pull])
        XCTAssertEqual(trims.first?.excessLoad, 1)
        XCTAssertEqual(trims.first?.protectedLoad, 2)
        XCTAssertEqual(trims.first?.reason.reasonCategory, .accessoryRemoved)
        XCTAssertEqual(trims.first?.reason.regionScope, .pull)
        XCTAssertEqual(trims.first?.reason.revertible, true)
    }

    func testEmptyWeekHasNoTrim() {
        XCTAssertTrue(
            RegionFatigueBudget.trimRecommendations(sources: [], budget: RegionLoad()).isEmpty
        )
    }

    func testWorkoutRegionLoadUsesRoleWeightedBodyLedger() {
        let workout = Workout(
            name: "Push",
            targetMuscleGroups: [.chest, .shoulders, .arms],
            warmup: [],
            mainExercises: [
                Exercise(
                    id: "bench",
                    name: "Bench Press",
                    muscleGroups: [.chest, .shoulders, .arms],
                    sets: 4,
                    reps: "6-8",
                    restSeconds: 120,
                    rpe: 8,
                    notes: nil,
                    substitution: nil
                )
            ],
            cooldown: [],
            estimatedMinutes: 45,
            notes: nil,
            blockType: nil
        )

        let load = RegionFatigueBudget.regionLoad(for: workout)

        XCTAssertEqual(load[.push], 5.4, accuracy: 0.001)
        XCTAssertEqual(load[.shoulders], 1.4, accuracy: 0.001)
    }

    func testDraftRegionLoadCarriesSkillMobilityAndTendonStress() {
        let draft = TrainingSessionDraft(
            userId: "u1",
            source: .routine,
            title: "Skill + Carry",
            estimatedMinutes: 32,
            blocks: [
                TrainingBlock(
                    kind: .skill,
                    title: "Handstand",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Freestanding Handstand",
                            sets: 5,
                            target: .holdSeconds(20),
                            restSeconds: 90
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .routine,
                    title: "Mobility",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Deep Squat Hold",
                            sets: 2,
                            target: .holdSeconds(45),
                            restSeconds: 20
                        )
                    ]
                ),
                TrainingBlock(
                    kind: .carry,
                    title: "Loaded Carry",
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: "Farmer Carry",
                            sets: 4,
                            target: .distanceMeters(40),
                            restSeconds: 90,
                            muscleGroups: [.back, .arms, .shoulders]
                        )
                    ]
                )
            ]
        )

        let load = RegionFatigueBudget.regionLoad(for: draft)

        XCTAssertGreaterThan(load[.shoulders], 0)
        XCTAssertGreaterThan(load[.posterior], 0)
        XCTAssertGreaterThan(load[.pull], 0)
        XCTAssertGreaterThan(load[.legs], 0)
    }
}
