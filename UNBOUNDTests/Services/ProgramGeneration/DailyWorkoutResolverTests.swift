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

    func testEquipmentModifierSubstitutesSameSlotCompatibleMovement() {
        let workout = Workout(
            name: "Travel Push",
            targetMuscleGroups: [.chest],
            warmup: [],
            mainExercises: [
                exercise("bench press", sets: 4)
            ],
            cooldown: [],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 1,
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(
                availableEquipment: [.dumbbells, .bench]
            )
        )

        let prescription = draft.blocks.first(where: { $0.kind == .strength })?.prescriptions.first
        XCTAssertEqual(prescription?.exerciseName, "Dumbbell Bench Press")
        XCTAssertEqual(prescription?.sets, 4)
        XCTAssertTrue(prescription?.notes?.contains("today's modifiers") == true)
        XCTAssertEqual(prescription.flatMap { MovementCatalog.definition(for: $0.movementId ?? "") }?.movementSlot, .horizontalPush)
        XCTAssertEqual(prescription.flatMap { MovementCatalog.definition(for: $0.rankStandardMovementId ?? "") }?.movementSlot, .horizontalPush)
    }

    func testTravelEquipmentModifierSwapsGymPullDayToBandSafeMovements() {
        let workout = Workout(
            name: "Travel Pull",
            targetMuscleGroups: [.back, .lats],
            warmup: [],
            mainExercises: [
                exercise("lat pulldown", sets: 3),
                exercise("cable row (seated)", sets: 3),
                exercise("barbell curl", sets: 2)
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
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(
                availableEquipment: [.bodyweight, .bands]
            )
        )

        let prescriptions = draft.blocks.first(where: { $0.kind == .strength })?.prescriptions ?? []
        XCTAssertEqual(prescriptions.count, 3)
        XCTAssertTrue(prescriptions.contains { $0.exerciseName == "Band Lat Pull" })
        XCTAssertTrue(prescriptions.contains { $0.exerciseName == "Band Row" })
        XCTAssertTrue(prescriptions.contains { $0.exerciseName == "Band Curl" })
        XCTAssertTrue(prescriptions.allSatisfy { prescription in
            guard let definition = prescription.movementId.flatMap(MovementCatalog.definition(for:)) else {
                return false
            }
            return MovementCatalog.isProgramCompatible(
                definition,
                style: .hybrid,
                userEquipment: [.bodyweight, .bands]
            )
        })
        XCTAssertTrue(prescriptions.allSatisfy { $0.notes?.contains("today's modifiers") == true })
    }

    func testResolvedTravelWorkoutSwapsCommonGymAccessoriesToBodyweightBandSafeMovements() {
        let workout = Workout(
            name: "Travel Full Body",
            targetMuscleGroups: [.chest, .shoulders, .arms, .core, .legs, .glutes],
            warmup: [
                exercise("world's greatest stretch", sets: 1, reps: "45s")
            ],
            mainExercises: [
                exercise("decline bench press", sets: 3),
                exercise("arnold press", sets: 3),
                exercise("cable curl", sets: 2),
                exercise("cable fly", sets: 2),
                exercise("cable crunch", sets: 2),
                exercise("cable hip abduction", sets: 2),
                exercise("leg curl (lying)", sets: 2)
            ],
            cooldown: [],
            estimatedMinutes: 45,
            notes: nil,
            blockType: nil
        )

        let resolved = DailyWorkoutResolver.resolvedWorkout(
            from: workout,
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(
                availableEquipment: [.bodyweight, .bands]
            )
        )

        XCTAssertEqual(resolved.warmup.count, workout.warmup.count)
        XCTAssertEqual(resolved.mainExercises.count, workout.mainExercises.count)
        XCTAssertTrue(resolved.mainExercises.allSatisfy { exercise in
            guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
                return false
            }
            return MovementCatalog.isProgramCompatible(
                definition,
                style: .bodyweight,
                userEquipment: [.bodyweight, .bands]
            )
        })
        XCTAssertTrue(resolved.mainExercises.allSatisfy { $0.substitution != nil })
        XCTAssertTrue(resolved.mainExercises.contains { $0.name.localizedCaseInsensitiveContains("pushup") })
        XCTAssertTrue(resolved.mainExercises.contains { $0.name.localizedCaseInsensitiveContains("band") })
        XCTAssertEqual(
            Set(resolved.mainExercises.map { MovementCatalog.normalized($0.name) }).count,
            resolved.mainExercises.count
        )
    }

    func testTravelSubstitutionsAvoidDuplicateReplacementsWhenPossible() {
        let workout = Workout(
            name: "Travel Arms",
            targetMuscleGroups: [.arms],
            warmup: [],
            mainExercises: [
                exercise("barbell curl", sets: 3),
                exercise("cable curl", sets: 3),
                exercise("tricep pushdown", sets: 3)
            ],
            cooldown: [],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let resolved = DailyWorkoutResolver.resolvedWorkout(
            from: workout,
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(
                availableEquipment: [.bodyweight, .bands]
            )
        )

        let names = resolved.mainExercises.map { MovementCatalog.normalized($0.name) }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertTrue(resolved.mainExercises.allSatisfy { exercise in
            guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
                return false
            }
            return MovementCatalog.isProgramCompatible(
                definition,
                style: .hybrid,
                userEquipment: [.bodyweight, .bands]
            )
        })
    }

    func testDeloadModifierReducesVolumeWithoutDroppingExercise() {
        let workout = Workout(
            name: "Deload Pull",
            targetMuscleGroups: [.back],
            warmup: [],
            mainExercises: [
                exercise("lat pulldown", sets: 4),
                exercise("cable row (seated)", sets: 3)
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
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(deloadFactor: 0.5)
        )

        let strength = draft.blocks.first { $0.kind == .strength }
        XCTAssertEqual(strength?.prescriptions.first { $0.exerciseName == "lat pulldown" }?.sets, 2)
        XCTAssertEqual(strength?.prescriptions.first { $0.exerciseName == "cable row (seated)" }?.sets, 1)
        XCTAssertTrue(strength?.prescriptions.allSatisfy { $0.notes?.contains("Deload modifier") == true } == true)
    }

    func testAvoidedMovementModifierSwapsCompatibleAlternative() {
        let workout = Workout(
            name: "Avoided Push",
            targetMuscleGroups: [.chest],
            warmup: [],
            mainExercises: [
                exercise("bench press", sets: 3)
            ],
            cooldown: [],
            estimatedMinutes: 35,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 1,
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(
                availableEquipment: [.fullGym],
                avoidedMovementIds: ["exercise.bench-press"]
            )
        )

        let prescription = draft.blocks.first(where: { $0.kind == .strength })?.prescriptions.first
        XCTAssertNotEqual(prescription?.exerciseName, "bench press")
        XCTAssertEqual(prescription.flatMap { MovementCatalog.definition(for: $0.movementId ?? "") }?.movementSlot, .horizontalPush)
        XCTAssertEqual(prescription.flatMap { MovementCatalog.definition(for: $0.rankStandardMovementId ?? "") }?.movementSlot, .horizontalPush)
        XCTAssertTrue(prescription?.notes?.contains("today's modifiers") == true)
    }

    func testTrialPrepModifierAddsMissingRequirementBlock() {
        let workout = Workout(
            name: "Base Day",
            targetMuscleGroups: [.legs],
            warmup: [],
            mainExercises: [
                exercise("goblet squat", sets: 3)
            ],
            cooldown: [],
            estimatedMinutes: 30,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 4,
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(
                trialPrepMovementIds: ["exercise.pushup"]
            )
        )

        let strength = draft.blocks.first { $0.kind == .strength }
        XCTAssertEqual(strength?.prescriptions.count, 2)
        XCTAssertEqual(strength?.prescriptions.last?.exerciseName, "pushup")
        XCTAssertEqual(strength?.prescriptions.last?.sets, 2)
        XCTAssertTrue(strength?.prescriptions.last?.notes?.contains("Trial prep") == true)
    }

    func testShortSessionModifierKeepsPriorityMovementsAndSummarizes() {
        let workout = Workout(
            name: "Upper Short",
            targetMuscleGroups: [.chest, .back],
            warmup: [],
            mainExercises: [
                exercise("bench press", sets: 4),
                exercise("lat pulldown", sets: 4),
                exercise("cable row (seated)", sets: 3),
                exercise("barbell curl", sets: 3),
                exercise("tricep pushdown", sets: 3)
            ],
            cooldown: [],
            estimatedMinutes: 55,
            notes: nil,
            blockType: nil
        )

        let draft = DailyWorkoutResolver.programDraft(
            from: workout,
            userId: "u1",
            programId: "p1",
            dayNumber: 1,
            scheduledSkillIds: [],
            modifierContext: DailyWorkoutModifierContext(shortSessionActive: true)
        )

        let prescriptions = draft.blocks.first { $0.kind == .strength }?.prescriptions ?? []
        XCTAssertEqual(prescriptions.map(\.exerciseName), ["bench press", "lat pulldown", "cable row (seated)"])
        XCTAssertTrue(prescriptions.allSatisfy { $0.notes?.contains("Short mode") == true })
        let summary = ProgramModifierSummary.summarize(draft: draft)
        XCTAssertTrue(summary.lines.contains { $0.kind == .shortSession })
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
