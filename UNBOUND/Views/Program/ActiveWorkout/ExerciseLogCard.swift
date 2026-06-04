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
    var movementId: String? = nil
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
    let onToggleQualityFlag: (Int, PerformanceQualityFlag) -> Void
    let onAddSet: () -> Void
    var rankTrialStyle: Bool = false
    var allowsProtocolEditing: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightPlatePolicy.unitDefaultsKey) private var weightUnitRaw = TrainingWeightUnit.localeDefault.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                exerciseThumbnail

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
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .layoutPriority(1)

                if allowsProtocolEditing {
                    ExerciseOverflowMenu(isWarmup: isWarmupCurrent, onIntent: onIntent)
                }
            }

            HStack(spacing: 8) {
                targetPill("\(plannedSets) x \(plannedReps)", icon: "scope")
                if let targetRPE {
                    targetPill("RPE \(targetRPE)", icon: "gauge.medium")
                }
                targetPill(Self.mmss(restSeconds), icon: "timer")
            }
            .padding(.bottom, isExpanded ? 0 : 4)

            if isUnmatched {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Won't count toward rank or XP")
                        .font(Font.unbound.captionS.weight(.semibold))
                }
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.bottom, isExpanded ? 0 : 2)
            }

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
                        qualityFlags: set.qualityFlags,
                        isCurrent: currentSetIndex == idx,
                        onEditWeight: { onEditWeight(idx) },
                        onEditReps: { onEditReps(idx) },
                        onPickRPE: { onPickRPE(idx) },
                        onConfirmAsPlanned: { onConfirmAsPlanned(idx) },
                        onToggleQualityFlag: { onToggleQualityFlag(idx, $0) }
                    )
                    if idx < sets.count - 1 {
                        Divider().overlay(Color.unbound.borderSubtle)
                    }
                }

                if allowsProtocolEditing {
                    Button(action: onAddSet) {
                        Label("Add set", systemImage: "plus")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                compactProgressRow
            }
        }
        .padding(rankTrialStyle ? 15 : 18)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(
            color: isCurrent
                ? Color.black.opacity(rankTrialStyle ? 0.10 : 0.14)
                : Color.clear,
            radius: rankTrialStyle ? 8 : 12,
            y: rankTrialStyle ? 2 : 3
        )
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85),
                   value: isExpanded)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.85),
                   value: isCurrent)
    }

    private var showsSetGrid: Bool {
        isCurrent || isExpanded
    }

    private var movementDefinition: MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: name,
            movementId: movementId
        )?.exact
    }

    private var isUnmatched: Bool {
        if movementDefinition != nil { return false }
        return MovementResolver.resolve(name).isUnmatched
    }

    @ViewBuilder
    private var exerciseThumbnail: some View {
        if let definition = movementDefinition {
            ExerciseVisualView(definition: definition, size: .thumbnail)
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: fallbackExerciseIcon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            .frame(width: 58, height: 58)
            .accessibilityHidden(true)
        }
    }

    private var fallbackExerciseIcon: String {
        switch blockKind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if rankTrialStyle {
            RankTrialActionDockShape()
                .fill(isCurrent ? Color.unbound.surface.opacity(0.94) : Color.unbound.surface.opacity(0.82))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(isCurrent ? Color.unbound.coachCyan : Color.unbound.borderSubtle)
                        .frame(width: 3)
                        .opacity(isCurrent ? 0.95 : 0.34)
                        .padding(.vertical, 12)
                }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(alignment: .leading) {
                    if isCurrent {
                        Rectangle()
                            .fill(Color.unbound.coachCyan)
                            .frame(width: 3)
                            .opacity(0.9)
                            .padding(.vertical, 14)
                    }
                }
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.unbound.coachCyan.opacity(0.035))
                    }
                }
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if rankTrialStyle {
            RankTrialActionDockShape()
                .strokeBorder(
                    isCurrent ? Color.unbound.coachCyan.opacity(0.54) : Color.unbound.borderSubtle,
                    lineWidth: 1
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isCurrent ? Color.unbound.coachCyan.opacity(0.38) : Color.unbound.border, lineWidth: 1)
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
            .overlay(Capsule().strokeBorder(isCurrent ? Color.unbound.coachCyan.opacity(0.16) : Color.unbound.borderSubtle, lineWidth: 1))
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

private struct RankTrialActionDockShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(rect.width * 0.08, 24)
        let radius: CGFloat = 12
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
