import SwiftUI
import UIKit

// MARK: - Program rank library

struct ProgramRankLibraryView: View {
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

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
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if selectedFilter != .all || !trimmedSearch.isEmpty {
            return filteredRows.isEmpty ? [] : [ProgramRankLibrarySection(title: "Results", rows: filteredRows)]
        }

        var sections: [ProgramRankLibrarySection] = []

        // Trophy case: everything the user holds a rank on, best tier first.
        let earned = filteredRows.filter(\.isEarned).sorted(by: sortRankRows)
        if !earned.isEmpty {
            sections.append(ProgramRankLibrarySection(title: "Your Ranks", rows: earned))
        }

        // The rest of the catalog to chase, grouped by category.
        let unearned = filteredRows.filter { !$0.isEarned }
        let categorySections = Dictionary(grouping: unearned, by: \.sectionTitle)
            .map { title, rows in
                ProgramRankLibrarySection(title: title, rows: rows.sorted(by: sortRowsWithinSection))
            }
            .sorted {
                ($0.rows.first?.sectionOrder ?? Int.max) < ($1.rows.first?.sectionOrder ?? Int.max)
            }
        sections.append(contentsOf: categorySections)

        return sections
    }

    private var earnedCount: Int {
        rows.filter(\.isEarned).count
    }

    private var topTier: SkillTier {
        rows.map(\.tier).max() ?? .initiate
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
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

                    Spacer().frame(height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedDetailRow) { row in
            RankDetailView(row: row) {
                await loadRanks()
            }
        }
        .task {
            await loadRanks()
            openRequestedDetailIfNeeded()
        }
    }

    /// Pinned, flush-to-top close control. A substantial circular button instead of
    /// a bare nav-bar glyph - stays available while the list scrolls.
    private var topBar: some View {
        HStack {
            Button {
                UnboundHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close rank library")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var rankLibraryHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rank Library")
                    .font(Font.unbound.titleL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                MetaLine([
                    "\(earnedCount) of \(rows.count) ranked",
                    "Top \(topTier.displayName)"
                ], emphasized: true)
            }
            Spacer(minLength: 0)
            Image(topTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .shadow(color: topTier.rewardTextTint.opacity(0.35), radius: 14)
        }
        .accessibilityIdentifier("program.rankLibrary.header")
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
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var rankFilterRail: some View {
        SegmentedFilterBar(
            items: ProgramRankLibraryFilter.allCases,
            title: { $0.displayName },
            selection: $selectedFilter
        )
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.accent)
                Spacer(minLength: 0)
                Text("\(section.rows.count)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .monospacedDigit()
            }

            VStack(spacing: 11) {
                ForEach(section.rows) { row in
                    Button {
                        UnboundHaptics.soft()
                        selectedDetailRow = row
                    } label: {
                        RankRow(row: row)
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
        let skillRows = Self.makeSkillRows(
            skillTiers: skillTiers,
            nodeStates: skillService.nodeStates,
            programFocusIds: skillService.programFocusIds
        )
        // The same movement is modelled by up to three subsystems (skill tree,
        // skill drill, exercise library), so it can surface as three rows. The
        // skill node is the single rank source, so fold every twin into it: the
        // "Hollow Body Hold" drill and the "Hollow Hold" exercise both collapse
        // into the "Hollow Body" skill row, while the genuinely different
        // "Hollow Rock" stays. See `movementFoldsIntoShownSkill`.
        let shownSkillIds = Set(skillRows.map(\.sourceId))
        let shownSkillNames = Set(skillRows.map { Self.searchKey($0.title) })
        let shownSkillAssets = Set(skillRows.compactMap(\.visualAssetName))
        let movementRows = Self.makeMovementRows(progressStates: progressStates, profile: userProfile)
            .filter { row in
                !Self.movementFoldsIntoShownSkill(
                    title: row.title,
                    sourceId: row.sourceId,
                    visualAssetName: row.visualAssetName,
                    shownSkillIds: shownSkillIds,
                    shownSkillNames: shownSkillNames,
                    shownSkillAssets: shownSkillAssets
                )
            }
        rows = skillRows + movementRows
        isLoading = false
    }

    /// Screenshot harness: push a specific detail straight from a launch arg
    /// (`--unbound-open-rank-detail <sourceId|rowId>`). DEBUG-only.
    private func openRequestedDetailIfNeeded() {
        #if DEBUG
        guard selectedDetailRow == nil,
              let id = Self.launchArgValue(for: "--unbound-open-rank-detail"),
              let match = rows.first(where: { $0.sourceId == id || $0.id == id })
        else { return }
        selectedDetailRow = match
        #endif
    }

    #if DEBUG
    private static func launchArgValue(for flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: flag), index + 1 < args.count {
            return args[index + 1]
        }
        if let combined = args.first(where: { $0.hasPrefix(flag + "=") }) {
            return String(combined.dropFirst(flag.count + 1))
        }
        return nil
    }
    #endif

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

    /// True when a movement row is just another label for a skill that is
    /// already shown as its own row, so it should be folded away (the skill is
    /// the single rank source). Three signals, in precision order:
    ///   1. Exact normalized-name twin — folds "Push-Up"/"Pushup" and any
    ///      exercise/drill named identically to a skill.
    ///   2. The movement is a skill drill/target owned by a shown skill
    ///      (`skillId`) — folds the "Hollow Body Hold" drill into "Hollow Body".
    ///   3. The movement renders the exact same picture as a shown skill AND is
    ///      linked to it — folds the "Hollow Hold" exercise (same art, different
    ///      name) while leaving "Hollow Rock" (different art) standing.
    /// Mere skill *association* is deliberately not enough on its own: Hollow
    /// Rock, Hanging Knee Raise, etc. all associate with the same skill but are
    /// distinct movements, so signal 3 also requires the identical asset.
    static func movementFoldsIntoShownSkill(
        title: String,
        sourceId: String,
        visualAssetName: String?,
        shownSkillIds: Set<String>,
        shownSkillNames: Set<String>,
        shownSkillAssets: Set<String>
    ) -> Bool {
        if shownSkillNames.contains(searchKey(title)) { return true }

        guard let definition = MovementCatalog.definition(for: sourceId) else { return false }

        if let skillId = definition.skillId, shownSkillIds.contains(skillId) { return true }

        if let asset = visualAssetName,
           shownSkillAssets.contains(asset),
           definition.skillAssociations.contains(where: shownSkillIds.contains) {
            return true
        }

        return false
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
