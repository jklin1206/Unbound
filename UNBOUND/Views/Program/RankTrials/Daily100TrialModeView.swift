import SwiftUI

struct Daily100TrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var oathMarks: [Daily100ReadyMark] {
        blocks.prefix(5).enumerated().map { index, block in
            Daily100ReadyMark(index: index, block: block)
        }
    }

    private var targetTotal: Int {
        max(100, oathMarks.reduce(0) { $0 + $1.targetValue })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Daily100ProofSeal(
                    progress: 1,
                    completedMarks: oathMarks.count,
                    totalMarks: max(5, oathMarks.count),
                    tint: tint,
                    pulse: false
                )
                .frame(width: 126, height: 152)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("DAILY 100")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)

                    Text("Five oath marks. One clean proof.")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Daily100Chip("\(oathMarks.count) marks", icon: "seal.fill", tint: tint)
                        Daily100Chip("\(targetTotal) proof", icon: "checkmark", tint: Color.unbound.coachCyan)
                    }
                }
                .layoutPriority(1)
            }

            Daily100EntryGate(marks: oathMarks, tint: tint)
                .frame(height: 164)
                .accessibilityIdentifier("workoutReady.daily100Gate")

            VStack(spacing: 9) {
                ForEach(oathMarks) { mark in
                    Daily100ReadyMarkRow(mark: mark, tint: tint)
                }
            }
            .accessibilityIdentifier("workoutReady.daily100OathMarks")
        }
    }
}

struct Daily100TrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sealIsLive = false

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
            activeGate(pair: pair)
            currentStationCard(pair.index, pair.exercise)
        } completedContent: {
            completedGate
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: loggedStations)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                sealIsLive = true
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(tint)
                Text(currentTitle)
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
                Text("MARKS")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private func activeGate(pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Daily100EntryGate(
                marks: stationMarks,
                tint: tint,
                activeIndex: markNumber(for: pair.index) - 1,
                completedCount: loggedStations
            )
            .frame(height: 156)
            .overlay(alignment: .topTrailing) {
                Daily100ProofSeal(
                    progress: stationProgress,
                    completedMarks: loggedStations,
                    totalMarks: totalStations,
                    tint: tint,
                    pulse: sealIsLive
                )
                .frame(width: 88, height: 102)
                .offset(x: -8, y: -18)
                .accessibilityHidden(true)
            }
            .accessibilityHidden(true)

            Daily100CurrentStationHero(
                exercise: pair.exercise,
                markNumber: markNumber(for: pair.index),
                tint: tint,
                pulse: sealIsLive,
                isLogged: pair.exercise.hasLoggedRankTrialWorkingSet
            )
            .frame(height: 224)

            HStack(spacing: 8) {
                Daily100Chip("Mark \(markLabel(for: pair.index))", icon: "line.3.horizontal.decrease", tint: tint)
                Daily100Chip(targetText(for: pair.exercise), icon: metricIcon(for: pair.exercise), tint: Color.unbound.coachCyan)
                Spacer(minLength: 0)
                Daily100Chip("\(targetTotal) proof", icon: "checkmark", tint: Color.unbound.accent)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("daily100.activeGate")
    }

    private var completedGate: some View {
        VStack(alignment: .leading, spacing: 16) {
            Daily100EntryGate(
                marks: stationMarks,
                tint: tint,
                activeIndex: nil,
                completedCount: totalStations
            )
            .frame(height: 220)
            .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.accent)
                Text("Daily 100 sealed. Finish the trial to record the result.")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("daily100.completedGate")
    }

    private var stationMarks: [Daily100ReadyMark] {
        session.exercises.enumerated().compactMap { index, exercise in
            guard !exercise.skipped else { return nil }
            return Daily100ReadyMark(
                id: exercise.id,
                index: index,
                title: exercise.blockTitle ?? oathTitle(for: index),
                exerciseName: exercise.name,
                targetText: targetText(for: exercise),
                targetValue: targetValue(for: exercise),
                kind: exercise.blockKind,
                movementDefinition: movementDefinition(for: exercise),
                isComplete: exercise.hasLoggedRankTrialWorkingSet
            )
        }
    }

    private var currentTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Proof Complete" }
        return pair.exercise.blockTitle ?? oathTitle(for: pair.index)
    }

    private var totalStations: Int {
        session.rankTrialStationCount
    }

    private var loggedStations: Int {
        session.rankTrialLoggedStationCount { $0.hasLoggedRankTrialWorkingSet }
    }

    private var stationProgress: CGFloat {
        session.rankTrialProgress(loggedStations: loggedStations)
    }

    private var targetTotal: Int {
        max(100, session.exercises.filter { !$0.skipped }.reduce(0) { $0 + targetValue(for: $1) })
    }

    private var tint: Color {
        definition.targetRank.rewardTextTint
    }

    private func movementDefinition(for exercise: ActiveWorkoutSession.ActiveExercise) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private func targetText(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        "\(exercise.plannedSets) x \(exercise.plannedReps)"
    }

    private func targetValue(for exercise: ActiveWorkoutSession.ActiveExercise) -> Int {
        RepRange.lowerBound(exercise.plannedReps) ?? 0
    }

    private func markNumber(for index: Int) -> Int {
        session.exercises[..<min(index, session.exercises.count)].filter { !$0.skipped }.count + 1
    }

    private func markLabel(for index: Int) -> String {
        let value = markNumber(for: index)
        return value < 10 ? "0\(value)" : "\(value)"
    }

    private func oathTitle(for index: Int) -> String {
        Daily100OathName.title(for: index)
    }

    private func metricIcon(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        switch exercise.metricKind {
        case .reps: return "number"
        case .holdSeconds, .durationSeconds: return "timer"
        case .distanceMeters: return "figure.run"
        case .calories: return "flame.fill"
        }
    }
}

private struct Daily100ReadyMark: Identifiable {
    let id: String
    let index: Int
    let title: String
    let exerciseName: String
    let targetText: String
    let targetValue: Int
    let kind: TrainingBlockKind
    let movementDefinition: MovementDefinition?
    let isComplete: Bool

    init(index: Int, block: TrainingBlock) {
        let prescription = block.prescriptions.first
        id = block.id
        self.index = index
        title = block.title.isEmpty ? Daily100OathName.title(for: index) : block.title
        exerciseName = prescription?.exerciseName ?? title
        targetText = prescription.map { "\($0.sets) x \($0.displayTargetText)" } ?? "Official mark"
        targetValue = prescription?.target.daily100Value ?? 0
        kind = block.kind
        movementDefinition = prescription.flatMap {
            MovementCatalog.resolvedTrainingMovement(
                name: $0.exerciseName,
                movementId: $0.movementId,
                rankStandardMovementId: $0.rankStandardMovementId
            )?.exact
        }
        isComplete = false
    }

    init(
        id: String,
        index: Int,
        title: String,
        exerciseName: String,
        targetText: String,
        targetValue: Int,
        kind: TrainingBlockKind,
        movementDefinition: MovementDefinition?,
        isComplete: Bool
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.exerciseName = exerciseName
        self.targetText = targetText
        self.targetValue = targetValue
        self.kind = kind
        self.movementDefinition = movementDefinition
        self.isComplete = isComplete
    }

    var markLabel: String {
        let value = index + 1
        return value < 10 ? "0\(value)" : "\(value)"
    }

    var cleanedTitle: String {
        title
            .replacingOccurrences(of: " Oath", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var fallbackIcon: String {
        Daily100Visuals.fallbackIcon(for: kind)
    }
}

private struct Daily100ProofSeal: View {
    let progress: CGFloat
    let completedMarks: Int
    let totalMarks: Int
    let tint: Color
    let pulse: Bool

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Daily100SealShape(sides: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surfaceElevated.opacity(0.98),
                            Color.unbound.bg.opacity(0.96),
                            tint.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Daily100SealShape(sides: 12).stroke(tint.opacity(0.48), lineWidth: 1.2))
                .shadow(color: tint.opacity(pulse ? 0.30 : 0.14), radius: pulse ? 24 : 12, y: 8)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [tint, Color.unbound.coachCyan, Color.unbound.accent, tint],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(13)

            Circle()
                .strokeBorder(Color.unbound.textPrimary.opacity(0.12), lineWidth: 1)
                .padding(23)

            VStack(spacing: 0) {
                Text("100")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.76)
                Text("PROOF")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                Text("\(completedMarks)/\(max(1, totalMarks))")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
                    .padding(.top, 5)
            }

            VStack {
                Daily100NotchRow(total: max(1, totalMarks), completed: completedMarks, tint: tint)
                Spacer()
            }
            .padding(.top, 14)
        }
        .accessibilityLabel("Daily 100 proof seal")
        .accessibilityValue("\(completedMarks) of \(max(1, totalMarks)) oath marks")
    }
}

private struct Daily100EntryGate: View {
    let marks: [Daily100ReadyMark]
    let tint: Color
    var activeIndex: Int? = nil
    var completedCount: Int = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Daily100GateShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.24),
                                Color.unbound.surfaceElevated.opacity(0.90),
                                Color.unbound.bg.opacity(0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Daily100GateShape().stroke(tint.opacity(0.38), lineWidth: 1.2))

                VStack(spacing: 10) {
                    HStack(spacing: 7) {
                        ForEach(Array(marks.prefix(5).enumerated()), id: \.element.id) { index, mark in
                            Daily100GateMark(
                                mark: mark,
                                isActive: activeIndex == index,
                                isComplete: mark.isComplete || index < completedCount,
                                tint: tint
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(tint.opacity(0.48))
                            .frame(width: max(30, proxy.size.width * 0.22), height: 2)
                        Text("ENTRY GATE")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Rectangle()
                            .fill(tint.opacity(0.48))
                            .frame(width: max(30, proxy.size.width * 0.22), height: 2)
                    }
                }
                .padding(.bottom, 18)
            }
        }
    }
}

private struct Daily100ReadyMarkRow: View {
    let mark: Daily100ReadyMark
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Daily100MarkShape()
                    .fill(tint.opacity(0.12))
                    .overlay(Daily100MarkShape().stroke(tint.opacity(0.42), lineWidth: 1))
                Text(mark.markLabel)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 38)

            if let definition = mark.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 54, height: 46)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: mark.fallbackIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 46)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(mark.cleanedTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(mark.exerciseName)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(mark.targetText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private struct Daily100CurrentStationHero: View {
    let exercise: ActiveWorkoutSession.ActiveExercise
    let markNumber: Int
    let tint: Color
    let pulse: Bool
    let isLogged: Bool

    private var movementDefinition: MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Daily100GateShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.22),
                            Color.unbound.surfaceElevated.opacity(0.86),
                            Color.unbound.bg.opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Daily100GateShape().stroke(tint.opacity(0.42), lineWidth: 1.2))

            if let movementDefinition {
                ExerciseVisualView(definition: movementDefinition, size: .thumbnail)
                    .frame(maxWidth: .infinity, maxHeight: 128)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 62)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: Daily100Visuals.fallbackIcon(for: exercise.blockKind))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: 128)
                    .padding(.bottom, 62)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: isLogged ? "checkmark.seal.fill" : "seal")
                        .font(.system(size: 12, weight: .black))
                    Text(isLogged ? "SEALED" : "OATH \(markNumber)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.3)
                }
                .foregroundStyle(isLogged ? Color.unbound.bg : Color.unbound.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(isLogged ? Color.unbound.accent : tint.opacity(pulse ? 0.34 : 0.22)))

                Text(exercise.name)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: tint.opacity(pulse ? 0.24 : 0.12), radius: pulse ? 22 : 12, y: 8)
    }
}

private struct Daily100GateMark: View {
    let mark: Daily100ReadyMark
    let isActive: Bool
    let isComplete: Bool
    let tint: Color

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Daily100MarkShape()
                    .fill(fill)
                    .overlay(Daily100MarkShape().stroke(border, lineWidth: isActive ? 1.5 : 1))
                    .shadow(color: shadow, radius: isActive ? 12 : 0)

                Image(systemName: isComplete ? "checkmark" : icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(isComplete ? Color.unbound.bg : labelTint)
            }
            .frame(height: 44)

            Text(mark.cleanedTitle.uppercased())
                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(isActive ? tint : Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity)
    }

    private var fill: Color {
        if isComplete { return Color.unbound.accent.opacity(0.94) }
        if isActive { return tint.opacity(0.26) }
        return Color.unbound.bg.opacity(0.72)
    }

    private var border: Color {
        if isComplete { return Color.unbound.accent }
        if isActive { return tint.opacity(0.82) }
        return Color.unbound.textPrimary.opacity(0.18)
    }

    private var labelTint: Color {
        isActive ? tint : Color.unbound.textSecondary
    }

    private var shadow: Color {
        isActive ? tint.opacity(0.30) : Color.clear
    }

    private var icon: String {
        switch mark.index {
        case 0: return "figure.strengthtraining.traditional"
        case 1: return "arrow.up.forward"
        case 2: return "arrow.left.and.right"
        case 3: return "figure.stairs"
        default: return "timer"
        }
    }
}

private struct Daily100Chip: View {
    let text: String
    let icon: String
    let tint: Color

    init(_ text: String, icon: String, tint: Color) {
        self.text = text
        self.icon = icon
        self.tint = tint
    }

    var body: some View {
        Label(text, systemImage: icon)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Capsule().fill(Color.unbound.surfaceElevated))
            .overlay(Capsule().strokeBorder(tint.opacity(0.34), lineWidth: 1))
    }
}

private struct Daily100NotchRow: View {
    let total: Int
    let completed: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < completed ? tint : Color.unbound.textPrimary.opacity(0.18))
                    .frame(width: 11, height: index < completed ? 5 : 3)
            }
        }
    }
}

private struct Daily100SealShape: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        let count = max(6, sides * 2)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) * 0.48
        let innerRadius = outerRadius * 0.88
        var path = Path()

        for index in 0..<count {
            let angle = (Double(index) / Double(count) * 2 * Double.pi) - Double.pi / 2
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct Daily100GateShape: Shape {
    func path(in rect: CGRect) -> Path {
        let capHeight = rect.height * 0.28
        let shoulder = rect.width * 0.14
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + capHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + capHeight),
            control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Daily100MarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.width * 0.18
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.24))
        path.closeSubpath()
        return path
    }
}

private enum Daily100OathName {
    static func title(for index: Int) -> String {
        switch index {
        case 0: return "Lower Oath"
        case 1: return "Push Oath"
        case 2: return "Posture Oath"
        case 3: return "Step Oath"
        default: return "Trunk Oath"
        }
    }
}

private enum Daily100Visuals {
    static func fallbackIcon(for blockKind: TrainingBlockKind) -> String {
        switch blockKind {
        case .strength, .custom: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.traditional"
        case .skill: return "figure.gymnastics"
        case .cardio: return "figure.run"
        case .carry: return "shippingbox.fill"
        case .routine: return "timer"
        }
    }
}

private extension TrainingTarget {
    var daily100Value: Int {
        switch self {
        case .reps(let value),
             .holdSeconds(let value),
             .timedSeconds(let value),
             .distanceMeters(let value),
             .calories(let value):
            return value
        case .repsRange(let lower, _):
            return lower
        case .amrap:
            return 0
        }
    }
}
