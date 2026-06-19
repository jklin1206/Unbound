import SwiftUI

/// Gate V — The Ascent. You light the temple tower as you climb: a bespoke moonlit
/// pagoda whose tiers ignite from base to summit, floor by floor, the glow front
/// rising with you until the finial beacon lights and the summit timer resolves. Full game
/// surface (like the Reckoning); the live trial lights a floor when its work is logged.
struct AscentStage: View {
    let world: GateWorld
    // One floor per painted tier, base → top, so each climb lights exactly one tier.
    var floors: [String] = [
        "The Path", "The Work Floors", "The Cloudline", "Thin Air", "The High Steps", "The Summit Gate"
    ]
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let towerAsset = "gate_tower_master"

    @State private var cleared = 0
    @State private var summitProgress = 0.0

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let summitTimer = 5.0

    private var total: Int { floors.count }
    private var currentFloor: Int { min(cleared + 1, total) }
    private var atSummit: Bool { currentFloor == total }
    private var done: Bool { cleared >= total }
    private var summitSecondsRemaining: Int {
        max(0, Int(ceil(summitTimer * (1 - summitProgress))))
    }

    /// Each painted tier ignites as a measured slice of the pagoda art, base → top.
    /// Top edges stay tight to the eave lip; bottom edges feather farther so the
    /// floor body and rail glow without bleeding into the next roof.
    private let tierBands: [TierBand] = [
        .init(threshold: 1, topY: 0.6470, bottomY: 0.7749, widthFrac: 0.92, topFeather: 0.008, bottomFeather: 0.026),
        .init(threshold: 2, topY: 0.5342, bottomY: 0.6499, widthFrac: 0.84, topFeather: 0.008, bottomFeather: 0.022),
        .init(threshold: 3, topY: 0.4331, bottomY: 0.5371, widthFrac: 0.76, topFeather: 0.007, bottomFeather: 0.020),
        .init(threshold: 4, topY: 0.3413, bottomY: 0.4346, widthFrac: 0.69, topFeather: 0.006, bottomFeather: 0.018),
        .init(threshold: 5, topY: 0.2630, bottomY: 0.3442, widthFrac: 0.61, topFeather: 0.004, bottomFeather: 0.016),
        .init(threshold: 6, topY: 0.1733, bottomY: 0.2554, widthFrac: 0.53, topFeather: 0.005, bottomFeather: 0.014)
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                tower(size: size)
                if done {
                    completedWorldLight(size: size)
                        .transition(.opacity)
                }
                beacon(size: size)
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    if done { finishedPanel } else { actionPanel }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 30)
            }
            .frame(width: size.width, height: size.height)
        }
        .onReceive(tick) { _ in step() }
        .accessibilityIdentifier("gate-stage-ascent")
    }

    // MARK: - The tower, lighting from base to summit

    private func tower(size: CGSize) -> some View {
        ZStack {
            // dormant tower
            Image(towerAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(-0.24)

            if done {
                completedTowerLight(size: size)
                    .transition(.opacity)
            } else {
                // each tier ignites as a soft glow from within
                ForEach(tierBands.indices, id: \.self) { i in
                    if cleared >= tierBands[i].threshold {
                        litTier(size: size, band: tierBands[i])
                            .transition(.opacity)
                    }
                }
            }
        }
        .overlay(LinearGradient(colors: [
            Color.unbound.bg.opacity(0.55),
            .clear,
            .clear,
            done ? Color.unbound.bg.opacity(0.50) : Color.unbound.bg
        ], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: cleared)
    }

    /// One ignited tier: the painted art lit + cyan-boosted, revealed by a measured
    /// band mask whose top and bottom anchors match the source art.
    private func litTier(size: CGSize, band: TierBand) -> some View {
        Image(towerAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .brightness(0.10).saturation(1.45)
            .overlay(world.fillTint.opacity(0.12).blendMode(.plusLighter))
            .mask(
                TierGlowMask(size: size, band: band)
            )
    }

    /// Final state: after the summit timer, the separate floors resolve into one
    /// lit tower so the full pagoda reads as opened, not merely band-highlighted.
    private func completedTowerLight(size: CGSize) -> some View {
        Image(towerAsset).resizable().scaledToFill()
            .frame(width: size.width, height: size.height).clipped()
            .brightness(0.15).saturation(1.58)
            .overlay(world.fillTint.opacity(0.16).blendMode(.plusLighter))
            .overlay(
                LinearGradient(stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.clear, location: 0.42),
                    .init(color: world.fillTint.opacity(0.08), location: 0.70),
                    .init(color: world.fillTint.opacity(0.18), location: 0.92),
                    .init(color: world.fillTint.opacity(0.12), location: 1.0)
                ], startPoint: .top, endPoint: .bottom)
                .blendMode(.plusLighter)
            )
            .mask(
                CompletedTowerGlowMask(size: size)
            )
    }

    /// Final bloom: the whole painted world catches the tower light after the timer
    /// resolves, lifting the scene without washing out the painting.
    private func completedWorldLight(size: CGSize) -> some View {
        ZStack {
            Image(towerAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(0.07).saturation(1.28)
                .opacity(0.28)
                .blendMode(.screen)

            RadialGradient(colors: [
                world.fillTint.opacity(0.18),
                world.fillTint.opacity(0.08),
                Color.clear
            ], center: .center, startRadius: 10, endRadius: max(size.width, size.height) * 0.58)
            .blendMode(.plusLighter)

            RadialGradient(colors: [
                world.fillTint.opacity(0.17),
                world.fillTint.opacity(0.07),
                Color.clear
            ], center: UnitPoint(x: 0.5, y: 0.74), startRadius: 0, endRadius: max(size.width, size.height) * 0.34)
            .blendMode(.plusLighter)

            LinearGradient(stops: [
                .init(color: Color.white.opacity(0.04), location: 0.0),
                .init(color: world.fillTint.opacity(0.07), location: 0.50),
                .init(color: world.fillTint.opacity(0.08), location: 0.78),
                .init(color: Color.clear, location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }

    private func beacon(size: CGSize) -> some View {
        let lit = atSummit || done
        let strength = done ? 1.0 : (atSummit ? summitProgress : 0)
        return ZStack {
            Circle().fill(world.fillTint)
                .frame(width: 70, height: 70).blur(radius: 26)
                .opacity(0.9 * strength)
            Circle().fill(Color.white)
                .frame(width: 10, height: 10).blur(radius: 2)
                .opacity(lit ? 0.4 + 0.6 * strength : 0)
        }
        .position(x: size.width * 0.5, y: size.height * 0.10)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(world.trialName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy)).tracking(2.5)
                .foregroundStyle(world.tint)
            Text(done ? "The temple opens." : floors[currentFloor - 1])
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.85), radius: 7, y: 1)
            if !done {
                Text("FLOOR \(currentFloor) OF \(total)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .shadow(color: .black.opacity(0.8), radius: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action

    @ViewBuilder private var actionPanel: some View {
        if atSummit {
            VStack(spacing: 12) {
                Text("Summit timer.").font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .shadow(color: .black.opacity(0.8), radius: 4)
                ZStack {
                    Circle().fill(Color.black.opacity(0.4))
                    Circle().fill(world.fillTint.opacity(0.16))
                    Circle().trim(from: 0, to: summitProgress)
                        .stroke(world.fillTint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle().strokeBorder(world.fillTint.opacity(0.4), lineWidth: 1)
                    VStack(spacing: 2) {
                        Text("\(summitSecondsRemaining)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(world.fillTint)
                        Text("SECONDS").font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4).foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                .frame(width: 140, height: 140)
                .accessibilityIdentifier("ascent.timer")
            }
        } else {
            Button(action: climb) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up").font(.system(size: 15, weight: .black))
                    Text("CLIMB").font(Font.unbound.bodyM.weight(.heavy)).tracking(2)
                }
                .foregroundStyle(Color.unbound.bg)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Capsule().fill(world.fillTint))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ascent.climb")
        }
    }

    private var finishedPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 26, weight: .black))
                .foregroundStyle(world.fillTint)
            Text("You reached the temple.").font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.8), radius: 4)
            Button { onFinished?(); reset() } label: {
                Text("RESET").font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(Color.unbound.bg).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(world.fillTint))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    private func climb() {
        guard !atSummit, !done else { return }
        if !reduceMotion { UnboundHaptics.soft() }
        withAnimation(.easeInOut(duration: 0.55)) { cleared += 1 }
    }

    private func step() {
        guard atSummit, !done else { return }
        summitProgress = min(1, summitProgress + 0.1 / summitTimer)
        if summitProgress >= 1 { summit() }
    }

    private func summit() {
        if !reduceMotion { UnboundHaptics.success() }
        withAnimation(.easeInOut(duration: 0.8)) { cleared = total }
    }

    private func reset() { cleared = 0; summitProgress = 0 }
}

private struct TierBand {
    let threshold: Int
    let topY: CGFloat
    let bottomY: CGFloat
    let widthFrac: CGFloat
    let topFeather: CGFloat
    let bottomFeather: CGFloat
}

private struct TierGlowMask: View {
    let size: CGSize
    let band: TierBand

    var body: some View {
        let top = size.height * band.topY
        let bottom = size.height * band.bottomY
        let topFeather = size.height * band.topFeather
        let bottomFeather = size.height * band.bottomFeather
        let bandHeight = max(1, bottom - top)
        let maskHeight = topFeather + bandHeight + bottomFeather
        let maskTop = top - topFeather

        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                .frame(height: topFeather)
            Rectangle()
                .fill(.white)
                .frame(height: bandHeight)
            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: bottomFeather)
        }
        .frame(width: size.width * band.widthFrac, height: maskHeight)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white, location: 0.18),
                .init(color: .white, location: 0.82),
                .init(color: .clear, location: 1.0)
            ], startPoint: .leading, endPoint: .trailing)
        )
        .blur(radius: 5)
        .position(x: size.width / 2, y: maskTop + maskHeight / 2)
    }
}

private struct CompletedTowerGlowMask: View {
    let size: CGSize

    var body: some View {
        let top = size.height * 0.150
        let bottom = size.height * 0.900
        let maskHeight = bottom - top

        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                .frame(height: maskHeight * 0.05)
            Rectangle()
                .fill(.white)
                .frame(height: maskHeight * 0.91)
            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: maskHeight * 0.04)
        }
        .frame(width: size.width, height: maskHeight)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white, location: 0.12),
                .init(color: .white, location: 0.88),
                .init(color: .clear, location: 1.0)
            ], startPoint: .leading, endPoint: .trailing)
        )
        .blur(radius: 16)
        .position(x: size.width / 2, y: top + maskHeight / 2)
    }
}
