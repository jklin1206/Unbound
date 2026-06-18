import SwiftUI

struct BossRushTrialReadyPreview: View {
    let blocks: [TrainingBlock]
    let tint: Color

    private var bosses: [BossRushReadyBoss] {
        blocks.enumerated().map { index, block in
            BossRushReadyBoss(index: index, block: block)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            readyHeader

            VStack(spacing: 10) {
                ForEach(bosses) { boss in
                    readyBossRow(boss)
                }
            }
            .accessibilityIdentifier("workoutReady.sevenSealsLadder")
        }
    }

    private var readyHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            BossRushClockFace(
                timeText: "06:00",
                label: "BOSS CLOCK",
                tint: tint,
                pulse: false
            )
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("BOSS RUSH")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(tint)
                Text("\(bosses.count) encounters. Break every HP plate before the clock wins.")
                    .font(Font.unbound.bodyM.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                HStack(spacing: 8) {
                    RankTrialInfoChip(text: "\(bosses.count) bosses", icon: "flame.fill", tint: tint, strokeOpacity: 0.30)
                    RankTrialInfoChip(text: "6 min cap", icon: "timer", tint: tint, strokeOpacity: 0.30)
                }
            }
            .layoutPriority(1)
        }
    }

    private func readyBossRow(_ boss: BossRushReadyBoss) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                BossRushBadgeShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(boss.isFinalBoss ? 0.48 : 0.28),
                                Color.unbound.bg.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(BossRushBadgeShape().stroke(tint.opacity(boss.isFinalBoss ? 0.78 : 0.42), lineWidth: 1.2))

                Text(boss.numberString)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .frame(width: 38, height: 46)
            .accessibilityHidden(true)

            if let definition = boss.movementDefinition {
                ExerciseVisualView(definition: definition, size: .thumbnail)
                    .frame(width: 58, height: 52)
                    .shadow(color: tint.opacity(0.18), radius: 12, y: 5)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: boss.fallbackIcon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 58, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.unbound.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tint.opacity(0.26), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(boss.title.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1)
                        .foregroundStyle(boss.isFinalBoss ? Color.unbound.emberGlow : tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 4)

                    Text(boss.summary)
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                BossRushHPPlate(
                    total: boss.hpPips,
                    filled: boss.hpPips,
                    tint: boss.isFinalBoss ? Color.unbound.emberGlow : tint,
                    pulse: false
                )
                .frame(height: 12)

                Text(boss.exerciseName)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            BossRushRowShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.surfaceElevated.opacity(0.92),
                            tint.opacity(boss.isFinalBoss ? 0.18 : 0.08)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            BossRushRowShape()
                .strokeBorder(tint.opacity(boss.isFinalBoss ? 0.38 : 0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

}

struct BossRushTrialActiveView<CurrentStationCard: View>: View {
    let definition: OverallRankTrialDefinition
    @ObservedObject var session: ActiveWorkoutSession
    let currentStationCard: (Int, ActiveWorkoutSession.ActiveExercise) -> CurrentStationCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rushIsLive = false

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
            bossArena(pair: pair)
            currentStationCard(pair.index, pair.exercise)
        } completedContent: {
            completedRushStage
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                rushIsLive = true
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BOSS RUSH")
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
                Text("\(defeatedBosses)/\(totalBosses)")
                    .font(Font.unbound.monoM.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("DEFEATED")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    private func bossArena(pair: (index: Int, exercise: ActiveWorkoutSession.ActiveExercise)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                BossRushEncounterLadder(
                    bosses: activeBosses,
                    tint: tint,
                    pulse: rushIsLive
                )
                .frame(width: 86, height: 302)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    currentBossHero(pair.exercise)

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            RankTrialInfoChip(
                                text: "Boss \(bossNumberString(for: pair.index))",
                                icon: "flame.fill",
                                tint: tint,
                                background: Color.unbound.bg.opacity(0.68)
                            )
                            RankTrialInfoChip(
                                text: "Rest \(Self.mmss(pair.exercise.restSeconds))",
                                icon: "bolt.heart.fill",
                                tint: tint,
                                background: Color.unbound.bg.opacity(0.68)
                            )
                        }

                        Text(pair.exercise.blockTitle ?? pair.exercise.name)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)

                        HStack(alignment: .center, spacing: 10) {
                            BossRushHPPlate(
                                total: totalWorkingSets(for: pair.exercise),
                                filled: loggedWorkingSets(for: pair.exercise),
                                tint: bossIsDefeated(pair.exercise) ? Color.unbound.accent : tint,
                                pulse: rushIsLive && !bossIsDefeated(pair.exercise)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 16)

                            Text("\(loggedWorkingSets(for: pair.exercise))/\(totalWorkingSets(for: pair.exercise))")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .monospacedDigit()
                        }

                        Text("\(pair.exercise.plannedSets) x \(pair.exercise.plannedReps)")
                            .font(Font.unbound.captionS.weight(.semibold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bossRush.activeArena")
    }

    private func currentBossHero(_ exercise: ActiveWorkoutSession.ActiveExercise) -> some View {
        ZStack(alignment: .bottomLeading) {
            BossRushArenaShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.bg.opacity(0.96),
                            tint.opacity(0.28),
                            Color.unbound.emberGlow.opacity(0.16)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .overlay(BossRushArenaShape().stroke(tint.opacity(rushIsLive ? 0.56 : 0.34), lineWidth: 1.2))

            HStack(alignment: .center, spacing: 12) {
                BossRushLiveClock(
                    startedAt: exercise.startedAt,
                    completedAt: exercise.completedAt,
                    tint: clockTint(for: exercise),
                    pulse: rushIsLive && !bossIsDefeated(exercise)
                )
                .frame(width: 92, height: 92)

                ZStack {
                    if let definition = movementDefinition(for: exercise) {
                        ExerciseVisualView(definition: definition, size: .thumbnail)
                            .padding(10)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: fallbackIcon(for: exercise.blockKind))
                            .font(.system(size: 44, weight: .black))
                            .foregroundStyle(tint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(16)

            VStack(alignment: .leading, spacing: 7) {
                Text("STRIKE LANE")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.textTertiary)
                BossRushStrikeLane(
                    total: totalWorkingSets(for: exercise),
                    filled: loggedWorkingSets(for: exercise),
                    tint: bossIsDefeated(exercise) ? Color.unbound.accent : tint,
                    pulse: rushIsLive && !bossIsDefeated(exercise)
                )
                .frame(height: 14)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                Image(systemName: bossIsDefeated(exercise) ? "checkmark.seal.fill" : "burst.fill")
                    .font(.system(size: 12, weight: .black))
                Text(bossIsDefeated(exercise) ? "DEFEATED" : "ENGAGED")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.3)
            }
            .foregroundStyle(bossIsDefeated(exercise) ? Color.unbound.bg : Color.unbound.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(bossIsDefeated(exercise) ? Color.unbound.accent : Color.unbound.emberGlow.opacity(0.34)))
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 224)
        .shadow(color: tint.opacity(rushIsLive ? 0.28 : 0.14), radius: rushIsLive ? 26 : 14, y: 10)
    }

    private struct BossRushStrikeLane: View {
        let total: Int
        let filled: Int
        let tint: Color
        let pulse: Bool

        var body: some View {
            HStack(spacing: 5) {
                ForEach(0..<max(1, total), id: \.self) { index in
                    let isFilled = index < filled
                    Capsule()
                        .fill(isFilled ? tint : Color.unbound.bg.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .overlay(Capsule().strokeBorder(tint.opacity(isFilled ? 0.76 : 0.26), lineWidth: 1))
                        .shadow(color: isFilled ? tint.opacity(pulse ? 0.34 : 0.12) : .clear, radius: 8)
                }
            }
        }
    }

    private var completedRushStage: some View {
        VStack(alignment: .leading, spacing: 16) {
            BossRushEncounterLadder(
                bosses: activeBosses,
                tint: tint,
                pulse: rushIsLive
            )
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.unbound.accent)
                Text("Boss rush cleared. Finish the trial to record the result.")
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .accessibilityIdentifier("bossRush.completedStage")
    }

    private var currentTitle: String {
        guard let pair = session.rankTrialCurrentExercisePair else { return "Rush Complete" }
        return "Boss \(bossNumberString(for: pair.index))"
    }

    private var activeBosses: [BossRushActiveBoss] {
        session.exercises.enumerated().compactMap { index, exercise in
            guard !exercise.skipped else { return nil }
            return BossRushActiveBoss(
                id: exercise.id,
                stationIndex: index,
                title: exercise.blockTitle ?? exercise.name,
                isCurrent: index == session.currentExerciseIndex,
                isDefeated: bossIsDefeated(exercise),
                totalHP: totalWorkingSets(for: exercise),
                remainingHP: max(0, totalWorkingSets(for: exercise) - loggedWorkingSets(for: exercise))
            )
        }
    }

    private var totalBosses: Int {
        session.rankTrialStationCount
    }

    private var defeatedBosses: Int {
        session.exercises.filter { !$0.skipped && bossIsDefeated($0) }.count
    }

    private var tint: Color {
        definition.targetRank.rewardTextTint
    }

    private func bossIsDefeated(_ exercise: ActiveWorkoutSession.ActiveExercise) -> Bool {
        loggedWorkingSets(for: exercise) >= totalWorkingSets(for: exercise)
    }

    private func loggedWorkingSets(for exercise: ActiveWorkoutSession.ActiveExercise) -> Int {
        exercise.sets.filter { $0.logged && !$0.isWarmup }.count
    }

    private func totalWorkingSets(for exercise: ActiveWorkoutSession.ActiveExercise) -> Int {
        max(1, exercise.sets.filter { !$0.isWarmup }.count)
    }

    private func movementDefinition(for exercise: ActiveWorkoutSession.ActiveExercise) -> MovementDefinition? {
        MovementCatalog.resolvedTrainingMovement(
            name: exercise.name,
            movementId: exercise.movementId,
            rankStandardMovementId: exercise.rankStandardMovementId
        )?.exact
    }

    private func bossNumberString(for index: Int) -> String {
        let number = activeBosses.firstIndex { $0.stationIndex == index }.map { $0 + 1 } ?? (index + 1)
        return number < 10 ? "0\(number)" : "\(number)"
    }

    private func clockTint(for exercise: ActiveWorkoutSession.ActiveExercise) -> Color {
        bossIsDefeated(exercise) ? Color.unbound.accent : Color.unbound.emberGlow
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

private struct BossRushReadyBoss: Identifiable {
    let index: Int
    let block: TrainingBlock

    var id: String { block.id }
    var number: Int { index + 1 }
    var numberString: String { number < 10 ? "0\(number)" : "\(number)" }
    var isFinalBoss: Bool { index == 4 || block.title.localizedCaseInsensitiveContains("final") }

    var title: String {
        block.title
            .replacingOccurrences(of: "Boss \(number) ", with: "")
            .replacingOccurrences(of: "Stage \(number) ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var prescription: TrainingBlockPrescription? {
        block.prescriptions.first
    }

    var exerciseName: String {
        prescription?.exerciseName ?? block.title
    }

    var hpPips: Int {
        min(6, max(2, prescription?.sets ?? 3))
    }

    var summary: String {
        guard let prescription else { return "6:00 cap" }
        var parts = ["\(prescription.sets)x \(prescription.displayTargetText)"]
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
}

private struct BossRushActiveBoss: Identifiable {
    let id: String
    let stationIndex: Int
    let title: String
    let isCurrent: Bool
    let isDefeated: Bool
    let totalHP: Int
    let remainingHP: Int

    var numberString: String {
        let value = stationIndex + 1
        return value < 10 ? "0\(value)" : "\(value)"
    }

    var healthText: String {
        "\(remainingHP)/\(max(1, totalHP))"
    }
}

private struct BossRushLiveClock: View {
    private static let capSeconds = 360

    let startedAt: Date?
    let completedAt: Date?
    let tint: Color
    let pulse: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            BossRushClockFace(
                timeText: timeText(at: context.date),
                label: "CAP",
                tint: tint,
                pulse: pulse
            )
        }
    }

    private func timeText(at now: Date) -> String {
        let anchor = startedAt ?? now
        let end = completedAt ?? now
        let elapsed = Int(end.timeIntervalSince(anchor))
        let remaining = max(0, Self.capSeconds - elapsed)
        return Self.mmss(remaining)
    }

    private static func mmss(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainingSeconds = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct BossRushClockFace: View {
    let timeText: String
    let label: String
    let tint: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(pulse ? 0.34 : 0.24),
                            Color.unbound.surfaceElevated.opacity(0.96),
                            Color.unbound.bg
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 70
                    )
                )
                .overlay(Circle().strokeBorder(tint.opacity(pulse ? 0.76 : 0.46), lineWidth: pulse ? 2 : 1.4))
                .shadow(color: tint.opacity(pulse ? 0.32 : 0.16), radius: pulse ? 18 : 8)

            Circle()
                .trim(from: 0.06, to: 0.94)
                .stroke(tint.opacity(0.56), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [3, 7]))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(timeText)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.70)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct BossRushHPPlate: View {
    let total: Int
    let filled: Int
    let tint: Color
    let pulse: Bool

    private var pipCount: Int { min(6, max(1, total)) }
    private var filledCount: Int { min(pipCount, max(0, filled)) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<pipCount, id: \.self) { index in
                Capsule()
                    .fill(fill(isActive: index < filledCount))
                    .overlay(
                        Capsule()
                            .strokeBorder(index < filledCount ? tint.opacity(0.78) : Color.unbound.textPrimary.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: index < filledCount && pulse ? tint.opacity(0.30) : Color.clear, radius: 8)
            }
        }
    }

    private func fill(isActive: Bool) -> LinearGradient {
        let colors = isActive
            ? [tint.opacity(pulse ? 0.98 : 0.86), Color.unbound.emberGlow.opacity(0.72)]
            : [Color.unbound.bg.opacity(0.72), Color.unbound.surfaceElevated.opacity(0.72)]
        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct BossRushEncounterLadder: View {
    let bosses: [BossRushActiveBoss]
    let tint: Color
    let pulse: Bool

    var body: some View {
        ZStack {
            BossRushSpineShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.bg.opacity(0.96),
                            Color.unbound.surfaceElevated.opacity(0.90),
                            tint.opacity(0.20)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(BossRushSpineShape().stroke(tint.opacity(0.28), lineWidth: 1.2))

            VStack(spacing: 7) {
                ForEach(bosses) { boss in
                    BossRushLadderNode(boss: boss, tint: tint, pulse: pulse)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
        }
    }
}

private struct BossRushLadderNode: View {
    let boss: BossRushActiveBoss
    let tint: Color
    let pulse: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(boss.numberString)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(labelTint)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(border, lineWidth: boss.isCurrent ? 1.4 : 1)
                    )
                    .frame(height: boss.isCurrent ? 18 : 14)
                    .shadow(color: boss.isCurrent && pulse ? tint.opacity(0.36) : Color.clear, radius: 12)

                Text(boss.healthText)
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }
        }
    }

    private var fill: Color {
        if boss.isDefeated { return Color.unbound.accent.opacity(0.92) }
        if boss.isCurrent { return Color.unbound.emberGlow.opacity(pulse ? 0.76 : 0.52) }
        return tint.opacity(0.18)
    }

    private var border: Color {
        if boss.isDefeated { return Color.unbound.accent }
        if boss.isCurrent { return Color.unbound.emberGlow.opacity(0.88) }
        return tint.opacity(0.30)
    }

    private var labelTint: Color {
        if boss.isDefeated { return Color.unbound.accent }
        if boss.isCurrent { return Color.unbound.emberGlow }
        return Color.unbound.textSecondary
    }
}

private struct BossRushRowShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let bevel: CGFloat = min(18, rect.height * 0.34)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + bevel, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 6, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - 6, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bevel, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct BossRushBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bevel = rect.width * 0.22
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bevel))
        path.addLine(to: CGPoint(x: rect.maxX - bevel * 0.4, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bevel * 0.4, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bevel))
        path.closeSubpath()
        return path
    }
}

private struct BossRushArenaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.width * 0.08
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + notch))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + notch))
        path.closeSubpath()
        return path
    }
}

private struct BossRushSpineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topInset = rect.width * 0.18
        let waist = rect.width * 0.08
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - waist, y: rect.minY + rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - waist, y: rect.maxY - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.minX + topInset, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
