import SwiftUI

// MARK: - ClusterStaircaseView
//
// Section-based vertical staircase. Each cluster is presented as a tight
// column of labelled sections — ACHIEVED, ACTIVE, NEXT, KEYSTONE, MYTHIC,
// OTHER DIRECTIONS — with hexes explicitly zig-zagged left/right and
// connected by glowing purple bezier rails.
//
// Sections
//   • ACHIEVED        — up to last 2 non-keystone achieved/mastered nodes
//   • ACTIVE          — single "do this now" hex (big, pulsing) + LOG SESSION
//   • NEXT            — up to 4 upcoming unlockables, zig-zag'd
//   • KEYSTONE        — big hex + "N beats away" label
//   • MYTHIC          — only surfaced once the keystone is achieved
//   • OTHER DIRECTIONS — horizontal scrollable row of true dead-end tangents
//
// Each multi-node section lives in a GeometryReader-sized ZStack: hexes
// are placed at alternating left/right x anchors and a Canvas underlay
// draws quadratic-bezier rails between consecutive hexes. Rails go solid
// + blurred when both endpoints are achieved, solid when only the source
// is, and dashed-dim otherwise.
//
// Integrations preserved
//   • Tap any hex → `SkillNodeDetailSheet` via `.sheet(item:)`
//   • `[FULL TREE]` → `ClusterDetailView` via `.sheet(isPresented:)`
//   • Auto-scroll to the ACTIVE node on first appear (ScrollViewReader)
//   • Back button pops the staircase

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

                        if !sections.achieved.isEmpty {
                            sectionDivider("ACHIEVED")
                                .padding(.top, 28)
                            zigzagColumn(
                                nodes: sections.achieved,
                                sizeKind: .far
                            )
                            .padding(.top, 36)
                        }

                        if let active = sections.active {
                            sectionDivider("ACTIVE")
                                .padding(.top, 32)
                            activeHex(node: active)
                                .padding(.top, 36)
                                .id("active")
                            logSessionButton(for: active)
                                .padding(.top, 14)
                        }

                        if !sections.next.isEmpty {
                            sectionDivider("NEXT")
                                .padding(.top, 32)
                            zigzagColumn(
                                nodes: sections.next,
                                sizeKind: .adjacent
                            )
                            .padding(.top, 36)
                        }

                        if let keystone = sections.keystone,
                           !sections.keystoneIsActive
                        {
                            sectionDivider("KEYSTONE")
                                .padding(.top, 32)
                            keystoneHex(keystone)
                                .padding(.top, 36)
                        }

                        if !sections.mythic.isEmpty {
                            sectionDivider("MYTHIC")
                                .padding(.top, 32)
                            zigzagColumn(
                                nodes: sections.mythic,
                                sizeKind: .mythic
                            )
                            .padding(.top, 36)
                        }

                        if !sections.other.isEmpty {
                            sectionDivider("OTHER DIRECTIONS")
                                .padding(.top, 32)
                            otherRow(sections.other)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
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

    // MARK: - Active hex (big, pulsing) + LOG SESSION CTA

    private func activeHex(node: SkillNode) -> some View {
        let state = nodeStates[node.id] ?? .locked
        let size: CGFloat = 140
        return VStack(spacing: 10) {
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
                glyph(for: node, state: state, fontSize: 44)
            }
            .scaleEffect(activePulse)
            .shadow(color: Color.unbound.accent.opacity(0.55), radius: 20)
            .onTapGesture {
                UnboundHaptics.medium()
                selectedNode = node
            }

            Text(node.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
    }

    private func logSessionButton(for node: SkillNode) -> some View {
        Button {
            UnboundHaptics.medium()
            selectedNode = node
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("LOG SESSION")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.6)
            }
            .foregroundStyle(Color.unbound.bg)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.unbound.accent))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Keystone hex (big) + "N beats away" label

    private func keystoneHex(_ node: SkillNode) -> some View {
        let state = nodeStates[node.id] ?? .locked
        let size: CGFloat = 140
        let beatsAway = sections.next.count + 1
        return VStack(spacing: 10) {
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
            .onTapGesture {
                UnboundHaptics.medium()
                selectedNode = node
            }

            Text(node.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Text("\(beatsAway) \(beatsAway == 1 ? "BEAT" : "BEATS") AWAY")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.accent)
        }
        .frame(maxWidth: .infinity)
    }

    private func keystoneFill(state: NodeState) -> Color {
        switch state {
        case .locked:     return Color.unbound.surface
        case .attempting: return Color.unbound.accent.opacity(0.16)
        case .achieved:   return Color.unbound.accent.opacity(0.22)
        case .mastered:   return Color.unbound.impact.opacity(0.22)
        }
    }

    // MARK: - OTHER DIRECTIONS (horizontal scroll)

    private func otherRow(_ nodes: [SkillNode]) -> some View {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Zig-zag column (for ACHIEVED / NEXT / MYTHIC)

    private func zigzagColumn(
        nodes: [SkillNode],
        sizeKind: HexSizeKind
    ) -> some View {
        let count = nodes.count
        let verticalGap: CGFloat = 100   // center-to-center distance
        let totalHeight: CGFloat = CGFloat(max(0, count - 1)) * verticalGap
            + sizeKind.size
            + 36  // label breathing room below last hex

        return GeometryReader { geo in
            let fullWidth = geo.size.width
            // ~45° diagonal — horizontal travel ≈ verticalGap (100pt).
            // On ~340pt container, 0.35/0.65 anchors give ~100pt hop.
            let leftX: CGFloat = fullWidth * 0.35
            let rightX: CGFloat = fullWidth * 0.65

            ZStack(alignment: .topLeading) {
                // Connecting rails drawn underneath.
                Canvas { ctx, _ in
                    drawRails(
                        ctx: ctx,
                        nodes: nodes,
                        leftX: leftX,
                        rightX: rightX,
                        verticalGap: verticalGap,
                        sizeKind: sizeKind
                    )
                }
                .frame(width: fullWidth, height: totalHeight)

                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                    let isLeft = (idx % 2 == 0)
                    let cx = isLeft ? leftX : rightX
                    let cy = CGFloat(idx) * verticalGap + sizeKind.size / 2
                    hexCell(node: node, sizeKind: sizeKind)
                        .position(x: cx, y: cy)
                        .onTapGesture {
                            UnboundHaptics.medium()
                            selectedNode = node
                        }
                }
            }
            .frame(width: fullWidth, height: totalHeight, alignment: .topLeading)
        }
        .frame(height: totalHeight)
        .padding(.horizontal, 16)
    }

    // Rails: quadratic bezier from bottom of hex[i] to top of hex[i+1].
    // Draw a blurred-wide underlay + a solid narrow core for the purple glow.
    private func drawRails(
        ctx: GraphicsContext,
        nodes: [SkillNode],
        leftX: CGFloat,
        rightX: CGFloat,
        verticalGap: CGFloat,
        sizeKind: HexSizeKind
    ) {
        guard nodes.count >= 2 else { return }
        let hexHalf = sizeKind.size / 2

        for idx in 0..<(nodes.count - 1) {
            let isLeft = (idx % 2 == 0)
            let nextIsLeft = ((idx + 1) % 2 == 0)
            let fromX = isLeft ? leftX : rightX
            let toX = nextIsLeft ? leftX : rightX
            // Anchor lines just inside the hex outline (0.42 of size from center).
            let fromY = CGFloat(idx) * verticalGap + sizeKind.size / 2 + hexHalf * 0.84
            let toY = CGFloat(idx + 1) * verticalGap + sizeKind.size / 2 - hexHalf * 0.84
            let midY = (fromY + toY) / 2

            var path = Path()
            path.move(to: CGPoint(x: fromX, y: fromY))
            path.addCurve(
                to: CGPoint(x: toX, y: toY),
                control1: CGPoint(x: fromX, y: midY),
                control2: CGPoint(x: toX, y: midY)
            )

            let fromNode = nodes[idx]
            let toNode = nodes[idx + 1]
            let fromReached = isUnlockedState(nodeStates[fromNode.id] ?? .locked)
            let toReached = isUnlockedState(nodeStates[toNode.id] ?? .locked)

            if fromReached && toReached {
                // Both reached — bright solid with blurred underlay.
                var blurCtx = ctx
                blurCtx.addFilter(.blur(radius: 4))
                blurCtx.stroke(
                    path,
                    with: .color(Color.unbound.accent.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                ctx.stroke(
                    path,
                    with: .color(Color.unbound.accent),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
            } else if fromReached {
                // Partial — glow a touch dimmer, still solid.
                var blurCtx = ctx
                blurCtx.addFilter(.blur(radius: 3))
                blurCtx.stroke(
                    path,
                    with: .color(Color.unbound.accent.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                ctx.stroke(
                    path,
                    with: .color(Color.unbound.accent.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            } else {
                // Locked-to-locked — dim solid purple with a faint blurred
                // underlay so every rail reads as a glowing line, not a dash.
                var blurCtx = ctx
                blurCtx.addFilter(.blur(radius: 2.5))
                blurCtx.stroke(
                    path,
                    with: .color(Color.unbound.accent.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                ctx.stroke(
                    path,
                    with: .color(Color.unbound.accent.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
            }
        }
    }

    // MARK: - Hex cell (shared rendering)

    private enum HexSizeKind {
        case far        // ACHIEVED (small, faded)
        case adjacent   // NEXT
        case mythic     // MYTHIC (gold stroke)
        case alternate  // OTHER DIRECTIONS row

        var size: CGFloat {
            switch self {
            case .far:       return 80
            case .adjacent:  return 95
            case .mythic:    return 90
            case .alternate: return 72
            }
        }

        var glyphSize: CGFloat {
            switch self {
            case .far:       return 20
            case .adjacent:  return 24
            case .mythic:    return 22
            case .alternate: return 18
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
                    .fill(fillColor(state: state, kind: sizeKind))
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(
                        borderColor(node: node, state: state, kind: sizeKind),
                        lineWidth: strokeWidth(state: state, kind: sizeKind)
                    )
                    .frame(width: size, height: size)
                if sizeKind == .mythic {
                    Hexagon()
                        .strokeBorder(Color.unbound.impact, lineWidth: 1.5)
                        .frame(width: size + 14, height: size + 14)
                        .opacity(state == .locked ? 0.45 : 0.9)
                }
                glyph(for: node, state: state, fontSize: sizeKind.glyphSize)
            }
            .shadow(
                color: glowColor(state: state, kind: sizeKind),
                radius: state == .locked ? 0 : 10
            )
            .opacity(sizeKind == .far ? 0.75 : 1.0)

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
        .frame(width: max(108, size + 10))
        .contentShape(Rectangle())
    }

    private func fillColor(state: NodeState, kind: HexSizeKind) -> Color {
        switch state {
        case .locked:
            return Color.unbound.surface
        case .attempting:
            return Color.unbound.accent.opacity(0.14)
        case .achieved:
            return Color.unbound.accent.opacity(kind == .far ? 0.1 : 0.18)
        case .mastered:
            return Color.unbound.impact.opacity(kind == .far ? 0.14 : 0.22)
        }
    }

    private func borderColor(node: SkillNode, state: NodeState, kind: HexSizeKind) -> Color {
        if node.isMythic && state == .locked { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .locked:
            return kind == .far ? Color.unbound.border.opacity(0.7) : Color.unbound.border
        case .attempting: return Color.unbound.accent
        case .achieved:   return Color.unbound.accent.opacity(kind == .far ? 0.7 : 1.0)
        case .mastered:   return Color.unbound.impact
        }
    }

    private func strokeWidth(state: NodeState, kind: HexSizeKind) -> CGFloat {
        if kind == .mythic { return 1.5 }
        switch state {
        case .locked:     return 1
        case .attempting: return 1.5
        case .achieved:   return 1.5
        case .mastered:   return 2
        }
    }

    private func glowColor(state: NodeState, kind: HexSizeKind) -> Color {
        if state == .locked { return .clear }
        if kind == .mythic { return Color.unbound.impact.opacity(0.5) }
        switch state {
        case .attempting: return Color.unbound.accent.opacity(0.4)
        case .achieved:   return Color.unbound.accent.opacity(kind == .far ? 0.25 : 0.45)
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
        var other: [SkillNode]
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
        // by effective tier ascending, keep only last 2 visible.
        let achievedAll = nodes
            .filter { !$0.isMythic && $0.id != keystone?.id }
            .filter { isUnlockedState(state($0)) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        let achieved = Array(achievedAll.suffix(2))

        // ACTIVE: first attempting → else lowest-tier unlockable locked →
        // else keystone as fallback.
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

        // NEXT: parallel training opportunities — every node that's
        // unlockable-right-now (.locked w/ prereqs satisfied) OR .attempting,
        // excluding the keystone, mythic, and the ACTIVE node itself.
        // Dropped the "must be on keystone ancestor path" filter so
        // parallel-lane skills (e.g. Handstand Walk 10m) show up here
        // instead of getting shuffled into OTHER DIRECTIONS.
        // Sort by effective tier asc, then id for stability, cap at 5.
        let nextCandidates = nodes
            .filter { !$0.isMythic }
            .filter { $0.id != keystone?.id }
            .filter { $0.id != activeNode?.id }
            .filter { node in
                let s = state(node)
                if s == .attempting { return true }
                if s == .locked && node.prereqsSatisfied(given: nodeStates) { return true }
                return false
            }
            .sorted {
                let ta = tiers[$0.id] ?? $0.tier
                let tb = tiers[$1.id] ?? $1.tier
                if ta != tb { return ta < tb }
                return $0.id < $1.id
            }
        let next = Array(nextCandidates.prefix(5))

        // MYTHIC: only surfaced once keystone is achieved/mastered.
        let mythic = keystoneUnlocked ? mythicNodes : []

        // OTHER DIRECTIONS: deeper-tier dead-end tangents — nodes NOT
        // unlockable yet AND NOT on the keystone ancestor path AND NOT
        // mythic. Usually empty after Change 1 (fine — section hides).
        let ancestors = keystone.map { keystoneAncestors(keystone: $0, nodeById: nodeById) }
            ?? Set(nodes.map(\.id))
        let consumed: Set<String> = Set(
            [activeNode?.id, keystone?.id].compactMap { $0 }
        )
            .union(achieved.map(\.id))
            .union(next.map(\.id))
            .union(mythic.map(\.id))

        let other = nodes
            .filter { !$0.isMythic }
            .filter { !consumed.contains($0.id) }
            .filter { !ancestors.contains($0.id) }
            .filter { !isUnlockedState(state($0)) }
            // Not unlockable right now (can't fit in NEXT).
            .filter { node in
                let s = state(node)
                if s == .attempting { return false }
                if s == .locked && node.prereqsSatisfied(given: nodeStates) { return false }
                return true
            }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        return StaircaseSections(
            achieved: achieved,
            active: activeNode,
            next: next,
            keystone: keystone,
            keystoneIsActive: keystoneIsActive,
            mythic: mythic,
            other: other
        )
    }

    /// Reverse BFS from the keystone walking backward through prereqs.
    /// Returns every node id that eventually feeds the keystone (including
    /// the keystone's own id).
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
