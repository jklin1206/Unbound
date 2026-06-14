import SwiftUI

/// Gate VIII — The Last Gate (in-trial header). The golden stairway is the living stage:
/// each station logged is a landing climbed, the radiant gate at the top brightening and
/// the whole world warming toward gold as the final ascent completes. Logging stays the
/// calm surface beneath; the stairway reacts to the one spine.
struct GoldenStairStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(climbed) of \(stationCount) landings.")
        .accessibilityIdentifier("gate-stage-landings")
    }

    private func stairway(size: CGSize) -> some View {
        Image(artAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .saturation(0.85 + 0.55 * progress)
            .brightness(-0.14 + 0.26 * progress)
            .overlay(
                RadialGradient(colors: [world.fillTint.opacity(0.55 * progress), .clear],
                               center: .init(x: 0.5, y: 0.22), startRadius: 6, endRadius: 220)
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
                Text(atTop ? "OPEN" : "\(climbed)/\(stationCount) CLIMBED")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(atTop ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(atTop ? "The last gate opens." : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: climbed, tint: world.fillTint)
        }
        .padding(16)
    }
}
