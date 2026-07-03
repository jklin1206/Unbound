import SwiftUI

// MARK: - ClusterCardView
//
// Rich, full-width card for one display tree on the Skill Map landing
// screen. Shows:
//   • Header: glyph + display name (uppercased, tracked) + tagline
//   • Progress: proven / total + thin bar
//   • NOW chip: first reachable unproven node
//   • Farthest proof: completed node title + rank chip
//   • Locked state: 40% opacity, dashed border, REQUIRES caption
//
// Tap handling is owned by the parent view. Display trees drill directly
// into their staircase.

struct ClusterCardView: View {
    let tree: SkillDisplayTree
    let graph: SkillGraph
    let nodeStates: [String: NodeState]

    private var total: Int { tree.totalCount(in: graph) }
    private var proven: Int { tree.provenCount(in: graph, states: nodeStates) }
    private var progressPct: Double {
        total == 0 ? 0 : Double(proven) / Double(total)
    }
    private var activeNode: SkillNode? {
        tree.activeNode(in: graph, states: nodeStates)
    }
    /// The skill the user is actively training in this tree (Program Focus), if any.
    private var trainingNode: SkillNode? {
        tree.trainingNode(in: graph, focusIds: SkillProgressService.shared.programFocusIds)
    }
    /// The artwork shown in the card's thumbnail. Pinned to the tree's fixed
    /// signature skill so the image is stable and always reads as the tree's
    /// headline movement (pull-up, push-up, pistol squat, …). Falls back to
    /// progress-derived nodes only if the signature node is somehow absent.
    private var representativeNode: SkillNode? {
        graph.node(id: tree.signatureSkillId)
            ?? tree.farthestProvenNode(in: graph, states: nodeStates)
            ?? trainingNode
            ?? activeNode
            ?? tree.previewKeystone(in: graph, states: nodeStates)
    }
    private var representativeAssetName: String? {
        representativeNode.flatMap { SkillTraditionalVisualResolver.assetName(for: $0) }
    }
    var body: some View {
        unlockedBody
    }

    // MARK: - Unlocked body

    private var unlockedBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            divider
            progressBlock
            targetRow
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

    // MARK: - Pieces

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            skillArtworkMark
                .frame(width: 58, height: 58)
                .fixedSize()

            VStack(alignment: .leading, spacing: 5) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        treeTitle
                        chapterSubtitleLabel
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        treeTitle
                        chapterSubtitleLabel
                    }
                }

                Text(tree.tagline)
                    .font(Font.unbound.captionS)
                    .tracking(0.4)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
    }

    private var treeTitle: some View {
        Text(tree.displayName.uppercased())
            .font(Font.unbound.captionS.weight(.heavy))
            .tracking(2.2)
            .foregroundStyle(Color.unbound.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .truncationMode(.tail)
            .layoutPriority(1)
    }

    private var chapterSubtitleLabel: some View {
        Text(tree.chapterSubtitle)
            .font(Font.unbound.captionS.weight(.regular).italic())
            .tracking(0.2)
            .foregroundStyle(Color.unbound.accent.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .truncationMode(.tail)
    }

    private var skillArtworkMark: some View {
        let assetName = representativeAssetName

        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated)

            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
                    .shadow(color: Color.black.opacity(0.34), radius: 5, x: 0, y: 3)
            } else {
                SkillTreeIconMark(tree: tree)
                    .padding(7)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    Color.unbound.accent.opacity(0.30),
                    lineWidth: 1
                )
        )
        .accessibilityHidden(true)
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
                Text("\(proven) / \(total)")
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

    // MARK: - Training row (the skill you are training in this tree)

    @ViewBuilder
    private var targetRow: some View {
        if let target = trainingNode {
            targetSetRow(target: target)
        } else if activeNode != nil {
            noTargetRow
        }
    }

    private func targetSetRow(target: SkillNode) -> some View {
        let userId = AuthService.shared.currentUserId ?? "anonymous"
        let earned = UserSkillTierStore.shared.load(userId: userId).perSkill[target.id] ?? .initiate
        return HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("TRAINING")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(target.title)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)
            Spacer(minLength: 6)
            Image(earned.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .shadow(color: earned.rewardTint.opacity(0.35), radius: 6)
                .accessibilityLabel("\(earned.displayName) rank")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.unbound.surfaceElevated))
    }

    private var noTargetRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
            Text("Tap a skill to start training it")
                .font(Font.unbound.bodyS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.unbound.surfaceElevated.opacity(0.6)))
    }

}

private struct SkillTreeIconMark: View {
    let tree: SkillDisplayTree

    private var primary: Color { Color.unbound.textPrimary }
    private var accent: Color { Color.unbound.accent }

    var body: some View {
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
        .accessibilityHidden(true)
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
