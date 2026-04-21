import SwiftUI

// MARK: - OnboardingProgressBar
//
// Thin 2pt progress bar anchored below the back chevron on every onboarding
// screen. Bone-white subtle track; violet fill that springs between steps.
// Matches the Arise/Liftoff pattern jlin referenced.

struct OnboardingProgressBar: View {
    /// 0...1 fraction complete. Caller computes from currentStep / totalSteps.
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.unbound.border.opacity(0.6))

                // Fill
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.unbound.accent,
                                Color.unbound.impact
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
                    .shadow(color: Color.unbound.accent.opacity(0.5), radius: 6, x: 0, y: 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.85), value: progress)
            }
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

#Preview("Progress bar") {
    VStack(spacing: 24) {
        OnboardingProgressBar(progress: 0.1)
        OnboardingProgressBar(progress: 0.45)
        OnboardingProgressBar(progress: 0.87)
        OnboardingProgressBar(progress: 1.0)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
