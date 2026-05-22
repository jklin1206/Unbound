import XCTest
@testable import UNBOUND

@MainActor
final class DailyWorkoutResolverTests: XCTestCase {
    func testPullupGoalAddsSkillBlockAndTapersVerticalPullVolume() {
        let workout = Workout(
            name: "Pull Day",
            targetMuscleGroups: [.back, .lats],
            warmup: [],
            mainExercises: [
                exercise("lat pulldown", sets: 4),
                exercise("cable row (seated)", sets: 3),
                exercise("barbell curl", sets: 3)
            ],
            cooldown: [],
            estimatedMinutes: 45,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 2,
            scheduledSkillIds: ["pp.pullup"]
        )

        let strength = draft.blocks.first { $0.kind == .strength }
        let skill = draft.blocks.first { $0.kind == .skill }
        XCTAssertEqual(skill?.skillId, "pp.pullup")
        XCTAssertEqual(strength?.prescriptions.first { $0.exerciseName == "lat pulldown" }?.sets, 3)
        XCTAssertEqual(strength?.prescriptions.first { $0.exerciseName == "cable row (seated)" }?.sets, 3)
        XCTAssertTrue(strength?.prescriptions.first { $0.exerciseName == "lat pulldown" }?.notes?.contains("scheduled skill work") == true)
    }

    func testHandstandGoalTapersVerticalPushFallbackSlot() {
        let workout = Workout(
            name: "Push Day",
            targetMuscleGroups: [.shoulders],
            warmup: [],
            mainExercises: [
                exercise("overhead press", sets: 4),
                exercise("bench press", sets: 3)
            ],
            cooldown: [],
            estimatedMinutes: 40,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 3,
            scheduledSkillIds: ["hs.freestanding-hs-30"]
        )

        let strength = draft.blocks.first { $0.kind == .strength }
        XCTAssertEqual(draft.blocks.first { $0.kind == .skill }?.skillId, "hs.freestanding-hs-30")
        XCTAssertEqual(strength?.prescriptions.first { $0.exerciseName == "overhead press" }?.sets, 3)
        XCTAssertEqual(strength?.prescriptions.first { $0.exerciseName == "bench press" }?.sets, 3)
    }

    func testSkillBlockStaysBeforeCooldown() {
        let workout = Workout(
            name: "Upper",
            targetMuscleGroups: [.chest],
            warmup: [exercise("pushup", sets: 1)],
            mainExercises: [exercise("bench press", sets: 3)],
            cooldown: [exercise("child pose", sets: 1, reps: "60s")],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 1,
            scheduledSkillIds: ["pp.pullup"]
        )

        XCTAssertEqual(draft.blocks.map(\.kind), [.bodyweight, .strength, .skill, .routine])
    }

    func testSkillOnlyDraftUsesWorkoutReadySpine() {
        let draft = DailyWorkoutResolver.skillOnlyDraft(skillId: "hs.wall-handstand-30", userId: "u1")

        XCTAssertEqual(draft?.source, .skill)
        XCTAssertEqual(draft?.blocks.count, 1)
        XCTAssertEqual(draft?.blocks.first?.kind, .skill)
        XCTAssertEqual(draft?.blocks.first?.skillId, "hs.wall-handstand-30")
        XCTAssertFalse(draft?.blocks.first?.prescriptions.isEmpty ?? true)
    }

    func testSkillDetailAddToProgramRoutesToNextEligibleProgramDayDraft() {
        let friday = date(year: 2026, month: 5, day: 22)
        let nextEligible = ProgramScheduler.shared.nextEligibleDate(
            forSkillId: "hs.wall-handstand-30",
            from: friday
        )

        XCTAssertNotNil(nextEligible)
        XCTAssertEqual(nextEligible.map { ProgramScheduler.shared.category(for: $0) }, .skills)

        let workout = Workout(
            name: "Upper",
            targetMuscleGroups: [.shoulders],
            warmup: [],
            mainExercises: [exercise("overhead press", sets: 3)],
            cooldown: [],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 6,
            date: nextEligible ?? friday,
            scheduledSkillIds: ["hs.wall-handstand-30"]
        )

        XCTAssertEqual(draft.date, nextEligible)
        XCTAssertEqual(draft.blocks.first(where: { $0.kind == .skill })?.skillId, "hs.wall-handstand-30")
        XCTAssertFalse(draft.blocks.first(where: { $0.kind == .skill })?.prescriptions.isEmpty ?? true)
    }

    private func exercise(_ name: String, sets: Int, reps: String = "8-10") -> Exercise {
        Exercise(
            id: UUID().uuidString,
            name: name,
            muscleGroups: [.back],
            sets: sets,
            reps: reps,
            restSeconds: 90,
            rpe: 8,
            notes: nil,
            substitution: nil
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar(identifier: .iso8601)
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day
        ))!
    }
}
