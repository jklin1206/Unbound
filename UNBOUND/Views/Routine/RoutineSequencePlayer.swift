import SwiftUI

// MARK: - RoutinePlayerView
//
// Step-sequence player for pre-set routines. No set logging: it shows the
// current step, gives a time reference when the step is timed, and advances.
// Faces: instruction · timed · interval · repTarget · complete.

struct RoutinePlayerView: View {
    let routine: RoutineDef
    let onComplete: (RoutineCompletionRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var services: ServiceContainer

    private let run: [RoutineRunStep]
    private let notes: [String]

    @State private var index = 0
    @State private var isComplete = false
    @State private var elapsedSeconds = 0
    @State private var startedAt = Date()

    // timed/interval transient state
    @State private var secondsRemaining = 0
    @State private var totalSeconds = 0
    @State private var intervalRound = 1
    @State private var intervalSegment = 0
    @State private var showNotes = false

    // repTarget transient state
    @State private var burstEntry = 10
    @State private var bursts: [Int] = []
    @State private var performanceEntries: [RoutinePerformanceEntry] = []
    @State private var capturedStepIds: Set<Int> = []

    private let clock = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    init(routine: RoutineDef,
         onComplete: @escaping (RoutineCompletionRecord) -> Void) {
        self.routine = routine
        self.onComplete = onComplete
        let built = RoutineRun.build(routine.steps)
        self.run = built.run
        self.notes = built.notes
    }

    private var accent: Color { routine.category.color }
    private var current: RoutineRunStep? {
        index < run.count ? run[index] : nil
    }
    private var elapsedLabel: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            if isComplete || current == nil {
                completeFace
            } else {
                VStack(spacing: 0) {
                    topBar
                    progressRail
                    Spacer(minLength: 8)
                    stepFace(current!)
                    Spacer(minLength: 8)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startedAt = Date()
            performanceEntries = []
            capturedStepIds = []
            prepare(run.first)
        }
        .onReceive(clock) { _ in tick() }
        .sheet(isPresented: $showNotes) { notesSheet }
    }

    // MARK: Top bar + rail

    private var topBar: some View {
        HStack {
            Button { UnboundHaptics.soft(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(elapsedLabel)
                .font(Font.unbound.monoS.weight(.bold)).tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary).monospacedDigit()
            Spacer()
            if notes.isEmpty {
                Spacer().frame(width: 36)
            } else {
                Button { UnboundHaptics.soft(); showNotes = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    private var progressRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(current?.roundLabel
                     ?? "STEP \(min(index + 1, run.count)) OF \(run.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4).foregroundStyle(Color.unbound.textTertiary)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.surface).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(accent)
                        .frame(width: geo.size.width
                               * CGFloat(index + 1) / CGFloat(max(run.count, 1)),
                               height: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                                   value: index)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Faces

    @ViewBuilder
    private func stepFace(_ step: RoutineRunStep) -> some View {
        switch step.kind {
        case .instruction(let text, let cue):
            instructionFace(text: text, cue: cue)
        case .timed(let label, _, let style):
            timedFace(label: label, style: style)
        case .interval(let label, let rounds, let segs):
            intervalFace(label: label, rounds: rounds, segments: segs)
        case .repTarget(let name, let target, let cue):
            repTargetFace(name: name, target: target, cue: cue)
        case .note, .circuit:
            // RoutineRun guarantees these never appear in the run.
            Color.clear.onAppear { advance() }
        }
    }

    private func instructionFace(text: String, cue: String?) -> some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 12) {
                Text(text)
                    .font(Font.unbound.displayM).tracking(0.3)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let cue {
                    Text(cue)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            primaryButton(isLast ? "FINISH" : "DONE") { advance() }
        }
    }

    private func timedFace(label: String, style: TimedStyle) -> some View {
        let ringColor = style == .rest ? Color.unbound.textTertiary : accent
        return VStack(spacing: 28) {
            Spacer()
            Text(label.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(style == .rest ? Color.unbound.textTertiary : accent)
            ZStack {
                Circle().strokeBorder(Color.unbound.surface, lineWidth: 10)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: totalSeconds > 0
                          ? CGFloat(secondsRemaining) / CGFloat(totalSeconds) : 1)
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.5), radius: 12)
                    .animation(.linear(duration: 1), value: secondsRemaining)
                Text("\(secondsRemaining)")
                    .font(.system(size: 60, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
                    .contentTransition(.numericText(value: Double(secondsRemaining)))
            }
            Spacer()
            HStack(spacing: 16) {
                secondaryButton("+30s") {
                    secondsRemaining = min(secondsRemaining + 30, 600)
                    totalSeconds = max(totalSeconds, secondsRemaining)
                }
                primaryButton("SKIP") { UnboundHaptics.heavy(); advance() }
            }
            .padding(.horizontal, 24)
        }
    }

    private func intervalFace(label: String, rounds: Int,
                              segments: [IntervalSegment]) -> some View {
        let seg = segments[min(intervalSegment, segments.count - 1)]
        return VStack(spacing: 24) {
            Spacer()
            Text(label.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.8).foregroundStyle(accent)
            Text("ROUND \(intervalRound) / \(rounds) · \(seg.label.uppercased())")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
            ZStack {
                Circle().strokeBorder(Color.unbound.surface, lineWidth: 10)
                    .frame(width: 210, height: 210)
                Circle()
                    .trim(from: 0, to: totalSeconds > 0
                          ? CGFloat(secondsRemaining) / CGFloat(totalSeconds) : 1)
                    .stroke(accent,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.5), radius: 12)
                    .animation(.linear(duration: 1), value: secondsRemaining)
                Text("\(secondsRemaining)")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
            }
            Spacer()
            primaryButton("SKIP ROUND") { UnboundHaptics.heavy(); advance() }
                .padding(.horizontal, 24)
        }
    }

    private func repTargetFace(name: String, target: Int?,
                               cue: String?) -> some View {
        let total = bursts.reduce(0, +)
        let hit = target.map { total >= $0 } ?? false
        return VStack(spacing: 22) {
            Spacer()
            Text(name.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.8).foregroundStyle(accent)
            Text(target.map { "\(total) / \($0)" } ?? "\(total)")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(hit ? accent : Color.unbound.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(total)))
                .scaleEffect(hit ? 1.04 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hit)
            if let cue {
                Text(cue).font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 28)
            }
            if !bursts.isEmpty {
                Text(bursts.map(String.init).joined(separator: " · "))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            HStack(spacing: 0) {
                stepperBtn("minus") { if burstEntry > 1 { burstEntry -= 1 } }
                Text("\(burstEntry)")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit().frame(width: 90)
                stepperBtn("plus") { burstEntry += 1 }
            }
            secondaryButton("ADD \(burstEntry)") {
                UnboundHaptics.medium()
                bursts.append(burstEntry)
            }
            .padding(.horizontal, 24)
            primaryButton(hit ? "DONE" : "I'M DONE") {
                UnboundHaptics.heavy(); advance()
            }
            .padding(.horizontal, 24).padding(.bottom, 8)
        }
    }

    private var completeFace: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold)).foregroundStyle(accent)
            }
            .shadow(color: accent.opacity(0.5), radius: 18)
            VStack(spacing: 6) {
                Text("ROUTINE COMPLETE")
                    .font(Font.unbound.captionS.weight(.bold)).tracking(2.0)
                    .foregroundStyle(accent)
                Text(routine.title.uppercased())
                    .font(Font.unbound.displayM).tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 0) {
                completeStat(headlineValue, headlineLabel)
                Divider().frame(height: 32).background(Color.unbound.border)
                completeStat(historyLabel, "HISTORY")
                Divider().frame(height: 32).background(Color.unbound.border)
                completeStat("+\(routine.spReward)", "LV XP")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1))
            .padding(.horizontal, 32)
            Spacer()
            primaryButton("RETURN") {
                UnboundHaptics.heavy()
                onComplete(buildRecord())
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    // MARK: Reusable controls

    private func primaryButton(_ title: String,
                               _ action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Text(title).font(Font.unbound.bodyMStrong).tracking(1.6)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent))
                .shadow(color: accent.opacity(0.5), radius: 14, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("routine.primary.\(MovementCatalog.slug(title))")
    }

    private func secondaryButton(_ title: String,
                                 _ action: @escaping () -> Void) -> some View {
        Button { UnboundHaptics.soft(); action() } label: {
            Text(title).font(Font.unbound.bodyMStrong).tracking(1.0)
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("routine.secondary.\(MovementCatalog.slug(title))")
    }

    private func stepperBtn(_ icon: String,
                            _ action: @escaping () -> Void) -> some View {
        Button { UnboundHaptics.tick(); action() } label: {
            Image(systemName: icon).font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.unbound.surface))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("routine.stepper.\(icon)")
    }

    private func completeStat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
            Text(l).font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var notesSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTES").font(Font.unbound.captionS.weight(.bold))
                .tracking(2.0).foregroundStyle(accent)
            ForEach(notes, id: \.self) { n in
                Text(n).font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.unbound.bg.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    // MARK: Drive

    private var isLast: Bool { index >= run.count - 1 }

    private func prepare(_ step: RoutineRunStep?) {
        guard let step else { return }
        switch step.kind {
        case .timed(_, let secs, _):
            secondsRemaining = secs; totalSeconds = secs
        case .interval(_, _, let segs):
            intervalRound = 1; intervalSegment = 0
            secondsRemaining = segs.first?.seconds ?? 0
            totalSeconds = secondsRemaining
        case .repTarget:
            bursts = []; burstEntry = 10
        default:
            break
        }
    }

    private func tick() {
        elapsedSeconds += 1
        guard let step = current else { return }
        switch step.kind {
        case .timed:
            if secondsRemaining <= 1 {
                secondsRemaining = 0
                UnboundHaptics.success(); advance()
            } else {
                secondsRemaining -= 1
                if secondsRemaining <= 3 { UnboundHaptics.tick() }
            }
        case .interval(_, let rounds, let segs):
            if secondsRemaining <= 1 {
                if intervalSegment + 1 < segs.count {
                    intervalSegment += 1
                } else if intervalRound + 1 <= rounds {
                    intervalRound += 1; intervalSegment = 0
                } else {
                    secondsRemaining = 0
                    UnboundHaptics.success(); advance(); return
                }
                secondsRemaining = segs[intervalSegment].seconds
                totalSeconds = secondsRemaining
            } else {
                secondsRemaining -= 1
                if secondsRemaining <= 3 { UnboundHaptics.tick() }
            }
        default:
            break
        }
    }

    private func advance() {
        captureCurrentStep()
        if isLast {
            withAnimation { isComplete = true }
            UnboundHaptics.success()
            return
        }
        index += 1
        prepare(current)
    }

    private func buildRecord() -> RoutineCompletionRecord {
        let allBursts = performanceEntries.flatMap(\.bursts).filter { $0 > 0 }
        let hasRep = !allBursts.isEmpty || run.contains {
            if case .repTarget = $0.kind { return true }
            return false
        }

        let metric: RoutineMetric
        if hasRep {
            metric = .repCount(total: allBursts.reduce(0, +), bursts: allBursts)
        } else if isTimerDominant {
            metric = .time(seconds: elapsedSeconds)
        } else {
            metric = .steps(done: run.count, total: run.count)
        }
        return RoutineCompletionRecord(
            routineId: routine.id,
            completedAt: Date(),
            elapsedSeconds: elapsedSeconds,
            primaryMetric: metric,
            spAwarded: routine.spReward,
            performanceEntries: performanceEntries)
    }

    private func captureCurrentStep() {
        guard let step = current, !capturedStepIds.contains(step.id) else { return }
        capturedStepIds.insert(step.id)

        switch step.kind {
        case .instruction(let text, _):
            performanceEntries.append(
                RoutinePerformanceEntry(
                    stepId: step.id,
                    source: .instruction,
                    name: text
                )
            )

        case .timed(let label, let seconds, let style):
            guard style == .work else { return }
            let actualSeconds = capturedTimedSeconds(targetSeconds: seconds)
            guard actualSeconds > 0 else { return }
            performanceEntries.append(timedEntry(stepId: step.id, name: label, seconds: actualSeconds, source: .timed))

        case .interval(let label, let rounds, let segments):
            let workSeconds = capturedIntervalWorkSeconds(rounds: rounds, segments: segments)
            guard workSeconds > 0 else { return }
            performanceEntries.append(
                RoutinePerformanceEntry(
                    stepId: step.id,
                    source: .interval,
                    name: label,
                    durationSeconds: workSeconds
                )
            )

        case .repTarget(let name, _, _):
            let cleanBursts = bursts.filter { $0 > 0 }
            guard !cleanBursts.isEmpty else { return }
            performanceEntries.append(
                RoutinePerformanceEntry(
                    stepId: step.id,
                    source: .repTarget,
                    name: name,
                    reps: cleanBursts.reduce(0, +),
                    bursts: cleanBursts
                )
            )

        case .note, .circuit:
            break
        }
    }

    private func capturedTimedSeconds(targetSeconds: Int) -> Int {
        let remaining = max(0, min(secondsRemaining, targetSeconds))
        if remaining == 0 { return targetSeconds }
        return max(0, targetSeconds - remaining)
    }

    private func capturedIntervalWorkSeconds(rounds: Int, segments: [IntervalSegment]) -> Int {
        guard rounds > 0, !segments.isEmpty else { return 0 }
        var total = 0

        for round in 1...rounds {
            for segmentIndex in segments.indices {
                let segment = segments[segmentIndex]
                guard !Self.isRestLike(segment.label) else { continue }

                if round < intervalRound || (round == intervalRound && segmentIndex < intervalSegment) {
                    total += segment.seconds
                } else if round == intervalRound && segmentIndex == intervalSegment {
                    let remaining = max(0, min(secondsRemaining, segment.seconds))
                    total += max(0, segment.seconds - remaining)
                }
            }
        }

        let plannedWork = rounds * segments
            .filter { !Self.isRestLike($0.label) }
            .reduce(0) { $0 + $1.seconds }
        return secondsRemaining == 0 ? plannedWork : total
    }

    private func timedEntry(
        stepId: Int,
        name: String,
        seconds: Int,
        source: RoutinePerformanceEntrySource
    ) -> RoutinePerformanceEntry {
        let resolved = MovementResolver.resolve(name)
        let metric = MovementCatalog.definition(for: resolved.movementId)?.defaultMetric
        if metric == .holdSeconds {
            return RoutinePerformanceEntry(stepId: stepId, source: source, name: name, holdSeconds: seconds)
        }
        return RoutinePerformanceEntry(stepId: stepId, source: source, name: name, durationSeconds: seconds)
    }

    private static func isRestLike(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("rest") || lower.contains("recover") || lower.contains("cool-down")
    }

    /// Timer-dominant ⇔ the single longest timed/interval block ≥ 50% of
    /// elapsed (spec's pinned primaryMetric rule).
    private var isTimerDominant: Bool {
        var longest = 0
        for s in run {
            switch s.kind {
            case .timed(_, let secs, _):
                longest = max(longest, secs)
            case .interval(_, let rounds, let segs):
                longest = max(longest, rounds * segs.reduce(0) { $0 + $1.seconds })
            default: break
            }
        }
        return elapsedSeconds > 0 && Double(longest) >= Double(elapsedSeconds) * 0.5
    }

    private var headlineValue: String {
        switch buildRecord().primaryMetric {
        case .time(let s): return String(format: "%02d:%02d", s / 60, s % 60)
        case .repCount(let t, _): return "\(t)"
        case .steps(let d, _): return "\(d)"
        }
    }
    private var headlineLabel: String {
        switch buildRecord().primaryMetric {
        case .time: return "TIME"
        case .repCount: return "REPS"
        case .steps: return "STEPS"
        }
    }
    private var historyLabel: String {
        let s = RoutineHistoryStore.shared.summary(routineId: routine.id)
        return "\((s?.count ?? 0) + 1)×"
    }
}
