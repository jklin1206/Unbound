import SwiftUI

/// The light behind a rank reveal: a tier-tinted radial bloom that breathes,
/// plus a double shockwave ring that expands outward the moment the badge
/// lands. Sits BEHIND the badge art — it never draws over it.
///
/// Static shadows read as chrome; this is the "the badge is emitting light"
/// treatment. Honors Reduce Motion: the bloom renders at rest and the
/// shockwave/breathing are skipped.
struct RankRevealBloom: View {
    let tint: Color
    /// Reveal trigger — flips once when the badge lands.
    let active: Bool
    /// Diameter of the badge art this bloom sits behind.
    var badgeSize: CGFloat = 172

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shockwave = false
    @State private var breathing = false

    private var bloomSize: CGFloat { badgeSize * 1.9 }

    var body: some View {
        ZStack {
            // Core bloom — soft radial light that slowly breathes.
            RadialGradient(
                colors: [
                    tint.opacity(0.55),
                    tint.opacity(0.18),
                    .clear
                ],
                center: .center,
                startRadius: badgeSize * 0.12,
                endRadius: bloomSize * 0.5
            )
            .frame(width: bloomSize, height: bloomSize)
            .scaleEffect(breathing ? 1.1 : 0.94)
            .opacity(active ? 1 : 0)
            .blur(radius: 6)

            // Shockwaves — two rings racing outward as the badge lands.
            if !reduceMotion {
                shockRing(delay: 0, maxScale: 1.55, width: 2.4)
                shockRing(delay: 0.12, maxScale: 1.95, width: 1.4)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: active) { _, on in if on { run() } }
        .onAppear { if active { run() } }
    }

    private func shockRing(delay: Double, maxScale: CGFloat, width: CGFloat) -> some View {
        Circle()
            .strokeBorder(tint.opacity(shockwave ? 0 : 0.75), lineWidth: width)
            .frame(width: badgeSize * 0.9, height: badgeSize * 0.9)
            .scaleEffect(shockwave ? maxScale : 0.72)
            .animation(.easeOut(duration: 0.9).delay(delay), value: shockwave)
    }

    private func run() {
        guard !reduceMotion else { return }
        shockwave = true
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }
}
