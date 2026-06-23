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
        let available = isAvailable(node)
        return ZStack {
            Hexagon()
                .fill(Color.unbound.surface)
                .frame(width: size, height: size)
            Hexagon()
                .fill(available ? availableFill() : fillColor(state: state, faded: faded))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(
                    available ? availableBorder() : borderColor(node: node, state: state, faded: faded),
                    lineWidth: available ? 1.5 : strokeWidth(state: state)
                )
                .frame(width: size, height: size)
            glyph(for: node, state: state, available: available, fontSize: 24)
        }
        .shadow(
            color: available ? availableGlow() : glowColor(state: state, faded: faded),
            radius: (state == .locked && !available) ? 0 : 10
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    func activeHex(node: SkillNode, state: NodeState, size: CGFloat) -> some View {
        let skin = skinService.currentSkin
        let available = isAvailable(node)
        return ZStack {
            Hexagon()
                .fill(Color.unbound.surface)
                .frame(width: size, height: size)
            Hexagon()
                .fill(available ? availableFill() : skin.nodeFill(state: state, faded: false))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(skin.primaryColor, lineWidth: 2)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(skin.impactColor.opacity(0.7), lineWidth: 1)
                .frame(width: size + 16, height: size + 16)
            glyph(for: node, state: state, available: available, fontSize: 36)
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
        // "Ready" = already proven, or available to claim now (prereqs met).
        let ready = state != .locked || isAvailable(node)
        return ZStack {
            Hexagon()
                .fill(Color.unbound.surface)
                .frame(width: size, height: size)
            Hexagon()
                .fill(ready && state == .locked ? availableFill() : keystoneFill(state: state))
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(skin.primaryColor, lineWidth: 2)
                .frame(width: size, height: size)
            Hexagon()
                .strokeBorder(
                    ready
                        ? skin.impactColor.opacity(0.85)
                        : skin.primaryColor.opacity(0.4),
                    lineWidth: 1
                )
                .frame(width: size + 18, height: size + 18)
            Image(systemName: ready ? "crown.fill" : "crown")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(skin.primaryColor)
        }
        .shadow(
            color: ready
                ? skin.impactColor.opacity(0.55)
                : skin.primaryColor.opacity(0.3),
            radius: 16
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UnboundHaptics.medium()
            selectedNode = node
        }
    }

    func defaultBelow(node: SkillNode, state: NodeState) -> some View {
        let available = isAvailable(node)
        return Text(node.title)
            .font(Font.unbound.captionS.weight(.semibold))
            .foregroundStyle(
                (state == .locked && !available)
                    ? Color.unbound.textTertiary
                    : Color.unbound.textPrimary
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
    }

    func keystoneFill(state: NodeState) -> Color {
        skinService.currentSkin.nodeFill(state: state, faded: false)
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
        let available = isAvailable(node)
        return VStack(spacing: 6) {
            ZStack {
                Hexagon()
                    .fill(Color.unbound.surface)
                    .frame(width: size, height: size)
                Hexagon()
                    .fill(available ? availableFill() : fillColor(state: state, faded: false))
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(skinService.currentSkin.impactColor, lineWidth: 1.5)
                    .frame(width: size, height: size)
                Hexagon()
                    .strokeBorder(skinService.currentSkin.impactColor, lineWidth: 1.5)
                    .frame(width: size + 14, height: size + 14)
                    .opacity((state == .locked && !available) ? 0.45 : 0.9)
                glyph(for: node, state: state, available: available, fontSize: 24)
            }
            .shadow(color: skinService.currentSkin.impactColor.opacity(0.5), radius: (state == .locked && !available) ? 0 : 10)

            Text(node.title)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(
                    (state == .locked && !available) ? Color.unbound.textTertiary : Color.unbound.textPrimary
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

    // MARK: - Availability (open vs gated)

    /// A node is "available" — trainable now, drawn open — when it is unproven
    /// and at least one prerequisite group is satisfied. Entry nodes (no
    /// prereqs) are always available. Anything that is NOT available keeps the
    /// padlock glyph.
    func isAvailable(_ node: SkillNode) -> Bool {
        guard (nodeStates[node.id] ?? .locked) == .locked else { return false }
        return node.prereqsSatisfied(given: nodeStates)
    }

    /// Skin-tinted styling for an available (open, unproven) node — roughly half
    /// the saturation of a proven node, so the rungs read distinctly on true
    /// black: gated (flat, padlock) < available (lit, icon) < proven (glowing).
    func availableFill() -> Color { skinService.currentSkin.primaryColor.opacity(0.12) }
    func availableBorder() -> Color { skinService.currentSkin.primaryColor.opacity(0.55) }
    func availableGlow() -> Color { skinService.currentSkin.primaryColor.opacity(0.22) }

    @ViewBuilder
    func glyph(for node: SkillNode, state: NodeState, available: Bool, fontSize: CGFloat) -> some View {
        switch state {
        case .locked where available:
            // Trainable now: show the skill icon (slightly ghosted), never a
            // padlock. The padlock is reserved for genuinely gated nodes.
            skillIcon(for: node, size: fontSize * 2.4,
                      fallback: node.isKeystone ? "crown" : "figure.strengthtraining.traditional",
                      tint: skinService.currentSkin.decalColor)
                .opacity(0.78)
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
