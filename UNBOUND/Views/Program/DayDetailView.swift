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
    var adjustments: [WaveAdjustment] = []
    var onUndoAdjustment: (WaveAdjustment) -> Void = { _ in }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dayHeader

                    ProgramWaveAdjustmentPanel(adjustments: adjustments, onUndo: onUndoAdjustment)

                    if !day.isRestDay, let workout = day.workout {
                        WorkoutSectionRow(
                            workout: workout,
                            workoutLog: workoutLog,
                            programId: programId,
                            dayNumber: day.dayNumber,
                            programViewModel: programViewModel
                        )
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        if let nutrition = nutritionPlan {
                            NutritionSectionRow(
                                plan: nutrition,
                                override: day.nutritionOverride,
                                isRestDay: day.isRestDay
                            )
                            Divider()
                                .overlay(Color.unbound.border.opacity(0.6))
                        }

                        if let recovery = recoveryPlan {
                            RecoverySectionRow(
                                plan: recovery,
                                activities: day.recoveryActivities
                            )
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Day \(day.dayNumber)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.isRestDay ? "REST DAY" : "TRAINING DAY")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(day.isRestDay ? Color.unbound.textTertiary : Color.unbound.accent)

            Text(day.isRestDay ? "Recovery & Nutrition" : day.label)
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)

            if !day.isRestDay, let workout = day.workout {
                MetaLine(workout.targetMuscleGroups.map(\.displayName))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Workout Section

private struct WorkoutSectionRow: View {
    let workout: Workout
    var workoutLog: WorkoutLog? = nil
    var programId: String = ""
    var dayNumber: Int = 0
    var programViewModel: ProgramViewModel? = nil

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
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WORKOUT")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(workout.name)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    MetaLine([
                        "\(workout.mainExercises.count) exercises",
                        "\(workout.estimatedMinutes) min",
                        workoutLog != nil ? logStatusText : nil
                    ], emphasized: true)
                }

                Spacer(minLength: 8)

                Image(systemName: workoutLog != nil ? "checkmark" : "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(workoutLog != nil ? Color.unbound.success : Color.unbound.textTertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nutrition Section

private struct NutritionSectionRow: View {
    let plan: NutritionPlan
    let override: DayNutrition?
    let isRestDay: Bool

    private var calories: Int { override?.calories ?? (isRestDay ? plan.restDayCalories : plan.dailyCalories) }
    private var protein: Int { override?.proteinGrams ?? (isRestDay ? plan.restDayProteinGrams : plan.proteinGrams) }
    private var carbs: Int { override?.carbsGrams ?? (isRestDay ? plan.restDayCarbsGrams : plan.carbsGrams) }
    private var fat: Int { override?.fatGrams ?? (isRestDay ? plan.restDayFatGrams : plan.fatGrams) }

    var body: some View {
        NavigationLink(destination: NutritionDayView(plan: plan, override: override, initialIsRestDay: isRestDay)) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("NUTRITION")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    HStack(spacing: 16) {
                        macroStat(value: "\(calories)", label: "KCAL")
                        macroStat(value: "\(protein)g", label: "PRO")
                        macroStat(value: "\(carbs)g", label: "CARB")
                        macroStat(value: "\(fat)g", label: "FAT")
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func macroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(Font.unbound.captionS.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }
}

// MARK: - Recovery Section

private struct RecoverySectionRow: View {
    let plan: RecoveryPlan
    let activities: [RecoveryActivity]

    var body: some View {
        NavigationLink(destination: RecoveryView(plan: plan)) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECOVERY")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    MetaLine([
                        "\(String(format: "%.1f", plan.sleepHoursTarget))h sleep",
                        "\(activities.isEmpty ? plan.activities.count : activities.count) activities"
                    ], emphasized: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
