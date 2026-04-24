import SwiftUI

// MARK: - Step_Paywall
//
// Hard paywall. Blurred full-protocol preview behind, unlock CTA in front.
//
// Two pricing tiers: weekly (highlighted) + annual (best value). 7-day free
// trial. Superwall wiring comes when we swap the stub `purchase()` with a
// real RevenueCat call — Day 2+ integration work.

struct Step_Paywall: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onUnlock: () -> Void

    @State private var selectedPlan: PricingPlan = .annual
    @State private var hasAnimated = false
    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            // Blurred protocol preview behind
            ProtocolPreviewBackdrop()
                .blur(radius: 22)
                .overlay(Color.unbound.bg.opacity(0.55))
                .ignoresSafeArea()

            // Violet vignette
            RadialGradient(
                colors: [Color.unbound.accent.opacity(0.25), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    header
                    benefits
                    pricingPlans
                    ctaSection

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .opacity(hasAnimated ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { hasAnimated = true }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 12) {
            RankBadge(letter: flow.derivedRank, size: .medium)

            Text("Start your arc.")
                .font(Font.unbound.displayM)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)

            Text("Every rep tracked. Every node earned. Every milestone yours.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("Your adaptive protocol — three arcs, tailored to you")
            benefitRow("Full skill tree: muscle-up, front lever, the whole ladder")
            benefitRow("Rescan anytime — watch the arc move")
            benefitRow("Daily sessions, streaks, and Gains logged forever")
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text(text)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer()
        }
    }

    // MARK: Pricing

    private var pricingPlans: some View {
        VStack(spacing: 12) {
            pricingCard(plan: .weekly)
            pricingCard(plan: .annual)
        }
    }

    private func pricingCard(plan: PricingPlan) -> some View {
        let isSelected = selectedPlan == plan
        return Button(action: {
            UnboundHaptics.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedPlan = plan
            }
        }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(Font.unbound.captionS)
                                .tracking(1.2)
                                .foregroundStyle(Color.unbound.impact)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .overlay(
                                    Capsule().strokeBorder(Color.unbound.impact.opacity(0.6), lineWidth: 1)
                                )
                        }
                    }
                    Text(plan.subtitle)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer()
                Text(plan.price)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent : Color.unbound.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? Color.unbound.accent.opacity(0.35) : .clear,
                radius: 14, x: 0, y: 0
            )
            .scaleEffect(isSelected ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: CTA

    private var ctaSection: some View {
        VStack(spacing: 8) {
            UnboundButton(
                title: "Start the arc — 7 days free",
                icon: "flame.fill",
                action: purchase
            )
            Text("Cancel anytime. \(selectedPlan.billingAfterTrial) after trial.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .multilineTextAlignment(.center)

            // Skip for Day 1 — real paywall will use Superwall
            Button(action: onUnlock) {
                Text("Continue with limited access")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private func purchase() {
        // Day 1 stub — unlocks immediately. Day 2+ wires real RevenueCat +
        // Superwall purchase flow with proper offering/package selection.
        Task {
            _ = try? await services.subscription.purchase(packageId: selectedPlan.productId)
            onUnlock()
        }
    }
}

// MARK: - PricingPlan

private enum PricingPlan {
    case weekly, annual

    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .annual: return "Annual"
        }
    }

    var subtitle: String {
        switch self {
        case .weekly: return "Flexible. Most popular."
        case .annual: return "Save 80%. Commit to the transformation."
        }
    }

    var price: String {
        switch self {
        case .weekly: return "$9.99 / wk"
        case .annual: return "$49.99 / yr"
        }
    }

    var badge: String? {
        switch self {
        case .annual: return "BEST VALUE"
        default: return nil
        }
    }

    var billingAfterTrial: String {
        switch self {
        case .weekly: return "$9.99 / week"
        case .annual: return "$49.99 / year ($0.96 / week)"
        }
    }

    var productId: String {
        switch self {
        case .weekly: return "unbound.weekly"
        case .annual: return "unbound.annual"
        }
    }
}

// MARK: - ProtocolPreviewBackdrop
//
// The blurred content behind the paywall — renders a fake protocol preview
// so the paywall feels like it's blocking a real thing.

private struct ProtocolPreviewBackdrop: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WEEK \(i + 1)")
                            .font(Font.unbound.captionS)
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Text("Upper body · \(45 + i * 5) min")
                            .font(Font.unbound.bodyLStrong)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Text("Bench · Row · Press · Curl · Core")
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.unbound.surface)
                )
            }
        }
        .padding(20)
    }
}
