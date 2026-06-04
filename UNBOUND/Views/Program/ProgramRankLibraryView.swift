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
                VStack(alignment: .leading, spacing: 3) {
                    Text("RANK LIBRARY")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("Every standard you can prove")
                        .font(Font.unbound.titleS)
                        .tracking(0.7)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
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
            Text("Clear the search or log a ranked movement.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
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

private struct ProgramRankLibrarySection: Identifiable {
    let title: String
    let rows: [ProgramRankLibraryRow]

    var id: String { title }
}

private struct ProgramRankLibraryRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let metric: String
    let tier: SkillTier
    let visualAssetName: String?
    let totalAP: Double
    let source: ProgramRankLibrarySource
    let sourceId: String
    let sectionTitle: String
    let sectionOrder: Int
    let lastActivityAt: Date?
    let earnedOverride: Bool?
    /// A not-yet feat (earned rank below its floor) has no real rank to show.
    var isRankHidden: Bool = false

    var isEarned: Bool {
        earnedOverride ?? (tier > .initiate || totalAP > 0)
    }

    var searchText: String {
        [
            title,
            subtitle,
            detail,
            metric,
            tier.displayName,
            source.displayName,
            sectionTitle
        ].joined(separator: " ")
    }
}

private enum ProgramRankLibrarySource: Equatable {
    case skill
    case exercise

    var displayName: String {
        switch self {
        case .skill: return "Skill"
        case .exercise: return "Exercise"
        }
    }

    var systemImage: String {
        switch self {
        case .skill: return "sparkles"
        case .exercise: return "dumbbell.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .skill: return 0
        case .exercise: return 1
        }
    }
}

private enum ProgramRankLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case earned
    case skills
    case exercises
    case top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .earned: return "Earned"
        case .skills: return "Skills"
        case .exercises: return "Exercises"
        case .top: return "Top"
        }
    }
}

private struct ProgramRankLibraryRowView: View {
    let row: ProgramRankLibraryRow
    var showsDisclosure: Bool = false

    private var tint: Color { row.tier.rewardTextTint }
    private var usesHighlightArt: Bool {
        row.visualAssetName?.hasSuffix("_highlight") == true
    }
    private var usesTraditionalExerciseArt: Bool {
        row.visualAssetName?.hasPrefix("exercise_visual_") == true
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: row.source.systemImage)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(tint)
                        Text(row.source.displayName.uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Spacer(minLength: 0)
                        Text(row.metric)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(tint.opacity(row.isEarned ? 0.95 : 0.58))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        if showsDisclosure {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                    }

                    Text(row.title.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text("\(row.subtitle) - \(row.detail)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 11)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            rankBand
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(row.isEarned ? 0.22 : 0.10), lineWidth: 1)
        )
        .opacity(row.isEarned ? 1 : 0.68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("\(row.title), \(row.tier.displayName), \(row.metric)")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(showsDisclosure ? "Opens full screen detail" : "")
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(artworkBackground)

            if let assetName = row.visualAssetName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(assetName.hasSuffix("_highlight") ? 1.34 : 1.0)
                    .padding((row.source == .exercise || usesTraditionalExerciseArt) ? 5 : (assetName.hasSuffix("_highlight") ? 0 : 4))
                    .opacity(row.isEarned ? 1.0 : 0.52)
            } else {
                Image(systemName: row.source.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint.opacity(row.isEarned ? 0.9 : 0.46))
            }
        }
        .frame(width: 58, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(row.isEarned ? 0.30 : 0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var artworkBackground: some ShapeStyle {
        if row.source == .exercise || usesTraditionalExerciseArt {
            return AnyShapeStyle(Color.white)
        }
        if usesHighlightArt {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.25, blue: 0.15),
                        Color(red: 0.18, green: 0.13, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(tint.opacity(row.isEarned ? 0.16 : 0.08))
    }

    private var rankBand: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if row.isRankHidden {
                // not-yet feat — no earned rank badge to show
                Text("—")
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 35, height: 35)
            } else {
                Image(row.tier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .opacity(row.isEarned ? 1.0 : 0.42)
                    .shadow(color: tint.opacity(row.isEarned ? 0.35 : 0.12), radius: 8)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                tint.opacity(row.isEarned ? 0.16 : 0.06)
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint.opacity(row.isEarned ? 0.22 : 0.10))
                .frame(width: 1)
        }
    }
}

private struct ProgramRankLibraryDetailScreen: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch row.source {
                case .exercise:
                    ProgramRankExerciseDetailView(row: row, onLogged: onLogged)
                case .skill:
                    if let movementRow = movementDetailRow(for: row) {
                        ProgramRankExerciseDetailView(row: movementRow, onLogged: onLogged)
                    } else if let node = SkillGraph.shared.node(id: row.sourceId) {
                        SkillDetailView(
                            node: node,
                            graph: SkillGraph.shared,
                            nodeStates: SkillProgressService.shared.nodeStates
                        )
                    } else {
                        missingSkillState
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UnboundHaptics.soft()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.unbound.surface.opacity(0.92)))
                            .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close rank detail")
                }
            }
        }
    }

    private func movementDetailRow(for row: ProgramRankLibraryRow) -> ProgramRankLibraryRow? {
        guard let definition = MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
        else { return nil }

        return ProgramRankLibraryRow(
            id: "movement-detail-\(definition.rankStandardMovementId)",
            title: definition.displayName,
            subtitle: definition.movementSlot.displayName,
            detail: row.detail,
            metric: row.metric,
            tier: row.tier,
            visualAssetName: row.visualAssetName,
            totalAP: row.totalAP,
            source: .exercise,
            sourceId: definition.rankStandardMovementId,
            sectionTitle: definition.movementSlot.displayName,
            sectionOrder: row.sectionOrder,
            lastActivityAt: row.lastActivityAt,
            earnedOverride: row.earnedOverride,
            isRankHidden: row.isRankHidden
        )
    }

    private var missingSkillState: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "questionmark.diamond")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("Skill not found")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("This rank no longer maps to a skill node.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
    }
}

private struct ProgramRankLibraryExpandedRow: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    private var tint: Color { row.tier.rewardTextTint }

    private var rankText: String {
        row.isRankHidden ? "—" : row.tier.displayName.uppercased()
    }

    private var statusText: String {
        if row.isEarned && row.tier.next == nil { return "MAXED" }
        return row.isEarned ? "EARNED" : "UNPROVEN"
    }

    private var targetLabel: String {
        if row.isEarned && row.tier.next == nil { return "PEAK STANDARD" }
        return row.isEarned ? "NEXT STANDARD" : "FIRST STANDARD"
    }

    private var lastActivityText: String {
        guard let lastActivityAt = row.lastActivityAt else { return "NONE" }
        return lastActivityAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private var movementDefinition: MovementDefinition? {
        guard row.source == .exercise else { return nil }
        return MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
    }

    private var associatedSkillNode: SkillNode? {
        if row.source == .skill {
            return SkillGraph.shared.node(id: row.sourceId)
        }
        guard let skillId = movementDefinition?.skillId else { return nil }
        return SkillGraph.shared.node(id: skillId)
    }

    private var ladderRows: [ProgramRankExpandedLadderRow] {
        if let associatedSkillNode {
            return annotatedRows(skillRows(for: associatedSkillNode))
        }
        if let movementDefinition {
            return annotatedRows(strengthRows(for: movementDefinition))
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                summaryTile(label: "STATUS", value: statusText, tint: row.isEarned ? Color.unbound.success : Color.unbound.textTertiary)
                summaryTile(label: "RANK", value: rankText, tint: tint)
                summaryTile(label: "LAST", value: lastActivityText, tint: Color.unbound.coachCyan)
            }

            targetPanel

            if !ladderRows.isEmpty {
                ladderPanel
            }

            if row.source == .exercise {
                NavigationLink {
                    ProgramRankExerciseDetailView(row: row) {
                        await onLogged()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint)
                        Text("LOG / VIEW HISTORY")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.2)
                            .foregroundStyle(Color.unbound.textPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(row.isEarned ? 0.20 : 0.11), lineWidth: 1)
        )
        .padding(.leading, 12)
        .accessibilityElement(children: .contain)
    }

    private var targetPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.source == .skill ? "scope" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.14)))

            VStack(alignment: .leading, spacing: 5) {
                Text(targetLabel)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(row.detail)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.44))
        )
    }

    private var ladderPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RANK PATH")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.3)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 0) {
                ForEach(ladderRows) { ladderRow in
                    ladderLine(ladderRow)
                }
            }
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.bg.opacity(0.34))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func ladderLine(_ ladderRow: ProgramRankExpandedLadderRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(ladderRow.tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .opacity(ladderRow.status == .locked ? 0.42 : 1.0)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(ladderRow.tier.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(0.9)
                        .foregroundStyle(ladderRow.status.tint(base: tint))
                    Text(ladderRow.status.displayName)
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(ladderRow.status.tint(base: tint))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ladderRow.status.tint(base: tint).opacity(0.13)))
                }

                Text(ladderRow.detail)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(ladderRow.status == .locked ? Color.unbound.textTertiary : Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func summaryTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.56)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.42))
        )
    }

    private func skillRows(for node: SkillNode) -> [(tier: SkillTier, detail: String)] {
        SkillTier.allCases
            .filter { $0.rawValue >= node.rankFloor.rawValue }
            .map { tier in
                (
                    tier: tier,
                    detail: node.tierCriteria[tier].map(Self.criterionSummary)
                        ?? node.target.displayName
                )
            }
    }

    private func strengthRows(for definition: MovementDefinition) -> [(tier: SkillTier, detail: String)] {
        let key = MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        return SkillTier.allCases.compactMap { tier in
            guard let ratio = StrengthStandards.ratio(exerciseKey: key, tier: tier, sex: nil) else { return nil }
            let ratioText = String(format: "%.2g", ratio)
            let prefix = definition.rankTemplate == .weightedBodyweight ? "added load " : ""
            return (tier: tier, detail: "\(prefix)\(ratioText)x bodyweight")
        }
    }

    private func annotatedRows(_ rows: [(tier: SkillTier, detail: String)]) -> [ProgramRankExpandedLadderRow] {
        guard !rows.isEmpty else { return [] }

        let visibleTiers = rows.map(\.tier)
        let nextTier = row.isEarned ? row.tier.next : row.tier
        let currentTier = nextTier.flatMap { target in
            visibleTiers.first { $0.rawValue >= target.rawValue }
        }

        return rows.map { candidate in
            let isCleared = row.isEarned
                && !row.isRankHidden
                && candidate.tier.rawValue <= row.tier.rawValue
            let status: ProgramRankExpandedLadderStatus
            if isCleared {
                status = .cleared
            } else if candidate.tier == currentTier {
                status = .current
            } else {
                status = .locked
            }

            return ProgramRankExpandedLadderRow(
                tier: candidate.tier,
                detail: candidate.detail,
                status: status
            )
        }
    }

    private static func criterionSummary(_ criterion: TierCriterion) -> String {
        switch criterion {
        case .reps(let count, let exerciseName):
            return "\(count) \(displayExerciseName(exerciseName))"
        case .seconds(let seconds):
            return "\(seconds)-second hold"
        case .exerciseSeconds(let seconds, let exerciseName):
            return "\(seconds)s \(displayExerciseName(exerciseName)) hold"
        case .weightKg(let weight):
            return "\(Int(weight.rounded())) kg working set"
        case .exerciseWeightKg(let weight, let exerciseName):
            return "\(Int(weight.rounded())) kg \(displayExerciseName(exerciseName))"
        case .bodyweightRatio(let ratio):
            return "\(String(format: "%.2g", ratio))x bodyweight"
        case .exerciseBodyweightRatio(let ratio, let exerciseName):
            return "\(String(format: "%.2g", ratio))x bodyweight \(displayExerciseName(exerciseName))"
        case .variant(let name):
            return "Log \(displayExerciseName(name))"
        case .compound(let criteria):
            return criteria.map(criterionSummary).joined(separator: " + ")
        }
    }

    private static func displayExerciseName(_ name: String) -> String {
        name
            .split(separator: " ")
            .map { part in
                part
                    .split(separator: "-")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }
}

private struct ProgramRankExpandedLadderRow: Identifiable {
    let tier: SkillTier
    let detail: String
    let status: ProgramRankExpandedLadderStatus

    var id: SkillTier { tier }
}

private enum ProgramRankExpandedLadderStatus {
    case cleared
    case current
    case locked

    var displayName: String {
        switch self {
        case .cleared: return "CLEARED"
        case .current: return "NEXT"
        case .locked: return "LOCKED"
        }
    }

    func tint(base: Color) -> Color {
        switch self {
        case .cleared: return Color.unbound.success
        case .current: return base
        case .locked: return Color.unbound.textTertiary
        }
    }
}

// MARK: - Rank exercise detail

private struct ProgramRankExerciseDetailView: View {
    let row: ProgramRankLibraryRow
    let onLogged: () async -> Void

    @EnvironmentObject private var services: ServiceContainer

    @State private var progress: MovementProgressState?
    @State private var userProfile: UserProfile?
    @State private var history: [ProgramRankExerciseHistoryEntry] = []
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var hasSeededDefaults = false

    @State private var selectedWeightDisplay: Double = 0
    @State private var selectedReps: Int = 1
    @State private var selectedSeconds: Int = 30
    @State private var selectedRepGraphRange: ProgramRankRepGraphRange = .thirtyDays
    @State private var rankReveal: ProgramRankAttemptReveal?

    private var definition: MovementDefinition? {
        MovementCatalog.definition(for: row.sourceId)
            ?? MovementCatalog.resolvedTrainingMovement(name: row.title)?.standard
    }

    private var logMode: ProgramRankExerciseLogMode {
        definition.map(ProgramRankExerciseLogMode.mode(for:)) ?? .oneRepMax
    }

    private var tint: Color {
        displayedTier.rewardTextTint
    }

    private var displayedTier: SkillTier {
        resolvedTier(for: progress) ?? row.tier
    }

    private var weightUnit: TrainingWeightUnit {
        WeightPlatePolicy.currentUnit
    }

    private var selectedWeightKg: Double? {
        guard selectedWeightDisplay > 0 else { return nil }
        return weightUnit.kilograms(fromDisplayValue: selectedWeightDisplay)
    }

    private var canSubmit: Bool {
        switch logMode {
        case .oneRepMax:
            return selectedWeightDisplay > 0
        case .reps:
            return selectedReps > 0
        case .hold:
            return selectedSeconds > 0
        }
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            if let definition {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        hero(definition)
                        progressSummary
                        guideLayer(definition)
                        singleLogCard(definition)
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 26)
                }
            } else {
                missingState
            }
        }
        .navigationTitle(definition?.displayName ?? row.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .alert("Couldn't save rank attempt", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Retry") { Task { await submitLog() } }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Your selections are still here.")
        }
        .toolbar(rankReveal == nil ? .visible : .hidden, for: .navigationBar)
        .overlay {
            if let rankReveal {
                ProgramRankAttemptRevealOverlay(reveal: rankReveal) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        self.rankReveal = nil
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }

    private func hero(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heroArtwork(definition)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.08, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                Text(definition.displayName.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func heroArtwork(_ definition: MovementDefinition) -> some View {
        if let assetName = row.visualAssetName {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(heroArtworkBackground(for: assetName))

                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(assetName.hasSuffix("_highlight") ? 1.18 : 1.0)
                    .padding(heroArtworkPadding(for: assetName))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel("\(definition.displayName) visual")
        } else {
            ExerciseVisualView(definition: definition, size: .hero)
        }
    }

    private func heroArtworkBackground(for assetName: String) -> AnyShapeStyle {
        if shouldUseWhiteArtworkStage(for: assetName) {
            return AnyShapeStyle(Color.white)
        }
        if assetName.hasSuffix("_highlight") {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.25, blue: 0.15),
                        Color(red: 0.18, green: 0.13, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.unbound.surfaceElevated.opacity(0.28))
    }

    private func shouldUseWhiteArtworkStage(for assetName: String) -> Bool {
        assetName.hasPrefix("exercise_visual_")
            && row.source == .exercise
            && !row.id.hasPrefix("movement-detail-")
    }

    private func heroArtworkPadding(for assetName: String) -> CGFloat {
        if assetName.hasPrefix("exercise_visual_") { return 6 }
        return assetName.hasSuffix("_highlight") ? 0 : 14
    }

    private var progressSummary: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(displayedTier.displayName.uppercased())
                .font(Font.unbound.titleS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            Text(bestSummary)
                .font(Font.unbound.bodyS.weight(.bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestSummary: String {
        if let progress {
            return ProgramRankExerciseFormatter.bestSummary(progress)
        }
        return row.detail
    }

    private func singleLogCard(_ definition: MovementDefinition) -> some View {
        detailSection(title: "LOG A SET") {
            VStack(alignment: .leading, spacing: 14) {
                switch logMode {
                case .oneRepMax:
                    oneRepMaxRail(definition)
                    proofHistoryGraph
                case .reps:
                    repsRail(limit: 80)
                    proofHistoryGraph
                case .hold:
                    secondsRail(title: "Hold Time")
                    proofHistoryGraph
                }

                rankLogActionButton
            }
        }
    }

    private var rankLogActionButton: some View {
        let isEnabled = canSubmit && !isSubmitting

        return Button {
            guard isEnabled else { return }
            UnboundHaptics.medium()
            Task { await submitLog() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSubmitting ? "hourglass" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text(isSubmitting ? "Saving Attempt" : "Reveal Rank")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isEnabled ? tint.opacity(0.72) : Color.unbound.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(isEnabled ? 1 : 0.58)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("program.rankExerciseDetail.logResult")
    }

    private var proofHistoryGraph: some View {
        ProgramRankProofHistoryLineGraph(
            entries: history,
            currentValue: currentProofGraphValue,
            historyValue: proofGraphValue(for:),
            valueFormatter: proofGraphValueText(_:),
            selectedRange: $selectedRepGraphRange,
            tint: tint,
            accessibilityUnit: logMode.accessibilityUnit
        )
    }

    private var currentProofGraphValue: Double {
        switch logMode {
        case .oneRepMax:
            return max(selectedWeightDisplay, 0)
        case .reps:
            return Double(max(selectedReps, 1))
        case .hold:
            return Double(max(selectedSeconds, 1))
        }
    }

    private func proofGraphValue(for entry: ProgramRankExerciseHistoryEntry) -> Double? {
        switch logMode {
        case .oneRepMax:
            guard let oneRepMaxKg = entry.oneRepMaxKg else { return nil }
            return weightUnit.displayValue(fromKilograms: oneRepMaxKg)
        case .reps:
            return entry.reps.map(Double.init)
        case .hold:
            return entry.holdSeconds.map(Double.init)
        }
    }

    private func proofGraphValueText(_ value: Double) -> String {
        switch logMode {
        case .oneRepMax:
            return "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
        case .reps:
            return "\(Int(value.rounded()))"
        case .hold:
            return ProgramRankExerciseFormatter.seconds(Int(value.rounded()))
        }
    }

    @ViewBuilder
    private func guideLayer(_ definition: MovementDefinition) -> some View {
        if let skillForm = skillFormGuide(for: definition) {
            detailSection(title: "SKILL FORM") {
                FormPhaseSlideshow(
                    phases: skillForm.phases,
                    skillTitle: skillForm.title
                )
            }
        } else {
            SkillGuideLayerView(
                layer: .rankExercise(definition: definition),
                tint: tint,
                isProminent: true
            )
        }
    }

    private func skillFormGuide(for definition: MovementDefinition) -> (title: String, phases: [FormPhase])? {
        guard let skillId = definition.skillId else { return nil }
        let node = SkillGraph.shared.node(id: skillId)
        let phases = FormPhaseLibrary.phases(
            for: skillId,
            fallbackTitle: node?.title ?? definition.displayName,
            formCues: node?.formCues ?? []
        )
        guard !phases.isEmpty else { return nil }
        return (node?.title ?? definition.displayName, phases)
    }

    private var historyCard: some View {
        detailSection(title: "PAST HISTORY", subtitle: "Recent attempts for this rank standard") {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.unbound.accent)
                    Text("Loading history")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if history.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("No attempts yet. Reveal one result and it will appear here.")
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(history) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
    }

    private var missingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.diamond")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Movement not found")
                .font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("This rank standard no longer maps to a catalog exercise.")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private func summaryTile(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(value)
                .font(Font.unbound.monoS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(cardBackground(cornerRadius: 12, tint: tint.opacity(0.16)))
    }

    private func oneRepMaxRail(_ definition: MovementDefinition) -> some View {
        let config = weightRulerConfig(allowsBodyweight: definition.rankTemplate == .weightedBodyweight)
        let tick = Binding<Int>(
            get: { config.tick(for: selectedWeightDisplay) },
            set: { selectedWeightDisplay = config.value(for: $0) }
        )
        let isAddedLoad = definition.rankTemplate == .weightedBodyweight
        let title = isAddedLoad ? "Added 1RM" : "1RM"
        let value = isAddedLoad ? addedLoadSummary : formatDisplayWeight(selectedWeightDisplay)

        return ProgramRankMetricRuler(
            title: title,
            valueText: value,
            range: config.range,
            value: tick,
            format: { config.formatValue($0, using: weightUnit, isAddedLoad: isAddedLoad) },
            tickLabel: { config.tickLabel($0) },
            majorEvery: config.majorEvery,
            tickSpacing: 13
        )
    }

    private func repsRail(limit: Int) -> some View {
        ProgramRankMetricRuler(
            title: "Reps",
            valueText: "\(selectedReps)",
            range: 1...limit,
            value: $selectedReps,
            unitLabel: "REPS",
            format: { "\($0)" },
            tickLabel: { "\($0)" },
            majorEvery: limit > 40 ? 10 : 5,
            tickSpacing: 15
        )
    }

    private func secondsRail(title: String) -> some View {
        let step = 5
        let maxTick = 1_200 / step
        let tick = Binding<Int>(
            get: { min(max(Int((Double(selectedSeconds) / Double(step)).rounded()), 1), maxTick) },
            set: { selectedSeconds = max(1, min($0, maxTick)) * step }
        )
        let majorEvery = title == "Hold Time" ? 6 : 12

        return ProgramRankMetricRuler(
            title: title,
            valueText: ProgramRankExerciseFormatter.seconds(selectedSeconds),
            range: 1...maxTick,
            value: tick,
            format: { ProgramRankExerciseFormatter.seconds($0 * step) },
            tickLabel: { ProgramRankExerciseFormatter.seconds($0 * step) },
            majorEvery: majorEvery,
            tickSpacing: 12
        )
    }

    private var addedLoadSummary: String {
        selectedWeightDisplay > 0 ? "+\(formatDisplayWeight(selectedWeightDisplay))" : "Bodyweight only"
    }

    private func detailSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.unbound.bodyS.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardBackground(cornerRadius: CGFloat, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(tint, lineWidth: 1)
        }
    }

    private func historyRow(_ entry: ProgramRankExerciseHistoryEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(Font.unbound.bodyS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.dateText)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func loadDetail() async {
        guard let userId = services.auth.currentUserId else {
            isLoading = false
            return
        }

        isLoading = true
        async let progressLoad: [MovementProgressState] = services.database.query(
            collection: "movement_progress",
            field: "userId",
            isEqualTo: userId,
            orderBy: nil,
            descending: true,
            limit: nil
        )
        async let logLoad: [PerformanceLog] = services.database.query(
            collection: "performanceLogs",
            field: "userId",
            isEqualTo: userId,
            orderBy: "completedAt",
            descending: true,
            limit: 80
        )
        async let profileLoad: UserProfile? = services.database.read(
            collection: "users",
            documentId: userId
        )

        let progressStates = (try? await progressLoad) ?? []
        let logs = (try? await logLoad) ?? []
        userProfile = try? await profileLoad
        progress = progressStates.first { $0.rankStandardMovementId == row.sourceId }
        history = ProgramRankExerciseHistoryEntry.entries(
            from: logs,
            rankStandardMovementId: row.sourceId
        )

        if !hasSeededDefaults {
            seedDefaults(from: progress)
            hasSeededDefaults = true
        }
        isLoading = false
    }

    @MainActor
    private func submitLog() async {
        guard !isSubmitting else { return }
        guard let definition else {
            errorMessage = "This rank standard is missing from the movement catalog."
            return
        }
        guard let userId = services.auth.currentUserId else {
            errorMessage = "Sign in before saving a rank attempt."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let now = Date()
        let performanceLog = makePerformanceLog(definition: definition, userId: userId, completedAt: now)
        let priorTier = displayedTier

        do {
            let result = try await TrainingCompletionService.shared.complete(performanceLog, services: services)
            let reveal = makeRankReveal(
                from: result,
                definition: definition,
                priorTier: priorTier
            )
            await loadDetail()
            await onLogged()
            if reveal.isRankUp {
                HapticManager.notification(.success)
            } else {
                UnboundHaptics.medium()
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                rankReveal = reveal
            }
        } catch {
            HapticManager.notification(.error)
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func makePerformanceLog(
        definition: MovementDefinition,
        userId: String,
        completedAt: Date
    ) -> PerformanceLog {
        let set = PerformanceSet(
            setNumber: 1,
            reps: logMode.recordsReps ? selectedReps : logMode.recordsOneRepMax ? 1 : nil,
            weightKg: logMode.recordsOneRepMax ? selectedWeightKg : nil,
            holdSeconds: logMode == .hold ? selectedSeconds : nil,
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            rpe: nil,
            qualityFlags: [],
            notes: nil
        )
        let exercise = PerformanceExercise(
            name: definition.displayName,
            movementId: definition.id,
            rankStandardMovementId: definition.rankStandardMovementId,
            plannedSets: 1,
            plannedTarget: logSummary,
            sets: [set],
            notes: nil
        )
        let block = PerformanceBlock(
            kind: definition.blockKind,
            title: definition.displayName,
            exercises: [exercise],
            durationSeconds: nil,
            distanceMeters: nil,
            calories: nil,
            notes: "Single rank attempt"
        )

        return PerformanceLog(
            id: "rank-log-\(UUID().uuidString)",
            userId: userId,
            source: .custom,
            title: "\(definition.displayName) Rank Attempt",
            startedAt: completedAt,
            completedAt: completedAt,
            blocks: [block],
            overallRPE: nil,
            notes: nil
        )
    }

    private func makeRankReveal(
        from result: TrainingCompletionResult,
        definition: MovementDefinition,
        priorTier: SkillTier
    ) -> ProgramRankAttemptReveal {
        let standardId = definition.rankStandardMovementId
        let updatedProgress = result.movementProgressStates.first {
            $0.rankStandardMovementId == standardId
        }
        let previousTier = resolvedTier(for: result.movementProgressPriorStates[standardId]) ?? priorTier
        let achievedTier = resolvedTier(for: updatedProgress)
            ?? resolvedTier(for: result.movementProgressPriorStates[standardId])
            ?? priorTier

        return ProgramRankAttemptReveal(
            attemptSummary: logSummary,
            tier: achievedTier,
            previousTier: previousTier
        )
    }

    private func resolvedTier(for state: MovementProgressState?) -> SkillTier? {
        guard let state else { return nil }
        return MovementProgressTierResolver.provenTier(
            for: state,
            bodyweightKg: userProfile?.weightKg,
            sex: userProfile?.biologicalSex
        )
    }

    private var logSummary: String {
        switch logMode {
        case .oneRepMax:
            if definition?.rankTemplate == .weightedBodyweight {
                return "Added 1RM \(addedLoadSummary)"
            }
            return "1RM \(formatDisplayWeight(selectedWeightDisplay))"
        case .reps:
            return "\(selectedReps) reps"
        case .hold:
            return "\(ProgramRankExerciseFormatter.seconds(selectedSeconds)) hold"
        }
    }

    private func seedDefaults(from progress: MovementProgressState?) {
        selectedReps = max(1, progress?.bestReps ?? 10)
        switch logMode {
        case .oneRepMax:
            if let oneRepMax = progress?.bestEstimatedOneRepMaxKg ?? progress?.bestLoadKg {
                selectedWeightDisplay = WeightPlatePolicy.editingValue(fromKilograms: oneRepMax, unit: weightUnit)
            } else {
                selectedWeightDisplay = defaultWeightDisplay
            }
        case .reps, .hold:
            selectedWeightDisplay = 0
        }
        selectedSeconds = progress?.bestHoldSeconds
            ?? progress?.bestDurationSeconds
            ?? defaultSeconds
    }

    private var defaultWeightDisplay: Double {
        guard logMode == .oneRepMax else { return 0 }
        if definition?.rankTemplate == .weightedBodyweight { return 0 }
        return weightUnit == .pounds ? 135 : 60
    }

    private var defaultSeconds: Int {
        switch logMode {
        case .hold: return 30
        default: return 30
        }
    }

    private func weightRulerConfig(allowsBodyweight: Bool) -> ProgramRankWeightRulerConfig {
        let step = WeightPlatePolicy.loadIncrement(unit: weightUnit)
        let majorIncrement: Double = weightUnit == .pounds ? 25 : 10
        let start: Double
        let baseEnd: Double

        if definition?.rankTemplate == .weightedBodyweight {
            start = allowsBodyweight ? 0 : step
            baseEnd = weightUnit == .pounds ? 300 : 140
        } else {
            start = weightUnit == .pounds ? 45 : 20
            baseEnd = weightUnit == .pounds ? 1_000 : 450
        }
        let selectedEnd = selectedWeightDisplay > 0
            ? (ceil((selectedWeightDisplay + majorIncrement * 2) / majorIncrement) * majorIncrement)
            : baseEnd
        let end = max(baseEnd, selectedEnd)

        return ProgramRankWeightRulerConfig(
            start: start,
            end: end,
            step: step,
            majorDisplayIncrement: majorIncrement
        )
    }

    private func formatDisplayWeight(_ value: Double) -> String {
        "\(WeightPlatePolicy.formatDisplayValue(value))\(weightUnit.shortLabel)"
    }
}

private struct ProgramRankAttemptReveal: Identifiable, Equatable {
    let id = UUID()
    let attemptSummary: String
    let tier: SkillTier
    let previousTier: SkillTier

    var isRankUp: Bool {
        tier > previousTier
    }
}

private struct ProgramRankAttemptRevealOverlay: View {
    let reveal: ProgramRankAttemptReveal
    let onDismiss: () -> Void

    @State private var isPresented = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        reveal.tier.rewardTextTint
    }

    var body: some View {
        ZStack {
            revealBackdrop
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 42, height: 42)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss rank result")
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                Spacer(minLength: 14)

                ZStack {
                    revealGlow
                    rankBadge
                }
                .frame(height: 238)
                .scaleEffect(isPresented ? 1 : 0.82)
                .opacity(isPresented ? 1 : 0)

                VStack(spacing: 10) {
                    Text(reveal.tier.displayName.uppercased())
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                        .shadow(color: tint.opacity(0.3), radius: 18)

                    Text(reveal.attemptSummary)
                        .font(Font.unbound.titleS.weight(.black))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .offset(y: isPresented ? 0 : 12)
                .opacity(isPresented ? 1 : 0)

                Spacer(minLength: 20)

                revealAction
                    .opacity(isPresented ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                isPresented = true
            }
            if !reduceMotion {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
        }
    }

    private var revealBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.unbound.bg,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(tint.opacity(0.18))
                .blur(radius: 72)
                .frame(width: 280, height: 280)
                .offset(y: -120)
        }
    }

    private var revealGlow: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(pulse ? 0 : 0.38), lineWidth: 1)
                .frame(width: 210, height: 210)
                .scaleEffect(pulse ? 1.38 : 0.86)
                .opacity(pulse ? 0 : 1)

            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 196, height: 196)
                .blur(radius: 18)
        }
    }

    private var rankBadge: some View {
        Image(reveal.tier.assetName)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 188, height: 188)
            .shadow(color: tint.opacity(0.35), radius: 28, y: 8)
            .rotationEffect(.degrees(isPresented ? 0 : -7))
    }

    private var revealAction: some View {
        Button {
            UnboundHaptics.medium()
            onDismiss()
        } label: {
            HStack(spacing: 10) {
                Text("Continue")
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    Color.unbound.surfaceElevated
                    Rectangle().fill(.thinMaterial).opacity(0.18)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(tint.opacity(0.72), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0), location: 0),
                    .init(color: Color.black, location: 0.2),
                    .init(color: Color.black, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private enum ProgramRankRepGraphRange: CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .thirtyDays: return "30D"
        case .ninetyDays: return "90D"
        case .all: return "ALL"
        }
    }

    func cutoff(relativeTo date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: date)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: date)
        case .all:
            return nil
        }
    }
}

private struct ProgramRankProofGraphPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    let isCurrentAttempt: Bool
}

private struct ProgramRankProofHistoryLineGraph: View {
    let entries: [ProgramRankExerciseHistoryEntry]
    let currentValue: Double
    let historyValue: (ProgramRankExerciseHistoryEntry) -> Double?
    let valueFormatter: (Double) -> String
    @Binding var selectedRange: ProgramRankRepGraphRange
    let tint: Color
    let accessibilityUnit: String

    private var dailyHistoryPoints: [ProgramRankProofGraphPoint] {
        let calendar = Calendar.autoupdatingCurrent
        var bestByDay: [Date: ProgramRankProofGraphPoint] = [:]

        for entry in entries {
            guard let value = historyValue(entry) else { continue }
            let day = calendar.startOfDay(for: entry.occurredAt)
            let point = ProgramRankProofGraphPoint(
                id: graphPointId(for: day),
                date: entry.occurredAt,
                value: value,
                isCurrentAttempt: false
            )

            if let existing = bestByDay[day] {
                let isBetterValue = value > existing.value
                let isLaterTie = value == existing.value && entry.occurredAt > existing.date
                if isBetterValue || isLaterTie {
                    bestByDay[day] = point
                }
            } else {
                bestByDay[day] = point
            }
        }

        return bestByDay.values.sorted { $0.date < $1.date }
    }

    private var points: [ProgramRankProofGraphPoint] {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let cutoff = selectedRange.cutoff(relativeTo: now)
        var filtered = dailyHistoryPoints.filter { point in
            guard let cutoff else { return true }
            return point.date >= cutoff
        }

        let current = max(currentValue, 0)
        guard current > 0 else { return filtered }

        let today = calendar.startOfDay(for: now)
        if let todayIndex = filtered.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            if current >= filtered[todayIndex].value {
                filtered[todayIndex] = ProgramRankProofGraphPoint(
                    id: graphPointId(for: today),
                    date: now,
                    value: current,
                    isCurrentAttempt: true
                )
            }
            return filtered
        }

        filtered.append(
            ProgramRankProofGraphPoint(
                id: graphPointId(for: today),
                date: now,
                value: current,
                isCurrentAttempt: true
            )
        )
        return filtered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(valueFormatter(points.last?.value ?? currentValue))
                    .font(Font.unbound.bodyS.weight(.black))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                Spacer(minLength: 10)
                rangePicker
            }

            GeometryReader { proxy in
                let plotPoints = plottedPoints(in: proxy.size)

                ZStack {
                    graphGrid

                    Path { path in
                        guard let first = plotPoints.first else { return }
                        path.move(to: first.location)
                        for point in plotPoints.dropFirst() {
                            path.addLine(to: point.location)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.45), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.86), value: currentValue)

                    ForEach(plotPoints) { point in
                        Circle()
                            .fill(point.source.isCurrentAttempt ? tint : Color.unbound.bg)
                            .frame(width: point.source.isCurrentAttempt ? 11 : 8, height: point.source.isCurrentAttempt ? 11 : 8)
                            .overlay(
                                Circle()
                                    .strokeBorder(tint.opacity(point.source.isCurrentAttempt ? 1 : 0.7), lineWidth: 2)
                            )
                            .shadow(color: point.source.isCurrentAttempt ? tint.opacity(0.42) : .clear, radius: 8)
                            .position(point.location)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 130)

            dateAxis
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank proof progress over time")
        .accessibilityValue("\(valueFormatter(currentValue)) \(accessibilityUnit) selected")
    }

    private var rangePicker: some View {
        HStack(spacing: 14) {
            ForEach(ProgramRankRepGraphRange.allCases) { range in
                Button {
                    selectedRange = range
                    UnboundHaptics.soft()
                } label: {
                    VStack(spacing: 4) {
                        Text(range.label)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .foregroundStyle(selectedRange == range ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                        Rectangle()
                            .fill(selectedRange == range ? tint : Color.clear)
                            .frame(height: 2)
                            .clipShape(Capsule())
                    }
                    .frame(minWidth: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var graphGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(Color.unbound.borderSubtle.opacity(index == 3 ? 0.44 : 0.22))
                    .frame(height: 1)
                if index < 3 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var dateAxis: some View {
        HStack {
            Text(dateLabel(for: visibleStartDate))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
            Spacer(minLength: 8)
            Text("Today")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var visibleStartDate: Date {
        let now = Date()
        if let cutoff = selectedRange.cutoff(relativeTo: now) {
            return cutoff
        }
        return dailyHistoryPoints.first?.date ?? now
    }

    private func graphPointId(for day: Date) -> String {
        "day-\(Int(day.timeIntervalSince1970))"
    }

    private func dateLabel(for date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private struct PlottedPoint: Identifiable {
        let source: ProgramRankProofGraphPoint
        let location: CGPoint

        var id: String { source.id }
    }

    private func plottedPoints(in size: CGSize) -> [PlottedPoint] {
        guard !points.isEmpty, size.width > 0, size.height > 0 else { return [] }

        let now = Date()
        let startDate = visibleStartDate
        let timeSpan = max(now.timeIntervalSince(startDate), 1)
        let values = points.map(\.value)
        let rawMin = values.min() ?? 0
        let rawMax = values.max() ?? 1
        let padding = max((rawMax - rawMin) * 0.18, 1)
        let minValue = max(rawMin - padding, 0)
        let maxValue = max(rawMax + padding, minValue + 1)
        let valueSpan = max(maxValue - minValue, 1)

        return points.map { point in
            let xRatio = min(max(point.date.timeIntervalSince(startDate) / timeSpan, 0), 1)
            let yRatio = CGFloat((point.value - minValue) / valueSpan)
            let location = CGPoint(
                x: CGFloat(xRatio) * size.width,
                y: size.height - (yRatio * size.height)
            )
            return PlottedPoint(source: point, location: location)
        }
    }
}

private struct ProgramRankMetricRuler: View {
    let title: String
    let valueText: String
    let range: ClosedRange<Int>
    @Binding var value: Int
    var unitLabel: String = ""
    var format: (Int) -> String
    var tickLabel: (Int) -> String
    var majorEvery: Int
    var tickSpacing: CGFloat = 14
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(Font.unbound.bodyS.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer(minLength: 8)
                Text(valueText)
                    .font(Font.unbound.bodyS.weight(.bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .monospacedDigit()
            }

            RulerPicker(
                range: range,
                value: $value,
                unitLabel: unitLabel,
                format: format,
                tickLabel: tickLabel,
                majorEvery: majorEvery,
                tickSpacing: tickSpacing
            )

            if let caption {
                Text(caption)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ProgramRankWeightRulerConfig {
    let start: Double
    let end: Double
    let step: Double
    let majorDisplayIncrement: Double

    var range: ClosedRange<Int> {
        0...max(0, Int(((end - start) / step).rounded()))
    }

    var majorEvery: Int {
        max(1, Int((majorDisplayIncrement / step).rounded()))
    }

    func tick(for value: Double) -> Int {
        let rawTick = Int(((value - start) / step).rounded())
        return min(max(rawTick, range.lowerBound), range.upperBound)
    }

    func value(for tick: Int) -> Double {
        let clamped = min(max(tick, range.lowerBound), range.upperBound)
        let rawValue = start + Double(clamped) * step
        return (rawValue * 100).rounded() / 100
    }

    func formatValue(
        _ tick: Int,
        using unit: TrainingWeightUnit,
        isAddedLoad: Bool
    ) -> String {
        let displayValue = value(for: tick)
        if isAddedLoad, displayValue <= 0 {
            return "BW"
        }
        let prefix = isAddedLoad && displayValue > 0 ? "+" : ""
        return "\(prefix)\(WeightPlatePolicy.formatDisplayValue(displayValue))\(unit.shortLabel)"
    }

    func tickLabel(_ tick: Int) -> String {
        let displayValue = value(for: tick)
        if displayValue <= 0 { return "BW" }
        return WeightPlatePolicy.formatDisplayValue(displayValue)
    }
}

private enum ProgramRankExerciseLogMode: Equatable {
    case oneRepMax
    case reps
    case hold

    static func mode(for definition: MovementDefinition) -> ProgramRankExerciseLogMode {
        switch definition.rankTemplate {
        case .barbellStrength, .machineStrength, .weightedBodyweight:
            return .oneRepMax
        case .bodyweightReps:
            return .reps
        case .holdControl, .mobilityDuration:
            return .hold
        case .cardioPerformance:
            switch definition.defaultMetric {
            case .reps: return .reps
            case .holdSeconds, .durationSeconds, .distanceMeters, .calories: return .hold
            }
        case .carrySled:
            return .hold
        case .routineCompletion, .unranked:
            switch definition.loggerMode {
            case .strengthSets: return .oneRepMax
            case .bodyweightSets, .skillAttempts: return .reps
            case .hold: return .hold
            case .carry, .cardio, .mobility, .routinePlayer: return .hold
            }
        }
    }

    var recordsReps: Bool {
        switch self {
        case .reps: return true
        case .oneRepMax, .hold: return false
        }
    }

    var recordsOneRepMax: Bool {
        switch self {
        case .oneRepMax: return true
        case .reps, .hold: return false
        }
    }

    var accessibilityUnit: String {
        switch self {
        case .oneRepMax:
            return "one rep max"
        case .reps:
            return "reps"
        case .hold:
            return "hold time"
        }
    }
}

private struct ProgramRankExerciseHistoryEntry: Identifiable {
    let id: String
    let occurredAt: Date
    let summary: String
    let oneRepMaxKg: Double?
    let reps: Int?
    let holdSeconds: Int?

    var dateText: String {
        occurredAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func entries(
        from logs: [PerformanceLog],
        rankStandardMovementId: String
    ) -> [ProgramRankExerciseHistoryEntry] {
        var entries: [ProgramRankExerciseHistoryEntry] = []
        for log in logs.sorted(by: { $0.completedAt > $1.completedAt }) {
            for block in log.blocks {
                for exercise in block.exercises where !exercise.skipped {
                    let resolvedStandard = exercise.rankStandardMovementId
                        ?? MovementResolver.resolve(exercise.name).rankStandardMovementId
                    guard resolvedStandard == rankStandardMovementId else { continue }

                    for set in exercise.sets where !set.isWarmup {
                        guard let summary = ProgramRankExerciseFormatter.summary(for: set) else { continue }
                        entries.append(
                            ProgramRankExerciseHistoryEntry(
                                id: "\(log.id):\(exercise.id):\(set.id)",
                                occurredAt: log.completedAt,
                                summary: summary,
                                oneRepMaxKg: estimatedOneRepMaxKg(weightKg: set.weightKg, reps: set.reps),
                                reps: set.reps,
                                holdSeconds: set.holdSeconds ?? set.durationSeconds
                            )
                        )
                    }
                }
            }
        }
        return Array(entries.prefix(80))
    }

    private static func estimatedOneRepMaxKg(weightKg: Double?, reps: Int?) -> Double? {
        guard let weightKg, weightKg > 0 else { return nil }
        let safeReps = max(reps ?? 1, 1)
        guard safeReps > 1 else { return weightKg }
        return weightKg * (1.0 + Double(safeReps) / 30.0)
    }
}

private enum ProgramRankExerciseFormatter {
    static func bestSummary(_ progress: MovementProgressState) -> String {
        let unit = WeightPlatePolicy.currentUnit
        if let estimated = progress.bestEstimatedOneRepMaxKg {
            return "1RM \(WeightPlatePolicy.formatLoggedWeight(estimated, unit: unit))\(unit.shortLabel)"
        }
        if let load = progress.bestLoadKg {
            let weight = "\(WeightPlatePolicy.formatLoggedWeight(load, unit: unit))\(unit.shortLabel)"
            if let reps = progress.bestReps {
                return "\(weight) x \(reps)"
            }
            return weight
        }
        if let reps = progress.bestReps {
            return "\(reps) reps"
        }
        if let hold = progress.bestHoldSeconds {
            return "\(seconds(hold)) hold"
        }
        if let duration = progress.bestDurationSeconds {
            return "\(seconds(duration)) hold"
        }
        return progress.rankTemplate.displayName
    }

    static func summary(for set: PerformanceSet) -> String? {
        let unit = WeightPlatePolicy.currentUnit
        if let weight = set.weightKg, let reps = set.reps {
            return "\(WeightPlatePolicy.formatLoggedWeight(weight, unit: unit))\(unit.shortLabel) x \(reps)"
        }
        if let reps = set.reps {
            return "\(reps) reps"
        }
        if let hold = set.holdSeconds {
            return "\(seconds(hold)) hold"
        }
        if let duration = set.durationSeconds {
            return "\(seconds(duration)) hold"
        }
        return nil
    }

    static func seconds(_ value: Int) -> String {
        if value < 60 { return "\(value)s" }
        let minutes = value / 60
        let seconds = value % 60
        if seconds == 0 { return "\(minutes)m" }
        return "\(minutes):" + String(format: "%02d", seconds)
    }

    static func distance(_ meters: Int) -> String {
        if meters >= 1_000 {
            let kilometers = Double(meters) / 1_000.0
            if abs(kilometers.rounded() - kilometers) < 0.001 {
                return "\(Int(kilometers.rounded()))km"
            }
            return String(format: "%.1fkm", kilometers)
        }
        return "\(meters)m"
    }
}
