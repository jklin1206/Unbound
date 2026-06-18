#if DEBUG
import SwiftUI

@MainActor
struct RankTrialDemoRecorderView: View {
    @State private var sceneIndex: Int
    @State private var context: RankTrialDemoContext
    @State private var phase: RankTrialDemoPhase = .ready
    @State private var didStartTimeline = false
    @State private var deckIsRevealed = false
    @State private var deckIsDrawing = false
    @State private var reelComplete = false

    private let scenarios: [RankTrialDemoScenario]
    private let stationAutoLogLimit: Int
    private let postScenarioHoldNanoseconds: UInt64

    init() {
        let allScenarios = RankTrialDemoScenario.all
        stationAutoLogLimit = Self.stationAutoLogLimit()
        postScenarioHoldNanoseconds = Self.postScenarioHoldNanoseconds()
        if let requestedIndex = Self.requestedScenarioIndex(in: allScenarios) {
            let scenario = allScenarios[requestedIndex]
            scenarios = [scenario]
            _sceneIndex = State(initialValue: 0)
            _context = State(initialValue: scenario.makeContext())
        } else {
            scenarios = allScenarios
            _sceneIndex = State(initialValue: 0)
            _context = State(initialValue: allScenarios[0].makeContext())
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    demoHeader

                    if reelComplete {
                        completionPanel
                            .padding(.horizontal, 18)
                    } else {
                        phaseContent
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 42)
            }
        }
        .task {
            guard !didStartTimeline else { return }
            didStartTimeline = true
            await playTimeline()
        }
        .accessibilityIdentifier("rankTrialDemo.reel")
    }

    private var demoHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("RANK TRIAL DEMO")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(tint)
                Spacer(minLength: 8)
                Text("\(sceneIndex + 1)/\(scenarios.count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            Text(context.definition.displayName)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            HStack(spacing: 8) {
                demoChip(phase == .ready ? "READY" : "LIVE", icon: phase == .ready ? "rectangle.stack.fill" : "play.fill")
                demoChip(context.definition.format.displayName.uppercased(), icon: "sparkle.magnifyingglass")
                demoChip("\(context.draft.estimatedMinutes) MIN", icon: "clock.fill")
            }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .ready:
            readyPreview
                .padding(.horizontal, 18)
        case .active:
            activePreview
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var readyPreview: some View {
        switch context.definition.format {
        case .firstLight:
            FirstLightTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .theCount:
            TheCountTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .theForging:
            FinisherTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .deckOfProof:
            RankTrialDemoDeckReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .theAscent:
            TowerTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .sevenSeals:
            BossRushTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .theThreshold:
            ThresholdRaidTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        case .theLastGate:
            FinalExamTrialReadyPreview(blocks: context.draft.blocks, tint: tint)
        }
    }

    @ViewBuilder
    private var activePreview: some View {
        switch context.definition.format {
        case .firstLight:
            FirstLightTrialActiveView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        case .theCount:
            TheCountTrialActiveView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        case .theForging:
            FinisherTrialActiveView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        case .deckOfProof:
            if let pair = currentExercisePair {
                DeckOfProofDrawStage(
                    exercise: pair.exercise,
                    drawIndex: pair.index,
                    totalDraws: context.session.exercises.count,
                    isRevealed: deckIsRevealed,
                    isDrawing: deckIsDrawing,
                    onDraw: drawDeckCard,
                    onComplete: completeDeckCard
                )
                .id(pair.exercise.id)
                .zIndex(Double(pair.index + 1))
            }
        case .theAscent:
            TowerTrialAscentView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        case .sevenSeals:
            BossRushTrialActiveView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        case .theThreshold:
            ThresholdRaidTrialActiveView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        case .theLastGate:
            FinalExamTrialActiveView(definition: context.definition, session: context.session) { index, exercise in
                RankTrialDemoStationCard(index: index, exercise: exercise, isCurrent: index == context.session.currentExerciseIndex, tint: tint)
            }
        }
    }

    private var completionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Color.unbound.accent)
            Text("All rank trials recorded")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("First Light, The Count, Finisher, Deck of Proof, Tower, Boss Rush, Threshold Raid, and Final Exam.")
                .font(Font.unbound.bodyS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 30)
    }

    private var currentExercisePair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)? {
        guard context.session.exercises.indices.contains(context.session.currentExerciseIndex) else { return nil }
        let exercise = context.session.exercises[context.session.currentExerciseIndex]
        guard !exercise.skipped else { return nil }
        return (context.session.currentExerciseIndex, exercise)
    }

    private var tint: Color {
        context.definition.targetRank.rewardTextTint
    }

    private func demoChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.bold))
            .foregroundStyle(Color.unbound.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(Color.unbound.surfaceElevated.opacity(0.74)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.26), lineWidth: 1))
    }

    private func playTimeline() async {
        for index in scenarios.indices {
            loadScenario(at: index)
            try? await Task.sleep(nanoseconds: 2_250_000_000)

            var phaseTransaction = Transaction()
            phaseTransaction.disablesAnimations = true
            withTransaction(phaseTransaction) {
                phase = .active
            }

            try? await Task.sleep(nanoseconds: 850_000_000)

            if context.definition.format == .deckOfProof {
                await playDeckTimeline()
            } else {
                await playStationTimeline()
            }

            try? await Task.sleep(nanoseconds: postScenarioHoldNanoseconds)
        }

        var completionTransaction = Transaction()
        completionTransaction.disablesAnimations = true
        withTransaction(completionTransaction) {
            reelComplete = true
        }
    }

    private func loadScenario(at index: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sceneIndex = index
            context = scenarios[index].makeContext()
            phase = .ready
            deckIsRevealed = false
            deckIsDrawing = false
            reelComplete = false
        }
    }

    private func playStationTimeline() async {
        for _ in 0..<stationAutoLogLimit {
            guard let set = nextUnloggedSet() else { break }
            withAnimation(.easeInOut(duration: 0.2)) {
                context.session.confirmAsPlanned(exerciseIndex: set.exerciseIndex, setIndex: set.setIndex)
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
        }
    }

    private func playDeckTimeline() async {
        for _ in 0..<3 {
            guard currentExercisePair != nil else { break }
            drawDeckCard()
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            completeDeckCard()
            try? await Task.sleep(nanoseconds: 820_000_000)
        }
    }

    private func drawDeckCard() {
        guard context.definition.format == .deckOfProof,
              currentExercisePair != nil,
              !deckIsDrawing,
              !deckIsRevealed
        else { return }

        deckIsDrawing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard context.definition.format == .deckOfProof else { return }
            withAnimation(.easeInOut(duration: 0.36)) {
                deckIsRevealed = true
                deckIsDrawing = false
            }
        }
    }

    private func completeDeckCard() {
        guard context.definition.format == .deckOfProof,
              deckIsRevealed,
              let pair = currentExercisePair
        else { return }

        let setIndex = pair.exercise.sets.firstIndex { !$0.isWarmup && !$0.logged }
            ?? pair.exercise.sets.firstIndex { !$0.logged }
        guard let setIndex else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            deckIsRevealed = false
            deckIsDrawing = false
            context.session.confirmAsPlanned(exerciseIndex: pair.index, setIndex: setIndex)
        }
    }

    private func nextUnloggedSet() -> (exerciseIndex: Int, setIndex: Int)? {
        for exerciseIndex in context.session.exercises.indices {
            let exercise = context.session.exercises[exerciseIndex]
            guard !exercise.skipped else { continue }
            if let setIndex = exercise.sets.firstIndex(where: { !$0.isWarmup && !$0.logged }) {
                return (exerciseIndex, setIndex)
            }
        }
        return nil
    }

    private static func stationAutoLogLimit() -> Int {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let requested = value(after: "-rankTrialDemoAutoSets", in: args)
            ?? value(after: "--rank-trial-demo-auto-sets", in: args)
            ?? env["RANK_TRIAL_DEMO_AUTO_SETS"]
        guard let requested,
              let count = Int(requested)
        else { return 5 }
        return min(max(count, 0), 30)
    }

    private static func postScenarioHoldNanoseconds() -> UInt64 {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let requested = value(after: "-rankTrialDemoPostHoldSeconds", in: args)
            ?? value(after: "--rank-trial-demo-post-hold-seconds", in: args)
            ?? env["RANK_TRIAL_DEMO_POST_HOLD_SECONDS"]
        guard let requested,
              let seconds = Double(requested)
        else { return 1_050_000_000 }
        let clampedSeconds = min(max(seconds, 0), 20)
        return UInt64(clampedSeconds * 1_000_000_000)
    }

    private static func requestedScenarioIndex(in scenarios: [RankTrialDemoScenario]) -> Int? {
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let requested = value(after: "-rankTrialDemo", in: args)
            ?? value(after: "--rank-trial-demo", in: args)
            ?? env["RANK_TRIAL_DEMO"]
        guard let requested, !requested.isEmpty else { return nil }

        if let numeric = Int(requested), scenarios.indices.contains(numeric) {
            return numeric
        }

        let normalized = requested
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
        return scenarios.firstIndex { scenario in
            scenario.definition.displayName
                .replacingOccurrences(of: "The ", with: "")
                .replacingOccurrences(of: " ", with: "")
                .lowercased() == normalized
                || scenario.definition.format.rawValue.lowercased() == normalized
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
}

private enum RankTrialDemoPhase {
    case ready
    case active
}

private struct RankTrialDemoScenario: Identifiable {
    let index: Int
    let definition: OverallRankTrialDefinition

    var id: String { definition.id }

    static let all: [RankTrialDemoScenario] = OverallRankTrialDefinitions.all.enumerated().map {
        RankTrialDemoScenario(index: $0.offset, definition: $0.element)
    }

    @MainActor
    func makeContext() -> RankTrialDemoContext {
        let equipment: Set<MovementEquipment> = [
            .bodyweight,
            .barbell,
            .dumbbell,
            .kettlebell,
            .cable,
            .machine,
            .pullupBar,
            .dipStation,
            .rings,
            .bench,
            .box,
            .band,
            .sled,
            .cardioMachine,
            .openSpace
        ]
        let resolution = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: DevBuildBootstrapper.userId,
            equipment: equipment
        )
        let draft = definition.makeDraft(
            userId: DevBuildBootstrapper.userId,
            resolvedTrial: resolution.resolvedTrial,
            bodyweightKg: 82
        )
        return RankTrialDemoContext(
            definition: definition,
            draft: draft,
            session: ActiveWorkoutSession(trainingDraft: draft)
        )
    }
}

private struct RankTrialDemoContext {
    let definition: OverallRankTrialDefinition
    let draft: TrainingSessionDraft
    let session: ActiveWorkoutSession
}

private struct RankTrialDemoDeckReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var examples: [TrainingBlock] {
        Array(blocks.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DECK OF PROOF")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)
                    Text("Four example draws. Real deck order starts when live.")
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Text("52")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(examples.enumerated()), id: \.element.id) { index, block in
                    RankTrialDemoDeckExampleCard(block: block, index: index, tint: tint)
                }
            }
        }
        .accessibilityIdentifier("rankTrialDemo.deckReady")
    }
}

private struct RankTrialDemoDeckExampleCard: View {
    let block: TrainingBlock
    let index: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cardCode)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(cardInk)
                Spacer()
                Text(suitGlyph)
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .foregroundStyle(cardInk)
            }

            Spacer(minLength: 10)

            Text(block.title.replacingOccurrences(of: "Card ", with: ""))
                .font(Font.unbound.captionS.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            if let prescription = block.prescriptions.first {
                Text(prescription.exerciseName.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(cardInk.opacity(0.84))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(13)
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.965, green: 0.955, blue: 0.925))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
        .rotationEffect(.degrees(Double(index - 1) * 1.8))
    }

    private var cardCode: String {
        let parts = block.title.split(separator: " ")
        guard parts.count > 1 else { return "\(index + 1)" }
        return String(parts[1])
    }

    private var suitGlyph: String {
        guard let suit = cardCode.last else { return "◆" }
        switch suit {
        case "H": return "♥"
        case "D": return "♦"
        case "C": return "♣"
        case "S": return "♠"
        default: return "◆"
        }
    }

    private var cardInk: Color {
        guard let suit = cardCode.last else { return tint }
        return suit == "H" || suit == "D" ? Color(red: 0.72, green: 0.05, blue: 0.08) : Color.black.opacity(0.86)
    }
}

private struct RankTrialDemoStationCard: View {
    let index: Int
    let exercise: ActiveWorkoutSession.ActiveExercise
    let isCurrent: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            visual
                .frame(width: 74, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(statusText)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(isComplete ? Color.unbound.accent : tint)
                Text(exercise.name)
                    .font(Font.unbound.bodyM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                Text("\(exercise.plannedSets) x \(exercise.plannedReps)  /  \(loggedWorkingSets)/\(totalWorkingSets) logged")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            Image(systemName: isComplete ? "checkmark.seal.fill" : "circle.dashed")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(isComplete ? Color.unbound.accent : Color.unbound.textTertiary)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isCurrent ? tint.opacity(0.58) : Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var visual: some View {
        if let movementDefinition {
            ExerciseVisualView(definition: movementDefinition, size: .thumbnail)
                .accessibilityHidden(true)
        } else {
            Image(systemName: fallbackIcon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
                .accessibilityHidden(true)
        }
    }

    private var movementDefinition: MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private var loggedWorkingSets: Int {
        exercise.sets.filter { !$0.isWarmup && $0.logged }.count
    }

    private var totalWorkingSets: Int {
        max(1, exercise.sets.filter { !$0.isWarmup }.count)
    }

    private var isComplete: Bool {
        loggedWorkingSets >= totalWorkingSets
    }

    private var statusText: String {
        if isComplete { return "STATION CLEAR" }
        return isCurrent ? "LIVE STATION" : "QUEUED"
    }

    private var fallbackIcon: String {
        switch exercise.blockKind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }
}
#endif
