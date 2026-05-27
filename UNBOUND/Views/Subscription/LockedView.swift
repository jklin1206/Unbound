import SwiftUI

struct LockedView: View {
    @EnvironmentObject private var services: ServiceContainer
    @ObservedObject private var entitlement = EntitlementService.shared
    @State private var didAutoPresent = false
    @State private var showPurchaseSheet = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 26) {
                Spacer(minLength: 32)

                VStack(spacing: 12) {
                    logo

                    Text(L10n.string(.appName, defaultValue: "UNBOUND"))
                        .font(Font.unbound.displayXL)
                        .tracking(4)
                        .foregroundStyle(Color.unbound.textPrimary)

                    Text(L10n.string(.subscriptionLockedTitle, defaultValue: "Subscribe to unlock UNBOUND"))
                        .font(Font.unbound.displayM)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.78)

                    Text(L10n.string(
                        .subscriptionLockedSubtitle,
                        defaultValue: "Your training, your crew, your build. Cancel anytime."
                    ))
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 14) {
                    UnboundButton(
                        title: L10n.string(.subscriptionLockedCTA, defaultValue: "Subscribe to continue"),
                        icon: "crown.fill",
                        action: { presentPaywall() }
                    )

                    RestorePurchasesButton()

                    #if DEBUG
                    Button {
                        DevFlags.shared.unlockAllFeatures = true
                    } label: {
                        Text(L10n.string(.subscriptionLockedDevUnlock, defaultValue: "DEV · Unlock simulator"))
                            .font(Font.unbound.monoS)
                            .tracking(1.4)
                            .foregroundStyle(Color.unbound.impact)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    #endif
                }
                .padding(.top, 8)

                Spacer(minLength: 42)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            services.analytics.track(.paywallViewed(placement: AppConstants.Paywall.hardGate))
            guard !didAutoPresent, !entitlement.isEntitled else { return }
            didAutoPresent = true
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                presentPaywall()
            }
        }
        .sheet(isPresented: $showPurchaseSheet) {
            PaywallPlaceholderView()
                .environmentObject(services)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.024, blue: 0.034),
                    Color(red: 0.055, green: 0.043, blue: 0.083),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            TechGridBackground(opacity: 0.08)

            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(0.30),
                    Color.unbound.accent.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 24,
                endRadius: 420
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.64)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(Color.unbound.accent.opacity(0.12))
                .frame(width: 112, height: 112)
                .blur(radius: 14)

            Image(systemName: "flame.fill")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(Color.unbound.accent)
                .shadow(color: Color.unbound.accent.opacity(0.65), radius: 18)
        }
        .frame(width: 126, height: 126)
    }

    private func presentPaywall() {
        guard !entitlement.isEntitled else { return }
        services.analytics.track(.paywallPresented(placement: AppConstants.Paywall.hardGate))
        showPurchaseSheet = true
    }
}

#Preview {
    LockedView()
        .environmentObject(ServiceContainer.mock)
}
