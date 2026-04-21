import SwiftUI
import AVKit

struct Step_Arc01_Opening: View {
    let onBegin: () -> Void

    @State private var phase: Phase = .dormant
    @State private var player: AVPlayer? = Self.makePlayer()
    @State private var buttonPulse = false

    enum Phase { case dormant, awakening, complete }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                CinematicVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .opacity(phase == .dormant ? 0 : 1)
                    .animation(.easeIn(duration: 0.35), value: phase)
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
                        .padding(.bottom, 32)
                        .transition(.opacity.combined(with: .offset(y: 60)))
                }
            }
        }
        .statusBarHidden()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            player?.seek(to: .zero, completionHandler: { _ in })
            player?.pause()
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

    // Loose-file loader for the WebP dormant bust asset. SwiftUI's
    // `Image("name")` only resolves Asset Catalog entries; the bust lives in
    // Resources/BodyMap/dormant_bust.webp as a raw file, so we bridge through
    // UIImage which handles WebP natively on iOS 14+.
    private static let dormantBustImage: UIImage? = {
        guard let url = Bundle.main.url(forResource: "dormant_bust", withExtension: "webp") else {
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
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.unbound.accent.opacity(0.55 * (1.0 - wave)), lineWidth: 2)
                    .scaleEffect(1.0 + 0.12 * wave)
                    .blur(radius: 2)

                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.unbound.accent.opacity(0.3 * (1.0 - wave * 0.8)), lineWidth: 1)
                    .scaleEffect(1.0 + 0.22 * wave)
                    .blur(radius: 6)

                UnboundButton(title: "Break the Restriction", action: awaken)
                    .scaleEffect(buttonPulse ? 1.02 : 1.0)
                    .shadow(color: Color.unbound.accent.opacity(0.35 + 0.45 * pulse),
                            radius: 18 + 14 * pulse, y: 0)
                    .shadow(color: Color.unbound.impact.opacity(0.2 + 0.3 * pulse),
                            radius: 44 + 20 * pulse, y: 0)
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text("UNBOUND")
                .font(Font.unbound.displayXL)
                .foregroundStyle(Color.unbound.textPrimary)
                .tracking(4)
                .shadow(color: .black.opacity(0.9), radius: 18, y: 4)
                .animeGlow(color: Color.unbound.accent, radius: 22, intensity: 0.85)

            Text("your arc starts now")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary.opacity(0.85))
                .tracking(1.4)
                .shadow(color: .black.opacity(0.9), radius: 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 72)
    }

    private func awaken() {
        guard phase == .dormant else { return }
        UnboundHaptics.heavy()
        withAnimation(.easeOut(duration: 0.4)) {
            phase = .awakening
        }
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            await playSequence()
        }
    }

    @MainActor
    private func playSequence() async {
        player?.seek(to: .zero, completionHandler: { _ in })
        player?.play()

        try? await Task.sleep(nanoseconds: 1_300_000_000)
        UnboundHaptics.heavy()

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        UnboundHaptics.medium()

        try? await Task.sleep(nanoseconds: 400_000_000)
        phase = .complete
        onBegin()
    }

    private static func makePlayer() -> AVPlayer? {
        guard let url = Bundle.main.url(forResource: "arc01_opening", withExtension: "mp4") else {
            return nil
        }
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        player.pause()
        return player
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
