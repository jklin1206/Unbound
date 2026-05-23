import SwiftUI

struct ExerciseLogCard: View {
    let name: String
    let plannedSets: Int
    let plannedReps: String
    let targetRPE: Int?
    let restSeconds: Int
    let muscleGroups: [MuscleGroup]
    let formCues: String?
    let substitution: String?
    var blockKind: TrainingBlockKind = .strength
    var metricKind: TrainingMetricKind = .reps
    var tracksHold: Bool = false
    let isWarmupCurrent: Bool
    let sets: [ActiveWorkoutSession.ActiveSet]
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onIntent: (OverflowIntent) -> Void
    let onEditWeight: (Int) -> Void
    let onEditReps: (Int) -> Void
    let onPickRPE: (Int) -> Void
    let onConfirmAsPlanned: (Int) -> Void
    let onAddSet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Button(action: onToggleExpand) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(Font.unbound.titleM)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                ExerciseOverflowMenu(isWarmup: isWarmupCurrent, onIntent: onIntent)
            }

            Text(targetCaption)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.bottom, isExpanded ? 0 : 6)

            if isExpanded {
                Divider().overlay(Color.unbound.borderSubtle).padding(.vertical, 10)
                ExerciseDetailSections(
                    muscleGroups: muscleGroups,
                    sets: plannedSets,
                    reps: plannedReps,
                    restSeconds: restSeconds,
                    formCues: formCues,
                    substitution: substitution
                )
                .padding(.bottom, 14)
            }

            HStack(spacing: 8) {
                Text("SET").frame(width: 20, alignment: .leading)
                Text(weightHeader).frame(maxWidth: .infinity)
                Text(metricHeader).frame(maxWidth: .infinity)
                Text("RPE").frame(width: 44)
                Spacer().frame(width: 40)
            }
            .font(Font.unbound.captionS)
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textTertiary)

            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                SetLogGridRow(
                    setNumber: idx + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    holdSeconds: set.holdSeconds,
                    durationSeconds: set.durationSeconds,
                    distanceMeters: set.distanceMeters,
                    calories: set.calories,
                    rpe: set.rpe,
                    suggestedWeightKg: set.suggestedWeightKg,
                    suggestedReps: set.suggestedReps,
                    suggestedHoldSeconds: set.suggestedHoldSeconds,
                    suggestedDurationSeconds: set.suggestedDurationSeconds,
                    suggestedDistanceMeters: set.suggestedDistanceMeters,
                    suggestedCalories: set.suggestedCalories,
                    suggestedRPE: set.suggestedRPE,
                    metricKind: metricKind,
                    tracksHold: tracksHold,
                    logged: set.logged,
                    onEditWeight: { onEditWeight(idx) },
                    onEditReps: { onEditReps(idx) },
                    onPickRPE: { onPickRPE(idx) },
                    onConfirmAsPlanned: { onConfirmAsPlanned(idx) }
                )
                if idx < sets.count - 1 {
                    Divider().overlay(Color.unbound.borderSubtle)
                }
            }

            Button(action: onAddSet) {
                Label("Add set", systemImage: "plus")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .padding(.top, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.unbound.surface))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.unbound.border, lineWidth: 1))
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85),
                   value: isExpanded)
    }

    private var targetCaption: String {
        let prefix: String
        switch blockKind {
        case .skill: prefix = "Skill"
        case .cardio: prefix = "Cardio"
        case .carry: prefix = "Carry"
        case .routine: prefix = "Routine"
        case .strength, .bodyweight, .custom: prefix = "Target"
        }
        var parts = ["\(prefix) · \(plannedSets) × \(plannedReps)"]
        if let r = targetRPE { parts.append("RPE \(r)") }
        parts.append("rest \(Self.mmss(restSeconds))")
        return parts.joined(separator: " · ")
    }

    private var metricHeader: String {
        switch metricKind {
        case .reps: return "REPS"
        case .holdSeconds: return "HOLD"
        case .durationSeconds: return "TIME"
        case .distanceMeters: return "DIST"
        case .calories: return "CAL"
        }
    }

    private var weightHeader: String {
        let unit = TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
        return (blockKind == .carry || tracksHold ? "LOAD" : "WEIGHT") + " " + unit.shortLabel.uppercased()
    }

    private static func mmss(_ s: Int) -> String {
        "\(s / 60):" + String(format: "%02d", s % 60)
    }
}
