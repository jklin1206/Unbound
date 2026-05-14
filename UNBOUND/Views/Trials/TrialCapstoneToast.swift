import SwiftUI

// MARK: - TrialCapstoneToast
//
// Bottom-of-screen toast fired when `TrialsService` posts `.trialCompleted`.
// Visual style matches TierBloomToast — slide up + brief hold + fade out.
//
// Usage:
//   .trialCapstoneToast()
//
// Beat timeline (~2.8s total):
//   0.0-0.40s  slide up from bottom + opacity in, heavy haptic
//   0.40-2.4s  hold with gentle pulse on the theme tag
//   2.4-2.8s   fade + slide out

struct TrialCapstoneToast: View {
    let trial: Trial
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var present: Bool = false
    @State private var pulse: Bool = false
    @State private var haptic: Int = 0

    private var tint: Color { trial.chosenCard.theme.tintColor }

    var body: some View {
        HStack(spacing: 14) {
            // Theme tag with subtle pulse
            ZStack {
                Capsule()
                    .fill(tint.opacity(0.18))
                    .frame(width: 68, height: 30)
                Capsule()
                    .stroke(tint, lineWidth: 1.2)
                    .frame(width: 68, height: 30)
                Text(trial.chosenCard.theme.displayLabel.prefix(7))
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            .scaleEffect(pulse ? 1.04 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(trial.chosenCard.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                Text("Trial Complete")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 12)

            Image(systemName: "flag.2.crossed.fill")
                .foregroundStyle(tint.opacity(0.8))
                .font(.system(size: 20))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.18), .clear],
                                center: .leading,
                                startRadius: 8,
                                endRadius: 200
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.30), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.28), radius: 18, y: -6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .opacity(present ? 1 : 0)
        .offset(y: present ? 0 : 60)
        .sensoryFeedback(.impact(weight: .heavy), trigger: haptic)
        .contentShape(Rectangle())
        .onTapGesture { dismiss(animated: true) }
        .task { await runSequence() }
    }

    // MARK: - Timing

    private func runSequence() async {
        if reduceMotion {
            present = true
            haptic &+= 1
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            present = true
        }
        haptic &+= 1

        withAnimation(.easeInOut(duration: 1.0).repeatCount(2, autoreverses: true)) {
            pulse = true
        }

        try? await Task.sleep(nanoseconds: 2_400_000_000)
        dismiss(animated: true)
    }

    private func dismiss(animated: Bool) {
        if animated {
            withAnimation(.easeIn(duration: 0.35)) {
                present = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: onDismiss)
        } else {
            onDismiss()
        }
    }
}

// MARK: - Presentation modifier

private struct TrialCapstoneToastModifier: ViewModifier {
    @State private var pendingTrial: Trial?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let current = pendingTrial {
                TrialCapstoneToast(trial: current, onDismiss: { pendingTrial = nil })
                    .id(current.id)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trialCompleted)) { note in
            guard let trial = note.object as? Trial else { return }
            pendingTrial = trial
        }
    }
}

extension View {
    /// Overlay a TrialCapstoneToast at the bottom of the view when a trial
    /// capstone is completed. Listens for `.trialCompleted` notifications.
    func trialCapstoneToast() -> some View {
        modifier(TrialCapstoneToastModifier())
    }
}

// MARK: - Previews

#Preview("Capstone complete — power") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCapstoneToast(
            trial: Trial(
                id: "trial-W20-aligned",
                userId: "preview",
                weekStart: Date(),
                chosenCard: TrialCard(
                    id: "trial-W20-aligned",
                    kind: .aligned,
                    theme: .axis(.power),
                    displayName: "Power Focus",
                    blurb: "Double down on heavy compound work.",
                    capstone: TrialCapstone(displayName: "Top-Set PR", description: "Hit a PR.", evaluation: .manualClaim)
                ),
                capstoneState: .completed
            ),
            onDismiss: {}
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
