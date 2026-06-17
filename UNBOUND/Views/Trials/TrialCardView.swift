import SwiftUI

// MARK: - TrialCardView
//
// Single card in the weekly Binding Vow pick tray. Sized ~460pt tall so it fills
// most of the viewport in a TabView/.page swiper without clipping.
//
// Binding Vows v2: a card is lane + bet + target. Phase 5 owns the premium
// sigil/seal styling; this is the minimal compile-correct treatment.

struct TrialCardView: View {
    let card: TrialCard

    private var tint: Color { card.lane.tintColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Lane tag row ───────────────────────────────────────────
            HStack(spacing: 8) {
                Text(card.lane.displayLabel)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(tint.opacity(0.15)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))

                Spacer(minLength: 0)

                betBadge
            }

            Spacer().frame(height: 14)

            WeeklyVowProofAsset(lane: card.lane, tint: tint)
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)

            Spacer().frame(height: 10)

            // ── Big title ─────────────────────────────────────────────
            Text(card.displayName)
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 10)

            // ── Blurb ─────────────────────────────────────────────────
            Text(card.blurb)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineSpacing(2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 16)

            vowTerms
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 460, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.unbound.surface)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [tint.opacity(0.45), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: tint.opacity(0.18), radius: 22, y: 10)
    }

    // MARK: - Sub-views

    private var betBadge: some View {
        Text("\(card.bet.displayLabel) BET")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }

    private var vowTerms: some View {
        VStack(alignment: .leading, spacing: 5) {
            vowTermRow(label: "TARGET", text: card.target.displayText)
            vowTermRow(label: "WHEN", text: windowSummary)
            vowTermRow(label: "STAKES", text: "Win +\(card.bet.winXP) XP · Miss −\(card.bet.oweXP) XP")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var windowSummary: String {
        "Self-report this week"
    }

    private func vowTermRow(label: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 7.5, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(tint)
                .frame(width: 48, alignment: .leading)

            Text(text)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

struct WeeklyVowProofAsset: View {
    let lane: VowLane
    let tint: Color
    var compact: Bool = false

    var body: some View {
        ZStack {
            if let image = UIImage(named: lane.sealAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: tint.opacity(compact ? 0.22 : 0.36), radius: compact ? 8 : 16)
            } else {
                fallbackMark
            }
        }
        .compositingGroup()
    }

    private var fallbackMark: some View {
        ZStack {
            VowFacetShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(compact ? 0.30 : 0.40),
                            Color.unbound.surfaceElevated.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VowFacetShape()
                .strokeBorder(tint.opacity(compact ? 0.45 : 0.62), lineWidth: compact ? 1 : 1.4)

            VowFacetShape()
                .inset(by: compact ? 7 : 10)
                .stroke(tint.opacity(0.22), lineWidth: 1)

            Image(systemName: lane.sealSymbolName)
                .font(.system(size: compact ? 18 : 28, weight: .black))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.35), radius: compact ? 8 : 14)
        }
    }
}

private struct VowFacetShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(rect.width, rect.height) * 0.18
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> VowFacetShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Previews

#Preview("Recovery card") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCardView(card: TrialCard(
            id: "weekly-vow-W20-recovery",
            lane: .recovery,
            bet: .small,
            displayName: "Iron Reset",
            blurb: "A low-day reset that protects recovery.",
            target: VowTarget(count: 1, noun: "recovery reset")
        ))
        .padding(20)
    }
}

#Preview("Engine card") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCardView(card: TrialCard(
            id: "weekly-vow-W20-engine",
            lane: .engine,
            bet: .large,
            displayName: "Engine Build",
            blurb: "Conditioning work that builds the engine.",
            target: VowTarget(count: 3, noun: "engine session")
        ))
        .padding(20)
    }
}
