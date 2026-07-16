import SwiftUI

// MARK: - Rank library browse surfaces
//
// The browse mode that replaces the old 355-row flat wall: a tier ledger
// (what you hold, by tier), a horizontal trophy shelf (your best), and a
// category grid (the whole catalog as ~14 progress tiles that drill in).
// Search and the filter rail still produce the flat row list.

/// Horizontal ledger of earned ranks per tier, best tier first. Calm:
/// emblem + mono count, no boxes.
struct RankLibraryTierLedger: View {
    let counts: [(tier: SkillTier, count: Int)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(counts, id: \.tier) { entry in
                    HStack(spacing: 7) {
                        Image(entry.tier.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .shadow(color: entry.tier.rewardTextTint.opacity(0.35), radius: 5)
                        Text("\(entry.count)")
                            .font(Font.unbound.monoM.weight(.black))
                            .foregroundStyle(entry.tier.rewardTextTint)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.count) at \(entry.tier.displayName)")
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Horizontal trophy shelf: the user's highest-ranked movements as compact
/// portrait tiles. The wall of earned rows collapses into this spotlight.
struct RankLibraryTrophyShelf: View {
    let rows: [ProgramRankLibraryRow]
    let onSelect: (ProgramRankLibraryRow) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(rows) { row in
                    Button {
                        UnboundHaptics.soft()
                        onSelect(row)
                    } label: {
                        tile(row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func tile(_ row: ProgramRankLibraryRow) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.95), Color(white: 0.82)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    if let asset = row.visualAssetName {
                        Image(asset)
                            .renderingMode(.original)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(5)
                    } else {
                        Image(systemName: row.source.systemImage)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(row.tier.rewardTextTint.opacity(0.7))
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(row.tier.rewardTextTint.opacity(0.5), lineWidth: 1)
                )

                Image(row.tier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .shadow(color: row.tier.rewardTextTint.opacity(0.6), radius: 5)
                    .offset(x: 7, y: 7)
            }

            Text(row.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .frame(width: 88)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title), \(row.tier.displayName)")
        .accessibilityAddTraits(.isButton)
    }
}

/// One category of the catalog as a progress tile: name, ranked fraction,
/// thin progress bar, and the best tier held inside it.
struct RankLibraryCategoryTile: View {
    let section: ProgramRankLibrarySection

    private var earned: Int { section.rows.filter(\.isEarned).count }
    private var topTier: SkillTier? {
        section.rows.filter(\.isEarned).map(\.tier).max()
    }
    private var fraction: Double {
        section.rows.isEmpty ? 0 : Double(earned) / Double(section.rows.count)
    }
    private var tint: Color {
        topTier?.rewardTextTint ?? Color.unbound.textTertiary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(section.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let topTier {
                    Image(topTier.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .shadow(color: tint.opacity(0.4), radius: 4)
                }
            }

            Spacer(minLength: 0)

            Text("\(earned) of \(section.rows.count) ranked")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(earned > 0 ? tint : Color.unbound.textTertiary)
                .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                    if fraction > 0 {
                        Capsule()
                            .fill(tint.opacity(0.85))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
            }
            .frame(height: 4)
        }
        .padding(14)
        .frame(height: 118)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(section.title), \(earned) of \(section.rows.count) ranked")
        .accessibilityAddTraits(.isButton)
    }
}

/// Drill-in for one category: its rows, earned first. Row taps route back
/// through the library's single detail destination.
struct RankLibraryCategoryDetailView: View {
    let section: ProgramRankLibrarySection
    let onSelect: (ProgramRankLibraryRow) -> Void

    @Environment(\.dismiss) private var dismiss

    private var earnedCount: Int { section.rows.filter(\.isEarned).count }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(spacing: 11) {
                    ForEach(section.rows) { row in
                        Button {
                            UnboundHaptics.soft()
                            onSelect(row)
                        } label: {
                            RankRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to rank library")

            VStack(alignment: .leading, spacing: 8) {
                Text(section.title)
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                MetaLine([
                    "\(earnedCount) of \(section.rows.count) ranked"
                ], emphasized: true)
            }
        }
    }
}
