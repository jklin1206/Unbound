import SwiftUI

struct HUDSlider: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10
    /// Semantic labels for each value in the range. Length must equal `range.count`.
    /// Index 0 maps to `range.lowerBound`. e.g. for 1...10 you pass 10 strings.
    var descriptors: [String]
    /// Short bottom-row framing for the endpoints. Optional — renders under the track dimmed.
    var leftAnchor: String? = nil
    var rightAnchor: String? = nil

    @State private var lastHapticValue: Int? = nil
    private let dotSize: CGFloat = 6
    private let handleSize: CGFloat = 28
    private let trackHeight: CGFloat = 4

    var body: some View {
        VStack(spacing: 28) {
            descriptorBlock

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let fraction = progress()
                let handleX = CGFloat(fraction) * totalWidth

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.borderSubtle)
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.unbound.accent.opacity(0.7), Color.unbound.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(handleX, 2), height: trackHeight)
                        .shadow(color: Color.unbound.accent.opacity(0.5), radius: 6)

                    ForEach(range, id: \.self) { tick in
                        let tickFraction = fractionFor(tick)
                        let tickX = CGFloat(tickFraction) * totalWidth
                        let isFilled = tick <= value
                        Circle()
                            .fill(isFilled ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                            .frame(width: dotSize, height: dotSize)
                            .offset(x: tickX - dotSize / 2)
                    }

                    HUDHexagon()
                        .fill(Color.unbound.accent)
                        .frame(width: handleSize, height: handleSize - 2)
                        .overlay(
                            HUDHexagon()
                                .stroke(Color.unbound.textPrimary.opacity(0.9), lineWidth: 1.5)
                        )
                        .shadow(color: Color.unbound.accent.opacity(0.6), radius: 12)
                        .shadow(color: Color.unbound.impact.opacity(0.35), radius: 22)
                        .offset(x: handleX - handleSize / 2)
                        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: value)
                }
                .frame(height: handleSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            updateValue(from: drag.location.x, totalWidth: totalWidth)
                        }
                        .onEnded { _ in
                            lastHapticValue = nil
                            UnboundHaptics.medium()
                        }
                )
            }
            .frame(height: handleSize)

            if leftAnchor != nil || rightAnchor != nil {
                HStack {
                    Text((leftAnchor ?? "").uppercased())
                        .font(Font.unbound.monoS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Text((rightAnchor ?? "").uppercased())
                        .font(Font.unbound.monoS)
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
        }
    }

    private var descriptorBlock: some View {
        VStack(spacing: 6) {
            Text(currentDescriptor.uppercased())
                .font(Font.unbound.displayM)
                .tracking(2)
                .foregroundStyle(Color.unbound.textPrimary)
                .animeGlow(color: Color.unbound.accent, radius: 18, intensity: 0.7)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
                .multilineTextAlignment(.center)

            Text("\(value) / \(range.upperBound)")
                .font(Font.unbound.monoS)
                .tracking(2)
                .foregroundStyle(Color.unbound.textTertiary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentDescriptor: String {
        let idx = value - range.lowerBound
        guard idx >= 0 && idx < descriptors.count else { return "" }
        return descriptors[idx]
    }

    private func progress() -> Double {
        fractionFor(value)
    }

    private func fractionFor(_ tick: Int) -> Double {
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
                UnboundHaptics.soft()
            }
        }
    }
}

// Curated descriptor sets per domain — callers use these as single source of truth.
extension HUDSlider {
    static let sleepDescriptors = [
        "Wrecked", "Rough", "Poor", "Patchy",
        "Mixed", "Okay", "Solid", "Rested",
        "Deep", "Peak"
    ]
    static let stressDescriptors = [
        "Calm", "Loose", "Steady", "Mild",
        "Tight", "Wound up", "Strained", "Under pressure",
        "Maxed out", "Burned out"
    ]
    static let dietDescriptors = [
        "Chaos", "Inconsistent", "Sloppy", "Uneven",
        "Mixed", "Decent", "Clean", "Locked in",
        "Dialed", "Peak fuel"
    ]
    static let commitmentDescriptors = [
        "Curious", "Browsing", "Testing", "Warming up",
        "Showing up", "In the door", "Locked in", "Serious",
        "No excuses", "All in"
    ]
}

#Preview("HUDSlider") {
    StatefulHUDSliderPreview()
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulHUDSliderPreview: View {
    @State private var a: Int = 5
    @State private var b: Int = 8

    var body: some View {
        VStack(spacing: 40) {
            HUDSlider(value: $a, descriptors: HUDSlider.sleepDescriptors,
                      leftAnchor: "Restless", rightAnchor: "Restored")
            HUDSlider(value: $b, descriptors: HUDSlider.commitmentDescriptors,
                      leftAnchor: "Curious", rightAnchor: "All in")
        }
    }
}
