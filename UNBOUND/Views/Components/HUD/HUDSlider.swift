import SwiftUI

struct HUDSlider: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10
    /// Optional discrete stored values. Use this when the model still wants
    /// coarse-grained 1...10 inputs but onboarding should only show a few stops.
    var steps: [Int]? = nil
    /// Semantic labels for each visible stop. With `steps`, length should match
    /// `steps.count`; otherwise it should match `range.count`.
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

                    ForEach(Array(tickValues.enumerated()), id: \.element) { index, tick in
                        let tickFraction = fractionFor(tick)
                        let tickX = CGFloat(tickFraction) * totalWidth
                        let isFilled = index <= currentStepIndex
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

            Text("\(currentStepIndex + 1) / \(tickValues.count)")
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
        let idx = currentStepIndex
        guard idx >= 0 && idx < descriptors.count else { return "" }
        return descriptors[idx]
    }

    private func progress() -> Double {
        fractionFor(tickValues[currentStepIndex])
    }

    private func fractionFor(_ tick: Int) -> Double {
        let values = tickValues
        guard steps != nil else {
            let span = Double(range.upperBound - range.lowerBound)
            guard span > 0 else { return 0 }
            return Double(tick - range.lowerBound) / span
        }
        let span = Double(max(values.count - 1, 1))
        guard let idx = values.firstIndex(of: tick) else { return 0 }
        guard span > 0 else { return 0 }
        return Double(idx) / span
    }

    private var tickValues: [Int] {
        steps ?? Array(range)
    }

    private var currentStepIndex: Int {
        let values = tickValues
        guard let first = values.first else { return 0 }
        var bestIndex = 0
        var bestDistance = abs(value - first)
        for (index, candidate) in values.enumerated() {
            let distance = abs(value - candidate)
            if distance < bestDistance {
                bestIndex = index
                bestDistance = distance
            }
        }
        return bestIndex
    }

    private func storedValue(forStepIndex index: Int) -> Int {
        let values = tickValues
        guard !values.isEmpty else { return value }
        return values[max(0, min(values.count - 1, index))]
    }

    private func stepIndex(for fraction: Double) -> Int {
        let span = Double(max(tickValues.count - 1, 1))
        return Int((fraction * span).rounded())
    }

    private func legacyValue(for fraction: Double) -> Int {
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        let raw = Double(range.lowerBound) + fraction * span
        return Int(raw.rounded())
    }

    private func updateValue(from x: CGFloat, totalWidth: CGFloat) {
        guard totalWidth > 0 else { return }
        let clampedX = max(0, min(totalWidth, x))
        let fraction = Double(clampedX / totalWidth)
        let snapped = steps == nil ? legacyValue(for: fraction) : storedValue(forStepIndex: stepIndex(for: fraction))
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
        "Wrecked", "Rough", "Okay", "Rested", "Peak"
    ]
    static let stressDescriptors = [
        "Calm", "Manageable", "Tense", "Pressed", "Burned out"
    ]
    static let dietDescriptors = [
        "Chaos", "Inconsistent", "Decent", "Clean", "Locked in"
    ]
    static let commitmentDescriptors = [
        "Curious", "Testing", "Showing up", "Serious", "All in"
    ]

    static let fivePointStoredSteps = [2, 4, 6, 8, 10]
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
