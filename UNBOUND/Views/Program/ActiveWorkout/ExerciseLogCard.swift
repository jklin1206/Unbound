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
    let isCurrent: Bool
    let currentSetIndex: Int?
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onToggleExpand) {
                    HStack(spacing: 8) {
                        if isCurrent {
                            Text("NOW")
                                .font(Font.unbound.captionS.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(Color.unbound.bg)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.unbound.coachCyan))
                        }
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

            HStack(spacing: 8) {
                targetPill("\(plannedSets) x \(plannedReps)", icon: "scope")
                if let targetRPE {
                    targetPill("RPE \(targetRPE)", icon: "gauge.medium")
                }
                targetPill(Self.mmss(restSeconds), icon: "timer")
            }
            .padding(.bottom, isExpanded ? 0 : 4)

            if isExpanded {
                Divider().overlay(Color.unbound.borderSubtle).padding(.vertical, 8)
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

            if showsSetGrid {
                HStack(spacing: 8) {
                    Text("SET").frame(width: 26, alignment: .leading)
                    Text(weightHeader).frame(maxWidth: .infinity)
                    Text(metricHeader).frame(maxWidth: .infinity)
                    Text("RPE").frame(width: 44)
                    Spacer().frame(width: 40)
                }
                .font(Font.unbound.captionS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.top, 2)

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
                        isCurrent: currentSetIndex == idx,
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
            } else {
                compactProgressRow
            }
        }
        .padding(18)
        .background(cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(isCurrent ? Color.unbound.coachCyan.opacity(0.62) : Color.unbound.border, lineWidth: 1))
        .shadow(color: isCurrent ? Color.unbound.coachCyan.opacity(0.18) : Color.clear, radius: 18, y: 4)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85),
                   value: isExpanded)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85),
                   value: isCurrent)
    }

    private var showsSetGrid: Bool {
        isCurrent || isExpanded
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.unbound.surface)
            .overlay {
                if isCurrent {
                    LinearGradient(
                        colors: [
                            Color.unbound.coachCyan.opacity(0.18),
                            Color.unbound.accent.opacity(0.10),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
    }

    private func targetPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(isCurrent ? Color.unbound.textPrimary : Color.unbound.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Capsule().fill(Color.unbound.surfaceElevated.opacity(isCurrent ? 1.0 : 0.72)))
            .overlay(Capsule().strokeBorder(isCurrent ? Color.unbound.coachCyan.opacity(0.24) : Color.unbound.borderSubtle, lineWidth: 1))
    }

    private var compactProgressRow: some View {
        let logged = sets.filter(\.logged).count
        let total = sets.count
        return HStack(spacing: 10) {
            Image(systemName: logged == total ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(logged == total ? Color.unbound.accent : Color.unbound.textTertiary)
            Text("\(logged)/\(total) sets logged")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
            Spacer()
            Text("TAP TO OPEN")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.top, 8)
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
