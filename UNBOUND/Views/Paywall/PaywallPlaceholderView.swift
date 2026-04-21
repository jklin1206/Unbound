import SwiftUI

struct PaywallPlaceholderView: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: String = "annual"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let features = [
        "Custom training program",
        "Nutrition plan",
        "Recovery guide",
        "Progress tracking",
        "Unlimited re-scans"
    ]

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.theme.primary)
                            .padding(.top, 40)

                        Text("Unlock Your Full Program")
                            .font(.headline(28))
                            .foregroundColor(.theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Everything you need to build your ideal physique")
                            .font(.bodyText(16))
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    // Feature list
                    VStack(spacing: 12) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.theme.secondary)
                                    .font(.system(size: 20))
                                Text(feature)
                                    .font(.bodyMedium(16))
                                    .foregroundColor(.theme.textPrimary)
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)

                    // Plan cards
                    HStack(spacing: 12) {
                        PlanCard(
                            title: "Weekly",
                            price: "$4.99",
                            period: "per week",
                            trialDays: "3-day trial",
                            badge: nil,
                            isSelected: selectedPlan == "weekly"
                        ) {
                            selectedPlan = "weekly"
                        }

                        PlanCard(
                            title: "Annual",
                            price: "$29.99",
                            period: "per year",
                            trialDays: "7-day trial",
                            badge: "BEST VALUE",
                            isSelected: selectedPlan == "annual"
                        ) {
                            selectedPlan = "annual"
                        }
                    }
                    .padding(.horizontal, 24)

                    // Error
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption())
                            .foregroundColor(.theme.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // CTA
                    VStack(spacing: 16) {
                        GradientButton(title: "Start Free Trial", action: {
                            Task { await startTrial() }
                        }, isLoading: isLoading)
                        .padding(.horizontal, 24)

                        Button("Restore Purchases") {
                            Task { await restorePurchases() }
                        }
                        .font(.bodyMedium(15))
                        .foregroundColor(.theme.textSecondary)
                    }

                    // Terms
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://unboundapp.com/terms")!)
                        Text("·")
                        Link("Privacy Policy", destination: URL(string: "https://unboundapp.com/privacy")!)
                    }
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
                    .padding(.bottom, 32)

                    #if DEBUG
                    // Dev-only: bypass the paywall without charging. Compiled out
                    // of Release builds entirely — the Button literal is gone.
                    Button {
                        DevFlags.shared.unlockAllFeatures = true
                    } label: {
                        Text("🧪 Dev: bypass paywall")
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)
                    }
                    .padding(.bottom, 24)
                    #endif
                }
            }
        }
    }

    private func startTrial() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let success = try await services.subscription.purchase(packageId: selectedPlan)
            if success { dismiss() }
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    private func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let success = try await services.subscription.restorePurchases()
            if success {
                dismiss()
            } else {
                errorMessage = "No active subscription found."
            }
        } catch {
            errorMessage = "Restore failed. Please try again."
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let trialDays: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(.theme.background)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.theme.primary)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 22)
                }

                Text(title)
                    .font(.bodyMedium(15))
                    .foregroundColor(.theme.textPrimary)

                Text(price)
                    .font(.headline(22))
                    .foregroundColor(isSelected ? .theme.primary : .theme.textPrimary)

                Text(period)
                    .font(.caption(12))
                    .foregroundColor(.theme.textSecondary)

                Text(trialDays)
                    .font(.caption(11))
                    .foregroundColor(.theme.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.theme.primary : Color.theme.surfaceLight, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallPlaceholderView()
        .environmentObject(ServiceContainer.mock)
}
