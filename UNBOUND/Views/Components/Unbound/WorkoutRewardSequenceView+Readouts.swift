import SwiftUI
import UIKit

extension WorkoutRewardSequenceView {
    var weightUnit: TrainingWeightUnit {
        TrainingWeightUnit(rawValue: weightUnitRaw) ?? .localeDefault
    }

    var volumeText: String {
        WeightPlatePolicy.formatVolume(summary.volumeKg, unit: weightUnit)
    }

    var dominantLiftTint: Color {
        summary.liftProgress.first(where: \.didAdvanceTier)?.toTier.rewardTint ?? summary.liftProgress.first?.toTier.rewardTint ?? Color.rewardBlue
    }

    var proofTint: Color {
        if summary.tally.ranksAdvanced > 0 || summary.emblemIgnition {
            return Color.unbound.rankGold
        }
        if summary.tally.unlocksGained > 0 {
            return Color.unbound.impact
        }
        return Color.unbound.coachCyan
    }

    // The reward hex shows progress toward the next level (moves a lot per
    // session), not the absolute level/100 (that's the profile's job).
    var previousAttributeMap: [AttributeKey: Double] {
        if !summary.attributePreviousHexValues.isEmpty {
            return summary.attributePreviousHexValues
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.levelProgressStart * 100) })
    }

    var currentAttributeMap: [AttributeKey: Double] {
        if !summary.attributeCurrentHexValues.isEmpty {
            return summary.attributeCurrentHexValues
        }
        return Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.currentProgress * 100) })
    }


    var previousAttributeLevels: [AttributeKey: Int]? {
        summary.attributePreviousLevels.isEmpty ? nil : summary.attributePreviousLevels
    }

    var currentAttributeLevels: [AttributeKey: Int]? {
        summary.attributeLevels.isEmpty ? nil : summary.attributeLevels
    }

    var previousAttributeTiers: [AttributeKey: RankTitle]? {
        let tiers = !summary.attributePreviousTiers.isEmpty
            ? summary.attributePreviousTiers
            : Dictionary(uniqueKeysWithValues: summary.attributeDeltas.map { ($0.key, $0.previousTier) })
        return tiers.isEmpty ? nil : tiers
    }

    var currentAttributeTiers: [AttributeKey: RankTitle]? {
        summary.attributeTiers.isEmpty ? nil : summary.attributeTiers
    }

    var primaryAttributeDelta: AttributeDeltaReward? {
        summary.attributeDeltas.first(where: { $0.didAdvanceTier || $0.didIncreaseLevel })
            ?? summary.attributeDeltas.first
    }

    func attributeDeltaText(_ delta: AttributeDeltaReward) -> String {
        "+\(formatReceiptNumber(delta.xpGained)) XP"
    }

    func readout(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Font.unbound.monoM.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(label)
                .font(Font.unbound.captionS)
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    func beatHeader(kicker: String, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.0)
                .foregroundStyle(tint)
            Text(title)
                .font(Font.unbound.titleM)
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }

    func rewardLine(label: String, value: String, tint: Color) -> some View {
        HStack {
            Text(label.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
            Spacer()
            Text(value.uppercased())
                .font(Font.unbound.monoS.weight(.heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.60)
                .allowsTightening(true)
                .multilineTextAlignment(.trailing)
        }
    }

    func progressionMiniSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.unbound.borderSubtle)
                .frame(height: 1)
            Text(title.uppercased())
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
            content()
        }
    }

    func formatReceiptNumber(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    func weeklyVowShareChip(_ callout: WeeklyVowRewardCallout) -> some View {
        let tint = callout.theme.tintColor
        let chipTitle = callout.completionBonus?.shareCard?.title ?? callout.shareTitle
        return HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .black))
            VStack(alignment: .leading, spacing: 2) {
                Text(chipTitle.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.5)
                Text(callout.receiptLine.uppercased())
                    .font(Font.unbound.captionS)
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.42), lineWidth: 1))
    }

    func yieldToken(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .allowsTightening(true)
            Text(label)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
    }

    func arcYieldToken(amount: Int) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .center, spacing: 4) {
                Text("+\(ArcCurrencyAmount.compactText(for: max(0, amount)))")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.rankGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .allowsTightening(true)

                Image("shop_currency_arc")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .shadow(color: Color.unbound.rankGold.opacity(0.28), radius: 5)
                    .accessibilityHidden(true)
            }

            Text("ARCS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount.formatted()) Arcs earned")
    }

}
