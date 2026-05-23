import SwiftUI

// MARK: - UnboundCinematic
//
// The single cinematic moment in UNBOUND's rank system. Fires ONCE per
// muscle group the first time it crosses from B → A (letter threshold).
// Every other tier-up plays a subtle color bloom — only A earns this
// full takeover. Protect the brand moment: do not reuse this animation
// for sub-rank advances or for other letter tiers.
//
// Beat timeline (~4.2s total):
//   0.0-0.5s  BIND       chained bone-white hex appears, low hum
//   0.5-1.3s  STRAIN     chains glow hot, badge shudders, warning haptic
//   1.3-1.6s  SHATTER    chains snap → fragments fly outward
//                        violet burst expands, speed lines radiate
//                        heavy impact haptic, screen flash
//   1.6-2.6s  REVEAL     letter "A" pulses in, violet aura holds
//   2.6-4.2s  HOLD       caption "{MUSCLE} · UNBOUND" visible,
//                        soft tap-to-share hint, then auto-dismiss
//
// Tap anywhere → dismiss immediately.
// Respects `reduceMotion` — skips shatter, jumps straight to REVEAL.

struct UnboundCinematic: View {
    let muscleName: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .bind
    @State private var chainsShattered: Bool = false
    @State private var showLetter: Bool = false
    @State private var showCaption: Bool = false
    @State private var showShareHint: Bool = false
    @State private var burstScale: CGFloat = 0
    @State private var flashOn: Bool = false
    @State private var badgeShake: CGFloat = 0
    @State private var dismissScheduled: Bool = false

    // Haptic triggers — incremented at the moments we want feedback to fire.
    // SwiftUI's .sensoryFeedback modifier watches these for changes.
    @State private var strainHaptic: Int = 0
    @State private var shatterHaptic: Int = 0
    @State private var successHaptic: Int = 0

    private enum Phase { case bind, strain, shatter, reveal, hold }

    private let violet = Color.unbound.accent
    private let violetImpact = Color.unbound.impact
    private let bone = Color.unbound.textPrimary

    var body: some View {
        ZStack {
            backdrop
            violetHalo
            burst
            chainedBadge
            letterReveal
            caption
            shareHint
            if flashOn {
                Color.white.opacity(0.85).ignoresSafeArea().transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { scheduleDismiss(delay: 0) }
        .sensoryFeedback(.warning, trigger: strainHaptic)
        .sensoryFeedback(.impact(weight: .heavy), trigger: shatterHaptic)
        .sensoryFeedback(.success, trigger: successHaptic)
        .task {
            if reduceMotion { await runReducedMotion() }
            else { await runFullSequence() }
        }
    }

    // MARK: Layers

    private var backdrop: some View {
        RadialGradient(
            colors: [Color.unbound.bg, Color.black],
            center: .center,
            startRadius: 10,
            endRadius: 900
        )
        .ignoresSafeArea()
    }

    private var violetHalo: some View {
        RadialGradient(
            colors: [
                violet.opacity(phase == .bind ? 0.15 : 0.55),
                Color.clear
            ],
            center: .center,
            startRadius: 10,
            endRadius: 480
        )
        .scaleEffect(phase == .strain ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                   value: phase)
        .ignoresSafeArea()
        .blendMode(.screen)
    }

    private var burst: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [violetImpact.opacity(0.95), violet.opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .scaleEffect(burstScale)
                .opacity(burstScale > 0 ? max(0, 1 - (burstScale - 0.4) / 1.2) : 0)
                .blendMode(.screen)

            // speed lines
            if phase == .shatter || phase == .reveal || phase == .hold {
                ShatterRays(color: bone, count: 18, innerRadius: 120, length: 220)
                    .opacity(phase == .hold ? 0 : 1)
                    .animation(.easeOut(duration: 0.9), value: phase)
            }
        }
    }

    private var chainedBadge: some View {
        ZStack {
            // The hex body — stays visible throughout, brightens on reveal
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(bone)
                .frame(width: 180, height: 180)
                .shadow(color: violet.opacity(showLetter ? 0.7 : 0.2), radius: 40)
                .scaleEffect(phase == .shatter ? 1.12 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: phase)

            // Chain wrap — shatters on impact
            ChainWrap(shattered: chainsShattered, tint: violet)
                .frame(width: 260, height: 260)
        }
        .offset(x: badgeShake, y: 0)
    }

    private var letterReveal: some View {
        Group {
            if showLetter {
                Text("A")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(bone)
                    .shadow(color: violet.opacity(0.9), radius: 24)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .scaleEffect(phase == .hold ? 1.04 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: phase
                    )
            }
        }
    }

    private var caption: some View {
        VStack {
            Spacer()
            if showCaption {
                VStack(spacing: 10) {
                    Text("\(muscleName.uppercased()) · UNBOUND")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .tracking(2.8)
                        .foregroundStyle(bone)

                    Text("The constraint broke.")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.6)
                        .foregroundStyle(violetImpact)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.bottom, 80)
            }
        }
    }

    private var shareHint: some View {
        VStack {
            Spacer()
            if showShareHint {
                Text("TAP TO DISMISS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.bottom, 32)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Timeline

    private func runFullSequence() async {
        // BIND (0.0 - 0.5)
        phase = .bind
        await sleep(0.5)

        // STRAIN (0.5 - 1.3) — chain glows hot, badge shudders
        withAnimation(.easeInOut(duration: 0.4)) { phase = .strain }
        strainHaptic &+= 1
        await animateBadgeShake()
        await sleep(0.8)

        // SHATTER (1.3 - 1.6) — CHAINS BREAK, violet burst, flash
        shatterHaptic &+= 1
        withAnimation(.easeOut(duration: 0.2)) { flashOn = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
            phase = .shatter
            chainsShattered = true
            burstScale = 1.6
        }
        await sleep(0.15)
        withAnimation(.easeIn(duration: 0.25)) { flashOn = false }
        await sleep(0.3)

        // REVEAL (1.6 - 2.6)
        withAnimation(.easeOut(duration: 0.4)) { phase = .reveal }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) {
            showLetter = true
        }
        await sleep(1.0)

        // HOLD (2.6 - 4.2)
        withAnimation(.easeInOut(duration: 0.5)) { phase = .hold }
        withAnimation(.easeOut(duration: 0.5).delay(0.05)) { showCaption = true }
        await sleep(1.2)
        withAnimation(.easeIn(duration: 0.35)) { showShareHint = true }
        await sleep(0.4)

        scheduleDismiss(delay: 0)
    }

    private func runReducedMotion() async {
        // Skip shatter choreography — go straight to the payoff.
        phase = .hold
        chainsShattered = true
        showLetter = true
        showCaption = true
        successHaptic &+= 1
        await sleep(2.8)
        scheduleDismiss(delay: 0)
    }

    private func animateBadgeShake() async {
        for offset in [-4.0, 4.0, -6.0, 6.0, -4.0, 4.0, 0.0] {
            withAnimation(.easeInOut(duration: 0.06)) {
                badgeShake = offset
            }
            await sleep(0.06)
        }
    }

    private func scheduleDismiss(delay: Double) {
        guard !dismissScheduled else { return }
        dismissScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onDismiss() }
    }

    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Chain wrap
//
// Four chain-link shapes arranged around the badge. On `shattered`, they
// animate outward with rotation — mirrors the logo's broken-chain motif.

private struct ChainWrap: View {
    let shattered: Bool
    let tint: Color

    private let links: [CGPoint] = [
        CGPoint(x: -1,  y: -0.4),
        CGPoint(x:  1,  y: -0.4),
        CGPoint(x: -1,  y:  0.4),
        CGPoint(x:  1,  y:  0.4),
        CGPoint(x:  0,  y: -1),
        CGPoint(x:  0,  y:  1),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(Array(links.enumerated()), id: \.offset) { i, base in
                    ChainLink(tint: tint)
                        .frame(width: 46, height: 76)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .offset(
                            x: base.x * (shattered ? w * 0.9 : w * 0.35),
                            y: base.y * (shattered ? h * 0.9 : h * 0.35)
                        )
                        .rotationEffect(.degrees(shattered ? Double(i) * 55 : 0))
                        .opacity(shattered ? 0 : 1)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.55)
                                .delay(Double(i) * 0.02),
                            value: shattered
                        )
                }
            }
            .frame(width: w, height: h)
        }
    }
}

private struct ChainLink: View {
    let tint: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.unbound.textPrimary, lineWidth: 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 14)
                    .blur(radius: 4)
            )
    }
}

// MARK: - Shatter rays

private struct ShatterRays: View {
    let color: Color
    let count: Int
    let innerRadius: CGFloat
    let length: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<count {
                let angle = Double(i) * (2 * .pi / Double(count))
                let start = CGPoint(
                    x: center.x + cos(angle) * innerRadius,
                    y: center.y + sin(angle) * innerRadius
                )
                let end = CGPoint(
                    x: center.x + cos(angle) * (innerRadius + length),
                    y: center.y + sin(angle) * (innerRadius + length)
                )
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                ctx.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 2.5)
            }
        }
        .blendMode(.screen)
    }
}

// MARK: - Previews

#Preview("Chest → Unbound") {
    UnboundCinematic(muscleName: "Chest", onDismiss: {})
}

#Preview("Back → Unbound") {
    UnboundCinematic(muscleName: "Back", onDismiss: {})
}
