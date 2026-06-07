import SwiftUI

struct FinisherTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var stations: [FinisherReadyStation] {
        blocks.enumerated().map { index, block in
            FinisherReadyStation(index: index, block: block)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                FinisherRoundStack(
                    rounds: Self.rounds,
                    activeRound: stations.first?.roundValue ?? 21,
                    progress: 0,
                    tint: tint,
                    isLive: true
                )
                .frame(width: 136, height: 190)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("21-15-9")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.8)
                        .foregroundStyle(tint)
                    Text("Three descending waves. Hit the first rep fast, then close the gap.")
                        .font(Font.unbound.bodyM.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        RankTrialInfoChip(text: "\(stations.count) stations", icon: "bolt.fill", tint: tint, strokeOpacity: 0.3)
                        RankTrialInfoChip(text: "Fast close", icon: "timer", tint: tint, strokeOpacity: 0.3)
                    }
                }
                .layoutPriority(1)
            }

            VStack(spacing: 9) {
                ForEach(stations) { station in
                    FinisherReadyStationRow(station: station, tint: tint)
                }
            }
            .accessibilityIdentifier("workoutReady.finisherGauntlet")
        }
    }

    private static let rounds = [21, 15, 9]
}

struct FinisherTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spiralIsLive = false

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
            gauntletStage(pair: pair)
            currentStationCard(pair.index, pair.exercise)
        } completedContent: {
            completedStage
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                spiralIsLive = true
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FINISHER")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(tint)
                Text(headerTitle)
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
                Text("CLEARED")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private func gauntletStage(pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                FinisherRoundStack(
                    rounds: roundValues,
                    activeRound: roundValue(for: pair.exercise),
                    progress: stationProgress,
                    tint: tint,
                    isLive: spiralIsLive
                )
                .frame(width: 128, height: 172)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        RankTrialInfoChip(text: roundLabel(for: pair.exercise), icon: "arrow.down.forward", tint: tint)
                        RankTrialInfoChip(text: "Gate \(pair.index + 1)", icon: "flag.checkered", tint: tint)
                    }

                    Text(pair.exercise.blockTitle ?? pair.exercise.name)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text(stationSummary(for: pair.exercise))
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            currentStationHero(pair.exercise)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("finisher.activeStage")
    }

    private func currentStationHero(_ exercise: ActiveWorkoutSession.ActiveExercise) -> some View {
        ZStack(alignment: .bottomLeading) {
            FinisherBladeShape(cutDepth: 32)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.bg.opacity(0.98),
                            Color.unbound.surfaceElevated.opacity(0.94),
                            tint.opacity(0.24)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .overlay(FinisherBladeShape(cutDepth: 32).stroke(tint.opacity(0.42), lineWidth: 1.2))

            HStack(alignment: .bottom, spacing: 0) {
                if let definition = movementDefinition(for: exercise) {
                    ExerciseVisualView(definition: definition, size: .thumbnail)
                        .padding(.leading, 16)
                        .padding(.vertical, 16)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: fallbackIcon(for: exercise.blockKind))
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(tint)
                        .frame(width: 132)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(roundValueString(for: exercise))
                        .font(Font.unbound.monoXL.weight(.black))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                    Text(metricLabel(for: exercise).uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }

            VStack {
                FinisherImpactTrack(
                    progress: stationProgress,
                    valueText: roundValueString(for: exercise),
                    tint: tint,
                    pulse: spiralIsLive
                )
                .padding(.horizontal, 18)
                .padding(.top, 16)
                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                Image(systemName: exercise.hasLoggedRankTrialWorkingSet ? "checkmark.seal.fill" : "bolt.fill")
                    .font(.system(size: 12, weight: .black))
                Text(exercise.hasLoggedRankTrialWorkingSet ? "CLOSED" : "LIVE ROUND")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
            }
            .foregroundStyle(exercise.hasLoggedRankTrialWorkingSet ? Color.unbound.bg : Color.unbound.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(exercise.hasLoggedRankTrialWorkingSet ? Color.unbound.accent : tint.opacity(0.3)))
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 218)
        .shadow(color: tint.opacity(spiralIsLive ? 0.24 : 0.12), radius: spiralIsLive ? 24 : 12, y: 10)
    }

    private struct FinisherImpactTrack: View {
        let progress: CGFloat
        let valueText: String
        let tint: Color
        let pulse: Bool

        private var clampedProgress: CGFloat {
            min(max(progress, 0), 1)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("PRESSURE")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(valueText)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(tint)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { index in
                        let threshold = CGFloat(index + 1) / 7
                        Capsule()
                            .fill(threshold <= clampedProgress ? tint : Color.unbound.bg.opacity(0.64))
                            .frame(maxWidth: .infinity)
                            .frame(height: index == 6 ? 12 : 8)
                            .overlay(
                                Capsule()
                                    .strokeBorder(tint.opacity(threshold <= clampedProgress ? 0.7 : 0.22), lineWidth: 1)
                            )
                            .shadow(color: threshold <= clampedProgress ? tint.opacity(pulse ? 0.24 : 0.08) : .clear, radius: 8)
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var completedStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            FinisherRoundStack(
                rounds: roundValues,
                activeRound: roundValues.last ?? 9,
                progress: 1,
                tint: tint,
                isLive: spiralIsLive
            )
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.accent)
                Text("Gauntlet closed. Finish the trial to record the result.")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .accessibilityIdentifier("finisher.completedStage")
    }

    private var headerTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Closeout Complete" }
        return "\(roundValueString(for: pair.exercise)) \(metricLabel(for: pair.exercise))"
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

    private var roundValues: [Int] {
        let parsed = session.exercises
            .filter { !$0.skipped }
            .compactMap { roundValue(for: $0) }
        let unique = Array(Set(parsed)).sorted(by: >)
        return unique.isEmpty ? [21, 15, 9] : unique
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

    private func roundValue(for exercise: ActiveWorkoutSession.ActiveExercise) -> Int? {
        if let value = RepRange.lowerBound(exercise.plannedReps) {
            return value
        }

        guard let title = exercise.blockTitle else { return nil }
        return Self.firstInteger(in: title)
    }

    private func roundValueString(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        guard let value = roundValue(for: exercise) else { return exercise.plannedReps.isEmpty ? "--" : exercise.plannedReps }
        return "\(value)"
    }

    private func roundLabel(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        "\(roundValueString(for: exercise)) wave"
    }

    private func metricLabel(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        switch exercise.metricKind {
        case .reps: return "reps"
        case .holdSeconds: return "sec hold"
        case .durationSeconds: return "sec"
        case .distanceMeters: return "meters"
        case .calories: return "cal"
        }
    }

    private func stationSummary(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        var parts = ["\(exercise.plannedSets)x \(exercise.plannedReps)"]
        if exercise.restSeconds > 0 {
            parts.append("Rest \(Self.mmss(exercise.restSeconds))")
        }
        if let rpe = exercise.targetRPE {
            parts.append("RPE \(rpe)")
        }
        return parts.joined(separator: " / ")
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

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private static func firstInteger(in text: String) -> Int? {
        var digits = ""
        for character in text {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits)
    }
}

private struct FinisherReadyStation: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }

    var prescription: TrainingBlockPrescription? {
        block.prescriptions.first
    }

    var roundValue: Int {
        prescription?.target.metricLowerBound
            ?? Self.firstInteger(in: block.title)
            ?? Self.defaultRounds[min(index, Self.defaultRounds.count - 1)]
    }

    var roundText: String {
        "\(roundValue)"
    }

    var title: String {
        block.title
            .replacingOccurrences(of: "\(roundValue)", with: "")
            .replacingOccurrences(of: "Round", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var exerciseName: String {
        prescription?.exerciseName ?? block.title
    }

    var summary: String {
        guard let prescription else { return "Official station" }
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

    private static let defaultRounds = [21, 15, 9]

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private static func firstInteger(in text: String) -> Int? {
        var digits = ""
        for character in text {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Int(digits)
    }
}

private struct FinisherReadyStationRow: View {
    let station: FinisherReadyStation
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(station.roundText)
                .font(Font.unbound.monoL.weight(.black))
                .foregroundStyle(tint)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)

            FinisherSlash()
                .fill(tint.opacity(0.52))
                .frame(width: 10, height: 54)
                .accessibilityHidden(true)

            if let definition = station.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 56, height: 50)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: station.fallbackIcon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 50)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(station.title.isEmpty ? "ROUND \(station.roundText)" : station.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(station.exerciseName)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(station.summary)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            FinisherBladeShape(cutDepth: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.12),
                            Color.unbound.surfaceElevated.opacity(0.88),
                            Color.unbound.bg.opacity(0.66)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(FinisherBladeShape(cutDepth: 18).stroke(tint.opacity(0.24), lineWidth: 1))
        .contentShape(FinisherBladeShape(cutDepth: 18))
        .accessibilityElement(children: .combine)
    }
}

private struct FinisherRoundStack: View {
    let rounds: [Int]
    let activeRound: Int?
    let progress: CGFloat
    let tint: Color
    let isLive: Bool

    private var displayRounds: [Int] {
        rounds.isEmpty ? [21, 15, 9] : rounds
    }

    var body: some View {
        ZStack {
            ForEach(Array(displayRounds.enumerated()), id: \.offset) { offset, round in
                let diameter = CGFloat(150 - (offset * 36))
                let isActive = round == activeRound

                Circle()
                    .trim(from: 0.08, to: ringEnd(offset: offset, isActive: isActive))
                    .stroke(
                        AngularGradient(
                            colors: [
                                tint.opacity(isActive ? 1 : 0.46),
                                Color.unbound.emberGlow.opacity(isActive ? 0.72 : 0.26),
                                tint.opacity(isActive ? 1 : 0.46)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: isActive ? 7 : 4, lineCap: .round)
                    )
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(Double(offset) * -22 + (isLive && isActive ? 12 : 0)))

                Text("\(round)")
                    .font(Font.unbound.monoS.weight(.black))
                    .foregroundStyle(isActive ? Color.unbound.bg : Color.unbound.textPrimary)
                    .monospacedDigit()
                    .frame(width: isActive ? 34 : 28, height: isActive ? 34 : 28)
                    .background(Circle().fill(isActive ? tint : Color.unbound.surfaceElevated))
                    .overlay(Circle().strokeBorder(tint.opacity(isActive ? 0.1 : 0.34), lineWidth: 1))
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(Double(offset) * 18))
            }

            VStack(spacing: 2) {
                Text("\(Int((1 - min(max(progress, 0), 1)) * 100))")
                    .font(Font.unbound.monoL.weight(.black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("LEFT")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(tint)
            }
        }
    }

    private func ringEnd(offset: Int, isActive: Bool) -> CGFloat {
        let base = CGFloat(0.78 - (Double(offset) * 0.08))
        guard isActive else { return base }
        return min(0.96, base + (isLive ? 0.08 : 0))
    }
}

private struct FinisherBladeShape: Shape {
    var cutDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        let cut = min(cutDepth, rect.width * 0.28, rect.height * 0.5)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: cut * 0.36, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct FinisherSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX * 0.54, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.46, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
