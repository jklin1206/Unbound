import SwiftUI

// MARK: - OnboardingBackdrop
//
// Atmospheric scene art behind onboarding / paywall screens so they read like
// stepping into a world, not filling out a form. A vertical scrim keeps the
// content legible: darkest at top (headlines) and bottom (CTAs), letting the
// art breathe through the middle. Tune `top/middle/bottom` per surface — light
// scrim for hero moments (paywall, promo), heavier for text-dense form steps.
//
// Default art `onboarding_path_open_gate` is a hero at a glowing portal: dark
// arches up top, bright portal low-centre — which is exactly why the scrim
// shape below works without washing the art out.

struct OnboardingBackdrop: View {
    var image: String = "onboarding_path_open_gate"
    var top: Double = 0.52
    var middle: Double = 0.16
    var bottom: Double = 0.9
    /// A faint accent bloom at the top, matching the app's other surfaces.
    var glow: Bool = true

    var body: some View {
        ZStack {
            Color.unbound.bg

            // Pinned behind Color.clear + clipped: a bare scaledToFill Image
            // proposes its overflow width upward and inflates the whole
            // screen's layout (buttons pushed off-screen, full-bleed cards).
            Color.clear
                .overlay(
                    Image(image)
                        .resizable()
                        .scaledToFill()
                )
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.unbound.bg.opacity(top), location: 0.0),
                    .init(color: Color.unbound.bg.opacity(middle), location: 0.42),
                    .init(color: Color.unbound.bg.opacity(bottom), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if glow {
                RadialGradient(
                    colors: [Color.unbound.accent.opacity(0.12), Color.clear],
                    center: .top, startRadius: 20, endRadius: 420
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
