import Foundation
@testable import UNBOUND

enum ProgramTestFactory {
    static func makeDay(
        dayNumber: Int,
        label: String = "Generated",
        role: SessionRole = .push,
        muscleGroups: [MuscleGroup] = [.chest]
    ) -> ProgramDay {
        ProgramDay(
            id: "day-\(dayNumber)",
            dayNumber: dayNumber,
            label: label,
            isRestDay: false,
            workout: Workout(
                name: label,
                targetMuscleGroups: muscleGroups,
                warmup: [],
                mainExercises: [
                    Exercise(
                        id: "exercise-\(dayNumber)",
                        name: label,
                        muscleGroups: muscleGroups,
                        sets: 3,
                        reps: "8-10",
                        restSeconds: 90
                    )
                ],
                cooldown: [],
                estimatedMinutes: 45,
                notes: nil,
                blockType: .accumulation
            ),
            sessionRole: role,
            nutritionOverride: nil,
            recoveryActivities: []
        )
    }

    static func makeProgram(
        days: [ProgramDay],
        createdAt: Date,
        withArc: Bool = false
    ) -> TrainingProgram {
        let arc = Arc(id: "arc-1", programId: "program-1", startDate: createdAt)
        return TrainingProgram(
            id: "program-1",
            scanId: "scan-1",
            analysisId: "analysis-1",
            userId: "user-1",
            createdAt: createdAt,
            name: "Arc",
            description: "Test program",
            durationDays: 28,
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2200,
                proteinGrams: 160,
                carbsGrams: 240,
                fatGrams: 70,
                mealCount: 4,
                meals: [],
                hydrationLiters: 3,
                supplements: [],
                notes: "",
                restDayCalories: 2000,
                restDayProteinGrams: 160,
                restDayCarbsGrams: 200,
                restDayFatGrams: 70
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8,
                restDaysPerWeek: 2,
                activities: [],
                notes: ""
            ),
            difficultyLevel: .intermediate,
            requiredEquipment: [],
            estimatedDailyMinutes: 45,
            arcs: withArc ? [arc] : [],
            currentArcId: withArc ? arc.id : nil
        )
    }
}
