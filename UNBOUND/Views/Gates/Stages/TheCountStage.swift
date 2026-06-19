import SwiftUI

/// Gate II — The Count. Discipline against the clock: the bell opens each count and its
/// resonance drains as a time window — you have to land all of the count's reps before it
/// runs out. The window tightens and the bell quickens count by count: calm at first, a
/// real push by the last. Miss the window and the count breaks — ring the bell and take
/// it again. This is the gate's whole game surface (like the Reckoning's deck); the live
/// trial maps each counted rep to a logged rep on the one spine.
struct TheCountStage: View {
    let world: GateWorld
    /// (title, reps, window seconds, toll interval). The window tightens and the bell
    /// quickens count by count — the escalation lives here.
    var counts: [(title: String, reps: Int, window: Double, toll: Double)] = [
        ("The Second Count", 8, 26, 2.0),
        ("The Third Count", 10, 22, 1.4),
        ("The Fourth Count", 12, 18, 1.0)
    ]
    var onFinished: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var countIndex = 0
    @State private var repsDone = 0
    @State private var remaining: Double = 26
    @State private var tollAccum: Double = 0
    @State private var ringPulse = false
    @State private var broke = false       // ran out of time on this count
    @State private var bounce = false

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var current: (title: String, reps: Int, window: Double, toll: Double) {
        counts[min(countIndex, counts.count - 1)]
    }
    private var done: Bool { countIndex >= counts.count }
    private var timeFraction: Double {
        guard current.window > 0 else { return 0 }
        return max(0, min(1, remaining / current.window))
    }
    private var urgent: Bool { !broke && !done && timeFraction < 0.25 }

    var body: some View {
        ZStack {
            Image(world.stageAssetName).resizable().scaledToFill().ignoresSafeArea()
                .overlay(Color.black.opacity(0.36))
                .overlay(LinearGradient(colors: [.clear, Color.unbound.bg.opacity(0.92)],
                                        startPoint: .center, endPoint: .bottom))

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                bell
                Spacer(minLength: 0)
                if done { finishedPanel } else { countPanel }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 30)
        }
        .onAppear { startCount() }
        .onReceive(tick) { _ in step() }
        .accessibilityIdentifier("gate-stage-count")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(world.trialName.uppercased())
                .font(Font.unbound.captionS.weight(.heavy)).tracking(2.5)
                .foregroundStyle(world.tint)
            Text(done ? "The count is kept." : (broke ? "The count broke." : current.title))
                .font(Font.unbound.titleM)
                .foregroundStyle(broke ? Color.orange : Color.unbound.textPrimary)
                .shadow(color: .black.opacity(0.85), radius: 7, y: 1)
            if !done {
                Text("COUNT \(countIndex + 1) OF \(counts.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
    }

    // MARK: - The bell (resonance ring = the time window, draining)

    private var bell: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: done ? 1 : timeFraction)
                .stroke((urgent ? Color.orange : world.fillTint).opacity(0.85),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 150, height: 150)
                .animation(.linear(duration: 0.12), value: remaining)

            // soft toll pulse — the bell's tempo, quicker each count
            Circle()
                .strokeBorder(world.fillTint.opacity(ringPulse ? 0 : 0.45), lineWidth: 2)
                .frame(width: ringPulse ? 210 : 96, height: ringPulse ? 210 : 96)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.9), value: ringPulse)

            BellShape()
                .fill(LinearGradient(
                    colors: [world.fillTint, world.fillTint.opacity(0.55), Color(white: 0.14)],
                    startPoint: .top, endPoint: .bottom))
                .overlay(BellShape().stroke(Color.white.opacity(0.28), lineWidth: 1))
                .frame(width: 92, height: 104)
                .shadow(color: world.fillTint.opacity(0.45), radius: 16)
                .scaleEffect(bounce && !reduceMotion ? 1.05 : 1.0)
                .rotationEffect(.degrees(bounce && !reduceMotion ? 4 : 0), anchor: .top)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: bounce)
                .grayscale(broke ? 0.8 : 0)
        }
        .frame(height: 200)
    }

    // MARK: - The count (reps under the window)

    private var countPanel: some View {
        VStack(spacing: 16) {
            Text(broke ? "Out of time — ring the bell and take it again."
                       : "Land all \(current.reps) before the bell fades.")
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(broke ? Color.orange : Color.unbound.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: broke ? ringAgain : countRep) {
                ZStack {
                    Circle().fill(world.fillTint.opacity(0.16))
                    Circle().strokeBorder(broke ? Color.orange : world.fillTint, lineWidth: 1.5)
                    if broke {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.orange)
                            Text("RING AGAIN").font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1).foregroundStyle(Color.unbound.textSecondary)
                        }
                    } else {
                        VStack(spacing: 0) {
                            Text("\(repsDone)").font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
                                .scaleEffect(bounce && !reduceMotion ? 1.12 : 1.0)
                            Text("OF \(current.reps)").font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.4).foregroundStyle(Color.unbound.textTertiary)
                        }
                    }
                }
                .frame(width: 150, height: 150)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("count.rep")

            Text(timeText).font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(urgent ? Color.orange : Color.unbound.textSecondary)
                .monospacedDigit()
                .opacity(broke ? 0.4 : 1)
        }
    }

    private var finishedPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 26, weight: .black))
                .foregroundStyle(world.fillTint)
            Text("Every count kept.").font(Font.unbound.titleS).foregroundStyle(Color.unbound.textPrimary)
            Button { onFinished?(); reset() } label: {
                Text("RESET").font(Font.unbound.captionS.weight(.heavy)).tracking(1.4)
                    .foregroundStyle(Color.unbound.bg).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(world.fillTint))
            }.buttonStyle(.plain)
        }
    }

    private var timeText: String {
        let s = max(0, Int(remaining.rounded(.up)))
        return broke ? "TIME UP" : String(format: "%d:%02d LEFT", s / 60, s % 60)
    }

    // MARK: - Logic

    private func startCount() {
        repsDone = 0
        broke = false
        remaining = current.window
        tollAccum = 0
        toll()
    }

    private func step() {
        guard !done, !broke, remaining > 0 else { return }
        remaining -= 0.1
        tollAccum += 0.1
        if tollAccum >= current.toll {        // the bell keeps the tempo — faster each count
            tollAccum -= current.toll
            toll()
        }
        if remaining <= 0 { remaining = 0; fail() }
    }

    private func countRep() {
        guard !done, !broke else { return }
        repsDone += 1
        if !reduceMotion {
            UnboundHaptics.soft()
            bounce.toggle()
        }
        if repsDone >= current.reps { answer() }
    }

    private func answer() {
        if !reduceMotion { UnboundHaptics.success() }
        withAnimation(.easeInOut(duration: 0.4)) { countIndex += 1 }
        if !done { startCount() }
    }

    /// The window closed before the reps landed — the count breaks, but it's recoverable:
    /// ring the bell and take the same count again.
    private func fail() {
        broke = true
        if !reduceMotion { UnboundHaptics.heavy() }
    }

    private func ringAgain() {
        startCount()
    }

    private func toll() {
        guard !reduceMotion else { return }
        bounce.toggle()
        ringPulse = false
        withAnimation { ringPulse = true }
    }

    private func reset() {
        countIndex = 0
        startCount()
    }
}

/// A simple temple-bell silhouette: flared body, lip, and a crown loop.
private struct BellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let topY = h * 0.16
        let lipY = h * 0.86
        p.addEllipse(in: CGRect(x: w * 0.44, y: h * 0.02, width: w * 0.12, height: h * 0.14))
        p.move(to: CGPoint(x: w * 0.30, y: topY))
        p.addCurve(to: CGPoint(x: w * 0.14, y: lipY),
                   control1: CGPoint(x: w * 0.20, y: h * 0.4),
                   control2: CGPoint(x: w * 0.12, y: h * 0.66))
        p.addLine(to: CGPoint(x: w * 0.10, y: lipY))
        p.addQuadCurve(to: CGPoint(x: w * 0.90, y: lipY), control: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w * 0.86, y: lipY))
        p.addCurve(to: CGPoint(x: w * 0.70, y: topY),
                   control1: CGPoint(x: w * 0.88, y: h * 0.66),
                   control2: CGPoint(x: w * 0.80, y: h * 0.4))
        p.addQuadCurve(to: CGPoint(x: w * 0.30, y: topY), control: CGPoint(x: w * 0.5, y: topY - h * 0.08))
        p.closeSubpath()
        return p
    }
}
