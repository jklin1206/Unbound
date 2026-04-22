import SwiftUI

// MARK: - RankBadge
//
// Hexagon-shaped rank badge. Letter (E/D/C/B/A/S) in Geist Mono (fallback
// .monospaced). Violet stroke. Used on dashboard, verdict, summary screens.

enum RankBadgeSize {
    case small, medium, large

    var side: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 72
        case .large: return 120
        }
    }
    var font: Font {
        switch self {
        case .small: return Font.unbound.monoM
        case .medium: return Font.unbound.monoL
        case .large: return Font.unbound.monoXL
        }
    }
    var strokeWidth: CGFloat {
        switch self {
        case .small: return 1.5
        case .medium: return 2
        case .large: return 2.5
        }
    }
}

struct RankBadge: View {
    let letter: String
    var size: RankBadgeSize = .medium
    var accentOverride: Color? = nil

    var body: some View {
        ZStack {
            Hexagon()
                .fill(Color.unbound.surface)
            Hexagon()
                .fill(.thinMaterial)
                .opacity(0.08)
            Hexagon()
                .strokeBorder(accentOverride ?? Color.unbound.accent, lineWidth: size.strokeWidth)
                .shadow(
                    color: (accentOverride ?? Color.unbound.accent).opacity(0.5),
                    radius: 8,
                    x: 0,
                    y: 0
                )
            Text(letter)
                .font(size.font)
                .foregroundStyle(Color.unbound.textPrimary)
        }
        .frame(width: size.side, height: size.side)
    }
}

// MARK: - Hexagon Shape

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

#Preview("Ranks") {
    HStack(spacing: 24) {
        RankBadge(letter: "E", size: .small)
        RankBadge(letter: "D", size: .medium)
        RankBadge(letter: "C", size: .medium)
        RankBadge(letter: "S", size: .large)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
