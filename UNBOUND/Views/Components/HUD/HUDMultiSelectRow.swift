import SwiftUI

struct HUDMultiSelectRow: View {
    let index: Int
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let onTap: () -> Void

    @State private var pressScale: CGFloat = 1.0

    var body: some View {
        Button(action: handleTap) {
            HUDPanel(isActive: isSelected, pulse: false) {
                HStack(spacing: 16) {
                    Text(String(format: "%02d", index))
                        .font(Font.unbound.monoS)
                        .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textTertiary)
                        .frame(width: 28, alignment: .leading)

                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isSelected ? Color.unbound.accent : Color.unbound.textSecondary)
                            .frame(width: 22)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Font.unbound.titleS)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .multilineTextAlignment(.leading)
                        if let subtitle {
                            Text(subtitle)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 8)

                    checkboxIndicator
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(HUDMultiSelectRowButtonStyle())
        .scaleEffect(pressScale)
    }

    private var checkboxIndicator: some View {
        ZStack {
            if isSelected {
                HUDHexagon()
                    .fill(Color.unbound.accent)
                    .frame(width: 26, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.unbound.textPrimary)
                    )
                    .animeGlow(color: Color.unbound.accent, radius: 10, intensity: 0.8)
            } else {
                HUDHexagon()
                    .stroke(Color.unbound.border, lineWidth: 1.25)
                    .frame(width: 26, height: 24)
            }
        }
        .frame(width: 28, height: 28)
    }

    private func handleTap() {
        UnboundHaptics.medium()
        withAnimation(.easeOut(duration: 0.12)) {
            pressScale = 0.98
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                pressScale = 1.0
            }
        }
        onTap()
    }
}

private struct HUDMultiSelectRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1.0)
    }
}

struct HUDMultiSelectGroup<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: Set<T>
    let title: (T) -> String
    var subtitle: (T) -> String? = { _ in nil }
    var icon: (T) -> String? = { _ in nil }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(options.enumerated()), id: \.element) { idx, option in
                HUDMultiSelectRow(
                    index: idx + 1,
                    title: title(option),
                    subtitle: subtitle(option),
                    icon: icon(option),
                    isSelected: selection.contains(option)
                ) {
                    if selection.contains(option) {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                }
            }
        }
    }
}

#Preview("Multi") {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 12) {
            HUDMultiSelectRow(index: 1, title: "Full gym", subtitle: "Barbells, machines, racks", icon: "dumbbell.fill", isSelected: true, onTap: {})
            HUDMultiSelectRow(index: 2, title: "Home weights", subtitle: "Dumbbells or kettlebells", icon: "figure.strengthtraining.traditional", isSelected: false, onTap: {})
            HUDMultiSelectRow(index: 3, title: "Just bodyweight", subtitle: "Nothing but the floor", icon: "figure.run", isSelected: true, onTap: {})
        }
        .padding()
    }
}
