import SwiftUI

/// Gate VII — The Threshold (in-trial header). The sealed ascendant gate is the living
/// stage: a thin seam of light at the start that widens and blazes brighter with every
/// logged station, throwing light rays and drawing motes up through the breach until the
/// portal stands open end to end. Logging stays the calm surface beneath.
struct BreachGateStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

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
                breachMotes(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(breached) of \(stationCount) breached.")
        .accessibilityIdentifier("gate-stage-siege")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func gate(size: CGSize) -> some View {
        let coreX = size.width * 0.5
        let coreY = size.height * 0.46
        return ZStack {
            Image(artAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(-0.14 + 0.20 * openness)

            // light rays fanning out from the breach as it opens
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [world.fillTint.opacity(0.5 * openness), .clear],
                                         startPoint: .bottom, endPoint: .top))
                    .frame(width: 5 + CGFloat(openness) * 4, height: size.height * (0.4 + 0.3 * openness))
                    .blur(radius: 6)
                    .rotationEffect(.degrees(Double(i - 3) * 12))
                    .position(x: coreX, y: coreY)
                    .opacity((0.3 + 0.7 * openness) * (pulse && !reduceMotion ? 1 : 0.7))
                    .blendMode(.plusLighter)
            }

            // the portal seam itself, widening and blazing white at the core
            Capsule()
                .fill(LinearGradient(colors: [world.fillTint.opacity(0), world.fillTint, .white, world.fillTint, world.fillTint.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: max(3, size.width * (0.015 + 0.18 * openness)), height: size.height * 0.74)
                .blur(radius: 10)
                .position(x: coreX, y: coreY)
                .opacity(0.6 + 0.4 * openness)
                .blendMode(.plusLighter)
        }
        .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                                startPoint: .top, endPoint: .bottom))
    }

    /// Motes drawn up through the breach — more of them, faster, as the portal opens.
    @ViewBuilder
    private func breachMotes(size: CGSize) -> some View {
        if openness > 0.02 && !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, canvasSize in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let count = Int(4 + openness * 20)
                    let cx = canvasSize.width * 0.5
                    for i in 0..<count {
                        let seed = Double(i) * 2.399963
                        let life = (t * (0.18 + Double(i % 4) * 0.05) + seed).truncatingRemainder(dividingBy: 1)
                        let spread = (sin(seed) * 0.5) * canvasSize.width * (0.04 + 0.10 * openness)
                        let x = cx + spread + sin(t + seed) * 5
                        let y = canvasSize.height * (0.82 - life * 0.7)
                        let fade = sin(life * .pi)
                        let r = 0.8 + Double(i % 3) * 0.7
                        var mote = Path()
                        mote.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                        ctx.fill(mote, with: .color(world.fillTint.opacity(0.75 * fade)))
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
