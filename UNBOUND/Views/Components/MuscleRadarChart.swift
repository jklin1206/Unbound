import SwiftUI

struct MuscleRadarChart: View {
    let data: [RadarDataPoint]
    var size: CGFloat = 250

    struct RadarDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let current: CGFloat
        let target: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                RadarGridShape(sides: data.count, scale: scale)
                    .stroke(Color.theme.surfaceLight, lineWidth: 0.5)
            }

            RadarDataShape(values: data.map { $0.target / 100 })
                .fill(Color.theme.primary.opacity(0.1))
            RadarDataShape(values: data.map { $0.target / 100 })
                .stroke(Color.theme.primary.opacity(0.4), lineWidth: 1)

            RadarDataShape(values: data.map { $0.current / 100 })
                .fill(Color.theme.secondary.opacity(0.2))
            RadarDataShape(values: data.map { $0.current / 100 })
                .stroke(Color.theme.secondary, lineWidth: 2)

            ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                let angle = angleFor(index: index, total: data.count)
                let radius = (size / 2) * (point.current / 100)
                Circle()
                    .fill(Color.theme.secondary)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: radius * cos(angle - .pi / 2),
                        y: radius * sin(angle - .pi / 2)
                    )
            }

            ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                let angle = angleFor(index: index, total: data.count)
                let labelRadius = (size / 2) + 20
                Text(point.label)
                    .font(.caption(11))
                    .foregroundColor(.theme.textSecondary)
                    .offset(
                        x: labelRadius * cos(angle - .pi / 2),
                        y: labelRadius * sin(angle - .pi / 2)
                    )
            }
        }
        .frame(width: size + 60, height: size + 60)
    }

    private func angleFor(index: Int, total: Int) -> CGFloat {
        (2 * .pi / CGFloat(total)) * CGFloat(index)
    }
}

struct RadarGridShape: Shape {
    let sides: Int
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * scale

        for i in 0..<sides {
            let angle = (2 * .pi / CGFloat(sides)) * CGFloat(i) - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct RadarDataShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2

        for (i, value) in values.enumerated() {
            let angle = (2 * .pi / CGFloat(values.count)) * CGFloat(i) - .pi / 2
            let radius = maxRadius * min(value, 1.0)
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
