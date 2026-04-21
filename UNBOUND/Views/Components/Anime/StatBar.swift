import SwiftUI

struct StatBar: View {
    let label: String
    var tier: String
    var value: Double
    var animate: Bool = true
    var muted: Bool = false
    var startDelay: Double = 0

    @State private var fillWidth: Double = 0
    @State private var sweepPhase: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(label)
                    .font(Font.unbound.captionS)
                    .tracking(1.4)
                    .foregroundStyle(muted ? Color.unbound.textTertiary : Color.unbound.textSecondary)
                Spacer()
                Text(tier)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(muted ? Color.unbound.textTertiary : Color.unbound.accent)
                    .frame(minWidth: 14, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.unbound.surfaceElevated)
                    Capsule()
                        .strokeBorder(Color.unbound.border, lineWidth: 0.5)

                    let clamped = max(0, min(1, fillWidth))
                    let w = geo.size.width * clamped

                    Capsule()
                        .fill(fillGradient)
                        .frame(width: w)
                        .overlay(
                            sweepOverlay(width: w)
                        )
                        .animeGlow(
                            color: muted ? Color.unbound.textTertiary : Color.unbound.accent,
                            radius: muted ? 4 : 12,
                            intensity: muted ? 0.3 : 0.8
                        )
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            guard animate else {
                fillWidth = value
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                    fillWidth = value
                }
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    sweepPhase = 1.0
                }
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                fillWidth = newValue
            }
        }
    }

    private var fillGradient: LinearGradient {
        if muted {
            return LinearGradient(
                colors: [
                    Color.unbound.textTertiary.opacity(0.7),
                    Color.unbound.textTertiary.opacity(0.9)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.unbound.accent,
                    Color.unbound.impact,
                    Color.unbound.accent.opacity(0.9)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    @ViewBuilder
    private func sweepOverlay(width: CGFloat) -> some View {
        if !muted && width > 0 {
            let offset = (sweepPhase * 2 - 1) * Double(width)
            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.55),
                    Color.white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: max(40, width * 0.25))
            .offset(x: offset)
            .mask(Capsule().frame(width: width))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

#Preview {
    ZStack {
        Color.unbound.bg.ignoresSafeArea()
        VStack(spacing: 18) {
            StatBar(label: "STRENGTH", tier: "E", value: 0.18, muted: true)
            StatBar(label: "STAMINA", tier: "E", value: 0.22, muted: true)
            StatBar(label: "DISCIPLINE", tier: "A", value: 0.82)
            StatBar(label: "CONFIDENCE", tier: "B", value: 0.72)
        }
        .padding(32)
    }
}
