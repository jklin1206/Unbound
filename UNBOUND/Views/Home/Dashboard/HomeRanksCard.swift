import SwiftUI

/// Compact Home row that surfaces the user's aggregate rank tier and opens the
/// full rank library.
struct HomeRanksRow: View {
    let aggregateTier: SkillTier
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            UnboundNativeRowButton(
                systemImage: "seal.fill",
                eyebrow: "Ranks",
                title: aggregateTier.displayName,
                detail: "Open the rank library",
                tint: aggregateTier.rewardTextTint,
                action: onOpen
            )

            UnboundNativeDivider(opacity: 0.42)
        }
        .accessibilityIdentifier("home.ranksRow")
    }
}
