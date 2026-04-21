import SwiftUI

struct ChamferedRectangle: Shape {
    var inset: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = max(2, min(inset, min(rect.width, rect.height) / 2))

        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.closeSubpath()
        return path
    }
}

struct HUDHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY

        let quarterH = h / 4.0
        let halfW = w / 2.0

        // Pointy-top hexagon
        path.move(to: CGPoint(x: cx, y: rect.minY))
        path.addLine(to: CGPoint(x: cx + halfW, y: cy - quarterH))
        path.addLine(to: CGPoint(x: cx + halfW, y: cy + quarterH))
        path.addLine(to: CGPoint(x: cx, y: rect.maxY))
        path.addLine(to: CGPoint(x: cx - halfW, y: cy + quarterH))
        path.addLine(to: CGPoint(x: cx - halfW, y: cy - quarterH))
        path.closeSubpath()
        return path
    }
}

#Preview("Chamfered") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 24) {
            ChamferedRectangle(inset: 8)
                .stroke(Color.unbound.accent, lineWidth: 1.5)
                .frame(width: 280, height: 60)

            ChamferedRectangle(inset: 12)
                .fill(Color.unbound.surface)
                .overlay(
                    ChamferedRectangle(inset: 12)
                        .stroke(Color.unbound.accent, lineWidth: 2)
                )
                .frame(width: 280, height: 80)

            HUDHexagon()
                .stroke(Color.unbound.accent, lineWidth: 1.5)
                .frame(width: 28, height: 28)

            HUDHexagon()
                .fill(Color.unbound.accent)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.unbound.textPrimary)
                )
        }
    }
}
