import SwiftUI

struct OperatorScreenTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scannerIsLive = false

    private var stations: [OperatorReadyStation] {
        blocks.enumerated().map { index, block in
            OperatorReadyStation(index: index, block: block)
        }
    }

    private var totalSets: Int {
        stations.reduce(0) { $0 + max(1, $1.prescription?.sets ?? 1) }
    }

    private var timedStations: Int {
        stations.filter(\.isTimed).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                OperatorReadinessScanner(
                    stations: stations,
                    tint: tint,
                    isLive: scannerIsLive && !reduceMotion
                )
                .frame(width: 128, height: 184)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OPERATOR SCREEN")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.7)
                            .foregroundStyle(tint)
                        Text("Field readiness lanes")
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    HStack(spacing: 8) {
                        OperatorMetricPip(value: "\(stations.count)", label: "LANES", tint: tint)
                        OperatorMetricPip(value: "\(totalSets)", label: "SETS", tint: Color.rewardTeal)
                        OperatorMetricPip(value: "\(timedStations)", label: "TIMED", tint: Color.unbound.coachCyan)
                    }
                }
                .layoutPriority(1)
            }

            OperatorGaugeStrip(stations: stations, tint: tint)

            VStack(spacing: 10) {
                ForEach(stations) { station in
                    OperatorReadyLaneRow(station: station, tint: tint)
                }
            }
            .accessibilityIdentifier("operatorScreen.readyLanes")
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                scannerIsLive = true
            }
        }
    }
}

struct OperatorScreenTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scannerIsLive = false

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
            OperatorActiveFocusPanel(
                definition: definition,
                exercise: pair.exercise,
                stationNumber: pair.index + 1,
                totalStations: totalStations,
                progress: progress,
                tint: tint,
                isLive: scannerIsLive && !reduceMotion
            )

            currentStationCard(pair.index, pair.exercise)

            OperatorActiveLaneBoard(
                exercises: session.exercises,
                currentIndex: session.currentExerciseIndex,
                tint: tint
            )
        } completedContent: {
            OperatorScreenCompletePanel(
                definition: definition,
                tint: tint,
                progress: progress
            )
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                scannerIsLive = true
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(definition.format.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.7)
                    .foregroundStyle(tint)
                Text(currentTitle)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(loggedStations)/\(totalStations)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("LANES CLEAR")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private var currentTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Screen Complete" }
        return "Lane \(OperatorText.twoDigit(pair.index + 1))"
    }

    private var totalStations: Int {
        session.rankTrialStationCount
    }

    private var loggedStations: Int {
        session.rankTrialLoggedStationCount { $0.hasLoggedRankTrialWorkingSet }
    }

    private var progress: CGFloat {
        session.rankTrialProgress(loggedStations: loggedStations)
    }

    private var tint: Color {
        definition.targetRank.rewardTextTint
    }
}

private struct OperatorReadyStation: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var laneNumber: Int { index + 1 }
    var laneLabel: String { OperatorText.twoDigit(laneNumber) }

    var prescription: TrainingBlockPrescription? {
        block.prescriptions.first
    }

    var title: String {
        block.title
            .replacingOccurrences(of: "Station \(laneNumber) ", with: "")
            .replacingOccurrences(of: "Lane \(laneNumber) ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var exerciseName: String {
        prescription?.exerciseName ?? title
    }

    var targetText: String {
        guard let prescription else { return "Official lane" }
        return "\(prescription.sets)x \(prescription.displayTargetText)"
    }

    var restText: String {
        guard let seconds = prescription?.restSeconds, seconds > 0 else { return "Reset on command" }
        return "\(OperatorText.mmss(seconds)) reset"
    }

    var movementDefinition: MovementDefinition? {
        guard let prescription else { return nil }
        return MovementCatalog.resolvedTrainingMovement(
            name: prescription.exerciseName,
            movementId: prescription.movementId,
            rankStandardMovementId: prescription.rankStandardMovementId
        )?.exact
    }

    var metricKind: TrainingMetricKind? {
        prescription?.target.metricKind
    }

    var isTimed: Bool {
        switch metricKind {
        case .holdSeconds, .durationSeconds, .distanceMeters, .calories:
            return true
        case .reps, .none:
            return false
        }
    }

    var gaugeValue: Double {
        let base = Double(min(1.0, 0.34 + (Double(index + 1) * 0.13)))
        return isTimed ? min(1.0, base + 0.12) : base
    }

    var fallbackIcon: String {
        OperatorIcon.icon(for: block.kind)
    }
}

private struct OperatorReadinessScanner: View {
    let stations: [OperatorReadyStation]
    let tint: Color
    let isLive: Bool

    var body: some View {
        ZStack {
            OperatorScannerShell()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surface.opacity(0.98),
                            Color.unbound.bg.opacity(0.92),
                            tint.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(OperatorScannerShell().stroke(tint.opacity(0.38), lineWidth: 1.2))

            VStack(spacing: 8) {
                Text("CAL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(tint)

                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(tint.opacity(index == 0 ? 0.56 : 0.2), lineWidth: index == 0 ? 1.4 : 1)
                            .scaleEffect(0.42 + CGFloat(index) * 0.28)
                    }

                    ForEach(Array(stations.prefix(6).enumerated()), id: \.element.id) { offset, station in
                        Circle()
                            .fill(scannerDotColor(for: station))
                            .frame(width: station.isTimed ? 8 : 6, height: station.isTimed ? 8 : 6)
                            .offset(dotOffset(offset: offset, count: min(stations.count, 6)))
                    }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, tint.opacity(isLive ? 0.78 : 0.24), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 2, height: 90)
                        .rotationEffect(.degrees(isLive ? 28 : -34))
                        .shadow(color: tint.opacity(isLive ? 0.45 : 0.15), radius: 12)
                }
                .frame(height: 112)

                HStack(spacing: 4) {
                    ForEach(0..<max(1, min(stations.count, 8)), id: \.self) { index in
                        Capsule()
                            .fill(index % 3 == 0 ? Color.rewardTeal.opacity(0.85) : tint.opacity(0.42))
                            .frame(width: index % 3 == 0 ? 14 : 8, height: 3)
                    }
                }
            }
            .padding(.vertical, 14)
        }
    }

    private func scannerDotColor(for station: OperatorReadyStation) -> Color {
        station.isTimed ? Color.unbound.coachCyan : tint
    }

    private func dotOffset(offset: Int, count: Int) -> CGSize {
        let angle = (Double(offset) / Double(max(1, count))) * Double.pi * 2 - Double.pi / 2
        let radius: Double = offset.isMultiple(of: 2) ? 34 : 22
        return CGSize(width: CGFloat(cos(angle) * radius), height: CGFloat(sin(angle) * radius))
    }
}

private struct OperatorGaugeStrip: View {
    let stations: [OperatorReadyStation]
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            OperatorReadinessGauge(
                value: readinessScore,
                label: "READINESS",
                tint: tint,
                icon: "scope"
            )
            OperatorReadinessGauge(
                value: timedScore,
                label: "CLOCK",
                tint: Color.unbound.coachCyan,
                icon: "timer"
            )
            OperatorReadinessGauge(
                value: spreadScore,
                label: "LANES",
                tint: Color.rewardTeal,
                icon: "rectangle.split.3x1"
            )
        }
    }

    private var readinessScore: Double {
        guard !stations.isEmpty else { return 0.2 }
        return min(1.0, 0.42 + Double(stations.count) * 0.08)
    }

    private var timedScore: Double {
        guard !stations.isEmpty else { return 0.18 }
        return min(1.0, 0.24 + Double(stations.filter(\.isTimed).count) / Double(stations.count))
    }

    private var spreadScore: Double {
        min(1.0, 0.32 + Double(Set(stations.compactMap(\.metricKind)).count) * 0.18)
    }
}

private struct OperatorReadinessGauge: View {
    let value: Double
    let label: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(tint)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.bg.opacity(0.9))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.72), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(min(max(value, 0), 1))))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct OperatorReadyLaneRow: View {
    let station: OperatorReadyStation
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            OperatorLaneBeacon(label: station.laneLabel, tint: station.isTimed ? Color.unbound.coachCyan : tint)
                .frame(width: 42, height: 58)

            if let definition = station.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 56, height: 50)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: station.fallbackIcon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(station.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1)
                    .foregroundStyle(station.isTimed ? Color.unbound.coachCyan : tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(station.exerciseName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(station.targetText) / \(station.restText)")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            OperatorLaneMicroGauge(value: station.gaugeValue, tint: station.isTimed ? Color.unbound.coachCyan : tint)
                .frame(width: 24, height: 48)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            OperatorLanePlateShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surface.opacity(0.98),
                            Color.unbound.surfaceElevated.opacity(0.86)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(OperatorLanePlateShape().stroke((station.isTimed ? Color.unbound.coachCyan : tint).opacity(0.26), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct OperatorMetricPip: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(width: 58, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct OperatorActiveFocusPanel: View {
    let definition: OverallRankTrialDefinition
    let exercise: ActiveWorkoutSession.ActiveExercise
    let stationNumber: Int
    let totalStations: Int
    let progress: CGFloat
    let tint: Color
    let isLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    OperatorFocusViewportShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.2),
                                    Color.unbound.surfaceElevated.opacity(0.92),
                                    Color.unbound.bg.opacity(0.96)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(OperatorFocusViewportShape().stroke(tint.opacity(isLive ? 0.5 : 0.32), lineWidth: 1.2))

                    if let definition = movementDefinition {
                        ExerciseVisualView(definition: definition, size: .thumbnail)
                            .padding(14)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: OperatorIcon.icon(for: exercise.blockKind))
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(tint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityHidden(true)
                    }

                    OperatorSweepLine(tint: tint, isLive: isLive)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
                .frame(width: 132, height: 152)
                .shadow(color: tint.opacity(isLive ? 0.26 : 0.12), radius: isLive ? 24 : 12, y: 10)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        OperatorStatusChip(text: "Lane \(OperatorText.twoDigit(stationNumber))", icon: "scope", tint: tint)
                        OperatorStatusChip(text: "\(totalStations) total", icon: "rectangle.split.3x1", tint: Color.rewardTeal)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(exercise.blockTitle ?? exercise.name)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                        Text(exercise.name)
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    HStack(spacing: 8) {
                        OperatorMetricPip(value: "\(exercise.plannedSets)", label: "SETS", tint: tint)
                        OperatorMetricPip(value: exercise.plannedReps, label: metricLabel, tint: Color.unbound.coachCyan)
                    }
                }
                .layoutPriority(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.surfaceElevated).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [Color.rewardTeal, tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)

            OperatorCalibrationTrack(
                stationNumber: stationNumber,
                totalStations: totalStations,
                progress: progress,
                tint: tint,
                isLive: isLive
            )
            .frame(height: 58)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("operatorScreen.activeFocus")
    }

    private var movementDefinition: MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private var metricLabel: String {
        switch exercise.metricKind {
        case .reps: return "TARGET"
        case .holdSeconds: return "HOLD"
        case .durationSeconds: return "CLOCK"
        case .distanceMeters: return "DIST"
        case .calories: return "CAL"
        }
    }
}

private struct OperatorActiveLaneBoard: View {
    let exercises: [ActiveWorkoutSession.ActiveExercise]
    let currentIndex: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LANE BOARD")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(clearedCount)/\(max(1, exercises.filter { !$0.skipped }.count))")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    if !exercise.skipped {
                        OperatorActiveLaneRow(
                            index: index,
                            exercise: exercise,
                            isCurrent: index == currentIndex,
                            tint: tint
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("operatorScreen.activeLanes")
    }

    private var clearedCount: Int {
        exercises.filter(OperatorExerciseState.isCleared).count
    }
}

private struct OperatorActiveLaneRow: View {
    let index: Int
    let exercise: ActiveWorkoutSession.ActiveExercise
    let isCurrent: Bool
    let tint: Color

    private var isCleared: Bool {
        OperatorExerciseState.isCleared(exercise)
    }

    var body: some View {
        HStack(spacing: 10) {
            OperatorLaneBeacon(
                label: OperatorText.twoDigit(index + 1),
                tint: laneTint,
                filled: isCleared
            )
            .frame(width: 40, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.blockTitle ?? exercise.name)
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .foregroundStyle(isCurrent ? laneTint : Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("\(exercise.plannedSets)x \(exercise.plannedReps) / Rest \(OperatorText.mmss(exercise.restSeconds))")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            HStack(spacing: 5) {
                Image(systemName: statusIcon)
                    .font(.system(size: 12, weight: .black))
                Text(statusText)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1)
            }
            .foregroundStyle(isCleared ? Color.unbound.bg : Color.unbound.textPrimary)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(Capsule().fill(isCleared ? Color.rewardTeal : laneTint.opacity(isCurrent ? 0.26 : 0.14)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            OperatorLanePlateShape()
                .fill(Color.unbound.surface.opacity(isCurrent ? 1 : 0.84))
        )
        .overlay(
            OperatorLanePlateShape()
                .stroke(laneTint.opacity(isCurrent ? 0.5 : 0.2), lineWidth: isCurrent ? 1.2 : 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var laneTint: Color {
        if isCleared { return Color.rewardTeal }
        if isCurrent { return tint }
        return Color.unbound.coachCyan
    }

    private var statusIcon: String {
        if isCleared { return "checkmark.seal.fill" }
        return isCurrent ? "scope" : "circle.dashed"
    }

    private var statusText: String {
        if isCleared { return "CLEAR" }
        return isCurrent ? "LIVE" : "STAGED"
    }
}

private struct OperatorCalibrationTrack: View {
    let stationNumber: Int
    let totalStations: Int
    let progress: CGFloat
    let tint: Color
    let isLive: Bool

    private var visibleSlots: Int {
        max(1, min(totalStations, 7))
    }

    private var activeSlot: Int {
        min(max(0, stationNumber - 1), visibleSlots - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CALIBRATION TRACK")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 8)
                Text("LANE \(OperatorText.twoDigit(stationNumber))")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                let slotWidth = width / CGFloat(max(1, visibleSlots))
                let sweepX = min(width - 6, max(6, width * min(max(progress, 0), 1)))

                ZStack(alignment: .leading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height * 0.52))
                        path.addLine(to: CGPoint(x: width, y: proxy.size.height * 0.52))
                    }
                    .stroke(tint.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                    ForEach(0..<visibleSlots, id: \.self) { index in
                        let centerX = slotWidth * (CGFloat(index) + 0.5)
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(index < activeSlot ? Color.rewardTeal : (index == activeSlot ? tint : Color.unbound.surfaceElevated))
                                .frame(width: index == activeSlot ? 28 : 18, height: index == activeSlot ? 9 : 6)
                                .shadow(color: index == activeSlot ? tint.opacity(isLive ? 0.42 : 0.18) : .clear, radius: isLive ? 10 : 4)
                            Text(OperatorText.twoDigit(index + 1))
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(index == activeSlot ? tint : Color.unbound.textTertiary)
                        }
                        .position(x: centerX, y: proxy.size.height * 0.54)
                    }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, tint.opacity(isLive ? 0.92 : 0.45), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 34, height: proxy.size.height)
                        .position(x: sweepX, y: proxy.size.height * 0.5)
                        .blendMode(.screen)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct OperatorScreenCompletePanel: View {
    let definition: OverallRankTrialDefinition
    let tint: Color
    let progress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.28), lineWidth: 1.2)
                    Circle()
                        .trim(from: 0, to: max(0.08, progress))
                        .stroke(Color.rewardTeal, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Color.rewardTeal)
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text(definition.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(tint)
                    Text("Screen complete")
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("Finish the trial to record the result.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            OperatorLanePlateShape()
                .fill(Color.unbound.surface)
        )
        .overlay(
            OperatorLanePlateShape()
                .stroke(Color.rewardTeal.opacity(0.34), lineWidth: 1)
        )
        .accessibilityIdentifier("operatorScreen.completePanel")
    }
}

private struct OperatorLaneBeacon: View {
    let label: String
    let tint: Color
    var filled: Bool = false

    var body: some View {
        ZStack {
            OperatorBeaconShape()
                .fill(filled ? tint : Color.unbound.bg.opacity(0.82))
            OperatorBeaconShape()
                .stroke(tint.opacity(0.72), lineWidth: 1.2)

            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(filled ? Color.unbound.bg : Color.unbound.textPrimary)
                    .monospacedDigit()
                Capsule()
                    .fill(filled ? Color.unbound.bg.opacity(0.8) : tint)
                    .frame(width: 16, height: 3)
            }
        }
    }
}

private struct OperatorLaneMicroGauge: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.unbound.bg.opacity(0.9))
                    .frame(width: 6)
                Capsule()
                    .fill(tint)
                    .frame(width: 6, height: max(6, proxy.size.height * CGFloat(min(max(value, 0), 1))))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct OperatorStatusChip: View {
    let text: String
    let icon: String
    let tint: Color

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

private struct OperatorSweepLine: View {
    let tint: Color
    let isLive: Bool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<9, id: \.self) { index in
                Capsule()
                    .fill(index == 4 ? tint : tint.opacity(0.25))
                    .frame(width: index == 4 ? 22 : 8, height: 3)
            }
        }
        .opacity(isLive ? 1 : 0.58)
    }
}

private enum OperatorExerciseState {
    static func isCleared(_ exercise: ActiveWorkoutSession.ActiveExercise) -> Bool {
        exercise.sets.contains { $0.logged && !$0.isWarmup }
    }
}

private enum OperatorIcon {
    static func icon(for blockKind: TrainingBlockKind) -> String {
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

private enum OperatorText {
    static func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct OperatorScannerShell: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut: CGFloat = min(rect.width, rect.height) * 0.12
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut * 1.4))
        path.addLine(to: CGPoint(x: rect.maxX - cut * 1.4, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut * 0.7, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut * 0.7))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct OperatorLanePlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut: CGFloat = min(18, rect.height * 0.28)
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

private struct OperatorBeaconShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cut = rect.width * 0.18
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY + rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.minY + rect.height * 0.2))
        path.closeSubpath()
        return path
    }
}

private struct OperatorFocusViewportShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch: CGFloat = min(rect.width, rect.height) * 0.16
        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + notch))
        path.closeSubpath()
        return path
    }
}
