import SwiftUI

/// Verdict (spec §6.6/§6.7). Pass: the hush → station accounting → minted gate
/// card (tapping it triggers The Crossing in Plan 3). Fail: "The gate holds." →
/// accounting → "What stands between you" → rematch CTA.
struct GateVerdictView: View {
    let evaluation: OverallRankTrialEvaluation
    let world: GateWorld
    var onMintedCardTapped: (() -> Void)? = nil   // Plan 3: triggers The Crossing
    var onRematch: (() -> Void)? = nil

    private var model: GateVerdictModel { .init(evaluation: evaluation, world: world) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.unbound.bg.ignoresSafeArea()
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headline
                        accounting
                        if model.outcome == .failed {
                            standingBetween
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 16)
                            mintedCardSlot
                            Spacer(minLength: 16)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 108)   // clearance for the pinned CTA
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
            ctaBar
        }
        .accessibilityIdentifier("gate-verdict-view")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.outcome == .passed ? "THE GATE IS ANSWERED" : "THE GATE HOLDS")
                .font(Font.unbound.titleL.weight(.black))
                .foregroundStyle(Color.unbound.textPrimary)
            Text(model.outcome == .passed
                 ? "\(world.trialName.uppercased()) — CLEARED"
                 : "The gate isn't going anywhere.")
                .font(model.outcome == .passed ? Font.unbound.captionS.weight(.heavy) : Font.unbound.bodyMStrong)
                .tracking(model.outcome == .passed ? 2 : 0)
                .foregroundStyle(model.outcome == .passed ? world.tint : Color.unbound.textSecondary)
        }
    }

    private var ctaBar: some View {
        Button {
            if model.outcome == .passed { UnboundHaptics.success(); onMintedCardTapped?() }
            else { onRematch?() }
        } label: {
            HStack(spacing: 8) {
                Text(model.outcome == .passed ? "ENTER THE CROSSING" : "ENTER AGAIN")
                if model.outcome == .passed {
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .heavy))
                }
            }
            .font(Font.unbound.titleS.weight(.heavy)).tracking(1.5)
            .foregroundStyle(Color.unbound.bg)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Capsule().fill(world.fillTint))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18).padding(.bottom, 28)
        .background(
            LinearGradient(colors: [Color.unbound.bg.opacity(0), Color.unbound.bg, Color.unbound.bg],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea().allowsHitTesting(false)
        )
        .accessibilityIdentifier("verdict-cta")
    }

    private var accounting: some View {
        VStack(spacing: 8) {
            ForEach(model.stationRows) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(row.passed ? Color.unbound.success : Color.unbound.warnOrange)
                    Text(row.title).font(Font.unbound.bodyMStrong).foregroundStyle(Color.unbound.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(row.yours) / \(row.floor)").font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(row.passed ? Color.unbound.textSecondary : Color.unbound.warnOrange)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
            }
        }
    }

    private var standingBetween: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT STANDS BETWEEN YOU").font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.5).foregroundStyle(Color.unbound.textTertiary)
            ForEach(model.standingBetween, id: \.self) { target in
                Text(target).font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(world.tint.opacity(0.1)))
            }
        }
    }

    private var mintedCardSlot: some View {
        Button {
            UnboundHaptics.success(); onMintedCardTapped?()
        } label: {
            GateCardView(
                world: world, dateText: nil,
                definingNumber: "\(model.stationRows.filter(\.passed).count)/\(model.stationRows.count)",
                stamped: true)
        }.buttonStyle(.plain)
    }
}
