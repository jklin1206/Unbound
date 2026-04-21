import SwiftUI

// MARK: - SkillTreeView
//
// Branching tree visualizer. Nodes positioned on a grid (row, column with
// -1 / 0 / +1 columns). Connecting lines drawn between prerequisites and
// their downstream nodes. Each node rendered as a hexagon matching the
// RankBadge language.
//
// Node states visualized:
//   - locked:     bone-white dim hexagon, small lock glyph inside
//   - attempting: violet outline, title visible, soft violet pulse
//   - achieved:   violet filled hexagon, checkmark glyph
//   - mastered:   impact-violet filled + outer glow + crown glyph
//
// Tap a node to see its requirement in a floating detail card.

struct SkillTreeView: View {
    let tree: SkillTree
    /// State per node id — caller provides (V1 hardcoded preview, V2 real).
    let nodeStates: [String: NodeState]
    /// Optional tap callback — caller opens a sheet or inline detail.
    var onNodeTap: ((SkillNode) -> Void)? = nil

    private let rowHeight: CGFloat = 135
    private let columnSpacing: CGFloat = 130
    private let nodeSize: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let height = CGFloat(tree.rowCount) * rowHeight + 40

            ZStack {
                // Layer 1 — connecting lines (prereq → downstream node)
                Canvas { context, _ in
                    for node in tree.nodes {
                        let allPrereqIds = node.prereqs.flatMap { $0.nodeIds }
                        for prereqId in allPrereqIds {
                            guard let prereq = tree.nodes.first(where: { $0.id == prereqId }) else { continue }
                            let from = pointFor(prereq, centerX: centerX, height: height)
                            let to = pointFor(node, centerX: centerX, height: height)
                            var path = Path()
                            path.move(to: from)
                            path.addLine(to: to)

                            let isReachable = nodeStates[node.id] != .locked ||
                                nodeStates[prereqId] == .achieved ||
                                nodeStates[prereqId] == .mastered
                            let color: Color = isReachable
                                ? Color.unbound.accent.opacity(0.6)
                                : Color.unbound.border
                            context.stroke(
                                path,
                                with: .color(color),
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    dash: isReachable ? [] : [3, 5]
                                )
                            )
                        }
                    }
                }
                .frame(width: geo.size.width, height: height)

                // Layer 2 — nodes
                ForEach(tree.nodes) { node in
                    let state = nodeStates[node.id] ?? .locked
                    let p = pointFor(node, centerX: centerX, height: height)
                    SkillNodeHexagon(node: node, state: state)
                        .position(p)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            onNodeTap?(node)
                        }
                }
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: CGFloat(tree.rowCount) * rowHeight + 40)
    }

    /// Node center point in the ZStack coordinate space. Tree flows
    /// TOP DOWN: row 0 (starting node / easiest) renders at the top of
    /// the view, highest row (BOSS) sits at the bottom — natural reading
    /// order when the user scrolls down through what's coming.
    private func pointFor(_ node: SkillNode, centerX: CGFloat, height: CGFloat) -> CGPoint {
        let x = centerX + CGFloat(node.position.column) * columnSpacing
        let y = CGFloat(node.position.row) * rowHeight + rowHeight / 2 + 20
        return CGPoint(x: x, y: y)
    }
}

// MARK: - SkillNodeHexagon

struct SkillNodeHexagon: View {
    let node: SkillNode
    let state: NodeState

    private var nodeSize: CGFloat {
        node.isKeystone ? 100 : 76
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Base
                Hexagon()
                    .fill(fillColor)
                    .frame(width: nodeSize, height: nodeSize)

                // Thin material overlay for depth
                Hexagon()
                    .fill(.thinMaterial)
                    .opacity(0.08)
                    .frame(width: nodeSize, height: nodeSize)

                // Border
                Hexagon()
                    .strokeBorder(borderColor, lineWidth: borderWidth)
                    .frame(width: nodeSize, height: nodeSize)

                // Outer glow for achieved / mastered / boss-active
                if state == .mastered || (node.isKeystone && state != .locked) {
                    Hexagon()
                        .strokeBorder(Color.unbound.impact, lineWidth: 1)
                        .frame(width: nodeSize + 10, height: nodeSize + 10)
                        .shadow(color: Color.unbound.impact.opacity(0.5), radius: 10)
                }

                // Center glyph
                glyph
            }
            .shadow(
                color: glowColor,
                radius: state == .locked ? 0 : 12,
                x: 0,
                y: 0
            )

            // Label
            VStack(spacing: 2) {
                Text(node.title)
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(labelColor)
                    .tracking(0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if node.isKeystone {
                    Text("BOSS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.impact)
                }
            }
            .frame(width: 100)
        }
    }

    // MARK: Styling per state

    private var fillColor: Color {
        switch state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.surface
        case .achieved:   return Color.unbound.accent.opacity(0.18)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    private var borderColor: Color {
        switch state {
        case .locked:     return Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent
        case .mastered:   return Color.unbound.impact
        }
    }

    private var borderWidth: CGFloat {
        switch state {
        case .locked:     return 1
        case .attempting: return 1.5
        case .achieved:   return 1.5
        case .mastered:   return 2
        }
    }

    private var glowColor: Color {
        switch state {
        case .locked:     return .clear
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(0.55)
        case .mastered:   return Color.unbound.impact.opacity(0.6)
        }
    }

    private var labelColor: Color {
        state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
    }

    // MARK: Glyph

    @ViewBuilder
    private var glyph: some View {
        switch state {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: node.isKeystone ? 26 : 20, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            Image(systemName: iconForType)
                .font(.system(size: node.isKeystone ? 30 : 24, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        case .achieved:
            Image(systemName: "checkmark")
                .font(.system(size: node.isKeystone ? 32 : 26, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .mastered:
            Image(systemName: "crown.fill")
                .font(.system(size: node.isKeystone ? 32 : 26, weight: .semibold))
                .foregroundStyle(Color.unbound.impact)
        }
    }

    private var iconForType: String {
        switch node.type {
        case .strength: return "dumbbell.fill"
        case .skill:    return "figure.strengthtraining.functional"
        case .hold:     return "figure.mind.and.body"
        }
    }
}

#Preview("Skill tree") {
    ScrollView {
        VStack(spacing: 20) {
            SkillTreeView(
                tree: .unitTree,
                nodeStates: [
                    "hl.bw-back-squat": .attempting,
                    "hl.bw-deadlift": .attempting
                ]
            )
            .padding(20)
        }
    }
    .background(Color.unbound.bg)
}
