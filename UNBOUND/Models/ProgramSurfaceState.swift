import Foundation

struct ProgramSurfaceState: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case noProgram
        case loading
        case loadError
        case blockComplete
        case restDay
        case trainingDay
        case missingDay
    }

    let kind: Kind
    let title: String
    let primaryActionTitle: String
    let secondaryActionTitle: String?

    var canStartWorkout: Bool {
        kind == .trainingDay
    }

    static func resolve(
        state: LoadingState<TrainingProgram>,
        selectedDate: Date = Date(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgramSurfaceState {
        switch state {
        case .idle:
            return ProgramSurfaceState(
                kind: .noProgram,
                title: "No program yet",
                primaryActionTitle: "Build Program",
                secondaryActionTitle: "Browse Routines"
            )
        case .loading:
            return ProgramSurfaceState(
                kind: .loading,
                title: "Loading program",
                primaryActionTitle: "Loading",
                secondaryActionTitle: nil
            )
        case .error:
            return ProgramSurfaceState(
                kind: .loadError,
                title: "Program unavailable",
                primaryActionTitle: "Retry",
                secondaryActionTitle: "Browse Routines"
            )
        case .loaded(let program):
            if BlockRolloverScheduler.shouldRollover(program: program, now: now) {
                return ProgramSurfaceState(
                    kind: .blockComplete,
                    title: "Block complete",
                    primaryActionTitle: "Build Next Block",
                    secondaryActionTitle: "Rescan"
                )
            }

            guard let day = programDay(for: selectedDate, in: program, calendar: calendar) else {
                return ProgramSurfaceState(
                    kind: .missingDay,
                    title: "No session planned",
                    primaryActionTitle: "Edit Program",
                    secondaryActionTitle: "Browse Routines"
                )
            }

            if day.isRestDay || day.workout == nil {
                return ProgramSurfaceState(
                    kind: .restDay,
                    title: "Recovery command",
                    primaryActionTitle: "View Recovery",
                    secondaryActionTitle: "Add Light Work"
                )
            }

            return ProgramSurfaceState(
                kind: .trainingDay,
                title: "Today command",
                primaryActionTitle: calendar.isDate(selectedDate, inSameDayAs: now) ? "Begin Session" : "View Details",
                secondaryActionTitle: "Edit"
            )
        }
    }

    private static func programDay(
        for date: Date,
        in program: TrainingProgram,
        calendar: Calendar
    ) -> ProgramDay? {
        guard !program.days.isEmpty else { return nil }
        let daysSinceStart = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: program.createdAt),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        let index = ((daysSinceStart % program.days.count) + program.days.count) % program.days.count
        return program.days[index]
    }
}

#if DEBUG
enum ProgramProofState: String, CaseIterable, Sendable {
    case trainingDay = "training-day"
    case restDay = "rest-day"
    case missingDay = "missing-day"
    case blockComplete = "block-complete"

    static func parse(_ rawValue: String) -> ProgramProofState? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return ProgramProofState(rawValue: normalized)
    }
}

enum ProgramSurfaceProofOverride: String, CaseIterable, Sendable {
    case noProgram = "no-program"
    case loading
    case loadError = "load-error"

    static let launchArgumentKey = "--unbound-proof-program-surface"

    static func parse(_ rawValue: String) -> ProgramSurfaceProofOverride? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return ProgramSurfaceProofOverride(rawValue: normalized)
    }

    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> ProgramSurfaceProofOverride? {
        for (index, argument) in arguments.enumerated() {
            if argument == launchArgumentKey,
               arguments.indices.contains(index + 1) {
                return parse(arguments[index + 1])
            }
            if argument.hasPrefix("\(launchArgumentKey)=") {
                return parse(String(argument.dropFirst(launchArgumentKey.count + 1)))
            }
        }
        return nil
    }

    var loadingState: LoadingState<TrainingProgram> {
        switch self {
        case .noProgram:
            return .idle
        case .loading:
            return .loading
        case .loadError:
            return .error(.networkNoConnection)
        }
    }
}

enum ProgramProofProgramFactory {
    static func make(
        state: ProgramProofState,
        userId: String,
        now: Date = Date()
    ) -> TrainingProgram {
        let createdAt: Date = {
            switch state {
            case .trainingDay, .restDay, .missingDay:
                return now
            case .blockComplete:
                return now.addingTimeInterval(-29 * 86_400)
            }
        }()

        let days: [ProgramDay] = state == .missingDay ? [] : (1...14).map { dayNumber in
            let isFirstDayRest = state == .restDay && dayNumber == 1
            let isScheduledRest = dayNumber == 4 || dayNumber == 7 || dayNumber == 11 || dayNumber == 14
            let isRest = isFirstDayRest || (!isFirstDayRest && isScheduledRest)
            return ProgramDay(
                id: "proof-day-\(dayNumber)",
                dayNumber: dayNumber,
                label: isRest ? "Recovery" : "Day \(dayNumber)",
                isRestDay: isRest,
                workout: isRest ? nil : proofWorkout(dayNumber: dayNumber),
                nutritionOverride: nil,
                recoveryActivities: isRest ? [
                    RecoveryActivity(
                        id: "proof-recovery-\(dayNumber)",
                        name: "Walk + Mobility",
                        description: "Low-intensity recovery with hips and shoulders open.",
                        durationMinutes: 30,
                        frequency: "Today"
                    )
                ] : []
            )
        }

        return TrainingProgram(
            id: "proof-program-\(state.rawValue)",
            scanId: "proof-scan",
            analysisId: "proof-analysis",
            userId: userId,
            createdAt: createdAt,
            name: "Program Proof \(state.rawValue)",
            description: "DEBUG fixture for Program simulator proof states.",
            durationDays: 14,
            days: days,
            nutritionPlan: NutritionPlan(
                dailyCalories: 2850,
                proteinGrams: 180,
                carbsGrams: 330,
                fatGrams: 80,
                mealCount: 4,
                meals: [],
                hydrationLiters: 3.2,
                supplements: ["Creatine", "Electrolytes"],
                notes: "Proof nutrition target.",
                restDayCalories: 2550,
                restDayProteinGrams: 180,
                restDayCarbsGrams: 260,
                restDayFatGrams: 85
            ),
            recoveryPlan: RecoveryPlan(
                sleepHoursTarget: 8,
                restDaysPerWeek: 2,
                activities: [],
                notes: "Proof recovery target."
            ),
            difficultyLevel: .advanced,
            requiredEquipment: ["Barbell", "Dumbbells", "Pullup Bar"],
            estimatedDailyMinutes: state == .restDay ? 30 : 55,
            rationale: nil
        )
    }

    private static func proofWorkout(dayNumber: Int) -> Workout {
        let workouts: [Workout] = [
            Workout(
                name: "Power Upper",
                targetMuscleGroups: [.chest, .shoulders, .arms],
                warmup: [],
                mainExercises: [
                    Exercise(id: "proof-bench", name: "Bench Press", muscleGroups: [.chest, .shoulders, .arms], sets: 4, reps: "4-6", restSeconds: 180, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "proof-ohp", name: "Overhead Press", muscleGroups: [.shoulders, .arms], sets: 3, reps: "5", restSeconds: 150, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "proof-pullup", name: "Pullup", muscleGroups: [.back, .arms], sets: 4, reps: "6-10", restSeconds: 120, rpe: 8, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 55,
                notes: "Proof seeded session.",
                blockType: .intensification
            ),
            Workout(
                name: "Lower Output",
                targetMuscleGroups: [.legs, .glutes, .core],
                warmup: [],
                mainExercises: [
                    Exercise(id: "proof-squat", name: "Back Squat", muscleGroups: [.legs, .glutes, .core], sets: 4, reps: "3-5", restSeconds: 180, rpe: 8, notes: nil, substitution: nil),
                    Exercise(id: "proof-rdl", name: "Romanian Deadlift", muscleGroups: [.legs, .glutes, .back], sets: 3, reps: "6-8", restSeconds: 150, rpe: 8, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 60,
                notes: "Proof seeded session.",
                blockType: .intensification
            ),
            Workout(
                name: "Skill Control",
                targetMuscleGroups: [.core, .shoulders],
                warmup: [],
                mainExercises: [
                    Exercise(id: "proof-handstand", name: "Wall Handstand", muscleGroups: [.shoulders, .core], sets: 5, reps: "30s", restSeconds: 90, rpe: 7, notes: nil, substitution: nil),
                    Exercise(id: "proof-lsit", name: "L-Sit", muscleGroups: [.core], sets: 5, reps: "15s", restSeconds: 90, rpe: 7, notes: nil, substitution: nil)
                ],
                cooldown: [],
                estimatedMinutes: 45,
                notes: "Proof seeded session.",
                blockType: .accumulation
            )
        ]
        return workouts[(dayNumber - 1) % workouts.count]
    }
}
#endif
