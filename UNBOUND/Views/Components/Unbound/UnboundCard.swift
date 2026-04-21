import SwiftUI

// MARK: - UnboundCard
//
// Generic surface card used for selection rows, content blocks, modals.
// Press state optionally delivered via isPressed binding (used by
// SelectionListRow, ArchetypePickerCard, etc.). For standalone cards
// that don't track press, just pass isPressed: false.

struct UnboundCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 20
    var isPressed: Bool = false
    var isSelected: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor,
                radius: isPressed || isSelected ? 14 : 18,
                x: 0,
                y: isPressed || isSelected ? 0 : 8
            )
            .scaleEffect(isPressed ? 0.98 : (isSelected ? 1.02 : 1.0))
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isPressed)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isSelected)
    }

    private var borderColor: Color {
        if isSelected || isPressed {
            return Color.unbound.accent
        }
        return Color.unbound.border
    }

    private var borderWidth: CGFloat {
        (isSelected || isPressed) ? 1.5 : 1
    }

    private var shadowColor: Color {
        if isSelected {
            return Color.unbound.accent.opacity(0.3)
        }
        if isPressed {
            return Color.unbound.accent.opacity(0.2)
        }
        return Color.black.opacity(0.4)
    }
}

#Preview("Cards") {
    VStack(spacing: 16) {
        UnboundCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Default")
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text("Idle state. Soft shadow, subtle border.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        UnboundCard(isPressed: true) {
            Text("Pressed").font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
        }
        UnboundCard(isSelected: true) {
            Text("Selected").font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
