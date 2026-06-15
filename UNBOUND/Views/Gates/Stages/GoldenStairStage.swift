import SwiftUI

/// Gate VIII — The Last Gate (in-trial header). The golden stairway is the living stage:
/// each station logged lights the next landing climbing toward the radiant gate at the
/// summit, which brightens and blooms as the final ascent completes and the whole world
/// warms to gold. Logging stays the calm surface beneath; the stairway reacts to the spine.
struct GoldenStairStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var artAsset: String { world.stageAssetName }
    private var climbed: Int { max(0, min(stationsCleared, stationCount)) }
    private var progress: Double {
        guard stationCount > 0 else { return 0 }
        return Double(climbed) / Double(stationCount)
    }
    private var atTop: Bool { stationCount > 0 && climbed >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                stairway(size: size)
                summitGate(size: size)
                landings(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(climbed) of \(stationCount) landings.")
        .accessibilityIdentifier("gate-stage-landings")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func stairway(size: CGSize) -> some View {
        Image(artAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .saturation(0.85 + 0.55 * progress)
            .brightness(-0.14 + 0.26 * progress)
            .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                                    startPoint: .top, endPoint: .bottom))
    }

    /// The radiant gate at the summit brightens as the climb completes — a soft warm
    /// bloom that reinforces the gate already painted into the art (upper right).
    private func summitGate(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(world.fillTint)
                .frame(width: 140, height: 140)
                .blur(radius: 42)
                .opacity(0.10 + 0.5 * progress)
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .blur(radius: 20)
                .opacity(0.08 + 0.5 * progress)
                .scaleEffect(atTop && pulse && !reduceMotion ? 1.1 : 1)
        }
        .position(x: size.width * 0.72, y: size.height * 0.3)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// The landings — lit bottom-to-top toward the gate as each station is climbed.
    private func landings(size: CGSize) -> some View {
        let n = max(stationCount, 1)
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let t: Double = n == 1 ? 0 : Double(i) / Double(n - 1)
                let x: CGFloat = size.width * (0.24 + 0.26 * t)
                let y: CGFloat = size.height * (0.80 - 0.42 * t)
                let w: CGFloat = CGFloat(30 - 8 * t)
                let lit = i < climbed
                let isNext = i == climbed && !atTop
                Capsule()
                    .fill(lit ? world.fillTint : Color.white.opacity(isNext ? 0.22 : 0.10))
                    .frame(width: w, height: 5)
                    .shadow(color: lit ? world.fillTint.opacity(0.8) : .clear, radius: 6)
                    .scaleEffect(isNext && pulse && !reduceMotion ? 1.12 : 1)
                    .position(x: x, y: y)
            }
        }
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(world.trialName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                Text(atTop ? L10n.string(.gateLandingsChipDone, defaultValue: "OPEN") : L10n.format(.gateLandingsChipProgress, defaultValue: "%d/%d CLIMBED", climbed, stationCount))
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(atTop ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(atTop ? L10n.string(.gateLandingsTitleDone, defaultValue: "The last gate opens.") : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: climbed, tint: world.fillTint)
        }
        .padding(16)
    }
}
