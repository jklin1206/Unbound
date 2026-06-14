import SwiftUI

/// Gate III — The Forging. The bespoke smithy is the living stage: a blade rests on
/// the anvil and takes heat with every strike cleared — dark steel → cherry → white-
/// hot — sparks flying, the forge brightening; the final station quenches it to a
/// forged edge. Logging stays calm beneath; the world is what reacts.
struct ForgeStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var artAsset: String { world.stageAssetName }

    private var litCount: Int { max(0, min(stationsCleared, stationCount)) }
    private var allLit: Bool { stationCount > 0 && litCount >= stationCount }

    /// Heat ramps over the working strikes; the last station is the quench (cools).
    private var heat: Double {
        guard stationCount > 1 else { return litCount > 0 ? 1 : 0 }
        let strikes = stationCount - 1
        return min(1, Double(min(litCount, strikes)) / Double(strikes))
    }
    private var quenched: Bool { allLit }
    private var displayHeat: Double { quenched ? 0.35 : heat }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                forge(size: size)
                sparkLayer(size: size)
                blade(size: size)
                if quenched { steam(size: size) }
                titleOverlay
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(litCount) of \(stationCount) strikes.")
        .accessibilityIdentifier("gate-stage-forge")
    }

    // MARK: - The smithy, warming with the work

    private func forge(size: CGSize) -> some View {
        Image(artAsset)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .saturation(0.9 + 0.45 * displayHeat)
            .brightness(0.18 * displayHeat)
            .overlay(
                RadialGradient(
                    colors: [world.fillTint.opacity(0.34 * displayHeat), .clear],
                    center: .init(x: 0.47, y: 0.6), startRadius: 6, endRadius: 220)
                .blendMode(.plusLighter)
            )
            .overlay(
                LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                               startPoint: .top, endPoint: .bottom)
            )
    }

    // MARK: - Sparks (fly off the blade while it's hot)

    @ViewBuilder
    private func sparkLayer(size: CGSize) -> some View {
        if displayHeat > 0.05 && !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, canvasSize in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let count = Int(6 + displayHeat * 22)
                    let cx = canvasSize.width * 0.47
                    let cy = canvasSize.height * 0.585
                    for i in 0..<count {
                        let seed = Double(i) * 2.399963
                        let life = (t * (0.5 + Double(i % 5) * 0.12) + seed).truncatingRemainder(dividingBy: 1)
                        let angle = -Double.pi / 2 + sin(seed) * 0.9
                        let dist = life * (40 + Double(i % 6) * 12)
                        let x = cx + cos(angle) * dist + sin(seed * 3) * 30
                        let y = cy + sin(angle) * dist
                        let fade = (1 - life)
                        let r = 0.8 + Double(i % 3) * 0.6
                        var spark = Path()
                        spark.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                        ctx.fill(spark, with: .color(world.fillTint.opacity(0.8 * fade)))
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
        }
    }

    // MARK: - The blade on the anvil

    private func blade(size: CGSize) -> some View {
        let center = CGPoint(x: size.width * 0.47, y: size.height * 0.585)
        let bladeW = size.width * 0.30
        return ZStack {
            // heat halo
            Capsule()
                .fill(world.fillTint)
                .frame(width: bladeW * 1.1, height: 26)
                .blur(radius: 22)
                .opacity(0.7 * displayHeat)

            // the blade: dark steel, glowing with heat, white-hot at peak
            ZStack(alignment: .leading) {
                // handle / tang
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: bladeW * 0.26, height: 7)
                // blade body
                bladeBody(width: bladeW)
            }
            .frame(width: bladeW, alignment: .leading)
        }
        .rotationEffect(.degrees(-5))
        .position(x: center.x, y: center.y)
    }

    private func bladeBody(width: CGFloat) -> some View {
        Capsule()
            .fill(Color(white: 0.16))                         // dark steel base
            .overlay(Capsule().fill(world.fillTint).opacity(min(1, displayHeat * 1.2)))  // heat
            .overlay(Capsule().fill(Color.white).opacity(max(0, displayHeat - 0.6) * 2.4)) // white-hot
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18 + 0.3 * displayHeat), lineWidth: 0.8))
            .frame(width: width, height: 9)
            .offset(x: width * 0.13)
            .shadow(color: world.fillTint.opacity(0.6 * displayHeat), radius: 6)
    }

    // MARK: - Quench steam

    private func steam(size: CGSize) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { ctx, canvasSize in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let cx = canvasSize.width * 0.47
                let cy = canvasSize.height * 0.585
                for i in 0..<10 {
                    let seed = Double(i) * 1.7
                    let life = (t * 0.22 + seed).truncatingRemainder(dividingBy: 1)
                    let x = cx + sin(seed * 2 + t) * 30 + Double(i - 5) * 6
                    let y = cy - life * 60
                    let fade = sin(life * .pi) * 0.4
                    let r = 4 + life * 10
                    var puff = Path()
                    puff.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                    ctx.fill(puff, with: .color(Color.white.opacity(fade)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
        .blur(radius: 3)
    }

    // MARK: - Title + progress

    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(world.trialName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                Text(quenched ? "QUENCHED" : "\(litCount)/\(stationCount) STRUCK")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(quenched ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(quenched ? "The steel holds." : currentStationTitle)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
        }
        .padding(16)
    }
}
