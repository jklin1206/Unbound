import SwiftUI

// Persistent visual layer shared across every onboarding step. Sits above
// the base bg color and below the step content, so bare steps (text pickers,
// selection lists) feel alive while the heavier cinematic steps (Arc01, Arc03)
// naturally cover it with their own backgrounds.
//
// Intensity scales every element, so callers can dial the atmosphere up as
// the user progresses through onboarding (e.g. 0.8 early → 1.3 late).

struct OnboardingAtmosphere: View {
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            godRayGlow
            emberLayer
            vignette
        }
        .allowsHitTesting(false)
    }

    // Soft purple radial from upper-center. Uses `.screen` blend so it adds
    // light rather than replacing color, which keeps the dark palette intact.
    private var godRayGlow: some View {
        RadialGradient(
            colors: [
                Color.unbound.accent.opacity(0.10 * intensity),
                Color.unbound.accent.opacity(0.04 * intensity),
                .clear
            ],
            center: UnitPoint(x: 0.5, y: 0.32),
            startRadius: 20,
            endRadius: 520
        )
        .ignoresSafeArea()
        .blendMode(.screen)
    }

    // Dim embers drifting upward. Runs the same ParticleEmitter used in the
    // Arc01 opening — shared config keeps the visual language consistent.
    private var emberLayer: some View {
        ParticleEmitter(config: .embers, isActive: true)
            .opacity(0.22 * intensity)
            .ignoresSafeArea()
    }

    // Edge darkening so content near the center reads with more authority.
    private var vignette: some View {
        RadialGradient(
            colors: [
                .clear,
                Color.black.opacity(0.45)
            ],
            center: .center,
            startRadius: 240,
            endRadius: 640
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        OnboardingAtmosphere()
    }
}
