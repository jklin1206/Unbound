import SwiftUI

struct OnboardingHowItWorksView: View {
    let onNext: () -> Void

    private struct Step {
        let icon: String
        let title: String
        let description: String
    }

    private var steps: [Step] {
        [
            Step(
                icon: "camera.fill",
                title: L10n.onboarding("howItWorks.step.photos.title", defaultValue: "Take 3 Photos"),
                description: L10n.onboarding("howItWorks.step.photos.description", defaultValue: "Front, side, and back — we'll guide you")
            ),
            Step(
                icon: "chart.bar.fill",
                title: L10n.onboarding("howItWorks.step.report.title", defaultValue: "Get Your Monthly Recap"),
                description: L10n.onboarding("howItWorks.step.report.description", defaultValue: "Monthly recaps summarize validated progress signals")
            ),
            Step(
                icon: "dumbbell.fill",
                title: L10n.onboarding("howItWorks.step.program.title", defaultValue: "Follow Your Program"),
                description: L10n.onboarding("howItWorks.step.program.description", defaultValue: "Custom training, nutrition, and recovery plan")
            )
        ]
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(L10n.onboarding("howItWorks.title", defaultValue: "How It Works"))
                    .font(.headline(28))
                    .foregroundColor(.theme.textPrimary)
                    .padding(.bottom, 40)

                VStack(spacing: 28) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.theme.primary.opacity(0.15))
                                    .frame(width: 52, height: 52)

                                Image(systemName: step.icon)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.theme.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.subheadline(18))
                                    .foregroundColor(.theme.textPrimary)

                                Text(step.description)
                                    .font(.bodyText(14))
                                    .foregroundColor(.theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                GradientButton(title: L10n.onboarding("common.continue", defaultValue: "Continue"), action: onNext)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 80)
            }
        }
    }
}
