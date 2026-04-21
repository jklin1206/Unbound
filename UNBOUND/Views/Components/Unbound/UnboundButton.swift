import SwiftUI

// MARK: - UnboundButton
//
// Premium button in two variants:
//   - .primary   — filled subtle material, violet shadow on press, bone-white label
//   - .secondary — transparent + 1px border, inverts to violet border on press
//
// Spring press animation + heavy haptic on tap. Use this instead of SwiftUI's
// default Button so we own the look & feel end-to-end.

enum UnboundButtonVariant {
    case primary
    case secondary
}

struct UnboundButton: View {
    let title: String
    var variant: UnboundButtonVariant = .primary
    var icon: String? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(Font.unbound.bodyLStrong)
                    .tracking(0.2)
            }
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundView)
            .overlay(borderView)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(
                color: shadowColor,
                radius: isPressed ? 18 : 14,
                x: 0,
                y: isPressed ? 0 : 8
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .disabled(!isEnabled)
        .buttonStyle(
            PressableCardStyle(
                isPressed: $isPressed,
                onPressBegin: {
                    guard isEnabled else { return }
                    UnboundHaptics.soft()
                },
                onPressRelease: {
                    guard isEnabled else { return }
                    UnboundHaptics.medium()
                }
            )
        )
    }

    // MARK: Styling

    private var labelColor: Color {
        switch variant {
        case .primary:
            return Color.unbound.textPrimary
        case .secondary:
            return isPressed ? Color.unbound.accent : Color.unbound.textPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            ZStack {
                Color.unbound.surfaceElevated
                Rectangle().fill(.thinMaterial).opacity(0.18)
            }
        case .secondary:
            Color.clear
        }
    }

    private var borderView: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(
                isPressed ? Color.unbound.accent : Color.unbound.border,
                lineWidth: 1
            )
    }

    private var shadowColor: Color {
        if !isEnabled { return .clear }
        switch variant {
        case .primary:
            return isPressed
                ? Color.unbound.accent.opacity(0.35)
                : Color.black.opacity(0.45)
        case .secondary:
            return isPressed
                ? Color.unbound.accent.opacity(0.25)
                : .clear
        }
    }
}

#Preview("Button variants") {
    VStack(spacing: 20) {
        UnboundButton(title: "Begin", action: {})
        UnboundButton(title: "Continue", icon: "arrow.right", action: {})
        UnboundButton(title: "Skip", variant: .secondary, action: {})
        UnboundButton(title: "Disabled", isEnabled: false, action: {})
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
