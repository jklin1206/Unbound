import SwiftUI

// MARK: - PressableCardStyle
//
// Shared ButtonStyle used by all selectable cards / chips / primary buttons
// in the onboarding flow.
//
// Why a ButtonStyle (and not a DragGesture + onTapGesture recipe):
//   SwiftUI `Button` defers to an enclosing `ScrollView` during gesture
//   arbitration — a vertical finger drag starting on a button becomes a
//   scroll, only taps that stay put fire the action. A custom
//   `DragGesture(minimumDistance: 0)` attached via `.gesture(...)` claims
//   the touch immediately and blocks scrolling wherever the finger lands.
//   That was the clunky "can't scroll over cards" bug.
//
// How the existing press feel is preserved:
//   The style exposes `configuration.isPressed` via `PressStateObserver`,
//   which mirrors it into a `@Binding<Bool>` owned by the card. The card
//   then drives its existing spring scale + shadow animations and fires
//   the same soft/medium/heavy haptics it fired before.

struct PressableCardStyle: ButtonStyle {
    /// Pushed into the parent view so it can drive its own animations.
    @Binding var isPressed: Bool

    /// Fired on the leading edge of a press (for `UnboundHaptics.soft()`).
    var onPressBegin: (() -> Void)? = nil

    /// Fired on successful tap release (i.e. the Button action is about to run).
    /// Use this for the release haptic instead of doing it inside `action`
    /// so the haptic feels tied to the finger, not the state change.
    var onPressRelease: (() -> Void)? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                PressStateObserver(
                    isPressed: configuration.isPressed,
                    binding: $isPressed,
                    onPressBegin: onPressBegin,
                    onPressRelease: onPressRelease
                )
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            )
    }
}

// MARK: - PressStateObserver
//
// Bridges `ButtonStyle.Configuration.isPressed` (value-type, read-only) into
// a `@Binding<Bool>` the parent card owns. We also fire leading-edge and
// trailing-edge callbacks so the parent can play haptics at the right moments.

private struct PressStateObserver: View {
    let isPressed: Bool
    @Binding var binding: Bool
    var onPressBegin: (() -> Void)?
    var onPressRelease: (() -> Void)?

    var body: some View {
        Color.clear
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    onPressBegin?()
                } else if binding {
                    // Transitioning from pressed -> released.
                    onPressRelease?()
                }
                binding = newValue
            }
    }
}
