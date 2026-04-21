import SwiftUI

// MARK: - ClusterStaircaseView
//
// Primary cluster-detail view. Replaces the hex-grid `ClusterDetailView`
// as the default way a cluster's progression is presented.
//
// Shape: a tight vertical column that surfaces all currently-unblocked
// nodes as parallel lane cards. Instead of picking ONE node as "active"
// and cramming the rest into a NEXT column, every node that is either
// `.attempting` or `.locked` with prereqs satisfied shows up as its own
// LaneCard. Up to 3 visible; overflow lives behind an expand chip.
//
// Below the lanes: a compact keystone pill, mythic row (gated on keystone
// achieved), and finally dead-end tangent branches under OTHER DIRECTIONS.
//
// Tapping any hex/lane opens `SkillNodeDetailSheet` as a sheet over the
// staircase — the staircase is never popped/dismissed by a tap. A
// top-bar `[FULL TREE]` button presents the existing `ClusterDetailView`
// (hex-grid) as a secondary "full tree" sheet.

struct ClusterStaircaseView: View {
    let cluster: SkillCluster
    let graph: SkillGraph
    let nodeStates: [String: NodeState]
    var nodeProgress: [String: Double] = [:]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedNode: SkillNode?
    @State private var showFullTree: Bool = false
    @State private var showExtraLanes: Bool = false

    // Reused everywhere — compute once per body pass.
    private var clusterNodes: [SkillNode] {
        graph.nodes(in: cluster)
    }

    private var sections: StaircaseSections {
        buildSections()
    }

    private var keystoneIsAchieved: Bool {
        guard let k = sections.keystone else { return false }
        let s = nodeStates[k.id] ?? .locked
        return s == .achieved || s == .mastered
    }

    private let horizontalInset: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    summaryBlock
                        .padding(.horizontal, horizontalInset)

                    // WORKING ON — parallel lanes for every currently-unblocked node
                    if !sections.lanes.isEmpty {
                        sectionDivider("WORKING ON")
                        VStack(spacing: 14) {
                            ForEach(sections.lanes) { node in
                                LaneCard(
                                    node: node,
                                    state: nodeStates[node.id] ?? .locked,
                                    downstream: firstDownstreamNode(of: node),
                                    onTap: { selectedNode = node }
                                )
                            }
                            if !sections.extraLanes.isEmpty || showExtraLanes {
                                if showExtraLanes {
                                    ForEach(sections.extraLanes) { node in
                                        LaneCard(
                                            node: node,
                                            state: nodeStates[node.id] ?? .locked,
                                            downstream: firstDownstreamNode(of: node),
                                            onTap: { selectedNode = node }
                                        )
                                    }
                                }
                                if !sections.extraLanes.isEmpty {
                                    extraLanesChip(count: sections.extraLanes.count)
                                }
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                    }

                    // KEYSTONE — compact pill (unless lane-complete cluster)
                    if let keystone = sections.keystone,
                       !(sections.lanes.contains(where: { $0.id == keystone.id })) {
                        sectionDivider("KEYSTONE")
                        keystonePill(keystone, beatsAway: beatsToKeystone(from: sections.lanes))
                    }

                    // MYTHIC — only once keystone is achieved/mastered
                    if !sections.mythic.isEmpty && keystoneIsAchieved {
                        sectionDivider("MYTHIC")
                        mythicRow(sections.mythic)
                    }

                    // OTHER DIRECTIONS — dead-end tangent branches
                    if !sections.alternatePaths.isEmpty {
                        sectionDivider("OTHER DIRECTIONS")
                        alternatePathsRow(sections.alternatePaths)
                    }
                }
                .padding(.vertical, 14)
                .padding(.bottom, 40)
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
    }

    // MARK: - Extra lanes expand chip

    private func extraLanesChip(count: Int) -> some View {
        Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.2)) {
                showExtraLanes.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showExtraLanes ? "chevron.up" : "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(showExtraLanes
                     ? "HIDE EXTRA CHOICES"
                     : "+ \(count) MORE \(count == 1 ? "CHOICE" : "CHOICES")")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.unbound.surface))
            .overlay(
                Capsule().strokeBorder(Color.unbound.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Keystone (compact pill form)

    private func keystonePill(_ node: SkillNode, beatsAway: Int) -> some View {
        let beats = max(1, beatsAway)
        return Button {
            UnboundHaptics.medium()
            selectedNode = node
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Hexagon()
                        .fill(Color.unbound.surface)
                        .frame(width: 60, height: 60)
                    Hexagon()
                        .strokeBorder(Color.unbound.accent.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                    Image(systemName: "crown")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.unbound.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("KEYSTONE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(Color.unbound.accent)
                    }
                    Text(node.title)
                        .font(Font.unbound.bodyS.weight(.semibold))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                    Text("\(beats) \(beats == 1 ? "beat" : "beats") away")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, horizontalInset)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mythic row (post-keystone)

    private func mythicRow(_ nodes: [SkillNode]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(nodes, id: \.id) { n in
                    hexCell(node: n, sizeKind: .mythic)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            selectedNode = n
                        }
                }
            }
            .padding(.horizontal, horizontalInset)
        }
    }

    // MARK: - Alternate paths row

    private func alternatePathsRow(_ nodes: [SkillNode]) -> some View {
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

    // MARK: - Downstream teaser

    /// First within-cluster node whose prereqs reference `node`. nil if leaf.
    private func firstDownstreamNode(of node: SkillNode) -> SkillNode? {
        clusterNodes
            .filter { candidate in
                candidate.id != node.id &&
                candidate.prereqs.contains { $0.nodeIds.contains(node.id) }
            }
            .sorted { $0.tier < $1.tier }
            .first
    }

    // MARK: - Beats-to-keystone

    private func beatsToKeystone(from lanes: [SkillNode]) -> Int {
        guard let keystone = sections.keystone else { return 0 }
        let tiers = computeEffectiveTiers(nodes: clusterNodes)
        let keystoneTier = tiers[keystone.id] ?? keystone.tier
        let lowestLaneTier = lanes
            .compactMap { tiers[$0.id] ?? $0.tier }
            .min() ?? keystoneTier
        return max(0, keystoneTier - lowestLaneTier)
    }

    // MARK: - Hex cell (shared rendering for keystone / mythic / alternate)

    private enum HexSizeKind {
        case mythic
        case alternate

        var size: CGFloat {
            switch self {
            case .mythic:    return 90
            case .alternate: return 72
            }
        }
    }

    @ViewBuilder
    private func hexCell(node: SkillNode, sizeKind: HexSizeKind) -> some View {
        let state = nodeStates[node.id] ?? .locked
        let size = sizeKind.size

        VStack(spacing: 6) {
            ZStack {
                Hexagon()
                    .fill(fillColor(for: node, state: state, kind: sizeKind))
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(
                        borderColor(for: node, state: state, kind: sizeKind),
                        lineWidth: strokeWidth(for: node, state: state, kind: sizeKind)
                    )
                    .frame(width: size, height: size)
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
                radius: state == .locked ? 0 : 10
            )

            Text(node.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(
                    state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: max(100, size + 10))

            if sizeKind == .mythic {
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
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.accent.opacity(0.14)
        case .achieved:   return Color.unbound.accent.opacity(0.18)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    private func borderColor(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> Color {
        if node.isMythic && state == .locked { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .locked:     return Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent
        case .mastered:   return Color.unbound.impact
        }
    }

    private func strokeWidth(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> CGFloat {
        if kind == .mythic { return 1.5 }
        switch state {
        case .locked:     return 1
        case .attempting: return 1.5
        case .achieved:   return 1.5
        case .mastered:   return 2
        }
    }

    private func glowColor(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> Color {
        if state == .locked { return .clear }
        if kind == .mythic { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(0.45)
        case .mastered:   return Color.unbound.impact.opacity(0.55)
        case .locked:     return .clear
        }
    }

    @ViewBuilder
    private func glyphView(for node: SkillNode, state: NodeState, kind: HexSizeKind) -> some View {
        let baseFont: CGFloat = (kind == .mythic ? 22 : 18)
        switch state {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: baseFont - 4, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .attempting:
            Image(systemName: node.glyph)
                .font(.system(size: baseFont, weight: .semibold))
                .foregroundStyle(Color.unbound.accent)
        case .achieved:
            Image(systemName: "checkmark")
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
        var lanes: [SkillNode]           // up to 3 visible unblocked nodes
        var extraLanes: [SkillNode]      // overflow under "+ N MORE CHOICES"
        var keystone: SkillNode?
        var mythic: [SkillNode]
        var alternatePaths: [SkillNode]
    }

    /// Reverse BFS from the keystone walking backward through prereqs.
    /// Produces every node that eventually feeds into the keystone
    /// (excluding cross-cluster prereqs — we only walk within this cluster).
    /// The returned set INCLUDES the keystone id itself.
    private func keystoneAncestors(keystone: SkillNode) -> Set<String> {
        var ancestors: Set<String> = [keystone.id]
        var queue: [String] = [keystone.id]
        while let currentId = queue.popLast() {
            guard let node = clusterNodes.first(where: { $0.id == currentId }) else { continue }
            let prereqIds = node.prereqs.flatMap { $0.nodeIds }
            for prereqId in prereqIds {
                if clusterNodes.contains(where: { $0.id == prereqId }) && !ancestors.contains(prereqId) {
                    ancestors.insert(prereqId)
                    queue.append(prereqId)
                }
            }
        }
        return ancestors
    }

    private func buildSections() -> StaircaseSections {
        let nodes = clusterNodes
        let tiers = computeEffectiveTiers(nodes: nodes)

        func stateOf(_ n: SkillNode) -> NodeState { nodeStates[n.id] ?? .locked }
        func isUnlockedState(_ s: NodeState) -> Bool { s == .achieved || s == .mastered }

        let keystone = nodes.first { $0.isKeystone && !$0.isMythic }
        let mythicNodes = nodes.filter { $0.isMythic }

        let ancestorSet: Set<String> = {
            if let k = keystone { return keystoneAncestors(keystone: k) }
            return Set(nodes.map(\.id))
        }()

        // Lane candidates: every non-keystone, non-mythic node that is either
        // currently being attempted, or locked with prereqs already satisfied.
        let laneCandidates = nodes
            .filter { !$0.isMythic }
            .filter { $0.id != keystone?.id }
            .filter { node in
                let s = stateOf(node)
                if s == .attempting { return true }
                if s == .locked && node.prereqsSatisfied(given: nodeStates) { return true }
                return false
            }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        let visibleCap = 3
        let lanes = Array(laneCandidates.prefix(visibleCap))
        let extraLanes = Array(laneCandidates.dropFirst(visibleCap))

        // If the keystone itself is currently unblocked, include it among the
        // lanes so the user can actually log against it. We put it LAST since
        // it's always the highest-tier target.
        var lanesWithKeystone = lanes
        var keystoneForPill: SkillNode? = keystone
        if let k = keystone {
            let ks = stateOf(k)
            let keystoneUnblocked = ks == .attempting || (ks == .locked && k.prereqsSatisfied(given: nodeStates))
            if keystoneUnblocked && !lanesWithKeystone.contains(where: { $0.id == k.id }) {
                lanesWithKeystone.append(k)
                keystoneForPill = nil // already rendered as lane; don't double up
            }
            // If keystone already achieved/mastered, the pill is redundant too.
            if isUnlockedState(ks) { keystoneForPill = nil }
        }

        // Alternate paths = nodes NOT in the keystone ancestor set, NOT mythic,
        // NOT already a lane, NOT achieved/mastered. Genuine dead-end tangents.
        let laneIds = Set(lanesWithKeystone.map(\.id) + extraLanes.map(\.id))
        let alternate = nodes
            .filter { !ancestorSet.contains($0.id) }
            .filter { !$0.isMythic }
            .filter { !laneIds.contains($0.id) }
            .filter { !isUnlockedState(stateOf($0)) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        return StaircaseSections(
            lanes: lanesWithKeystone,
            extraLanes: extraLanes,
            keystone: keystoneForPill,
            mythic: mythicNodes,
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

// MARK: - LaneCard

private struct LaneCard: View {
    let node: SkillNode
    let state: NodeState
    let downstream: SkillNode?
    let onTap: () -> Void

    var body: some View {
        Button {
            UnboundHaptics.soft()
            onTap()
        } label: {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Hexagon()
                        .fill(hexFillColor)
                        .frame(width: 72, height: 72)
                    Hexagon()
                        .strokeBorder(hexBorderColor, lineWidth: 1.5)
                        .frame(width: 72, height: 72)
                    glyph
                }
                .shadow(color: hexGlowColor, radius: state == .attempting ? 8 : 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text(node.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if !node.subtitle.isEmpty {
                        Text(node.subtitle)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    stateBadge
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("LOG SESSION")
                            .font(Font.unbound.captionS.weight(.heavy))
                            .tracking(1.4)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.unbound.accent)
                    .clipShape(Capsule())
                    .padding(.top, 4)

                    if let downstream {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .semibold))
                            Text("unlocks \(downstream.title)")
                                .font(Font.unbound.captionS)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        state == .attempting
                            ? Color.unbound.accent.opacity(0.5)
                            : Color.unbound.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var hexFillColor: Color {
        switch state {
        case .attempting:          return Color.unbound.accent.opacity(0.18)
        case .achieved, .mastered: return Color.unbound.accent.opacity(0.25)
        case .locked:              return Color.unbound.surfaceElevated
        }
    }

    private var hexBorderColor: Color {
        state == .attempting ? Color.unbound.accent : Color.unbound.border
    }

    private var hexGlowColor: Color {
        state == .attempting ? Color.unbound.accent.opacity(0.5) : .clear
    }

    @ViewBuilder private var glyph: some View {
        Image(systemName: node.glyph)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(state == .locked ? Color.unbound.textSecondary : Color.unbound.accent)
    }

    @ViewBuilder private var stateBadge: some View {
        if state == .attempting {
            Text("◉ WORKING ON")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.accent)
        } else {
            Text("○ READY TO START")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary)
        }
    }
}
