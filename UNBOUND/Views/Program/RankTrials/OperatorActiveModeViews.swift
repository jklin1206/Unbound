import SwiftUI

struct OperatorActiveFocusPanel: View {
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
        .accessibilityIdentifier("theCount.activeFocus")
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

struct OperatorActiveLaneBoard: View {
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
        .accessibilityIdentifier("theCount.activeLanes")
    }

    private var clearedCount: Int {
        exercises.filter(OperatorExerciseState.isCleared).count
    }
}

struct OperatorActiveLaneRow: View {
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

struct OperatorCalibrationTrack: View {
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

struct TheCountCompletePanel: View {
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
                    Text("Count complete")
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
        .accessibilityIdentifier("theCount.completePanel")
    }
}
