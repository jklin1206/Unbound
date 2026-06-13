import SwiftUI

/// Station-clear beat (spec §6.5): the world floods back full-bleed, one line of
/// copy, a signature haptic, then recedes. Reduced-motion shows a brief flash.
struct GateBeatOverlay: View {
    let world: GateWorld
    let stationTitle: String
    var onFinished: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var line: String { "\(stationTitle) — \(world.beatVerb)." }

    var body: some View {
        ZStack {
            Image(world.bannerAssetName).resizable().scaledToFill().ignoresSafeArea()
                .overlay(world.fillTint.opacity(0.18)).overlay(Color.black.opacity(0.32))
            Text(line.uppercased()).font(Font.unbound.titleM.weight(.black)).tracking(1.5)
                .foregroundStyle(Color.unbound.textPrimary).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .opacity(shown ? 1 : 0)
        .task { await play() }
        .accessibilityIdentifier("gate-beat-overlay")
    }

    private func play() async {
        UnboundHaptics.success()
        withAnimation(.easeOut(duration: reduceMotion ? 0.05 : 0.28)) { shown = true }
        try? await Task.sleep(nanoseconds: reduceMotion ? 400_000_000 : 1_100_000_000)
        withAnimation(.easeIn(duration: 0.3)) { shown = false }
        try? await Task.sleep(nanoseconds: 320_000_000)
        onFinished?()
    }
}
