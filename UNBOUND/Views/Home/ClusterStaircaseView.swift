import SwiftUI
import UIKit

// MARK: - ClusterStaircaseView
//
// Candy-Crush-style cluster map. Every node in the cluster lives on a
// single zig-zag map — no lane cards, no overflow chips, no segregated
// "other directions" footer. Tier-depth (computed from prereqs) places
// each node on a row, and a barycentric sort within each tier aligns
// children horizontally with their prereqs. Multiple within-cluster
// prereqs render as siblings on the same tier, both edges descending
// to the shared child — honest parallel forks.
//
// Edges are Canvas-drawn quadratic beziers with glow:
//   • both nodes achieved  → solid bright accent, heavy + blurred underlay
//   • prereq achieved only → medium accent, solid
//   • otherwise            → dim accent, dashed
//
// Pan + pinch-zoom ships via a UIScrollView bridge — SwiftUI scaleEffect
// bugged out on render offsets in earlier iterations (see 1c72100), so
// the bridge is the robust path. Scale clamped [0.5, 2.0]. Double-tap
// resets scale to 1.0 and re-centers on the active node. On first
// appearance we auto-center on the active node (first .attempting, else
// the lowest-tier unlockable .locked, else the keystone).
//
// Unchanged integrations:
//   • Tap any node → presents `SkillNodeDetailSheet`
//   • [FULL TREE] → presents `ClusterDetailView` as a sheet
//   • Back button dismisses the staircase

struct ClusterStaircaseView: View {
    let cluster: SkillCluster
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedNode: SkillNode?
    @State private var showFullTree: Bool = false
    @State private var activePulse: CGFloat = 1.0
    @State private var scrollViewHandle: UIScrollView?

    private var clusterNodes: [SkillNode] {
        graph.nodes(in: cluster)
    }

    // MARK: - Layout constants

    private let rowSpacing: CGFloat = 140
    private let columnSpacing: CGFloat = 120
    private let mapHorizontalPadding: CGFloat = 80
    private let mapVerticalPadding: CGFloat = 100

    // MARK: - Computed layout

    private var layout: MapLayout {
        buildLayout()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            mapScrollable
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .sheet(item: $selectedNode) { node in
            SkillNodeDetailSheet(
                node: node,
                currentState: nodeStates[node.id] ?? .locked
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.unbound.bg)
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
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                activePulse = 1.08
            }
        }
    }

    // MARK: - Scrollable map host (pan + pinch zoom)

    private var mapScrollable: some View {
        let l = layout
        return ZoomableScrollView(
            contentSize: l.contentSize,
            onReady: { scroll in
                scrollViewHandle = scroll
                centerOnActive(scroll: scroll, layout: l, animated: false)
            },
            onDoubleTap: { scroll in
                scroll.setZoomScale(1.0, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    centerOnActive(scroll: scroll, layout: l, animated: true)
                }
            }
        ) {
            mapContent(layout: l)
        }
    }

    @ViewBuilder
    private func mapContent(layout l: MapLayout) -> some View {
        ZStack(alignment: .topLeading) {
            // Edge layer — all bezier rails drawn underneath the hexes.
            Canvas { ctx, _ in
                drawEdges(ctx: ctx, layout: l)
            }
            .frame(width: l.contentSize.width, height: l.contentSize.height)

            // Node layer.
            ForEach(l.placements, id: \.node.id) { placement in
                MapHexCell(
                    node: placement.node,
                    state: nodeStates[placement.node.id] ?? .locked,
                    kind: placement.kind,
                    isActive: placement.node.id == l.activeId,
                    pulse: placement.node.id == l.activeId ? activePulse : 1.0,
                    onTap: {
                        UnboundHaptics.medium()
                        selectedNode = placement.node
                    }
                )
                .position(
                    x: placement.position.x,
                    y: placement.position.y
                )
            }
        }
        .frame(width: l.contentSize.width, height: l.contentSize.height, alignment: .topLeading)
        .background(Color.unbound.bg)
    }

    // MARK: - Edge drawing

    private func drawEdges(ctx: GraphicsContext, layout l: MapLayout) {
        let placementById = Dictionary(uniqueKeysWithValues: l.placements.map { ($0.node.id, $0) })

        for placement in l.placements {
            let node = placement.node
            let withinPrereqs = node.prereqs
                .flatMap { $0.nodeIds }
                .compactMap { placementById[$0] }
            guard !withinPrereqs.isEmpty else { continue }

            let childState = nodeStates[node.id] ?? .locked
            let childReached = childState == .achieved || childState == .mastered

            for prereq in withinPrereqs {
                let prereqState = nodeStates[prereq.node.id] ?? .locked
                let prereqReached = prereqState == .achieved || prereqState == .mastered

                let style: EdgeStyle
                if prereqReached && childReached {
                    style = .bothReached
                } else if prereqReached {
                    style = .prereqReached
                } else {
                    style = .dim
                }

                drawEdge(
                    ctx: ctx,
                    from: prereq.position,
                    to: placement.position,
                    fromHexSize: prereq.kind.hexSize,
                    toHexSize: placement.kind.hexSize,
                    style: style
                )
            }
        }
    }

    private func drawEdge(
        ctx: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        fromHexSize: CGFloat,
        toHexSize: CGFloat,
        style: EdgeStyle
    ) {
        // Anchor the curve at the bottom of the upstream hex and the top
        // of the downstream hex. The hex is drawn centered at `position`,
        // so edges enter/leave at (cx, cy ± size/2).
        let start = CGPoint(x: from.x, y: from.y + fromHexSize * 0.42)
        let end   = CGPoint(x: to.x,   y: to.y   - toHexSize   * 0.42)

        let midY = (start.y + end.y) / 2
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x, y: midY),
            control2: CGPoint(x: end.x,   y: midY)
        )

        switch style {
        case .bothReached:
            // Glowing blurred underlay + bright solid rail.
            ctx.stroke(
                path,
                with: .color(Color.unbound.accent.opacity(0.55)),
                style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
            ctx.stroke(
                path,
                with: .color(Color.unbound.accent),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
        case .prereqReached:
            ctx.stroke(
                path,
                with: .color(Color.unbound.accent.opacity(0.8)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        case .dim:
            ctx.stroke(
                path,
                with: .color(Color.unbound.accent.opacity(0.3)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 6])
            )
        }
    }

    private enum EdgeStyle { case bothReached, prereqReached, dim }

    // MARK: - Auto-center on active

    private func centerOnActive(scroll: UIScrollView, layout l: MapLayout, animated: Bool) {
        guard let active = l.placements.first(where: { $0.node.id == l.activeId }) else { return }
        let viewport = scroll.bounds.size
        guard viewport.width > 0, viewport.height > 0 else {
            // Viewport not laid out yet — retry shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                centerOnActive(scroll: scroll, layout: l, animated: animated)
            }
            return
        }
        let scale = scroll.zoomScale
        let targetX = active.position.x * scale - viewport.width / 2
        let targetY = active.position.y * scale - viewport.height / 2
        let maxX = max(0, l.contentSize.width * scale - viewport.width)
        let maxY = max(0, l.contentSize.height * scale - viewport.height)
        let clamped = CGPoint(
            x: min(max(0, targetX), maxX),
            y: min(max(0, targetY), maxY)
        )
        scroll.setContentOffset(clamped, animated: animated)
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

    // MARK: - Layout algorithm

    private struct Placement {
        let node: SkillNode
        let position: CGPoint
        let kind: HexKind
    }

    private struct MapLayout {
        let placements: [Placement]
        let contentSize: CGSize
        let activeId: String?
    }

    enum HexKind {
        case locked
        case active
        case keystone
        case mythic

        var hexSize: CGFloat {
            switch self {
            case .locked:   return 90
            case .active:   return 110
            case .keystone: return 120
            case .mythic:   return 100
            }
        }
    }

    private func buildLayout() -> MapLayout {
        let nodes = clusterNodes
        guard !nodes.isEmpty else {
            return MapLayout(placements: [], contentSize: CGSize(width: 200, height: 200), activeId: nil)
        }

        let effectiveTiers = computeEffectiveTiers(nodes: nodes)
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })

        // Partition: keystone + mythic get custom placement; everything else
        // flows through tier-based rows.
        let keystone = nodes.first { $0.isKeystone && !$0.isMythic }
        let mythicNodes = nodes.filter { $0.isMythic }

        let gridNodes = nodes.filter { $0.id != keystone?.id && !$0.isMythic }

        // Group grid nodes by effective tier.
        var rows: [Int: [SkillNode]] = [:]
        for n in gridNodes {
            let t = effectiveTiers[n.id] ?? n.tier
            rows[t, default: []].append(n)
        }

        let sortedTiers = rows.keys.sorted()
        let maxGridTier = sortedTiers.last ?? 1

        // Barycentric sort: iterate tier-by-tier, ordering each row so that
        // each node's x-position is the mean of its prereqs' x-positions.
        // First tier is ordered stably by (tier, id) so the iteration is
        // deterministic across renders.
        var columnIndex: [String: CGFloat] = [:]  // column slot per node id

        for (rowIdx, tier) in sortedTiers.enumerated() {
            var rowNodes = rows[tier] ?? []
            if rowIdx == 0 {
                rowNodes.sort { ($0.tier, $0.id) < ($1.tier, $1.id) }
            } else {
                rowNodes.sort { lhs, rhs in
                    let lBary = barycenter(for: lhs, using: columnIndex, nodeById: nodeById)
                    let rBary = barycenter(for: rhs, using: columnIndex, nodeById: nodeById)
                    if lBary == rBary { return lhs.id < rhs.id }
                    return lBary < rBary
                }
            }
            // Assign column slots centered around 0.
            let count = rowNodes.count
            let offset = CGFloat(count - 1) / 2.0
            for (i, node) in rowNodes.enumerated() {
                columnIndex[node.id] = CGFloat(i) - offset
            }
            rows[tier] = rowNodes
        }

        // Place keystone one tier above the highest grid tier (it's the arc
        // endpoint — lives at the bottom of the map). Mythic nodes stack
        // ABOVE the keystone as a small horizontal cluster.
        let keystoneTier: Int
        if let keystone {
            keystoneTier = (effectiveTiers[keystone.id] ?? keystone.tier)
        } else {
            keystoneTier = maxGridTier + 1
        }
        // Mythic goes at keystoneTier + 1 (one row further down — past the
        // keystone). Spec says: "Mythic nodes render inline above the
        // keystone on the same map." Above in visual terms = higher on
        // screen = smaller y. We'll place them ABOVE (smaller y) the
        // keystone so the keystone remains the visible arc endpoint.
        let mythicTier: Int = keystoneTier + 1

        // Figure out total row count to compute y-offset.
        // Row 1 (tier 1) renders at y = mapVerticalPadding; tier N at
        // mapVerticalPadding + (N - minTier) * rowSpacing.
        let minTier = sortedTiers.first ?? 1
        let gridMaxTier = max(maxGridTier, keystoneTier, mythicTier)

        func yForTier(_ tier: Int) -> CGFloat {
            CGFloat(tier - minTier) * rowSpacing + mapVerticalPadding
        }

        // Determine the widest row in columns so we can center everything.
        var widestRowSpan: CGFloat = 1
        for tier in sortedTiers {
            widestRowSpan = max(widestRowSpan, CGFloat(rows[tier]?.count ?? 0))
        }
        // Include keystone + mythic when sizing.
        if keystone != nil { widestRowSpan = max(widestRowSpan, 1) }
        if !mythicNodes.isEmpty { widestRowSpan = max(widestRowSpan, CGFloat(mythicNodes.count)) }

        let contentWidth = widestRowSpan * columnSpacing + mapHorizontalPadding * 2
        let centerX = contentWidth / 2

        func xForColumn(_ col: CGFloat) -> CGFloat {
            centerX + col * columnSpacing
        }

        // Figure out active node now — we need to know which grid node gets
        // the .active kind (larger hex + pulse).
        let activeId = resolveActiveNodeId(
            nodes: nodes,
            keystone: keystone,
            tiers: effectiveTiers
        )

        var placements: [Placement] = []

        // Grid nodes
        for tier in sortedTiers {
            guard let rowNodes = rows[tier] else { continue }
            for node in rowNodes {
                let col = columnIndex[node.id] ?? 0
                let pos = CGPoint(x: xForColumn(col), y: yForTier(tier))
                let kind: HexKind = (node.id == activeId) ? .active : .locked
                placements.append(Placement(node: node, position: pos, kind: kind))
            }
        }

        // Keystone
        if let keystone {
            let col: CGFloat = 0  // center
            let kind: HexKind = (keystone.id == activeId) ? .active : .keystone
            placements.append(Placement(
                node: keystone,
                position: CGPoint(x: xForColumn(col), y: yForTier(keystoneTier)),
                kind: kind
            ))
        }

        // Mythic row — centered horizontally, tier above the keystone.
        if !mythicNodes.isEmpty {
            let count = mythicNodes.count
            let offset = CGFloat(count - 1) / 2.0
            for (i, node) in mythicNodes.enumerated() {
                let col = CGFloat(i) - offset
                placements.append(Placement(
                    node: node,
                    position: CGPoint(x: xForColumn(col), y: yForTier(mythicTier)),
                    kind: .mythic
                ))
            }
        }

        let contentHeight = yForTier(gridMaxTier) + mapVerticalPadding
        let contentSize = CGSize(width: contentWidth, height: contentHeight)

        return MapLayout(placements: placements, contentSize: contentSize, activeId: activeId)
    }

    private func barycenter(
        for node: SkillNode,
        using columnIndex: [String: CGFloat],
        nodeById: [String: SkillNode]
    ) -> CGFloat {
        let prereqIds = node.prereqs.flatMap { $0.nodeIds }
            .filter { nodeById[$0] != nil }
        guard !prereqIds.isEmpty else { return 0 }
        let xs = prereqIds.compactMap { columnIndex[$0] }
        guard !xs.isEmpty else { return 0 }
        return xs.reduce(0, +) / CGFloat(xs.count)
    }

    private func resolveActiveNodeId(
        nodes: [SkillNode],
        keystone: SkillNode?,
        tiers: [String: Int]
    ) -> String? {
        func stateOf(_ n: SkillNode) -> NodeState { nodeStates[n.id] ?? .locked }

        // 1. First .attempting (by effective tier)
        let attempting = nodes
            .filter { stateOf($0) == .attempting }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        if let first = attempting.first { return first.id }

        // 2. Lowest-tier unlockable .locked (prereqs satisfied)
        let unlockable = nodes
            .filter { stateOf($0) == .locked }
            .filter { $0.prereqsSatisfied(given: nodeStates) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        if let first = unlockable.first { return first.id }

        // 3. Keystone fallback
        return keystone?.id ?? nodes.first?.id
    }

    // MARK: - Effective tier (kept verbatim from prior revision)

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
}

// MARK: - MapHexCell (a single hex marker on the candy-crush map)

private struct MapHexCell: View {
    let node: SkillNode
    let state: NodeState
    let kind: ClusterStaircaseView.HexKind
    let isActive: Bool
    let pulse: CGFloat
    let onTap: () -> Void

    private var size: CGFloat { kind.hexSize }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Hexagon()
                    .fill(fillColor)
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(borderColor, lineWidth: strokeWidth)
                    .frame(width: size, height: size)

                if kind == .active && state != .locked {
                    Hexagon()
                        .strokeBorder(Color.unbound.accent.opacity(0.7), lineWidth: 1)
                        .frame(width: size + 14, height: size + 14)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 14)
                }

                if kind == .keystone {
                    Hexagon()
                        .strokeBorder(
                            state == .locked
                                ? Color.unbound.accent.opacity(0.4)
                                : Color.unbound.accent.opacity(0.85),
                            lineWidth: 1
                        )
                        .frame(width: size + 16, height: size + 16)
                        .shadow(
                            color: state == .locked ? .clear : Color.unbound.accent.opacity(0.5),
                            radius: 12
                        )
                }

                if kind == .mythic {
                    Hexagon()
                        .strokeBorder(Color.unbound.impact.opacity(0.9), lineWidth: 1.5)
                        .frame(width: size + 14, height: size + 14)
                        .opacity(state == .locked ? 0.5 : 0.95)
                }

                glyphView
            }
            .scaleEffect(isActive ? pulse : 1.0)
            .shadow(color: glowColor, radius: state == .locked ? 0 : (isActive ? 18 : 10))

            Text(node.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: max(100, size + 14))

            if kind == .keystone {
                Text("KEYSTONE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
            } else if kind == .mythic {
                Text("MYTHIC")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.impact)
            }
        }
        .frame(width: max(120, size + 14))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var fillColor: Color {
        switch state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.accent.opacity(kind == .active ? 0.22 : 0.14)
        case .achieved:   return Color.unbound.accent.opacity(0.18)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    private var borderColor: Color {
        if kind == .mythic {
            return Color.unbound.impact.opacity(state == .locked ? 0.5 : 1.0)
        }
        if node.isMythic && state == .locked { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .locked:     return Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent
        case .mastered:   return Color.unbound.impact
        }
    }

    private var strokeWidth: CGFloat {
        switch kind {
        case .active:   return 2
        case .keystone: return 2
        case .mythic:   return 2   // gold/impact stroke is a defining trait
        case .locked:
            switch state {
            case .locked:     return 1
            case .attempting: return 1.5
            case .achieved:   return 1.5
            case .mastered:   return 2
            }
        }
    }

    private var glowColor: Color {
        if state == .locked { return .clear }
        if kind == .active { return Color.unbound.accent.opacity(0.7) }
        if kind == .keystone { return Color.unbound.accent.opacity(0.5) }
        if kind == .mythic { return Color.unbound.impact.opacity(0.55) }
        switch state {
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(0.45)
        case .mastered:   return Color.unbound.impact.opacity(0.55)
        case .locked:     return .clear
        }
    }

    @ViewBuilder
    private var glyphView: some View {
        let base: CGFloat = {
            switch kind {
            case .active:   return 26
            case .keystone: return 30
            case .mythic:   return 22
            case .locked:   return 20
            }
        }()
        switch state {
        case .locked:
            Image(systemName: kind == .keystone ? "crown" : "lock.fill")
                .font(.system(size: base - 3, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            Image(systemName: node.glyph)
                .font(.system(size: base, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        case .achieved:
            Image(systemName: kind == .keystone ? "crown.fill" : "checkmark")
                .font(.system(size: base, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .mastered:
            Image(systemName: "crown.fill")
                .font(.system(size: base, weight: .semibold))
                .foregroundStyle(Color.unbound.impact)
        }
    }
}

// MARK: - ZoomableScrollView — UIScrollView bridge for pan + pinch

private struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let contentSize: CGSize
    let onReady: (UIScrollView) -> Void
    let onDoubleTap: (UIScrollView) -> Void
    @ViewBuilder var content: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 0.5
        scroll.maximumZoomScale = 2.0
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .clear
        scroll.delegate = context.coordinator

        let hosting = UIHostingController(rootView: content())
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        hosting.view.frame = CGRect(origin: .zero, size: contentSize)
        scroll.addSubview(hosting.view)
        scroll.contentSize = contentSize

        context.coordinator.contentView = hosting.view
        context.coordinator.hosting = hosting
        context.coordinator.onDoubleTap = { [weak scroll] in
            guard let scroll else { return }
            onDoubleTap(scroll)
        }

        // Double-tap gesture → reset zoom + recenter.
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        DispatchQueue.main.async {
            onReady(scroll)
        }
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Keep the hosted content fresh if SwiftUI state changes.
        context.coordinator.hosting?.rootView = content()
        if uiView.contentSize != contentSize {
            uiView.contentSize = contentSize
            context.coordinator.contentView?.frame = CGRect(origin: .zero, size: contentSize)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var contentView: UIView?
        var hosting: UIHostingController<Content>?
        var onDoubleTap: (() -> Void)?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }

        @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
            onDoubleTap?()
        }
    }
}
