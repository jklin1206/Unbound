import SwiftUI

// MARK: - ClusterStaircaseView
//
// Primary cluster-detail view. Replaces the hex-grid `ClusterDetailView`
// as the default way a cluster's progression is presented.
//
// Shape: a tight vertical column that only surfaces what matters right
// now — the most recent achieved node (small/faded), the active node
// (big, pulsing), up to 4 NEXT nodes in the keystone's ancestor chain,
// an optional "+ N more beats to keystone" chip if ancestors exceed the
// NEXT cap, a compact keystone pill at the bottom (or a full keystone
// hex once the keystone becomes the active node), and finally any
// genuine dead-end branches under ALTERNATE PATHS.
//
// "Keystone ancestors" = all nodes whose prereq chain eventually feeds
// the keystone. Computed via reverse BFS from the keystone. Anything
// NOT in that set, not mythic, and not achieved is a dead-end branch.
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
    @State private var expandedRemaining: Bool = false

    // Reused everywhere — compute once per body pass.
    private var clusterNodes: [SkillNode] {
        graph.nodes(in: cluster)
    }

    private var sections: StaircaseSections {
        buildSections()
    }

    private let horizontalInset: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        summaryBlock
                            .padding(.horizontal, horizontalInset)

                        // Most-recent achieved node — tiny faded hex above the
                        // active node. Replaces the old full ACHIEVED section
                        // to keep the view focused on the next action.
                        if let recent = sections.recentAchieved {
                            recentAchievedRow(recent)
                                .padding(.top, 4)
                        }

                        activeSection
                            .id("active-anchor")

                        if !sections.next.isEmpty {
                            nextColumn(sections.next)
                        }

                        if sections.remainingBeforeKeystone > 0 {
                            remainingBeatsChip(count: sections.remainingBeforeKeystone)
                        }

                        if expandedRemaining, !sections.remainingNodes.isEmpty {
                            remainingExpansion(sections.remainingNodes)
                        }

                        if let keystone = sections.keystone {
                            if sections.keystoneIsActive {
                                // Active-state keystone was already rendered
                                // as the big active hex. Nothing to draw here.
                                EmptyView()
                            } else {
                                keystonePill(keystone)
                                    .padding(.top, 6)
                            }
                        }

                        if !sections.mythic.isEmpty {
                            mythicSection(sections.mythic)
                        }

                        if !sections.alternatePaths.isEmpty {
                            alternatePathsSection(sections.alternatePaths)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.bottom, 40)
                }
                .onAppear {
                    // Slight delay so ScrollView is laid out before we jump.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.4)) {
                            proxy.scrollTo("active-anchor", anchor: .center)
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

    // MARK: - Recent achieved context

    private func recentAchievedRow(_ node: SkillNode) -> some View {
        VStack(spacing: 6) {
            hexCell(node: node, sizeKind: .far)
                .opacity(0.6)
            // Dashed connector down to the active hex.
            Rectangle()
                .fill(Color.clear)
                .frame(width: 1, height: 14)
                .overlay(
                    Rectangle()
                        .fill(Color.unbound.accent.opacity(0.4))
                        .frame(width: 1, height: 14)
                        .mask(
                            VStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle().frame(height: 3)
                                }
                            }
                        )
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Active section

    @ViewBuilder
    private var activeSection: some View {
        VStack(spacing: 10) {
            sectionDivider("ACTIVE")
            if let active = sections.active {
                VStack(spacing: 10) {
                    // If the keystone IS the active node, render full keystone
                    // presentation. Otherwise render the standard active hex.
                    if sections.keystoneIsActive {
                        hexCell(node: active, sizeKind: .keystone, pulses: true)
                            .onTapGesture {
                                UnboundHaptics.medium()
                                selectedNode = active
                            }
                        Text("YOUR ARC ENDS HERE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(Color.unbound.accent)
                    } else {
                        hexCell(node: active, sizeKind: .active, pulses: true)
                            .onTapGesture {
                                UnboundHaptics.medium()
                                selectedNode = active
                            }
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
                Text("Cluster complete.")
                    .font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    // MARK: - NEXT column (up to 4 ancestors)

    private func nextColumn(_ nodes: [SkillNode]) -> some View {
        VStack(spacing: 10) {
            sectionDivider("NEXT")
            GeometryReader { geo in
                let fullWidth = geo.size.width
                let widthFraction: CGFloat = 0.78
                let size = HexSizeKind.adjacent.size
                let gap = HexSizeKind.adjacent.verticalGap
                let bandWidth = fullWidth * widthFraction
                let leftAnchor = (fullWidth - bandWidth) / 2
                let rightAnchor = leftAnchor + bandWidth - size

                ZStack(alignment: .topLeading) {
                    connectingLines(
                        nodes: nodes,
                        leftAnchor: leftAnchor,
                        rightAnchor: rightAnchor,
                        sizeKind: .adjacent
                    )
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                        let isLeft = (idx % 2 == 0)
                        let x = isLeft ? leftAnchor : rightAnchor
                        let y = CGFloat(idx) * (size + gap)
                        hexCell(node: node, sizeKind: .adjacent)
                            .offset(x: x, y: y)
                    }
                }
                .frame(
                    width: fullWidth,
                    height: CGFloat(max(0, nodes.count)) * size
                        + CGFloat(max(0, nodes.count - 1)) * gap
                        + 12,
                    alignment: .topLeading
                )
            }
            .frame(
                height: CGFloat(max(0, nodes.count)) * HexSizeKind.adjacent.size
                    + CGFloat(max(0, nodes.count - 1)) * HexSizeKind.adjacent.verticalGap
                    + 12
            )
        }
    }

    // MARK: - "+ N more beats to keystone" chip

    private func remainingBeatsChip(count: Int) -> some View {
        Button {
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedRemaining.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: expandedRemaining ? "chevron.up" : "plus")
                    .font(.system(size: 10, weight: .bold))
                Text("\(count) MORE \(count == 1 ? "BEAT" : "BEATS") TO KEYSTONE")
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
    }

    private func remainingExpansion(_ nodes: [SkillNode]) -> some View {
        VStack(spacing: 10) {
            ForEach(nodes, id: \.id) { node in
                HStack(spacing: 10) {
                    hexCell(node: node, sizeKind: .far)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Keystone (compact pill form)

    private func keystonePill(_ node: SkillNode) -> some View {
        let beats = sections.next.count + sections.remainingBeforeKeystone + 1
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

    // MARK: - Mythic (post-keystone) — only surfaced when keystone complete

    private func mythicSection(_ nodes: [SkillNode]) -> some View {
        VStack(spacing: 10) {
            sectionDivider("MYTHIC")
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
    }

    // MARK: - Alternate paths

    private func alternatePathsSection(_ nodes: [SkillNode]) -> some View {
        VStack(spacing: 10) {
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

    // MARK: - Connecting lines between stacked hexes

    private func connectingLines(
        nodes: [SkillNode],
        leftAnchor: CGFloat,
        rightAnchor: CGFloat,
        sizeKind: HexSizeKind
    ) -> some View {
        Canvas { ctx, _ in
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

    // MARK: - Hex cell (shared rendering)

    private enum HexSizeKind {
        case far        // dim achieved / remaining-collapsed nodes
        case adjacent   // NEXT nodes
        case active     // current node
        case keystone   // full keystone presentation when it IS active
        case mythic     // post-keystone bosses
        case alternate  // dead-end branch row

        var size: CGFloat {
            switch self {
            case .far:        return 70
            case .adjacent:   return 95
            case .active:     return 130
            case .keystone:   return 150
            case .mythic:     return 90
            case .alternate:  return 72
            }
        }

        var verticalGap: CGFloat {
            switch self {
            case .far:        return 14
            case .adjacent:   return 18
            case .mythic:     return 16
            case .alternate:  return 14
            case .active, .keystone: return 18
            }
        }
    }

    @ViewBuilder
    private func hexCell(node: SkillNode, sizeKind: HexSizeKind, pulses: Bool = false) -> some View {
        let state = nodeStates[node.id] ?? .locked
        let size = sizeKind.size

        VStack(spacing: 6) {
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
        case .active:    return 30
        case .keystone:  return 32
        case .far:       return 18
        case .alternate: return 18
        case .adjacent:  return 22
        case .mythic:    return 22
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
        var recentAchieved: SkillNode?
        var active: SkillNode?
        var next: [SkillNode]
        var remainingBeforeKeystone: Int
        var remainingNodes: [SkillNode]
        var keystone: SkillNode?
        var keystoneIsActive: Bool
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
        let nodeById = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let tiers = computeEffectiveTiers(nodes: nodes)

        func state(_ n: SkillNode) -> NodeState { nodeStates[n.id] ?? .locked }
        func isUnlockedState(_ s: NodeState) -> Bool { s == .achieved || s == .mastered }

        let keystone = nodes.first { $0.isKeystone && !$0.isMythic }
        let mythicNodes = nodes.filter { $0.isMythic }

        // Ancestor set for the keystone. Includes the keystone id itself.
        // If there's no keystone at all (shouldn't happen post-data-fix),
        // treat every node as an ancestor so nothing drops into ALTERNATE.
        let ancestorSet: Set<String> = {
            if let k = keystone { return keystoneAncestors(keystone: k) }
            return Set(nodes.map(\.id))
        }()

        // Active = first attempting (ancestor-preferred), else lowest-tier
        // locked-but-unlockable ancestor, else the keystone as a fallback.
        let attemptingAncestors = nodes
            .filter { state($0) == .attempting && ancestorSet.contains($0.id) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
        let attemptingAny = nodes
            .filter { state($0) == .attempting }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        var activeNode: SkillNode? = attemptingAncestors.first ?? attemptingAny.first

        if activeNode == nil {
            let unlockables = nodes
                .filter { ancestorSet.contains($0.id) }
                .filter { state($0) == .locked }
                .filter { node in
                    let withinClusterPrereqIds = node.prereqs
                        .flatMap { $0.nodeIds }
                        .filter { nodeById[$0] != nil }
                    guard !withinClusterPrereqIds.isEmpty || node.prereqs.isEmpty else {
                        return true
                    }
                    guard !node.prereqs.isEmpty else { return true }
                    return node.prereqs.contains { group in
                        group.nodeIds.allSatisfy { pid in
                            guard let prereq = nodeById[pid] else { return true }
                            return isUnlockedState(state(prereq))
                        }
                    }
                }
                .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }
            activeNode = unlockables.first
        }

        if activeNode == nil { activeNode = keystone }

        let keystoneIsActive = (activeNode?.id == keystone?.id) && keystone != nil

        // Most recently achieved ancestor — highest effective tier among
        // achieved/mastered nodes in the ancestor chain. Falls back to any
        // achieved node if nothing in the ancestor set has been achieved.
        let achievedAncestors = nodes
            .filter { ancestorSet.contains($0.id) }
            .filter { isUnlockedState(state($0)) && $0.id != activeNode?.id }
            .sorted { (tiers[$0.id] ?? $0.tier) > (tiers[$1.id] ?? $1.tier) }
        let achievedAny = nodes
            .filter { isUnlockedState(state($0)) && $0.id != activeNode?.id }
            .sorted { (tiers[$0.id] ?? $0.tier) > (tiers[$1.id] ?? $1.tier) }
        let recentAchieved = achievedAncestors.first ?? achievedAny.first

        // NEXT = remaining locked ancestors (excluding active + keystone),
        // sorted by effective tier, capped at 4.
        let allRemainingAncestors: [SkillNode] = nodes
            .filter { ancestorSet.contains($0.id) }
            .filter { !isUnlockedState(state($0)) }
            .filter { $0.id != activeNode?.id && $0.id != keystone?.id }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        let nextCap = 4
        let nextNodes = Array(allRemainingAncestors.prefix(nextCap))
        let remainingNodes = Array(allRemainingAncestors.dropFirst(nextCap))
        let remainingCount = remainingNodes.count

        // Alternate paths = nodes NOT in the ancestor set, NOT mythic, NOT
        // achieved. These are genuine dead-end branches off the main line.
        let alternate = nodes
            .filter { !ancestorSet.contains($0.id) }
            .filter { !$0.isMythic }
            .filter { !isUnlockedState(state($0)) }
            .sorted { (tiers[$0.id] ?? $0.tier) < (tiers[$1.id] ?? $1.tier) }

        // Mythic only surfaces once the keystone is complete.
        let keystoneUnlocked = keystone.map { isUnlockedState(state($0)) } ?? false
        let mythicToShow = keystoneUnlocked ? mythicNodes : []

        return StaircaseSections(
            recentAchieved: recentAchieved,
            active: activeNode,
            next: nextNodes,
            remainingBeforeKeystone: remainingCount,
            remainingNodes: remainingNodes,
            keystone: keystone,
            keystoneIsActive: keystoneIsActive,
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
