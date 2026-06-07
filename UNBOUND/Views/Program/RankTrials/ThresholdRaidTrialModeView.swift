import SwiftUI

struct ThresholdRaidTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var nodes: [ThresholdRaidReadyNode] {
        blocks.enumerated().map { index, block in
            ThresholdRaidReadyNode(index: index, block: block)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                ThresholdRaidReadyMap(nodes: nodes, tint: tint)
                    .frame(width: 132, height: 250)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("THRESHOLD RAID")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(tint)

                    Text("Break three phase gates: engine repeat, breach work, control hold.")
                        .font(Font.unbound.bodyM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        RankTrialInfoChip(text: "\(nodes.count) stations", icon: "point.3.connected.trianglepath.dotted", tint: tint, strokeOpacity: 0.3)
                        RankTrialInfoChip(text: "3 gates", icon: "shield.lefthalf.filled", tint: tint, strokeOpacity: 0.3)
                    }
                }
                .layoutPriority(1)
            }

            VStack(spacing: 10) {
                ForEach(ThresholdRaidPhase.readyPhases(for: nodes)) { phase in
                    ThresholdRaidReadyPhaseRow(phase: phase, tint: tint)
                }
            }
            .accessibilityIdentifier("workoutReady.thresholdRaidPhases")
        }
    }

}

struct ThresholdRaidTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var raidIsLive = false

    init(
        definition: OverallRankTrialDefinition,
        session: ActiveWorkoutSession,
        @ViewBuilder currentStationCard: @escaping (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard
    ) {
        self.definition = definition
        self.session = session
        self.currentStationCard = currentStationCard
    }

    var body: some View {
        RankTrialActiveStageLayout(pair: session.rankTrialCurrentExercisePair) {
            activeHeader
        } activeContent: { pair in
            raidStage(pair: pair)
            currentStationCard(pair.index, pair.exercise)
        } completedContent: {
            completedRaidStage
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                raidIsLive = true
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RAID MAP")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(tint)
                Text(currentPhase.displayTitle)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("BREACH")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(tint)
            }
        }
    }

    private func raidStage(pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ThresholdRaidActiveMap(
                nodes: activeNodes,
                currentPhase: currentPhase,
                progress: stationProgress,
                tint: tint,
                pulse: raidIsLive
            )
            .frame(maxWidth: .infinity)
            .frame(height: 184)
            .accessibilityHidden(true)

            currentChamber(pair: pair)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("thresholdRaid.activeStage")
    }

    private func currentChamber(pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        let isComplete = pair.exercise.hasCompletedRankTrialWorkingSets
        let statusText = stationStatusText(pair.exercise)

        return ZStack(alignment: .bottomLeading) {
            ThresholdRaidGateShape()
                .fill(
                    LinearGradient(
                        colors: [
                            currentPhase.color.opacity(0.34),
                            Color.unbound.surfaceElevated.opacity(0.88),
                            Color.unbound.bg.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(ThresholdRaidGateShape().stroke(currentPhase.color.opacity(0.48), lineWidth: 1.2))

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    ThresholdRaidGateShape()
                        .fill(Color.unbound.bg.opacity(0.58))
                        .overlay(ThresholdRaidGateShape().stroke(tint.opacity(0.24), lineWidth: 1))

                    if let definition = movementDefinition(for: pair.exercise) {
                        ExerciseVisualView(definition: definition, size: .thumbnail)
                            .padding(10)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: fallbackIcon(for: pair.exercise.blockKind))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(currentPhase.color)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: 116, height: 112)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        raidPill(currentPhase.shortTitle, icon: currentPhase.icon)
                        raidPill("Node \(numberString(pair.index + 1))", icon: isComplete ? "checkmark.seal.fill" : "scope")
                    }

                    Text(pair.exercise.blockTitle ?? pair.exercise.name)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text(stationSummary(pair.exercise))
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .layoutPriority(1)
            }
            .padding(14)

            ThresholdRaidTraceCharge(
                phase: currentPhase,
                progress: stationProgress,
                pulse: raidIsLive,
                tint: tint
            )
            .frame(width: 118, height: 82)
            .padding(.top, 14)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                Image(systemName: isComplete ? "checkmark.seal.fill" : "bolt.shield.fill")
                    .font(.system(size: 12, weight: .black))
                Text(statusText)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
            }
            .foregroundStyle(isComplete ? Color.unbound.bg : Color.unbound.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(isComplete ? Color.unbound.accent : currentPhase.color.opacity(0.28)))
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .shadow(color: currentPhase.color.opacity(raidIsLive ? 0.26 : 0.14), radius: raidIsLive ? 24 : 12, y: 10)
    }

    private struct ThresholdRaidTraceCharge: View {
        let phase: ThresholdRaidPhase
        let progress: CGFloat
        let pulse: Bool
        let tint: Color

        private var clampedProgress: CGFloat {
            min(max(progress, 0), 1)
        }

        var body: some View {
            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(phase.color.opacity(index == 0 ? 0.48 : 0.16), lineWidth: index == 0 ? 1.2 : 1)
                            .scaleEffect(1 - CGFloat(index) * 0.18)
                    }

                    Path { path in
                        path.move(to: CGPoint(x: proxy.size.width * 0.14, y: proxy.size.height * 0.72))
                        path.addLine(to: CGPoint(x: proxy.size.width * 0.42, y: proxy.size.height * 0.28))
                        path.addLine(to: CGPoint(x: proxy.size.width * 0.64, y: proxy.size.height * 0.56))
                        path.addLine(to: CGPoint(x: proxy.size.width * 0.86, y: proxy.size.height * 0.22))
                    }
                    .trim(from: 0, to: max(0.16, clampedProgress))
                    .stroke(
                        LinearGradient(colors: [tint, phase.color], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: phase.color.opacity(pulse ? 0.42 : 0.16), radius: pulse ? 12 : 5)

                    Image(systemName: phase.icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(phase.color)
                }
            }
        }
    }

    private var completedRaidStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThresholdRaidActiveMap(
                nodes: activeNodes,
                currentPhase: .control,
                progress: 1,
                tint: tint,
                pulse: raidIsLive
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.accent)
                Text("Threshold breached. Finish the trial to record the result.")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .accessibilityIdentifier("thresholdRaid.completedStage")
    }

    private func raidPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(Color.unbound.surfaceElevated.opacity(0.92)))
            .overlay(Capsule().strokeBorder(currentPhase.color.opacity(0.36), lineWidth: 1))
    }

    private var activeNodes: [ThresholdRaidActiveNode] {
        session.exercises.enumerated().compactMap { index, exercise in
            guard !exercise.skipped else { return nil }
            let phase = ThresholdRaidPhase.phase(for: exercise.blockTitle ?? exercise.name, fallbackIndex: index)
            return ThresholdRaidActiveNode(
                id: exercise.id,
                index: index,
                phase: phase,
                title: exercise.blockTitle ?? exercise.name,
                isCurrent: index == session.currentExerciseIndex,
                isCleared: exercise.hasCompletedRankTrialWorkingSets
            )
        }
    }

    private var currentPhase: ThresholdRaidPhase {
        guard let pair = session.rankTrialCurrentExercisePair else { return .control }
        return ThresholdRaidPhase.phase(for: pair.exercise.blockTitle ?? pair.exercise.name, fallbackIndex: pair.index)
    }

    private var totalStations: Int {
        session.rankTrialStationCount
    }

    private var loggedStations: Int {
        session.rankTrialLoggedStationCount { $0.hasCompletedRankTrialWorkingSets }
    }

    private var stationProgress: CGFloat {
        session.rankTrialProgress(loggedStations: loggedStations)
    }

    private var tint: Color {
        definition.targetRank.rewardTextTint
    }

    private func stationStatusText(_ exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        if exercise.hasCompletedRankTrialWorkingSets { return "GATE OPEN" }

        let workingSets = exercise.sets.filter { !$0.isWarmup }
        let loggedSets = workingSets.filter(\.logged).count
        guard loggedSets > 0 else { return "BREACHING" }

        return "BREACH \(loggedSets)/\(max(1, workingSets.count))"
    }

    private func stationSummary(_ exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        var parts = ["\(exercise.plannedSets)x \(exercise.plannedReps)"]
        if exercise.restSeconds > 0 {
            parts.append("Rest \(Self.mmss(exercise.restSeconds))")
        }
        if let rpe = exercise.targetRPE {
            parts.append("RPE \(rpe)")
        }
        return parts.joined(separator: " / ")
    }

    private func movementDefinition(for exercise: ActiveWorkoutSession.ActiveExercise) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private func fallbackIcon(for blockKind: TrainingBlockKind) -> String {
        switch blockKind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }

    private func numberString(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private enum ThresholdRaidPhase: Int, CaseIterable, Identifiable {
    case engine = 1
    case breach = 2
    case control = 3

    var id: Int { rawValue }

    var displayTitle: String {
        switch self {
        case .engine: return "Stage 1: Engine Repeats"
        case .breach: return "Stage 2: Breach Work"
        case .control: return "Stage 3: Control Hold"
        }
    }

    var shortTitle: String {
        switch self {
        case .engine: return "Engine"
        case .breach: return "Breach"
        case .control: return "Control"
        }
    }

    var icon: String {
        switch self {
        case .engine: return "repeat"
        case .breach: return "bolt.shield.fill"
        case .control: return "timer"
        }
    }

    var color: Color {
        switch self {
        case .engine: return Color.unbound.coachCyan
        case .breach: return Color.unbound.impact
        case .control: return Color.unbound.rankGold
        }
    }

    static func phase(for title: String, fallbackIndex: Int) -> ThresholdRaidPhase {
        let lowercased = title.lowercased()
        if lowercased.contains("stage 1") || lowercased.contains("engine") {
            return .engine
        }
        if lowercased.contains("stage 3") || lowercased.contains("control") || lowercased.contains("hold") {
            return .control
        }
        if lowercased.contains("stage 2") || lowercased.contains("carry") || lowercased.contains("raid") {
            return .breach
        }
        if fallbackIndex == 0 { return .engine }
        return fallbackIndex >= 4 ? .control : .breach
    }

    static func readyPhases(for nodes: [ThresholdRaidReadyNode]) -> [ThresholdRaidReadyPhase] {
        ThresholdRaidPhase.allCases.map { phase in
            let phaseNodes = nodes.filter { $0.phase == phase }
            return ThresholdRaidReadyPhase(phase: phase, nodes: phaseNodes)
        }
    }
}

private struct ThresholdRaidReadyNode: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var phase: ThresholdRaidPhase { ThresholdRaidPhase.phase(for: block.title, fallbackIndex: index) }
    var title: String { block.title }
    var prescription: TrainingBlockPrescription? { block.prescriptions.first }
    var exerciseName: String { prescription?.exerciseName ?? block.title }

    var summary: String {
        guard let prescription else { return "Official gate" }
        var parts = ["\(prescription.sets)x \(prescription.displayTargetText)"]
        if prescription.restSeconds > 0 {
            parts.append("\(Self.mmss(prescription.restSeconds)) rest")
        }
        if let rpe = prescription.rpe {
            parts.append("RPE \(rpe)")
        }
        return parts.joined(separator: " / ")
    }

    var movementDefinition: MovementDefinition? {
        guard let prescription else { return nil }
        return MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    var fallbackIcon: String {
        switch block.kind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct ThresholdRaidReadyPhase: Identifiable {
    let phase: ThresholdRaidPhase
    let nodes: [ThresholdRaidReadyNode]

    var id: Int { phase.rawValue }
}

private struct ThresholdRaidActiveNode: Identifiable {
    let id: String
    let index: Int
    let phase: ThresholdRaidPhase
    let title: String
    let isCurrent: Bool
    let isCleared: Bool
}

private struct ThresholdRaidReadyPhaseRow: View {
    let phase: ThresholdRaidReadyPhase
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                ThresholdRaidDiamond()
                    .fill(phase.phase.color.opacity(0.22))
                ThresholdRaidDiamond()
                    .stroke(phase.phase.color.opacity(0.64), lineWidth: 1.2)
                Image(systemName: phase.phase.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(phase.phase.color)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(phase.phase.displayTitle.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(phase.phase.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("\(phase.nodes.count)")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .foregroundStyle(Color.unbound.bg)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(tint))
                }

                if let primary = phase.nodes.first {
                    HStack(spacing: 10) {
                        if let definition = primary.movementDefinition {
                            ExerciseVisualView(definition: definition, size: .thumbnail)
                                .frame(width: 46, height: 38)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: primary.fallbackIcon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(phase.phase.color)
                                .frame(width: 46, height: 38)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(primary.exerciseName)
                                .font(Font.unbound.bodyS.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(primary.summary)
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .layoutPriority(1)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct ThresholdRaidReadyMap: View {
    let nodes: [ThresholdRaidReadyNode]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = Self.points(in: proxy.size, count: nodes.count)

            ZStack {
                ThresholdRaidMapPlate()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.bg.opacity(0.96),
                                Color.unbound.surfaceElevated.opacity(0.9),
                                tint.opacity(0.2)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .overlay(ThresholdRaidMapPlate().stroke(tint.opacity(0.34), lineWidth: 1.2))

                ThresholdRaidPath(points: points)
                    .stroke(tint.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [7, 6]))

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    ZStack {
                        ThresholdRaidDiamond()
                            .fill(node.phase.color.opacity(0.24))
                        ThresholdRaidDiamond()
                            .stroke(node.phase.color.opacity(0.76), lineWidth: index == 0 || index == nodes.count - 1 ? 1.8 : 1.2)
                        Text("\(node.phase.rawValue)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.unbound.textPrimary)
                    }
                    .frame(width: index == 0 || index == nodes.count - 1 ? 34 : 28, height: index == 0 || index == nodes.count - 1 ? 34 : 28)
                    .position(point(at: index, in: points))
                }
            }
        }
    }

    private func point(at index: Int, in points: [CGPoint]) -> CGPoint {
        points.indices.contains(index) ? points[index] : .zero
    }

    private static func points(in size: CGSize, count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let usableWidth = max(1, size.width - 34)
        let step = count == 1 ? 0 : usableWidth / CGFloat(count - 1)
        return (0..<count).map { index in
            let x = 17 + CGFloat(index) * step
            let wave = CGFloat(index % 2 == 0 ? -1 : 1)
            let y = (size.height * 0.5) + (wave * size.height * 0.2)
            return CGPoint(x: x, y: min(max(24, y), size.height - 24))
        }
    }
}

private struct ThresholdRaidActiveMap: View {
    let nodes: [ThresholdRaidActiveNode]
    let currentPhase: ThresholdRaidPhase
    let progress: CGFloat
    let tint: Color
    let pulse: Bool

    var body: some View {
        GeometryReader { proxy in
            let points = Self.points(in: proxy.size, count: nodes.count)

            ZStack {
                ThresholdRaidMapPlate()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.bg.opacity(0.98),
                                Color.unbound.surfaceElevated.opacity(0.9),
                                currentPhase.color.opacity(0.24)
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
                    .overlay(ThresholdRaidMapPlate().stroke(currentPhase.color.opacity(0.38), lineWidth: 1.2))

                ThresholdRaidPath(points: points)
                    .stroke(Color.unbound.textTertiary.opacity(0.34), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [9, 7]))

                ThresholdRaidPath(points: Self.progressPoints(points: points, progress: progress))
                    .stroke(tint.opacity(0.82), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: tint.opacity(0.45), radius: pulse ? 12 : 5)

                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    ThresholdRaidActiveMapNode(node: node, label: "\(index + 1)", pulse: pulse)
                        .frame(width: node.isCurrent ? 42 : 34, height: node.isCurrent ? 42 : 34)
                        .position(point(at: index, in: points))
                }
            }
        }
    }

    private func point(at index: Int, in points: [CGPoint]) -> CGPoint {
        points.indices.contains(index) ? points[index] : .zero
    }

    private static func points(in size: CGSize, count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let usableWidth = max(1, size.width - 44)
        let step = count == 1 ? 0 : usableWidth / CGFloat(count - 1)
        return (0..<count).map { index in
            let x = 22 + CGFloat(index) * step
            let phaseOffset: CGFloat
            switch index {
            case 0: phaseOffset = -0.22
            case 1...3: phaseOffset = CGFloat(index % 2 == 0 ? -0.04 : 0.2)
            default: phaseOffset = -0.16
            }
            let y = (size.height * 0.52) + (size.height * phaseOffset)
            return CGPoint(x: x, y: min(max(24, y), size.height - 24))
        }
    }

    private static func progressPoints(points: [CGPoint], progress: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        let clamped = min(max(progress, 0), 1)
        let scaled = clamped * CGFloat(points.count - 1)
        let fullIndex = Int(scaled.rounded(.down))
        var visible = Array(points.prefix(min(points.count, fullIndex + 1)))
        if fullIndex < points.count - 1 {
            let remainder = scaled - CGFloat(fullIndex)
            let start = points[fullIndex]
            let end = points[fullIndex + 1]
            visible.append(
                CGPoint(
                    x: start.x + ((end.x - start.x) * remainder),
                    y: start.y + ((end.y - start.y) * remainder)
                )
            )
        }
        return visible
    }
}

private struct ThresholdRaidActiveMapNode: View {
    let node: ThresholdRaidActiveNode
    let label: String
    let pulse: Bool

    var body: some View {
        ZStack {
            if node.isCurrent {
                ThresholdRaidDiamond()
                    .stroke(node.phase.color.opacity(pulse ? 0.2 : 0.46), lineWidth: 8)
                    .scaleEffect(pulse ? 1.18 : 1)
            }

            ThresholdRaidDiamond()
                .fill(node.isCleared ? node.phase.color : Color.unbound.bg.opacity(0.94))
            ThresholdRaidDiamond()
                .stroke(node.isCurrent ? node.phase.color : node.phase.color.opacity(0.54), lineWidth: node.isCurrent ? 1.8 : 1.1)

            Image(systemName: node.isCleared ? "checkmark" : (node.isCurrent ? node.phase.icon : "circle.fill"))
                .font(.system(size: node.isCurrent ? 12 : 8, weight: .black))
                .foregroundStyle(node.isCleared ? Color.unbound.bg : node.phase.color)
        }
        .accessibilityLabel("\(node.title), node \(label)")
    }
}

private struct ThresholdRaidPath: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct ThresholdRaidMapPlate: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = min(rect.width, rect.height) * 0.12
        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.maxX - notch * 0.55, y: rect.maxY - notch * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + notch * 0.85, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX + notch * 0.45, y: rect.minY + notch * 0.6))
        path.closeSubpath()
        return path
    }
}

private struct ThresholdRaidGateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut = min(rect.width, rect.height) * 0.16
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut * 0.6, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - cut * 0.6, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct ThresholdRaidDiamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
