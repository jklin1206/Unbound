import SwiftUI
import UIKit

struct RankPulseRings: View {
    let tint: Color
    let hot: Bool
    let animate: Bool

    var body: some View {
        ZStack {
            Hexagon()
                .stroke(tint.opacity(0.18), lineWidth: 2)
                .frame(width: 116, height: 116)
                .scaleEffect(animate ? 1.10 : 0.86)
                .opacity(animate ? 0.92 : 0.34)
            Hexagon()
                .stroke(tint.opacity(hot ? 0.72 : 0.46), lineWidth: hot ? 2.2 : 1.5)
                .frame(width: 92, height: 92)
                .shadow(color: tint.opacity(hot ? 0.58 : 0.22), radius: hot ? 24 : 10)
            if hot {
                Hexagon()
                    .stroke(tint.opacity(animate ? 0.0 : 0.68), lineWidth: 1.4)
                    .frame(width: 92, height: 92)
                    .scaleEffect(animate ? 1.42 : 0.86)
            }
        }
        .animation(.easeOut(duration: 0.9), value: animate)
    }
}

struct LevelUpChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(Font.unbound.captionS.weight(.black))
            .tracking(1.4)
            .foregroundStyle(Color.unbound.bg)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint, in: Capsule())
            .shadow(color: tint.opacity(0.40), radius: 10)
    }
}

struct AttributeLevelProgressRow: View {
    let delta: AttributeDeltaReward
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(delta.key.shortCode) LVL \(delta.currentLevel)")
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("CURRENT RANK \(delta.currentTier.displayName.uppercased())")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(delta.currentTier.rewardTextTint.opacity(0.95))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(formatWhole(delta.xpGained)) XP")
                        .font(Font.unbound.monoM.weight(.black))
                        .foregroundStyle(delta.tint)
                    Text(levelText)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.1)
                        .foregroundStyle(delta.didIncreaseLevel ? delta.tint : Color.unbound.textTertiary)
                }
            }

            RPGStatBar(
                from: delta.levelProgressStart,
                to: delta.currentProgress,
                tint: delta.tint,
                animate: animate,
                height: 18,
                segments: 8,
                showOriginCap: false
            )

            HStack {
                Text("\(formatWhole(delta.xpIntoCurrentLevel)) / \(formatWhole(delta.xpNeededForCurrentLevel)) XP")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(formatWhole(delta.xpRemainingInLevel)) XP TO NEXT")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.0)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .padding(.vertical, 9)
        .overlay(Rectangle().fill(Color.unbound.textPrimary.opacity(0.08)).frame(height: 1), alignment: .bottom)
    }

    private var levelText: String {
        delta.didIncreaseLevel ? "LVL \(delta.previousLevel) -> \(delta.currentLevel)" : "TO NEXT"
    }
}

struct MovementXPProgressRow: View {
    let line: ProgressionMovementLine
    let tint: Color
    let animate: Bool

    private var rowTint: Color { line.didRankUp ? Color.unbound.rankGold : tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .tracking(0.5)
                        .foregroundStyle(Color.unbound.textPrimary)
                    if let rank = line.currentRank {
                        Text(line.didRankUp ? "RANK UP → \(rank.displayName.uppercased())" : "RANK \(rank.displayName.uppercased())")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.1)
                            .foregroundStyle(line.didRankUp ? rowTint : Color.unbound.textTertiary)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(formatWhole(line.xpGained)) XP")
                        .font(Font.unbound.monoM.weight(.black))
                        .foregroundStyle(rowTint)
                    if line.currentRank != nil {
                        Text(toNextLabel)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                }
            }

            if line.currentRank != nil, line.nextRank != nil {
                RPGStatBar(
                    from: line.didRankUp ? 0 : line.fractionToNextRank,
                    to: line.fractionToNextRank,
                    tint: rowTint,
                    animate: animate,
                    height: 16,
                    segments: 5,
                    showOriginCap: false
                )
            }
        }
    }

    private var toNextLabel: String {
        guard let next = line.nextRank else { return "MAXED" }
        return "\(Int((line.fractionToNextRank * 100).rounded()))% → \(next.displayName.uppercased())"
    }
}

struct ReceiptTotalRow: View {
    let label: String
    let value: String
    let tint: Color
    let show: Bool

    var body: some View {
        if show {
            HStack {
                Text(label.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .allowsTightening(true)
                Spacer()
                Text(value.uppercased())
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

/// XP fill — a clean dimensional energy gradient with top gloss while it grows,
/// then a single specular shimmer that sweeps across once the bar reaches the end
/// (the flourish lands at completion, not continuously during the fill).
