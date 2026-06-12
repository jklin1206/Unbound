import SwiftUI
import UIKit

extension ClusterStaircaseView {
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
}
