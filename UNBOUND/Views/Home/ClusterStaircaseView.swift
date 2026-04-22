import SwiftUI

// MARK: - ClusterStaircaseView
//
// True tree layout replacing the prior 2-column zig-zag staircase. Each
// cluster renders as a top-to-bottom tree: roots at top, keystone as the
// terminus, branches fanning out beneath each parent.
//
// Layout algorithm
//   1. For every cluster node, pick a "primary parent" = first in-cluster
//      prereq id in declaration order. Nodes without an in-cluster primary
//      parent are roots. Multiple roots render side-by-side at the top.
//   2. Pre-pass: compute `subtreeWidth(id)` for every node. Leaf = 120pt.
//      Parent = max(120, Σ children.subtreeWidth + 24pt gaps). Bottom-up.
//   3. Position pass: recurse from roots. Each parent centers its children
//      around its own x using their subtree widths as allocations.
//   4. Vertical spacing: 160pt default row, 200pt active row, 210pt keystone.
//   5. Horizontal ScrollView wraps the tree when it's wider than viewport.
//
// Rails
//   • Primary rails use the orthogonal step path (parent bottom-center →
//     midY → horizontal crossbar → child top-center) with blur+solid glow
//     tiered by reached/partial/locked.
//   • Secondary prereqs (anything other than the primary parent) render as
//     ghost rails — dashed, alpha 0.3, drawn first in the Canvas so primary
//     rails paint over them.
//
// Preserved
//   • Header, summary card, FULL TREE button, detail sheet handoff
//   • Active pulse, auto-scroll to active on appear
//   • Keystone sizing + crown + "N BEATS AWAY" chip
//   • MYTHIC section below the tree when keystone achieved

struct ClusterStaircaseView: View {
    let cluster: SkillCluster
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedNode: SkillNode?
    @State private var showFullTree: Bool = false
    @State private var activePulse: CGFloat = 1.0

    private var clusterNodes: [SkillNode] { graph.nodes(in: cluster) }

    private var sections: StaircaseSections { buildSections() }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        summaryCard
                            .padding(.top, 12)
                            .padding(.horizontal, 16)

                        mainTree
                            .padding(.top, 28)

                        if !sections.mythic.isEmpty {
                            sectionDivider("MYTHIC")
                                .padding(.top, 32)
                            mythicChain(nodes: sections.mythic)
                                .padding(.top, 28)
                        }
                    }
                    .padding(.bottom, 48)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            proxy.scrollTo("active", anchor: .center)
                        }
                    }
                    withAnimation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        activePulse = 1.05
                    }
                }
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .fullScreenCover(item: $selectedNode) { node in
            SkillDetailView(
                node: node,
                graph: graph,
                nodeStates: nodeStates
            )
        }
        .sheet(isPresented: $showFullTree) {
            ClusterDetailView(
                cluster: cluster,
                graph: graph,
                nodeStates: nodeStates,
                nodeProgress: nodeProgress,
                onNodeTap: { node in
                    showFullTree = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        selectedNode = node
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            Image(systemName: cluster.glyph)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(cluster.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.0)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(cluster.tagline)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button { showFullTree = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("FULL TREE")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.unbound.surface))
                .overlay(
                    Capsule().strokeBorder(Color.unbound.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.unbound.border.opacity(0.4))
            .frame(height: 1)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let unlocked = clusterNodes
            .filter { isUnlockedState(nodeStates[$0.id] ?? .locked) }
            .count
        let total = max(1, clusterNodes.count)
        let fraction = Double(unlocked) / Double(total)
        let keystoneNode = clusterNodes.first { $0.isKeystone && !$0.isMythic }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("PROGRESS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Spacer()
                Text("\(unlocked) / \(clusterNodes.count)")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            progressBar(fraction: fraction)
            if let k = keystoneNode {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.accent)
                    Text("KEYSTONE —")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(k.title)
                        .font(Font.unbound.captionS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.border, lineWidth: 1)
        )
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.unbound.surfaceElevated)
                Capsule()
                    .fill(Color.unbound.accent)
                    .frame(width: max(0, geo.size.width * CGFloat(max(0, min(1, fraction)))))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Section label divider

    private func sectionDivider(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
            Text(text)
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(Color.unbound.textTertiary)
            Rectangle()
                .fill(Color.unbound.border.opacity(0.5))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Roles

    private enum NodeRole { case achieved, active, next, keystone, tangent }

    private func sizeFor(role: NodeRole) -> CGFloat {
        switch role {
        case .active:   return 120
        case .keystone: return 140
        default:        return 95
        }
    }

    private func belowOffset(for role: NodeRole) -> CGFloat {
        switch role {
        case .active:   return 10 + 18
        case .keystone: return 10 + 32
        default:        return 8 + 14
        }
    }

    private func rowGap(for role: NodeRole) -> CGFloat {
        switch role {
        case .active:   return 185
        case .keystone: return 220
        default:        return 175
        }
    }

    // MARK: - Tree structure

    /// Assembles the primary-parent tree for this cluster's non-mythic nodes.
    /// Returns the root ids (nodes with no in-cluster prereq), a children map
    /// (parent → sorted child ids), a primary-parent map, and a role map.
    private func buildTreeStructure() -> (
        rootIds: [String],
        children: [String: [String]],
        primaryParent: [String: String],
        roles: [String: NodeRole]
    ) {
        let nodes = clusterNodes.filter { !$0.isMythic }
        let clusterIds = Set(nodes.map(\.id))

        // Primary parent: first in-cluster prereq id in declaration order.
        var primaryParent: [String: String] = [:]
        for n in nodes {
            for group in n.prereqs {
                if let first = group.nodeIds.first(where: { clusterIds.contains($0) }) {
                    primaryParent[n.id] = first
                    break
                }
            }
        }

        // Children map, sorted by id for stable layout.
        var children: [String: [String]] = [:]
        for (childId, parentId) in primaryParent {
            children[parentId, default: []].append(childId)
        }
        for k in Array(children.keys) {
            children[k]?.sort()
        }

        // Roots: any non-mythic node without a primary parent in-cluster.
        let rootIds = nodes
            .filter { primaryParent[$0.id] == nil }
            .map(\.id)
            .sorted()

        // Roles: achieved, active, next, keystone, or tangent (fallback).
        var roles: [String: NodeRole] = [:]
        for n in sections.achieved { roles[n.id] = .achieved }
        if let a = sections.active { roles[a.id] = .active }
        for n in sections.next { roles[n.id] = .next }
        if let k = sections.keystone { roles[k.id] = .keystone }
        for n in nodes where roles[n.id] == nil {
            roles[n.id] = .tangent
        }

        return (rootIds, children, primaryParent, roles)
    }

    /// Bottom-up pre-pass: each node's subtree width is either its own hex
    /// cell width (leaf) or the sum of its children's subtree widths plus
    /// gaps. Cycle-safe via a visited set — a revisit returns the leaf width.
    private func computeSubtreeWidths(
        rootIds: [String],
        children: [String: [String]]
    ) -> [String: CGFloat] {
        let hexCellWidth: CGFloat = 120
        let gap: CGFloat = 24
        var widths: [String: CGFloat] = [:]
        var visiting: Set<String> = []

        func compute(_ id: String) -> CGFloat {
            if let w = widths[id] { return w }
            if visiting.contains(id) { return hexCellWidth }
            visiting.insert(id)
            defer { visiting.remove(id) }

            let kids = children[id] ?? []
            if kids.isEmpty {
                widths[id] = hexCellWidth
                return hexCellWidth
            }
            let kidTotal = kids.map { compute($0) }.reduce(0, +)
                + gap * CGFloat(max(0, kids.count - 1))
            let w = max(hexCellWidth, kidTotal)
            widths[id] = w
            return w
        }

        for id in rootIds { _ = compute(id) }
        return widths
    }

    /// Recurse from each root, centering children around the parent's x
    /// using subtree widths. Vertical step varies per role.
    private func assignPositions(
        rootIds: [String],
        children: [String: [String]],
        subtreeWidths: [String: CGFloat],
        roles: [String: NodeRole],
        totalWidth: CGFloat,
        topY: CGFloat
    ) -> [String: CGPoint] {
        let gap: CGFloat = 24
        var positions: [String: CGPoint] = [:]
        var visiting: Set<String> = []

        func place(_ id: String, x: CGFloat, y: CGFloat) {
            if visiting.contains(id) { return }
            visiting.insert(id)
            defer { visiting.remove(id) }
            positions[id] = CGPoint(x: x, y: y)

            let kids = children[id] ?? []
            guard !kids.isEmpty else { return }
            let kidWidths = kids.map { subtreeWidths[$0] ?? 120 }
            let totalKidWidth = kidWidths.reduce(0, +) + gap * CGFloat(max(0, kids.count - 1))
            var cursor = x - totalKidWidth / 2
            for (i, kid) in kids.enumerated() {
                let kw = kidWidths[i]
                let kx = cursor + kw / 2
                let ky = y + rowGap(for: roles[kid] ?? .tangent)
                place(kid, x: kx, y: ky)
                cursor += kw + gap
            }
        }

        // Lay roots side-by-side along the top row.
        let rootWidths = rootIds.map { subtreeWidths[$0] ?? 120 }
        let totalRootsWidth = rootWidths.reduce(0, +) + gap * CGFloat(max(0, rootIds.count - 1))
        let startX = (totalWidth - totalRootsWidth) / 2
        var cursor = startX
        for (i, id) in rootIds.enumerated() {
            let w = rootWidths[i]
            let x = cursor + w / 2
            place(id, x: x, y: topY)
            cursor += w + gap
        }
        return positions
    }

    // MARK: - Main tree

    private var mainTree: some View {
        let (rootIds, children, primaryParent, roles) = buildTreeStructure()
        let subtreeWidths = computeSubtreeWidths(rootIds: rootIds, children: children)

        // Compute overall tree width from root subtree widths.
        let rootWidthsSum = rootIds.map { subtreeWidths[$0] ?? 120 }.reduce(0, +)
        let rootGapWidth = CGFloat(max(0, rootIds.count - 1)) * 24
        let contentWidth = max(340, rootWidthsSum + rootGapWidth + 32)

        let topY: CGFloat = 80
        let positions = assignPositions(
            rootIds: rootIds,
            children: children,
            subtreeWidths: subtreeWidths,
            roles: roles,
            totalWidth: contentWidth,
            topY: topY
        )

        // Compute tree height from positions + bottom padding for keystone label.
        let maxY = positions.values.map(\.y).max() ?? topY
        let treeHeight = maxY + 200

        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        return ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    drawGhostRails(
                        ctx: ctx,
                        positions: positions,
                        primaryParent: primaryParent,
                        roles: roles,
                        nodeById: nodeById
                    )
                    drawPrimaryRails(
                        ctx: ctx,
                        positions: positions,
                        primaryParent: primaryParent,
                        roles: roles
                    )
                }
                .frame(width: contentWidth, height: treeHeight)
                .allowsHitTesting(false)

                ForEach(Array(positions.keys), id: \.self) { id in
                    if let pos = positions[id],
                       let node = nodeById[id]
                    {
                        let role = roles[id] ?? .tangent
                        let size = sizeFor(role: role)

                        hexCore(node: node, role: role, size: size)
                            .position(x: pos.x, y: pos.y)
                            .modifier(ActiveAnchorModifier(isActive: role == .active))

                        hexBelow(node: node, role: role)
                            .position(x: pos.x, y: pos.y + size / 2 + belowOffset(for: role))
                    }
                }
            }
            .frame(width: contentWidth, height: treeHeight, alignment: .topLeading)
        }
        .frame(height: treeHeight)
    }

    /// Tags the active hex with the `id("active")` anchor used by
    /// auto-scroll, without forcing every hex to own an id.
    private struct ActiveAnchorModifier: ViewModifier {
        let isActive: Bool
        func body(content: Content) -> some View {
            if isActive { content.id("active") } else { content }
        }
    }

    // MARK: - Hex rendering

    @ViewBuilder
    private func hexCore(node: SkillNode, role: NodeRole, size: CGFloat) -> some View {
        let state = nodeStates[node.id] ?? .locked
        switch role {
        case .active:
            activeHex(node: node, state: state, size: size)
        case .keystone:
            keystoneHex(node: node, state: state, size: size)
        default:
            defaultHex(node: node, state: state, size: size, faded: role == .achieved)
        }
    }

    @ViewBuilder
    private func hexBelow(node: SkillNode, role: NodeRole) -> some View {
        let state = nodeStates[node.id] ?? .locked
        switch role {
        case .active:
            activeBelow(node: node)
        case .keystone:
            keystoneBelow(node: node)
        default:
            defaultBelow(node: node, state: state)
        }
    }

    private func defaultHex(
        node: SkillNode,
        state: NodeState,
        size: CGFloat,
        faded: Bool
    ) -> some View {
        ZStack {
            Hexagon()
                .fill(fillColor(state: state, faded: faded))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(
                    borderColor(node: node, state: state, faded: faded),
                    lineWidth: strokeWidth(state: state)
                )
                .frame(width: size, height: size)
            glyph(for: node, state: state, fontSize: 24)
        }
        .shadow(color: glowColor(state: state, faded: faded), radius: state == .locked ? 0 : 10)
        .opacity(faded ? 0.78 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    private func activeHex(node: SkillNode, state: NodeState, size: CGFloat) -> some View {
        ZStack {
            Hexagon()
                .fill(Color.unbound.accent.opacity(0.22))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(Color.unbound.accent, lineWidth: 2)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(Color.unbound.accent.opacity(0.7), lineWidth: 1)
                .frame(width: size + 16, height: size + 16)
            glyph(for: node, state: state, fontSize: 36)
        }
        .scaleEffect(activePulse)
        .shadow(color: Color.unbound.accent.opacity(0.55), radius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    private func keystoneHex(node: SkillNode, state: NodeState, size: CGFloat) -> some View {
        ZStack {
            Hexagon()
                .fill(keystoneFill(state: state))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(Color.unbound.accent, lineWidth: 2)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(
                    state == .locked
                        ? Color.unbound.accent.opacity(0.4)
                        : Color.unbound.accent.opacity(0.85),
                    lineWidth: 1
                )
                .frame(width: size + 18, height: size + 18)
            Image(systemName: state == .locked ? "crown" : "crown.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        }
        .shadow(
            color: state == .locked
                ? Color.unbound.accent.opacity(0.3)
                : Color.unbound.accent.opacity(0.55),
            radius: 16
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    private func defaultBelow(node: SkillNode, state: NodeState) -> some View {
        Text(node.title)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(
                state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
            )
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.unbound.bg)
            .frame(width: 110)
    }

    private func activeBelow(node: SkillNode) -> some View {
        Text(node.title)
            .font(Font.unbound.bodyMStrong)
            .foregroundStyle(Color.unbound.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.unbound.bg)
            .frame(width: 180)
    }

    private func keystoneBelow(node: SkillNode) -> some View {
        let beatsAway = sections.next.count + 1
        return VStack(spacing: 8) {
            Text(node.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.unbound.bg)
                .frame(width: 160)

            Text("\(beatsAway) \(beatsAway == 1 ? "BEAT" : "BEATS") AWAY")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.unbound.bg)
        }
        .frame(width: 160)
    }

    private func keystoneFill(state: NodeState) -> Color {
        switch state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.accent.opacity(0.16)
        case .achieved:   return Color.unbound.accent.opacity(0.22)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    // MARK: - Rails

    /// Primary rails: child ← primary parent. Orthogonal step path with
    /// full-accent glow tiered by reached/partial/locked state.
    private func drawPrimaryRails(
        ctx: GraphicsContext,
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole]
    ) {
        for (childId, parentId) in primaryParent {
            guard let childPt = positions[childId],
                  let parentPt = positions[parentId],
                  parentPt.y < childPt.y
            else { continue }

            let fromSize = sizeFor(role: roles[parentId] ?? .tangent)
            let toSize   = sizeFor(role: roles[childId]  ?? .tangent)

            drawRail(
                ctx: ctx,
                from: parentPt,
                to: childPt,
                fromSize: fromSize,
                toSize: toSize,
                fromReached: isUnlockedState(nodeStates[parentId] ?? .locked),
                toReached: isUnlockedState(nodeStates[childId] ?? .locked),
                tint: Color.unbound.accent
            )
        }
    }

    /// Ghost rails: secondary prereqs (anything other than the primary
    /// parent). Dashed, low opacity, neutral tint — rendered before primary
    /// rails so they sit behind them in the Canvas.
    private func drawGhostRails(
        ctx: GraphicsContext,
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole],
        nodeById: [String: SkillNode]
    ) {
        let ghostColor = Color.unbound.textTertiary.opacity(0.3)

        for (childId, childPt) in positions {
            guard let childNode = nodeById[childId] else { continue }
            let allPrereqIds = Set(childNode.prereqs.flatMap { $0.nodeIds })
            let primary = primaryParent[childId]
            let secondary = allPrereqIds
                .filter { $0 != primary }
                .filter { positions[$0] != nil }

            let toSize = sizeFor(role: roles[childId] ?? .tangent)

            for pid in secondary {
                guard let parentPt = positions[pid],
                      parentPt.y < childPt.y
                else { continue }
                let fromSize = sizeFor(role: roles[pid] ?? .tangent)
                let start = CGPoint(x: parentPt.x, y: parentPt.y + fromSize / 2)
                let end   = CGPoint(x: childPt.x,  y: childPt.y  - toSize / 2)

                var path = Path()
                let tolerance: CGFloat = 1.0
                if abs(end.x - start.x) <= tolerance {
                    path.move(to: start)
                    path.addLine(to: end)
                } else {
                    let biased = start.y + (end.y - start.y) * 0.7
                    let midY = min(biased, end.y - 2)
                    path.move(to: start)
                    path.addLine(to: CGPoint(x: start.x, y: midY))
                    path.addLine(to: CGPoint(x: end.x, y: midY))
                    path.addLine(to: end)
                }
                ctx.stroke(
                    path,
                    with: .color(ghostColor),
                    style: StrokeStyle(
                        lineWidth: 1.2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [4, 6]
                    )
                )
            }
        }
    }

    /// Orthogonal "step" rail between two hexes. Anchors at the parent's
    /// bottom-center and the child's top-center so every rail enters and
    /// exits straight down.
    ///
    /// Path shape:
    ///   • Same column (|dx| ≤ tolerance): single vertical line start → end.
    ///   • Different columns: down-stub → horizontal crossbar at midY →
    ///     down-stub. Two bends, each rounded with a small arc.
    private func drawRail(
        ctx: GraphicsContext,
        from parent: CGPoint,
        to child: CGPoint,
        fromSize: CGFloat,
        toSize: CGFloat,
        fromReached: Bool,
        toReached: Bool,
        tint: Color
    ) {
        let start = CGPoint(x: parent.x, y: parent.y + fromSize / 2)
        let end   = CGPoint(x: child.x,  y: child.y  - toSize / 2)

        var path = Path()
        let tolerance: CGFloat = 1.0

        if abs(end.x - start.x) <= tolerance {
            path.move(to: start)
            path.addLine(to: end)
        } else {
            // Bias the crossbar toward the child so it sits in the lower
            // half of the rail, clear of the label rendered beneath the
            // parent hex.
            let biased = start.y + (end.y - start.y) * 0.7
            let midY = min(biased, end.y - 2)
            let cornerRadius: CGFloat = 8

            let vStub1 = midY - start.y
            let vStub2 = end.y - midY
            let hSpan  = abs(end.x - start.x)
            let r = max(0, min(cornerRadius, min(vStub1, vStub2, hSpan / 2)))

            let goingRight = end.x > start.x
            let bend1 = CGPoint(x: start.x, y: midY)
            let bend2 = CGPoint(x: end.x,   y: midY)

            path.move(to: start)
            if r > 0 {
                path.addLine(to: CGPoint(x: start.x, y: midY - r))
                let afterBend1X = start.x + (goingRight ? r : -r)
                path.addQuadCurve(
                    to: CGPoint(x: afterBend1X, y: midY),
                    control: bend1
                )
                let beforeBend2X = end.x + (goingRight ? -r : r)
                path.addLine(to: CGPoint(x: beforeBend2X, y: midY))
                path.addQuadCurve(
                    to: CGPoint(x: end.x, y: midY + r),
                    control: bend2
                )
                path.addLine(to: end)
            } else {
                path.addLine(to: bend1)
                path.addLine(to: bend2)
                path.addLine(to: end)
            }
        }

        strokeRail(ctx: ctx, path: path, fromReached: fromReached, toReached: toReached, tint: tint)
    }

    private func strokeRail(
        ctx: GraphicsContext,
        path: Path,
        fromReached: Bool,
        toReached: Bool,
        tint: Color
    ) {
        if fromReached && toReached {
            var blurCtx = ctx
            blurCtx.addFilter(.blur(radius: 4))
            blurCtx.stroke(
                path,
                with: .color(tint.opacity(0.6)),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            ctx.stroke(
                path,
                with: .color(tint),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
        } else if fromReached {
            var blurCtx = ctx
            blurCtx.addFilter(.blur(radius: 3))
            blurCtx.stroke(
                path,
                with: .color(tint.opacity(0.45)),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            ctx.stroke(
                path,
                with: .color(tint.opacity(0.85)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        } else {
            var blurCtx = ctx
            blurCtx.addFilter(.blur(radius: 2.5))
            blurCtx.stroke(
                path,
                with: .color(tint.opacity(0.25)),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            ctx.stroke(
                path,
                with: .color(tint.opacity(0.55)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
        }
    }

    // MARK: - Mythic chain

    private func mythicChain(nodes: [SkillNode]) -> some View {
        struct MythicSlot: Identifiable {
            let id: String
            let node: SkillNode
            let rowIndex: Int
            let left: Bool
        }
        let slots: [MythicSlot] = nodes
            .sorted { $0.id < $1.id }
            .enumerated()
            .map { idx, n in
                MythicSlot(id: n.id, node: n, rowIndex: idx, left: idx % 2 == 0)
            }
        let rowCount = slots.count
        let verticalGap: CGFloat = 110
        let size: CGFloat = 90
        let totalHeight = CGFloat(max(0, rowCount - 1)) * verticalGap + size + 44

        return GeometryReader { geo in
            let fullWidth = geo.size.width
            let leftX = fullWidth * 0.28
            let rightX = fullWidth * 0.72
            let positions: [String: CGPoint] = Dictionary(
                uniqueKeysWithValues: slots.map { s in
                    (s.id, CGPoint(
                        x: s.left ? leftX : rightX,
                        y: size / 2 + CGFloat(s.rowIndex) * verticalGap
                    ))
                }
            )
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for i in 0..<max(0, slots.count - 1) {
                        let a = slots[i]
                        let b = slots[i + 1]
                        guard let pa = positions[a.id], let pb = positions[b.id] else { continue }
                        drawRail(
                            ctx: ctx,
                            from: pa,
                            to: pb,
                            fromSize: size,
                            toSize: size,
                            fromReached: isUnlockedState(nodeStates[a.id] ?? .locked),
                            toReached: isUnlockedState(nodeStates[b.id] ?? .locked),
                            tint: Color.unbound.impact
                        )
                    }
                }
                .frame(width: fullWidth, height: totalHeight)
                .allowsHitTesting(false)

                ForEach(slots) { slot in
                    if let p = positions[slot.id] {
                        mythicHex(node: slot.node, size: size)
                            .position(x: p.x, y: p.y)
                    }
                }
            }
            .frame(width: fullWidth, height: totalHeight, alignment: .topLeading)
        }
        .frame(height: totalHeight)
        .padding(.horizontal, 16)
    }

    private func mythicHex(node: SkillNode, size: CGFloat) -> some View {
        let state = nodeStates[node.id] ?? .locked
        return VStack(spacing: 6) {
            ZStack {
                Hexagon()
                    .fill(fillColor(state: state, faded: false))
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(Color.unbound.impact, lineWidth: 1.5)
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(Color.unbound.impact, lineWidth: 1.5)
                    .frame(width: size + 14, height: size + 14)
                    .opacity(state == .locked ? 0.45 : 0.9)
                glyph(for: node, state: state, fontSize: 24)
            }
            .shadow(color: Color.unbound.impact.opacity(0.5), radius: state == .locked ? 0 : 10)

            Text(node.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(
                    state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: max(108, size + 14))
            Text("MYTHIC")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color.unbound.impact)
        }
        .frame(width: max(108, size + 14))
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    // MARK: - Hex styling helpers

    private func fillColor(state: NodeState, faded: Bool) -> Color {
        switch state {
        case .locked:
            return Color.unbound.surface
        case .attempting:
            return Color.unbound.accent.opacity(0.14)
        case .achieved:
            return Color.unbound.accent.opacity(faded ? 0.1 : 0.18)
        case .mastered:
            return Color.unbound.impact.opacity(faded ? 0.14 : 0.22)
        }
    }

    private func borderColor(node: SkillNode, state: NodeState, faded: Bool) -> Color {
        if node.isMythic && state == .locked { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .locked:
            return faded ? Color.unbound.border.opacity(0.7) : Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent.opacity(faded ? 0.7 : 1.0)
        case .mastered:   return Color.unbound.impact
        }
    }

    private func strokeWidth(state: NodeState) -> CGFloat {
        switch state {
        case .locked:     return 1
        case .attempting: return 1.5
        case .achieved:   return 1.5
        case .mastered:   return 2
        }
    }

    private func glowColor(state: NodeState, faded: Bool) -> Color {
        if state == .locked { return .clear }
        switch state {
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(faded ? 0.25 : 0.45)
        case .mastered:   return Color.unbound.impact.opacity(0.55)
        case .locked:     return .clear
        }
    }

    @ViewBuilder
    private func glyph(for node: SkillNode, state: NodeState, fontSize: CGFloat) -> some View {
        switch state {
        case .locked:
            Image(systemName: node.isKeystone ? "crown" : "lock.fill")
                .font(.system(size: fontSize - 3, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            Image(systemName: node.glyph)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        case .achieved:
            Image(systemName: node.isKeystone ? "crown.fill" : "checkmark")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .mastered:
            Image(systemName: "crown.fill")
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(Color.unbound.impact)
        }
    }

    // MARK: - Section algorithm (unchanged — still used to identify role)

    private struct StaircaseSections {
        var achieved: [SkillNode]
        var active: SkillNode?
        var next: [SkillNode]
        var keystone: SkillNode?
        var keystoneIsActive: Bool
        var mythic: [SkillNode]
    }

    private func buildSections() -> StaircaseSections {
        let nodes = clusterNodes
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let tiers = computeEffectiveTiers(nodes: nodes)

        func state(_ n: SkillNode) -> NodeState { nodeStates[n.id] ?? .locked }

        let keystone = nodes.first { $0.isKeystone && !$0.isMythic }
        let mythicNodes = nodes.filter { $0.isMythic }
        let keystoneUnlocked = keystone.map { isUnlockedState(state($0)) } ?? false

        let achievedAll = nodes
            .filter { !$0.isMythic && $0.id != keystone?.id }
            .filter { isUnlockedState(state($0)) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        let achieved = Array(achievedAll.suffix(2))

        let attempting = nodes
            .filter { state($0) == .attempting }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        var activeNode: SkillNode? = attempting.first
        if activeNode == nil {
            let unlockables = nodes
                .filter { state($0) == .locked }
                .filter { $0.prereqsSatisfied(given: nodeStates) }
                .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
            activeNode = unlockables.first
        }
        if activeNode == nil { activeNode = keystone }

        let keystoneIsActive = (activeNode?.id == keystone?.id) && keystone != nil

        let ancestorIds: Set<String> = keystone
            .map { keystoneAncestors(keystone: $0, nodeById: nodeById) }
            ?? []

        let nextCandidates = nodes
            .filter { !$0.isMythic }
            .filter { $0.id != keystone?.id }
            .filter { $0.id != activeNode?.id }
            .filter { !isUnlockedState(state($0)) }
            .filter { node in
                if ancestorIds.contains(node.id) { return true }
                if node.prereqsSatisfied(given: nodeStates) { return true }
                if state(node) == .attempting { return true }
                return false
            }
            .sorted {
                let ta = tiers[$0.id] ?? $0.tier
                let tb = tiers[$1.id] ?? $1.tier
                if ta != tb { return ta < tb }
                return $0.id < $1.id
            }
        let next = Array(nextCandidates.prefix(5))

        let mythic = keystoneUnlocked ? mythicNodes : []

        return StaircaseSections(
            achieved: achieved,
            active: activeNode,
            next: next,
            keystone: keystone,
            keystoneIsActive: keystoneIsActive,
            mythic: mythic
        )
    }

    private func keystoneAncestors(
        keystone: SkillNode,
        nodeById: [String: SkillNode]
    ) -> Set<String> {
        var ancestors: Set<String> = [keystone.id]
        var queue: [String] = [keystone.id]
        while let currentId = queue.popLast() {
            guard let node = nodeById[currentId] else { continue }
            let prereqIds = node.prereqs.flatMap { $0.nodeIds }
            for pid in prereqIds where nodeById[pid] != nil && !ancestors.contains(pid) {
                ancestors.insert(pid)
                queue.append(pid)
            }
        }
        return ancestors
    }

    // MARK: - Effective tier

    private func computeEffectiveTiers(nodes: [SkillNode]) -> [String: Int] {
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var cache: [String: Int] = [:]
        var inProgress: Set<String> = []

        func depth(_ id: String) -> Int {
            if let cached = cache[id] { return cached }
            guard let node = nodeById[id] else { return 1 }
            if inProgress.contains(id) { return node.tier }
            inProgress.insert(id)
            defer { inProgress.remove(id) }

            let within = node.prereqs.flatMap { $0.nodeIds }
                .filter { nodeById[$0] != nil }
            let d: Int
            if within.isEmpty {
                d = 1
            } else {
                let maxPrereqDepth = within.map { depth($0) }.max() ?? 0
                d = maxPrereqDepth + 1
            }
            cache[id] = d
            return d
        }

        for node in nodes { _ = depth(node.id) }
        return cache
    }

    // MARK: - Helpers

    private func isUnlockedState(_ s: NodeState) -> Bool {
        s == .achieved || s == .mastered
    }
}
