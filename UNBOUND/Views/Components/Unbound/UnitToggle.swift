import SwiftUI

// MARK: - UnitToggle

struct UnitToggle: View {
    let leftLabel: String
    let rightLabel: String
    @Binding var isRight: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment(label: leftLabel, active: !isRight) { isRight = false }
            segment(label: rightLabel, active: isRight) { isRight = true }
        }
        .padding(3)
        .background(Capsule().fill(Color.unbound.surface))
        .overlay(Capsule().strokeBorder(Color.unbound.border, lineWidth: 1))
    }

    @ViewBuilder
    private func segment(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            UnboundHaptics.medium()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                action()
            }
        }) {
            Text(label)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(active ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .frame(minWidth: 72)
                .background(
                    Capsule().fill(active ? Color.unbound.accent.opacity(0.18) : Color.clear)
                )
                .overlay(
                    Capsule().strokeBorder(active ? Color.unbound.accent : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Unit toggle") {
    StatefulUnitTogglePreview()
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulUnitTogglePreview: View {
    @State private var useMetric: Bool = false
    var body: some View {
        UnitToggle(leftLabel: "cm", rightLabel: "ft", isRight: $useMetric)
    }
}
