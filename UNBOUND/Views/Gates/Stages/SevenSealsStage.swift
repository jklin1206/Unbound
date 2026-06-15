import SwiftUI

/// Gate VI — The Seven Seals. The attribute ritual: six seals ring a sacrificial
/// chalice, each one a part of you made physical (endurance, vitality, explosiveness,
/// power, control, mobility), with SPIRIT as the seventh seal set into the chalice
/// itself. You pour yourself into each seal in turn — hold it until its ward overloads
/// and shatters — and the chalice flame grows with every break, erupting when the last
/// seal gives way. Calm and deliberate: no clock, no rush. Full game surface (like the
/// Reckoning); the live trial breaks a seal when its attribute station is logged.
struct SevenSealsStage: View {
    let world: GateWorld
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let artAsset = "gate_seals_vessel"

    /// The seven seals in break order (SPIRIT always last). `pos` is screen-normalized;
    /// the six attribute seals ring the upper sanctum, SPIRIT sits on the chalice.
    private struct Seal {
        let name: String
        let glyph: String
        let pos: CGPoint
        let center: Bool   // the chalice seal (SPIRIT)
    }
    /// Positions ride the painted heptagram's seven vertices (center ≈ 0.50, 0.43;
    /// Rx 0.30, Ry 0.15). Break order sweeps the ring clockwise; SPIRIT crowns the top
    /// and falls last, igniting the chalice below.
    private let seals: [Seal] = [
        Seal(name: "Endurance",     glyph: "figure.run",         pos: CGPoint(x: 0.735, y: 0.337), center: false),
        Seal(name: "Vitality",      glyph: "heart.fill",         pos: CGPoint(x: 0.792, y: 0.463), center: false),
        Seal(name: "Explosiveness", glyph: "bolt.fill",          pos: CGPoint(x: 0.630, y: 0.565), center: false),
        Seal(name: "Power",         glyph: "dumbbell.fill",      pos: CGPoint(x: 0.370, y: 0.565), center: false),
        Seal(name: "Control",       glyph: "scope",              pos: CGPoint(x: 0.208, y: 0.463), center: false),
        Seal(name: "Mobility",      glyph: "figure.flexibility", pos: CGPoint(x: 0.265, y: 0.337), center: false),
        Seal(name: "Spirit",        glyph: "sparkles",           pos: CGPoint(x: 0.50,  y: 0.28),  center: true)
    ]
    private let chalice = CGPoint(x: 0.50, y: 0.655)

    @State private var broken = 0          // seals broken so far == index of the active seal
    @State private var burst = Array(repeating: 0.0, count: 7)
    @State private var pulse = false

    private var done: Bool { broken >= seals.count }
    private var active: Seal? { done ? nil : seals[broken] }
    private var flameStrength: Double { Double(broken) / Double(seals.count) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                backdrop(size: size)
                chaliceFlame(size: size)
                ForEach(seals.indices, id: \.self) { i in
                    sealView(i, size: size)
                }
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    if done { finishedPanel } else { instruction }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 28)
            }
            .frame(width: size.width, height: size.height)
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true } } }
        .accessibilityIdentifier("gate-stage-seals")
    }

    // MARK: - The sanctum

    private func backdrop(size: CGSize) -> some View {
        Image(artAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .overlay(LinearGradient(colors: [Color.unbound.bg.opacity(0.55), .clear, .clear, Color.unbound.bg],
                                    startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea()
    }

    /// The chalice flame, growing as the parts are sealed and erupting at the end.
    private func chaliceFlame(size: CGSize) -> some View {
        let s = done ? 1.0 : flameStrength
        let bloom = 60.0 + 150.0 * s
        return ZStack {
            Circle().fill(world.fillTint)
                .frame(width: bloom, height: bloom).blur(radius: 40)
                .opacity(0.25 + 0.55 * s)
            Image(systemName: "flame.fill")
                .font(.system(size: 26 + 52 * s, weight: .black))
                .foregroundStyle(LinearGradient(colors: [.white, world.fillTint],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: world.fillTint.opacity(0.8), radius: 18)
                .opacity(0.55 + 0.45 * s)
                .scaleEffect(pulse && !reduceMotion ? 1.05 : 1.0, anchor: .bottom)
        }
        .position(x: size.width * chalice.x, y: size.height * chalice.y)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: broken)
        .allowsHitTesting(false)
    }

    // MARK: - A single seal (dormant · active/charging · broken)

    private func sealView(_ i: Int, size: CGSize) -> some View {
        let seal = seals[i]
        let isBroken = i < broken
        let isActive = i == broken && !done
        let d = seal.center ? 116.0 : 92.0
        return ZStack {
            if isBroken {
                shards(i: i, color: world.fillTint, diameter: d)
                Image(systemName: "burst.fill")
                    .font(.system(size: d * 0.26, weight: .black))
                    .foregroundStyle(world.fillTint.opacity(0.22))
            } else {
                ward(seal: seal, active: isActive, diameter: d)
            }
        }
        .frame(width: d, height: d)
        .contentShape(Circle())
        .position(x: size.width * seal.pos.x, y: size.height * seal.pos.y)
        .onTapGesture { if isActive { breakSeal() } }
    }

    /// The unbroken seal: concentric runic rings + attribute glyph. The active one
    /// brightens, slowly turns, and shows the charge arc as it's held.
    private func ward(seal: Seal, active: Bool, diameter d: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.black.opacity(active ? 0.45 : 0.3))
            Circle().strokeBorder(world.fillTint.opacity(active ? 0.9 : 0.4), lineWidth: 1.5)
                .frame(width: d * 0.86, height: d * 0.86)
            // runic tick ring
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: active ? 3 : 2, dash: [2, 7]))
                .foregroundStyle(world.fillTint.opacity(active ? 0.85 : 0.45))
                .frame(width: d * 0.66, height: d * 0.66)
                .rotationEffect(.degrees(active && pulse && !reduceMotion ? 30 : 0))
            Image(systemName: seal.glyph)
                .font(.system(size: d * 0.26, weight: .bold))
                .foregroundStyle(active ? world.tint : world.fillTint.opacity(0.55))
        }
        .scaleEffect(active && pulse && !reduceMotion ? 1.06 : 1.0)
        .shadow(color: world.fillTint.opacity(active ? 0.7 : 0.2), radius: active ? 16 : 6)
        .opacity(active ? 1 : 0.85)
    }

    /// One-shot shard burst when a seal shatters.
    private func shards(i: Int, color: Color, diameter d: CGFloat) -> some View {
        let p = burst[i]
        return ZStack {
            ForEach(0..<8, id: \.self) { k in
                let ang = Double(k) / 8 * 2 * .pi
                Capsule()
                    .fill(color.opacity(max(0, 0.9 - p)))
                    .frame(width: 3, height: 10 + d * 0.12)
                    .offset(y: -(d * 0.2 + p * d * 0.55))
                    .rotationEffect(.radians(ang))
            }
        }
        .opacity(p < 1 ? 1 : 0)
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 6) {
            Text(world.trialName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy)).tracking(2.5)
                .foregroundStyle(world.tint)
            Text(done ? "The vessel is filled." : (active?.name ?? ""))
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.85), radius: 7, y: 1)
            if !done {
                Text("SEAL \(broken + 1) OF \(seals.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .shadow(color: .black.opacity(0.8), radius: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var instruction: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.tap.fill").font(.system(size: 15, weight: .bold))
                .foregroundStyle(world.fillTint.opacity(0.7))
            Text("Break the seal as you clear its work.")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .shadow(color: .black.opacity(0.8), radius: 4)
        }
    }

    private var finishedPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 26, weight: .black))
                .foregroundStyle(world.fillTint)
            Text("Every part of you, sealed.").font(Font.unbound.titleS)
                .foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.8), radius: 4)
            Button { onFinished?(); reset() } label: {
                Text("RESET").font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(Color.unbound.bg).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(world.fillTint))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    private func breakSeal() {
        guard !done else { return }
        let i = broken
        if !reduceMotion { UnboundHaptics.soft() }
        withAnimation(.easeOut(duration: 0.6)) { burst[i] = 1 }
        withAnimation(.easeInOut(duration: 0.5)) { broken += 1 }
        if broken >= seals.count, !reduceMotion { UnboundHaptics.success() }
    }

    private func reset() {
        broken = 0
        burst = Array(repeating: 0, count: 7)
    }
}
