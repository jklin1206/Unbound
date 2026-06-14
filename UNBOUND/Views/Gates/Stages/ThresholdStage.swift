import SwiftUI

/// Gate VII — The Threshold. A siege in three acts against a sealed ascendant gate:
/// the Approach (intervals), the Breach (rounds), and Hold the Light (one unbroken hold
/// inside the opening gate). The portal is the living stage — it cracks wider and blazes
/// brighter with every beat across the whole trial, the only gate whose world transforms
/// end to end. Cards level: each beat opens the portal a step; the final hold is a timer
/// you start. The live trial maps each interval / round / hold to logged work.
struct ThresholdStage: View {
    let world: GateWorld
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let portalAsset = "gate_portal_ascendant"

    private struct Act { let name: String; let beats: Int; let verb: String; let unit: String }
    private let acts: [Act] = [
        Act(name: "The Approach", beats: 3, verb: "PUSH",   unit: "INTERVAL"),
        Act(name: "The Breach",   beats: 4, verb: "BREACH", unit: "ROUND")
    ]

    @State private var breached = 0          // assault beats logged (0…assaultTotal)
    @State private var holdRunning = false
    @State private var holdProgress = 0.0
    @State private var completed = false

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let holdTimer = 6.0              // demo stand-in for the 120s Hold the Light

    private var assaultTotal: Int { acts.reduce(0) { $0 + $1.beats } }   // 7
    private var atHold: Bool { breached >= assaultTotal && !completed }
    private var done: Bool { completed }

    /// Which act, and how far into it, from the assault count.
    private var actIndex: Int {
        var rem = breached
        for (i, a) in acts.enumerated() { if rem < a.beats { return i }; rem -= a.beats }
        return acts.count - 1
    }
    private var beatInAct: Int {
        var rem = breached
        for a in acts { if rem < a.beats { return rem }; rem -= a.beats }
        return acts.last?.beats ?? 0
    }

    /// 0…1 how far the portal has opened: most across the siege, the rest on the hold.
    private var openness: Double {
        if completed { return 1 }
        let siege = Double(breached) / Double(assaultTotal) * 0.7
        return atHold ? 0.7 + 0.3 * holdProgress : siege
    }
    private var holdSecondsRemaining: Int { max(0, Int(ceil(holdTimer * (1 - holdProgress)))) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                portal(size: size)
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 0)
                    if done { finishedPanel } else if atHold { holdPanel } else { assaultPanel }
                }
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 30)
            }
            .frame(width: size.width, height: size.height)
        }
        .onReceive(tick) { _ in step() }
        .accessibilityIdentifier("gate-stage-threshold")
    }

    // MARK: - The portal, opening across the siege

    private func portal(size: CGSize) -> some View {
        let cx = size.width * 0.5
        let cy = size.height * 0.42
        let coreH = size.height * 0.40
        let coreW = max(4, size.width * (0.02 + 0.5 * openness))
        return ZStack {
            // sealed gate
            Image(portalAsset).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .brightness(-0.18)

            // light pouring through the opening portal — widens with the siege
            Capsule()
                .fill(LinearGradient(colors: [world.fillTint.opacity(0), world.fillTint, .white, world.fillTint, world.fillTint.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: coreW, height: coreH)
                .blur(radius: 18)
                .position(x: cx, y: cy)
                .opacity(0.5 + 0.5 * openness)
                .blendMode(.plusLighter)

            // bright seam core
            Capsule().fill(Color.white)
                .frame(width: max(2, coreW * 0.18), height: coreH * 0.96)
                .blur(radius: 4)
                .position(x: cx, y: cy)
                .opacity(0.4 + 0.6 * openness)
                .blendMode(.plusLighter)

            // bloom
            Circle().fill(world.fillTint)
                .frame(width: 120 + 320 * openness, height: 120 + 320 * openness)
                .blur(radius: 80)
                .position(x: cx, y: cy)
                .opacity(0.16 + 0.4 * openness)
                .blendMode(.plusLighter)

            if completed { flood(size: size) }
        }
        .overlay(LinearGradient(colors: [Color.unbound.bg.opacity(0.5), .clear, .clear, Color.unbound.bg],
                                startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: breached)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: holdProgress)
    }

    private func flood(size: CGSize) -> some View {
        RadialGradient(colors: [Color.white.opacity(0.3), world.fillTint.opacity(0.4), .clear],
                       center: .init(x: 0.5, y: 0.42), startRadius: 10, endRadius: max(size.width, size.height) * 0.7)
            .blendMode(.plusLighter)
            .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        let act = acts[actIndex]
        return VStack(spacing: 6) {
            Text(world.trialName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy)).tracking(2.5)
                .foregroundStyle(world.tint)
            Text(done ? "The portal stands open." : (atHold ? "Hold the Light" : act.name))
                .font(Font.unbound.titleM).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.85), radius: 7, y: 1)
            if !done {
                Text(atHold ? "ONE UNBROKEN HOLD" : "\(act.unit) \(beatInAct + 1) OF \(act.beats)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .shadow(color: .black.opacity(0.8), radius: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action

    private var assaultPanel: some View {
        let act = acts[actIndex]
        return Button(action: breach) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").font(.system(size: 15, weight: .black))
                Text(act.verb).font(Font.unbound.bodyM.weight(.heavy)).tracking(2)
            }
            .foregroundStyle(Color.unbound.bg)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(Capsule().fill(world.fillTint))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("threshold.breach")
    }

    private var holdPanel: some View {
        VStack(spacing: 12) {
            Text("Hold the light — one unbroken hold inside the gate.")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.8), radius: 4)
            ZStack {
                Circle().fill(Color.black.opacity(0.4))
                Circle().fill(world.fillTint.opacity(0.16))
                Circle().trim(from: 0, to: holdProgress)
                    .stroke(world.fillTint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().strokeBorder(world.fillTint.opacity(0.4), lineWidth: 1)
                VStack(spacing: 2) {
                    Image(systemName: holdRunning ? "figure.stand" : "play.fill")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(world.fillTint)
                    Text(holdRunning ? "\(holdSecondsRemaining)" : "BEGIN")
                        .font(.system(size: holdRunning ? 16 : 9, weight: .heavy, design: .monospaced))
                        .tracking(1.4).foregroundStyle(Color.unbound.textSecondary)
                }
            }
            .frame(width: 140, height: 140)
            .scaleEffect(holdRunning && !reduceMotion ? 1.04 : 1)
            .animation(.easeOut(duration: 0.2), value: holdRunning)
            .contentShape(Circle())
            .onTapGesture { if !holdRunning { startHold() } }
            .accessibilityIdentifier("threshold.hold")
        }
    }

    private var finishedPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 26, weight: .black))
                .foregroundStyle(world.fillTint)
            Text("You held the light.").font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.8), radius: 4)
            Button { onFinished?(); reset() } label: {
                Text("RESET").font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(Color.unbound.bg).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(world.fillTint))
            }.buttonStyle(.plain)
        }
    }

    // MARK: - Logic

    private func breach() {
        guard !atHold, !done else { return }
        if !reduceMotion { UnboundHaptics.soft() }
        withAnimation(.easeInOut(duration: 0.5)) { breached += 1 }
    }

    private func startHold() {
        guard atHold, !done else { return }
        if !reduceMotion { UnboundHaptics.soft() }
        holdRunning = true
    }

    private func step() {
        guard atHold, !done, holdRunning else { return }
        holdProgress = min(1, holdProgress + 0.1 / holdTimer)
        if holdProgress >= 1 { complete() }
    }

    private func complete() {
        holdRunning = false
        if !reduceMotion { UnboundHaptics.success() }
        withAnimation(.easeInOut(duration: 0.9)) { completed = true }
    }

    private func reset() {
        breached = 0; holdRunning = false; holdProgress = 0; completed = false
    }
}
