import SwiftUI

struct SetLogGridRow: View {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let effort: Effort?
    let logged: Bool
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onLog: () -> Void
    let onCycleEffort: () -> Void

    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            Text("\(setNumber)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 22, alignment: .leading)

            cell(text: weightKg.map(Self.fmt) ?? "—", action: onEditWeight)
            cell(text: reps.map(String.init) ?? "—", action: onEditReps)

            Button {
                if logged {
                    onCycleEffort()
                    HapticManager.selection()
                } else {
                    onLog()
                    HapticManager.notification(.success)
                    if !reduceMotion {
                        pop = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { pop = false }
                    }
                }
            } label: {
                Circle()
                    .fill(logged ? dotColor : Color.clear)
                    .overlay(Circle().strokeBorder(
                        logged ? Color.clear : Color.unbound.textTertiary, lineWidth: 1.5))
                    .frame(width: 28, height: 28)
                    .scaleEffect(pop && !reduceMotion ? 1.18 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pop)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .accessibilityLabel(logged ? "Set \(setNumber) effort" : "Log set \(setNumber)")
        }
        .padding(.vertical, 8)
    }

    private var dotColor: Color {
        switch effort ?? .solid {
        case .easy:  return Color.unbound.success
        case .solid: return Color.unbound.warnOrange
        case .hard:  return Color.unbound.alert
        }
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
