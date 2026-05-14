import SwiftUI

// MARK: - TrialCardView
//
// Single card in the weekly pick tray. Sized ~460pt tall so it fills
// most of the viewport in a TabView/.page swiper without clipping.
//
// Layout top → bottom:
//   1. Theme tag (axis name or WILDCARD) + kind badge
//   2. Display name (big title)
//   3. Blurb (narrative subtitle)
//   4. Aligned-axes pills (derived from TrialTheme)
//   5. Capstone hint footer

struct TrialCardView: View {
    let card: TrialCard

    private var tint: Color { card.theme.tintColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Theme tag row ──────────────────────────────────────────
            HStack(spacing: 8) {
                Text(card.theme.displayLabel)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(tint.opacity(0.15)))
                    .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))

                Spacer(minLength: 0)

                kindBadge
            }

            Spacer().frame(height: 28)

            // ── Big title ─────────────────────────────────────────────
            Text(card.displayName)
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 14)

            // ── Blurb ─────────────────────────────────────────────────
            Text(card.blurb)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 24)

            // ── Aligned-axes pills ────────────────────────────────────
            alignedAxesPills

            Spacer(minLength: 20)

            // ── Capstone divider ──────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)

            Spacer().frame(height: 16)

            // ── Capstone hint ─────────────────────────────────────────
            capstoneHint
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 460, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.unbound.surface)
                // Subtle tint wash in top-leading corner
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

    private var kindBadge: some View {
        let label: String
        let badgeTint: Color
        switch card.kind {
        case .aligned:
            label = "ALIGNED"
            badgeTint = Color.unbound.accent
        case .growth:
            label = "GROWTH"
            badgeTint = Color(red: 0.3, green: 0.75, blue: 0.5)
        case .prestige:
            label = "PRESTIGE"
            badgeTint = Color(red: 0.9, green: 0.75, blue: 0.3)
        }
        return Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(badgeTint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(badgeTint.opacity(0.12))
            )
    }

    @ViewBuilder
    private var alignedAxesPills: some View {
        let axes = alignedAxes
        if !axes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("TRAINS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                HStack(spacing: 8) {
                    ForEach(axes, id: \.self) { axis in
                        Text(axis.shortCode)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tint.opacity(0.14))
                            )
                    }
                }
            }
        }
    }

    private var alignedAxes: [AttributeKey] {
        switch card.theme {
        case .axis(let key): return [key]
        case .wildcard:      return []
        }
    }

    private var capstoneHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.8))

            VStack(alignment: .leading, spacing: 3) {
                Text("CAPSTONE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(card.capstone.displayName)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Previews

#Preview("Aligned card") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCardView(card: TrialCard(
            id: "trial-W20-aligned",
            kind: .aligned,
            theme: .axis(.power),
            displayName: "Power Focus",
            blurb: "Double down on heavy compound work this week. Let the bar move fast.",
            capstone: TrialCapstone(
                displayName: "Top-Set Benchmark",
                description: "Hit a top-set PR or match last cycle's peak on back squat.",
                evaluation: .manualClaim
            )
        ))
        .padding(20)
    }
}

#Preview("Prestige card") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCardView(card: TrialCard(
            id: "trial-W20-prestige",
            kind: .prestige,
            theme: .wildcard,
            displayName: "Open Circuit",
            blurb: "No axis bias. Pick one weakness and hammer it for 7 days straight.",
            capstone: TrialCapstone(
                displayName: "Circuit Finisher",
                description: "Complete a 20-minute AMRAP with at least 4 movements.",
                evaluation: .manualClaim
            )
        ))
        .padding(20)
    }
}
