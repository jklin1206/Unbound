import SwiftUI

// MARK: - SkillDetailView (Phase 3a)
//
// Full-screen detail view presented via `.fullScreenCover(item:)` from any
// cluster view's hex tap. Replaces the legacy SkillNodeDetailSheet bottom
// sheet with a premium dedicated screen.
//
// Layout, top-to-bottom:
//   1. Custom nav bar (back + bookmark)
//   2. Hero section (glyph + cluster crumb + title + rank chip)
//   3. Subtitle / description blurb
//   4. Requirements card (OR-of-AND prereq groups)
//   5. Progress card (level + XP bar from SkillProgressService)
//   6. Levels selector (5 pills + inline expansion)
//   7. TRAIN THIS SKILL CTA (awards session XP)
//   8. 4 tabs: OVERVIEW / PROGRESSIONS / TECHNIQUE / PROGRAMS
//
// Real AI hero art arrives in Phase 4. Authored educational content (tabs
// OVERVIEW/TECHNIQUE) currently derives what it can from existing node
// metadata and renders tagged placeholders for the rest.

struct SkillDetailView: View {
    let node: SkillNode
    let graph: SkillGraph
    let nodeStates: [String: NodeState]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SkillDetailTab = .overview
    @State private var expandedLevel: Int? = nil
    @State private var isBookmarked: Bool = false

    @Bindable private var skillProgress = SkillProgressService.shared

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navBar
                hero
                    .padding(.top, 4)

                VStack(spacing: 20) {
                    subtitleBlock
                    requirementsCard
                    progressCard
                    levelsSelector
                    trainCTA
                    tabBar
                    tabContent
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 12) {
            Button {
                UnboundHaptics.medium()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                UnboundHaptics.medium()
                isBookmarked.toggle()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(
                        isBookmarked ? Color.unbound.accent : Color.unbound.textSecondary
                    )
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient backdrop
            LinearGradient(
                colors: [
                    Color.unbound.bg,
                    Color.unbound.accent.opacity(0.25),
                    Color.unbound.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Centered glyph (AI art placeholder)
            Image(systemName: node.glyph)
                .font(.system(size: 96, weight: .regular))
                .foregroundStyle(Color.unbound.accent)
                .shadow(color: Color.unbound.accent.opacity(0.55), radius: 24)
                .frame(maxWidth: .infinity)

            // Bottom-left identity overlay
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(clusterCrumb)
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text(node.title)
                        .font(Font.unbound.titleL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                rankChip
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var clusterCrumb: String {
        let cluster = node.cluster.displayName.uppercased()
        let tierLabel = tierName(for: node.tier)
        return "\(cluster) · \(tierLabel)"
    }

    private func tierName(for tier: Int) -> String {
        switch tier {
        case ...1: return "NOVICE"
        case 2:    return "FOUNDATION"
        case 3:    return "INTERMEDIATE"
        case 4:    return "ADVANCED"
        case 5:    return "ELITE"
        case 6:    return "ELITE+"
        default:   return "MYTHIC"
        }
    }

    private var rankChip: some View {
        ZStack {
            Hexagon()
                .fill(Color.unbound.surface)
                .frame(width: 56, height: 56)
            Hexagon()
                .strokeBorder(node.rank.accentColor, lineWidth: 2)
                .shadow(color: node.rank.accentColor.opacity(0.45), radius: 8)
                .frame(width: 56, height: 56)
            Text(node.rank.letter)
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }

    // MARK: - Subtitle block

    private var subtitleBlock: some View {
        let text: String = {
            if !node.subtitle.isEmpty { return node.subtitle }
            return "Work toward this skill through the level progression."
        }()
        return HStack(alignment: .top) {
            Text(text)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Requirements card

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("REQUIREMENTS")

            if node.prereqs.isEmpty {
                emptyPrereqCard
            } else {
                prereqGroups
            }
        }
    }

    private var emptyPrereqCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
            Text("No prerequisites — start any time.")
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    private var prereqGroups: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(node.prereqs.enumerated()), id: \.offset) { idx, group in
                prereqGroupRow(group: group)

                if idx < node.prereqs.count - 1 {
                    orDivider
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    private func prereqGroupRow(group: PrerequisiteGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(group.nodeIds, id: \.self) { pid in
                prereqLine(id: pid)
            }
        }
    }

    @ViewBuilder
    private func prereqLine(id: String) -> some View {
        let resolved = graph.node(id: id)
        let state = nodeStates[id] ?? .locked
        let met = (state == .achieved || state == .mastered)
        HStack(spacing: 10) {
            Image(systemName: met ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    met ? Color.unbound.accent : Color.unbound.textTertiary
                )
            Text(resolved?.title ?? id)
                .font(Font.unbound.bodyM)
                .foregroundStyle(
                    met ? Color.unbound.textPrimary : Color.unbound.textTertiary
                )
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
            Text("OR")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.unbound.surfaceElevated)
                )
                .overlay(
                    Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                )
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Progress card

    private var progressCard: some View {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let state = nodeStates[node.id] ?? .locked
        let isMastered = (state == .mastered && sp.currentLevel == 5)
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PROGRESS")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("LEVEL \(sp.currentLevel)")
                        .font(Font.unbound.monoL)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Spacer()
                    if isMastered {
                        masteredBadge
                    } else {
                        Text("\(sp.xpInLevel) / \(sp.xpToNextLevel) XP")
                            .font(Font.unbound.monoS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }

                xpBar(fraction: xpFraction(sp))

                if !isMastered {
                    nextLevelRow(progress: sp)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(roundedCardBackground)
        }
    }

    private func xpFraction(_ sp: SkillProgress) -> Double {
        guard sp.xpToNextLevel > 0 else { return 0 }
        return max(0, min(1, Double(sp.xpInLevel) / Double(sp.xpToNextLevel)))
    }

    private func xpBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.unbound.surfaceElevated)
                Capsule()
                    .fill(Color.unbound.accent)
                    .frame(width: max(0, geo.size.width * CGFloat(fraction)))
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private func nextLevelRow(progress sp: SkillProgress) -> some View {
        let nextLevelIdx = min(sp.currentLevel, max(0, node.levels.count - 1))
        if node.levels.indices.contains(nextLevelIdx) {
            let lvl = node.levels[nextLevelIdx]
            HStack(spacing: 8) {
                Text("NEXT LEVEL:")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(lvl.criterion)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        } else {
            Text("KEEP TRAINING")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textTertiary)
        }
    }

    private var masteredBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
            Text("MASTERED")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.6)
        }
        .foregroundStyle(Color.unbound.impact)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.unbound.impact.opacity(0.15))
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Levels selector

    private var levelsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("LEVELS")

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    levelPill(level: i)
                }
            }

            if let lvl = expandedLevel, let detail = levelDetail(for: lvl) {
                expandedLevelCard(level: lvl, detail: detail)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func levelPill(level: Int) -> some View {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let isActive = level == sp.currentLevel
        let hasData = node.levels.contains(where: { $0.level == level })
        let isExpanded = expandedLevel == level
        return Button {
            UnboundHaptics.medium()
            withAnimation(.easeOut(duration: 0.22)) {
                expandedLevel = isExpanded ? nil : level
            }
        } label: {
            Text(hasData ? "LV \(level)" : "—")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(pillForeground(active: isActive, hasData: hasData))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    Capsule().fill(pillFill(active: isActive))
                )
                .overlay(
                    Capsule().strokeBorder(pillBorder(active: isActive, expanded: isExpanded), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasData)
        .opacity(hasData ? 1.0 : 0.45)
    }

    private func pillFill(active: Bool) -> Color {
        active ? Color.unbound.accent.opacity(0.22) : Color.unbound.surface
    }

    private func pillBorder(active: Bool, expanded: Bool) -> Color {
        if active { return Color.unbound.accent }
        if expanded { return Color.unbound.accent.opacity(0.65) }
        return Color.unbound.border
    }

    private func pillForeground(active: Bool, hasData: Bool) -> Color {
        if !hasData { return Color.unbound.textTertiary }
        return active ? Color.unbound.accent : Color.unbound.textSecondary
    }

    private func levelDetail(for level: Int) -> SkillLevel? {
        node.levels.first(where: { $0.level == level })
    }

    private func expandedLevelCard(level: Int, detail: SkillLevel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("LEVEL \(level)")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text("+\(detail.xpReward) XP")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            Text(detail.criterion)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(levelTargetLabel(detail.target))
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    private func levelTargetLabel(_ target: LevelTarget) -> String {
        switch target {
        case .firstRep:                        return "TARGET — first clean rep"
        case .reps(let count):                 return "TARGET — \(count) reps"
        case .hold(let seconds):               return "TARGET — \(seconds)s hold"
        case .weight(let mult):                return "TARGET — \(formatMult(mult)) bodyweight"
        case .distance(let meters):            return "TARGET — \(Int(meters))m"
        case .duration(let seconds):           return "TARGET — \(seconds)s"
        case .combined:                        return "TARGET — combined metric"
        }
    }

    private func formatMult(_ mult: Double) -> String {
        mult == mult.rounded() ? "\(Int(mult))×" : String(format: "%.2g×", mult)
    }

    // MARK: - Train CTA

    private var trainCTA: some View {
        UnboundButton(title: "TRAIN THIS SKILL", icon: "dumbbell.fill") {
            UnboundHaptics.medium()
            Task {
                await SkillProgressService.shared.awardSessionXP(forNodeId: node.id)
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(SkillDetailTab.allCases, id: \.self) { tab in
                tabSegment(tab)
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Color.unbound.surface)
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func tabSegment(_ tab: SkillDetailTab) -> some View {
        let isSelected = tab == selectedTab
        return Button {
            UnboundHaptics.medium()
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            Text(tab.label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(
                    isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.unbound.accent : Color.clear,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            OverviewTabView(node: node)
        case .progressions:
            ProgressionsTabView(node: node, graph: graph, nodeStates: nodeStates)
        case .technique:
            TechniqueTabView(node: node)
        case .programs:
            ProgramsTabView(node: node)
        }
    }

    // MARK: - Shared styling helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(2.0)
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private var roundedCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        }
    }
}

// MARK: - Tab enum

enum SkillDetailTab: String, CaseIterable, Hashable {
    case overview, progressions, technique, programs

    var label: String {
        switch self {
        case .overview:     return "OVERVIEW"
        case .progressions: return "PROGRESSIONS"
        case .technique:    return "TECHNIQUE"
        case .programs:     return "PROGRAMS"
        }
    }
}
