import SwiftUI

/// Premium horizontal ruler picker. Drags under a fixed center needle with
/// a violet chevron marker. Tick hierarchy has real depth — major ticks
/// (every `majorEvery` units) carry labels + a taller, thicker stroke;
/// minor ticks are short and dim. Major crossings fire a medium haptic,
/// minor crossings fire a subtle tick.
///
/// Value readout is decoupled from raw integer: pass a `format` closure if
/// you want "5'11"" instead of "71" while still operating on integer inches
/// internally.
struct RulerPicker: View {
    let range: ClosedRange<Int>
    @Binding var value: Int
    /// Short unit label shown to the right of the numeric readout (e.g.
    /// `CM`, `KG`, `LB`). Pass empty string to hide.
    var unitLabel: String = ""
    /// Custom formatter for the big readout. Default renders the raw int.
    /// Used by the height screen to render feet-and-inches from an
    /// underlying total-inches value.
    var format: (Int) -> String = { "\($0)" }
    /// Custom formatter for the tick labels (majors only). Default renders
    /// the raw int. Height screen uses this to show `5'` / `6'` on the
    /// major ticks while minor ticks stay unlabeled.
    var tickLabel: (Int) -> String = { "\($0)" }
    var majorEvery: Int = 10
    var tickSpacing: CGFloat = 14

    @State private var isDragging = false
    @State private var dragStartValue: Int? = nil
    @State private var lastHapticValue: Int = .min

    var body: some View {
        VStack(spacing: 20) {
            valueReadout

            rulerBody
                .frame(height: 132)
        }
        .onChange(of: value) { _, newValue in
            maybeHaptic(for: newValue)
        }
    }

    private var valueReadout: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(format(value))
                .font(Font.unbound.displayL)
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: value)
            if !unitLabel.isEmpty {
                Text(unitLabel)
                    .font(Font.unbound.monoM)
                    .foregroundStyle(Color.unbound.accent)
                    .tracking(1.8)
            }
        }
    }

    private var rulerBody: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2

            ZStack {
                surface
                ticks(centerX: centerX)
                centerMarker
                edgeFade
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(centerX: centerX))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.unbound.border, lineWidth: 1)
            )
        }
    }

    private var surface: some View {
        LinearGradient(
            colors: [
                Color.unbound.surfaceElevated,
                Color.unbound.surface
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func ticks(centerX: CGFloat) -> some View {
        let minV = range.lowerBound
        let maxV = range.upperBound
        let offsetFromValue = CGFloat(value - minV) * tickSpacing

        ZStack {
            ForEach(minV...maxV, id: \.self) { i in
                let x = centerX + CGFloat(i - minV) * tickSpacing - offsetFromValue
                let isMajor = (i - minV) % majorEvery == 0
                let isCurrent = i == value
                let distance = abs(CGFloat(i - value)) * tickSpacing
                let fade = max(0.12, 1.0 - (distance / (centerX * 1.1)))

                tick(
                    x: x,
                    y: 56,
                    isMajor: isMajor,
                    isCurrent: isCurrent,
                    fade: fade,
                    label: isMajor ? tickLabel(i) : nil
                )
            }
        }
    }

    @ViewBuilder
    private func tick(
        x: CGFloat,
        y: CGFloat,
        isMajor: Bool,
        isCurrent: Bool,
        fade: Double,
        label: String?
    ) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    isCurrent
                        ? AnyShapeStyle(Color.unbound.accent)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: isMajor
                                    ? [Color.unbound.textSecondary, Color.unbound.textSecondary.opacity(0.7)]
                                    : [Color.unbound.border, Color.unbound.border.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .frame(
                    width: isMajor ? 2.5 : 1,
                    height: isMajor ? 44 : 20
                )
                .opacity(fade)
                .shadow(
                    color: isCurrent ? Color.unbound.accent.opacity(0.5) : .clear,
                    radius: 6
                )

            if let label {
                Text(label)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(
                        isCurrent ? Color.unbound.accent : Color.unbound.textTertiary
                    )
                    .opacity(fade)
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .position(x: x, y: y)
    }

    /// Center marker — a glowing violet needle with a chevron pointer at
    /// the top. Sits above the ticks, stays fixed while the ticks slide
    /// beneath it. This is the "your current value" anchor.
    private var centerMarker: some View {
        VStack(spacing: 0) {
            RulerChevron()
                .fill(Color.unbound.accent)
                .frame(width: 14, height: 8)
                .shadow(color: Color.unbound.accent.opacity(0.6), radius: 6)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.unbound.accent)
                .frame(width: 2.5, height: 70)
                .shadow(color: Color.unbound.accent.opacity(0.55), radius: 8)
                .shadow(color: Color.unbound.accent.opacity(0.35), radius: 16)
        }
    }

    /// Left + right edge gradient so ticks gently dissolve off the ruler
    /// instead of getting sliced by the border. Uses the surface color so
    /// it disappears cleanly into the card.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [Color.unbound.surfaceElevated, Color.unbound.surfaceElevated.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
            Spacer()
            LinearGradient(
                colors: [Color.unbound.surface.opacity(0), Color.unbound.surface],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 48)
        }
        .allowsHitTesting(false)
    }

    private func dragGesture(centerX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                isDragging = true
                if dragStartValue == nil { dragStartValue = value }
                let deltaUnits = Int((-drag.translation.width / tickSpacing).rounded())
                let proposed = (dragStartValue ?? value) + deltaUnits
                let clamped = min(max(proposed, range.lowerBound), range.upperBound)
                if clamped != value {
                    value = clamped
                }
            }
            .onEnded { _ in
                isDragging = false
                dragStartValue = nil
            }
    }

    private func maybeHaptic(for newValue: Int) {
        guard newValue != lastHapticValue else { return }
        lastHapticValue = newValue
        if (newValue - range.lowerBound) % majorEvery == 0 {
            UnboundHaptics.medium()
        } else {
            UnboundHaptics.tick()
        }
    }
}

// MARK: - Shapes

private struct RulerChevron: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Metric") {
    StatefulRulerPreview(unit: "CM", majorEvery: 10, initial: 178)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

#Preview("Imperial — feet/inches") {
    StatefulHeightImperialPreview()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulRulerPreview: View {
    let unit: String
    let majorEvery: Int
    @State var value: Int
    init(unit: String, majorEvery: Int, initial: Int) {
        self.unit = unit
        self.majorEvery = majorEvery
        self._value = State(initialValue: initial)
    }
    var body: some View {
        RulerPicker(range: 140...220, value: $value, unitLabel: unit, majorEvery: majorEvery)
    }
}

private struct StatefulHeightImperialPreview: View {
    @State var inches: Int = 71
    var body: some View {
        RulerPicker(
            range: 54...86,
            value: $inches,
            unitLabel: "",
            format: { formatFeetInches($0) },
            tickLabel: { $0 % 12 == 0 ? "\($0 / 12)'" : "" },
            majorEvery: 12
        )
    }
    private func formatFeetInches(_ total: Int) -> String {
        let ft = total / 12
        let inch = total % 12
        return "\(ft)' \(inch)\""
    }
}
