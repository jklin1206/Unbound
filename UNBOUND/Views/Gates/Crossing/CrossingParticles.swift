import SwiftUI

/// Native SwiftUI particle layer for the investiture/arrival beats (spec §9:
/// "minor beats = native SwiftUI particles"). Color-keyed to the destination
/// rank tint — never a hardcoded color (Color Design Check §1). Reduced-motion
/// renders a single static glow instead of moving particles.
struct CrossingParticles: View {
    let tint: Color
    var reduceMotion: Bool = false
    var particleCount: Int = 28

    var body: some View {
        if reduceMotion {
            RadialGradient(colors: [tint.opacity(0.35), .clear],
                           center: .center, startRadius: 10, endRadius: 280)
                .blendMode(.screen)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for i in 0..<particleCount {
                        let seed = Double(i)
                        let phase = (t * 0.35 + seed * 0.137).truncatingRemainder(dividingBy: 1)
                        let x = size.width * (0.5 + 0.42 * sin(seed * 2.4))
                        let y = size.height * (1.0 - phase) - 20
                        let radius = 2.0 + 3.0 * (1 - phase)
                        let opacity = max(0, sin(phase * .pi)) * 0.7
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
