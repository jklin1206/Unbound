import SwiftUI

// MARK: - ClusterStaircaseView
//
// A single, continuous zig-zag chain of hexes reading top-to-bottom from
// the lowest-tier achieved node through the active node, the path ahead,
// and terminating at the keystone. Tangent (off-path) nodes in the same
// cluster are integrated inline at their effective tier in the opposite
// column from the keystone-path node at that tier.
//
// Layout rules (enforced — no centered single nodes):
//   • Two fixed columns at 0.28W (LEFT) and 0.72W (RIGHT).
//   • Row parity assignment: if a row has ONE node, it goes to LEFT on
//     even row indices and RIGHT on odd. Row index is the node's effective
//     tier within the chain, so the zig-zag is stable and globally aware.
//   • If a row has TWO nodes (keystone-path + tangent), the keystone-path
//     node keeps its parity slot and the tangent takes the opposite column.
//   • If a row has THREE+ nodes (rare), fall back to evenly spaced 0.15W
//     → 0.85W fractions.
//
// Rails:
//   • Follow the real prereq graph — each visible node walks
//     `prereqs.flatMap(\.nodeIds)` and draws a rail from each VISIBLE
//     parent. Rails anchor to the flat-top hex's 45°-edge midpoints so
//     the line visually emerges from the diagonal corner.
//   • Gentle bezier, tiered glow (both reached / partial / locked).
//
// Sections below the chain:
//   • MYTHIC — its own zig-zag section, surfaced only when the keystone
//     is achieved or mastered.
//
// Preserved
//   • buildSections() logic (active/keystone/achieved/next/mythic).
//   • Auto-scroll to active node on appear.
//   • Active pulse animation, tap-to-open detail sheet, FULL TREE button.

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

                        mainChain
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

    // MARK: - Main chain (the one true staircase)

    /// Data payload for rendering a row in the chain.
    private struct ChainSlot: Identifiable {
        let id: String        // node id
        let node: SkillNode
        let rowIndex: Int     // y-axis bucket
        let column: Column    // left / right
        let role: Role
        enum Column { case left, right, center, centerFallback(CGFloat) /* 0..1 fraction */ }
        enum Role { case achieved, active, next, keystone, tangent }
    }

    /// Assembles the ordered chain: achieved → active → next → keystone,
    /// with tangents slotted in at their effective tier (opposite column
    /// from the keystone-path node at that tier when present).
    private func buildChainSlots() -> [ChainSlot] {
        let tiers = computeEffectiveTiers(nodes: clusterNodes)

        // Primary (keystone-path + active) ordered list.
        var primary: [(node: SkillNode, role: ChainSlot.Role)] = []
        for n in sections.achieved { primary.append((n, .achieved)) }
        if let a = sections.active { primary.append((a, .active)) }
        for n in sections.next { primary.append((n, .next)) }
        if let k = sections.keystone, !sections.keystoneIsActive {
            primary.append((k, .keystone))
        }

        // Dedup primary in case buildSections overlaps (it shouldn't, but
        // defensive). Preserve the first-seen ordering.
        var seen: Set<String> = []
        primary = primary.filter { seen.insert($0.node.id).inserted }

        // Map primary node → its row index in the rendered chain. Row 0
        // is the top. Rows are normalized to be contiguous so the column
        // parity reads naturally from top to bottom.
        var rowOfPrimary: [String: Int] = [:]
        for (i, entry) in primary.enumerated() {
            rowOfPrimary[entry.node.id] = i
        }

        // Tangents: nodes in the cluster NOT in primary, NOT mythic.
        // Place them at a row that corresponds to their effective tier,
        // mapped into the chain's row space. If no primary occupies that
        // tier, they get their own row appended in tier order.
        let primaryIds = Set(primary.map { $0.node.id })
        let tangents = clusterNodes
            .filter { !$0.isMythic && !primaryIds.contains($0.id) }

        // Primary tier buckets — group primary by effective tier so we
        // can map a tangent's tier to a primary row.
        var primaryByTier: [Int: String] = [:]
        for entry in primary {
            let t = tiers[entry.node.id] ?? entry.node.tier
            // Prefer the first primary seen at that tier (keeps the
            // keystone-path visible as the "anchor" of its row).
            if primaryByTier[t] == nil {
                primaryByTier[t] = entry.node.id
            }
        }

        // Assign tangents to rows. If tangent's tier matches a primary
        // tier, it shares that row. Otherwise, it gets its own new row
        // inserted in sorted-tier position.
        struct TangentAssignment {
            let node: SkillNode
            let tier: Int
            var sharesRowWith: String?  // primary node id
        }
        let tangentAssignments: [TangentAssignment] = tangents
            .map { t in
                let tier = tiers[t.id] ?? t.tier
                return TangentAssignment(
                    node: t,
                    tier: tier,
                    sharesRowWith: primaryByTier[tier]
                )
            }
            .sorted { (a, b) in
                if a.tier != b.tier { return a.tier < b.tier }
                return a.node.id < b.node.id
            }

        // Build the final row list. Start with primary rows in order.
        // Then insert standalone tangent rows (those without a matching
        // primary tier) at positions that preserve tier ordering.
        struct RowSpec {
            var primaryId: String?
            var tier: Int
            var tangents: [SkillNode] = []
        }
        var rows: [RowSpec] = []
        for entry in primary {
            let t = tiers[entry.node.id] ?? entry.node.tier
            rows.append(RowSpec(primaryId: entry.node.id, tier: t))
        }
        for ta in tangentAssignments {
            if let sharedId = ta.sharesRowWith,
               let idx = rows.firstIndex(where: { $0.primaryId == sharedId })
            {
                rows[idx].tangents.append(ta.node)
            } else {
                // Insert a new standalone row at the correct tier position.
                let insertAt = rows.firstIndex(where: { $0.tier > ta.tier })
                    ?? rows.count
                var new = RowSpec(primaryId: nil, tier: ta.tier)
                new.tangents.append(ta.node)
                rows.insert(new, at: insertAt)
            }
        }

        // Walk rows with a fresh contiguous row index and produce slots.
        var slots: [ChainSlot] = []
        for (rowIdx, row) in rows.enumerated() {
            // Primary node for the row (if any): parity slot.
            let parityLeft = (rowIdx % 2 == 0) // row 0 = LEFT, 1 = RIGHT, ...
            let primarySlotLeft = parityLeft
            var usedLeft = false
            var usedRight = false

            if let pid = row.primaryId,
               let entry = primary.first(where: { $0.node.id == pid })
            {
                let col: ChainSlot.Column = primarySlotLeft ? .left : .right
                if primarySlotLeft { usedLeft = true } else { usedRight = true }
                slots.append(ChainSlot(
                    id: pid,
                    node: entry.node,
                    rowIndex: rowIdx,
                    column: col,
                    role: entry.role
                ))
            }

            // Tangents on this row: first tangent takes the OPPOSITE
            // column from the primary (or parity slot if no primary).
            // Additional tangents fall back to an evenly-spaced fraction
            // between 0.15W and 0.85W per the spec, skipping used cols.
            let rowTangents = row.tangents
            if !rowTangents.isEmpty {
                // First tangent — opposite column from primary slot.
                let first = rowTangents[0]
                let firstCol: ChainSlot.Column
                if usedLeft {
                    firstCol = .right; usedRight = true
                } else if usedRight {
                    firstCol = .left;  usedLeft = true
                } else {
                    // No primary; parity puts primary on L, tangent alone
                    // takes parity slot so the chain still zig-zags.
                    firstCol = primarySlotLeft ? .left : .right
                    if primarySlotLeft { usedLeft = true } else { usedRight = true }
                }
                slots.append(ChainSlot(
                    id: first.id,
                    node: first,
                    rowIndex: rowIdx,
                    column: firstCol,
                    role: .tangent
                ))

                // Any further tangents — fall back to 0.15→0.85 fractions.
                if rowTangents.count > 1 {
                    let extras = Array(rowTangents.dropFirst())
                    let count = extras.count
                    let start: CGFloat = 0.15
                    let end: CGFloat = 0.85
                    let step = count == 1 ? 0 : (end - start) / CGFloat(count - 1)
                    for (i, t) in extras.enumerated() {
                        let f = count == 1 ? 0.5 : (start + step * CGFloat(i))
                        slots.append(ChainSlot(
                            id: t.id,
                            node: t,
                            rowIndex: rowIdx,
                            column: .centerFallback(f),
                            role: .tangent
                        ))
                    }
                }
            }
        }

        // Second pass: center "branch parents" whose direct children in the
        // next row occupy BOTH left and right columns. This avoids broken-
        // looking forks where a left-column parent sends an arm back to the
        // left and another diagonally across to the right.
        //
        // Guard: only re-center a node when its row contains exactly one
        // slot (the node itself). If another slot shares the row (e.g. a
        // tangent), keep parity to prevent hex overlap at x = 0.5W.
        //
        // Scope: only direct children in row i+1 count. Grandchildren don't
        // cascade upward — branching has to actually happen at this level.
        let visibleIdsByRow: [Int: Set<String>] = Dictionary(
            grouping: slots, by: { $0.rowIndex }
        ).mapValues { Set($0.map(\.id)) }

        let slotIndexById: [String: Int] = Dictionary(
            uniqueKeysWithValues: slots.enumerated().map { ($1.id, $0) }
        )

        for (i, slot) in slots.enumerated() {
            // Only one-slot rows are eligible.
            let rowMembers = slots.filter { $0.rowIndex == slot.rowIndex }
            guard rowMembers.count == 1 else { continue }

            let nextRow = slot.rowIndex + 1
            guard let nextIds = visibleIdsByRow[nextRow] else { continue }

            // Direct children = nodes in the next row whose prereqs include
            // this slot's node id. Walk the actual prereq graph so a child
            // that happens to sit in the next row by coincidence (but isn't
            // this node's child) doesn't count.
            let childSlots: [ChainSlot] = slots.filter { candidate in
                guard candidate.rowIndex == nextRow,
                      nextIds.contains(candidate.id) else { return false }
                let parentIds = Set(candidate.node.prereqs.flatMap { $0.nodeIds })
                return parentIds.contains(slot.id)
            }
            guard childSlots.count >= 2 else { continue }

            var hasLeft = false
            var hasRight = false
            for c in childSlots {
                switch c.column {
                case .left:  hasLeft = true
                case .right: hasRight = true
                case .center, .centerFallback: break
                }
            }
            guard hasLeft && hasRight else { continue }

            if let idx = slotIndexById[slot.id] {
                slots[idx] = ChainSlot(
                    id: slot.id,
                    node: slot.node,
                    rowIndex: slot.rowIndex,
                    column: .center,
                    role: slot.role
                )
            }
        }

        return slots
    }

    private var mainChain: some View {
        let slots = buildChainSlots()
        guard !slots.isEmpty else {
            return AnyView(EmptyView())
        }

        let rowCount = (slots.map(\.rowIndex).max() ?? 0) + 1
        let baseSize: CGFloat = 95       // standard adjacent size
        let activeSize: CGFloat = 120
        let keystoneSize: CGFloat = 140

        // Determine the dominant role per row so variable row heights can
        // be allocated (active/keystone rows need more vertical headroom
        // for their stacked title + button/chip below the hex).
        enum RowKind { case base, active, keystone }
        var rowKinds: [RowKind] = Array(repeating: .base, count: rowCount)
        for slot in slots {
            switch slot.role {
            case .active:
                rowKinds[slot.rowIndex] = .active
            case .keystone:
                // keystone wins over base but not active (active+keystone
                // shouldn't co-exist on one row in practice).
                if rowKinds[slot.rowIndex] != .active {
                    rowKinds[slot.rowIndex] = .keystone
                }
            default:
                break
            }
        }
        let rowHeights: [CGFloat] = rowKinds.map { kind in
            switch kind {
            case .base:     return 140
            case .active:   return 180
            case .keystone: return 200
            }
        }
        // Cumulative row-center y: center of row i is sum(heights[0..<i]) + heights[i]/2.
        var rowCenters: [CGFloat] = []
        var running: CGFloat = 0
        for h in rowHeights {
            rowCenters.append(running + h / 2)
            running += h
        }
        let totalHeight: CGFloat = running

        return AnyView(
            GeometryReader { geo in
                let fullWidth = geo.size.width
                let leftX = fullWidth * 0.28
                let rightX = fullWidth * 0.72
                let centerX = fullWidth * 0.5

                let positions: [String: CGPoint] = Dictionary(
                    uniqueKeysWithValues: slots.map { slot in
                        let x: CGFloat
                        switch slot.column {
                        case .left:              x = leftX
                        case .right:             x = rightX
                        case .center:            x = centerX
                        case .centerFallback(let f): x = fullWidth * f
                        }
                        let y = rowCenters[slot.rowIndex]
                        return (slot.id, CGPoint(x: x, y: y))
                    }
                )
                let sizeFor: (ChainSlot) -> CGFloat = { slot in
                    switch slot.role {
                    case .active:   return activeSize
                    case .keystone: return keystoneSize
                    default:        return baseSize
                    }
                }
                let visibleIds = Set(positions.keys)

                ZStack(alignment: .topLeading) {
                    // Rails under the hexes.
                    Canvas { ctx, _ in
                        drawPrereqRails(
                            ctx: ctx,
                            slots: slots,
                            positions: positions,
                            sizeFor: sizeFor,
                            visibleIds: visibleIds
                        )
                    }
                    .frame(width: fullWidth, height: totalHeight)
                    .allowsHitTesting(false)

                    // Render hex + detached label as separate positioned
                    // elements per slot. Label x-center is locked to hex
                    // x-center (same `p.x`) so it never drifts horizontally
                    // regardless of text length.
                    ForEach(slots) { slot in
                        if let p = positions[slot.id] {
                            let s = sizeFor(slot)
                            chainHexCore(slot: slot, size: s)
                                .position(x: p.x, y: p.y)
                                .modifier(ActiveAnchorModifier(isActive: slot.role == .active))

                            chainHexBelow(slot: slot, size: s)
                                .position(x: p.x, y: p.y + s / 2 + belowAnchorOffset(for: slot))
                        }
                    }
                }
                .frame(width: fullWidth, height: totalHeight, alignment: .topLeading)
            }
            .frame(height: totalHeight)
            .padding(.horizontal, 16)
        )
    }

    /// Vertical offset from the hex's bottom edge to the anchor point of
    /// the VStack placed below. We use `.position()` which centers on this
    /// y coordinate, so we need to pick a y that puts the stack's natural
    /// top just below the hex — SwiftUI centers the view on that y, so we
    /// add half the stack's approximate height. For correctness we use
    /// `.topLeading` via an overlaid `alignmentGuide`… simpler: we nudge
    /// by a small gap and let `.frame(width:)` + `.fixedSize()` keep the
    /// stack's own center close enough to the intended top.
    private func belowAnchorOffset(for slot: ChainSlot) -> CGFloat {
        // Position's y is the CENTER of the below-view. We want the below
        // view's TOP to be roughly (hex bottom + 12). So center_y =
        // hex_bottom + 12 + viewHeight/2. We estimate a nominal view
        // height per role:
        switch slot.role {
        case .active:   return 12 + 54  // ~ title(40) + button(28) gap => halfHeight ~54
        case .keystone: return 12 + 34  // title(40) + beats(14) gap => halfHeight ~34
        default:        return 12 + 18  // 2-line caption => halfHeight ~18
        }
    }

    /// Tags the active hex with the `id("active")` anchor used by
    /// auto-scroll, without forcing every hex to own an id.
    private struct ActiveAnchorModifier: ViewModifier {
        let isActive: Bool
        func body(content: Content) -> some View {
            if isActive { content.id("active") } else { content }
        }
    }

    // MARK: - Chain hex core (hex-only, no label) + below-content

    /// The hex itself — positioned at the row center. Labels and buttons
    /// are rendered separately via `chainHexBelow(...)` so they don't drag
    /// the hex horizontally when they grow/wrap.
    @ViewBuilder
    private func chainHexCore(slot: ChainSlot, size: CGFloat) -> some View {
        let node = slot.node
        let state = nodeStates[node.id] ?? .locked

        switch slot.role {
        case .active:
            activeHexOnly(node: node, state: state, size: size)
        case .keystone:
            keystoneHexOnly(node: node, state: state, size: size)
        default:
            defaultHexOnly(node: node, state: state, size: size, role: slot.role)
        }
    }

    /// The content rendered directly below a hex: title (+ LOG SESSION for
    /// active, + BEATS AWAY for keystone). The VStack has a fixed width so
    /// it centers on the hex's x-axis and wraps cleanly.
    @ViewBuilder
    private func chainHexBelow(slot: ChainSlot, size: CGFloat) -> some View {
        let node = slot.node
        let state = nodeStates[node.id] ?? .locked

        switch slot.role {
        case .active:
            activeBelow(node: node)
        case .keystone:
            keystoneBelow(node: node, state: state)
        default:
            defaultBelow(node: node, state: state, role: slot.role)
        }
    }

    // MARK: Hex-only variants

    private func defaultHexOnly(
        node: SkillNode,
        state: NodeState,
        size: CGFloat,
        role: ChainSlot.Role
    ) -> some View {
        let glyphSize: CGFloat = 24
        let fade = role == .achieved ? 0.78 : 1.0
        return ZStack {
            Hexagon()
                .fill(fillColor(state: state, faded: role == .achieved))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(
                    borderColor(node: node, state: state, faded: role == .achieved),
                    lineWidth: strokeWidth(state: state)
                )
                .frame(width: size, height: size)
            glyph(for: node, state: state, fontSize: glyphSize)
        }
        .shadow(color: glowColor(state: state, faded: role == .achieved), radius: state == .locked ? 0 : 10)
        .opacity(fade)
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    private func activeHexOnly(
        node: SkillNode,
        state: NodeState,
        size: CGFloat
    ) -> some View {
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

    private func keystoneHexOnly(
        node: SkillNode,
        state: NodeState,
        size: CGFloat
    ) -> some View {
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

    // MARK: Below-hex content variants

    private func defaultBelow(node: SkillNode, state: NodeState, role: ChainSlot.Role) -> some View {
        Text(node.title)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(
                state == .locked ? Color.unbound.textTertiary : Color.unbound.textPrimary
            )
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 120)
    }

    private func activeBelow(node: SkillNode) -> some View {
        VStack(spacing: 10) {
            Text(node.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 200)

            Button {
                UnboundHaptics.medium()
                selectedNode = node
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("LOG SESSION")
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.6)
                }
                .foregroundStyle(Color.unbound.bg)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 200)
    }

    private func keystoneBelow(node: SkillNode, state: NodeState) -> some View {
        let beatsAway = sections.next.count + 1
        return VStack(spacing: 8) {
            Text(node.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 220)

            Text("\(beatsAway) \(beatsAway == 1 ? "BEAT" : "BEATS") AWAY")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)
        }
        .frame(width: 220)
    }

    private func keystoneFill(state: NodeState) -> Color {
        switch state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.accent.opacity(0.16)
        case .achieved:   return Color.unbound.accent.opacity(0.22)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    // MARK: - Mythic chain (same zig-zag machinery, mythic styling)

    private func mythicChain(nodes: [SkillNode]) -> some View {
        // Build a simple zig-zag by row index (no tier-math — each mythic
        // gets its own row to keep the section readable).
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
                    // Connect consecutive mythic hexes top→down for a
                    // visual thread (mythic nodes rarely have real
                    // prereqs within the mythic subset).
                    for i in 0..<(slots.count - 1) {
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
                    .strokeBorder(
                        Color.unbound.impact,
                        lineWidth: 1.5
                    )
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

    // MARK: - Rails

    /// For each slot, walk actual prereq ids and draw a rail from every
    /// prereq that is also visible in the chain. Rails exit straight down
    /// from the parent's bottom-center and enter straight down into the
    /// child's top-center — see `drawRail(...)` for the step-path geometry.
    private func drawPrereqRails(
        ctx: GraphicsContext,
        slots: [ChainSlot],
        positions: [String: CGPoint],
        sizeFor: (ChainSlot) -> CGFloat,
        visibleIds: Set<String>
    ) {
        // id → slot map for O(1) size lookups.
        let slotById: [String: ChainSlot] = Dictionary(
            uniqueKeysWithValues: slots.map { ($0.id, $0) }
        )

        for child in slots {
            guard let childPt = positions[child.id] else { continue }
            let prereqIds = Set(child.node.prereqs.flatMap { $0.nodeIds })
                .intersection(visibleIds)
            guard !prereqIds.isEmpty else { continue }

            for pid in prereqIds {
                guard let parentSlot = slotById[pid],
                      let parentPt = positions[pid]
                else { continue }
                // Only draw rails top→down.
                guard parentPt.y < childPt.y else { continue }

                drawRail(
                    ctx: ctx,
                    from: parentPt,
                    to: childPt,
                    fromSize: sizeFor(parentSlot),
                    toSize: sizeFor(child),
                    fromReached: isUnlockedState(nodeStates[pid] ?? .locked),
                    toReached: isUnlockedState(nodeStates[child.id] ?? .locked),
                    tint: Color.unbound.accent
                )
            }
        }
    }

    /// Draws an orthogonal "step" rail between two hexes, reading as an
    /// intentional tree diagram. Anchors at the parent's bottom-center and
    /// the child's top-center so every rail enters and exits straight down.
    ///
    /// Path shape:
    ///   • Same column (|dx| ≤ tolerance): single vertical line start → end.
    ///   • Different columns: down-stub → horizontal crossbar at midY →
    ///     down-stub. Two bends, each rounded with a small arc so the
    ///     corners read as crisp but not pixel-sharp.
    ///
    /// Each hex's OWN size drives its anchor so a larger active hex (S=120)
    /// or keystone (S=140) still exits/enters cleanly from its own edge.
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
            // Same column — single clean vertical line.
            path.move(to: start)
            path.addLine(to: end)
        } else {
            // Step path: down, across, down. Round the two bends.
            let midY = (start.y + end.y) / 2
            let cornerRadius: CGFloat = 8

            // Clamp the corner radius to the available stub / crossbar
            // lengths so small spacings don't overshoot.
            let vStub1 = midY - start.y
            let vStub2 = end.y - midY
            let hSpan  = abs(end.x - start.x)
            let r = max(0, min(cornerRadius, min(vStub1, vStub2, hSpan / 2)))

            let goingRight = end.x > start.x
            let bend1 = CGPoint(x: start.x, y: midY)
            let bend2 = CGPoint(x: end.x,   y: midY)

            path.move(to: start)
            if r > 0 {
                // Vertical down to just above bend1.
                path.addLine(to: CGPoint(x: start.x, y: midY - r))
                // Arc around bend1 into the horizontal segment.
                let afterBend1X = start.x + (goingRight ? r : -r)
                path.addQuadCurve(
                    to: CGPoint(x: afterBend1X, y: midY),
                    control: bend1
                )
                // Horizontal across to just before bend2.
                let beforeBend2X = end.x + (goingRight ? -r : r)
                path.addLine(to: CGPoint(x: beforeBend2X, y: midY))
                // Arc around bend2 into the second vertical.
                path.addQuadCurve(
                    to: CGPoint(x: end.x, y: midY + r),
                    control: bend2
                )
                // Vertical down into child top-center.
                path.addLine(to: end)
            } else {
                // Fallback: sharp bends when spacing is too tight to round.
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

    // MARK: - Section algorithm

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

        // ACHIEVED: all non-keystone, non-mythic achieved/mastered, sorted
        // by effective tier ascending. Keep the last 2 visible so the
        // chain doesn't bloat with every historical win.
        let achievedAll = nodes
            .filter { !$0.isMythic && $0.id != keystone?.id }
            .filter { isUnlockedState(state($0)) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        let achieved = Array(achievedAll.suffix(2))

        // ACTIVE: first attempting → else lowest-tier unlockable locked →
        // else keystone fallback.
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

    /// Reverse BFS from the keystone walking backward through prereqs.
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
