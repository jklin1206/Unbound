import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("onboarding_path_open_gate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 168, height: 168)
                    .shadow(color: Color.unbound.accent.opacity(0.32), radius: 18)
                    .padding(.bottom, 48)

                VStack(spacing: 12) {
                    Text(L10n.onboarding("welcome.title", defaultValue: "Your anime physique starts here."))
                        .font(.headline(32))
                        .foregroundColor(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(L10n.onboarding("welcome.subtitle", defaultValue: "Deterministic training, monthly recaps, and real progression."))
                        .font(.bodyText())
                        .foregroundColor(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                Spacer()

                GradientButton(title: L10n.onboarding("welcome.cta", defaultValue: "Get Started"), action: onNext)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
            }
        }
    }
}
