import SwiftUI

/// Gate II — The Count, live. The bespoke dojo hall is the stage: you ring the bell to open
/// the count, do the whole set at your own pace, and keep the count before the hall's light
/// fades. The window is on the WHOLE count, not each rep — timed ("move with the bell") with
/// no mid-set tapping: one tap to begin, one to keep. Miss it and the count breaks — ring
/// again, no penalty. Keeping logs the station "as planned" on the one spine, then the next
/// count opens. Art-forward: the scene carries it, not drawn chrome.
struct CountCardStage: View {
    let world: GateWorld
    let exercise: ActiveWorkoutSession.ActiveExercise
    let stationIndex: Int
    let stationCount: Int
    let stationsCleared: Int
    let onKeepCount: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var running = false
    @State private var broke = false
    @State private var struck = false
    @State private var remaining: Double = 0
    @State private var tollAccum: Double = 0
    @State private var sway = false
    @State private var glow = false
    @State private var resonate = false

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var workingSet: ActiveWorkoutSession.ActiveSet? {
        exercise.sets.first { !$0.isWarmup && !$0.logged } ?? exercise.sets.first { !$0.logged }
    }

    private var targetReps: Int {
        if let r = workingSet?.reps, r > 0 { return r }
        if let r = workingSet?.suggestedReps, r > 0 { return r }
        if let r = Int(exercise.plannedReps.prefix(while: { $0.isNumber })), r > 0 { return r }
        return 8
    }

    private var targetLine: String {
        let s = workingSet
        switch exercise.metricKind {
        case .reps: return "\(targetReps) reps"
        case .distanceMeters:
            let m = s?.distanceMeters ?? s?.suggestedDistanceMeters ?? 0
            return m > 0 ? "\(m) m" : exercise.plannedReps
        case .holdSeconds:
            let h = s?.holdSeconds ?? s?.suggestedHoldSeconds ?? 0
            return h > 0 ? "\(h)s hold" : exercise.plannedReps
        case .durationSeconds:
            let d = s?.durationSeconds ?? s?.suggestedDurationSeconds ?? 0
            return d > 0 ? String(format: "%d:%02d", d / 60, d % 60) : exercise.plannedReps
        default: return exercise.plannedReps
        }
    }

    private var toll: Double { max(0.9, 2.0 - Double(stationIndex) * 0.18) }

    private var windowLength: Double {
        let s = workingSet
        let tighten = max(0.78, 1.0 - Double(stationIndex) * 0.03)
        switch exercise.metricKind {
        case .reps: return max(20, Double(targetReps) * 2.2 * tighten)
        case .distanceMeters:
            let m = Double(s?.distanceMeters ?? s?.suggestedDistanceMeters ?? 200)
            return max(60, m * 0.45)
        case .holdSeconds:
            let h = Double(s?.holdSeconds ?? s?.suggestedHoldSeconds ?? 30)
            return max(20, h + 15)
        case .durationSeconds:
            let d = Double(s?.durationSeconds ?? s?.suggestedDurationSeconds ?? 60)
            return max(30, d + 20)
        default: return 60
        }
    }

    private var timeFraction: Double {
        guard windowLength > 0 else { return 0 }
        return max(0, min(1, remaining / windowLength))
    }
    private var urgent: Bool { running && !broke && timeFraction < 0.22 }
    private var alertTint: Color { Color.orange }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.55), .black.opacity(0.86)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            bellLayer
            topBar
            bottomBlock
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480)
        .background(scene)
        .overlay(alignment: .center) { if struck { keptStamp.allowsHitTesting(false) } }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder((urgent ? alertTint : world.tint).opacity(0.35), lineWidth: 1)
            .allowsHitTesting(false))
        .shadow(color: .black.opacity(0.5), radius: 22, y: 12)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.97)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) { appeared = true }
            startBellAnimations()
        }
        .onChange(of: workingSet?.id) { _, _ in resetForCount() }
        .onChange(of: running) { _, isRunning in if isRunning { startResonance() } }
        .onReceive(tick) { _ in step() }
    }

    // MARK: - The bell (the generated bonshō, hanging in the hall)

    private var bellLayer: some View {
        VStack(spacing: 0) {
            bellView.padding(.top, 42)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }

    private var bellView: some View {
        ZStack {
            Circle().fill(world.fillTint)
                .frame(width: 210, height: 210).blur(radius: 58)
                .opacity(running ? 0.30 : 0.15)
                .scaleEffect((glow && !reduceMotion) ? 1.06 : 0.92)
            if running && !reduceMotion {
                Circle().stroke(world.fillTint.opacity(0.45), lineWidth: 2)
                    .frame(width: 130, height: 130)
                    .scaleEffect(resonate ? 1.7 : 0.8)
                    .opacity(resonate ? 0 : 0.55)
            }
            Image("count_bell").resizable().scaledToFit()
                .frame(height: 176)
                .rotationEffect(.degrees((sway && !reduceMotion) ? 2.2 : -2.2), anchor: .top)
                .shadow(color: .black.opacity(0.55), radius: 14, y: 10)
                .grayscale(broke ? 0.7 : 0)
        }
    }

    private func startBellAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { sway = true }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { glow = true }
    }

    private func startResonance() {
        guard !reduceMotion else { return }
        resonate = false
        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { resonate = true }
    }

    // MARK: - The hall (dims as the count's window fades)

    private var scene: some View {
        Image(world.stageAssetName)
            .resizable().scaledToFill()
            .brightness(running && !reduceMotion ? -0.34 * (1 - timeFraction) : (broke ? -0.34 : 0))
            .saturation(broke ? 0.55 : 1)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(world.trialName.uppercased()) · GATE \(world.numeral)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(2)
                    .foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 0)
                Text("COUNT \(min(stationIndex + 1, stationCount)) OF \(stationCount)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .shadow(color: .black.opacity(0.7), radius: 6)
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var bottomBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.7)
                Text(targetLine)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(world.tint)
            }
            .shadow(color: .black.opacity(0.8), radius: 8, y: 1)

            timeRow
            keepButton
        }
        .padding(20)
    }

    @ViewBuilder
    private var timeRow: some View {
        if running || broke {
            HStack(spacing: 10) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.16)).frame(height: 4)
                        Capsule()
                            .fill(urgent || broke ? alertTint : world.fillTint)
                            .frame(width: proxy.size.width * (broke ? 0 : timeFraction), height: 4)
                    }
                }
                .frame(height: 4)
                Text(timeText)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(urgent || broke ? alertTint : .white.opacity(0.85))
            }
        } else {
            Text("Ring the bell, do the set, then keep the count before the hall fades.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeText: String {
        if broke { return "TIME UP" }
        let s = max(0, Int(remaining.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var keptStamp: some View {
        Text("KEPT")
            .font(.system(size: 22, weight: .black, design: .monospaced)).tracking(4)
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 9)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white, lineWidth: 2.5))
            .rotationEffect(.degrees(-9))
            .shadow(color: world.fillTint.opacity(0.8), radius: 16)
            .transition(.scale.combined(with: .opacity))
    }

    private var keepButton: some View {
        Button(action: primary) {
            HStack(spacing: 10) {
                Image(systemName: broke ? "arrow.counterclockwise" : "bell.fill")
                    .font(.system(size: 15, weight: .black))
                Text(buttonTitle).font(.system(size: 15, weight: .heavy, design: .rounded)).tracking(0.8)
            }
            .foregroundStyle(Color.black.opacity(0.88))
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Capsule().fill(broke ? alertTint : world.fillTint))
            .shadow(color: (broke ? alertTint : world.fillTint).opacity(0.5), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("count.keep")
    }

    private var buttonTitle: String {
        if broke { return "Ring the bell again" }
        if running { return "Keep the count" }
        return "Ring the bell"
    }

    // MARK: - Logic

    private func resetForCount() {
        running = false; broke = false; struck = false
        remaining = windowLength; tollAccum = 0
    }

    private func step() {
        guard running, !broke, remaining > 0 else { return }
        remaining -= 0.1
        tollAccum += 0.1
        if tollAccum >= toll { tollAccum -= toll }
        if remaining <= 0 {
            remaining = 0; broke = true; running = false
            if !reduceMotion { UnboundHaptics.heavy() }
        }
    }

    private func primary() {
        if running { keep() } else { begin() }
    }

    private func begin() {
        running = true; broke = false
        remaining = windowLength; tollAccum = 0
        if !reduceMotion { UnboundHaptics.soft() }
    }

    private func keep() {
        running = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { struck = true }
        if !reduceMotion { UnboundHaptics.success() }
        onKeepCount()
    }
}
