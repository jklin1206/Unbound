import SwiftUI

struct TechGridBackground: View {
    var spacing: CGFloat = 48
    var lineWidth: CGFloat = 0.5
    var opacity: Double = 0.35
    var driftRate: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let driftX = CGFloat(t).truncatingRemainder(dividingBy: spacing)
                let driftY = CGFloat(t * Double(driftRate) * 0.6).truncatingRemainder(dividingBy: spacing)

                Canvas { canvas, size in
                    let color = Color.unbound.border.opacity(opacity)
                    var x: CGFloat = -spacing + driftX
                    while x <= size.width + spacing {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        canvas.stroke(path, with: .color(color), lineWidth: lineWidth)
                        x += spacing
                    }
                    var y: CGFloat = -spacing + driftY
                    while y <= size.height + spacing {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        canvas.stroke(path, with: .color(color), lineWidth: lineWidth)
                        y += spacing
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay(
                    RadialGradient(
                        colors: [.clear, Color.unbound.bg.opacity(0.95)],
                        center: .center,
                        startRadius: min(geo.size.width, geo.size.height) * 0.25,
                        endRadius: max(geo.size.width, geo.size.height) * 0.75
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Grid") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        TechGridBackground()
            .ignoresSafeArea()
    }
}
