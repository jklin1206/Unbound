import SwiftUI

// MARK: - ClusterDetailView
//
// Drill-in view for a single skill cluster. Renders the cluster's nodes
// as a mini-graph with edges between prerequisite pairs. Keystones and
// Mythic nodes get amplified visual treatment (outer ring / gold stroke).
//
// Layout: nodes positioned by tier (row = tier) and within-tier order
// sorted barycentrically (by average column of prereqs in the prior
// tier) to minimize edge crossings.
//
// Horizontal + vertical scroll is always available so dense clusters
// scroll naturally rather than being clipped.

struct ClusterDetailView: View {
    let cluster: SkillCluster
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]
    var onNodeTap: (SkillNode) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var skinService = SkinService.shared

    private var clusterNodes: [SkillNode] {
        graph.nodes(in: cluster)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryRow
                    graphCanvas
                        .padding(.horizontal, 10)
                    callouts
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: cluster.glyph)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.unbound.surfaceElevated)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(cluster.displayName.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2.2)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text(cluster.tagline)
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle().fill(Color.unbound.surfaceElevated)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    // MARK: Summary row

    private var summaryRow: some View {
        let unlocked = clusterNodes.filter { isUnlocked(nodeStates[$0.id] ?? .locked) }.count
        let keystone = clusterNodes.first { $0.isKeystone && !$0.isMythic }
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROGRESS")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("\(unlocked) / \(clusterNodes.count)")
                    .font(Font.unbound.monoL)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            Spacer()
            if let k = keystone {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("KEYSTONE")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(k.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: Graph canvas

    private var graphCanvas: some View {
        let layout = computeLayout()
        let tiers = computeEffectiveTiers()
        let width = layout.width
        let height = layout.height

        let canvas = ZStack {
            Canvas { ctx, _ in
                // Draw edges for nodes inside this cluster only.
                for node in clusterNodes {
                    guard let to = layout.positions[node.id] else { continue }
                    let allPrereqIds = node.prereqs.flatMap { $0.nodeIds }
                    for prereqId in allPrereqIds {
                        guard let prereq = graph.node(id: prereqId) else { continue }
                        // Only render descending edges — skip any edge where
                        // prereq is at the same effective tier or higher than
                        // the node. Use effective tier (computed from prereqs)
                        // so edges always descend even when hand-assigned tiers
                        // are inconsistent.
                        let prereqTier = tiers[prereq.id] ?? prereq.tier
                        let nodeTier = tiers[node.id] ?? node.tier
                        guard prereqTier < nodeTier else { continue }
                        guard clusterNodes.contains(where: { $0.id == prereqId }),
                              let from = layout.positions[prereqId] else { continue }
                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)
                        let reachable = isUnlocked(nodeStates[prereqId] ?? .locked)
                        ctx.stroke(
                            path,
                            with: .color(reachable
                                         ? skinService.currentSkin.primaryColor.opacity(0.55)
                                         : Color.unbound.border),
                            style: StrokeStyle(
                                lineWidth: 1.5,
                                lineCap: .round,
                                dash: reachable ? [] : [3, 5]
                            )
                        )
                    }
                }
            }
            .frame(width: width, height: height)

            ForEach(clusterNodes) { node in
                clusterNodeCanvasEntry(node: node, layout: layout)
            }
        }
        .frame(width: width, height: height)

        return ScrollView([.horizontal, .vertical], showsIndicators: false) {
            canvas
                .padding(.vertical, 20)
        }
        .frame(maxHeight: 560)
    }

    // MARK: Cross-cluster callouts

    private var callouts: some View {
        let crossEdges = computeCrossClusterPrereqs()
        return Group {
            if !crossEdges.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CROSS-CLUSTER PATHS")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .padding(.top, 16)

                    ForEach(crossEdges, id: \.self) { msg in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(Color.unbound.accent.opacity(0.12))
                                )
                            Text(msg)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.unbound.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: Node canvas entry (extracted to help Swift type-inference)

    @ViewBuilder
    private func clusterNodeCanvasEntry(node: SkillNode, layout: Layout) -> some View {
        if let p = layout.positions[node.id] {
            ClusterNodeHex(
                node: node,
                state: nodeStates[node.id] ?? .locked,
                progress: nodeProgress[node.id],
                skin: skinService.currentSkin
            )
            .position(p)
            .onTapGesture {
                UnboundHaptics.medium()
                onNodeTap(node)
            }
        }
    }

    // MARK: Layout computation

    private struct Layout {
        let positions: [String: CGPoint]
        let width: CGFloat
        let height: CGFloat
    }

    /// For each within-cluster node, compute its effective tier as depth from
    /// the nearest root within this cluster. Root nodes (no within-cluster
    /// prereqs) get effective tier 1. Cross-cluster prereqs are ignored — they
    /// don't count toward depth inside THIS cluster.
    ///
    /// If the node has within-cluster prereqs, its effective tier is
    /// `1 + max(effective tier of each within-cluster prereq)`.
    ///
    /// Cycle-safe: uses memoization + an "in-progress" marker to detect cycles.
    /// If a cycle is detected, the involved nodes fall back to their
    /// hand-assigned `tier` (graceful degradation).
    private func computeEffectiveTiers() -> [String: Int] {
        let nodeById = Dictionary(uniqueKeysWithValues: clusterNodes.map { ($0.id, $0) })
        var cache: [String: Int] = [:]
        var inProgress: Set<String> = []

        func depth(_ id: String) -> Int {
            if let cached = cache[id] { return cached }
            guard let node = nodeById[id] else { return 1 }
            if inProgress.contains(id) {
                // Cycle — fall back to hand-assigned tier for this node.
                return node.tier
            }
            inProgress.insert(id)
            defer { inProgress.remove(id) }

            let withinClusterPrereqIds = node.prereqs.flatMap { $0.nodeIds }
                .filter { nodeById[$0] != nil }

            let d: Int
            if withinClusterPrereqIds.isEmpty {
                d = 1   // root within this cluster
            } else {
                let maxPrereqDepth = withinClusterPrereqIds.map { depth($0) }.max() ?? 0
                d = maxPrereqDepth + 1
            }
            cache[id] = d
            return d
        }

        for node in clusterNodes {
            _ = depth(node.id)
        }
        return cache
    }

    private func computeLayout() -> Layout {
        // Pan+zoom is always on, so dense clusters just fit-to-width on appear.
        // Use consistent spacing regardless of cluster size.
        let dense = clusterNodes.count > 14
        let rowHeight: CGFloat = dense ? 150 : 130
        let colSpacing: CGFloat = dense ? 110 : 130
        let effectiveTier = computeEffectiveTiers()
        let minTier = clusterNodes.compactMap { effectiveTier[$0.id] }.min() ?? 1

        // Group by effective tier (derived from prereq depth rather than the
        // hand-assigned data field — guarantees every node renders below its
        // within-cluster prereqs).
        let byTier = Dictionary(grouping: clusterNodes, by: { effectiveTier[$0.id] ?? $0.tier })

        let sortedTiers = byTier.keys.sorted()

        // Barycentric within-tier ordering. For each tier (top down), sort its
        // nodes by the average column position of their prereqs in the prior
        // tier. Nodes with no prior-tier prereqs (root / cross-cluster only)
        // get a center barycenter as a stable fallback.
        var orderedByTier: [Int: [SkillNode]] = [:]
        for (tierIdx, tier) in sortedTiers.enumerated() {
            let nodes = byTier[tier] ?? []
            if tierIdx == 0 {
                // Root tier: stable alphabetical by id.
                orderedByTier[tier] = nodes.sorted { $0.id < $1.id }
                continue
            }

            let prevTier = sortedTiers[tierIdx - 1]
            let prevOrdered = orderedByTier[prevTier] ?? []
            let prevIndex: [String: Int] = Dictionary(
                uniqueKeysWithValues: prevOrdered.enumerated().map { ($1.id, $0) }
            )
            let centerIdx = Double(max(1, prevOrdered.count)) / 2.0

            let sorted = nodes.sorted { a, b in
                func barycenter(_ node: SkillNode) -> Double {
                    let prereqIds = node.prereqs.flatMap { $0.nodeIds }
                    let idxs = prereqIds.compactMap { prevIndex[$0] }.map(Double.init)
                    guard !idxs.isEmpty else { return centerIdx }
                    return idxs.reduce(0, +) / Double(idxs.count)
                }
                let ba = barycenter(a)
                let bb = barycenter(b)
                if ba != bb { return ba < bb }
                return a.id < b.id  // stable tiebreak
            }
            orderedByTier[tier] = sorted
        }

        let maxColumns = orderedByTier.values.map(\.count).max() ?? 1
        let width = max(320, CGFloat(maxColumns) * colSpacing + 80)
        let height = CGFloat(sortedTiers.count) * rowHeight + 60
        let centerX = width / 2

        var positions: [String: CGPoint] = [:]
        for tier in sortedTiers {
            let row = tier - minTier
            let nodes = orderedByTier[tier] ?? []
            let totalWidth = CGFloat(nodes.count - 1) * colSpacing
            let startX = centerX - totalWidth / 2
            for (idx, n) in nodes.enumerated() {
                let x = startX + CGFloat(idx) * colSpacing
                let y = CGFloat(row) * rowHeight + rowHeight / 2 + 30
                positions[n.id] = CGPoint(x: x, y: y)
            }
        }
        return Layout(positions: positions, width: width, height: height)
    }

    // MARK: Cross-cluster prereq messages

    private func computeCrossClusterPrereqs() -> [String] {
        var messages: [String] = []
        for node in clusterNodes {
            // Only surface cross-cluster prereqs for mythic/keystone to avoid noise
            guard node.isKeystone || node.isMythic else { continue }
            let prereqIds = node.prereqs.flatMap { $0.nodeIds }
            let foreign = prereqIds.compactMap { graph.node(id: $0) }
                .filter { $0.cluster != cluster }
            guard !foreign.isEmpty else { continue }
            let foreignNames = foreign.map(\.title).joined(separator: " + ")
            messages.append("\(node.title) also requires \(foreignNames) (\(foreign[0].cluster.displayName))")
        }
        return messages
    }

    private func isUnlocked(_ s: NodeState) -> Bool {
        s == .proven
    }
}

// MARK: - Node hex for the cluster detail

private struct ClusterNodeHex: View {
    let node: SkillNode
    let state: NodeState
    var progress: Double? = nil        // 0.0-1.0; rendered as bottom fill when attempting
    let skin: SkillTreeSkin

    private var size: CGFloat {
        if node.isMythic || node.isKeystone { return 92 }
        return 72
    }

    private var clampedProgress: Double {
        max(0, min(1, progress ?? 0))
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Hexagon().fill(fillColor).frame(width: size, height: size)

                // Live progress fill — only while attempting and progress > 0.
                if state == .locked, let p = progress, p > 0 {
                    progressFill(fraction: p)
                        .frame(width: size, height: size)
                }

                Hexagon().fill(.thinMaterial).opacity(0.08)
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(borderColor, lineWidth: strokeWidth)
                    .frame(width: size, height: size)
                if node.isKeystone && state != .locked {
                    Hexagon()
                        .strokeBorder(outerRingColor, lineWidth: 1)
                        .frame(width: size + 12, height: size + 12)
                        .shadow(color: outerRingColor.opacity(0.5), radius: 10)
                }
                if node.isMythic {
                    Hexagon()
                        .strokeBorder(skin.impactColor, lineWidth: 1.5)
                        .frame(width: size + 16, height: size + 16)
                        .opacity(state == .locked ? 0.3 : 0.8)
                }
                glyph

                // Progress readout label (e.g. "7/10") over-painted for attempting nodes
                if state == .locked, let p = progress, p > 0 {
                    progressLabel(fraction: p)
                        .offset(y: size / 2 - 4)
                }
            }
            .shadow(color: glowColor, radius: state == .locked ? 0 : 10)

            VStack(spacing: 2) {
                Text(node.title)
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(labelColor)
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 96)

                if node.isMythic {
                    Text("MYTHIC")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(skin.impactDecalColor)
                } else if node.isKeystone {
                    Text("KEYSTONE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(skin.decalColor)
                }
            }
        }
    }

    private var fillColor: Color {
        skin.nodeFill(state: state, faded: false)
    }

    private var borderColor: Color {
        skin.nodeBorder(state: state, faded: false, mythic: node.isMythic)
    }

    private var strokeWidth: CGFloat {
        switch state {
        case .locked: return node.isMythic ? 1.5 : 1
        case .proven: return 1.5
        }
    }

    private var outerRingColor: Color {
        skin.primaryColor
    }

    private var glowColor: Color {
        skin.nodeGlow(state: state, faded: false)
    }

    private var labelColor: Color {
        state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
    }

    @ViewBuilder
    private var glyph: some View {
        let fontSize = node.isKeystone || node.isMythic ? 26.0 : 22.0
        switch state {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: fontSize - 4, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .proven:
            assetOrSymbol(symbolName: "checkmark", fontSize: fontSize, tint: skin.decalColor)
        }
    }

    @ViewBuilder
    private func assetOrSymbol(symbolName: String, fontSize: CGFloat, tint: Color) -> some View {
        let assetName = node.id.replacingOccurrences(of: ".", with: "_")
        if UIImage(named: assetName) != nil {
            let size = fontSize * 2.15
            ZStack {
                Circle()
                    .fill(Color.unbound.bg.opacity(0.5))
                    .overlay(
                        Circle()
                            .strokeBorder(tint.opacity(0.28), lineWidth: max(1, size * 0.025))
                    )
                    .frame(width: size * 0.88, height: size * 0.88)
                    .shadow(color: Color.black.opacity(0.42), radius: 4)

                Image(assetName)
                    .renderingMode(usesOriginalNodeArtwork(assetName) ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(tint)
                    .frame(
                        width: size * (usesOriginalNodeArtwork(assetName) ? 0.9 : 0.78),
                        height: size * (usesOriginalNodeArtwork(assetName) ? 0.9 : 0.78)
                    )
                    .shadow(color: Color.black.opacity(0.72), radius: 3)
                    .shadow(color: tint.opacity(0.5), radius: 4)
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: fontSize, weight: symbolName == "checkmark" ? .bold : .semibold))
                .foregroundStyle(tint)
        }
    }

    private func usesOriginalNodeArtwork(_ assetName: String) -> Bool {
        assetName == "hs_tuck-handstand"
    }

    // MARK: In-hex progress fill

    private func progressFill(fraction: Double) -> some View {
        let f = max(0, min(1, fraction))
        return Hexagon()
            .fill(skin.primaryColor.opacity(0.35))
            .mask(
                VStack(spacing: 0) {
                    Color.clear.frame(height: size * (1 - f))
                    Color.black.frame(height: size * f)
                }
                .frame(width: size, height: size)
            )
            .animation(.easeOut(duration: 0.45), value: fraction)
    }

    private func progressLabel(fraction: Double) -> some View {
        let pct = Int((max(0, min(1, fraction)) * 100).rounded())
        return Text("\(pct)%")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(skin.decalColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.unbound.bg)
            )
            .overlay(
                Capsule().strokeBorder(skin.decalColor.opacity(0.6), lineWidth: 1)
            )
    }
}
