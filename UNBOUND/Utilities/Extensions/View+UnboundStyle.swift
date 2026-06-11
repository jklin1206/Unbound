import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Style Modifiers
//
// Shared ViewModifiers that enforce the Premium Hollow design language.
// Use these everywhere in the new onboarding flow instead of hand-rolling
// shadows, borders, and backgrounds — drives visual consistency.

// MARK: Card surface

struct UnboundCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.unbound.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.thinMaterial)
                            .opacity(0.12)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isPressed ? Color.unbound.accent : Color.unbound.border,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isPressed
                    ? Color.unbound.accent.opacity(0.25)
                    : Color.black.opacity(0.35),
                radius: isPressed ? 14 : 18,
                x: 0,
                y: isPressed ? 0 : 8
            )
    }
}

extension View {
    func unboundCard(cornerRadius: CGFloat = 16, isPressed: Bool = false) -> some View {
        modifier(UnboundCardStyle(cornerRadius: cornerRadius, isPressed: isPressed))
    }
}

// MARK: Pressable — tracks press state + delivers heavy haptic

struct UnboundPressableStyle: ViewModifier {
    @State private var isPressed: Bool = false
    var onTap: () -> Void

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            UnboundHaptics.soft()
                        }
                    }
                    .onEnded { value in
                        isPressed = false
                        let extent = max(abs(value.translation.width), abs(value.translation.height))
                        if extent < 12 {
                            UnboundHaptics.medium()
                            onTap()
                        }
                    }
            )
    }
}

extension View {
    /// Wraps a view in a press-tracking gesture with tactile haptics.
    /// Prefer this over `Button` when the view isn't a standard button shape.
    func unboundPressable(onTap: @escaping () -> Void) -> some View {
        modifier(UnboundPressableStyle(onTap: onTap))
    }
}

// MARK: Hero gradient — the single permitted vertical fade

struct UnboundHeroFade: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [Color.unbound.surface, Color.unbound.bg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    /// Use ONLY on hero / splash / processing / verdict screens.
    /// Never stack multiple hero fades.
    func heroVerticalFade() -> some View {
        modifier(UnboundHeroFade())
    }
}

// MARK: Premium shadow — for floating primary buttons

extension View {
    func premiumShadow(intensity: CGFloat = 1.0) -> some View {
        self.shadow(
            color: Color.black.opacity(0.45 * intensity),
            radius: 20 * intensity,
            x: 0,
            y: 12 * intensity
        )
    }
}

// MARK: Haptics

enum UnboundHaptics {
    /// Soft touch — on initial press contact
    static func soft() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Medium — on standard tap release
    static func medium() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Heavy — for impactful moments: archetype selection, processing complete, rank reveal
    static func heavy() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Rigid — for ticks in sliders and pickers (short and crisp)
    static func tick() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.7)
    }

    /// Success notification — for completion moments
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
}
