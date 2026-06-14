import SwiftUI

/// Gate V — The Ascent (in-trial header). The bespoke temple world is the living stage:
/// the light front rises from the base toward the summit a floor at a time as each floor
/// is logged, the world brightening with altitude until the summit gate glows. Logging
/// stays the calm surface beneath; the climb reacts to the one spine.
struct AscentTowerStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(climbed) of \(stationCount) floors climbed.")
        .accessibilityIdentifier("gate-stage-ascent")
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
        .overlay(
            RadialGradient(colors: [world.fillTint.opacity(0.5 * altitude), .clear],
                           center: .init(x: 0.5, y: 0.18), startRadius: 6, endRadius: 200)
            .blendMode(.plusLighter)
        )
        .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                                startPoint: .top, endPoint: .bottom))
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(world.trialName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                Text(atSummit ? "SUMMIT" : "\(climbed)/\(stationCount) CLIMBED")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(atSummit ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(atSummit ? "The temple opens." : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: climbed, tint: world.fillTint)
        }
        .padding(16)
    }
}
