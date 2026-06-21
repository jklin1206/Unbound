import SwiftUI

/// Gate I — First Light. A string of paper lanterns hangs across the bespoke night
/// courtyard; each station cleared lights the next lantern from within and warms the
/// whole world a step toward dawn, embers rising as it comes alive. Logging stays
/// calm beneath; the world is what reacts.
struct LanternCourtyardStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bespoke trial art (Codex image_gen, style-locked to the Novice banner).
    private var artAsset: String { world.stageAssetName }

    private var litCount: Int { max(0, min(stationsCleared, stationCount)) }
    private var litFraction: Double {
        guard stationCount > 0 else { return 0 }
        return Double(litCount) / Double(stationCount)
    }
    private var allLit: Bool { stationCount > 0 && litCount >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                courtyard(size: size)
                emberLayer(size: size)
                lanternString(size: size)
                titleOverlay
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(litCount) of \(stationCount) lanterns lit.")
        .accessibilityIdentifier("gate-stage-lanterns")
    }

    // MARK: - The courtyard, night → dawn

    private func courtyard(size: CGSize) -> some View {
        Image(artAsset)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .saturation(0.85 + 0.4 * litFraction)
            .brightness(0.30 * litFraction)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.unbound.emberGlow.opacity(0.32 * litFraction)],
                    startPoint: .center, endPoint: .bottom
                )
                .blendMode(.plusLighter)
            )
            .overlay(
                LinearGradient(
                    colors: [Color.unbound.emberGlow.opacity(0.14 * litFraction), .clear],
                    startPoint: .top, endPoint: .center
                )
                .blendMode(.plusLighter)
            )
            .overlay(
                LinearGradient(
                    colors: [.clear, .clear, Color.unbound.bg],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    // MARK: - Embers

    @ViewBuilder
    private func emberLayer(size: CGSize) -> some View {
        if litCount > 0 && !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { ctx, canvasSize in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let count = Int(Double(litCount) * 5)
                    for i in 0..<count {
                        let seed = Double(i) * 2.399963
                        let originX = (sin(seed) * 0.5 + 0.5)
                        let speed = 0.05 + (Double(i % 4) * 0.018)
                        let life = (t * speed + originX).truncatingRemainder(dividingBy: 1)
                        let drift = sin((t * 0.6) + seed) * 14
                        let x = originX * canvasSize.width + drift
                        let y = canvasSize.height * (0.86 - life * 0.66)
                        let fade = sin(life * .pi)
                        let r = 1.0 + (Double(i % 3) * 0.7)
                        var ember = Path()
                        ember.addEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                        ctx.fill(ember, with: .color(Color.unbound.emberGlow.opacity(0.5 * fade)))
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .blendMode(.plusLighter)
        }
    }

    // MARK: - The strung lanterns

    private func lanternString(size: CGSize) -> some View {
        let pts = lanternPoints(in: size)
        return ZStack(alignment: .topLeading) {
            // the cord the lanterns hang from
            if pts.count > 1 {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: pts[0].y - 21))
                    for pt in pts { p.addLine(to: CGPoint(x: pt.x, y: pt.y - 21)) }
                    p.addLine(to: CGPoint(x: size.width, y: pts[pts.count - 1].y - 21))
                }
                .stroke(Color.black.opacity(0.5), lineWidth: 1.5)
            }
            ForEach(0..<pts.count, id: \.self) { i in
                PaperLantern(
                    lit: i < litCount,
                    isNext: i == litCount && !allLit,
                    reduceMotion: reduceMotion,
                    swaySeed: Double(i)
                )
                .position(pts[i])
            }
        }
    }

    /// A gentle catenary sag across the upper courtyard.
    private func lanternPoints(in size: CGSize) -> [CGPoint] {
        let n = max(stationCount, 1)
        return (0..<n).map { i in
            let t = n == 1 ? 0.5 : Double(i) / Double(n - 1)
            let x = 0.13 + 0.74 * t
            let y = 0.30 + 0.075 * sin(t * .pi)   // hangs lower in the middle
            return CGPoint(x: x * size.width, y: y * size.height)
        }
    }

    // MARK: - Title + progress

    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(world.trialName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                Text(allLit ? L10n.string(.gateLanternsChipDone, defaultValue: "COURTYARD LIT") : L10n.format(.gateLanternsChipProgress, defaultValue: "%d/%d LIT", litCount, stationCount))
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(allLit ? Color.unbound.emberGlow : Color.unbound.textSecondary)
            }
            Text(allLit ? L10n.string(.gateLanternsTitleDone, defaultValue: "The courtyard is lit.") : currentStationTitle)
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
        }
        .padding(16)
    }
}

/// A hanging paper lantern (chōchin): warm paper body with ribs, a top fitting and a
/// tassel below. Lit glows from within and sways gently; unlit is dark dormant paper;
/// the next-to-light one carries a faint invite.
private struct PaperLantern: View {
    let lit: Bool
    let isNext: Bool
    let reduceMotion: Bool
    let swaySeed: Double

    @State private var glow = false
    @State private var sway = false

    var body: some View {
        VStack(spacing: 0) {
            // top fitting
            Capsule()
                .fill(Color.black.opacity(0.7))
                .frame(width: 7, height: 4)

            ZStack {
                if lit {
                    Circle()
                        .fill(Color.unbound.emberGlow)
                        .frame(width: 48, height: 48)
                        .blur(radius: 18)
                        .opacity(glow && !reduceMotion ? 0.9 : 0.6)
                } else if isNext {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 34, height: 34)
                        .blur(radius: 8)
                }
                lanternBody
            }

            // bottom fitting + tassel
            Capsule()
                .fill(Color.black.opacity(0.7))
                .frame(width: 4, height: 3)
            Rectangle()
                .fill(lit ? Color.unbound.emberGlow.opacity(0.85) : Color.white.opacity(0.16))
                .frame(width: 1.5, height: lit ? 7 : 5)
        }
        .rotationEffect(.degrees(sway && !reduceMotion ? 2.2 : -2.2), anchor: .top)
        .onAppear {
            guard !reduceMotion else { return }
            if lit {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { glow = true }
            }
            withAnimation(.easeInOut(duration: 2.4 + swaySeed.truncatingRemainder(dividingBy: 3) * 0.3)
                .repeatForever(autoreverses: true)) { sway = true }
        }
    }

    private var lanternBody: some View {
        Ellipse()
            .fill(
                lit
                    ? RadialGradient(
                        colors: [Color.white.opacity(0.95), Color.unbound.emberGlow, Color.unbound.emberGlow.opacity(0.7)],
                        center: .center, startRadius: 1, endRadius: 17)
                    : RadialGradient(
                        colors: [Color.white.opacity(isNext ? 0.16 : 0.09), Color.black.opacity(0.5)],
                        center: .center, startRadius: 1, endRadius: 17)
            )
            .frame(width: 25, height: 33)
            .overlay(
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(Color.black.opacity(lit ? 0.16 : 0.28)).frame(height: 1)
                    }
                }
                .padding(.horizontal, 3)
            )
            .overlay(
                Ellipse().strokeBorder(
                    lit ? Color.unbound.emberGlow.opacity(0.9) : Color.white.opacity(isNext ? 0.4 : 0.22),
                    lineWidth: 1)
            )
    }
}
