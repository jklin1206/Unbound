import SwiftUI

// MARK: - PromoExitSheet
//
// Exit-intent offer. Surfaced when a user hesitates on the hard paywall instead
// of subscribing. Presents the discounted annual (`promo` RevenueCat offering).
// The saving is computed live from the promo price against the standard annual
// anchor, so the "X% OFF" badge and struck-through anchor appear only when the
// discount is real and in a believable range; otherwise the offer degrades to
// honest, non-numeric copy. Declining returns to the paywall.
//
// Deliberately spare: the struck price is the message. No framing paragraphs.

struct PromoExitSheet: View {
    /// Called after a successful purchase so the caller can advance past the gate.
    let onUnlock: () -> Void
    var placement: String = "promo_exit"

    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @State private var promo: SubscriptionPackage?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var message: String?
    @State private var glow = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                closeBar
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
        .task { await load() }
        .onAppear {
            glow = true
            services.analytics.track(.paywallViewed(placement: placement))
        }
        .animation(.easeInOut(duration: 0.2), value: message)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().tint(Color.unbound.accent).padding(.vertical, 60)
        } else if let promo {
            VStack(spacing: 30) {
                header(promo)
                offerCard(promo)
                cta(promo)
            }
        } else {
            unavailable
        }
    }

    /// Badge line: the honest computed saving when there is one, else a
    /// non-numeric fallback that never overstates the offer.
    private func badgeText(_ package: SubscriptionPackage) -> String {
        if let percent = package.discountPercent {
            return "\(percent)% OFF"
        }
        return "LIMITED-TIME OFFER"
    }

    private func header(_ package: SubscriptionPackage) -> some View {
        VStack(spacing: 14) {
            Text(badgeText(package))
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(3.0)
                .foregroundStyle(Color.unbound.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.6)))
                .overlay(Capsule().strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1))

            Text("One year for \(package.price).")
                .font(Font.unbound.titleL)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 6)
                .shadow(color: Color.unbound.accent.opacity(0.3), radius: 16)
        }
    }

    private func offerCard(_ package: SubscriptionPackage) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if package.discountPercent != nil, let anchor = package.anchorPrice {
                    Text(anchor)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .strikethrough(true, color: Color.unbound.textTertiary)
                }
                Text(package.price)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .shadow(color: Color.unbound.accent.opacity(0.4), radius: 16)
            }

            Text(package.pricePerMonth.map { "per year · \($0)/mo" } ?? "per year")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.68))
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: Color.unbound.accent.opacity(glow ? 0.30 : 0.12), radius: 22)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glow)
    }

    private func cta(_ package: SubscriptionPackage) -> some View {
        VStack(spacing: 12) {
            UnboundButton(
                title: isPurchasing ? "Opening checkout..." : "Claim \(package.price)/year",
                variant: .prominent,
                icon: "crown.fill",
                action: { Task { await purchase(package) } }
            )
            .disabled(isPurchasing)

            if let message {
                Text(message)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Button {
                UnboundHaptics.soft()
                services.analytics.track(.paywallDismissed(placement: placement))
                dismiss()
            } label: {
                Text("No thanks")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            .buttonStyle(.plain)

            // App Review (3.1.2): a direct-purchase surface needs Restore,
            // the auto-renew disclosure, and functional Terms + Privacy links.
            RestorePurchasesButton(onRestored: onUnlock)

            Text("Auto-renews yearly at \(package.price) unless canceled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple ID settings.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 4)

            HStack(spacing: 12) {
                Link("Terms of Use", destination: AppConstants.Legal.termsURL)
                Text("·")
                Link("Privacy Policy", destination: AppConstants.Legal.privacyURL)
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var unavailable: some View {
        VStack(spacing: 12) {
            Text("This offer isn't available right now.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
            Button("Back") { dismiss() }
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.accent)
        }
        .padding(.vertical, 30)
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button {
                UnboundHaptics.soft()
                services.analytics.track(.paywallDismissed(placement: placement))
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.unbound.surface.opacity(0.8)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    private var background: some View {
        OnboardingBackdrop(image: "promo_locked_door", top: 0.42, middle: 0.1, bottom: 0.82, glow: false)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        promo = (try? await services.subscription.fetchPromoOffering())?.first
    }

    private func purchase(_ package: SubscriptionPackage) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        services.analytics.track(.paywallPresented(placement: placement))
        do {
            let outcome = try await services.subscription.purchase(
                packageId: package.id,
                fromOffering: package.sourceOfferingId ?? AppConstants.RevenueCat.promoOfferingKey
            )
            switch outcome {
            case .purchased:
                services.analytics.track(.paywallConverted(placement: placement, productId: package.productId))
                UnboundHaptics.success()
                onUnlock()
                dismiss()
            case .userCancelled:
                // Backing out of the payment sheet is a choice, not a failure:
                // show nothing and leave the offer on screen.
                message = nil
            case .notEntitled:
                message = "Purchase was not completed."
            }
        } catch {
            message = "Purchase failed. Please try again."
        }
    }
}
