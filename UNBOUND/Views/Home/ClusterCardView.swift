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
                SkillTreeIconMark(tree: tree, isLocked: isLocked)
                    .padding(5)
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
            Text("LVL \(currentLevel)")
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

private struct SkillTreeIconMark: View {
    let tree: SkillDisplayTree
    let isLocked: Bool

    private var primary: Color {
        isLocked ? Color.unbound.textTertiary : Color.unbound.textPrimary
    }

    private var accent: Color {
        isLocked ? Color.unbound.border : Color.unbound.accent
    }

    var body: some View {
        Group {
            if UIImage(named: representativeAssetName) != nil {
                Image(representativeAssetName)
                    .renderingMode(representativeAssetName.hasSuffix("_highlight") ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(primary)
                    .scaleEffect(representativeAssetName.hasSuffix("_highlight") ? 1.22 : 1.0)
                    .shadow(color: Color.black.opacity(isLocked ? 0.1 : 0.45), radius: 2)
                    .shadow(color: accent.opacity(isLocked ? 0 : 0.45), radius: 5)
                    .overlay(alignment: .bottom) {
                        Capsule()
                            .fill(accent.opacity(isLocked ? 0.18 : 0.5))
                            .frame(width: 19, height: 2)
                            .offset(y: 3)
                    }
            } else {
                Canvas { context, size in
                    drawGuideLines(in: &context, size: size)

                    switch tree {
                    case .pull:
                        drawPull(in: &context, size: size)
                    case .push:
                        drawPush(in: &context, size: size)
                    case .legs:
                        drawLegs(in: &context, size: size)
                    case .coreLevers:
                        drawCore(in: &context, size: size)
                    case .handstand:
                        drawHandstand(in: &context, size: size)
                    case .planche:
                        drawPlanche(in: &context, size: size)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var representativeAssetName: String {
        let base: String = switch tree {
        case .pull: "pp_pullup"
        case .push: "cal_pushup"
        case .legs: "ld_pistol-squat"
        case .coreLevers: "cl_vertical-l-sit"
        case .handstand: "hs_handstand"
        case .planche: "pl_full-planche"
        }
        let highlight = "\(base)_highlight"
        return UIImage(named: highlight) == nil ? base : highlight
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    private func stroke(
        _ path: Path,
        in context: inout GraphicsContext,
        color: Color,
        width: CGFloat = 2.2
    ) {
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func line(
        _ a: CGPoint,
        _ b: CGPoint,
        in context: inout GraphicsContext,
        color: Color,
        width: CGFloat = 2.2
    ) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        stroke(path, in: &context, color: color, width: width)
    }

    private func circle(
        center: CGPoint,
        radius: CGFloat,
        in context: inout GraphicsContext,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func drawGuideLines(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: point(0.16, 0.82, in: size))
        path.addLine(to: point(0.84, 0.82, in: size))
        stroke(path, in: &context, color: accent.opacity(0.22), width: 1.1)
    }

    private func drawPull(in context: inout GraphicsContext, size: CGSize) {
        line(point(0.16, 0.18, in: size), point(0.84, 0.18, in: size), in: &context, color: accent, width: 2.4)
        circle(center: point(0.5, 0.36, in: size), radius: size.width * 0.075, in: &context, color: primary)
        line(point(0.34, 0.18, in: size), point(0.44, 0.42, in: size), in: &context, color: primary)
        line(point(0.66, 0.18, in: size), point(0.56, 0.42, in: size), in: &context, color: primary)
        line(point(0.5, 0.44, in: size), point(0.5, 0.66, in: size), in: &context, color: primary)
        line(point(0.5, 0.66, in: size), point(0.38, 0.78, in: size), in: &context, color: primary)
        line(point(0.5, 0.66, in: size), point(0.62, 0.78, in: size), in: &context, color: primary)
    }

    private func drawPush(in context: inout GraphicsContext, size: CGSize) {
        line(point(0.15, 0.76, in: size), point(0.86, 0.76, in: size), in: &context, color: accent.opacity(0.45), width: 1.6)
        circle(center: point(0.28, 0.48, in: size), radius: size.width * 0.07, in: &context, color: primary)
        line(point(0.34, 0.51, in: size), point(0.72, 0.62, in: size), in: &context, color: primary, width: 2.8)
        line(point(0.72, 0.62, in: size), point(0.86, 0.65, in: size), in: &context, color: primary)
        line(point(0.43, 0.54, in: size), point(0.38, 0.76, in: size), in: &context, color: primary)
        line(point(0.55, 0.57, in: size), point(0.58, 0.76, in: size), in: &context, color: primary)
    }

    private func drawLegs(in context: inout GraphicsContext, size: CGSize) {
        circle(center: point(0.42, 0.28, in: size), radius: size.width * 0.07, in: &context, color: primary)
        line(point(0.43, 0.36, in: size), point(0.34, 0.56, in: size), in: &context, color: primary)
        line(point(0.36, 0.48, in: size), point(0.22, 0.56, in: size), in: &context, color: primary)
        line(point(0.36, 0.48, in: size), point(0.5, 0.56, in: size), in: &context, color: primary)
        line(point(0.34, 0.56, in: size), point(0.48, 0.7, in: size), in: &context, color: primary)
        line(point(0.48, 0.7, in: size), point(0.4, 0.82, in: size), in: &context, color: primary)
        line(point(0.38, 0.58, in: size), point(0.82, 0.58, in: size), in: &context, color: accent, width: 2.4)
    }

    private func drawCore(in context: inout GraphicsContext, size: CGSize) {
        line(point(0.2, 0.66, in: size), point(0.2, 0.34, in: size), in: &context, color: accent.opacity(0.7), width: 1.7)
        line(point(0.8, 0.66, in: size), point(0.8, 0.34, in: size), in: &context, color: accent.opacity(0.7), width: 1.7)
        line(point(0.16, 0.5, in: size), point(0.84, 0.5, in: size), in: &context, color: accent, width: 1.8)
        circle(center: point(0.42, 0.28, in: size), radius: size.width * 0.065, in: &context, color: primary)
        line(point(0.42, 0.36, in: size), point(0.42, 0.58, in: size), in: &context, color: primary)
        line(point(0.42, 0.58, in: size), point(0.78, 0.58, in: size), in: &context, color: primary, width: 2.7)
        line(point(0.36, 0.42, in: size), point(0.24, 0.5, in: size), in: &context, color: primary)
        line(point(0.48, 0.42, in: size), point(0.62, 0.5, in: size), in: &context, color: primary)
    }

    private func drawHandstand(in context: inout GraphicsContext, size: CGSize) {
        circle(center: point(0.5, 0.66, in: size), radius: size.width * 0.065, in: &context, color: primary)
        line(point(0.5, 0.58, in: size), point(0.5, 0.34, in: size), in: &context, color: primary, width: 2.8)
        line(point(0.5, 0.36, in: size), point(0.36, 0.18, in: size), in: &context, color: primary)
        line(point(0.5, 0.36, in: size), point(0.64, 0.18, in: size), in: &context, color: primary)
        line(point(0.43, 0.7, in: size), point(0.34, 0.82, in: size), in: &context, color: accent, width: 2.4)
        line(point(0.57, 0.7, in: size), point(0.66, 0.82, in: size), in: &context, color: accent, width: 2.4)
    }

    private func drawPlanche(in context: inout GraphicsContext, size: CGSize) {
        line(point(0.2, 0.76, in: size), point(0.33, 0.76, in: size), in: &context, color: accent, width: 1.8)
        line(point(0.62, 0.76, in: size), point(0.75, 0.76, in: size), in: &context, color: accent, width: 1.8)
        circle(center: point(0.28, 0.42, in: size), radius: size.width * 0.06, in: &context, color: primary)
        line(point(0.34, 0.44, in: size), point(0.72, 0.5, in: size), in: &context, color: primary, width: 2.8)
        line(point(0.72, 0.5, in: size), point(0.88, 0.46, in: size), in: &context, color: primary)
        line(point(0.44, 0.46, in: size), point(0.34, 0.76, in: size), in: &context, color: primary)
        line(point(0.55, 0.48, in: size), point(0.62, 0.76, in: size), in: &context, color: primary)
    }
}

// MARK: - Convenience init (no progress service)

extension ClusterCardView {
    init(tree: SkillDisplayTree, graph: SkillGraph, nodeStates: [String: NodeState]) {
        self.init(tree: tree, graph: graph, nodeStates: nodeStates, skillProgress: nil)
    }
}
