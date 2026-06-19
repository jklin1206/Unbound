import SwiftUI
import UIKit

// MARK: - RoutinePlayerView drive
//
// Step advancement, timers, and performance capture for RoutinePlayerView.

extension RoutinePlayerView {
    // MARK: Drive

    var isLast: Bool { index >= run.count - 1 }

    func prepare(_ step: RoutineRunStep?) {
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

    func tick() {
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

    func advance() {
        captureCurrentStep()
        if isLast {
            withAnimation { isComplete = true }
            UnboundHaptics.success()
            return
        }
        index += 1
        prepare(current)
    }

    func buildRecord() -> RoutineCompletionRecord {
        let allBursts = performanceEntries.flatMap(\.bursts).filter { $0 > 0 }
        let hasRepTarget = run.contains {
            if case .repTarget = $0.kind { return true }
            return false
        }

        let metric: RoutineMetric
        if hasRepTarget {
            metric = .repCount(total: allBursts.reduce(0, +), bursts: allBursts)
        } else if isTimerDominant {
            metric = .time(seconds: elapsedSeconds)
        } else {
            metric = .steps(done: run.count, total: run.count)
        }
        let recordId = pendingCompletionRecordId ?? UUID().uuidString
        pendingCompletionRecordId = recordId

        return RoutineCompletionRecord(
            id: recordId,
            routineId: routine.id,
            completedAt: Date(),
            elapsedSeconds: elapsedSeconds,
            primaryMetric: metric,
            spAwarded: 0,
            performanceEntries: completionPerformanceEntries)
    }

    private var completionPerformanceEntries: [RoutinePerformanceEntry] {
        if !performanceEntries.isEmpty { return performanceEntries }
        return [
            RoutinePerformanceEntry(
                source: .instruction,
                name: "No logged routine work",
                notes: "Completion captured no rewardable metrics."
            )
        ]
    }

    var hasRewardableWork: Bool {
        performanceEntries.contains { entry in
            (entry.reps ?? 0) > 0 ||
            (entry.holdSeconds ?? 0) > 0 ||
            (entry.durationSeconds ?? 0) > 0 ||
            (entry.distanceMeters ?? 0) > 0 ||
            (entry.calories ?? 0) > 0
        }
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

    var headlineValue: String {
        switch buildRecord().primaryMetric {
        case .time(let s): return String(format: "%02d:%02d", s / 60, s % 60)
        case .repCount(let t, _): return "\(t)"
        case .steps(let d, _): return "\(d)"
        }
    }
    var headlineLabel: String {
        switch buildRecord().primaryMetric {
        case .time: return "TIME"
        case .repCount: return "REPS"
        case .steps: return "STEPS"
        }
    }
    var historyLabel: String {
        let s = RoutineHistoryStore.shared.summary(routineId: routine.id)
        return "\((s?.count ?? 0) + 1)×"
    }
}
