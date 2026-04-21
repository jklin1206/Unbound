import SwiftUI

// MARK: - SelectionListRow
//
// Tappable card row for single-select list screens (fitness level, activity
// level, experience, frequency, session length, etc.). Shows title + optional
// subtitle + optional leading icon. Selected state = violet border + scale.
//
// Usage:
//   SelectionListRow(
//       title: "Beginner",
//       subtitle: "New or have only tried it for a bit",
//       icon: "leaf.fill",
//       isSelected: selection == .beginner,
//       action: { selection = .beginner }
//   )

struct SelectionListRow: View {
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

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.unbound.accent : Color.unbound.border,
                            lineWidth: 1.5
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.unbound.accent)
                            .frame(width: 12, height: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
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
                onPressRelease: {
                    if !isSelected { UnboundHaptics.medium() }
                }
            )
        )
    }
}

#Preview("SelectionListRow") {
    StatefulListPreview()
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.unbound.bg)
}

private struct StatefulListPreview: View {
    @State private var selection: String = "Intermediate"
    let options = [
        ("Beginner", "New or have only tried it for a bit", "leaf.fill"),
        ("Intermediate", "I've lifted weights before", "bolt.fill"),
        ("Advanced", "I've been lifting for a while", "flame.fill")
    ]
    var body: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.0) { option in
                SelectionListRow(
                    title: option.0,
                    subtitle: option.1,
                    icon: option.2,
                    isSelected: selection == option.0
                ) {
                    selection = option.0
                }
            }
        }
    }
}
