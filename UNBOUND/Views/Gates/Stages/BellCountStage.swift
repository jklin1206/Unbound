import SwiftUI

/// Gate II — The Count (in-trial header). The dojo hall is the living stage: the great
/// bell resonates a step further with every count logged, its ring filling toward the
/// full count and the hall warming as the discipline holds. Logging stays the calm
/// surface beneath; the bell reacts to the one spine. (The timed-rep cadence game is the
/// standalone showcase; in-trial the cadence window is evaluated on the logging side.)
struct BellCountStage: View {
    let world: GateWorld
    let stationCount: Int
    let stationsCleared: Int
    let currentStationTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var artAsset: String { world.stageAssetName }
    private var counted: Int { max(0, min(stationsCleared, stationCount)) }
    private var fraction: Double {
        guard stationCount > 0 else { return 0 }
        return Double(counted) / Double(stationCount)
    }
    private var allCounted: Bool { stationCount > 0 && counted >= stationCount }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                hall(size: size)
                bell(size: size)
                chrome
            }
            .frame(width: size.width, height: size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stationsCleared)
        }
        .frame(height: 268)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(world.trialName). \(counted) of \(stationCount) counted.")
        .accessibilityIdentifier("gate-stage-bell")
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
    }

    private func hall(size: CGSize) -> some View {
        Image(artAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .brightness(-0.10 + 0.16 * fraction)
            .overlay(LinearGradient(colors: [.clear, .clear, Color.unbound.bg],
                                    startPoint: .top, endPoint: .bottom))
    }

    /// The great bell already hangs in the bespoke hall art — so the stage treats
    /// it as a living sound source: a warm bloom and concentric resonance waves
    /// ring out from it, swelling with the count, instead of a flat glyph.
    private func bell(size: CGSize) -> some View {
        ZStack {
            // Warm light blooming off the struck bell in the art.
            RadialGradient(
                colors: [world.fillTint.opacity(0.20 + 0.5 * fraction), .clear],
                center: .center, startRadius: 4, endRadius: 150)
                .frame(width: 300, height: 300)
                .blendMode(.plusLighter)
                .scaleEffect(pulse && !reduceMotion ? 1.06 : 0.94)

            // The bell rings out — concentric resonance waves over the hall.
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(world.fillTint.opacity((0.55 - Double(ring) * 0.16) * (0.45 + 0.55 * fraction)),
                            lineWidth: 1.4)
                    .frame(width: 92 + CGFloat(ring) * 54, height: 92 + CGFloat(ring) * 54)
                    .scaleEffect(pulse && !reduceMotion ? 1.0 + CGFloat(ring) * 0.05 : 0.9)
                    .opacity(pulse && !reduceMotion ? 1 : 0.5)
            }

            // The discipline filling — count progress traced around the bell.
            Circle()
                .trim(from: 0, to: allCounted ? 1 : fraction)
                .stroke(world.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 126, height: 126)
                .shadow(color: world.fillTint.opacity(0.8), radius: 10)
        }
        .position(x: size.width * 0.5, y: size.height * 0.29)
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(world.trialName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy)).tracking(2)
                    .foregroundStyle(world.tint)
                Spacer(minLength: 0)
                Text(allCounted ? L10n.string(.gateBellChipDone, defaultValue: "KEPT") : L10n.format(.gateBellChipProgress, defaultValue: "%d/%d COUNTED", counted, stationCount))
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(allCounted ? world.fillTint : Color.unbound.textSecondary)
            }
            Text(allCounted ? L10n.string(.gateBellTitleDone, defaultValue: "The count is kept.") : currentStationTitle)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.8), radius: 7, y: 1)
            GateStationRail(total: stationCount, filled: counted, tint: world.fillTint)
        }
        .padding(16)
    }
}
