import SwiftUI

// MARK: - TierBloomToast
//
// Subtle top-of-screen notification that fires when a muscle crosses a
// letter-tier threshold OTHER than A. A-tier crossings get the full
// `UnboundCinematic` takeover — this is everything else.
//
// Beat timeline (~1.4s total):
//   0.0-0.2s  slide in from top + color bloom fade up, medium haptic
//   0.2-1.0s  hold, breathing pulse on the tier letter
//   1.0-1.4s  fade + slide out
//
// Never show this for sub-rank advances (E- → E) — those stay haptic-only.
// Never show this for A-tier crossings — use UnboundCinematic.
//
// Usage:
//   .overlay(alignment: .top) {
//       TierBloomToast(
//           muscle: "Chest",
//           newTier: .b,
//           caption: "Sharpened",   // optional override; defaults to tier.caption
//           onDismiss: { activeBloom = nil }
//       )
//   }

struct TierBloomToast: View {
    let muscle: String
    let newTier: MuscleGroupTier
    let caption: String?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var present: Bool = false
    @State private var pulse: Bool = false
    @State private var haptic: Int = 0

    init(muscle: String, newTier: MuscleGroupTier, caption: String? = nil, onDismiss: @escaping () -> Void) {
        self.muscle = muscle
        self.newTier = newTier
        self.caption = caption
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 14) {
            // Tier letter disc — tinted to the tier color, subtle pulse
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(tint, lineWidth: 1.5)
                    .frame(width: 52, height: 52)
                Text(newTier.letter)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(letterColor)
            }
            .scaleEffect(pulse ? 1.05 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(muscle.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(resolvedCaption)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            Spacer(minLength: 12)

            Text("+1")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .stroke(tint.opacity(0.55), lineWidth: 1)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surfaceElevated)
                .overlay(
                    // color bloom — soft radial tint of the tier's color
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.25), .clear],
                                center: .leading,
                                startRadius: 8,
                                endRadius: 200
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.35), radius: 20, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .opacity(present ? 1 : 0)
        .offset(y: present ? 0 : -50)
        .sensoryFeedback(.impact(weight: .medium), trigger: haptic)
        .contentShape(Rectangle())
        .onTapGesture { dismiss(animated: true) }
        .task {
            await runSequence()
        }
    }

    // MARK: Timing

    private func runSequence() async {
        if reduceMotion {
            present = true
            haptic &+= 1
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            onDismiss()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            present = true
        }
        haptic &+= 1

        // breathing pulse during hold
        withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
            pulse = true
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
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

    // MARK: Styling

    private var resolvedCaption: String {
        caption ?? "\(newTier.caption.uppercased()) · TIER UP"
    }

    private var tint: Color {
        switch newTier {
        case .e: return Color.unbound.rankRed
        case .d: return Color.unbound.rankOrange
        case .c: return Color.unbound.rankAmber
        case .b: return Color.unbound.rankGreen
        case .a: return Color.unbound.accent       // A should use UnboundCinematic — included for completeness
        case .s: return Color.unbound.rankGold
        }
    }

    private var letterColor: Color {
        switch newTier {
        case .c, .s: return Color.unbound.bg   // bright tints → dark letter
        default:     return Color.unbound.textPrimary
        }
    }
}

// MARK: - Presentation helper
//
// Usage on a root view:
//   .tierBloomOverlay($pendingTierUp)
//
// where `pendingTierUp: TierBloomPayload?` is set when the
// `muscleGroupTierChanged` notification fires for any tier except .a.

struct TierBloomPayload: Equatable, Identifiable {
    let id = UUID()
    let muscle: String
    let newTier: MuscleGroupTier
    let caption: String?

    init(muscle: String, newTier: MuscleGroupTier, caption: String? = nil) {
        self.muscle = muscle
        self.newTier = newTier
        self.caption = caption
    }
}

extension View {
    /// Overlays a `TierBloomToast` at the top of the view when `payload`
    /// is non-nil. Clears `payload` on dismissal.
    func tierBloomOverlay(_ payload: Binding<TierBloomPayload?>) -> some View {
        overlay(alignment: .top) {
            if let current = payload.wrappedValue {
                TierBloomToast(
                    muscle: current.muscle,
                    newTier: current.newTier,
                    caption: current.caption,
                    onDismiss: { payload.wrappedValue = nil }
                )
                .id(current.id)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Previews

#Preview("Chest → B (Sharpened)") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TierBloomToast(muscle: "Chest", newTier: .b, onDismiss: {})
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview("Legs → S (Ascended)") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TierBloomToast(muscle: "Legs", newTier: .s, onDismiss: {})
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

#Preview("Shoulders → D (Awakened)") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TierBloomToast(muscle: "Shoulders", newTier: .d, onDismiss: {})
            .frame(maxHeight: .infinity, alignment: .top)
    }
}
