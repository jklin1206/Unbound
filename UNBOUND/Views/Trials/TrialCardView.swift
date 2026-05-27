import SwiftUI

// MARK: - TrialCardView
//
// Single card in the weekly Binding Vow pick tray. Sized ~460pt tall so it fills
// most of the viewport in a TabView/.page swiper without clipping.
//
// Layout top → bottom:
//   1. Theme tag (axis name or WILDCARD) + kind badge
//   2. Custom vow mark
//   3. Display name (big title)
//   4. Blurb (narrative subtitle)
//   5. Session prescription pills
//   6. Standard hint footer

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

            Spacer().frame(height: 20)

            WeeklyVowProofAsset(kind: card.kind, tint: tint)
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            Spacer().frame(height: 18)

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

            // ── Session prescription pills ───────────────────────────
            vowPrescription

            Spacer(minLength: 20)

            // ── Standard divider ─────────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)

            Spacer().frame(height: 16)

            // ── Standard hint ────────────────────────────────────────
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
                Text("SESSION")
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
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.8))

            VStack(alignment: .leading, spacing: 3) {
                Text("STANDARD")
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

struct WeeklyVowProofAsset: View {
    let kind: WeeklyVowKind
    let tint: Color
    var compact: Bool = false

    var body: some View {
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

            Image(systemName: kind.proofAssetSymbolName)
                .font(.system(size: compact ? 18 : 28, weight: .black))
                .foregroundStyle(tint)
                .shadow(color: tint.opacity(0.35), radius: compact ? 8 : 14)
        }
    }
}

struct WeeklyVowCoachValidationStrip: View {
    let tint: Color
    var compact: Bool = false

    private let lenses: [(label: String, detail: String, icon: String)] = [
        ("Home", "Clear setup", "house.fill"),
        ("Pro", "Load checked", "clipboard.fill"),
        ("Elite", "Clean standard", "medal.fill")
    ]

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            ForEach(lenses, id: \.label) { lens in
                HStack(spacing: 5) {
                    Image(systemName: lens.icon)
                        .font(.system(size: compact ? 9 : 10, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(lens.label.uppercased())
                            .font(.system(size: compact ? 7 : 8, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                        if !compact {
                            Text(lens.detail)
                                .font(Font.unbound.captionS)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }
                .foregroundStyle(tint)
                .padding(.horizontal, compact ? 7 : 9)
                .frame(height: compact ? 26 : 34)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.11))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                )
            }
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

#Preview("Aligned card") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TrialCardView(card: TrialCard(
            id: "weekly-vow-W20-ember",
            kind: .ember,
            theme: .axis(.power),
            displayName: "Iron Reset",
            blurb: "A low-day proof for clean power work.",
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
            displayName: "Pull-Up Standard",
            blurb: "A dedicated weekend proof.",
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
