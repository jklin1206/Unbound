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
        rankTrialDefinition?.format == .deckOfProof
    }

    private func shouldShowSharedRankTrialHeader(for definition: OverallRankTrialDefinition) -> Bool {
        definition.format == .deckOfProof
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
    private func rankTrialModeFlow(for definition: OverallRankTrialDefinition) -> some View {
        switch definition.format {
        case .firstLight:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .theCount:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .theForging:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .deckOfProof:
            deckDrawFlow
        case .theAscent:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .sevenSeals:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .theThreshold:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
                exerciseCard(ei: index, ex: exercise, isCurrent: index == session.currentExerciseIndex)
            }
        case .theLastGate:
            GateTrialActiveView(definition: definition, session: session) { index, exercise in
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

private struct RankTrialActiveFlowHeader: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession

    @ViewBuilder
    var body: some View {
        if definition.format == .deckOfProof {
            floatingDeckHeader
        } else {
            standardHeader
        }
    }

    private var floatingDeckHeader: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.format.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .foregroundStyle(Color.unbound.coachCyan)
                    Text(definition.displayName)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                Spacer()

                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.09)).frame(height: 3)
                    Capsule()
                        .fill(Color.unbound.coachCyan)
                        .frame(width: proxy.size.width * progress, height: 3)
                }
            }
            .frame(height: 3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                        stationChip(index: index, exercise: exercise)
                    }
                }
            }
        }
        .padding(.top, 28)
    }

    private var standardHeader: some View {
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
        return Group {
            if definition.format == .deckOfProof {
                HStack(spacing: 6) {
                    Image(systemName: isLogged ? "checkmark.circle.fill" : (isCurrent ? "circle.dashed" : "circle"))
                        .font(.system(size: 12, weight: .bold))
                    Text(chipTitle(for: exercise, index: index))
                        .font(Font.unbound.captionS.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(isLogged ? Color.unbound.accent : (isCurrent ? Color.unbound.coachCyan : Color.unbound.textTertiary))
                .frame(height: 24)
            } else {
                HStack(spacing: 6) {
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
        }
    }

    private func chipTitle(for exercise: ActiveWorkoutSession.ActiveExercise, index: Int) -> String {
        if definition.format == .deckOfProof {
            return "Draw \(numberString(index + 1))"
        }
        if let blockTitle = exercise.blockTitle, !blockTitle.isEmpty {
            return blockTitle
        }
        return "\(unitLabel) \(index + 1)"
    }

    private func numberString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private var unitLabel: String {
        switch definition.format {
        case .firstLight: return "Set"
        case .theCount: return "Count"
        case .theForging: return "Round"
        case .deckOfProof: return "Card"
        case .theAscent: return "Floor"
        case .sevenSeals: return "Boss"
        case .theThreshold: return "Stage"
        case .theLastGate: return "Part"
        }
    }
}
