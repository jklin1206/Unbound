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
    /// If set, this option is promoted to the top as an umbrella row.
    /// Tapping it selects every other option. Tapping any child deselects it.
    var umbrella: T? = nil
    /// Caption shown under the umbrella row (falls back to the normal subtitle).
    var umbrellaSubtitle: String? = nil

    private var children: [T] {
        guard let umbrella else { return options }
        return options.filter { $0 != umbrella }
    }

    private var umbrellaActive: Bool {
        guard let umbrella else { return false }
        return selection.contains(umbrella)
    }

    var body: some View {
        VStack(spacing: 12) {
            if let umbrella {
                HUDUmbrellaRow(
                    title: title(umbrella),
                    subtitle: umbrellaSubtitle ?? subtitle(umbrella),
                    icon: icon(umbrella),
                    isActive: umbrellaActive
                ) {
                    toggleUmbrella(umbrella)
                }
            }

            ForEach(Array(children.enumerated()), id: \.element) { idx, option in
                HUDMultiSelectRow(
                    index: idx + 1,
                    title: title(option),
                    subtitle: subtitle(option),
                    icon: icon(option),
                    isSelected: selection.contains(option)
                ) {
                    toggleChild(option)
                }
                .opacity(umbrellaActive ? 0.55 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: umbrellaActive)
            }
        }
    }

    private func toggleUmbrella(_ umbrella: T) {
        if selection.contains(umbrella) {
            selection.removeAll()
        } else {
            selection = Set(options)
        }
    }

    private func toggleChild(_ option: T) {
        if let umbrella, selection.contains(umbrella) {
            selection.remove(umbrella)
        }
        if selection.contains(option) {
            selection.remove(option)
        } else {
            selection.insert(option)
        }
    }
}

// MARK: - Umbrella row

/// Full-width emphasized row that sits above a multi-select group and implies
/// "select everything below." Styling deliberately distinct from standard
/// rows — taller, subtle ember accent when active — so users read it as a
/// different kind of choice, not just another option.
private struct HUDUmbrellaRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let isActive: Bool
    let onTap: () -> Void

    @State private var pressScale: CGFloat = 1.0

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 18) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isActive ? Color.unbound.ember : Color.unbound.textSecondary)
                        .frame(width: 36)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Font.unbound.titleM)
                        .foregroundStyle(Color.unbound.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                indicator
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isActive ? Color.unbound.surfaceElevated : Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.unbound.ember : Color.unbound.border,
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
            .shadow(
                color: isActive ? Color.unbound.ember.opacity(0.35) : .clear,
                radius: 16, x: 0, y: 0
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressScale)
    }

    private var indicator: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isActive ? Color.unbound.ember : Color.unbound.border,
                    lineWidth: 1.25
                )
                .frame(width: 26, height: 26)
            if isActive {
                Circle()
                    .fill(Color.unbound.ember)
                    .frame(width: 14, height: 14)
            }
        }
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
