import SwiftUI

// MARK: - ClusterStaircaseView
//
// Primary cluster-detail view. Replaces the hex-grid `ClusterDetailView`
// as the default way a cluster's progression is presented.
//
// Shape: a vertical zig-zag staircase of hexagons, grouped into sections
// (ACHIEVED / ACTIVE / NEXT / KEYSTONE / MYTHIC / ALTERNATE PATHS). The
// active node (the one the user is currently chasing) is centered,
// oversized, and pulses with a purple glow. Dashed lines connect
// consecutive hexes top-to-bottom.
//
// Tapping any hex opens `SkillNodeDetailSheet` as a sheet over the
// staircase — the staircase is never popped/dismissed by a tap. A
// top-bar `[full tree]` button presents the existing `ClusterDetailView`
// (hex-grid) as a secondary "full tree" sheet.

struct ClusterStaircaseView: View {
    let cluster: SkillCluster
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedNode: SkillNode?
    @State private var showFullTree: Bool = false
    @State private var activePulse: CGFloat = 1.0

    // Reused everywhere — compute once per body pass.
    private var clusterNodes: [SkillNode] {
        graph.nodes(in: cluster)
    }

    private var sections: StaircaseSections {
        buildSections()
    }

    // Screen metrics for zig-zag math — approximated, clamped in layout
    // math so we don't blow up on tiny widths.
    private let horizontalInset: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        summaryBlock
                            .padding(.horizontal, horizontalInset)

                        if !sections.achieved.isEmpty {
                            staircaseSection(
                                label: "ACHIEVED",
                                nodes: sections.achieved,
                                widthFraction: 0.6,
                                sizeKind: .far
                            )
                        }

                        // Active section is always rendered (even if cluster
                        // is fully complete, we surface the keystone as the
                        // active anchor — see buildSections()).
                        activeSection
                            .id("active-anchor")

                        if !sections.next.isEmpty {
                            staircaseSection(
                                label: "NEXT",
                                nodes: sections.next,
                                widthFraction: 0.8,
                                sizeKind: .adjacent
                            )
                        }

                        if let keystone = sections.keystone,
                           keystone.id != sections.active?.id {
                            keystoneSection(keystone)
                        }

                        if !sections.mythic.isEmpty {
                            staircaseSection(
                                label: "MYTHIC",
                                nodes: sections.mythic,
                                widthFraction: 0.7,
                                sizeKind: .mythic
                            )
                        }

                        if !sections.alternatePaths.isEmpty {
                            alternatePathsSection(sections.alternatePaths)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    // Slight delay so ScrollView is laid out before we jump.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            proxy.scrollTo("active-anchor", anchor: .center)
                        }
                    }
                    // Kick off the pulse animation on the active hex.
                    withAnimation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        activePulse = 1.05
                    }
                }
            }
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

    // MARK: - Summary (progress + keystone)

    private var summaryBlock: some View {
        let unlocked = clusterNodes.filter { isUnlocked(nodeStates[$0.id] ?? .locked) }.count
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
        .padding(.top, 4)
    }

    // MARK: - Staircase (generic zig-zag column)

    private func staircaseSection(
        label: String,
        nodes: [SkillNode],
        widthFraction: CGFloat,
        sizeKind: HexSizeKind
    ) -> some View {
        VStack(spacing: 14) {
            sectionDivider(label)
            staircaseColumn(nodes: nodes, widthFraction: widthFraction, sizeKind: sizeKind)
        }
    }

    @ViewBuilder
    private func staircaseColumn(
        nodes: [SkillNode],
        widthFraction: CGFloat,
        sizeKind: HexSizeKind
    ) -> some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let bandWidth = fullWidth * widthFraction
            let leftAnchor = (fullWidth - bandWidth) / 2
            let rightAnchor = leftAnchor + bandWidth - sizeKind.size

            ZStack(alignment: .topLeading) {
                // Connecting dashed line layer (between consecutive hexes).
                connectingLines(
                    nodes: nodes,
                    leftAnchor: leftAnchor,
                    rightAnchor: rightAnchor,
                    sizeKind: sizeKind
                )

                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                    let isLeft = (idx % 2 == 0)
                    let x = isLeft ? leftAnchor : rightAnchor
                    let y = CGFloat(idx) * (sizeKind.size + sizeKind.verticalGap)
                    hexCell(node: node, sizeKind: sizeKind)
                        .offset(x: x, y: y)
                }
            }
            .frame(
                width: fullWidth,
                height: CGFloat(max(0, nodes.count)) * sizeKind.size
                    + CGFloat(max(0, nodes.count - 1)) * sizeKind.verticalGap
                    + 20,
                alignment: .topLeading
            )
        }
        .frame(
            height: CGFloat(max(0, nodes.count)) * sizeKind.size
                + CGFloat(max(0, nodes.count - 1)) * sizeKind.verticalGap
                + 20
        )
    }

    private func connectingLines(
        nodes: [SkillNode],
        leftAnchor: CGFloat,
        rightAnchor: CGFloat,
        sizeKind: HexSizeKind
    ) -> some View {
        Canvas { ctx, size in
            guard nodes.count >= 2 else { return }
            for idx in 0..<(nodes.count - 1) {
                let isLeft = (idx % 2 == 0)
                let nextIsLeft = ((idx + 1) % 2 == 0)
                let fromX = (isLeft ? leftAnchor : rightAnchor) + sizeKind.size / 2
                let toX = (nextIsLeft ? leftAnchor : rightAnchor) + sizeKind.size / 2
                let fromY = CGFloat(idx) * (sizeKind.size + sizeKind.verticalGap) + sizeKind.size
                let toY = CGFloat(idx + 1) * (sizeKind.size + sizeKind.verticalGap)

                var path = Path()
                path.move(to: CGPoint(x: fromX, y: fromY))
                // Gentle cubic curve so the line feels organic but never loops.
                let midY = (fromY + toY) / 2
                path.addCurve(
                    to: CGPoint(x: toX, y: toY),
                    control1: CGPoint(x: fromX, y: midY),
                    control2: CGPoint(x: toX, y: midY)
                )

                let node = nodes[idx]
                let prevState = nodeStates[node.id] ?? .locked
                let reached = prevState == .achieved || prevState == .mastered
                ctx.stroke(
                    path,
                    with: .color(reached
                                 ? Color.unbound.accent.opacity(0.5)
                                 : Color.unbound.border),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: reached ? [] : [4, 6]
                    )
                )
            }
        }
    }

    // MARK: - Active section

    @ViewBuilder
    private var activeSection: some View {
        VStack(spacing: 14) {
            sectionDivider("ACTIVE")
            if let active = sections.active {
                VStack(spacing: 12) {
                    hexCell(node: active, sizeKind: .active, pulses: true)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            selectedNode = active
                        }
                    Button {
                        UnboundHaptics.medium()
                        selectedNode = active
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("LOG SESSION")
                                .font(Font.unbound.captionS.weight(.heavy))
                                .tracking(1.6)
                        }
                        .foregroundStyle(Color.unbound.bg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.unbound.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
            } else {
                // Fallback — shouldn't happen because buildSections() always
                // fills this slot, but stay defensive.
                Text("Cluster complete.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    // MARK: - Keystone section

    private func keystoneSection(_ node: SkillNode) -> some View {
        VStack(spacing: 14) {
            sectionDivider("KEYSTONE")
            VStack(spacing: 8) {
                hexCell(node: node, sizeKind: .keystone)
                    .onTapGesture {
                        UnboundHaptics.medium()
                        selectedNode = node
                    }
                Text("THE CLUSTER'S GATE")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Alternate paths

    private func alternatePathsSection(_ nodes: [SkillNode]) -> some View {
        VStack(spacing: 14) {
            sectionDivider("ALTERNATE PATHS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(nodes, id: \.id) { n in
                        hexCell(node: n, sizeKind: .alternate)
                            .onTapGesture {
                                UnboundHaptics.medium()
                                selectedNode = n
                            }
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
        }
    }

    // MARK: - Hex cell (shared rendering)

    private enum HexSizeKind {
        case far        // dim achieved nodes
        case adjacent   // next-up nodes
        case active     // current node
        case keystone   // cluster gate
        case mythic     // post-keystone bosses
        case alternate  // compact branch row

        var size: CGFloat {
            switch self {
            case .far:        return 90
            case .adjacent:   return 110
            case .active:     return 140
            case .keystone:   return 150
            case .mythic:     return 100
            case .alternate:  return 80
            }
        }

        var verticalGap: CGFloat {
            switch self {
            case .far:        return 22
            case .adjacent:   return 28
            case .mythic:     return 24
            case .alternate:  return 18
            case .active, .keystone: return 24
            }
        }
    }

    @ViewBuilder
    private func hexCell(node: SkillNode, sizeKind: HexSizeKind, pulses: Bool = false) -> some View {
        let state = nodeStates[node.id] ?? .locked
        let size = sizeKind.size

        VStack(spacing: 8) {
            ZStack {
                Hexagon().fill(fillColor(for: node, state: state, kind: sizeKind))
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(
                        borderColor(for: node, state: state, kind: sizeKind),
                        lineWidth: strokeWidth(for: node, state: state, kind: sizeKind)
                    )
                    .frame(width: size, height: size)
                if sizeKind == .active && state != .locked {
                    Hexagon()
                        .strokeBorder(Color.unbound.accent.opacity(0.7), lineWidth: 1)
                        .frame(width: size + 14, height: size + 14)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 15)
                }
                if sizeKind == .keystone {
                    Hexagon()
                        .strokeBorder(
                            state == .locked
                                ? Color.unbound.accent.opacity(0.35)
                                : Color.unbound.accent.opacity(0.8),
                            lineWidth: 1
                        )
                        .frame(width: size + 16, height: size + 16)
                        .shadow(
                            color: state == .locked
                                ? .clear
                                : Color.unbound.accent.opacity(0.5),
                            radius: state == .locked ? 0 : 12
                        )
                }
                if sizeKind == .mythic {
                    Hexagon()
                        .strokeBorder(Color.unbound.impact, lineWidth: 1.5)
                        .frame(width: size + 14, height: size + 14)
                        .opacity(state == .locked ? 0.35 : 0.9)
                }
                glyphView(for: node, state: state, kind: sizeKind)
            }
            .shadow(
                color: glowColor(for: node, state: state, kind: sizeKind),
                radius: state == .locked ? 0 : (sizeKind == .active ? 18 : 10)
            )
            .scaleEffect(pulses ? activePulse : 1.0)

            Text(node.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(
                    state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: max(100, size + 10))

            if sizeKind == .keystone {
                Text("KEYSTONE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.accent)
            } else if sizeKind == .mythic {
                Text("MYTHIC")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.impact)
            }
        }
        .frame(width: size)
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    private func fillColor(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> Color {
        switch state {
        case .locked:
            return Color.unbound.surface
        case .attempting:
            return Color.unbound.accent.opacity(kind == .active ? 0.22 : 0.14)
        case .achieved:
            return Color.unbound.accent.opacity(kind == .far ? 0.1 : 0.18)
        case .mastered:
            return Color.unbound.impact.opacity(kind == .far ? 0.14 : 0.22)
        }
    }

    private func borderColor(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> Color {
        if node.isMythic && state == .locked { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .locked:
            return kind == .far ? Color.unbound.border.opacity(0.7) : Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent.opacity(kind == .far ? 0.7 : 1.0)
        case .mastered:   return Color.unbound.impact
        }
    }

    private func strokeWidth(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> CGFloat {
        switch kind {
        case .active:   return 2
        case .keystone: return 2
        case .mythic:   return 1.5
        default:
            switch state {
            case .locked:     return 1
            case .attempting: return 1.5
            case .achieved:   return 1.5
            case .mastered:   return 2
            }
        }
    }

    private func glowColor(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> Color {
        if state == .locked { return .clear }
        if kind == .active { return Color.unbound.accent.opacity(0.7) }
        if kind == .keystone { return Color.unbound.accent.opacity(0.5) }
        if kind == .mythic { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(kind == .far ? 0.25 : 0.45)
        case .mastered:   return Color.unbound.impact.opacity(0.55)
        case .locked:     return .clear
        }
    }

    private func baseFontSize(for kind: HexSizeKind) -> CGFloat {
        switch kind {
        case .active:    return 32
        case .keystone:  return 32
        case .far:       return 20
        case .alternate: return 18
        case .adjacent:  return 24
        case .mythic:    return 24
        }
    }

    @ViewBuilder
    private func glyphView(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> some View {
        let baseFont = baseFontSize(for: kind)
        switch state {
        case .locked:
            Image(systemName: kind == .keystone ? "crown" : "lock.fill")
                .font(.system(size: baseFont - 4, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            Image(systemName: node.glyph)
                .font(.system(size: baseFont, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        case .achieved:
            Image(systemName: kind == .keystone ? "crown.fill" : "checkmark")
                .font(.system(size: baseFont, weight: .bold))
                .foregroundStyle(Color.unbound.accent)
        case .mastered:
            Image(systemName: "crown.fill")
                .font(.system(size: baseFont, weight: .semibold))
                .foregroundStyle(Color.unbound.impact)
        }
    }

    // MARK: - Section algorithm

    private struct StaircaseSections {
        var achieved: [SkillNode]
        var active: SkillNode?
        var next: [SkillNode]
        var keystone: SkillNode?
        var mythic: [SkillNode]
        var alternatePaths: [SkillNode]
    }

    private func buildSections() -> StaircaseSections {
        let nodes = clusterNodes
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let tiers = computeEffectiveTiers(nodes: nodes)

        func state(_ n: SkillNode) -> NodeState { nodeStates[n.id] ?? .locked }
        func isUnlockedState(_ s: NodeState) -> Bool { s == .achieved || s == .mastered }

        // Keystone (after data fix, single node per cluster)
        let keystone = nodes.first { $0.isKeystone && !$0.isMythic }
        let mythicNodes = nodes.filter { $0.isMythic }

        // Active = first attempting, else first locked-but-unlockable (lowest
        // effective tier), else the keystone as a fallback.
        let attempting = nodes.filter { state($0) == .attempting }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        var activeNode: SkillNode? = attempting.first

        if activeNode == nil {
            let unlockables = nodes
                .filter { state($0) == .locked }
                .filter { node in
                    let withinClusterPrereqIds = node.prereqs
                        .flatMap { $0.nodeIds }
                        .filter { nodeById[$0] != nil }
                    guard !withinClusterPrereqIds.isEmpty || node.prereqs.isEmpty else {
                        // Node has prereqs but all are cross-cluster — treat as unlockable.
                        return true
                    }
                    guard !node.prereqs.isEmpty else { return true }
                    // Any group fully satisfied → unlockable
                    return node.prereqs.contains { group in
                        group.nodeIds.allSatisfy { pid in
                            guard let prereq = nodeById[pid] else {
                                // Cross-cluster — assume satisfied for purposes of
                                // choosing the staircase's active node. We surface
                                // cross-cluster gates via ClusterDetailView callouts.
                                return true
                            }
                            return isUnlockedState(state(prereq))
                        }
                    }
                }
                .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
            activeNode = unlockables.first
        }

        if activeNode == nil {
            // Cluster effectively complete — use keystone as the anchor.
            activeNode = keystone
        }

        // Achieved: everything unlocked except the current active. Sorted by
        // effective tier top-down so older wins sit at the top of the staircase.
        let achieved: [SkillNode] = nodes
            .filter { isUnlockedState(state($0)) && $0.id != activeNode?.id }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        // Primary path from active → keystone. Each step pick the child with the
        // most descendants (the "main line"). Collect up to 3 nodes.
        var nextPath: [SkillNode] = []
        if let active = activeNode, let keystoneId = keystone?.id, active.id != keystoneId {
            // Build child map within cluster.
            var childMap: [String: [String]] = [:]
            for n in nodes {
                let prereqIds = n.prereqs.flatMap { $0.nodeIds }
                for pid in prereqIds where nodeById[pid] != nil {
                    childMap[pid, default: []].append(n.id)
                }
            }
            // Memoized descendant count for ranking.
            var descendantCache: [String: Int] = [:]
            func descendants(_ id: String, seen: inout Set<String>) -> Int {
                if let c = descendantCache[id] { return c }
                if seen.contains(id) { return 0 }
                seen.insert(id)
                let kids = childMap[id] ?? []
                var total = 0
                for k in kids {
                    total += 1 + descendants(k, seen: &seen)
                }
                descendantCache[id] = total
                return total
            }

            var currentId = active.id
            var guardCounter = 0
            while currentId != keystoneId && nextPath.count < 3 && guardCounter < nodes.count {
                guardCounter += 1
                let kids = (childMap[currentId] ?? [])
                    .compactMap { nodeById[$0] }
                    .filter { !isUnlockedState(state($0)) && $0.id != activeNode?.id }
                guard !kids.isEmpty else { break }
                // Prefer the child that leads toward keystone: most descendants,
                // tie-break by lower effective tier.
                let ranked = kids.sorted { a, b in
                    var sa = Set<String>()
                    var sb = Set<String>()
                    let da = descendants(a.id, seen: &sa)
                    let db = descendants(b.id, seen: &sb)
                    if da != db { return da > db }
                    return (tiers[a.id] ?? a.tier) < (tiers[b.id] ?? b.tier)
                }
                guard let pick = ranked.first else { break }
                nextPath.append(pick)
                currentId = pick.id
            }
        }

        // Alternate paths: every locked, non-mythic, non-keystone node that
        // isn't already surfaced in active/next.
        let shown: Set<String> = {
            var s = Set<String>()
            if let a = activeNode { s.insert(a.id) }
            if let k = keystone { s.insert(k.id) }
            nextPath.forEach { s.insert($0.id) }
            mythicNodes.forEach { s.insert($0.id) }
            achieved.forEach { s.insert($0.id) }
            return s
        }()

        let alternate = nodes
            .filter { !shown.contains($0.id) }
            .filter { !$0.isMythic && !$0.isKeystone }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        // Mythic only renders if keystone achieved/mastered.
        let keystoneUnlocked = keystone.map { isUnlockedState(state($0)) } ?? false
        let mythicToShow = keystoneUnlocked ? mythicNodes : []

        return StaircaseSections(
            achieved: achieved,
            active: activeNode,
            next: nextPath,
            keystone: keystone,
            mythic: mythicToShow,
            alternatePaths: alternate
        )
    }

    // MARK: - Effective tier (same algorithm as ClusterDetailView)

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

    private func isUnlocked(_ s: NodeState) -> Bool {
        s == .achieved || s == .mastered
    }
}
