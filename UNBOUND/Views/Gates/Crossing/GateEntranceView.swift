import SwiftUI

/// The entrance cinematic — walking INTO the gate's world when a trial begins
/// (the Seedance entrance clip + the gate title fading in), then hands off to the
/// trial. Tap to skip. Reduced-motion / missing clip → a brief still hold.
struct GateEntranceView: View {
    let crossing: GateCrossing
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleShown = false

    private var clipURL: URL? { CrossingAssetResolver.entranceClipURL(for: crossing) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = clipURL, !reduceMotion {
                CrossingClipLayer(url: url, onFinished: onFinished).ignoresSafeArea()
            } else {
                Image(CrossingAssetResolver.thresholdStill(for: crossing))
                    .resizable().scaledToFill().ignoresSafeArea().clipped()
                    .overlay(Color.black.opacity(0.4).ignoresSafeArea())
            }

            LinearGradient(colors: [.clear, .clear, Color.black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 10) {
                Spacer()
                if titleShown {
                    Text("RANK GATE \(crossing.world.numeral)")
                        .font(Font.unbound.captionS.weight(.heavy)).tracking(4)
                        .foregroundStyle(crossing.tint)
                        .shadow(color: .black.opacity(0.85), radius: 4, y: 1)
                    Text(crossing.world.trialName.uppercased())
                        .font(.system(size: 40, weight: .black)).tracking(3)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.7), radius: 8, y: 2)
                        .shadow(color: crossing.fillTint.opacity(0.5), radius: 26)
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 96)
            .transition(.opacity)
        }
        .contentShape(Rectangle())
        .onTapGesture { onFinished() }   // tap to skip
        .task {
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) { titleShown = true }
            if clipURL == nil || reduceMotion {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                onFinished()
            }
        }
        .accessibilityIdentifier("gate-entrance")
    }
}
