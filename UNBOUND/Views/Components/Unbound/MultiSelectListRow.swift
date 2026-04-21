import SwiftUI

// MARK: - MultiSelectListRow
//
// Full-width card row for multi-select (equipment, obstacles, motivations,
// prior attempts). Visually matches SelectionListRow but uses a checkbox
// indicator instead of a radio. Card feels locked-in and present —
// the premium alternative to pill-chip grids.

struct MultiSelectListRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            isSelected ? Color.unbound.accent : Color.unbound.textSecondary
                        )
                        .frame(width: 24)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Font.unbound.bodyLStrong)
                        .foregroundStyle(Color.unbound.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                checkIndicator
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.unbound.accent : Color.unbound.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? Color.unbound.accent.opacity(0.25)
                    : Color.black.opacity(0.3),
                radius: isSelected ? 12 : 10,
                x: 0,
                y: isSelected ? 0 : 6
            )
            .scaleEffect(isPressed ? 0.98 : (isSelected ? 1.01 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isSelected)
            .animation(.spring(response: 0.24, dampingFraction: 0.75), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(
            PressableCardStyle(
                isPressed: $isPressed,
                onPressBegin: { UnboundHaptics.soft() },
                onPressRelease: { UnboundHaptics.medium() }
            )
        )
    }

    // MARK: Check indicator — square with rounded corners for multi-select

    private var checkIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.unbound.accent : Color.clear)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.unbound.accent : Color.unbound.border,
                    lineWidth: 1.5
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 22)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

// MARK: - MultiSelectListGroup — convenience wrapper

struct MultiSelectListGroup<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: Set<T>
    let title: (T) -> String
    var subtitle: (T) -> String? = { _ in nil }
    var icon: (T) -> String? = { _ in nil }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options) { option in
                MultiSelectListRow(
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

#Preview("MultiSelectListRow") {
    StatefulMultiPreview()
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulMultiPreview: View {
    @State private var selected: Set<Equipment> = [.fullGym, .homeWeights]
    var body: some View {
        MultiSelectListGroup(
            options: Equipment.allCases,
            selection: $selected,
            title: { $0.displayName },
            icon: { $0.icon }
        )
    }
}
