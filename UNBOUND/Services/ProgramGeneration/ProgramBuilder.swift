import Foundation

// Expands a Claude-generated 7-day weekly template into the full 84-day
// TrainingProgram, assigns stable UUIDs, and maps string muscle groups to
// the MuscleGroup enum. Falls back sensibly when LLM omits optional fields.

enum ProgramBuilder {

    static func build(
        from output: ProgramLLMOutput,
        userId: String,
        scanId: String,
        analysisId: String,
        buildIdentity: BuildIdentity
    ) -> TrainingProgram {
        // Sort week template by dayOfWeek, pad/truncate to exactly 7.
        var sorted = output.weekTemplate.sorted { $0.dayOfWeek < $1.dayOfWeek }
        while sorted.count < 7 {
            let missingDay = sorted.count + 1
            sorted.append(WeekDayOutput(dayOfWeek: missingDay, label: "Rest", isRestDay: true, workout: nil))
        }
        let week = Array(sorted.prefix(7))

        // Expand to 84 days, each with a fresh UUID.
        var days: [ProgramDay] = []
        for dayNumber in 1...84 {
            let templateIndex = (dayNumber - 1) % 7
            let template = week[templateIndex]
            let workout = template.workout.map(makeWorkout)
            days.append(ProgramDay(
                id: UUID().uuidString,
                dayNumber: dayNumber,
                label: template.label,
                isRestDay: template.isRestDay,
                workout: workout,
                nutritionOverride: nil,
                recoveryActivities: []
            ))
        }

        let nutrition = makeNutrition(from: output.nutritionPlan)
        let recovery = makeRecovery(from: output.recoveryPlan)
        let rationale = makeRationale(from: output.rationale)
        let difficulty = DifficultyLevel(rawValue: output.difficultyLevel) ?? .intermediate

        return TrainingProgram(
            id: UUID().uuidString,
            scanId: scanId,
            analysisId: analysisId,
            userId: userId,
            createdAt: Date(),
            name: output.name,
            description: output.description,
            durationDays: 84,
            days: days,
            nutritionPlan: nutrition,
            recoveryPlan: recovery,
            difficultyLevel: difficulty,
            requiredEquipment: output.requiredEquipment,
            estimatedDailyMinutes: output.estimatedDailyMinutes,
            rationale: rationale
        )
    }

    // MARK: - Helpers

    private static func makeWorkout(_ w: WorkoutOutput) -> Workout {
        Workout(
            name: w.name,
            targetMuscleGroups: mapGroups(w.targetMuscleGroups),
            warmup: w.warmup.map(makeExercise),
            mainExercises: w.mainExercises.map(makeExercise),
            cooldown: w.cooldown.map(makeExercise),
            estimatedMinutes: w.estimatedMinutes,
            notes: w.notes
        )
    }

    private static func makeExercise(_ e: ExerciseOutput) -> Exercise {
        Exercise(
            id: UUID().uuidString,
            name: e.name,
            muscleGroups: mapGroups(e.muscleGroups),
            sets: e.sets,
            reps: e.reps,
            restSeconds: e.restSeconds,
            rpe: e.rpe,
            notes: e.notes,
            substitution: e.substitution
        )
    }

    private static func mapGroups(_ strings: [String]) -> [MuscleGroup] {
        strings.compactMap { MuscleGroup(rawValue: $0) }
    }

    private static func makeNutrition(from n: NutritionPlanOutput) -> NutritionPlan {
        NutritionPlan(
            dailyCalories: n.dailyCalories,
            proteinGrams: n.proteinGrams,
            carbsGrams: n.carbsGrams,
            fatGrams: n.fatGrams,
            mealCount: n.mealCount,
            meals: n.meals.map { m in
                MealTemplate(
                    id: UUID().uuidString,
                    name: m.name,
                    timing: m.timing,
                    calories: m.calories,
                    protein: m.protein,
                    carbs: m.carbs,
                    fat: m.fat,
                    examples: m.examples
                )
            },
            hydrationLiters: n.hydrationLiters,
            supplements: n.supplements,
            notes: n.notes,
            restDayCalories: n.restDayCalories,
            restDayProteinGrams: n.restDayProteinGrams,
            restDayCarbsGrams: n.restDayCarbsGrams,
            restDayFatGrams: n.restDayFatGrams
        )
    }

    private static func makeRecovery(from r: RecoveryPlanOutput) -> RecoveryPlan {
        RecoveryPlan(
            sleepHoursTarget: r.sleepHoursTarget,
            restDaysPerWeek: r.restDaysPerWeek,
            activities: r.activities.map { a in
                RecoveryActivity(
                    id: UUID().uuidString,
                    name: a.name,
                    description: a.description,
                    durationMinutes: a.durationMinutes,
                    frequency: a.frequency
                )
            },
            notes: r.notes
        )
    }

    private static func makeRationale(from r: RationaleOutput) -> ProgramRationale {
        ProgramRationale(
            headline: r.headline,
            summaryCopy: r.summaryCopy,
            decisions: r.decisions.map { d in
                ProgramRationale.Decision(
                    inputSummary: d.inputSummary,
                    decisionApplied: d.decisionApplied,
                    iconSystemName: d.iconSystemName
                )
            }
        )
    }
}
