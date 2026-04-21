import SwiftUI

struct ScoreRing: View {
    let score: Int
    let maxScore: Int
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10
    var color: Color = .theme.secondary

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat {
        CGFloat(score) / CGFloat(maxScore)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.theme.surfaceLight, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.stat(size * 0.3))
                    .foregroundColor(.theme.textPrimary)
                Text("/ \(maxScore)")
                    .font(.caption(size * 0.12))
                    .foregroundColor(.theme.textMuted)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = progress
            }
        }
    }
}
