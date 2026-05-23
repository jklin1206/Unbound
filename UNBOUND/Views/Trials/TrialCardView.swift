import SwiftUI

// MARK: - TrialCardView
//
// Single card in the weekly vow pick tray. Sized ~460pt tall so it fills
// most of the viewport in a TabView/.page swiper without clipping.
//
// Layout top → bottom:
//   1. Theme tag (axis name or WILDCARD) + kind badge
//   2. Display name (big title)
//   3. Blurb (narrative subtitle)
//   4. Vow prescription pills
//   5. Proof hint footer

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

            // ── Vow prescription pills ───────────────────────────────
            vowPrescription

            Spacer(minLength: 20)

            // ── Proof divider ────────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)

            Spacer().frame(height: 16)

            // ── Proof hint ───────────────────────────────────────────
            proofHint
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
        let badgeTint: Color
        switch card.kind {
        case .ember:
            badgeTint = Color.unbound.accent
        case .overdrive:
            badgeTint = Color(red: 0.3, green: 0.75, blue: 0.5)
        case .apex:
            badgeTint = Color(red: 0.9, green: 0.75, blue: 0.3)
        }
        return Text(card.kind.displayName.uppercased())
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
    private var vowPrescription: some View {
        if let prescription = card.prescription {
            VStack(alignment: .leading, spacing: 6) {
                Text("VOW")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                HStack(spacing: 8) {
                    vowPill(card.kind.shortDescription.uppercased())
                    vowPill(prescription.summary.uppercased())
                }
            }
        }
    }

    private func vowPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }

    private var proofHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.8))

            VStack(alignment: .leading, spacing: 3) {
                Text("VOW PROOF")
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
            id: "weekly-vow-W20-ember",
            kind: .ember,
            theme: .axis(.power),
            displayName: "Ember · Power Reset",
            blurb: "Keep the streak warm with recovery-safe work.",
            capstone: TrialCapstone(
                displayName: "Low-Day Proof",
                description: "Complete easy power work at RPE 3-5.",
                evaluation: .manualClaim
            ),
            prescription: WeeklyVowPrescription(
                placement: .recoveryDay,
                minMinutes: 8,
                maxMinutes: 12,
                minRPE: 3,
                maxRPE: 5
            )
        ))
        .padding(20)
    }
}

#Preview("Prestige card") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCardView(card: TrialCard(
            id: "weekly-vow-W20-apex",
            kind: .apex,
            theme: .wildcard,
            displayName: "Apex · Open Circuit",
            blurb: "Set aside a focused weekend session.",
            capstone: TrialCapstone(
                displayName: "Circuit Finisher",
                description: "Complete a 20-minute AMRAP with at least 4 movements.",
                evaluation: .manualClaim
            ),
            prescription: WeeklyVowPrescription(
                placement: .dedicatedSession,
                minMinutes: 20,
                maxMinutes: 45,
                minRPE: 8,
                maxRPE: 9
            )
        ))
        .padding(20)
    }
}
