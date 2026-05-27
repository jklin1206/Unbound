import SwiftUI

struct PaywallPlaceholderView: View {
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    private var features: [String] {
        [
            L10n.string(.paywallFeatureCustomProgram, defaultValue: "Custom training program"),
            L10n.string(.paywallFeatureNutritionRecovery, defaultValue: "Nutrition and recovery guidance"),
            L10n.string(.paywallFeatureProgressScans, defaultValue: "Progress tracking and re-scans"),
            L10n.string(.paywallFeatureSkillTree, defaultValue: "Skill tree progression"),
            L10n.string(.paywallFeatureSquadsVowsUnlocks, defaultValue: "Squads, proofs, and unlocks")
        ]
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList

                    SubscriptionPackagePicker(
                        placement: AppConstants.Paywall.hardGate,
                        ctaTitle: L10n.string(.paywallSubscribeToUnlock, defaultValue: "Subscribe to unlock"),
                        onPurchased: { dismiss() }
                    )
                    .environmentObject(services)

                    RestorePurchasesButton()
                        .padding(.top, 4)

                    legalLinks

                    #if DEBUG
                    Button {
                        DevFlags.shared.unlockAllFeatures = true
                        dismiss()
                    } label: {
                        Text(L10n.string(.subscriptionLockedDevUnlock, defaultValue: "DEV · Unlock simulator"))
                            .font(Font.unbound.monoS)
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.impact)
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 34)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Color.unbound.accent)
                .shadow(color: Color.unbound.accent.opacity(0.55), radius: 18)

            Text(L10n.string(.paywallUnlockTitle, defaultValue: "Unlock UNBOUND"))
                .font(Font.unbound.displayM)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.string(
                .paywallUnlockSubtitle,
                defaultValue: "Your full training system, progress engine, and crew layer."
            ))
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(spacing: 12) {
            ForEach(features, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                    Text(feature)
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private var legalLinks: some View {
        HStack(spacing: 6) {
            Link(L10n.string(.legalTermsShort, defaultValue: "Terms"), destination: AppConstants.Legal.termsURL)
            Text("/")
                .foregroundStyle(Color.unbound.textTertiary)
            Link(L10n.string(.legalPrivacyShort, defaultValue: "Privacy"), destination: AppConstants.Legal.privacyURL)
        }
        .font(Font.unbound.captionS)
        .foregroundStyle(Color.unbound.textSecondary)
        .padding(.top, 4)
    }
}

#Preview {
    PaywallPlaceholderView()
        .environmentObject(ServiceContainer.mock)
}
