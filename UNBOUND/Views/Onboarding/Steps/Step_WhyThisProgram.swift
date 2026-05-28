import SwiftUI

struct Step_WhyThisProgram: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "The path starts paying you back.",
            subtitle: "Behind the gate is not a feed of random workouts. It is a route that keeps turning effort into visible progress.",
            progress: progress,
            primaryTitle: "Show the climb",
            primaryEnabled: true,
            hudStep: .whyThisProgram,
            onBack: onBack,
            onPrimary: {
                UnboundHaptics.heavy()
                onContinue()
            }
        ) {
            VStack(spacing: 14) {
                pathHero

                VStack(spacing: 10) {
                    routeStat(label: "RECEIVE", value: "YOUR OPENING ARC", icon: "map.fill")
                    routeStat(label: "TRACK", value: "RANK, LOGS, PROOF", icon: "hexagon.fill")
                    routeStat(label: "RHYTHM", value: "\(sessionsPerWeek)x / \(sessionLengthLabel.uppercased())", icon: "timer")
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.unbound.impact)
                        .padding(.top, 2)
                    Text("You get the first block, recovery targets, workout logging, monthly scans, rank movement, and the next gate only after the current one is earned.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surface.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.unbound.impact.opacity(0.26), lineWidth: 1)
                )
            }
        }
    }

    private var pathHero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("onboarding_path_transformation")
                .resizable()
                .scaledToFill()
                .frame(height: 302)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("WHAT OPENS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.accent)
                Text("THE ARC SYSTEM")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(0.22), radius: 18)
    }

    private var sessionsPerWeek: Int {
        flow.targetFrequency?.numericCount ?? 4
    }

    private var sessionLengthLabel: String {
        flow.sessionLength?.displayName ?? "45 minutes"
    }

    private func routeStat(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.unbound.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(value)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }
}

#Preview {
    Step_WhyThisProgram(
        flow: OnboardingFlowViewModel(),
        progress: 0.8,
        onBack: {},
        onContinue: {}
    )
}
