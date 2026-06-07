import XCTest
@testable import UNBOUND

@MainActor
final class TrainingSessionAdapterTests: XCTestCase {
    func makeDraft(_ exerciseNames: [String]) -> TrainingSessionDraft {
        TrainingSessionDraft(
            id: "draft-edit-summary",
            userId: "u1",
            source: .program,
            title: "Power Upper",
            estimatedMinutes: 45,
            blocks: [
                TrainingBlock(
                    id: "block-1",
                    kind: .strength,
                    title: "Power Upper",
                    prescriptions: exerciseNames.map(makePrescription)
                )
            ]
        )
    }

    func makePrescription(_ exerciseName: String) -> TrainingBlockPrescription {
        TrainingBlockPrescription(
            exerciseName: exerciseName,
            sets: 3,
            target: .repsRange(6, 10),
            restSeconds: 120,
            muscleGroups: [.chest],
            rpe: 8
        )
    }

    func makeSkillRungPerformanceLog(
        skillId: String,
        skillTitle: String,
        rungId: String,
        exerciseName: String,
        sets: [PerformanceSet]
    ) -> PerformanceLog {
        PerformanceLog(
            id: "perf-\(rungId)",
            userId: "u1",
            source: .skill,
            title: skillTitle,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 700),
            blocks: [
                PerformanceBlock(
                    id: "skill-block",
                    kind: .skill,
                    title: skillTitle,
                    skillId: skillId,
                    selectedRungId: rungId,
                    selectedRungSource: .regression,
                    selectedRungReason: "Test review path.",
                    exercises: [
                        PerformanceExercise(
                            name: exerciseName,
                            plannedSets: 3,
                            plannedTarget: "5-8 reps",
                            sets: sets
                        )
                    ],
                    durationSeconds: 600
                )
            ]
        )
    }
}
