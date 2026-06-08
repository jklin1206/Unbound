import SwiftUI

/// Compact entry on Home that surfaces the user's aggregate rank tier and opens
/// the full rank library. Replaces the old Program→RANKS sub-tab.
struct HomeRanksCard: View {
    let aggregateTier: SkillTier
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RANKS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(aggregateTier.displayName)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer(minLength: 0)
                Text("View")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.ranksCard")
    }
}
