import SwiftUI

// MARK: - CrossingShareCard
//
// 2:3 vertical card (1080 x 1620) sized for IG story / TikTok frame share.
// Rendered to UIImage via ImageRenderer from The Crossing's SHARE button.
//
// Layout (top -> bottom):
//   - "UNBOUND" wordmark + "RANK GATE <numeral>" line
//   - Rank badge + investiture title + dwell line
//   - Stamped gate card (date + defining number)
//   - Footer: unboundbtr.com + gate/rank pill
//
// Background: the gate world's threshold still under a legibility gradient.

struct CrossingShareCard: View {
    let crossing: GateCrossing
    let dateText: String?
    let definingNumber: String?

    var body: some View {
        ZStack {
            Color.unbound.bg

            Image(CrossingAssetResolver.thresholdStill(for: crossing))
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1620)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                header
                Spacer()
                investiture
                Spacer()
                mintedCard
                footer
                    .padding(.top, 44)
            }
            .padding(.vertical, 60)
            .padding(.horizontal, 48)
        }
        .frame(width: 1080, height: 1620)
        .background(Color.unbound.bg)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 10) {
            Text("UNBOUND")
                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                .tracking(6.0)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("RANK GATE \(crossing.world.numeral)")
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .tracking(4.0)
                .foregroundStyle(crossing.tint)
        }
        .shadow(color: .black.opacity(0.8), radius: 6, y: 1)
    }

    private var investiture: some View {
        VStack(spacing: 24) {
            Image(crossing.world.destinationRank.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .shadow(color: crossing.fillTint.opacity(0.8), radius: 40)
                .shadow(color: crossing.fillTint.opacity(0.45), radius: 90)

            Text(crossing.investitureTitle)
                .font(.system(size: 88, weight: .black))
                .tracking(6.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.9), radius: 10, y: 2)
                .shadow(color: crossing.fillTint.opacity(0.6), radius: 34)

            Text(crossing.dwellLine)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(crossing.tint)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.9), radius: 6, y: 1)
        }
    }

    private var mintedCard: some View {
        GateCardView(
            world: crossing.world,
            dateText: dateText,
            definingNumber: definingNumber,
            stamped: true
        )
        .frame(width: 640)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("unboundbtr.com")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)
            Circle()
                .fill(Color.unbound.textTertiary)
                .frame(width: 5, height: 5)
            Text("GATE \(crossing.world.numeral) · ANSWERED")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(crossing.tint)
        }
        .shadow(color: .black.opacity(0.8), radius: 4, y: 1)
    }
}

// MARK: Renderer helper

@MainActor
enum CrossingShareCardRenderer {
    /// Render the share card to UIImage at scale 2 (2160 x 3240, social quality).
    static func render(
        crossing: GateCrossing,
        dateText: String?,
        definingNumber: String?
    ) -> UIImage? {
        let card = CrossingShareCard(
            crossing: crossing,
            dateText: dateText,
            definingNumber: definingNumber
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    /// Auto-generated caption for the system share sheet.
    static func caption(crossing: GateCrossing) -> String {
        """
        Gate \(crossing.world.numeral) answered. \(crossing.world.destinationRank.displayName) confirmed. The arc continues. - via UNBOUND

        #UNBOUND #RankGate
        """
    }
}

#Preview {
    CrossingShareCard(
        crossing: GateCrossingCatalog.crossing(for: .theForging),
        dateText: "Jun 13, 2026",
        definingNumber: "4/4"
    )
    .scaleEffect(0.25)
}
