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

    /// The whole point of the vow, in plain words: "Log 3 fuel anchors".
    private var goalText: String {
        let plural = card.target.count == 1 ? card.target.noun : "\(card.target.noun)s"
        return "Log \(card.target.count) \(plural)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            // ── Sigil + the goal, big ─────────────────────────────────
            HStack(alignment: .center, spacing: 14) {
                WeeklyVowProofAsset(lane: card.lane, tint: tint)
                    .frame(width: 54, height: 54)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.displayName.uppercased())
                        .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                    Text(goalText)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ── Blurb ─────────────────────────────────────────────────
            Text(card.blurb)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            vowTerms

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
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

    // How to complete it + what's at stake, in plain readable rows.
    private var vowTerms: some View {
        VStack(alignment: .leading, spacing: 10) {
            termRow(icon: "calendar", text: "Log one a day — self-reported this week")
            termRow(icon: "trophy.fill", text: "Win +\(card.bet.winXP) XP   ·   Miss −\(card.bet.oweXP) XP")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
        )
    }

    private func termRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
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
