import SwiftUI

/// Animated ember glow. Three states:
/// - `.dormant`  — cold, dim grey, slow 2s pulse (sealed / before)
/// - `.active`   — alive violet, faster 1s pulse (ignited)
/// - `.igniting` — reserved transition state; renders like `.active` for now
///
/// Used across onboarding as a core visual motif:
/// baseline silhouette chest, chapter card ignition, stage card runes.
struct EmberView: View {
    enum State {
        case dormant
        case active
        case igniting
    }

    var state: State = .dormant
    var size: CGFloat = 24

    // Disambiguate from our own `State` enum above.
    @SwiftUI.State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Outer halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [haloColor.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 1.4
                    )
                )
                .frame(width: size * 2.8, height: size * 2.8)
                .opacity(pulse ? 1.0 : 0.55)

            // Core
            Circle()
                .fill(coreColor)
                .frame(width: size * 0.55, height: size * 0.55)
                .blur(radius: 2)
                .opacity(pulse ? 1.0 : 0.75)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: pulseDuration)
                    .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }

    // MARK: - State-driven styling

    private var pulseDuration: Double {
        switch state {
        case .dormant: return 2.0
        case .active, .igniting: return 1.0
        }
    }

    private var coreColor: Color {
        switch state {
        case .dormant: return Color.gray.opacity(0.5)
        case .active, .igniting: return Color.unbound.accent
        }
    }

    private var haloColor: Color {
        switch state {
        case .dormant: return Color.gray
        case .active, .igniting: return Color.unbound.accent
        }
    }
}

#Preview("Ember — dormant vs active") {
    HStack(spacing: 48) {
        EmberView(state: .dormant, size: 40)
        EmberView(state: .active, size: 40)
    }
    .frame(width: 400, height: 200)
    .background(Color.unbound.bg)
}
