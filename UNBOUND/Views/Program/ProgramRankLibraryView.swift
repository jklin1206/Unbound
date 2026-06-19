import SwiftUI
import UIKit

// MARK: - Program rank library

struct ProgramRankLibraryView: View {
    @EnvironmentObject private var services: ServiceContainer

    @State private var rows: [ProgramRankLibraryRow] = []
    @State private var searchText = ""
    @State private var selectedFilter: ProgramRankLibraryFilter = .all
    @State private var selectedDetailRow: ProgramRankLibraryRow?
    @State private var isLoading = true

    private var filteredRows: [ProgramRankLibraryRow] {
        rows
            .filter(matchesSearchAndFilter)
            .sorted(by: sortRankRows)
    }

    private var groupedSections: [ProgramRankLibrarySection] {
        if selectedFilter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filteredRows.isEmpty ? [] : [ProgramRankLibrarySection(title: "Results", rows: filteredRows)]
        }

        let grouped = Dictionary(grouping: filteredRows, by: \.sectionTitle)
        return grouped.map { title, rows in
            ProgramRankLibrarySection(
                title: title,
                rows: rows.sorted(by: sortRowsWithinSection)
            )
        }
        .sorted {
            ($0.rows.first?.sectionOrder ?? Int.max) < ($1.rows.first?.sectionOrder ?? Int.max)
        }
    }

    private var earnedCount: Int {
        rows.filter(\.isEarned).count
    }

    private var topTier: SkillTier {
        rows.map(\.tier).max() ?? .initiate
    }

    private var totalAP: Int {
        Int(rows.reduce(0) { $0 + $1.totalAP }.rounded())
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                rankLibraryHeader
                rankSearchField
                rankFilterRail

                if isLoading {
                    loadingState
                } else if groupedSections.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedSections) { section in
                        rankSection(section)
                    }
                }

                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .task {
            await loadRanks()
        }
        .fullScreenCover(item: $selectedDetailRow) { row in
            ProgramRankLibraryDetailScreen(row: row) {
                await loadRanks()
            }
        }
    }

    private var rankLibraryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("RANK LIBRARY")
                    .font(Font.unbound.titleS)
                    .tracking(0.7)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Image(topTier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .shadow(color: topTier.rewardTextTint.opacity(0.35), radius: 10)
            }

            HStack(spacing: 8) {
                rankStatTile(label: "EARNED", value: "\(earnedCount)", tint: Color.unbound.accent)
                rankStatTile(label: "STANDARDS", value: "\(rows.count)", tint: Color.unbound.coachCyan)
                rankStatTile(label: "TOP", value: topTier.displayName.uppercased(), tint: topTier.rewardTextTint)
                rankStatTile(label: "XP", value: "\(totalAP)", tint: Color.unbound.rankGold)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(topTier.rewardTextTint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityIdentifier("program.rankLibrary.header")
    }

    private func rankStatTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var rankSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)

            TextField("Search ranks", text: $searchText)
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var rankFilterRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProgramRankLibraryFilter.allCases) { filter in
                    rankFilterChip(filter)
                }
            }
        }
    }

    private func rankFilterChip(_ filter: ProgramRankLibraryFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.displayName)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.0)
                .foregroundStyle(isSelected ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.unbound.accent.opacity(0.24) : Color.unbound.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.unbound.accent.opacity(0.36) : Color.unbound.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(Color.unbound.accent)
            Text("LOADING RANKS")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.6)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "seal")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("No ranks match those filters")
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private func rankSection(_ section: ProgramRankLibrarySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 0)
                Text("\(section.rows.count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            VStack(spacing: 8) {
                ForEach(section.rows) { row in
                    Button {
                        UnboundHaptics.soft()
                        selectedDetailRow = row
                    } label: {
                        ProgramRankLibraryRowView(row: row, showsDisclosure: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func loadRanks() async {
        isLoading = true
        guard let userId = services.auth.currentUserId else {
            rows = []
            isLoading = false
            return
        }

        let progressStates: [MovementProgressState] = (try? await services.database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: true,
            limit: nil
        )) ?? []
        let userProfile: UserProfile? = try? await services.database.read(
            collection: "users",
            documentId: userId
        )

        let skillTiers = UserSkillTierStore.shared.load(userId: userId)
        let skillService = SkillProgressService.shared
        rows = Self.makeSkillRows(
            skillTiers: skillTiers,
            nodeStates: skillService.nodeStates,
            programFocusIds: skillService.programFocusIds
        ) + Self.makeMovementRows(progressStates: progressStates, profile: userProfile)
        isLoading = false
    }

    private func matchesSearchAndFilter(_ row: ProgramRankLibraryRow) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesSearch = query.isEmpty
            || row.searchText.localizedCaseInsensitiveContains(query)
            || Self.searchKey(row.searchText).contains(Self.searchKey(query))
        guard matchesSearch else { return false }

        switch selectedFilter {
        case .all:
            return true
        case .earned:
            return row.isEarned
        case .skills:
            return row.source == .skill
        case .exercises:
            return row.source == .exercise
        case .top:
            return row.tier.rawValue >= SkillTier.veteran.rawValue
        }
    }

    private func sortRankRows(_ lhs: ProgramRankLibraryRow, _ rhs: ProgramRankLibraryRow) -> Bool {
        if lhs.tier != rhs.tier { return lhs.tier > rhs.tier }
        if lhs.totalAP != rhs.totalAP { return lhs.totalAP > rhs.totalAP }
        if lhs.source != rhs.source { return lhs.source.sortOrder < rhs.source.sortOrder }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func sortRowsWithinSection(_ lhs: ProgramRankLibraryRow, _ rhs: ProgramRankLibraryRow) -> Bool {
        if lhs.isEarned != rhs.isEarned { return lhs.isEarned && !rhs.isEarned }
        return sortRankRows(lhs, rhs)
    }

    private static func makeSkillRows(
        skillTiers: UserSkillTierState,
        nodeStates: [String: NodeState],
        programFocusIds: Set<String>
    ) -> [ProgramRankLibraryRow] {
        SkillGraph.shared.nodes.map { node in
            let state = nodeStates[node.id] ?? .locked
            let tier = skillTiers.tier(for: node.id)

            let status = programFocusIds.contains(node.id) ? "FOCUS" : Self.nodeStateLabel(state)
            let detail = RankBenchmarkSummary.nextBenchmark(for: node, currentTier: tier)
                ?? node.target.displayName

            return ProgramRankLibraryRow(
                id: "skill-\(node.id)",
                title: node.title,
                subtitle: "\(node.cluster.displayName) skill",
                detail: detail,
                metric: status,
                tier: tier,
                visualAssetName: Self.skillVisualAssetName(for: node),
                totalAP: 0,
                source: .skill,
                sourceId: node.id,
                sectionTitle: "\(node.cluster.displayName) Skills",
                sectionOrder: Self.skillSectionOrder(for: node.cluster),
                lastActivityAt: nil,
                earnedOverride: state == .proven || tier > .initiate,
                isRankHidden: node.earnedRankIsBelowFloor(tier)
            )
        }
    }

    private static func skillSectionOrder(for cluster: SkillCluster) -> Int {
        1 + (SkillCluster.allCases.firstIndex(of: cluster) ?? 0)
    }

    private static func makeMovementRows(
        progressStates: [MovementProgressState],
        profile: UserProfile?
    ) -> [ProgramRankLibraryRow] {
        let progressByStandard = progressStates.reduce(into: [String: MovementProgressState]()) { result, state in
            result[state.rankStandardMovementId] = state
        }

        var seenStandards: Set<String> = []
        var rows: [ProgramRankLibraryRow] = ExerciseLibrary.all.compactMap { item in
            guard item.isRankable,
                  seenStandards.insert(item.rankStandardMovementId).inserted
            else { return nil }

            let progress = progressByStandard[item.rankStandardMovementId]
            let displayRow = ExerciseLibraryDisplayRow(
                item: item,
                preferenceStatus: nil,
                movementProgress: progress,
                workingWeight: nil
            )
            let tier = progress.map {
                MovementProgressTierResolver.provenTier(
                    for: $0,
                    bodyweightKg: profile?.weightKg,
                    sex: profile?.biologicalSex
                )
            } ?? .initiate

            return ProgramRankLibraryRow(
                id: "movement-\(item.rankStandardMovementId)",
                title: progress?.displayName ?? item.name,
                subtitle: item.movementSlot.displayName,
                detail: displayRow.nextBenchmarkSummary ?? displayRow.bestMetricSummary ?? item.rankTemplate.displayName,
                metric: progress.map { "\(Int($0.totalAP.rounded())) XP" } ?? "0 XP",
                tier: tier,
                visualAssetName: Self.exerciseVisualAssetName(for: item.id),
                totalAP: progress?.totalAP ?? 0,
                source: .exercise,
                sourceId: item.rankStandardMovementId,
                sectionTitle: item.movementSlot.displayName,
                sectionOrder: 20 + ExerciseLibrary.slotOrder(item.movementSlot),
                lastActivityAt: progress?.lastLoggedAt ?? progress?.updatedAt,
                earnedOverride: nil
            )
        }

        let skillDrillRows = MovementCatalog.skillDrills
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .compactMap { definition -> ProgramRankLibraryRow? in
                guard definition.rankable,
                      definition.rankTemplate != .unranked,
                      seenStandards.insert(definition.rankStandardMovementId).inserted
                else { return nil }

                let item = ExerciseLibraryItem(definition: definition)
                let progress = progressByStandard[definition.rankStandardMovementId]
                let displayRow = ExerciseLibraryDisplayRow(
                    item: item,
                    preferenceStatus: nil,
                    movementProgress: progress,
                    workingWeight: nil
                )
                let tier = progress.map {
                    MovementProgressTierResolver.provenTier(
                        for: $0,
                        bodyweightKg: profile?.weightKg,
                        sex: profile?.biologicalSex
                    )
                } ?? .initiate

                return ProgramRankLibraryRow(
                    id: "movement-\(definition.rankStandardMovementId)",
                    title: progress?.displayName ?? definition.displayName,
                    subtitle: "Skill drill",
                    detail: displayRow.nextBenchmarkSummary ?? displayRow.bestMetricSummary ?? definition.rankTemplate.displayName,
                    metric: progress.map { "\(Int($0.totalAP.rounded())) XP" } ?? "0 XP",
                    tier: tier,
                    visualAssetName: Self.exerciseVisualAssetName(for: definition.id),
                    totalAP: progress?.totalAP ?? 0,
                    source: .exercise,
                    sourceId: definition.rankStandardMovementId,
                    sectionTitle: "Skill Drills",
                    sectionOrder: 20 + ExerciseLibrary.slotOrder(.skill),
                    lastActivityAt: progress?.lastLoggedAt ?? progress?.updatedAt,
                    earnedOverride: nil
                )
            }

        rows.append(contentsOf: skillDrillRows)

        let representedStandards = Set(rows.map(\.sourceId))
        let extraRows = progressStates
            .filter { !representedStandards.contains($0.rankStandardMovementId) }
            .map { state in
                let tier = MovementProgressTierResolver.provenTier(
                    for: state,
                    bodyweightKg: profile?.weightKg,
                    sex: profile?.biologicalSex
                )
                return ProgramRankLibraryRow(
                    id: "movement-\(state.rankStandardMovementId)",
                    title: state.displayName,
                    subtitle: state.rankTemplate.displayName,
                    detail: Self.movementProgressSummary(state),
                    metric: "\(Int(state.totalAP.rounded())) XP",
                    tier: tier,
                    visualAssetName: Self.exerciseVisualAssetName(for: state.rankStandardMovementId),
                    totalAP: state.totalAP,
                    source: .exercise,
                    sourceId: state.rankStandardMovementId,
                    sectionTitle: "Other Standards",
                    sectionOrder: 80,
                    lastActivityAt: state.lastLoggedAt ?? state.updatedAt,
                    earnedOverride: nil
                )
            }

        rows.append(contentsOf: extraRows)
        return rows
    }

    private static func skillVisualAssetName(for node: SkillNode) -> String? {
        SkillTraditionalVisualResolver.assetName(for: node)
    }

    private static func exerciseVisualAssetName(for movementId: String) -> String? {
        ExerciseVisualAsset.existingAssetName(forMovementId: movementId)
    }

    private static func searchKey(_ value: String) -> String {
        value
            .lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func nodeStateLabel(_ state: NodeState) -> String {
        switch state {
        case .locked: return "LOCKED"
        case .proven: return "CLEARED"
        }
    }

    private static func movementProgressSummary(_ state: MovementProgressState) -> String {
        if let estimated = state.bestEstimatedOneRepMaxKg {
            let unit = WeightPlatePolicy.currentUnit
            return "1RM \(WeightPlatePolicy.formatLoggedWeight(estimated, unit: unit))\(unit.shortLabel)"
        }
        if let load = state.bestLoadKg {
            let unit = WeightPlatePolicy.currentUnit
            if let reps = state.bestReps {
                return "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel) x \(reps)"
            }
            return "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel)"
        }
        if let reps = state.bestReps { return "\(reps) reps" }
        if let seconds = state.bestHoldSeconds { return "\(seconds)s hold" }
        if let seconds = state.bestDurationSeconds { return "\(seconds)s hold" }
        return state.rankTemplate.displayName
    }
}
