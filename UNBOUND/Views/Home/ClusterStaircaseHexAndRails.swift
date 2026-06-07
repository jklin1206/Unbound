import SwiftUI
import UIKit

extension ClusterStaircaseView {
    @ViewBuilder
    func hexCore(node: SkillNode, role: NodeRole, size: CGFloat) -> some View {
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
    func hexBelow(node: SkillNode, role: NodeRole) -> some View {
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

    func defaultHex(
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

    func activeHex(node: SkillNode, state: NodeState, size: CGFloat) -> some View {
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

    func keystoneHex(node: SkillNode, state: NodeState, size: CGFloat) -> some View {
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

    func defaultBelow(node: SkillNode, state: NodeState) -> some View {
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

    func activeBelow(node: SkillNode) -> some View {
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

    func keystoneBelow(node: SkillNode) -> some View {
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

    func keystoneFill(state: NodeState) -> Color {
        skinService.currentSkin.nodeFill(state: state, faded: false)
    }

    // MARK: - Rails

    /// Primary rails: child ← primary parent. Orthogonal step path with
    /// full-accent glow tiered by reached/partial/locked state. Parallel
    /// children render a horizontal side-rail at the shared y instead.
    func drawPrimaryRails(
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
    func drawParallelRail(
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
    func drawGhostRails(
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
    func drawRail(
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

    func strokeRail(
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

    func drawPrimaryRailsCG(
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

    func drawParallelRailCG(
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

    func drawGhostRailsCG(
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

    func drawRailCG(
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

    func strokeRailCG(
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

    func mythicChain(nodes: [SkillNode]) -> some View {
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

    func mythicHex(node: SkillNode, size: CGFloat) -> some View {
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

    func fillColor(state: NodeState, faded: Bool) -> Color {
        skinService.currentSkin.nodeFill(state: state, faded: faded)
    }

    func borderColor(node: SkillNode, state: NodeState, faded: Bool) -> Color {
        skinService.currentSkin.nodeBorder(state: state, faded: faded, mythic: node.isMythic)
    }

    func strokeWidth(state: NodeState) -> CGFloat {
        switch state {
        case .locked: return 1
        case .proven: return 1.5
        }
    }

    func glowColor(state: NodeState, faded: Bool) -> Color {
        skinService.currentSkin.nodeGlow(state: state, faded: faded)
    }

    @ViewBuilder
    func glyph(for node: SkillNode, state: NodeState, fontSize: CGFloat) -> some View {
        switch state {
        case .locked:
            Image(systemName: node.isKeystone ? "crown" : "lock.fill")
                .font(.system(size: fontSize - 3, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
        case .proven:
            skillIcon(for: node, size: fontSize * 2.4,
                      fallback: node.isKeystone ? "crown.fill" : "checkmark",
                      tint: skinService.currentSkin.decalColor)
        }
    }

    /// Renders the generated skill icon asset if it exists; otherwise falls
    /// back to an SF Symbol.
    /// Asset names map node ids by replacing dots with underscores
    /// (e.g. `cal.pushup` → `cal_pushup`).
    @ViewBuilder
    func skillIcon(
        for node: SkillNode,
        size: CGFloat,
        fallback symbolName: String,
        tint: Color
    ) -> some View {
        if let assetName = SkillTraditionalVisualResolver.assetName(for: node),
           UIImage(named: assetName) != nil {
            let usesOriginalArtwork = usesOriginalNodeArtwork(assetName)
            ZStack {
                Image(assetName)
                    .renderingMode(usesOriginalArtwork ? .original : .template)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(tint)
                    .frame(
                        width: size * (usesOriginalArtwork ? 1.12 : 0.82),
                        height: size * (usesOriginalArtwork ? 1.12 : 0.82)
                    )
                    .shadow(color: Color.black.opacity(0.72), radius: size > 80 ? 5 : 3)
                    .shadow(color: usesOriginalArtwork ? Color.clear : tint.opacity(0.5), radius: size > 80 ? 8 : 4)
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: symbolName)
                .font(.system(size: size / 2.4, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    func usesOriginalNodeArtwork(_ assetName: String) -> Bool {
        true
    }
}
