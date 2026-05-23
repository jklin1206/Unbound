import SwiftUI

// MARK: - TierBloomToast
//
// Subtle bottom-of-screen notification that fires when a skill crosses a
// SkillTier threshold where `to.isFlagshipMoment == false` (i.e., Initiate
// through Honed). Flagship tiers (Vessel/Unbound/Ascendant) use the full
// RankUpCinematic chain-shatter takeover — this is everything else.
//
// Beat timeline (~2.5s total):
//   0.0-0.35s  slide up from bottom + opacity in, medium haptic
//   0.35-2.1s  hold (visible + breathing pulse on tier name)
//   2.1-2.5s   fade + slide out
//
// Usage (via view modifier):
//   .tierBloomToast()
//
// The modifier attaches a listener for `.skillTierAdvanced` notifications
// and renders the toast for non-flagship advances.

struct TierBloomToast: View {
    let advance: SkillTierAdvance
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var present: Bool = false
    @State private var pulse: Bool = false
    @State private var haptic: Int = 0

    var body: some View {
        HStack(spacing: 14) {
            // Tier pill — tinted to the tier color, subtle pulse
            ZStack {
                Capsule()
                    .fill(tint.opacity(0.18))
                    .frame(width: 72, height: 30)
                Capsule()
                    .stroke(tint, lineWidth: 1.2)
                    .frame(width: 72, height: 30)
                Text(advance.to.displayName.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(tint)
            }
            .scaleEffect(pulse ? 1.04 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(skillDisplayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("Tier Up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.up.circle.fill")
                .foregroundStyle(tint.opacity(0.7))
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
                        .stroke(tint.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.28), radius: 18, y: -6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .opacity(present ? 1 : 0)
        .offset(y: present ? 0 : 60)
        .sensoryFeedback(.impact(weight: .medium), trigger: haptic)
        .contentShape(Rectangle())
        .onTapGesture { dismiss(animated: true) }
        .task { await runSequence() }
    }

    // MARK: - Timing

    private func runSequence() async {
        if reduceMotion {
            present = true
            haptic &+= 1
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            present = true
        }
        haptic &+= 1

        withAnimation(.easeInOut(duration: 0.9).repeatCount(2, autoreverses: true)) {
            pulse = true
        }

        try? await Task.sleep(nanoseconds: 2_100_000_000)
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

    // MARK: - Helpers

    /// Human-readable skill display name from the skill graph. Falls back
    /// to the raw id if the node isn't found.
    private var skillDisplayName: String {
        SkillGraph.shared.nodes.first(where: { $0.id == advance.skillId })?.title
            ?? advance.skillId
    }

    private var tint: Color {
        advance.to.rewardTint
    }
}

// MARK: - Presentation modifier
//
// Listens for `.skillTierAdvanced` notifications. Fires TierBloomToast only
// when `advance.isFlagship == false`. Flagship advances are handled by
// RankUpCinematicPresenter.

private struct TierBloomToastModifier: ViewModifier {
    @State private var pending: SkillTierAdvance?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if let current = pending {
                TierBloomToast(advance: current, onDismiss: { pending = nil })
                    .id(current.id)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillTierAdvanced)) { note in
            guard let advance = note.object as? SkillTierAdvance else { return }
            guard !advance.isFlagship else { return }
            // Replace any pending toast (most recent wins)
            pending = advance
        }
    }
}

extension View {
    /// Overlay a TierBloomToast at the bottom of the view for non-flagship
    /// SkillTier advances. Flagship tiers (Vessel/Unbound/Ascendant) are
    /// handled by RankUpCinematicPresenter.
    func tierBloomToast() -> some View {
        modifier(TierBloomToastModifier())
    }
}

// MARK: - Previews

#Preview("Forged tier-up") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TierBloomToast(
            advance: SkillTierAdvance(skillId: "pp.pullup", from: .apprentice, to: .forged),
            onDismiss: {}
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

#Preview("Veteran tier-up") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TierBloomToast(
            advance: SkillTierAdvance(skillId: "pp.handstand", from: .forged, to: .veteran),
            onDismiss: {}
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
