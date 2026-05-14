import SwiftUI

// MARK: - Hexagon Shape
//
// Pointy-top hexagon used by skill-tree nodes, rank badges, and MiniRankBadge.
// Extracted from RankBadge.swift so it can be shared across the codebase
// after RankBadge.swift is deleted.

struct Hexagon: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let w = r.width
        let h = r.height
        let q = h / 4   // pointy-top: top/bottom are single vertices, sides are flat

        var path = Path()
        path.move(to: CGPoint(x: r.midX, y: r.minY))                // top vertex
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + q))         // upper-right
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - q))         // lower-right
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY))             // bottom vertex
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - q))         // lower-left
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + q))         // upper-left
        path.closeSubpath()
        _ = w
        return path
    }

    func inset(by amount: CGFloat) -> Hexagon {
        var copy = self
        copy.inset += amount
        return copy
    }
}
