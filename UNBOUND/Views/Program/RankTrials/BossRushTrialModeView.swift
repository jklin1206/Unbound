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
