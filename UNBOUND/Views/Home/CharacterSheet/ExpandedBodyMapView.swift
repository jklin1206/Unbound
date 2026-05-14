import SwiftUI

// MARK: - ExpandedBodyMapView
//
// Full-screen character sheet. The body map is the primary control: tapping a
// heat group opens the exact detailed region where possible, or asks the user
// to choose between the detailed regions that share that heatmap area.

struct ExpandedBodyMapView: View {
    let regionRanks: [BodyRegion: RegionRank]
    let groupRanks: [MuscleHeatGroup: SubRank]
    let archetypeName: String
    let aggregateRank: SubRank
    let allLiftRanks: [LiftRank]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var services: ServiceContainer

    @State private var selectedRegion: BodyRegion?
    @State private var selectedHeatGroup: MuscleHeatGroup?

    private var allRegions: [RegionRank] {
        BodyRegion.allCases.map { region in
            regionRanks[region] ?? Self.fallbackRank(for: region)
        }
    }

    private var weakestRegions: [RegionRank] {
        allRegions.sorted { lhs, rhs in
            if lhs.rank.ordinal == rhs.rank.ordinal {
                return lhs.region.displayName < rhs.region.displayName
            }
            return lhs.rank.ordinal < rhs.rank.ordinal
        }
    }

    private var strongestRegions: [RegionRank] {
        allRegions.sorted { lhs, rhs in
            if lhs.rank.ordinal == rhs.rank.ordinal {
                return lhs.region.displayName < rhs.region.displayName
            }
            return lhs.rank.ordinal > rhs.rank.ordinal
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    figureSection
                    prioritySection
                    regionGridSection
                    Spacer().frame(height: 28)
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)
            }

            closeButton
                .padding(.horizontal, 18)
                .padding(.top, 12)
        }
        .sheet(item: $selectedRegion) { region in
            MuscleDetailSheet(
                region: region,
                regionRank: regionRanks[region] ?? Self.fallbackRank(for: region),
                allLiftRanks: allLiftRanks
            )
            .environmentObject(services)
        }
        .confirmationDialog(
            "Choose region",
            isPresented: Binding(
                get: { selectedHeatGroup != nil },
                set: { if !$0 { selectedHeatGroup = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(regions(for: selectedHeatGroup ?? .chest), id: \.self) { region in
                Button(region.displayName) {
                    selectedRegion = region
                    selectedHeatGroup = nil
                }
            }
        }
    }

    // MARK: Header

    private var background: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            LinearGradient(
                colors: [
                    aggregateRank.regionTint.opacity(0.18),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .topTrailing,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            TierBadge(tier: aggregateRank.asSkillTier)

            VStack(alignment: .leading, spacing: 5) {
                Text("CHARACTER SHEET")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.7)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(archetypeName.uppercased())
                    .font(Font.unbound.bodyM.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                HStack(spacing: 8) {
                    CharacterMetricPill(label: "RANK", value: aggregateRank.displayName, tint: aggregateRank.regionTint)
                    CharacterMetricPill(label: "WEAK", value: weakestRegions.first?.rank.displayName ?? "E-", tint: weakestRegions.first?.rank.regionTint ?? Color.unbound.rankRed)
                    CharacterMetricPill(label: "PEAK", value: strongestRegions.first?.rank.displayName ?? "E-", tint: strongestRegions.first?.rank.regionTint ?? Color.unbound.rankRed)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Figure

    private var figureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("BODY MAP")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("TAP MUSCLE")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(Color.unbound.accent.opacity(0.9))
            }

            VStack(spacing: 12) {
                MuscleHeatmapView(groupRanks: groupRanks) { group in
                    UnboundHaptics.medium()
                    open(group: group)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 430)

                Group {
                    if let weakest = weakestRegions.first {
                        CharacterCallout(
                            title: "WEAK LINK",
                            regionRank: weakest,
                            systemImage: "scope",
                            onTap: { selectedRegion = weakest.region }
                        )
                    }
                    if let strongest = strongestRegions.first {
                        CharacterCallout(
                            title: "BEST ZONE",
                            regionRank: strongest,
                            systemImage: "bolt.fill",
                            onTap: { selectedRegion = strongest.region }
                        )
                    }
                    if let next = nextTarget {
                        CharacterCallout(
                            title: "NEXT PUSH",
                            regionRank: next,
                            systemImage: "arrow.up.right",
                            onTap: { selectedRegion = next.region }
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(aggregateRank.regionTint.opacity(0.28), lineWidth: 1)
            )
        }
    }

    private var nextTarget: RegionRank? {
        weakestRegions.first { !$0.topContributingLifts.isEmpty } ?? weakestRegions.first
    }

    // MARK: Priority

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIORITY REGIONS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(Array(weakestRegions.prefix(4))) { regionRank in
                    CharacterRegionRow(regionRank: regionRank, style: .priority) {
                        UnboundHaptics.soft()
                        selectedRegion = regionRank.region
                    }
                }
            }
        }
    }

    // MARK: Region Grid

    private var regionGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ALL REGIONS")
                .font(Font.unbound.captionS.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)

            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weakestRegions) { regionRank in
                    CharacterRegionRow(regionRank: regionRank, style: .compact) {
                        UnboundHaptics.soft()
                        selectedRegion = regionRank.region
                    }
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
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.unbound.surface.opacity(0.94)))
                .overlay(Circle().stroke(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func open(group: MuscleHeatGroup) {
        let options = regions(for: group)
        if options.count == 1, let only = options.first {
            selectedRegion = only
        } else {
            selectedHeatGroup = group
        }
    }

    private func regions(for group: MuscleHeatGroup) -> [BodyRegion] {
        BodyRegion.allCases.filter { $0.heatGroup == group }
    }

    private static func fallbackRank(for region: BodyRegion) -> RegionRank {
        RegionRank(region: region, rank: .eMinus, topContributingLifts: [], needsWork: true)
    }
}

// MARK: - CharacterMetricPill

private struct CharacterMetricPill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.11)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.32), lineWidth: 1))
    }
}

// MARK: - CharacterCallout

private struct CharacterCallout: View {
    let title: String
    let regionRank: RegionRank
    let systemImage: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(regionRank.rank.regionTint)
                    Text(title)
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .center, spacing: 8) {
                    TierBadge(tier: regionRank.rank.asSkillTier, compact: true)
                        .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(regionRank.region.displayName.uppercased())
                            .font(Font.unbound.bodyS.weight(.semibold))
                            .tracking(0.7)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                        Text(regionRank.region.needsWorkDirective)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.52))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(regionRank.rank.regionTint.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CharacterRegionRow

private enum CharacterRegionRowStyle {
    case priority, compact
}

private struct CharacterRegionRow: View {
    let regionRank: RegionRank
    let style: CharacterRegionRowStyle
    let onTap: () -> Void

    private var progress: Double {
        let step = Double(regionRank.rank.ordinal % 3)
        return min(0.95, max(0.18, (step + 1) / 3.4))
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: style == .priority ? 12 : 9) {
                TierBadge(tier: regionRank.rank.asSkillTier, compact: style != .priority)
                    .frame(width: style == .priority ? 42 : 34, height: style == .priority ? 42 : 34)

                VStack(alignment: .leading, spacing: style == .priority ? 6 : 4) {
                    HStack(spacing: 7) {
                        Text(regionRank.region.displayName.uppercased())
                            .font(style == .priority ? Font.unbound.bodyS.weight(.semibold) : Font.unbound.captionS.weight(.bold))
                            .tracking(style == .priority ? 0.8 : 1.0)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(regionRank.rank.displayName)
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(regionRank.rank.regionTint)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.unbound.borderSubtle)
                            Capsule()
                                .fill(regionRank.rank.regionTint)
                                .frame(width: max(7, proxy.size.width * progress))
                        }
                    }
                    .frame(height: style == .priority ? 5 : 3)

                    if style == .priority {
                        Text(regionRank.region.needsWorkDirective)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, style == .priority ? 12 : 10)
            .padding(.vertical, style == .priority ? 11 : 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.unbound.surface.opacity(style == .priority ? 0.86 : 0.68))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(regionRank.rank.regionTint.opacity(regionRank.needsWork ? 0.36 : 0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
