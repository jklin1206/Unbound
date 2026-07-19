import SwiftUI

/// Gate V — The Ascent (in-trial header). The literal temple tower is the living stage:
/// its painted tiers ignite from base to summit while the ten narrative floors fill on
/// the rail. Logging stays on the shared workout spine beneath this gate-specific world.
struct AscentTowerStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let towerAsset = "gate_tower_master"

    private var climbed: Int { max(0, min(stationsCleared, stationCount)) }

    /// The prescription has eleven stations because Floor 9 contains both a push and a
    /// pull. Story progress remains the promised ten-floor ascent: Floor 9 lights only
    /// after both halves clear.
    private var narrativeFloorCount: Int {
        stationCount == 11 ? 10 : max(stationCount, 1)
    }

    private var narrativeFloorsClimbed: Int {
        guard stationCount == 11 else {
            return min(climbed, narrativeFloorCount)
        }
        if climbed <= 8 { return climbed }
        return min(climbed - 1, narrativeFloorCount)
    }

    private var activeNarrativeFloor: Int {
        min(narrativeFloorsClimbed + 1, narrativeFloorCount)
    }

    private var altitude: Double {
        Double(narrativeFloorsClimbed) / Double(narrativeFloorCount)
    }

    private var atSummit: Bool { stationCount > 0 && climbed >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                atmosphericBackdrop(size: size)
                dormantTower(size: size)
                litTowerTiers(size: size)
                riseMotes(size: size)
                summitBeacon(size: size)
                narrativeFloorRail(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 430)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(world.trialName). \(narrativeFloorsClimbed) of \(narrativeFloorCount) floors climbed."
        )
        .accessibilityIdentifier("gate-stage-ascent")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func atmosphericBackdrop(size: CGSize) -> some View {
        Image(towerAsset)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 18)
            .scaleEffect(1.08)
            .brightness(-0.46 + 0.12 * altitude)
            .saturation(0.72 + 0.25 * altitude)
            .overlay(Color.unbound.bg.opacity(0.36))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.unbound.bg.opacity(0.28),
                        .clear,
                        Color.unbound.bg.opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }

    private func dormantTower(size: CGSize) -> some View {
        Image(towerAsset)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .brightness(-0.25 + 0.08 * altitude)
            .saturation(0.86)
            .contrast(1.06)
            .overlay(
                LinearGradient(
                    colors: [.clear, .clear, Color.unbound.bg.opacity(0.52)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }

    /// Reuses the measured pagoda-tier masks from the original tower experience.
    /// Ten story floors feed six painted architectural tiers; the adjacent rail still
    /// advances on every narrative floor so progress never appears to stall.
    private func litTowerTiers(size: CGSize) -> some View {
        ZStack {
            ForEach(Self.tierBands.indices, id: \.self) { index in
                let band = Self.tierBands[index]
                if narrativeFloorsClimbed >= band.floorThreshold {
                    Image(towerAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .brightness(0.12)
                        .saturation(1.56)
                        .overlay(world.fillTint.opacity(0.14).blendMode(.plusLighter))
                        .mask(LiveAscentTierGlowMask(size: size, band: band))
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
        }
        .shadow(color: world.fillTint.opacity(0.18 + 0.22 * altitude), radius: 18)
        .allowsHitTesting(false)
    }

    private func summitBeacon(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(world.fillTint)
                .frame(width: atSummit ? 96 : 72, height: atSummit ? 96 : 72)
                .blur(radius: atSummit ? 34 : 26)
                .opacity(0.10 + 0.70 * altitude)
            Circle()
                .fill(Color.white)
                .frame(width: atSummit ? 11 : 7, height: atSummit ? 11 : 7)
                .blur(radius: 2)
                .opacity(atSummit ? 0.92 : 0.18 * altitude)
        }
        .scaleEffect(atSummit && pulse && !reduceMotion ? 1.08 : 1)
        .position(x: size.width * 0.5, y: size.height * 0.075)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    private func narrativeFloorRail(size: CGSize) -> some View {
        LiveAscentFloorRail(
            total: narrativeFloorCount,
            filled: narrativeFloorsClimbed,
            tint: world.fillTint,
            pulse: pulse && !reduceMotion
        )
        .frame(width: 66, height: size.height * 0.62)
        .position(x: size.width - 37, y: size.height * 0.45)
        .allowsHitTesting(false)
    }

    /// Motes drifting up the spine while the climb is underway.
    @ViewBuilder
    private func riseMotes(size: CGSize) -> some View {
        if narrativeFloorsClimbed > 0 && !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, canvasSize in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let count = narrativeFloorsClimbed * 4
                    let cx = canvasSize.width * 0.5
                    for i in 0..<count {
                        let seed = Double(i) * 2.399963
                        let life = (t * (0.16 + Double(i % 4) * 0.04) + seed).truncatingRemainder(dividingBy: 1)
                        let x = cx + sin(t * 0.7 + seed) * 26
                        let y = canvasSize.height * (0.88 - life * 0.72)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("THE TOWER")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(world.tint)
                    Text("FLOOR \(activeNarrativeFloor) OF \(narrativeFloorCount)")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer(minLength: 0)
                Text(
                    atSummit
                        ? L10n.string(.gateAscentChipDone, defaultValue: "SUMMIT")
                        : L10n.format(
                            .gateAscentChipProgress,
                            defaultValue: "%d/%d CLIMBED",
                            narrativeFloorsClimbed,
                            narrativeFloorCount
                        )
                )
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(atSummit ? world.fillTint : Color.unbound.textSecondary)
            }

            Spacer(minLength: 0)

            Text(atSummit ? L10n.string(.gateAscentTitleDone, defaultValue: "The temple opens.") : currentStationTitle)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
                .padding(.bottom, 10)

            GateStationRail(
                total: narrativeFloorCount,
                filled: narrativeFloorsClimbed,
                tint: world.fillTint
            )
        }
        .padding(16)
    }

    private static let tierBands: [LiveAscentTierBand] = [
        .init(floorThreshold: 1, topY: 0.6470, bottomY: 0.7749, widthFrac: 0.92, topFeather: 0.008, bottomFeather: 0.026),
        .init(floorThreshold: 3, topY: 0.5342, bottomY: 0.6499, widthFrac: 0.84, topFeather: 0.008, bottomFeather: 0.022),
        .init(floorThreshold: 5, topY: 0.4331, bottomY: 0.5371, widthFrac: 0.76, topFeather: 0.007, bottomFeather: 0.020),
        .init(floorThreshold: 7, topY: 0.3413, bottomY: 0.4346, widthFrac: 0.69, topFeather: 0.006, bottomFeather: 0.018),
        .init(floorThreshold: 9, topY: 0.2630, bottomY: 0.3442, widthFrac: 0.61, topFeather: 0.004, bottomFeather: 0.016),
        .init(floorThreshold: 10, topY: 0.1733, bottomY: 0.2554, widthFrac: 0.53, topFeather: 0.005, bottomFeather: 0.014)
    ]
}

private struct LiveAscentFloorRail: View {
    let total: Int
    let filled: Int
    let tint: Color
    let pulse: Bool

    var body: some View {
        GeometryReader { proxy in
            let step = proxy.size.height / CGFloat(max(total, 1))

            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .position(x: proxy.size.width - 8, y: proxy.size.height / 2)

                ForEach(0..<max(total, 1), id: \.self) { floor in
                    let isLit = floor < filled
                    let isNext = floor == filled && filled < total
                    let y = proxy.size.height - step * (CGFloat(floor) + 0.5)

                    HStack(spacing: 6) {
                        Text(Self.floorLabel(floor + 1))
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(isLit || isNext ? tint : Color.unbound.textTertiary)
                            .frame(width: 18, alignment: .trailing)

                        Capsule()
                            .fill(isLit ? tint : Color.white.opacity(isNext ? 0.24 : 0.10))
                            .frame(width: isLit || isNext ? 30 : 22, height: isLit ? 5 : 4)
                            .shadow(color: isLit ? tint.opacity(0.78) : .clear, radius: 7)
                            .scaleEffect(isNext && pulse ? 1.12 : 1)
                    }
                    .frame(width: proxy.size.width, alignment: .trailing)
                    .position(x: proxy.size.width / 2, y: y)
                }
            }
        }
    }

    private static func floorLabel(_ floor: Int) -> String {
        floor < 10 ? "0\(floor)" : "\(floor)"
    }
}

private struct LiveAscentTierBand {
    let floorThreshold: Int
    let topY: CGFloat
    let bottomY: CGFloat
    let widthFrac: CGFloat
    let topFeather: CGFloat
    let bottomFeather: CGFloat
}

private struct LiveAscentTierGlowMask: View {
    let size: CGSize
    let band: LiveAscentTierBand

    var body: some View {
        let top = size.height * band.topY
        let bottom = size.height * band.bottomY
        let topFeather = size.height * band.topFeather
        let bottomFeather = size.height * band.bottomFeather
        let bandHeight = max(1, bottom - top)
        let maskHeight = topFeather + bandHeight + bottomFeather
        let maskTop = top - topFeather

        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                .frame(height: topFeather)
            Rectangle()
                .fill(.white)
                .frame(height: bandHeight)
            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: bottomFeather)
        }
        .frame(width: size.width * band.widthFrac, height: maskHeight)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.18),
                    .init(color: .white, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .blur(radius: 5)
        .position(x: size.width / 2, y: maskTop + maskHeight / 2)
    }
}
