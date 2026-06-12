import SwiftUI
import UIKit

extension ClusterStaircaseView {
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
}
