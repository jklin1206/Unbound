import SwiftUI

/// Gate VII — The Threshold (in-trial header). The sealed ascendant gate is the living
/// stage: a thin seam of light at the start that widens and blazes brighter with every
/// logged station across the siege, the only gate whose world opens end to end. Logging
/// stays the calm surface beneath; the portal reacts to the one spine.
struct BreachGateStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var artAsset: String { world.stageAssetName }
    private var breached: Int { max(0, min(stationsCleared, stationCount)) }
    private var openness: Double {
        guard stationCount > 0 else { return 0 }
        return Double(breached) / Double(stationCount)
    }
    private var fullyOpen: Bool { stationCount > 0 && breached >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                gate(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(breached) of \(stationCount) breached.")
        .accessibilityIdentifier("gate-stage-siege")
    }

    private func gate(size: CGSize) -> some View {
        ZStack {
            Image(artAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(-0.12 + 0.18 * openness)

            // the portal seam widening as the siege presses in
            Capsule()
                .fill(LinearGradient(colors: [world.fillTint.opacity(0), world.fillTint, .white, world.fillTint, world.fillTint.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: max(3, size.width * (0.015 + 0.16 * openness)), height: size.height * 0.74)
                .blur(radius: 12)
                .position(x: size.width * 0.5, y: size.height * 0.46)
                .opacity(0.55 + 0.45 * openness)
                .blendMode(.plusLighter)
        }
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
                Text(fullyOpen ? L10n.string(.gateSiegeChipDone, defaultValue: "OPEN") : L10n.format(.gateSiegeChipProgress, defaultValue: "%d/%d BREACHED", breached, stationCount))
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(fullyOpen ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(fullyOpen ? L10n.string(.gateSiegeTitleDone, defaultValue: "The portal stands open.") : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: breached, tint: world.fillTint)
        }
        .padding(16)
    }
}
