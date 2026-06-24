import SwiftUI
import UIKit

extension ClusterStaircaseView {
    func mainTree(layout: ComputedTreeLayout) -> some View {
        // During an unlock reveal, OPEN already framed on the parent→node chain
        // (slightly zoomed out) instead of on the tree's active node — otherwise
        // it pans across the whole tree and parks on unrelated nodes mid-flight.
        // The focusPoint fly then does a small punch-in onto the chain.
        let revealOpenFocus = unlockFocusPoint(layout: layout)
        let openZoom: CGFloat = revealOpenFocus != nil ? 0.95 : layout.activeZoom
        let openOffset: CGPoint? = revealOpenFocus
            .map { revealInitialOffset(focus: $0, zoom: openZoom, layout: layout) }
            ?? layout.initialOffset

        return ZoomableTreeScrollView(
            contentSize: CGSize(width: layout.contentWidth, height: layout.treeHeight),
            minZoom: minZoom,
            maxZoom: maxZoom,
            initialZoom: openZoom,
            initialOffset: openOffset,
            focusPoint: revealFocus,
            focusZoom: 1.08,
            onFocusArrived: { igniteReveal() }
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

                // Unlock reveal: the rail from the parent lights up into the node.
                unlockChainOverlay(layout: layout)

                // Interactive hex nodes — kept OUTSIDE any drawingGroup so
                // tap gestures still fire.
                ForEach(Array(layout.positions.keys), id: \.self) { id in
                    if let pos = layout.positions[id],
                       let node = layout.nodeById[id]
                    {
                        let role = layout.roles[id] ?? .tangent
                        let size = sizeFor(role: role)
                        let isReveal = (id == unlockRevealNodeId)
                        // The parent the unlock flows from — glows while the chain lights.
                        let isRevealParent = (unlockRevealNodeId != nil)
                            && (id == layout.primaryParent[unlockRevealNodeId ?? ""])

                        hexCore(node: node, role: role, size: size)
                            .overlay {
                                if isReveal {
                                    Hexagon()
                                        .trim(from: 0, to: revealOutline)
                                        .stroke(
                                            skinService.currentSkin.impactColor,
                                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                                        )
                                        .frame(width: size, height: size)
                                        .shadow(color: skinService.currentSkin.impactColor.opacity(0.9), radius: 6)
                                }
                            }
                            .scaleEffect(isReveal ? revealHexScale : 1)
                            .shadow(
                                color: skinService.currentSkin.impactColor.opacity(
                                    isReveal ? revealGlow * 0.85 : (isRevealParent ? revealChainProgress * 0.6 : 0)
                                ),
                                radius: (isReveal || isRevealParent) ? 22 : 0
                            )
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

    // MARK: - Unlock reveal (post-workout: fly to the node + ignite in place)

    /// The point the reveal camera frames: biased toward the new node, with its
    /// in-cluster primary parent kept visible above (the chain the unlock travels
    /// down). Falls back to the node itself for root/entry nodes with no parent.
    func unlockFocusPoint(layout: ComputedTreeLayout) -> CGPoint? {
        guard let nodeId = unlockRevealNodeId, let pos = layout.positions[nodeId] else { return nil }
        guard let parentPos = layout.primaryParent[nodeId].flatMap({ layout.positions[$0] }) else { return pos }
        return CGPoint(x: (parentPos.x + pos.x) / 2,
                       y: parentPos.y + (pos.y - parentPos.y) * 0.62)
    }

    /// Content offset that centers `focus` in the viewport at `zoom`, clamped to
    /// the content. Mirrors the active-node offset math in `buildLayout`.
    func revealInitialOffset(focus: CGPoint, zoom: CGFloat, layout: ComputedTreeLayout) -> CGPoint {
        let vw = ScreenMetrics.bounds.width
        let vh = layout.viewportHeight
        let maxOffX = max(0, layout.contentWidth * zoom - vw)
        let maxOffY = max(0, layout.treeHeight * zoom - vh)
        return CGPoint(
            x: min(max(0, focus.x * zoom - vw / 2), maxOffX),
            y: min(max(0, focus.y * zoom - vh / 2), maxOffY)
        )
    }

    /// Drives the camera fly-to + ignition when the tree is opened focused on a
    /// freshly-unlocked node. No-op during normal browsing.
    func startUnlockRevealIfNeeded() {
        guard !revealStarted,
              let nodeId = unlockRevealNodeId,
              let layout = treeLayout,
              let pos = layout.positions[nodeId] else { return }
        revealStarted = true

        let focus = unlockFocusPoint(layout: layout) ?? pos

        // Freeze (screenshot aid): jump straight to the lit + unlocked state.
        if revealFreeze {
            revealFocus = focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                revealChainProgress = 1
                revealHexScale = 1.22
                revealOutline = 1
                revealGlow = 0.7
                revealCaption = true
            }
            return
        }

        // Bring the parent + node into frame. The ignite is NOT on a timer — it
        // fires from `onFocusArrived` once travel completes (see igniteReveal),
        // so nothing lights up mid-flight. A fallback fires it if the arrival
        // callback is missed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { revealFocus = focus }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            igniteReveal()
        }
    }

    /// On camera arrival: a quick, smooth highlight flows down the rail from the
    /// parent, then wraps + forges the node. Idempotent — only the first call
    /// has any effect.
    func igniteReveal() {
        guard revealStarted, !revealIgnited,
              let nodeId = unlockRevealNodeId,
              let layout = treeLayout,
              layout.positions[nodeId] != nil else { return }
        revealIgnited = true

        let hasParent = !reduceMotion && layout.primaryParent[nodeId] != nil
        if hasParent {
            // One continuous line-draw (SwiftUI .trim) down the rail, paced slow
            // enough to clearly watch it trace, then the wrap. Not segmented.
            UnboundHaptics.soft()
            withAnimation(.easeInOut(duration: 1.4)) { revealChainProgress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { wrapAndForgeNode() }
        } else {
            revealChainProgress = 1
            wrapAndForgeNode()
        }
    }

    /// The highlight arrives and WRAPS around the node's hex (outline trace from
    /// the top, where the chain lands), then the node forges: grows once to its
    /// held size + glows, holding until the user taps Continue.
    private func wrapAndForgeNode() {
        UnboundHaptics.medium()
        withAnimation(.easeInOut(duration: 0.7)) { revealOutline = 1 }   // wrap around the hex
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UnboundHaptics.success()
            withAnimation(.easeOut(duration: 0.55)) { revealHexScale = 1.22 }
            withAnimation(.easeOut(duration: 0.6)) { revealGlow = 1 }
            withAnimation(.easeOut(duration: 0.4)) { revealCaption = true }
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                        revealGlow = 0.6
                    }
                }
            }
        }
    }

    /// The rail from the unlock node's parent into it, drawn over the static
    /// rails image and trimmed 0→1 so the highlight visibly snakes down the
    /// chain. Gated on the node/parent EXISTENCE (not on progress) so the view
    /// is present before the trim animates — otherwise it's inserted mid-flight
    /// at the final value and the line just pops in fully drawn.
    @ViewBuilder
    func unlockChainOverlay(layout: ComputedTreeLayout) -> some View {
        if let nodeId = unlockRevealNodeId,
           let parentId = layout.primaryParent[nodeId],
           let parentPos = layout.positions[parentId],
           let nodePos = layout.positions[nodeId] {
            ChainPath(
                from: parentPos,
                to: nodePos,
                fromSize: sizeFor(role: layout.roles[parentId] ?? .tangent),
                toSize: sizeFor(role: layout.roles[nodeId] ?? .tangent)
            )
            .trim(from: 0, to: revealChainProgress)
            .stroke(
                skinService.currentSkin.impactColor,
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: skinService.currentSkin.impactColor.opacity(0.9), radius: 8)
            .frame(width: layout.contentWidth, height: layout.treeHeight, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    var unlockRevealCaption: some View {
        if revealCaption,
           let nodeId = unlockRevealNodeId,
           let node = graph.node(id: nodeId) {
            let headline = node.isMythic ? "MYTHIC ACHIEVED"
                : node.isKeystone ? "KEYSTONE UNLOCKED" : "NODE UNLOCKED"
            VStack(spacing: 10) {
                Text(headline)
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(3.0)
                    .foregroundStyle(skinService.currentSkin.impactColor)
                Text(node.title)
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                UnboundButton(title: "Continue", icon: "arrow.right") {
                    onUnlockRevealFinished?()
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
            }
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.unbound.bg.opacity(0), Color.unbound.bg.opacity(0.82), Color.unbound.bg],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    func cosmeticTreeBackground(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.unbound.bg
            if UIImage(named: skinService.currentSkin.backgroundAssetName) != nil {
                Image(skinService.currentSkin.backgroundAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .saturation(1.08)
                    .contrast(skinService.currentSkin.backgroundAssetContrast)
                    .opacity(skinService.currentSkin.backgroundAssetOpacity)
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
    func renderRailsImage(
        positions: [String: CGPoint],
        primaryParent: [String: String],
        roles: [String: NodeRole],
        nodeById: [String: SkillNode],
        contentWidth: CGFloat,
        treeHeight: CGFloat
    ) -> UIImage {
        let size = CGSize(width: contentWidth, height: treeHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = ScreenMetrics.scale
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
    func mapViewportHeight(contentWidth: CGFloat, for treeHeight: CGFloat) -> CGFloat {
        let screenWidth = ScreenMetrics.bounds.width
        let initialZoom = min(1.0, max(minZoom, screenWidth / max(contentWidth, 1)))
        let renderedHeight = ceil(treeHeight * initialZoom)
        let screenHeight = ScreenMetrics.bounds.height
        return min(max(renderedHeight, 400), min(screenHeight * 0.72, 760))
    }

    // MARK: - Rank bands

    /// One gutter row. `isPresent` toggles colored vs dimmed styling.
    struct RankBand {
        let rank: RankTier
        let y: CGFloat
        let isPresent: Bool
    }

    /// Compute a row for every intrinsic difficulty bucket so the gutter
    /// always reads as a stable badge ladder.
    /// Present ranks anchor to the min-Y of their nodes. Absent ranks get
    /// an interpolated Y between the nearest present ranks above & below
    /// so the column of hex badges spaces evenly top-to-bottom.
    func computeAllRankBands(
        positions: [String: CGPoint],
        nodeById: [String: SkillNode],
        topY: CGFloat,
        bottomY: CGFloat
    ) -> [RankBand] {
        var minY: [RankTier: CGFloat] = [:]
        for (id, pt) in positions {
            guard let node = nodeById[id] else { continue }
            let r = node.placementRank
            if let existing = minY[r] {
                if pt.y < existing { minY[r] = pt.y }
            } else {
                minY[r] = pt.y
            }
        }

        let ranks = RankTier.allCases

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
    struct RankBandRegion {
        let rank: RankTier
        let top: CGFloat
        let bottom: CGFloat
    }

    /// Background stripes + dotted divider Y-positions. Driven only by
    /// ranks actually present in the cluster (absent ranks collapse — no
    /// empty stripe, no phantom divider). Divider between adjacent ranks
    /// sits at the midpoint between the prior rank's max-Y and the next
    /// rank's min-Y (so they land in the whitespace between rows).
    func computeRankBandRegions(
        positions: [String: CGPoint],
        nodeById: [String: SkillNode],
        topY: CGFloat,
        bottomY: CGFloat
    ) -> (bands: [RankBandRegion], dividers: [CGFloat]) {
        var minY: [RankTier: CGFloat] = [:]
        var maxY: [RankTier: CGFloat] = [:]
        for (id, pt) in positions {
            guard let node = nodeById[id] else { continue }
            let r = node.placementRank
            if let e = minY[r] { if pt.y < e { minY[r] = pt.y } } else { minY[r] = pt.y }
            if let e = maxY[r] { if pt.y > e { maxY[r] = pt.y } } else { maxY[r] = pt.y }
        }

        let presentRanks = RankTier.allCases.filter { minY[$0] != nil }

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
    func rankBandTrack(
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
    func rankTitleBadge(rank: RankTier, active: Bool, size: CGFloat) -> some View {
        Image(rank.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(active ? 1 : 0.15)
            .opacity(active ? 1.0 : 0.28)
            .shadow(
                color: rank.rewardTint.opacity(active ? 0.35 : 0),
                radius: active ? 8 : 0
            )
            .accessibilityLabel("\(rank.displayName) difficulty")
    }

    /// Tags the active hex with the `id("active")` anchor used by
    /// auto-scroll, without forcing every hex to own an id.
    struct ActiveAnchorModifier: ViewModifier {
        let isActive: Bool
        func body(content: Content) -> some View {
            if isActive { content.id("active") } else { content }
        }
    }
}

/// The orthogonal rail from a parent node down into its child, in tree content
/// coordinates. Trimmed 0→1 to animate the unlock travelling down the chain.
private struct ChainPath: Shape {
    let from: CGPoint   // parent center
    let to: CGPoint     // child center
    let fromSize: CGFloat
    let toSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: from.x, y: from.y + fromSize / 2)  // parent bottom
        let end = CGPoint(x: to.x, y: to.y - toSize / 2)          // child top
        let midY = (start.y + end.y) / 2
        p.move(to: start)
        p.addLine(to: CGPoint(x: start.x, y: midY))
        p.addLine(to: CGPoint(x: end.x, y: midY))
        p.addLine(to: end)
        return p
    }
}
