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
    @State private var revealedDeckExerciseId: String?
    @State private var isDrawingDeckCard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let rankTrialDefinition, shouldShowSharedRankTrialHeader(for: rankTrialDefinition) {
                    RankTrialActiveFlowHeader(definition: rankTrialDefinition, session: session)
                }

                if isDeckTrial {
                    deckDrawFlow
                } else if isTowerTrial {
                    towerAscentFlow
                } else if let rankTrialDefinition {
                    rankTrialModeFlow(for: rankTrialDefinition)
                } else {
                    standardExerciseList
                }

                Spacer().frame(height: 190)
            }
            .padding(16)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear(perform: syncDeckReveal)
        .onChange(of: session.currentExerciseIndex) { _, _ in
            syncDeckReveal()
        }
    }

    private var isDeckTrial: Bool {
        rankTrialDefinition?.format == .fixedDeck
    }

    private var isTowerTrial: Bool {
        rankTrialDefinition?.format == .tower
    }

    private func shouldShowSharedRankTrialHeader(for definition: OverallRankTrialDefinition) -> Bool {
        definition.format == .fixedDeck
    }

    private var currentExercisePair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)? {
        guard session.exercises.indices.contains(session.currentExerciseIndex) else { return nil }
        let exercise = session.exercises[session.currentExerciseIndex]
        guard !exercise.skipped else { return nil }
        return (session.currentExerciseIndex, exercise)
    }

    @ViewBuilder
    private var standardExerciseList: some View {
        let visible = Array(session.exercises.enumerated()).filter { !$0.element.skipped }
        let current = session.currentExerciseIndex
        VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.element.id) { pos, pair in
                let ei = pair.offset
                let isActive = ei == current
                exerciseCard(ei: ei, ex: pair.element, isCurrent: isActive)

                if pos < visible.count - 1 {
                    let nextIsActive = visible[pos + 1].offset == current
                    if isActive || nextIsActive {
                        // The active panel floats on whitespace — no divider
                        // jammed against its raised surface.
                        Color.clear.frame(height: 8)
                    } else {
                        Divider()
                            .overlay(Color.unbound.border)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deckDrawFlow: some View {
        if let pair = currentExercisePair {
            DeckOfProofDrawStage(
                exercise: pair.exercise,
                drawIndex: pair.index,
                totalDraws: session.exercises.count,
                isRevealed: isDeckExerciseRevealed(pair.exercise),
                isDrawing: isDrawingDeckCard,
                onDraw: revealDeckExercise,
                onComplete: completeDeckExercise
            )
            .id(pair.exercise.id)
            .zIndex(Double(pair.index + 1))
        }
    }

    @ViewBuilder
    private var towerAscentFlow: some View {
        if let definition = rankTrialDefinition {
            TowerTrialAscentView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        }
    }

    @ViewBuilder
    private func rankTrialModeFlow(for definition: OverallRankTrialDefinition) -> some View {
        switch definition.format {
        case .daily100:
            Daily100TrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .operatorScreen:
            OperatorScreenTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .finisher:
            FinisherTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .fixedDeck:
            deckDrawFlow
        case .tower:
            towerAscentFlow
        case .bossRush:
            BossRushTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .raid:
            ThresholdRaidTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .finalExam:
            FinalExamTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        }
    }

    private func exerciseCard(ei: Int, ex: ActiveWorkoutSession.ActiveExercise, isCurrent: Bool) -> some View {
        ExerciseLogCard(
            name: ex.name,
            plannedSets: ex.plannedSets,
            plannedReps: ex.plannedReps,
            targetRPE: ex.targetRPE,
            restSeconds: ex.restSeconds,
            muscleGroups: ex.muscleGroups,
            formCues: ex.formCues,
            substitution: ex.substitution,
            movementId: ex.movementId,
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
            rankTrialStyle: rankTrialDefinition != nil,
            allowsProtocolEditing: rankTrialDefinition == nil
        )
    }

    private func revealDeckExercise() {
        guard let pair = currentExercisePair,
              !isDeckExerciseRevealed(pair.exercise),
              !isDrawingDeckCard
        else { return }

        isDrawingDeckCard = true
        UnboundHaptics.soft()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard currentExercisePair?.exercise.id == pair.exercise.id else { return }
            withAnimation(.easeInOut(duration: 0.36)) {
                revealedDeckExerciseId = pair.exercise.id
                isDrawingDeckCard = false
            }
            UnboundHaptics.success()
        }
    }

    private func completeDeckExercise() {
        guard let pair = currentExercisePair,
              isDeckExerciseRevealed(pair.exercise)
        else { return }

        let setIndex = pair.exercise.sets.firstIndex { !$0.isWarmup && !$0.logged }
            ?? pair.exercise.sets.firstIndex { !$0.logged }
        guard let setIndex else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            revealedDeckExerciseId = nil
        }
        onConfirmAsPlanned(pair.index, setIndex)
    }

    private func syncDeckReveal() {
        guard isDeckTrial, let pair = currentExercisePair else { return }
        isDrawingDeckCard = false
        if pair.exercise.sets.contains(where: \.logged) {
            revealedDeckExerciseId = pair.exercise.id
            expanded.insert(pair.exercise.id)
        } else {
            revealedDeckExerciseId = nil
        }
    }

    private func isDeckExerciseRevealed(_ exercise: ActiveWorkoutSession.ActiveExercise) -> Bool {
        revealedDeckExerciseId == exercise.id || exercise.sets.contains(where: \.logged)
    }
}
