import SwiftUI

struct SetLogGridRow: View {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let rpe: Int?
    let logged: Bool
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onPickRPE: () -> Void
    let onLog: () -> Void

    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 20, alignment: .leading)

            cell(text: weightKg.map(Self.fmt) ?? "—", action: onEditWeight)
            cell(text: reps.map(String.init) ?? "—", action: onEditReps)

            Button(action: onPickRPE) {
                Text(rpe.map(String.init) ?? "—")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(rpe == nil ? Color.unbound.textTertiary : Color.unbound.accent)
                    .frame(width: 44)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            Button {
                onLog()
                UnboundHaptics.success()
                if !reduceMotion {
                    pop = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { pop = false }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(logged ? Color.unbound.accent : Color.clear)
                        .overlay(Circle().strokeBorder(
                            logged ? Color.clear : Color.unbound.textTertiary, lineWidth: 1.5))
                        .frame(width: 30, height: 30)
                    if logged {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.unbound.bg)
                    }
                }
                .scaleEffect(pop && !reduceMotion ? 1.18 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pop)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .accessibilityLabel(logged ? "Set \(setNumber) logged" : "Log set \(setNumber)")
        }
        .padding(.vertical, 8)
    }

    private func cell(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Font.unbound.monoM)
                .foregroundStyle(text == "—" ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    private static func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}
