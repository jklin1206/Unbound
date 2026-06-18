import SwiftUI

// MARK: - Home Trials tiles
//
// Compact, side-by-side cards in the Home Trials row. Each is a SINGLE tap into
// its flow — the rank card opens the trial detail (requirements + Open the Gate
// live there), the vow card (ActiveTrialCard) logs inline. They share
// HomeTrialTileShell so the two columns stay matched.

struct RankTrialInlineCard: View {
    let readiness: OverallRankTrialReadiness
    let tint: Color
    let onOpen: () -> Void

    private var targetName: String { readiness.targetRank?.displayName ?? "Rank" }

    private var proofText: String {
        let met = readiness.requirements.filter(\.isMet).count
        let total = max(1, readiness.requirements.count)
        if readiness.isReady { return "READY" }
        let left = max(0, total - met)
        return "\(left) PROOF\(left == 1 ? "" : "S") LEFT"
    }

    private var proofTint: Color {
        readiness.isReady ? Color.unbound.success : Color.unbound.textTertiary
    }

    var body: some View {
        HomeTrialTileShell(
            tint: tint,
            eyebrow: "RANK TRIAL",
            title: targetName,
            status: proofText,
            statusTint: proofTint,
            onTap: onOpen,
            glyph: { HomeTrialGlyph(systemName: "key.fill", rotation: -45, tint: tint) },
            trailing: { HomeTrialOpenChevron() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank trial, \(targetName), \(proofText). Opens the trial.")
    }
}

// Fallback tile for the not-active states (rank gate locked, or no vow picked).
struct HomeTrialStubTile: View {
    let systemName: String
    var rotation: Double = 0
    let eyebrow: String
    let title: String
    let status: String
    let tint: Color
    let onTap: () -> Void

    var body: some View {
        HomeTrialTileShell(
            tint: tint,
            eyebrow: eyebrow,
            title: title,
            status: status,
            statusTint: Color.unbound.textTertiary,
            onTap: onTap,
            glyph: { HomeTrialGlyph(systemName: systemName, rotation: rotation, tint: tint) },
            trailing: { HomeTrialOpenChevron() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(eyebrow), \(title), \(status)")
    }
}

// MARK: - Shared tile pieces

struct HomeTrialGlyph: View {
    let systemName: String
    var rotation: Double = 0
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .black))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .rotationEffect(.degrees(rotation))
            .shadow(color: tint.opacity(0.4), radius: 6)
            .frame(width: 30, height: 30, alignment: .leading)
    }
}

struct HomeTrialOpenChevron: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.unbound.textTertiary)
    }
}

/// Frosted-glass tile shell shared by the two Home Trials columns so they match.
/// The whole tile is the tap target — one flow.
struct HomeTrialTileShell<Glyph: View, Trailing: View>: View {
    let tint: Color
    let eyebrow: String
    let title: String
    let status: String
    let statusTint: Color
    let onTap: () -> Void
    @ViewBuilder let glyph: () -> Glyph
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    glyph()
                    Spacer(minLength: 0)
                    trailing()
                }

                Spacer(minLength: 14)

                Text(eyebrow)
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .padding(.top, 2)
                Text(status)
                    .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(statusTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .premiumGlassCard(cornerRadius: 18, tint: tint)
        }
        .buttonStyle(.plain)
    }
}
