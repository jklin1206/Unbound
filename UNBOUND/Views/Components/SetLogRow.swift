import SwiftUI

// MARK: - SetLogRow
//
// A single row inside a WorkoutLoggingView exercise card: set number
// (tap to toggle warmup), weight input, reps input, RPE chip, optional
// delete. Styled to match the UNBOUND palette so the in-gym logging
// surface feels like the same app as the home dashboard.

struct SetLogRow: View {
    let setNumber: Int
    @Binding var weightKg: String
    @Binding var reps: String
    @Binding var rpe: Int?
    @Binding var isWarmup: Bool
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Set number / warmup toggle
            Button {
                isWarmup.toggle()
                UnboundHaptics.soft()
            } label: {
                Text(isWarmup ? "W" : "\(setNumber)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(
                        isWarmup ? Color.unbound.warnOrange : Color.unbound.textPrimary
                    )
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(
                            isWarmup
                                ? Color.unbound.warnOrange.opacity(0.18)
                                : Color.unbound.bg
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(
                            isWarmup
                                ? Color.unbound.warnOrange.opacity(0.45)
                                : Color.unbound.borderSubtle,
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)

            // Weight
            inputField(text: $weightKg, width: 60, keyboard: .decimalPad)

            // Reps
            inputField(text: $reps, width: 46, keyboard: .numberPad)

            // RPE
            Menu {
                ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                    Button("RPE \(value)") { rpe = value }
                }
                Button("Clear") { rpe = nil }
            } label: {
                Text(rpe.map { "\($0)" } ?? "—")
                    .font(Font.unbound.monoS.weight(.semibold))
                    .foregroundStyle(
                        rpe != nil ? Color.unbound.accent : Color.unbound.textTertiary
                    )
                    .monospacedDigit()
                    .frame(minWidth: 36)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.unbound.bg)
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
            }

            Spacer(minLength: 0)

            if let onDelete {
                Button {
                    UnboundHaptics.soft()
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func inputField(text: Binding<String>, width: CGFloat, keyboard: UIKeyboardType) -> some View {
        TextField("0", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(Font.unbound.monoM.weight(.semibold))
            .foregroundStyle(Color.unbound.textPrimary)
            .tint(Color.unbound.accent)
            .frame(width: width, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.unbound.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
    }
}
