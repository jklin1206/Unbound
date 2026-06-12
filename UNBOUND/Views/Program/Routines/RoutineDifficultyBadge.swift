import SwiftUI
import UIKit

struct RoutineDifficultyBadge: View {
    let tier: SkillTier
    var compact: Bool = false

    private var tint: Color { tier.rewardTextTint }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 14 : 18, height: compact ? 14 : 18)

            Text(tier.displayName.uppercased())
                .font(compact ? Font.unbound.monoS.weight(.heavy) : Font.unbound.captionS.weight(.heavy))
                .tracking(compact ? 1.0 : 1.3)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, compact ? 9 : 11)
        .padding(.vertical, compact ? 6 : 8)
        .background(Capsule().fill(Color.unbound.bg.opacity(compact ? 0.62 : 0.52)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.36), lineWidth: 1))
        .accessibilityLabel("\(tier.displayName) routine difficulty")
    }
}
