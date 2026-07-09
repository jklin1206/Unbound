import SwiftUI

/// Finger-drawn signature capture with a glowing ink stroke. Emits normalized
/// strokes (points in 0...1 relative to the pad) so a captured signature can be
/// re-rendered at any size later (profile, vow surfaces).
///
/// Uses `highPriorityGesture` so drawing wins over an enclosing `ScrollView`
/// (the onboarding scaffold scrolls its content).
struct SignaturePadView: View {
    /// Captured strokes, each a list of normalized points (0...1).
    @Binding var strokes: [[CGPoint]]
    var inkColor: Color = Color.unbound.accent

    /// In-progress stroke in the pad's own point space (denormalized).
    @State private var activeStroke: [CGPoint] = []

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { context, canvasSize in
                let rendered = strokes.map { denormalize($0, in: canvasSize) }
                    + (activeStroke.count > 1 ? [activeStroke] : [])
                for points in rendered where points.count > 1 {
                    let path = strokePath(points)
                    // Soft glow underlay, then the crisp ink line on top.
                    context.stroke(
                        path,
                        with: .color(inkColor.opacity(0.30)),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(inkColor),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in activeStroke.append(value.location) }
                    .onEnded { _ in
                        if activeStroke.count > 1 {
                            strokes.append(normalize(activeStroke, in: size))
                        }
                        activeStroke = []
                    }
            )
        }
    }

    private func strokePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func normalize(_ points: [CGPoint], in size: CGSize) -> [CGPoint] {
        guard size.width > 0, size.height > 0 else { return points }
        return points.map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) }
    }

    private func denormalize(_ points: [CGPoint], in size: CGSize) -> [CGPoint] {
        points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }
}
