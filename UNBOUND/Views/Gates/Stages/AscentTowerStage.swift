import SwiftUI

/// Gate V — The Ascent (in-trial header). The bespoke temple world is the living stage:
/// a tower spine climbs the frame and each floor logged lights its landing while the
/// light front rises and motes drift up toward the summit gate, which glows once the
/// climb tops out. Logging stays the calm surface beneath; the climb reacts to the spine.
struct AscentTowerStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var artAsset: String { world.stageAssetName }
    private var climbed: Int { max(0, min(stationsCleared, stationCount)) }
    private var altitude: Double {
        guard stationCount > 0 else { return 0 }
        return Double(climbed) / Double(stationCount)
    }
    private var atSummit: Bool { stationCount > 0 && climbed >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                temple(size: size)
                riseMotes(size: size)
                towerFloors(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(climbed) of \(stationCount) floors climbed.")
        .accessibilityIdentifier("gate-stage-ascent")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func temple(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            Image(artAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(-0.16 + 0.24 * altitude)
                .saturation(0.85 + 0.5 * altitude)

            // the light front rising from the base with the climb
            LinearGradient(colors: [world.fillTint.opacity(0.45 * altitude), .clear],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: size.height * (0.12 + 0.82 * altitude))
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .overlay(summitGlow(size: size))
        .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                                startPoint: .top, endPoint: .bottom))
    }

    private func summitGlow(size: CGSize) -> some View {
        Circle()
            .fill(world.fillTint)
            .frame(width: 140, height: 140)
            .blur(radius: 42)
            .opacity(0.12 + 0.5 * altitude)
            .scaleEffect(atSummit && pulse && !reduceMotion ? 1.06 : 1)
            .position(x: size.width * 0.5, y: size.height * 0.18)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// The tower floors — landing ticks up the spine, lit base-to-summit as floors clear.
    private func towerFloors(size: CGSize) -> some View {
        let n = max(stationCount, 1)
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let t: Double = n == 1 ? 0 : Double(i) / Double(n - 1)
                let y: CGFloat = size.height * (0.78 - 0.52 * t)
                let lit = i < climbed
                let isNext = i == climbed && !atSummit
                Capsule()
                    .fill(lit ? world.fillTint : Color.white.opacity(isNext ? 0.22 : 0.10))
                    .frame(width: 26, height: 4)
                    .shadow(color: lit ? world.fillTint.opacity(0.8) : .clear, radius: 6)
                    .scaleEffect(isNext && pulse && !reduceMotion ? 1.14 : 1)
                    .position(x: size.width * 0.5, y: y)
            }
        }
    }

    /// Motes drifting up the spine while the climb is underway.
    @ViewBuilder
    private func riseMotes(size: CGSize) -> some View {
        if climbed > 0 && !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, canvasSize in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let count = Int(Double(climbed) * 4)
                    let cx = canvasSize.width * 0.5
                    for i in 0..<count {
                        let seed = Double(i) * 2.399963
                        let life = (t * (0.16 + Double(i % 4) * 0.04) + seed).truncatingRemainder(dividingBy: 1)
                        let x = cx + sin(t * 0.7 + seed) * 26
                        let y = canvasSize.height * (0.82 - life * 0.64)
                        let fade = sin(life * .pi)
                        let r = 0.8 + Double(i % 3) * 0.6
                        var mote = Path()
                        mote.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                        ctx.fill(mote, with: .color(world.fillTint.opacity(0.7 * fade)))
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
        }
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(world.trialName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                Text(atSummit ? L10n.string(.gateAscentChipDone, defaultValue: "SUMMIT") : L10n.format(.gateAscentChipProgress, defaultValue: "%d/%d CLIMBED", climbed, stationCount))
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(atSummit ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(atSummit ? L10n.string(.gateAscentTitleDone, defaultValue: "The temple opens.") : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: climbed, tint: world.fillTint)
        }
        .padding(16)
    }
}
