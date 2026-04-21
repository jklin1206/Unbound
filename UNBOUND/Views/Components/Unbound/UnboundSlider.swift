import SwiftUI

// MARK: - UnboundSlider
//
// Premium tick-mark slider for 1–10 style questions (diet / sleep / stress /
// commitment). Custom DragGesture-backed — not the stock iOS `Slider` —
// because we need:
//   - visible bone-white tick marks at every integer
//   - violet thumb with soft shadow
//   - violet fill to the left of the thumb
//   - floating Geist Mono value label above the thumb
//   - haptic `tick` on each integer crossing
//
// Usage:
//   @State var value: Int = 5
//   UnboundSlider(value: $value, range: 1...10)

struct UnboundSlider: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10
    /// Optional caption shown beneath the leading/trailing extremes (e.g. "Poor" / "Excellent")
    var minLabel: String? = nil
    var maxLabel: String? = nil

    @State private var lastHapticValue: Int? = nil
    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Value label
            Text("\(value)")
                .font(Font.unbound.monoL)
                .foregroundStyle(Color.unbound.accent)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: value)

            // Track
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let currentFraction = progress()
                let thumbX = CGFloat(currentFraction) * totalWidth

                ZStack(alignment: .leading) {
                    // Unfilled track
                    Capsule()
                        .fill(Color.unbound.border.opacity(0.7))
                        .frame(height: trackHeight)

                    // Filled track
                    Capsule()
                        .fill(Color.unbound.accent)
                        .frame(width: max(thumbX, 2), height: trackHeight)
                        .shadow(color: Color.unbound.accent.opacity(0.4), radius: 6, x: 0, y: 0)

                    // Tick marks
                    ForEach(range, id: \.self) { tick in
                        let tickFraction = fraction(for: tick)
                        let tickX = CGFloat(tickFraction) * totalWidth
                        let isFilled = tick <= value
                        Circle()
                            .fill(isFilled ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                            .frame(width: 4, height: 4)
                            .offset(x: tickX - 2)
                    }

                    // Thumb
                    Circle()
                        .fill(Color.unbound.accent)
                        .frame(width: thumbSize, height: thumbSize)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.unbound.textPrimary.opacity(0.9), lineWidth: 2)
                        )
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 10, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 4)
                        .offset(x: thumbX - thumbSize / 2)
                        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: value)
                }
                .frame(height: thumbSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            updateValue(from: drag.location.x, totalWidth: totalWidth)
                        }
                        .onEnded { _ in
                            lastHapticValue = nil
                        }
                )
            }
            .frame(height: thumbSize)

            // Optional labels
            if minLabel != nil || maxLabel != nil {
                HStack {
                    Text(minLabel ?? "")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text(maxLabel ?? "")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
        }
    }

    // MARK: Math

    private func progress() -> Double {
        fraction(for: value)
    }

    private func fraction(for tick: Int) -> Double {
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return Double(tick - range.lowerBound) / span
    }

    private func updateValue(from x: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let clampedX = max(0, min(totalWidth, x))
        let fraction = Double(clampedX / totalWidth)
        let span = Double(range.upperBound - range.lowerBound)
        let raw = Double(range.lowerBound) + fraction * span
        let snapped = Int(raw.rounded())
        let clamped = max(range.lowerBound, min(range.upperBound, snapped))
        if clamped != value {
            value = clamped
            if lastHapticValue != clamped {
                lastHapticValue = clamped
                UnboundHaptics.tick()
            }
        }
    }
}

#Preview("Slider") {
    VStack(spacing: 40) {
        StatefulPreview()
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}

private struct StatefulPreview: View {
    @State private var diet: Int = 5
    @State private var sleep: Int = 7
    @State private var commit: Int = 8

    var body: some View {
        VStack(spacing: 36) {
            UnboundSlider(value: $diet, minLabel: "Poor", maxLabel: "Excellent")
            UnboundSlider(value: $sleep, minLabel: "Terrible", maxLabel: "Restorative")
            UnboundSlider(value: $commit, minLabel: "Curious", maxLabel: "All in")
        }
    }
}
