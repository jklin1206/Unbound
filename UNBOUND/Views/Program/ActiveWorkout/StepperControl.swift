import SwiftUI

/// Big glove-friendly numeric stepper. Tap value to type; ▲/▼ step;
/// one `tick` haptic per increment.
struct StepperControl: View {
    let label: String
    @Binding var value: Double
    var step: Double
    var unit: String?
    var allowsDecimal: Bool

    @State private var typing = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(label.uppercased())
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textTertiary)
                .tracking(1.5)

            HStack(spacing: 18) {
                stepButton(system: "minus", delta: -step)

                Group {
                    if typing {
                        TextField("", text: $draft)
                            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focused)
                            .onSubmit(commit)
                            .onChange(of: focused) { _, isFocused in
                                if !isFocused { commit() }
                            }
                    } else {
                        Text(display)
                            .contentTransition(.numericText())
                            .onTapGesture {
                                draft = display
                                typing = true
                                focused = true
                                UnboundHaptics.soft()
                            }
                    }
                }
                .font(Font.unbound.monoXL)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(minWidth: 132)

                stepButton(system: "plus", delta: step)
            }

            if let unit {
                Text(unit)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var display: String {
        guard allowsDecimal else { return String(Int(value)) }
        if abs(value - value.rounded()) < 0.005 {
            return String(format: "%.0f", value)
        }
        if abs((value * 10).rounded() - value * 10) < 0.005 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private func commit() {
        if let n = Double(draft.replacingOccurrences(of: ",", with: ".")) {
            value = max(0, n)
        }
        typing = false
    }

    private func stepButton(system: String, delta: Double) -> some View {
        Button {
            value = max(0, value + delta)
            UnboundHaptics.tick()
        } label: {
            Image(systemName: system)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.unbound.surfaceElevated))
                .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Decrease \(label)" : "Increase \(label)")
    }
}
