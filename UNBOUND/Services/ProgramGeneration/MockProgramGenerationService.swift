import Foundation

final class MockProgramGenerationService: ProgramGenerationServiceProtocol, @unchecked Sendable {
    func generateProgram(analysis: BodyAnalysis, userProfile: UserProfile) async throws -> TrainingProgram {
        try await Task.sleep(for: .seconds(2))

        let days = (1...14).map { dayNum in
            let isRest = dayNum % 4 == 0 || dayNum % 7 == 0
            return ProgramDay(
                id: UUID().uuidString,
                dayNumber: dayNum,
                label: isRest ? "Day \(dayNum): Rest & Recovery" : "Day \(dayNum): Upper Push + Shoulders",
                isRestDay: isRest,
                workout: isRest ? nil : Workout(
                    name: "Upper Push Hypertrophy",
                    targetMuscleGroups: [.chest, .shoulders, .arms],
                    warmup: [Exercise(id: UUID().uuidString, name: "Arm Circles", muscleGroups: [.shoulders], sets: 2, reps: "15", restSeconds: 30, rpe: nil, notes: nil, substitution: nil)],
                    mainExercises: [
                        Exercise(id: UUID().uuidString, name: "Overhead Press", muscleGroups: [.shoulders], sets: 4, reps: "8-12", restSeconds: 90, rpe: 8, notes: "Brace core, press overhead", substitution: "Dumbbell shoulder press"),
                        Exercise(id: UUID().uuidString, name: "Incline Bench Press", muscleGroups: [.chest, .shoulders], sets: 4, reps: "8-10", restSeconds: 90, rpe: 8, notes: "30-degree incline", substitution: "Incline dumbbell press")
                    ],
                    cooldown: [],
                    estimatedMinutes: 45,
                    notes: nil
                ),
                nutritionOverride: nil,
                recoveryActivities: []
            )
        }

        return TrainingProgram(
            id: UUID().uuidString,
            scanId: analysis.scanId,
            analysisId: analysis.id,
            userId: analysis.userId,
            createdAt: Date(),
            archetype: analysis.targetArchetype,
            name: "\(analysis.targetArchetype.displayName) Blueprint: Block 1",
            description: "A targeted program to move you closer to the \(analysis.targetArchetype.displayName) archetype.",
            durationDays: 28,
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2500, proteinGrams: 180, carbsGrams: 280, fatGrams: 80,
                mealCount: 4, meals: [], hydrationLiters: 3.0, supplements: ["Creatine 5g", "Vitamin D"],
                notes: "Prioritize protein timing around workouts",
                restDayCalories: 2200, restDayProteinGrams: 180, restDayCarbsGrams: 220, restDayFatGrams: 80
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8, restDaysPerWeek: 3,
                activities: [RecoveryActivity(id: UUID().uuidString, name: "Foam Rolling", description: "Full body foam roll", durationMinutes: 15, frequency: "Post-workout")],
                notes: "Sleep is the #1 recovery tool"
            ),
            difficultyLevel: .intermediate,
            requiredEquipment: ["Barbell", "Dumbbells", "Cable machine", "Pull-up bar"],
            estimatedDailyMinutes: 50,
            rationale: nil
        )
    }
}
