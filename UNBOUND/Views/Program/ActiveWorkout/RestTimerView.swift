import SwiftUI

struct RestTimerView: View {
    let totalSeconds: Int
    let nextLabel: String          // e.g. "Bench · set 3"
    let onFinished: () -> Void
    let onSkip: () -> Void

    @State private var remaining: Int
    @State private var ringPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(totalSeconds: Int, nextLabel: String,
         onFinished: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.nextLabel = nextLabel
        self.onFinished = onFinished
        self.onSkip = onSkip
        _remaining = State(initialValue: totalSeconds)
    }

    private var progress: Double {
        totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()

            VStack(spacing: 36) {
                Text("REST")
                    .font(Font.unbound.captionS)
                    .tracking(4)
                    .foregroundStyle(Color.unbound.textTertiary)

                ZStack {
                    Circle()
                        .strokeBorder(Color.unbound.surfaceElevated, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.unbound.accent,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                    Text(timeString)
                        .font(Font.unbound.monoXL)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .monospacedDigit()
                }
                .frame(width: 240, height: 240)
                .scaleEffect(ringPulse && !reduceMotion ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: ringPulse)

                Text("NEXT · \(nextLabel.uppercased())")
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .tracking(1.5)

                HStack(spacing: 28) {
                    Button("SKIP") { finish(skipped: true) }
                        .font(Font.unbound.captionS)
                        .tracking(2)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Button("+30s") {
                        remaining += 30
                        UnboundHaptics.soft()
                    }
                        .font(Font.unbound.captionS)
                        .tracking(2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(.top, 8)
            }
            .padding(40)
        }
        .onReceive(clock) { _ in tick() }
    }

    private var timeString: String {
        let m = remaining / 60, s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func tick() {
        if remaining <= 1 { finish(skipped: false); return }
        remaining -= 1
        if remaining <= 5 {
            UnboundHaptics.tick()
            ringPulse.toggle()
        }
    }

    private func finish(skipped: Bool) {
        clock.upstream.connect().cancel()
        if skipped {
            UnboundHaptics.soft()
            onSkip()
        } else {
            UnboundHaptics.success()
            onFinished()
        }
    }
}
