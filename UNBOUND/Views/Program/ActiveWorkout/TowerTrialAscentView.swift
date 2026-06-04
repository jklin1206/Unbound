import SwiftUI

struct TowerTrialAscentView<CurrentFloorCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentFloorCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentFloorCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var towerIsLive = false

    init(
        definition: OverallRankTrialDefinition,
        session: ActiveWorkoutSession,
        @ViewBuilder currentFloorCard: @escaping (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentFloorCard
    ) {
        self.definition = definition
        self.session = session
        self.currentFloorCard = currentFloorCard
    }

    var body: some View {
        RankTrialActiveStageLayout(pair: session.rankTrialCurrentExercisePair) {
            ascentHeader
        } activeContent: { pair in
            towerStage(pair: pair)
            currentFloorCard(pair.index, pair.exercise)
        } completedContent: {
            completedTowerStage
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                towerIsLive = true
            }
        }
    }

    private var ascentHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THE TOWER")
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
                Text("STATIONS")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private func towerStage(pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        HStack(alignment: .center, spacing: 18) {
            TowerAscentMap(
                floors: floorStates,
                progress: stationProgress,
                tint: tint,
                pulse: towerIsLive
            )
            .frame(width: 112, height: 392)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 14) {
                currentFloorHero(pair.exercise)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ascentChip("Floor \(floorNumberString(for: pair.exercise))", icon: "arrow.up")
                        ascentChip("Gate \(pair.index + 1)", icon: "flag.checkered")
                    }

                    Text(pair.exercise.blockTitle ?? pair.exercise.name)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text("\(pair.exercise.plannedSets) x \(pair.exercise.plannedReps) / Rest \(Self.mmss(pair.exercise.restSeconds))")
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tower.ascentStage")
    }

    private func currentFloorHero(_ exercise: ActiveWorkoutSession.ActiveExercise) -> some View {
        ZStack(alignment: .bottomLeading) {
            TowerDoorwayShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.22),
                            Color.unbound.surfaceElevated.opacity(0.84),
                            Color.unbound.bg.opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(TowerDoorwayShape().stroke(tint.opacity(0.42), lineWidth: 1.2))

            if let definition = movementDefinition(for: exercise) {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: fallbackIcon(for: exercise.blockKind))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .trailing, spacing: 8) {
                Text("ALT \(floorNumberString(for: exercise))")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(tint)
                TowerClimbRungRail(progress: stationProgress, tint: tint, pulse: towerIsLive)
                    .frame(width: 76, height: 96)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 16)
            .padding(.trailing, 16)
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                Image(systemName: exercise.hasLoggedRankTrialWorkingSet ? "checkmark.seal.fill" : "figure.stairs")
                    .font(.system(size: 12, weight: .black))
                Text(exercise.hasLoggedRankTrialWorkingSet ? "CLEARED" : "CLIMBING")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
            }
            .foregroundStyle(exercise.hasLoggedRankTrialWorkingSet ? Color.unbound.bg : Color.unbound.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(exercise.hasLoggedRankTrialWorkingSet ? Color.unbound.accent : tint.opacity(0.28)))
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 228)
        .shadow(color: tint.opacity(towerIsLive ? 0.26 : 0.14), radius: towerIsLive ? 26 : 14, y: 10)
    }

    private struct TowerClimbRungRail: View {
        let progress: CGFloat
        let tint: Color
        let pulse: Bool

        private var clampedProgress: CGFloat {
            min(max(progress, 0), 1)
        }

        var body: some View {
            GeometryReader { proxy in
                let rungCount = 7
                let spacing = proxy.size.height / CGFloat(rungCount)

                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: proxy.size.width * 0.22, y: 0))
                        path.addLine(to: CGPoint(x: proxy.size.width * 0.22, y: proxy.size.height))
                        path.move(to: CGPoint(x: proxy.size.width * 0.78, y: 0))
                        path.addLine(to: CGPoint(x: proxy.size.width * 0.78, y: proxy.size.height))
                    }
                    .stroke(tint.opacity(0.24), lineWidth: 1)

                    ForEach(0..<rungCount, id: \.self) { index in
                        let value = CGFloat(index + 1) / CGFloat(rungCount)
                        let y = proxy.size.height - (spacing * (CGFloat(index) + 0.5))
                        Capsule()
                            .fill(value <= clampedProgress ? tint : Color.unbound.surfaceElevated.opacity(0.84))
                            .frame(width: value <= clampedProgress ? proxy.size.width * 0.74 : proxy.size.width * 0.56, height: 5)
                            .overlay(Capsule().strokeBorder(tint.opacity(value <= clampedProgress ? 0.7 : 0.2), lineWidth: 1))
                            .shadow(color: value <= clampedProgress ? tint.opacity(pulse ? 0.34 : 0.12) : .clear, radius: 8)
                            .position(x: proxy.size.width * 0.5, y: y)
                    }
                }
            }
        }
    }

    private var completedTowerStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            TowerAscentMap(
                floors: floorStates,
                progress: 1,
                tint: tint,
                pulse: towerIsLive
            )
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.accent)
                Text("Tower cleared. Finish the trial to record the result.")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .accessibilityIdentifier("tower.completedStage")
    }

    private func ascentChip(_ text: String, icon: String) -> some View {
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

    private var floorStates: [TowerAscentFloor] {
        session.exercises.enumerated().compactMap { index, exercise in
            guard !exercise.skipped else { return nil }
            return TowerAscentFloor(
                id: exercise.id,
                stationIndex: index,
                floorNumber: floorNumber(for: exercise) ?? (index + 1),
                title: exercise.blockTitle ?? exercise.name,
                isCurrent: index == session.currentExerciseIndex,
                isCleared: exercise.hasLoggedRankTrialWorkingSet
            )
        }
    }

    private var currentTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Ascent Complete" }
        return "Floor \(floorNumberString(for: pair.exercise))"
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

    private func floorNumberString(for exercise: ActiveWorkoutSession.ActiveExercise) -> String {
        let value = floorNumber(for: exercise) ?? (session.currentExerciseIndex + 1)
        return value < 10 ? "0\(value)" : "\(value)"
    }

    private func floorNumber(for exercise: ActiveWorkoutSession.ActiveExercise) -> Int? {
        guard let title = exercise.blockTitle else { return nil }
        return Self.floorNumber(from: title)
    }

    private static func floorNumber(from title: String) -> Int? {
        let pieces = title.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        guard let floorIndex = pieces.firstIndex(where: { $0.caseInsensitiveCompare("floor") == .orderedSame }),
              pieces.indices.contains(floorIndex + 1)
        else { return nil }
        return Int(pieces[floorIndex + 1])
    }

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
}

private struct TowerAscentFloor: Identifiable {
    let id: String
    let stationIndex: Int
    let floorNumber: Int
    let title: String
    let isCurrent: Bool
    let isCleared: Bool

    var floorLabel: String {
        floorNumber < 10 ? "0\(floorNumber)" : "\(floorNumber)"
    }

    var isBossFloor: Bool {
        floorNumber >= 10 || title.localizedCaseInsensitiveContains("boss")
    }
}

private struct TowerAscentMap: View {
    let floors: [TowerAscentFloor]
    let progress: CGFloat
    let tint: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            TowerAscentBodyShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.bg.opacity(0.96),
                            Color.unbound.surfaceElevated.opacity(0.9),
                            tint.opacity(0.18)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(TowerAscentBodyShape().stroke(tint.opacity(0.34), lineWidth: 1.2))

            VStack(spacing: 5) {
                ForEach(floors.reversed()) { floor in
                    TowerAscentFloorSlice(floor: floor, tint: tint, pulse: pulse)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)

            GeometryReader { proxy in
                let usableHeight = max(1, proxy.size.height - 46)
                let markerY = proxy.size.height - 23 - (usableHeight * min(max(progress, 0), 1))
                Circle()
                    .fill(tint)
                    .frame(width: pulse ? 14 : 10, height: pulse ? 14 : 10)
                    .shadow(color: tint.opacity(0.65), radius: pulse ? 16 : 8)
                    .position(x: proxy.size.width - 12, y: markerY)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct TowerAscentFloorSlice: View {
    let floor: TowerAscentFloor
    let tint: Color
    let pulse: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(floor.floorLabel)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(labelTint)
                .frame(width: 18, alignment: .leading)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(border, lineWidth: floor.isCurrent ? 1.4 : 1)
                )
                .frame(height: floor.isBossFloor ? 18 : 14)
                .shadow(color: shadow, radius: floor.isCurrent && pulse ? 11 : 0)
        }
    }

    private var fill: Color {
        if floor.isCleared { return Color.unbound.accent.opacity(0.92) }
        if floor.isCurrent { return tint.opacity(pulse ? 0.76 : 0.52) }
        if floor.isBossFloor { return Color.unbound.emberGlow.opacity(0.22) }
        return Color.unbound.bg.opacity(0.74)
    }

    private var border: Color {
        if floor.isCleared { return Color.unbound.accent }
        if floor.isCurrent { return tint.opacity(0.88) }
        if floor.isBossFloor { return Color.unbound.emberGlow.opacity(0.48) }
        return Color.unbound.textPrimary.opacity(0.20)
    }

    private var labelTint: Color {
        if floor.isCleared { return Color.unbound.accent }
        if floor.isCurrent { return tint }
        if floor.isBossFloor { return Color.unbound.emberGlow }
        return Color.unbound.textSecondary
    }

    private var shadow: Color {
        floor.isCurrent ? tint.opacity(0.34) : Color.clear
    }
}

private struct TowerAscentBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * 0.17
        let bottomInset = rect.width * 0.03
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bottomInset, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TowerDoorwayShape: Shape {
    func path(in rect: CGRect) -> Path {
        let capHeight = rect.height * 0.20
        let radius = rect.width * 0.20
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + capHeight))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX + radius, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + capHeight),
            control: CGPoint(x: rect.maxX - radius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
