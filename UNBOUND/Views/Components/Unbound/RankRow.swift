import SwiftUI

/// Calm rank-library row: movement art, title + typographic meta, tier shield.
/// A single fill-only raised surface - no bordered-card chrome, no rank-band
/// strip, no pills. Replaces the heavier bordered-card library row look.
struct RankRow: View {
    let row: ProgramRankLibraryRow

    private var tint: Color { row.tier.rewardTextTint }

    private var rankLabel: String {
        row.isRankHidden ? "Unranked" : row.tier.displayName
    }

    var body: some View {
        HStack(spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(rankLabel)
                    .font(Font.unbound.caption.weight(.semibold))
                    .foregroundStyle(row.isRankHidden ? Color.unbound.textTertiary : tint)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            tierShield
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
                .overlay(
                    // Faint tier wash so each row carries its rank's color —
                    // the library reads as a spectrum (muted at Initiate,
                    // richer toward Unbound) without bars or borders.
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.08))
                )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title), \(rankLabel)")
        .accessibilityAddTraits(.isButton)
    }

    private var usesCharacterArt: Bool {
        row.source == .exercise
            || (row.visualAssetName?.hasPrefix("exercise_visual_") == true)
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(artworkBackground)

            if let assetName = row.visualAssetName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(3)
            } else {
                Image(systemName: row.source.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.9))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(artworkBorder, lineWidth: 1)
        )
    }

    // Character art is dark-on-transparent, drawn for a light backdrop. Give it a
    // crafted light "portrait" tile - a soft top-down gradient framed by the rank
    // tint - so it reads as an intentional collectible, not a flat white sticker.
    private var artworkBackground: some ShapeStyle {
        if usesCharacterArt {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(white: 0.95), Color(white: 0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(tint.opacity(0.16))
    }

    private var artworkBorder: Color {
        if usesCharacterArt {
            return tint.opacity(0.45)
        }
        return tint.opacity(0.3)
    }

    @ViewBuilder
    private var tierShield: some View {
        if row.isRankHidden {
            Text("—")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 34, height: 34)
        } else {
            Image(row.tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .shadow(color: tint.opacity(0.3), radius: 6)
        }
    }
}

#Preview("Rank rows") {
    let rows: [ProgramRankLibraryRow] = [
        ProgramRankLibraryRow(id: "1", title: "Front Lever", subtitle: "Pull Skill", detail: "Tuck to Full", metric: "5s hold", tier: .veteran, visualAssetName: nil, totalAP: 1200, source: .skill, sourceId: "front-lever", sectionTitle: "Pull", sectionOrder: 0, lastActivityAt: nil, earnedOverride: true),
        ProgramRankLibraryRow(id: "2", title: "Weighted Pull-up", subtitle: "Pull", detail: "+40kg", metric: "+0.5xBW", tier: .apprentice, visualAssetName: nil, totalAP: 300, source: .exercise, sourceId: "wpu", sectionTitle: "Pull", sectionOrder: 1, lastActivityAt: nil, earnedOverride: true),
        ProgramRankLibraryRow(id: "3", title: "One-Arm Handstand", subtitle: "Balance", detail: "Locked", metric: "Locked", tier: .initiate, visualAssetName: nil, totalAP: 0, source: .skill, sourceId: "oah", sectionTitle: "Handstand", sectionOrder: 2, lastActivityAt: nil, earnedOverride: false)
    ]
    return VStack(spacing: 10) {
        ForEach(rows) { RankRow(row: $0) }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.unbound.bg)
}
