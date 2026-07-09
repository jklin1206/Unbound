import SwiftUI

/// Verdict. On a PASS the animation is the reward (The Crossing) — no accounting
/// screen. This view is primarily the FAIL: the world holds steady, "THE GATE
/// HOLDS", one resolute line, ENTER AGAIN. Background-driven and simple (no boxes).
/// A pass variant is kept for the standalone demo (→ ENTER THE CROSSING).
struct GateVerdictView: View {
    let evaluation: OverallRankTrialEvaluation
    let world: GateWorld
    /// The XP/Arcs banked during the failed attempt (e.g. "+120 XP · +90 ARCS
    /// BANKED"). A failed gate skips the reward sequence, so this one quiet
    /// line is the only place those spoils are ever shown.
    var spoilsLine: String? = nil
    var onMintedCardTapped: (() -> Void)? = nil   // pass → The Crossing
    var onRematch: (() -> Void)? = nil            // fail → try again

    private var model: GateVerdictModel { .init(evaluation: evaluation, world: world) }
    private var passed: Bool { model.outcome == .passed }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            Image(world.bannerAssetName).resizable().scaledToFill().ignoresSafeArea().clipped()
                .saturation(passed ? 1 : 0.35)
                .overlay(Color.black.opacity(passed ? 0.4 : 0.64).ignoresSafeArea())
                .overlay(LinearGradient(colors: [.clear, Color.black.opacity(0.85)],
                                        startPoint: .center, endPoint: .bottom).ignoresSafeArea())

            VStack(spacing: 12) {
                Spacer()
                Text("RANK GATE \(world.numeral)")
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(4)
                    .foregroundStyle(passed ? world.tint : Color.unbound.textTertiary)
                    .shadow(color: .black.opacity(0.85), radius: 4, y: 1)
                Text(passed ? "THE GATE IS ANSWERED" : "THE GATE HOLDS")
                    .font(Font.unbound.titleL.weight(.black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.7), radius: 8, y: 2)
                Text(passed ? world.trialName.uppercased() : "The gate isn't going anywhere.")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(passed ? world.tint : Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.85), radius: 4, y: 1)
                if !passed, let closest = model.standingBetween.first {
                    Text(closest)
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.warnOrange)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .shadow(color: .black.opacity(0.85), radius: 4, y: 1)
                }
                if !passed, let spoilsLine {
                    Text(spoilsLine)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                        .shadow(color: .black.opacity(0.85), radius: 4, y: 1)
                }
                Spacer()
            }
            .padding(.horizontal, 28).padding(.bottom, 112)

            ctaBar
        }
        .accessibilityIdentifier("gate-verdict-view")
    }

    private var ctaBar: some View {
        Button {
            if passed { UnboundHaptics.success(); onMintedCardTapped?() } else { onRematch?() }
        } label: {
            HStack(spacing: 8) {
                Text(passed ? "ENTER THE CROSSING" : "ENTER AGAIN")
                if passed { Image(systemName: "arrow.right").font(.system(size: 14, weight: .heavy)) }
            }
            .font(Font.unbound.titleS.weight(.heavy)).tracking(1.5)
            .foregroundStyle(passed ? Color.unbound.bg : Color.unbound.textPrimary)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Capsule().fill(passed ? world.fillTint : Color.unbound.surfaceElevated))
            .overlay(passed ? nil : Capsule().strokeBorder(world.tint.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18).padding(.bottom, 28)
        .accessibilityIdentifier("verdict-cta")
    }
}
