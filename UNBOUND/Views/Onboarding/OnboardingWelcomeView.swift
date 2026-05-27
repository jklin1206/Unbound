import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 100, weight: .thin))
                    .foregroundColor(.theme.primary)
                    .padding(.bottom, 48)

                VStack(spacing: 12) {
                    Text(L10n.onboarding("welcome.title", defaultValue: "Your anime physique starts here."))
                        .font(.headline(32))
                        .foregroundColor(.theme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(L10n.onboarding("welcome.subtitle", defaultValue: "Deterministic training, monthly recaps, and real progression."))
                        .font(.bodyText())
                        .foregroundColor(.theme.textSecondary)
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
