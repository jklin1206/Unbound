import SwiftUI

/// Tertiary, edge-parked: progress dots + session clock. Tap a dot to jump.
struct ExerciseDotNavigator: View {
    let exerciseCount: Int
    let currentIndex: Int
    let completedIndices: Set<Int>
    let elapsedSeconds: Int
    let onJump: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0..<max(exerciseCount, 1), id: \.self) { i in
                    Circle()
                        .fill(color(for: i))
                        .frame(width: i == currentIndex ? 9 : 6,
                               height: i == currentIndex ? 9 : 6)
                        .onTapGesture {
                            UnboundHaptics.soft()
                            onJump(i)
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.8),
                                   value: currentIndex)
                }
            }
            Spacer(minLength: 8)
            Text(clock)
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
        }
    }

    private func color(for i: Int) -> Color {
        if i == currentIndex { return Color.unbound.accent }
        if completedIndices.contains(i) { return Color.unbound.textSecondary }
        return Color.unbound.textTertiary.opacity(0.5)
    }

    private var clock: String {
        let m = elapsedSeconds / 60, s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
