import SwiftUI
import UIKit

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

    let run: [RoutineRunStep]
    private let notes: [String]

    @State var index = 0
    @State var isComplete = false
    @State var elapsedSeconds = 0
    @State private var startedAt = Date()

    // timed/interval transient state
    @State var secondsRemaining = 0
    @State var totalSeconds = 0
    @State var intervalRound = 1
    @State var intervalSegment = 0
    @State private var showNotes = false

    // repTarget transient state
    @State var burstEntry = 10
    @State var bursts: [Int] = []
    @State var performanceEntries: [RoutinePerformanceEntry] = []
    @State var capturedStepIds: Set<Int> = []
    @State var pendingCompletionRecordId: String? = nil

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
    var current: RoutineRunStep? {
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
        .toolbar(.hidden, for: .navigationBar)
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
        let reference = MobilityReferenceLibrary.reference(for: "\(text) \(cue ?? "")")
        let exerciseAssetName = reference == nil ? exerciseVisualAssetName(for: "\(text) \(cue ?? "")") : nil
        return VStack(spacing: 20) {
            Spacer()
            if let reference {
                MobilityReferenceCard(reference: reference, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            } else if let exerciseAssetName {
                RoutineExerciseVisualCard(assetName: exerciseAssetName, title: text, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            }
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
        let reference = style == .work ? MobilityReferenceLibrary.reference(for: label) : nil
        let exerciseAssetName = style == .work && reference == nil ? exerciseVisualAssetName(for: label) : nil
        return VStack(spacing: 28) {
            Spacer()
            if let reference {
                MobilityReferenceCard(reference: reference, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            } else if let exerciseAssetName {
                RoutineExerciseVisualCard(assetName: exerciseAssetName, title: label, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            }
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
        let exerciseAssetName = exerciseVisualAssetName(for: label)
        return VStack(spacing: 24) {
            Spacer()
            if let exerciseAssetName {
                RoutineExerciseVisualCard(assetName: exerciseAssetName, title: label, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            }
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
        let reference = MobilityReferenceLibrary.reference(for: "\(name) \(cue ?? "")")
        let exerciseAssetName = reference == nil ? exerciseVisualAssetName(for: "\(name) \(cue ?? "")") : nil
        return VStack(spacing: 22) {
            Spacer()
            if let reference {
                MobilityReferenceCard(reference: reference, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            } else if let exerciseAssetName {
                RoutineExerciseVisualCard(assetName: exerciseAssetName, title: name, accent: accent, compact: true)
                    .padding(.horizontal, 24)
            }
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
                completeStat(hasRewardableWork ? "PENDING" : "0", "LVL XP")
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

    private func exerciseVisualAssetName(for text: String) -> String? {
        guard let assetName = RoutineStepVisualLibrary.assetName(for: text),
              let resolved = ExerciseVisualAsset.existingAssetName(forBaseAssetName: assetName)
        else { return nil }
        return resolved
    }
}
