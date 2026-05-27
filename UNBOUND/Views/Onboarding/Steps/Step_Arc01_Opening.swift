import SwiftUI
import AVKit

struct Step_Arc01_Opening: View {
    let onBegin: () -> Void

    @State private var phase: Phase = .dormant
    @State private var player: AVPlayer? = Self.makePlayer()
    @State private var buttonPulse = false
    @State private var flashOpacity: Double = 0

    /// Peak volume the video sits at once it's faded in. Kept below 1.0
    /// because the source mix is loud — anything hotter lands as a smack
    /// coming out of a silent dormant screen. Tuned by ear.
    private static let peakVolume: Float = 0.75

    enum Phase { case dormant, awakening, complete }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                CinematicVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(phase == .dormant ? 0 : 1)
                    .animation(.easeInOut(duration: 0.7), value: phase)
            }

            if phase == .dormant {
                dormantBust
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))

                ParticleEmitter(config: .embers, isActive: true)
                    .opacity(0.85)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Impact flash bridge — brief radial bloom covers the cut from
            // dormant bust to video so the handoff reads as a punch rather
            // than a jarring swap. Violet + ember tint keeps the brand
            // language; the outer edges stay black so it feels contained.
            RadialGradient(
                colors: [
                    Color.unbound.accent.opacity(0.85),
                    Color.unbound.ember.opacity(0.55),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
            .opacity(flashOpacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .blendMode(.screen)

            topScrim
                .allowsHitTesting(false)

            titleBlock
                .opacity(phase == .awakening ? 0 : 1)
                .animation(.easeOut(duration: 0.4), value: phase)

            VStack {
                Spacer()
                if phase == .dormant {
                    ctaButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 42)
                        .transition(.opacity.combined(with: .offset(y: 60)))
                }
            }
        }
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            player?.seek(to: .zero, completionHandler: { _ in })
            player?.pause()
            // Start silent so the ramp-up is the source of drama, not the
            // raw mp4 slap. Volume climbs inside `playSequence()`.
            player?.volume = 0
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                buttonPulse = true
            }
        }
    }

    private var topScrim: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.92),
                Color.black.opacity(0.75),
                Color.black.opacity(0.35),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 320)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private var dormantBust: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let breathe = 1.0 + 0.012 * sin(t * 1.1)
            if let image = Self.dormantBustImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(breathe)
                    .shadow(color: Color.unbound.accent.opacity(0.45), radius: 28)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                Color.clear
            }
        }
    }

    private static let dormantBustImage: UIImage? = {
        guard let url = Bundle.main.url(forResource: "openingscreen", withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }()

    private var ctaButton: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 2.0) + 1.0) / 2.0
            let wave = (sin(t * 1.4) + 1.0) / 2.0

            ZStack {
                Capsule()
                    .stroke(Color.unbound.accent.opacity(0.42 * (1.0 - wave)), lineWidth: 2)
                    .scaleEffect(1.0 + 0.12 * wave)
                    .blur(radius: 3)

                Capsule()
                    .stroke(Color.unbound.accent.opacity(0.3 * (1.0 - wave * 0.8)), lineWidth: 1)
                    .scaleEffect(1.0 + 0.22 * wave)
                    .blur(radius: 8)

                Button(action: awaken) {
                    HStack(spacing: 12) {
                        Text(L10n.onboarding("arcOpening.cta", defaultValue: "BEGIN YOUR ARC"))
                            .font(Font.unbound.bodyMStrong)
                            .tracking(2.2)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .black))
                    }
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.86),
                                        Color.unbound.accent.opacity(0.12),
                                        Color.black.opacity(0.88)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.unbound.accent.opacity(0.78), lineWidth: 1.5)
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 28)
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(buttonPulse ? 1.018 : 1.0)
                .shadow(color: Color.unbound.accent.opacity(0.32 + 0.42 * pulse),
                        radius: 18 + 14 * pulse, y: 0)
                .shadow(color: Color.unbound.impact.opacity(0.18 + 0.28 * pulse),
                        radius: 42 + 18 * pulse, y: 0)
            }
        }
        .frame(height: 82)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            auraText(L10n.string(.appName, defaultValue: "UNBOUND"), font: Font.unbound.displayXL, tracking: 4)

            Text(L10n.onboarding("arcOpening.tagline", defaultValue: "BREAK THE RESTRICTION"))
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.accent)
                .tracking(3.2)
                .textCase(.uppercase)
                .shadow(color: .black.opacity(0.9), radius: 10)
                .shadow(color: Color.unbound.accent.opacity(0.7), radius: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 72)
    }

    private func auraText(_ text: String, font: Font, tracking: CGFloat) -> some View {
        ZStack {
            Text(text)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(Color.unbound.accent.opacity(0.95))
                .blur(radius: 1.4)
                .scaleEffect(x: 1.018, y: 1.06)
                .shadow(color: Color.unbound.impact.opacity(0.85), radius: 22)

            Text(text)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.95), radius: 18, y: 4)
                .shadow(color: Color.unbound.accent.opacity(0.85), radius: 18)
                .shadow(color: Color.unbound.impact.opacity(0.48), radius: 34)
        }
    }

    private func awaken() {
        guard phase == .dormant else { return }
        UnboundHaptics.heavy()

        // Flash bridge — bloom in over ~120ms, held for 180ms, faded over
        // ~500ms. Visually "absorbs" the bust and "births" the video so
        // the cut never feels like a swap.
        withAnimation(.easeOut(duration: 0.12)) {
            flashOpacity = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.easeInOut(duration: 0.5)) {
                flashOpacity = 0
            }
        }

        withAnimation(.easeOut(duration: 0.6)) {
            phase = .awakening
        }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            await playSequence()
        }
    }

    @MainActor
    private func playSequence() async {
        player?.seek(to: .zero, completionHandler: { _ in })
        player?.volume = 0
        player?.play()
        // Volume ramp — climbs from 0 to `peakVolume` over 600ms in 50ms
        // steps. This smooths the audio drop-in so the opening bass hit
        // arrives as a rise, not a smack.
        rampVolume(to: Self.peakVolume, over: 0.6)

        // Eyes open / ignition (≈1.3s into the 5.06s video)
        try? await Task.sleep(nanoseconds: 1_300_000_000)
        UnboundHaptics.heavy()

        // Chain break / shockwave (≈2.8s)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        UnboundHaptics.heavy()

        // Hero-stance reveal (≈4.0s)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        UnboundHaptics.medium()

        // Hold through end of video (≈5.1s) before advancing.
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        phase = .complete
        onBegin()
    }

    private static func makePlayer() -> AVPlayer? {
        guard let url = Bundle.main.url(forResource: "openingintro", withExtension: "mp4") else {
            return nil
        }
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        player.volume = 0
        player.pause()
        return player
    }

    /// Steps the player volume from its current value to `target` over
    /// `duration` seconds in 50ms increments. Simple linear ramp — no
    /// external dependencies, no AVAudioSession ducking required. Silent
    /// no-op if the player is missing.
    private func rampVolume(to target: Float, over duration: TimeInterval) {
        guard let player else { return }
        let steps = max(1, Int(duration / 0.05))
        let start = player.volume
        let delta = (target - start) / Float(steps)
        for step in 1...steps {
            let when = DispatchTime.now() + .milliseconds(50 * step)
            DispatchQueue.main.asyncAfter(deadline: when) {
                player.volume = min(max(start + delta * Float(step), 0), 1)
            }
        }
    }
}

private struct CinematicVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {}
}

private final class PlayerHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

#Preview {
    Step_Arc01_Opening(onBegin: {})
}
