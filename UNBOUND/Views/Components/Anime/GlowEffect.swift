import SwiftUI

struct GlowEffectModifier: ViewModifier {
    var color: Color = Color.unbound.accent
    var radius: CGFloat = 20
    var intensity: Double = 1.0
    var pulses: Bool = false

    func body(content: Content) -> some View {
        let base = content
            .shadow(color: color.opacity(0.55 * intensity), radius: radius * 0.4, x: 0, y: 0)
            .shadow(color: color.opacity(0.40 * intensity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.25 * intensity), radius: radius * 2.0, x: 0, y: 0)

        if pulses {
            base.modifier(PulseModifier())
        } else {
            base
        }
    }
}

private struct PulseModifier: ViewModifier {
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulse ? 1.015 : 1.0)
            .opacity(pulse ? 1.0 : 0.92)
            .animation(
                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}

extension View {
    func animeGlow(
        color: Color = Color.unbound.accent,
        radius: CGFloat = 20,
        intensity: Double = 1.0,
        pulses: Bool = false
    ) -> some View {
        modifier(GlowEffectModifier(color: color, radius: radius, intensity: intensity, pulses: pulses))
    }
}

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 40) {
            Text("UNBOUND")
                .font(Font.unbound.displayL)
                .foregroundStyle(Color.unbound.textPrimary)
                .animeGlow(color: Color.unbound.accent, radius: 24)
            Circle()
                .fill(Color.unbound.impact)
                .frame(width: 80, height: 80)
                .animeGlow(color: Color.unbound.impact, radius: 40, pulses: true)
        }
    }
}
