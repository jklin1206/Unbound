import SwiftUI

// MARK: - ClusterCardView
//
// Rich, full-width card for one display tree on the Skill Map landing
// screen. Shows:
//   • Header: glyph + display name (uppercased, tracked) + tagline
//   • Progress: achieved / total + thin bar
//   • NOW chip: current `.attempting` node + level (if any)
//   • Farthest achievement: completed node title + rank chip
//   • Locked state: 40% opacity, dashed border, REQUIRES caption
//
// Tap handling is owned by the parent view. Display trees drill directly
// into their staircase.

struct ClusterCardView: View {
    let tree: SkillDisplayTree
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    let skillProgress: SkillProgressService?  // for level lookups, optional

    private var total: Int { tree.totalCount(in: graph) }
    private var achieved: Int { tree.achievedCount(in: graph, states: nodeStates) }
    private var progressPct: Double {
        total == 0 ? 0 : Double(achieved) / Double(total)
    }
    private var activeNode: SkillNode? {
        tree.activeNode(in: graph, states: nodeStates)
    }
    private var achievementPreview: AchievementPreview? {
        if let achievedNode = tree.farthestAchievement(in: graph, states: nodeStates) {
            return AchievementPreview(node: achievedNode, label: "FARTHEST", icon: "trophy.fill", isAchieved: true)
        }
        if let activeNode {
            return AchievementPreview(node: activeNode, label: "CHASING", icon: "scope", isAchieved: false)
        }
        return nil
    }
    private var isLocked: Bool {
        tree.isLocked(in: graph, states: nodeStates)
    }

    var body: some View {
        if isLocked {
            lockedBody
        } else {
            unlockedBody
        }
    }

    // MARK: - Unlocked body

    private var unlockedBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            divider
            progressBlock
            if let node = activeNode, achievementPreview?.isAchieved ?? true {
                nowChip(node)
            }
            if let preview = achievementPreview {
                achievementRow(preview)
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
                .strokeBorder(
                    activeNode == nil ? Color.unbound.border : Color.unbound.accent.opacity(0.35),
                    lineWidth: 1
                )
        )
        .shadow(
            color: activeNode == nil ? .clear : Color.unbound.accent.opacity(0.18),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    // MARK: - Locked body

    private var lockedBody: some View {
        let requiredName = tree.requiredClusterName()?.uppercased() ?? "—"
        return VStack(alignment: .leading, spacing: 14) {
            headerRow
            divider
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("REQUIRES · \(requiredName) KEYSTONE")
                    .font(Font.unbound.captionS.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            Text("\(total) skills · locked")
                .font(Font.unbound.captionS)
                .tracking(0.8)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.unbound.border,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
        .opacity(0.6)
    }

    // MARK: - Pieces

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surfaceElevated)
                Image(systemName: tree.glyph)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(tree.displayName.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2.2)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(tree.chapterSubtitle)
                        .font(Font.unbound.captionS.weight(.regular).italic())
                        .tracking(0.2)
                        .foregroundStyle(Color.unbound.accent.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Text(tree.tagline)
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if tree.isUmbrella {
                subClusterPill
            }
        }
    }

    private var subClusterPill: some View {
        HStack(spacing: 4) {
            Text("3")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
            Text("STAGES")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.2)
        }
        .foregroundStyle(Color.unbound.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.unbound.accent.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.unbound.border)
            .frame(height: 1)
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("PROGRESS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(achieved) / \(total)")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.border)
                    Capsule()
                        .fill(Color.unbound.accent)
                        .frame(width: max(2, geo.size.width * progressPct))
                }
            }
            .frame(height: 4)
        }
    }

    private func nowChip(_ node: SkillNode) -> some View {
        let currentLevel = skillProgress?.skillProgress[node.id]?.currentLevel ?? 1
        return HStack(spacing: 8) {
            Circle()
                .fill(Color.unbound.accent)
                .frame(width: 6, height: 6)
            Text("NOW")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.accent)
            Text("·")
                .foregroundStyle(Color.unbound.textTertiary)
            Text(node.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text("LV \(currentLevel)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.unbound.surfaceElevated))
    }

    private func achievementRow(_ preview: AchievementPreview) -> some View {
        let node = preview.node
        return HStack(spacing: 10) {
            Image(systemName: preview.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(preview.isAchieved ? Color.unbound.impact : Color.unbound.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(preview.label)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(node.title)
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()
            let userId = AuthService.shared.currentUserId ?? "anonymous"
            let skillTier = UserSkillTierStore.shared.load(userId: userId).perSkill[node.id] ?? .initiate
            TierBadge(tier: skillTier, compact: true)
            rankPill(rank: node.rank)
        }
    }

    private func rankPill(rank: SkillRank) -> some View {
        Image(rank.rankTitle.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
            .shadow(color: rank.accentColor.opacity(0.35), radius: 8)
            .accessibilityLabel("\(rank.rankTitle.displayName) difficulty")
    }
}

private struct AchievementPreview {
    let node: SkillNode
    let label: String
    let icon: String
    let isAchieved: Bool
}

// MARK: - Convenience init (no progress service)

extension ClusterCardView {
    init(tree: SkillDisplayTree, graph: SkillGraph, nodeStates: [String: NodeState]) {
        self.init(tree: tree, graph: graph, nodeStates: nodeStates, skillProgress: nil)
    }
}
