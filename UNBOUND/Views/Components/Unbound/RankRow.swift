import SwiftUI

/// Calm rank-library row: movement art, title + typographic meta, tier shield.
/// A single fill-only raised surface - no bordered-card chrome, no rank-band
/// strip, no pills. Replaces the heavier bordered-card library row look.
struct RankRow: View {
    let row: ProgramRankLibraryRow

    private var tint: Color { row.tier.rewardTextTint }

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(Font.unbound.bodyLStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                MetaLine([
                    row.source.displayName,
                    row.isRankHidden ? nil : row.tier.displayName,
                    row.metric
                ])
            }

            Spacer(minLength: 8)

            tierShield

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .opacity(row.isEarned ? 1 : 0.6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title), \(row.source.displayName), \(row.isRankHidden ? "unranked" : row.tier.displayName), \(row.metric)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(artworkBackground)

            if let assetName = row.visualAssetName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(4)
                    .opacity(row.isEarned ? 1 : 0.5)
            } else {
                Image(systemName: row.source.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint.opacity(row.isEarned ? 0.9 : 0.45))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var artworkBackground: some ShapeStyle {
        let usesExerciseArt = row.source == .exercise
            || (row.visualAssetName?.hasPrefix("exercise_visual_") == true)
        if usesExerciseArt { return AnyShapeStyle(Color.white) }
        return AnyShapeStyle(tint.opacity(row.isEarned ? 0.14 : 0.07))
    }

    @ViewBuilder
    private var tierShield: some View {
        if row.isRankHidden {
            Text("—")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 30, height: 30)
        } else {
            Image(row.tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .opacity(row.isEarned ? 1 : 0.4)
                .shadow(color: tint.opacity(row.isEarned ? 0.3 : 0), radius: 6)
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
