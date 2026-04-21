import SwiftUI

// MARK: - ScanLineSweep
//
// Single 1pt violet horizontal line that sweeps top→bottom (default)
// or bottom→top, with a soft glow. Used on fake processing screens
// (Screens 24–26) and Day 2 scan animation.
//
// Loopable — sweeps continuously while the view is on screen.

struct ScanLineSweep: View {
    var duration: Double = 1.6
    var glowRadius: CGFloat = 14

    @State private var offset: CGFloat = -0.5

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.accent.opacity(0),
                            Color.unbound.accent.opacity(0.4),
                            Color.unbound.accent,
                            Color.unbound.accent.opacity(0.4),
                            Color.unbound.accent.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: Color.unbound.accent.opacity(0.7), radius: glowRadius, x: 0, y: 0)
                .shadow(color: Color.unbound.impact.opacity(0.4), radius: glowRadius * 1.5, x: 0, y: 0)
                .offset(y: offset * geo.size.height)
                .onAppear {
                    offset = -0.5
                    withAnimation(
                        .linear(duration: duration).repeatForever(autoreverses: false)
                    ) {
                        offset = 1.5
                    }
                }
        }
    }
}

// MARK: - ProcessingStatusDisplay
//
// Composite used on Screens 24-26: large status text, a scan-line sweep
// behind it, and a mono percentage counter that animates between start
// and end values over a given duration.

struct ProcessingStatusDisplay: View {
    let statusText: String
    let startPercent: Int
    let endPercent: Int
    var duration: Double = 3.0
    /// Hold on 100 (or endPercent) before advancing. Gives the reveal weight.
    var completionHold: Double = 0.75
    var onComplete: () -> Void = {}

    @State private var currentPercent: Int = 0
    @State private var hasStarted = false
    @State private var hasReachedEnd = false
    @State private var sweepOpacity: Double = 0.8

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("\(currentPercent)")
                .font(Font.unbound.monoXL)
                .foregroundStyle(hasReachedEnd ? Color.unbound.impact : Color.unbound.accent)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(currentPercent)))
                .overlay(
                    Text("%")
                        .font(Font.unbound.monoM)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .offset(x: 48, y: 10),
                    alignment: .trailing
                )
                .scaleEffect(hasReachedEnd ? 1.15 : 1.0)
                .shadow(
                    color: hasReachedEnd ? Color.unbound.impact.opacity(0.55) : .clear,
                    radius: hasReachedEnd ? 24 : 0,
                    x: 0, y: 0
                )
                .animation(.spring(response: 0.45, dampingFraction: 0.58), value: hasReachedEnd)

            Text(statusText)
                .font(Font.unbound.bodyLStrong)
                .foregroundStyle(Color.unbound.textPrimary)
                .tracking(0.8)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .opacity(hasReachedEnd ? 0.6 : 1.0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ScanLineSweep(duration: 1.4)
                .opacity(sweepOpacity)
                .animation(.easeOut(duration: 0.4), value: sweepOpacity)
        )
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            currentPercent = startPercent
            animateProgress()
        }
    }

    private func animateProgress() {
        let span = endPercent - startPercent
        guard span > 0 else {
            onComplete()
            return
        }
        let tickCount = min(60, span)
        let tickDuration = duration / Double(tickCount)
        for i in 1...tickCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + tickDuration * Double(i)) {
                let fraction = Double(i) / Double(tickCount)
                let value = Int(Double(startPercent) + fraction * Double(span))
                withAnimation(.easeOut(duration: tickDuration * 1.5)) {
                    currentPercent = value
                }
                if i == tickCount {
                    // Hit the end — punch + pause + heavy haptic before advancing.
                    hasReachedEnd = true
                    sweepOpacity = 0.0 // calm the scan line down so the % shines
                    UnboundHaptics.heavy()
                    DispatchQueue.main.asyncAfter(deadline: .now() + completionHold) {
                        onComplete()
                    }
                }
            }
        }
    }
}

#Preview("Scan line") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        ScanLineSweep()
    }
}

#Preview("Processing") {
    ProcessingStatusDisplay(
        statusText: "Analyzing your profile",
        startPercent: 0,
        endPercent: 34,
        duration: 3.0
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
