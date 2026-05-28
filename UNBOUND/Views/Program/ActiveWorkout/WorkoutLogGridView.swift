import SwiftUI

struct WorkoutLogGridView: View {
    @ObservedObject var session: ActiveWorkoutSession
    let rankTrialDefinition: OverallRankTrialDefinition?
    let onIntent: (Int, OverflowIntent) -> Void
    let onEditWeight: (Int, Int) -> Void
    let onEditReps: (Int, Int) -> Void
    let onPickRPE: (Int, Int) -> Void
    let onConfirmAsPlanned: (Int, Int) -> Void
    let onToggleQualityFlag: (Int, Int, PerformanceQualityFlag) -> Void
    let onAddSet: (Int) -> Void

    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let rankTrialDefinition {
                    RankTrialActiveFlowHeader(definition: rankTrialDefinition, session: session)
                }

                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { ei, ex in
                    if !ex.skipped {
                        let isCurrent = ei == session.currentExerciseIndex
                        ExerciseLogCard(
                            name: ex.name,
                            plannedSets: ex.plannedSets,
                            plannedReps: ex.plannedReps,
                            targetRPE: ex.targetRPE,
                            restSeconds: ex.restSeconds,
                            muscleGroups: ex.muscleGroups,
                            formCues: ex.formCues,
                            substitution: ex.substitution,
                            blockKind: ex.blockKind,
                            metricKind: ex.metricKind,
                            tracksHold: ex.tracksHold,
                            isWarmupCurrent: ex.sets.first?.isWarmup ?? false,
                            sets: ex.sets,
                            isExpanded: expanded.contains(ex.id),
                            isCurrent: isCurrent,
                            currentSetIndex: isCurrent ? session.currentSetIndex : nil,
                            onToggleExpand: {
                                if expanded.contains(ex.id) { expanded.remove(ex.id) }
                                else { expanded.insert(ex.id) }
                            },
                            onIntent: { onIntent(ei, $0) },
                            onEditWeight: { onEditWeight(ei, $0) },
                            onEditReps: { onEditReps(ei, $0) },
                            onPickRPE: { onPickRPE(ei, $0) },
                            onConfirmAsPlanned: { onConfirmAsPlanned(ei, $0) },
                            onToggleQualityFlag: { si, flag in onToggleQualityFlag(ei, si, flag) },
                            onAddSet: { onAddSet(ei) },
                            allowsProtocolEditing: rankTrialDefinition == nil
                        )
                    }
                }

                Spacer().frame(height: 190)
            }
            .padding(16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}

private struct RankTrialActiveFlowHeader: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definition.format.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text(definition.displayName)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated).frame(height: 6)
                    Capsule()
                        .fill(Color.unbound.coachCyan)
                        .frame(width: proxy.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                        stationChip(index: index, exercise: exercise)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.coachCyan.opacity(0.28), lineWidth: 1)
        )
    }

    private var totalStations: Int {
        max(1, session.exercises.count)
    }

    private var loggedStations: Int {
        session.exercises.filter { exercise in
            exercise.sets.contains { $0.logged && !$0.isWarmup }
        }.count
    }

    private var progress: CGFloat {
        CGFloat(loggedStations) / CGFloat(totalStations)
    }

    private func stationChip(index: Int, exercise: ActiveWorkoutSession.ActiveExercise) -> some View {
        let isLogged = exercise.sets.contains { $0.logged && !$0.isWarmup }
        let isCurrent = index == session.currentExerciseIndex
        return HStack(spacing: 6) {
            Image(systemName: isLogged ? "checkmark.circle.fill" : (isCurrent ? "circle.dashed" : "circle"))
                .font(.system(size: 12, weight: .bold))
            Text(chipTitle(for: exercise, index: index))
                .font(Font.unbound.captionS.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(isLogged ? Color.unbound.accent : (isCurrent ? Color.unbound.coachCyan : Color.unbound.textSecondary))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(Color.unbound.surfaceElevated))
        .overlay(Capsule().strokeBorder(isCurrent ? Color.unbound.coachCyan.opacity(0.42) : Color.unbound.borderSubtle, lineWidth: 1))
    }

    private func chipTitle(for exercise: ActiveWorkoutSession.ActiveExercise, index: Int) -> String {
        if let blockTitle = exercise.blockTitle, !blockTitle.isEmpty {
            return blockTitle
        }
        return "\(unitLabel) \(index + 1)"
    }

    private var unitLabel: String {
        switch definition.format {
        case .daily100: return "Set"
        case .operatorScreen: return "Card"
        case .finisher: return "Round"
        case .fixedDeck: return "Card"
        case .tower: return "Floor"
        case .bossRush: return "Boss"
        case .raid: return "Stage"
        case .finalExam: return "Part"
        }
    }
}
