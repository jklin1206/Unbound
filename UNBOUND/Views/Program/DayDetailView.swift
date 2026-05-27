import SwiftUI

struct DayDetailView: View {
    let day: ProgramDay
    let nutritionPlan: NutritionPlan?
    let recoveryPlan: RecoveryPlan?
    var workoutLog: WorkoutLog? = nil
    /// Optional — when present, WorkoutDetailView shows an Edit toolbar so
    /// the user can swap exercises and adjust sets/reps.
    var programViewModel: ProgramViewModel? = nil
    var programId: String = ""

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Day header
                    dayHeader

                    if !day.isRestDay, let workout = day.workout {
                        WorkoutSectionCard(
                            workout: workout,
                            workoutLog: workoutLog,
                            programId: programId,
                            dayNumber: day.dayNumber,
                            programViewModel: programViewModel
                        )
                    }

                    if let nutrition = nutritionPlan {
                        NutritionSectionCard(
                            plan: nutrition,
                            override: day.nutritionOverride,
                            isRestDay: day.isRestDay
                        )
                    }

                    if let recovery = recoveryPlan {
                        RecoverySectionCard(
                            plan: recovery,
                            activities: day.recoveryActivities
                        )
                    }
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Day \(day.dayNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(day.isRestDay ? "Rest Day" : day.label)
                    .font(.subheadline(20))
                    .foregroundColor(.theme.textPrimary)

                if day.isRestDay {
                    Text("Recovery & Nutrition")
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textSecondary)
                } else if let workout = day.workout {
                    Text(workout.targetMuscleGroups.map(\.displayName).joined(separator: " · "))
                        .font(.bodyText(14))
                        .foregroundColor(.theme.textSecondary)
                }
            }
            Spacer()

            if day.isRestDay {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.theme.textMuted)
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.theme.primary)
            }
        }
        .padding(16)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Workout Section Card

private struct WorkoutSectionCard: View {
    let workout: Workout
    var workoutLog: WorkoutLog? = nil
    var programId: String = ""
    var dayNumber: Int = 0
    var programViewModel: ProgramViewModel? = nil
    @State private var navigate = false

    private var logStatusText: String {
        guard let log = workoutLog else { return "Not logged yet" }
        let daysSince = Calendar.current.dateComponents([.day], from: log.startedAt, to: Date()).day ?? 0
        if daysSince == 0 { return "Completed today" }
        return "Completed \(daysSince) day\(daysSince == 1 ? "" : "s") ago"
    }

    var body: some View {
        NavigationLink(destination: WorkoutDetailView(
            workout: workout,
            programId: programId,
            dayNumber: dayNumber,
            programViewModel: programViewModel
        )) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Workout", systemImage: "dumbbell.fill")
                        .font(.bodyMedium(16))
                        .foregroundColor(.theme.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption())
                        .foregroundColor(.theme.textMuted)
                }

                Text(workout.name)
                    .font(.subheadline(18))
                    .foregroundColor(.theme.textPrimary)

                Text(logStatusText)
                    .font(.caption(12))
                    .foregroundColor(workoutLog != nil ? .theme.textSecondary : .theme.textMuted)

                HStack(spacing: 20) {
                    statPill(
                        icon: "list.bullet",
                        value: "\(workout.mainExercises.count)",
                        label: "exercises"
                    )
                    statPill(
                        icon: "clock",
                        value: "\(workout.estimatedMinutes)",
                        label: "min"
                    )
                }
            }
            .padding(16)
            .background(Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption(12))
                .foregroundColor(.theme.textMuted)
            Text(value)
                .font(.bodyMedium(15))
                .foregroundColor(.theme.textPrimary)
            Text(label)
                .font(.caption(13))
                .foregroundColor(.theme.textSecondary)
        }
    }
}

// MARK: - Nutrition Section Card

private struct NutritionSectionCard: View {
    let plan: NutritionPlan
    let override: DayNutrition?
    let isRestDay: Bool

    private var calories: Int { override?.calories ?? (isRestDay ? plan.restDayCalories : plan.dailyCalories) }
    private var protein: Int { override?.proteinGrams ?? (isRestDay ? plan.restDayProteinGrams : plan.proteinGrams) }
    private var carbs: Int { override?.carbsGrams ?? (isRestDay ? plan.restDayCarbsGrams : plan.carbsGrams) }
    private var fat: Int { override?.fatGrams ?? (isRestDay ? plan.restDayFatGrams : plan.fatGrams) }

    var body: some View {
        NavigationLink(destination: NutritionDayView(plan: plan, override: override, initialIsRestDay: isRestDay)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Nutrition", systemImage: "fork.knife")
                        .font(.bodyMedium(16))
                        .foregroundColor(.theme.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption())
                        .foregroundColor(.theme.textMuted)
                }

                HStack(spacing: 0) {
                    macroPill(value: "\(calories)", label: "kcal", color: .theme.primary)
                    Spacer()
                    macroPill(value: "\(protein)g", label: "protein", color: .theme.secondary)
                    Spacer()
                    macroPill(value: "\(carbs)g", label: "carbs", color: Color.yellow)
                    Spacer()
                    macroPill(value: "\(fat)g", label: "fat", color: Color.orange)
                }
            }
            .padding(16)
            .background(Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func macroPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.bodyMedium(16))
                .foregroundColor(color)
            Text(label)
                .font(.caption(11))
                .foregroundColor(.theme.textSecondary)
        }
    }
}

// MARK: - Recovery Section Card

private struct RecoverySectionCard: View {
    let plan: RecoveryPlan
    let activities: [RecoveryActivity]

    var body: some View {
        NavigationLink(destination: RecoveryView(plan: plan)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Recovery", systemImage: "heart.fill")
                        .font(.bodyMedium(16))
                        .foregroundColor(Color.pink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption())
                        .foregroundColor(.theme.textMuted)
                }

                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)
                        Text("\(String(format: "%.1f", plan.sleepHoursTarget))h sleep")
                            .font(.bodyText(14))
                            .foregroundColor(.theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)
                        Text("\(activities.isEmpty ? plan.activities.count : activities.count) activities")
                            .font(.bodyText(14))
                            .foregroundColor(.theme.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
