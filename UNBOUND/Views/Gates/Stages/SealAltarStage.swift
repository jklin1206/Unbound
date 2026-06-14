import SwiftUI

/// Gate VI — The Seven Seals (in-trial header). The bespoke vessel altar is the living
/// stage: each attribute station logged shatters one seal on the ritual rail and feeds
/// the chalice flame, which grows brighter as the seals fall. Logging stays the calm
/// surface beneath; the world is what reacts to the one spine.
struct SealAltarStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var artAsset: String { world.stageAssetName }
    private var brokenCount: Int { max(0, min(stationsCleared, stationCount)) }
    private var brokenFraction: Double {
        guard stationCount > 0 else { return 0 }
        return Double(brokenCount) / Double(stationCount)
    }
    private var allBroken: Bool { stationCount > 0 && brokenCount >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                altar(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(brokenCount) of \(stationCount) seals broken.")
        .accessibilityIdentifier("gate-stage-seals")
    }

    private func altar(size: CGSize) -> some View {
        Image(artAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .saturation(0.9 + 0.5 * brokenFraction)
            .brightness(0.10 * brokenFraction)
            .overlay(
                RadialGradient(colors: [world.fillTint.opacity(0.5 * brokenFraction), .clear],
                               center: .init(x: 0.5, y: 0.52), startRadius: 4, endRadius: 200)
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
                Text(allBroken ? "SEALED" : "\(brokenCount)/\(stationCount) BROKEN")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(allBroken ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(allBroken ? "The vessel is filled." : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: brokenCount, tint: world.fillTint)
        }
        .padding(16)
    }
}
