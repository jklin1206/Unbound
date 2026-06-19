import SwiftUI
import AVFoundation

/// Plays a bundled gate Crossing clip (Seedance i2v, with audio) as the "walk"
/// beat of The Crossing (spec §8: "camera pushes through the threshold into the
/// world"). scaledToFill, plays once, fires `onFinished` at the end. Reduced-motion
/// never reaches here — TheCrossingView picks the Ken Burns still fallback instead.
struct CrossingClipLayer: View {
    let url: URL
    var onFinished: () -> Void = {}

    @State private var player = AVPlayer()

    var body: some View {
        CrossingPlayerHost(player: player)
            .onAppear { start() }
            .onDisappear { player.pause() }
    }

    private func start() {
        // A rank-up crossing should be heard even with the ringer silenced.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in onFinished() }

        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        player.volume = 1
        player.play()
    }
}

private struct CrossingPlayerHost: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> Host {
        let view = Host()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: Host, context: Context) {}

    final class Host: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
