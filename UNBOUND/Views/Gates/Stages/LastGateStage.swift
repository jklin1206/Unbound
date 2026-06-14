import SwiftUI

/// Gate VIII — The Last Gate. The golden stairway: seven landings, one memory from
/// every gate you've already crossed, climbed in turn until the final gate opens at the
/// summit. The world lights from the base up as you ascend, each landing rekindling the
/// sign of its gate, the radiant gate above brightening with the climb. Cards level:
/// each landing is a beat; the live trial lights one when its station is logged.
struct LastGateStage: View {
    let world: GateWorld
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stairAsset = "gate_stairway_unbound"

    /// One landing per prior gate, base → summit, each carrying that gate's sign.
    private struct Landing { let gate: String; let glyph: String; let pos: CGPoint }
    private let landings: [Landing] = [
        .init(gate: "First Light",     glyph: "flame.fill",          pos: CGPoint(x: 0.50, y: 0.780)),
        .init(gate: "The Count",       glyph: "bell.fill",           pos: CGPoint(x: 0.50, y: 0.695)),
        .init(gate: "The Forging",     glyph: "hammer.fill",         pos: CGPoint(x: 0.50, y: 0.610)),
        .init(gate: "The Reckoning",   glyph: "suit.spade.fill",     pos: CGPoint(x: 0.50, y: 0.525)),
        .init(gate: "The Ascent",      glyph: "mountain.2.fill",     pos: CGPoint(x: 0.50, y: 0.440)),
        .init(gate: "The Seven Seals", glyph: "seal.fill",           pos: CGPoint(x: 0.50, y: 0.355)),
        .init(gate: "The Threshold",   glyph: "door.left.hand.open", pos: CGPoint(x: 0.50, y: 0.270))
    ]

    @State private var cleared = 0
    @State private var bloom = false

    private var total: Int { landings.count }
    private var currentIndex: Int { min(cleared, total - 1) }
    private var done: Bool { cleared >= total }
    private var progress: Double { Double(cleared) / Double(total) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                stairway(size: size)
                finalGate(size: size)
                ForEach(landings.indices, id: \.self) { i in landingMarker(i, size: size) }
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    if done { finishedPanel } else { actionPanel }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 30)
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bloom = true } } }
        .accessibilityIdentifier("gate-stage-lastgate")
    }

    // MARK: - The stairway, lighting from base to summit

    private func stairway(size: CGSize) -> some View {
        ZStack {
            Image(stairAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(-0.28 + 0.30 * progress).saturation(0.85 + 0.6 * progress)
            if done { completedFlood(size: size) }
        }
        .overlay(LinearGradient(colors: [Color.unbound.bg.opacity(0.45), .clear, .clear, Color.unbound.bg],
                                startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: cleared)
    }

    private func completedFlood(size: CGSize) -> some View {
        RadialGradient(colors: [Color.white.opacity(0.32), world.fillTint.opacity(0.4), .clear],
                       center: .init(x: 0.5, y: 0.20), startRadius: 10, endRadius: max(size.width, size.height) * 0.75)
            .blendMode(.plusLighter).ignoresSafeArea()
    }

    /// The radiant gate at the summit, brightening with the climb.
    private func finalGate(size: CGSize) -> some View {
        let strength = done ? 1.0 : progress
        return Circle().fill(world.fillTint)
            .frame(width: 80 + 200 * strength, height: 80 + 200 * strength)
            .blur(radius: 60)
            .opacity(0.2 + 0.5 * strength)
            .position(x: size.width * 0.5, y: size.height * 0.16)
            .allowsHitTesting(false)
    }

    private func landingMarker(_ i: Int, size: CGSize) -> some View {
        let l = landings[i]
        let lit = i < cleared
        let isNext = i == cleared && !done
        let d = 52.0
        return ZStack {
            Circle().fill(Color.black.opacity(lit ? 0.35 : 0.5))
            Circle().strokeBorder(world.fillTint.opacity(lit ? 0.95 : (isNext ? 0.7 : 0.3)), lineWidth: lit ? 2 : 1)
            Image(systemName: l.glyph)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(lit ? world.tint : world.fillTint.opacity(isNext ? 0.7 : 0.35))
        }
        .frame(width: d, height: d)
        .scaleEffect(isNext && bloom && !reduceMotion ? 1.1 : 1.0)
        .shadow(color: world.fillTint.opacity(lit ? 0.7 : 0), radius: lit ? 14 : 0)
        .position(x: size.width * l.pos.x, y: size.height * l.pos.y)
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 6) {
            Text(world.trialName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy)).tracking(2.5)
                .foregroundStyle(world.tint)
            Text(done ? "The last gate opens." : landings[currentIndex].gate)
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.85), radius: 7, y: 1)
            if !done {
                Text("LANDING \(currentIndex + 1) OF \(total)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .shadow(color: .black.opacity(0.8), radius: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionPanel: some View {
        Button(action: ascend) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up").font(.system(size: 15, weight: .black))
                Text(cleared == total - 1 ? "THE LAST GATE" : "ASCEND")
                    .font(Font.unbound.bodyM.weight(.heavy)).tracking(2)
            }
            .foregroundStyle(Color.unbound.bg)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Capsule().fill(world.fillTint))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("lastgate.ascend")
    }

    private var finishedPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill").font(.system(size: 26, weight: .black))
                .foregroundStyle(world.fillTint)
            Text("Every gate, answered.").font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.8), radius: 4)
            Button { onFinished?(); reset() } label: {
                Text("RESET").font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(Color.unbound.bg).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(world.fillTint))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    private func ascend() {
        guard !done else { return }
        if !reduceMotion { UnboundHaptics.soft() }
        withAnimation(.easeInOut(duration: 0.5)) { cleared += 1 }
        if cleared >= total, !reduceMotion { UnboundHaptics.success() }
    }

    private func reset() { cleared = 0 }
}
