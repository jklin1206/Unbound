import SwiftUI

/// Gate VI — The Seven Seals (in-trial header). The bespoke vessel altar is the living
/// stage: a ring of wax seals guards the chalice, and each attribute station logged
/// shatters the next seal while the chalice flame climbs and brightens. Logging stays
/// the calm surface beneath; the world is what reacts to the one spine.
struct SealAltarStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flicker = false

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
                chaliceFlame(size: size)
                sealRail(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(brokenCount) of \(stationCount) seals broken.")
        .accessibilityIdentifier("gate-stage-seals")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { flicker = true }
        }
    }

    private func altar(size: CGSize) -> some View {
        Image(artAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .saturation(0.9 + 0.5 * brokenFraction)
            .brightness(0.10 * brokenFraction)
            .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                                    startPoint: .top, endPoint: .bottom))
    }

    /// The chalice flame at the altar's heart — taller and brighter as the seals fall.
    private func chaliceFlame(size: CGSize) -> some View {
        let h = size.height * (0.12 + 0.30 * brokenFraction)
        return ZStack {
            Circle()
                .fill(world.fillTint)
                .frame(width: 130, height: 130)
                .blur(radius: 36)
                .opacity(0.16 + 0.42 * brokenFraction)
            FlameShape()
                .fill(LinearGradient(colors: [world.fillTint, .white.opacity(0.92)],
                                     startPoint: .bottom, endPoint: .top))
                .frame(width: h * 0.6, height: h)
                .scaleEffect(y: flicker && !reduceMotion ? 1.07 : 0.93, anchor: .bottom)
                .opacity(0.5 + 0.5 * brokenFraction)
                .shadow(color: world.fillTint.opacity(0.85), radius: 12)
        }
        .position(x: size.width * 0.5, y: size.height * 0.6)
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }

    /// The seals on the ritual rail — each station logged shatters the next.
    private func sealRail(size: CGSize) -> some View {
        let n = max(stationCount, 1)
        return ZStack {
            ForEach(0..<n, id: \.self) { i in
                let t: Double = n == 1 ? 0.5 : Double(i) / Double(n - 1)
                let x: CGFloat = size.width * (0.19 + 0.62 * t)
                SealSigil(
                    broken: i < brokenCount,
                    isNext: i == brokenCount && !allBroken,
                    tint: world.fillTint,
                    flicker: flicker,
                    reduceMotion: reduceMotion
                )
                .position(x: x, y: size.height * 0.29)
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
                Text(allBroken ? L10n.string(.gateSealsChipDone, defaultValue: "SEALED") : L10n.format(.gateSealsChipProgress, defaultValue: "%d/%d BROKEN", brokenCount, stationCount))
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(allBroken ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(allBroken ? L10n.string(.gateSealsTitleDone, defaultValue: "The vessel is filled.") : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: brokenCount, tint: world.fillTint)
        }
        .padding(16)
    }
}

/// A single wax seal on the rail: intact seals glow with a ringed sigil and pulse;
/// the next-to-break carries a brighter invite; broken seals split into two dim halves.
private struct SealSigil: View {
    let broken: Bool
    let isNext: Bool
    let tint: Color
    let flicker: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            if broken {
                // two fallen halves
                ForEach(0..<2, id: \.self) { half in
                    Circle()
                        .trim(from: half == 0 ? 0 : 0.5, to: half == 0 ? 0.5 : 1)
                        .stroke(tint.opacity(0.28), lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .offset(x: half == 0 ? -3 : 3, y: half == 0 ? 2 : 3)
                        .rotationEffect(.degrees(half == 0 ? -14 : 12))
                }
            } else {
                Circle()
                    .fill(tint.opacity(isNext ? 0.22 : 0.12))
                    .frame(width: 22, height: 22)
                    .blur(radius: 4)
                Circle()
                    .strokeBorder(tint.opacity(isNext ? 0.95 : 0.7), lineWidth: 1.6)
                    .frame(width: 18, height: 18)
                Circle()
                    .fill(tint.opacity(isNext ? 0.9 : 0.55))
                    .frame(width: 5, height: 5)
            }
        }
        .scaleEffect((isNext && flicker && !reduceMotion) ? 1.12 : 1)
        .shadow(color: broken ? .clear : tint.opacity(isNext ? 0.7 : 0.4), radius: 6)
    }
}

/// A simple tapered flame / leaf used by the chalice.
private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.80),
                       control: CGPoint(x: rect.maxX, y: h * 0.32))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.80),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: h * 0.32))
        p.closeSubpath()
        return p
    }
}
