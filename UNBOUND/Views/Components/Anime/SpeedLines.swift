import SwiftUI

struct SpeedLines: View {
    var count: Int = 32
    var length: CGFloat = 140
    var innerRadius: CGFloat = 60
    var color: Color = Color.unbound.textPrimary
    var burstDuration: Double = 0.6
    var trigger: UUID

    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
            let elapsed = max(0, ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: burstDuration * 2))
            let progress = min(1.0, elapsed / burstDuration)
            let ease = 1 - pow(1 - progress, 3)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxReach = max(size.width, size.height)
                for i in 0..<count {
                    let angle = Double(i) / Double(count) * .pi * 2
                    let jitter = sin(Double(i) * 7.3) * 0.15
                    let inner = innerRadius + CGFloat(ease) * (maxReach * 0.1)
                    let outer = inner + length * CGFloat(ease) * CGFloat(1.0 + jitter)
                    let start = CGPoint(
                        x: center.x + cos(angle) * inner,
                        y: center.y + sin(angle) * inner
                    )
                    let end = CGPoint(
                        x: center.x + cos(angle) * outer,
                        y: center.y + sin(angle) * outer
                    )
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    let alpha = (1.0 - progress) * 0.9
                    context.stroke(
                        path,
                        with: .color(color.opacity(alpha)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
            }
        }
        .id(trigger)
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        SpeedLines(trigger: UUID())
    }
}
