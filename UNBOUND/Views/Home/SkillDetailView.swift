import SwiftUI

// MARK: - SkillDetailView (Phase 2i — typography + hero redesign)
//
// Full-screen detail view presented via `.fullScreenCover(item:)` from any
// cluster view's hex tap. Phase 2i softens the whole screen: Title Case
// section headers, full-width silhouette hero with a top-left overlay, small
// numbered level circles, merged Progress + Next Level card, and a sentence-
// case Train CTA.
//
// Layout, top-to-bottom:
//   1. Hero (nav chevron + bookmark overlaid on a full-width silhouette card
//      with top-left title / subtitle)
//   2. Subtitle / description blurb
//   3. Requirements card (✓/🔒 rows w/ separators, "Or" chip between groups)
//   4. Progress card (level + XP bar + Next Level mini-header w/ criterion)
//   5. Levels selector — 5 small numbered circles + inline expansion
//   6. Train This Skill CTA (sentence case, softer)
//   7. 4 tabs: Overview / Progressions / Technique / Programs
//
// Real AI hero art arrives in Phase 4. This view remains tolerant of missing
// art — it renders a glyph + violet glow as the placeholder silhouette.

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
                hero

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
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero
    //
    // Full-width silhouette card. Title + subtitle overlay the top-left,
    // nav chevron sits above them, bookmark floats top-right. The silhouette
    // (SF Symbol placeholder for now) centers in the card with a violet glow.

    private var hero: some View {
        ZStack(alignment: .top) {
            // Vertical gradient backdrop.
            LinearGradient(
                colors: [
                    Color.unbound.bg,
                    Color.unbound.accent.opacity(0.20),
                    Color.unbound.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Silhouette (AI art slot in Phase 4).
            VStack {
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(Color.unbound.accent.opacity(0.22))
                        .frame(width: 200, height: 200)
                        .blur(radius: 46)
                    Image(systemName: node.glyph)
                        .font(.system(size: 140, weight: .regular))
                        .foregroundStyle(Color.unbound.accent)
                        .shadow(color: Color.unbound.accent.opacity(0.55), radius: 28)
                }
                .frame(height: 220)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            // Top-left title + subtitle overlay, plus top-right bookmark.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    backButton
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title)
                            .font(.system(.title, design: .default).weight(.bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Text(heroSubtitle)
                            .font(.system(.subheadline))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 12)
                bookmarkButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 56) // clear status bar
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var backButton: some View {
        Button {
            UnboundHaptics.medium()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }

    private var bookmarkButton: some View {
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
                .background(Circle().fill(Color.unbound.surfaceElevated.opacity(0.9)))
        }
        .buttonStyle(.plain)
        .padding(.top, 44) // aligned with title, not with chevron
    }

    /// "Pull Tree · Advanced Skill" style string. Tree = cluster displayName,
    /// followed by a tier description that reads more like prose than a code.
    private var heroSubtitle: String {
        let tree = "\(node.cluster.displayName) Tree"
        return "\(tree) · \(rankDescription(for: node.rank)) Skill"
    }

    /// Plain-English label for a rank — used as the hero subtitle.
    /// Derived from rank, not tier, so the hero and the tree gutter stay
    /// in agreement.
    private func rankDescription(for rank: SkillRank) -> String {
        switch rank {
        case .e: return "Starter"
        case .d: return "Beginner"
        case .c: return "Intermediate"
        case .b: return "Advanced"
        case .a: return "Elite"
        case .s: return "Mythic"
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
            sectionHeader("Requirements")

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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(node.prereqs.enumerated()), id: \.offset) { idx, group in
                prereqGroupBlock(group: group)

                if idx < node.prereqs.count - 1 {
                    orChipRow
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(roundedCardBackground)
    }

    /// Renders each id inside a group as its own separated row.
    @ViewBuilder
    private func prereqGroupBlock(group: PrerequisiteGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(group.nodeIds.enumerated()), id: \.offset) { idx, pid in
                prereqLine(id: pid)
                    .padding(.vertical, 10)
                if idx < group.nodeIds.count - 1 {
                    Rectangle()
                        .fill(Color.unbound.border.opacity(0.5))
                        .frame(height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func prereqLine(id: String) -> some View {
        let resolved = graph.node(id: id)
        let state = nodeStates[id] ?? .locked
        let met = (state == .achieved || state == .mastered)
        let inProgress = (state == .attempting)

        HStack(spacing: 12) {
            Image(systemName: prereqIcon(met: met, inProgress: inProgress))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(prereqIconColor(met: met, inProgress: inProgress))
                .frame(width: 20, alignment: .center)
            Text(resolved?.title ?? id)
                .font(Font.unbound.bodyM)
                .foregroundStyle(met ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if met {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
            }
        }
    }

    private func prereqIcon(met: Bool, inProgress: Bool) -> String {
        if met { return "checkmark.circle.fill" }
        if inProgress { return "pencil.circle" }
        return "lock.fill"
    }

    private func prereqIconColor(met: Bool, inProgress: Bool) -> Color {
        if met { return Color.unbound.accent }
        if inProgress { return Color.unbound.accent.opacity(0.7) }
        return Color.unbound.textTertiary
    }

    /// Lowercase "Or" chip centered on a hairline — between groups only.
    private var orChipRow: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
            Text("Or")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.unbound.surfaceElevated))
                .overlay(Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Progress card (merged with Next Level)

    private var progressCard: some View {
        let sp = skillProgress.currentSkillProgress(for: node.id)
        let state = nodeStates[node.id] ?? .locked
        let isMastered = (state == .mastered && sp.currentLevel == 5)
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Progress")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Level \(sp.currentLevel)")
                        .font(.system(.title3).weight(.semibold))
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
                    nextLevelBlock(progress: sp)
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

    /// Inlined "Next Level" header + criterion body. Replaces the separate
    /// uppercase NEXT LEVEL row.
    @ViewBuilder
    private func nextLevelBlock(progress sp: SkillProgress) -> some View {
        let nextLevelIdx = min(sp.currentLevel, max(0, node.levels.count - 1))
        if node.levels.indices.contains(nextLevelIdx) {
            let lvl = node.levels[nextLevelIdx]
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Level")
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(lvl.criterion)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        } else {
            Text("Keep training")
                .font(.system(.subheadline).weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }

    private var masteredBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
            Text("Mastered")
                .font(.system(.caption).weight(.semibold))
        }
        .foregroundStyle(Color.unbound.impact)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.unbound.impact.opacity(0.15)))
        .overlay(Capsule().strokeBorder(Color.unbound.impact.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Levels selector (numbered circles)

    private var levelsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Levels")

            HStack(spacing: 16) {
                Spacer(minLength: 0)
                ForEach(1...5, id: \.self) { i in
                    levelCircle(level: i)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            if let lvl = expandedLevel, let detail = levelDetail(for: lvl) {
                expandedLevelCard(level: lvl, detail: detail)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// 34pt numbered circle. Active level = accent fill + bg-colored digit.
    /// Inactive = surface fill with subtle border. Disabled (no data) dims.
    private func levelCircle(level: Int) -> some View {
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
            ZStack {
                Circle()
                    .fill(isActive ? Color.unbound.accent : Color.unbound.surface)
                Circle()
                    .strokeBorder(
                        levelCircleBorder(active: isActive, expanded: isExpanded),
                        lineWidth: isActive ? 2 : 1
                    )
                Text("\(level)")
                    .font(.system(.footnote).weight(.semibold))
                    .foregroundStyle(levelCircleText(active: isActive, hasData: hasData))
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(!hasData)
        .opacity(hasData ? 1.0 : 0.45)
    }

    private func levelCircleBorder(active: Bool, expanded: Bool) -> Color {
        if active { return Color.unbound.accent }
        if expanded { return Color.unbound.accent.opacity(0.65) }
        return Color.unbound.border
    }

    private func levelCircleText(active: Bool, hasData: Bool) -> Color {
        if !hasData { return Color.unbound.textTertiary }
        return active ? Color.unbound.bg : Color.unbound.textPrimary
    }

    private func levelDetail(for level: Int) -> SkillLevel? {
        node.levels.first(where: { $0.level == level })
    }

    private func expandedLevelCard(level: Int, detail: SkillLevel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Level \(level)")
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundStyle(Color.unbound.accent)
                Spacer()
                Text("+\(detail.xpReward) XP")
                    .font(Font.unbound.monoS)
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
        case .firstRep:                        return "Target — first clean rep"
        case .reps(let count):                 return "Target — \(count) reps"
        case .hold(let seconds):               return "Target — \(seconds)s hold"
        case .weight(let mult):                return "Target — \(formatMult(mult)) bodyweight"
        case .distance(let meters):            return "Target — \(Int(meters))m"
        case .duration(let seconds):           return "Target — \(seconds)s"
        case .combined:                        return "Target — combined metric"
        }
    }

    private func formatMult(_ mult: Double) -> String {
        mult == mult.rounded() ? "\(Int(mult))×" : String(format: "%.2g×", mult)
    }

    // MARK: - Train CTA

    private var trainCTA: some View {
        UnboundButton(title: "Train This Skill", icon: "dumbbell.fill") {
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
        .background(Capsule().fill(Color.unbound.surface))
        .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
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
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(
                    isSelected ? Color.unbound.textPrimary : Color.unbound.textSecondary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Capsule().fill(isSelected ? Color.unbound.accent.opacity(0.22) : Color.clear)
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
            OverviewTabView(node: node, graph: graph)
        case .progressions:
            ProgressionsTabView(node: node, graph: graph, nodeStates: nodeStates)
        case .technique:
            TechniqueTabView(node: node)
        case .programs:
            ProgramsTabView(node: node)
        }
    }

    // MARK: - Shared styling helpers

    /// Phase 2i header style — Title Case, semibold headline, primary text
    /// color, no tracking. Replaces the old uppercase + tracking treatment.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline).weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
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

    /// Tab labels stay uppercase — tabs legitimately use that style — but
    /// the render side applies reduced tracking (1.2) so they don't shout.
    var label: String {
        switch self {
        case .overview:     return "OVERVIEW"
        case .progressions: return "PROGRESSIONS"
        case .technique:    return "TECHNIQUE"
        case .programs:     return "PROGRAMS"
        }
    }
}
