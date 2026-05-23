import SwiftUI
import UIKit

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
    @State private var treeLayout: ComputedTreeLayout?
    @StateObject private var skinService = SkinService.shared

    private let minZoom: CGFloat = 0.45
    private let maxZoom: CGFloat = 1.5

    private var clusterNodes: [SkillNode] { graph.nodes(in: cluster) }

    private var sections: StaircaseSections { buildSections() }

    /// Chapter subtitle surfaced in the header. Derived from the parent
    /// display tree so umbrella sub-clusters (Handstand / HSPU / One-Arm)
    /// inherit "The Inversion". Falls back to the cluster tagline if the
    /// cluster is somehow not mapped to a display tree.
    private var headerSubtitle: String {
        SkillDisplayTree.containing(cluster)?.chapterSubtitle ?? cluster.tagline
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    summaryCard
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    if let layout = treeLayout {
                        mainTree(layout: layout)
                            .padding(.top, 28)
                    } else {
                        Color.unbound.bg
                            .frame(height: 500)
                            .padding(.top, 28)
                    }

                    if !sections.mythic.isEmpty {
                        sectionDivider("MYTHIC")
                            .padding(.top, 32)
                        mythicChain(nodes: sections.mythic)
                            .padding(.top, 28)
                    }
                }
                .padding(.bottom, 48)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        activePulse = 1.05
                    }
                    if treeLayout == nil {
                        treeLayout = buildLayout()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .skinChanged)) { _ in
                    treeLayout = buildLayout()
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
                Text(headerSubtitle)
                    .font(Font.unbound.captionS.italic())
                    .foregroundStyle(skinService.currentSkin.primaryColor.opacity(0.85))
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
                        .foregroundStyle(skinService.currentSkin.primaryColor)
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
                    .fill(skinService.currentSkin.nodeGradient)
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

    fileprivate enum NodeRole { case achieved, active, next, keystone, tangent }

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
        case .active:   return 245
        case .keystone: return 290
        default:        return 235
        }
    }

    // MARK: - Tree structure

    /// Assembles the primary-parent tree for every node in this cluster —
    /// mythics included. Mythics are real terminals (Strict Muscle-Up,
    /// One-Arm Pull-Up, etc.) that chain naturally off non-mythic parents,
    /// so they belong in the main tree, not a separate section.
    /// Returns the root ids (nodes with no in-cluster prereq), a children map
    /// (parent → sorted child ids), a primary-parent map, and a role map.
    private func buildTreeStructure() -> (
        rootIds: [String],
        children: [String: [String]],
        primaryParent: [String: String],
        roles: [String: NodeRole]
    ) {
        let nodes = clusterNodes
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

    /// Bottom-up pre-pass: each node's subtree width is its own hex cell
    /// width (leaf), the sum of regular children's subtree widths centered
    /// below it, plus the sum of any parallel children's subtree widths
    /// extending to the right at the same y. Cycle-safe via a visited set.
    private func computeSubtreeWidths(
        rootIds: [String],
        children: [String: [String]]
    ) -> [String: CGFloat] {
        let hexCellWidth: CGFloat = 160
        let gap: CGFloat = 48
        var widths: [String: CGFloat] = [:]
        var visiting: Set<String> = []
        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        func isParallel(_ id: String) -> Bool {
            nodeById[id]?.isParallelToParent ?? false
        }

        func compute(_ id: String) -> CGFloat {
            if let w = widths[id] { return w }
            if visiting.contains(id) { return hexCellWidth }
            visiting.insert(id)
            defer { visiting.remove(id) }

            let kids = children[id] ?? []
            let regularKids = kids.filter { !isParallel($0) }
            let parallelKids = kids.filter { isParallel($0) }

            // Regular subtree below: standard child packing centered under self.
            let regularBelowWidth: CGFloat
            if regularKids.isEmpty {
                regularBelowWidth = hexCellWidth
            } else {
                let sum = regularKids.map { compute($0) }.reduce(0, +)
                    + gap * CGFloat(max(0, regularKids.count - 1))
                regularBelowWidth = max(hexCellWidth, sum)
            }

            // Parallel siblings extend to the right of the parent's own
            // bounding box; each parallel kid contributes its own subtree
            // width plus a leading gap separating it from what's left.
            let parallelSideWidth = parallelKids
                .map { compute($0) }
                .reduce(0, +)
                + gap * CGFloat(parallelKids.count)

            let w = regularBelowWidth + parallelSideWidth
            widths[id] = w
            return w
        }

        for id in rootIds { _ = compute(id) }
        return widths
    }

    /// Recurse from each root, centering regular children around the
    /// parent's x and placing parallel children at the same y to the
    /// right. Vertical step varies per role.
    private func assignPositions(
        rootIds: [String],
        children: [String: [String]],
        subtreeWidths: [String: CGFloat],
        roles: [String: NodeRole],
        totalWidth: CGFloat,
        topY: CGFloat
    ) -> [String: CGPoint] {
        let gap: CGFloat = 48
        let hexCellWidth: CGFloat = 160
        var positions: [String: CGPoint] = [:]
        var visiting: Set<String> = []
        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        func isParallel(_ id: String) -> Bool {
            nodeById[id]?.isParallelToParent ?? false
        }

        // Place a node into a horizontal allocation slot starting at
        // `slotLeft` with width `subtreeWidths[id]`. The node's own x is
        // anchored to the centerline of its regular-below subtree (i.e.
        // its left "block"). Parallel kids consume the right-hand
        // portion of the slot at the parent's y.
        func place(_ id: String, slotLeft: CGFloat, y: CGFloat) {
            if visiting.contains(id) { return }
            visiting.insert(id)
            defer { visiting.remove(id) }

            let kids = children[id] ?? []
            let regularKids = kids.filter { !isParallel($0) }
            let parallelKids = kids.filter { isParallel($0) }

            // Reconstruct the regular-below width so we can position self
            // over its center. Mirrors logic in computeSubtreeWidths.
            let regularBelowWidth: CGFloat = {
                if regularKids.isEmpty { return hexCellWidth }
                let sum = regularKids.map { subtreeWidths[$0] ?? hexCellWidth }.reduce(0, +)
                    + gap * CGFloat(max(0, regularKids.count - 1))
                return max(hexCellWidth, sum)
            }()

            let selfX = slotLeft + regularBelowWidth / 2
            positions[id] = CGPoint(x: selfX, y: y)

            // Regular kids: distribute centered around self at y + rowGap.
            if !regularKids.isEmpty {
                var cursor = slotLeft
                if regularKids.count == 1 {
                    // Center single child directly under parent.
                    let kw = subtreeWidths[regularKids[0]] ?? hexCellWidth
                    let kSlotLeft = selfX - kw / 2
                    let ky = y + rowGap(for: roles[regularKids[0]] ?? .tangent)
                    place(regularKids[0], slotLeft: kSlotLeft, y: ky)
                } else {
                    // Pack regular kids' slots end-to-end across the
                    // regular-below band, which already starts at slotLeft
                    // and is regularBelowWidth wide (centered on selfX).
                    let bandLeft = selfX - regularBelowWidth / 2
                    cursor = bandLeft
                    for kid in regularKids {
                        let kw = subtreeWidths[kid] ?? hexCellWidth
                        let ky = y + rowGap(for: roles[kid] ?? .tangent)
                        place(kid, slotLeft: cursor, y: ky)
                        cursor += kw + gap
                    }
                }
            }

            // Parallel kids: same y, march to the right of self's regular
            // block. Each one starts after a gap.
            if !parallelKids.isEmpty {
                var cursor = slotLeft + regularBelowWidth + gap
                for kid in parallelKids {
                    let kw = subtreeWidths[kid] ?? hexCellWidth
                    place(kid, slotLeft: cursor, y: y)
                    cursor += kw + gap
                }
            }
        }

        // Lay roots side-by-side along the top row.
        let rootWidths = rootIds.map { subtreeWidths[$0] ?? hexCellWidth }
        let totalRootsWidth = rootWidths.reduce(0, +) + gap * CGFloat(max(0, rootIds.count - 1))
        let startX = (totalWidth - totalRootsWidth) / 2
        var cursor = startX
        for (i, id) in rootIds.enumerated() {
            let w = rootWidths[i]
            place(id, slotLeft: cursor, y: topY)
            cursor += w + gap
            _ = i
        }
        return positions
    }

    // MARK: - Main tree

    /// Pre-compute everything needed to render the tree, including the rails
    /// as a UIImage. Called once on .onAppear, cached in `treeLayout` state.
    /// Rails are rendered with UIGraphicsImageRenderer (which always renders
    /// the FULL content size) rather than SwiftUI Canvas (which renders
    /// lazily per visible rect inside UIScrollView — causing rails connecting
    /// to off-viewport nodes to vanish when the user zooms out).
    private func buildLayout() -> ComputedTreeLayout {
        let (rootIds, children, primaryParent, roles) = buildTreeStructure()
        let subtreeWidths = computeSubtreeWidths(rootIds: rootIds, children: children)

        let rootWidthsSum = rootIds.map { subtreeWidths[$0] ?? 120 }.reduce(0, +)
        let rootGapWidth = CGFloat(max(0, rootIds.count - 1)) * 48
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

        let maxY = positions.values.map(\.y).max() ?? topY
        let treeHeight = maxY + 200

        let nodeById: [String: SkillNode] = Dictionary(
            uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) }
        )

        let rankBands = computeAllRankBands(
            positions: positions,
            nodeById: nodeById,
            topY: topY,
            bottomY: maxY
        )

        let bandRegions = computeRankBandRegions(
            positions: positions,
            nodeById: nodeById,
            topY: 0,
            bottomY: treeHeight
        )

        let activeId = roles.first(where: { $0.value == .active })?.key
        let activePos = activeId.flatMap { positions[$0] }
        let activeZoom = min(maxZoom, max(minZoom, 1.0))

        let viewportH = mapViewportHeight(contentWidth: contentWidth, for: treeHeight)
        let initialOffset: CGPoint? = activePos.map { pt in
            let viewportW = UIScreen.main.bounds.width
            let scaledX = pt.x * activeZoom - viewportW / 2
            let scaledY = pt.y * activeZoom - viewportH / 2
            let maxOffX = max(0, contentWidth * activeZoom - viewportW)
            let maxOffY = max(0, treeHeight * activeZoom - viewportH)
            return CGPoint(
                x: min(max(0, scaledX), maxOffX),
                y: min(max(0, scaledY), maxOffY)
            )
        }

        let railsImage = renderRailsImage(
            positions: positions,
            primaryParent: primaryParent,
            roles: roles,
            nodeById: nodeById,
            contentWidth: contentWidth,
            treeHeight: treeHeight
        )

        return ComputedTreeLayout(
            contentWidth: contentWidth,
            treeHeight: treeHeight,
            positions: positions,
            primaryParent: primaryParent,
            roles: roles,
            nodeById: nodeById,
            rankBands: rankBands,
            bandRegions: bandRegions,
            railsImage: railsImage,
            initialOffset: initialOffset,
            activeZoom: activeZoom,
            viewportHeight: viewportH
        )
    }

    private func mainTree(layout: ComputedTreeLayout) -> some View {
        ZoomableTreeScrollView(
            contentSize: CGSize(width: layout.contentWidth, height: layout.treeHeight),
            minZoom: minZoom,
            maxZoom: maxZoom,
            initialZoom: layout.activeZoom,
            initialOffset: layout.initialOffset
        ) {
            ZStack(alignment: .topLeading) {
                cosmeticTreeBackground(width: layout.contentWidth, height: layout.treeHeight)

                // Rank-band background stripes — radar-faint tint per tier.
                ForEach(layout.bandRegions.bands, id: \.rank) { region in
                    Rectangle()
                        .fill(skinService.currentSkin.bandTint(for: region.rank))
                        .frame(
                            width: layout.contentWidth,
                            height: max(0, region.bottom - region.top)
                        )
                        .position(
                            x: layout.contentWidth / 2,
                            y: (region.top + region.bottom) / 2
                        )
                }

                // Dotted horizontal dividers between adjacent rank groups.
                ForEach(Array(layout.bandRegions.dividers.enumerated()), id: \.offset) { _, y in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: layout.contentWidth, y: y))
                    }
                    .stroke(
                        Color.unbound.border.opacity(0.5),
                        style: StrokeStyle(lineWidth: 0.8, dash: [4, 6])
                    )
                    .frame(width: layout.contentWidth, height: layout.treeHeight)
                }

                // Rails — pre-rendered UIImage at full content size. Avoids
                // SwiftUI Canvas lazy-rendering bug inside UIScrollView where
                // off-viewport rails vanish when zoomed out.
                Image(uiImage: layout.railsImage)
                    .frame(width: layout.contentWidth, height: layout.treeHeight)
                    .allowsHitTesting(false)

                // Interactive hex nodes — kept OUTSIDE any drawingGroup so
                // tap gestures still fire.
                ForEach(Array(layout.positions.keys), id: \.self) { id in
                    if let pos = layout.positions[id],
                       let node = layout.nodeById[id]
                    {
                        let role = layout.roles[id] ?? .tangent
                        let size = sizeFor(role: role)

                        hexCore(node: node, role: role, size: size)
                            .position(x: pos.x, y: pos.y)
                            .modifier(ActiveAnchorModifier(isActive: role == .active))

                        hexBelow(node: node, role: role)
                            .position(x: pos.x, y: pos.y + size / 2 + belowOffset(for: role))
                    }
                }

            }
            .frame(width: layout.contentWidth, height: layout.treeHeight, alignment: .topLeading)
        }
        .frame(height: layout.viewportHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(skinService.currentSkin.primaryColor.opacity(0.32), lineWidth: 1)
        )
    }

    private func cosmeticTreeBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.unbound.bg
            if UIImage(named: skinService.currentSkin.backgroundAssetName) != nil {
                Image(skinService.currentSkin.backgroundAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .saturation(1.08)
                    .contrast(1.08)
                    .opacity(0.82)
            }
            Rectangle()
                .fill(skinService.currentSkin.mapBackground)
                .blendMode(.screen)
            LinearGradient(
                stops: [
                    .init(color: Color.unbound.bg.opacity(0.10), location: 0.0),
                    .init(color: Color.unbound.bg.opacity(0.18), location: 0.45),
                    .init(color: Color.unbound.bg.opacity(0.58), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    /// Renders the ghost rails + primary rails into a single UIImage sized
    /// to the full tree content. UIGraphicsImageRenderer ALWAYS renders the
    /// entire requested rect (unlike SwiftUI Canvas which renders lazily).
    private func renderRailsImage(
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole],
        nodeById: [String: SkillNode],
        contentWidth: CGFloat,
        treeHeight: CGFloat
    ) -> UIImage {
        let size = CGSize(width: contentWidth, height: treeHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            cgCtx.setLineCap(.round)
            cgCtx.setLineJoin(.round)
            drawGhostRailsCG(
                cgCtx,
                positions: positions,
                primaryParent: primaryParent,
                roles: roles,
                nodeById: nodeById
            )
            drawPrimaryRailsCG(
                cgCtx,
                positions: positions,
                primaryParent: primaryParent,
                roles: roles,
                nodeById: nodeById
            )
        }
    }

    /// Pick a viewport height for the tree map that matches the rendered
    /// height of the content at its initial zoom. If the tree is wide and
    /// gets clamped down to fit horizontally, the content renders shorter
    /// vertically too — sizing the viewport off the *rendered* height
    /// avoids the black empty space that appears when the frame is taller
    /// than the actual zoomed content.
    private func mapViewportHeight(contentWidth: CGFloat, for treeHeight: CGFloat) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let initialZoom = min(1.0, max(minZoom, screenWidth / max(contentWidth, 1)))
        let renderedHeight = ceil(treeHeight * initialZoom)
        let screenHeight = UIScreen.main.bounds.height
        return min(max(renderedHeight, 400), min(screenHeight * 0.72, 760))
    }

    // MARK: - Rank bands

    /// One gutter row. `isPresent` toggles colored vs dimmed styling.
    fileprivate struct RankBand {
        let rank: SkillRank
        let y: CGFloat
        let isPresent: Bool
    }

    /// Compute a row for ALL 6 rank tiers so the gutter always reads E-S.
    /// Present ranks anchor to the min-Y of their nodes. Absent ranks get
    /// an interpolated Y between the nearest present ranks above & below
    /// so the column of hex badges spaces evenly top-to-bottom.
    private func computeAllRankBands(
        positions: [String: CGPoint],
        nodeById: [String: SkillNode],
        topY: CGFloat,
        bottomY: CGFloat
    ) -> [RankBand] {
        var minY: [SkillRank: CGFloat] = [:]
        for (id, pt) in positions {
            guard let node = nodeById[id] else { continue }
            let r = node.rank
            if let existing = minY[r] {
                if pt.y < existing { minY[r] = pt.y }
            } else {
                minY[r] = pt.y
            }
        }

        let ranks = SkillRank.allCases  // E, D, C, B, A, S

        // Anchors: y for every present rank. Synthetic edge anchors at the
        // top/bottom so absent ranks at the head/tail of the list still get
        // a sensible interpolation.
        let presentIndices = ranks.indices.filter { minY[ranks[$0]] != nil }
        let anchors: [(idx: Int, y: CGFloat)] = {
            var a: [(Int, CGFloat)] = []
            if !presentIndices.contains(0) {
                a.append((-1, topY))
            }
            for idx in presentIndices {
                a.append((idx, minY[ranks[idx]] ?? topY))
            }
            if !presentIndices.contains(ranks.count - 1) {
                a.append((ranks.count, bottomY))
            }
            return a
        }()

        func interpolate(at index: Int) -> CGFloat {
            // Find straddling anchors.
            var before: (Int, CGFloat) = anchors.first ?? (-1, topY)
            var after: (Int, CGFloat) = anchors.last ?? (ranks.count, bottomY)
            for a in anchors {
                if a.idx <= index { before = a }
                if a.idx >= index { after = a; break }
            }
            if before.0 == after.0 { return before.1 }
            let span = CGFloat(after.0 - before.0)
            let offset = CGFloat(index - before.0) / max(1, span)
            return before.1 + (after.1 - before.1) * offset
        }

        return ranks.enumerated().map { idx, rank in
            let present = minY[rank] != nil
            let y = present ? (minY[rank] ?? topY) : interpolate(at: idx)
            return RankBand(rank: rank, y: y, isPresent: present)
        }
    }

    // MARK: - Rank band regions (backgrounds + dividers)

    /// A full-width horizontal stripe for a single rank.
    fileprivate struct RankBandRegion {
        let rank: SkillRank
        let top: CGFloat
        let bottom: CGFloat
    }

    /// Background stripes + dotted divider Y-positions. Driven only by
    /// ranks actually present in the cluster (absent ranks collapse — no
    /// empty stripe, no phantom divider). Divider between adjacent ranks
    /// sits at the midpoint between the prior rank's max-Y and the next
    /// rank's min-Y (so they land in the whitespace between rows).
    private func computeRankBandRegions(
        positions: [String: CGPoint],
        nodeById: [String: SkillNode],
        topY: CGFloat,
        bottomY: CGFloat
    ) -> (bands: [RankBandRegion], dividers: [CGFloat]) {
        var minY: [SkillRank: CGFloat] = [:]
        var maxY: [SkillRank: CGFloat] = [:]
        for (id, pt) in positions {
            guard let node = nodeById[id] else { continue }
            let r = node.rank
            if let e = minY[r] { if pt.y < e { minY[r] = pt.y } } else { minY[r] = pt.y }
            if let e = maxY[r] { if pt.y > e { maxY[r] = pt.y } } else { maxY[r] = pt.y }
        }

        let presentRanks = SkillRank.allCases.filter { minY[$0] != nil }

        // Short-circuit: no ranks present — single covering band.
        guard !presentRanks.isEmpty else {
            return ([], [])
        }

        // Dividers: midpoint between maxY(rN) and minY(rN+1) for each
        // consecutive pair of present ranks.
        var dividers: [CGFloat] = []
        for i in 0..<(presentRanks.count - 1) {
            let rA = presentRanks[i]
            let rB = presentRanks[i + 1]
            let aMax = maxY[rA] ?? topY
            let bMin = minY[rB] ?? bottomY
            dividers.append((aMax + bMin) / 2)
        }

        // Bands: first band starts at topY, last ends at bottomY. Inner
        // boundaries follow the dividers.
        var bands: [RankBandRegion] = []
        for (i, rank) in presentRanks.enumerated() {
            let top    = (i == 0) ? topY : dividers[i - 1]
            let bottom = (i == presentRanks.count - 1) ? bottomY : dividers[i]
            bands.append(RankBandRegion(rank: rank, top: top, bottom: bottom))
        }

        return (bands, dividers)
    }

    /// Faint per-rank background tint. Opacity ramps up from E→A, with
    /// S switching to impact orange for the flame/mythic band. Values
    /// tuned to sit just above perception — like a radar sweep.
    /// Vertical rank-tier track rendered at the left edge of the tree
    /// viewport. Just the hex badges per rank — all 6 render, absent ranks
    /// appear dimmed in neutral grey so the user can see the full tier
    /// ladder at a glance.
    @ViewBuilder
    private func rankBandTrack(
        bands: [RankBand],
        height: CGFloat
    ) -> some View {
        if bands.isEmpty {
            Color.clear.frame(width: 0, height: 0)
        } else {
            let badgeSize: CGFloat = 34
            let paddingLeading: CGFloat = 8
            let columnWidth = paddingLeading + badgeSize + 4

            ZStack(alignment: .topLeading) {
                // One difficulty badge per rank band, always bottom-to-top.
                ForEach(bands, id: \.rank) { band in
                    rankTitleBadge(rank: band.rank, active: band.isPresent, size: badgeSize)
                        .position(x: paddingLeading + badgeSize / 2, y: band.y)
                }
            }
            .frame(width: columnWidth, height: height, alignment: .topLeading)
        }
    }

    /// Small difficulty badge in the gutter. Uses rank-title badge art so
    /// difficulty reads as Initiate → Ascendant rather than letter grades.
    private func rankTitleBadge(rank: SkillRank, active: Bool, size: CGFloat) -> some View {
        Image(rank.rankTitle.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(active ? 1 : 0.15)
            .opacity(active ? 1.0 : 0.28)
            .shadow(
                color: rank.accentColor.opacity(active ? 0.35 : 0),
                radius: active ? 8 : 0
            )
            .accessibilityLabel("\(rank.rankTitle.displayName) difficulty")
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
        let skin = skinService.currentSkin
        return ZStack {
            Hexagon()
                .fill(skin.nodeFill(state: state, faded: false))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(skin.primaryColor, lineWidth: 2)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(skin.impactColor.opacity(0.7), lineWidth: 1)
                .frame(width: size + 16, height: size + 16)
            glyph(for: node, state: state, fontSize: 36)
        }
        .scaleEffect(activePulse)
        .shadow(color: skin.primaryColor.opacity(0.55), radius: 20)
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    private func keystoneHex(node: SkillNode, state: NodeState, size: CGFloat) -> some View {
        let skin = skinService.currentSkin
        return ZStack {
            Hexagon()
                .fill(keystoneFill(state: state))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(skin.primaryColor, lineWidth: 2)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(
                    state == .locked
                        ? skin.primaryColor.opacity(0.4)
                        : skin.impactColor.opacity(0.85),
                    lineWidth: 1
                )
                .frame(width: size + 18, height: size + 18)
            Image(systemName: state == .locked ? "crown" : "crown.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(skin.primaryColor)
        }
        .shadow(
            color: state == .locked
                ? skin.primaryColor.opacity(0.3)
                : skin.impactColor.opacity(0.55),
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
                .foregroundStyle(skinService.currentSkin.primaryColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.unbound.bg)
        }
        .frame(width: 160)
    }

    private func keystoneFill(state: NodeState) -> Color {
        skinService.currentSkin.nodeFill(state: state, faded: false)
    }

    // MARK: - Rails

    /// Primary rails: child ← primary parent. Orthogonal step path with
    /// full-accent glow tiered by reached/partial/locked state. Parallel
    /// children render a horizontal side-rail at the shared y instead.
    private func drawPrimaryRails(
        ctx: GraphicsContext,
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole],
        nodeById: [String: SkillNode]
    ) {
        for (childId, parentId) in primaryParent {
            guard let childPt = positions[childId],
                  let parentPt = positions[parentId]
            else { continue }

            let fromSize = sizeFor(role: roles[parentId] ?? .tangent)
            let toSize   = sizeFor(role: roles[childId]  ?? .tangent)
            let isParallel = nodeById[childId]?.isParallelToParent ?? false

            if isParallel {
                drawParallelRail(
                    ctx: ctx,
                    from: parentPt,
                    to: childPt,
                    fromSize: fromSize,
                    toSize: toSize,
                    fromReached: isUnlockedState(nodeStates[parentId] ?? .locked),
                    toReached: isUnlockedState(nodeStates[childId] ?? .locked),
                    tint: skinService.currentSkin.primaryColor
                )
            } else {
                guard parentPt.y < childPt.y else { continue }
                drawRail(
                    ctx: ctx,
                    from: parentPt,
                    to: childPt,
                    fromSize: fromSize,
                    toSize: toSize,
                    fromReached: isUnlockedState(nodeStates[parentId] ?? .locked),
                    toReached: isUnlockedState(nodeStates[childId] ?? .locked),
                    tint: skinService.currentSkin.primaryColor
                )
            }
        }
    }

    /// Horizontal "side" rail used when a child is rendered parallel to
    /// its parent (same y, offset to the right). Anchors at the parent's
    /// right hex edge and the child's left hex edge.
    private func drawParallelRail(
        ctx: GraphicsContext,
        from parent: CGPoint,
        to child: CGPoint,
        fromSize: CGFloat,
        toSize: CGFloat,
        fromReached: Bool,
        toReached: Bool,
        tint: Color
    ) {
        let goingRight = child.x >= parent.x
        let start = CGPoint(
            x: parent.x + (goingRight ? fromSize / 2 : -fromSize / 2),
            y: parent.y
        )
        let end = CGPoint(
            x: child.x + (goingRight ? -toSize / 2 : toSize / 2),
            y: child.y
        )
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        strokeRail(
            ctx: ctx,
            path: path,
            fromReached: fromReached,
            toReached: toReached,
            tint: tint
        )
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

    // MARK: - Rails (CGContext versions for UIGraphicsImageRenderer)
    //
    // SwiftUI Canvas inside UIHostingController inside UIScrollView renders
    // lazily — only what UIKit considers "visible." When the user zooms out,
    // rails connecting nodes outside the original viewport simply vanish.
    // `.drawingGroup()` doesn't help (the Metal texture itself is sized to
    // the visible region). The CG renderer below draws into a full-content-
    // sized UIImage that gets displayed inline, bypassing the lazy behavior.

    private func drawPrimaryRailsCG(
        _ cgCtx: CGContext,
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole],
        nodeById: [String: SkillNode]
    ) {
        for (childId, parentId) in primaryParent {
            guard let childPt = positions[childId],
                  let parentPt = positions[parentId]
            else { continue }

            let fromSize = sizeFor(role: roles[parentId] ?? .tangent)
            let toSize   = sizeFor(role: roles[childId]  ?? .tangent)
            let isParallel = nodeById[childId]?.isParallelToParent ?? false

            if isParallel {
                drawParallelRailCG(
                    cgCtx,
                    from: parentPt,
                    to: childPt,
                    fromSize: fromSize,
                    toSize: toSize,
                    fromReached: isUnlockedState(nodeStates[parentId] ?? .locked),
                    toReached: isUnlockedState(nodeStates[childId] ?? .locked),
                    tint: skinService.currentSkin.primaryColor
                )
            } else {
                guard parentPt.y < childPt.y else { continue }
                drawRailCG(
                    cgCtx,
                    from: parentPt,
                    to: childPt,
                    fromSize: fromSize,
                    toSize: toSize,
                    fromReached: isUnlockedState(nodeStates[parentId] ?? .locked),
                    toReached: isUnlockedState(nodeStates[childId] ?? .locked),
                    tint: skinService.currentSkin.primaryColor
                )
            }
        }
    }

    private func drawParallelRailCG(
        _ cgCtx: CGContext,
        from parent: CGPoint,
        to child: CGPoint,
        fromSize: CGFloat,
        toSize: CGFloat,
        fromReached: Bool,
        toReached: Bool,
        tint: Color
    ) {
        let goingRight = child.x >= parent.x
        let start = CGPoint(
            x: parent.x + (goingRight ? fromSize / 2 : -fromSize / 2),
            y: parent.y
        )
        let end = CGPoint(
            x: child.x + (goingRight ? -toSize / 2 : toSize / 2),
            y: child.y
        )
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        strokeRailCG(
            cgCtx,
            path: path,
            fromReached: fromReached,
            toReached: toReached,
            tint: tint
        )
    }

    private func drawGhostRailsCG(
        _ cgCtx: CGContext,
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole],
        nodeById: [String: SkillNode]
    ) {
        let ghostUIColor = UIColor(Color.unbound.textTertiary).withAlphaComponent(0.3)

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

                let path = CGMutablePath()
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
                cgCtx.saveGState()
                cgCtx.setStrokeColor(ghostUIColor.cgColor)
                cgCtx.setLineWidth(1.2)
                cgCtx.setLineDash(phase: 0, lengths: [4, 6])
                cgCtx.addPath(path)
                cgCtx.strokePath()
                cgCtx.setLineDash(phase: 0, lengths: [])
                cgCtx.restoreGState()
            }
        }
    }

    private func drawRailCG(
        _ cgCtx: CGContext,
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

        let path = CGMutablePath()
        let tolerance: CGFloat = 1.0

        if abs(end.x - start.x) <= tolerance {
            path.move(to: start)
            path.addLine(to: end)
        } else {
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

        strokeRailCG(cgCtx, path: path, fromReached: fromReached, toReached: toReached, tint: tint)
    }

    private func strokeRailCG(
        _ cgCtx: CGContext,
        path: CGMutablePath,
        fromReached: Bool,
        toReached: Bool,
        tint: Color
    ) {
        let uiTint = UIColor(tint)
        if fromReached && toReached {
            cgCtx.saveGState()
            cgCtx.setShadow(offset: .zero, blur: 4, color: uiTint.withAlphaComponent(0.6).cgColor)
            cgCtx.setStrokeColor(uiTint.withAlphaComponent(0.6).cgColor)
            cgCtx.setLineWidth(6)
            cgCtx.addPath(path)
            cgCtx.strokePath()
            cgCtx.restoreGState()
            cgCtx.setStrokeColor(uiTint.cgColor)
            cgCtx.setLineWidth(2.5)
            cgCtx.addPath(path)
            cgCtx.strokePath()
        } else if fromReached {
            cgCtx.saveGState()
            cgCtx.setShadow(offset: .zero, blur: 3, color: uiTint.withAlphaComponent(0.45).cgColor)
            cgCtx.setStrokeColor(uiTint.withAlphaComponent(0.45).cgColor)
            cgCtx.setLineWidth(5)
            cgCtx.addPath(path)
            cgCtx.strokePath()
            cgCtx.restoreGState()
            cgCtx.setStrokeColor(uiTint.withAlphaComponent(0.85).cgColor)
            cgCtx.setLineWidth(2)
            cgCtx.addPath(path)
            cgCtx.strokePath()
        } else {
            cgCtx.saveGState()
            cgCtx.setShadow(offset: .zero, blur: 2.5, color: uiTint.withAlphaComponent(0.25).cgColor)
            cgCtx.setStrokeColor(uiTint.withAlphaComponent(0.25).cgColor)
            cgCtx.setLineWidth(4)
            cgCtx.addPath(path)
            cgCtx.strokePath()
            cgCtx.restoreGState()
            cgCtx.setStrokeColor(uiTint.withAlphaComponent(0.55).cgColor)
            cgCtx.setLineWidth(1.8)
            cgCtx.addPath(path)
            cgCtx.strokePath()
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
                            tint: skinService.currentSkin.impactColor
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
                    .strokeBorder(skinService.currentSkin.impactColor, lineWidth: 1.5)
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(skinService.currentSkin.impactColor, lineWidth: 1.5)
                    .frame(width: size + 14, height: size + 14)
                    .opacity(state == .locked ? 0.45 : 0.9)
                glyph(for: node, state: state, fontSize: 24)
            }
            .shadow(color: skinService.currentSkin.impactColor.opacity(0.5), radius: state == .locked ? 0 : 10)

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
                .foregroundStyle(skinService.currentSkin.impactColor)
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
        skinService.currentSkin.nodeFill(state: state, faded: faded)
    }

    private func borderColor(node: SkillNode, state: NodeState, faded: Bool) -> Color {
        skinService.currentSkin.nodeBorder(state: state, faded: faded, mythic: node.isMythic)
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
        skinService.currentSkin.nodeGlow(state: state, faded: faded)
    }

    @ViewBuilder
    private func glyph(for node: SkillNode, state: NodeState, fontSize: CGFloat) -> some View {
        switch state {
        case .locked:
            Image(systemName: node.isKeystone ? "crown" : "lock.fill")
                .font(.system(size: fontSize - 3, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            skillIcon(for: node, size: fontSize * 2.4, fallback: node.glyph,
                      tint: skinService.currentSkin.primaryColor)
        case .achieved:
            skillIcon(for: node, size: fontSize * 2.4,
                      fallback: node.isKeystone ? "crown.fill" : "checkmark",
                      tint: skinService.currentSkin.primaryColor)
        case .mastered:
            skillIcon(for: node, size: fontSize * 2.4, fallback: "crown.fill",
                      tint: skinService.currentSkin.impactColor)
        }
    }

    /// Renders the AI-generated skill icon if the asset exists; otherwise falls
    /// back to an SF Symbol. Asset images already carry the violet silhouette
    /// styling so we don't tint them — only the SF Symbol fallback is tinted.
    /// Asset names map node ids by replacing dots with underscores
    /// (e.g. `cal.pushup` → `cal_pushup`).
    @ViewBuilder
    private func skillIcon(
        for node: SkillNode,
        size: CGFloat,
        fallback symbolName: String,
        tint: Color
    ) -> some View {
        let assetName = node.id.replacingOccurrences(of: ".", with: "_")
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: size / 2.4, weight: .semibold))
                .foregroundStyle(tint)
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

        // Mythics now render inline in the main tree as the deepest tier,
        // so the dedicated MYTHIC section below the tree is empty.
        let mythic: [SkillNode] = []
        _ = mythicNodes
        _ = keystoneUnlocked

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

/// Snapshot of everything ClusterStaircaseView needs to draw the tree,
/// computed once on appear and cached in @State. The `railsImage` field
/// is a pre-rendered UIImage covering the FULL content size — see
/// `renderRailsImage(...)` for the reason.
private struct ComputedTreeLayout {
    let contentWidth: CGFloat
    let treeHeight: CGFloat
    let positions: [String: CGPoint]
    let primaryParent: [String: String]
    let roles: [String: ClusterStaircaseView.NodeRole]
    let nodeById: [String: SkillNode]
    let rankBands: [ClusterStaircaseView.RankBand]
    let bandRegions: (bands: [ClusterStaircaseView.RankBandRegion], dividers: [CGFloat])
    let railsImage: UIImage
    let initialOffset: CGPoint?
    let activeZoom: CGFloat
    let viewportHeight: CGFloat
}

private struct ZoomableTreeScrollView<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let initialZoom: CGFloat
    let initialOffset: CGPoint?
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(minZoom: minZoom, maxZoom: maxZoom)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.zoomScale = initialZoom
        // Hard boundaries: no bounce past content edges on any axis.
        // bouncesZoom stays on so pinch overshoot still feels rubbery.
        scrollView.bounces = false
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .normal
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true

        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(origin: .zero, size: contentSize)
        host.view.isUserInteractionEnabled = true
        context.coordinator.hostingController = host

        scrollView.addSubview(host.view)
        scrollView.contentSize = contentSize

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let isInteracting = scrollView.isZooming || scrollView.isDragging || scrollView.isDecelerating
        if !isInteracting {
            context.coordinator.hostingController?.rootView = content()
            if context.coordinator.hostingController?.view.bounds.size != contentSize {
                context.coordinator.hostingController?.view.frame = CGRect(origin: .zero, size: contentSize)
            }
        }
        context.coordinator.minZoom = minZoom
        context.coordinator.maxZoom = maxZoom
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.contentSize = contentSize

        if !context.coordinator.didApplyInitialZoom {
            let zoom = min(max(initialZoom, minZoom), maxZoom)
            scrollView.setZoomScale(zoom, animated: false)
            context.coordinator.didApplyInitialZoom = true
        } else if scrollView.zoomScale < minZoom || scrollView.zoomScale > maxZoom {
            scrollView.setZoomScale(min(max(scrollView.zoomScale, minZoom), maxZoom), animated: false)
        }

        // Apply initial content offset once, after zoom is set, so the
        // active node lands centered in the viewport on open.
        if !context.coordinator.didApplyInitialOffset, let offset = initialOffset {
            // Clamp to valid range against the *current* zoomed content size
            // and viewport bounds, in case sizing changed between layouts.
            let maxOffX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
            let maxOffY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let clamped = CGPoint(
                x: min(max(0, offset.x), maxOffX),
                y: min(max(0, offset.y), maxOffY)
            )
            scrollView.setContentOffset(clamped, animated: false)
            context.coordinator.didApplyInitialOffset = true
        }

        context.coordinator.centerContentIfNeeded()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var hostingController: UIHostingController<Content>?
        weak var scrollView: UIScrollView?
        var minZoom: CGFloat = 0.45
        var maxZoom: CGFloat = 1.5
        var didApplyInitialZoom = false
        var didApplyInitialOffset = false

        init(minZoom: CGFloat, maxZoom: CGFloat) {
            self.minZoom = minZoom
            self.maxZoom = maxZoom
            super.init()
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContentIfNeeded()
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > minZoom + 0.08 {
                scrollView.setZoomScale(minZoom, animated: true)
                return
            }

            let tapPoint = recognizer.location(in: hostingController?.view)
            let targetZoom = min(max(1.0, minZoom), maxZoom)
            let width = scrollView.bounds.width / targetZoom
            let height = scrollView.bounds.height / targetZoom
            let rect = CGRect(
                x: tapPoint.x - width / 2,
                y: tapPoint.y - height / 2,
                width: width,
                height: height
            )
            scrollView.zoom(to: rect, animated: true)
        }

        func centerContentIfNeeded() {
            guard let scrollView, let hostedView = hostingController?.view else { return }
            let boundsSize = scrollView.bounds.size
            var frame = hostedView.frame
            frame.origin.x = frame.size.width < boundsSize.width
                ? (boundsSize.width - frame.size.width) / 2
                : 0
            frame.origin.y = frame.size.height < boundsSize.height
                ? (boundsSize.height - frame.size.height) / 2
                : 0
            hostedView.frame = frame
        }
    }
}
