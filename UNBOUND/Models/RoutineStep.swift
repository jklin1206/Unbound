import Foundation

/// Styles the timed-step ring: work uses the routine's category accent;
/// rest uses a recovery (muted) treatment.
enum TimedStyle: String, Codable, Hashable, Sendable {
    case work
    case rest
}

/// One segment of an interval block, e.g. WORK 20s / REST 10s.
struct IntervalSegment: Codable, Hashable, Sendable {
    let label: String
    let seconds: Int

    init(label: String, seconds: Int) {
        self.label = label
        self.seconds = seconds
    }
}

/// A typed routine step. Replaces the old free-text `[String]` + regex
/// parser. The player renders each kind in its own face; `.note` is never
/// advanced through (it is context), `.circuit` is expanded at runtime.
indirect enum RoutineStep: Codable, Hashable, Sendable {
    case instruction(text: String, cue: String?)
    case timed(label: String, seconds: Int, style: TimedStyle)
    case interval(label: String, rounds: Int, segments: [IntervalSegment])
    /// `target == nil` ⇒ AMRAP (open tally, user ends manually).
    case repTarget(name: String, target: Int?, cue: String?)
    case circuit(rounds: Int, restBetweenSeconds: Int, steps: [RoutineStep])
    case note(text: String)
}
