import SwiftUI

// MARK: - ExpandedBodyMapView
//
// Full-screen body-map cover presented when a user taps the condensed
// home-dashboard figure. Gives the character sheet room to breathe: large
// swipeable figure on top, full muscle-rank list below. This is the
// surface that takes the muscle-list job the home tab used to carry —
// condensed home keeps the heatmap as the summary, this view owns the
// exhaustive breakdown.

struct ExpandedBodyMapView: View {
    let regionRanks: [BodyRegion: RegionRank]
    let archetypeName: String
    let aggregateRank: SubRank
    let allLiftRanks: [LiftRank]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    @State private var selectedRegion: BodyRegion?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.unbound.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    figureSection
                    listSection
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
            }

            closeButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        .sheet(item: $selectedRegion) { region in
            MuscleDetailSheet(
                region: region,
                regionRank: regionRanks[region] ?? RegionRank(
                    region: region,
                    rank: .eMinus,
                    topContributingLifts: [],
                    needsWork: true
                ),
                allLiftRanks: allLiftRanks
            )
            .environmentObject(services)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(archetypeName.uppercased())
                .font(Font.unbound.captionS)
                .tracking(1.8)
                .foregroundStyle(Color.unbound.textTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("RANK")
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(aggregateRank.displayName)
                    .font(Font.unbound.monoXL)
                    .foregroundStyle(aggregateRank.regionTint)
            }
        }
    }

    // MARK: Figure

    private var figureSection: some View {
        BodyMapView(regionRanks: regionRanks) { region in
            UnboundHaptics.medium()
            selectedRegion = region
        }
        .frame(minHeight: 520)
        .padding(.vertical, 6)
    }

    // MARK: List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL MUSCLES")
                .font(Font.unbound.captionS)
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)

            // Sort ascending by rank so weaknesses surface first — that's the
            // useful read on this screen.
            let sorted = BodyRegion.allCases
                .map { region -> (BodyRegion, RegionRank) in
                    let rr = regionRanks[region] ?? RegionRank(
                        region: region, rank: .eMinus,
                        topContributingLifts: [], needsWork: true
                    )
                    return (region, rr)
                }
                .sorted { $0.1.rank.ordinal < $1.1.rank.ordinal }

            VStack(spacing: 8) {
                ForEach(sorted, id: \.0) { _, rr in
                    MuscleListRow(regionRank: rr, onTap: {
                        UnboundHaptics.soft()
                        selectedRegion = rr.region
                    })
                }
            }
        }
    }

    // MARK: Close

    private var closeButton: some View {
        Button {
            UnboundHaptics.soft()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    ChamferedRectangle(inset: 8)
                        .fill(Color.unbound.surface)
                )
                .overlay(
                    ChamferedRectangle(inset: 8)
                        .stroke(Color.unbound.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MuscleListRow

private struct MuscleListRow: View {
    let regionRank: RegionRank
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(regionRank.region.displayName.uppercased())
                    .font(Font.unbound.bodyM)
                    .tracking(0.6)
                    .foregroundStyle(
                        regionRank.needsWork
                            ? Color.unbound.textSecondary
                            : Color.unbound.textPrimary
                    )
                    .lineLimit(1)
                Spacer()
                rankChip
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        regionRank.rank.ordinal >= SubRank.bMinus.ordinal
                            ? regionRank.rank.regionTint.opacity(0.45)
                            : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var rankChip: some View {
        Text(regionRank.rank.displayName)
            .font(Font.unbound.monoS)
            .foregroundStyle(regionRank.rank.regionTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(regionRank.rank.regionTint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(regionRank.rank.regionTint.opacity(0.6), lineWidth: 1)
            )
    }
}
