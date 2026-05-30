import Foundation

// MARK: - SkillTierGenerator
//
// Generates a skill's full 9-tier ladder ([SkillTier: TierCriterion]) from a few
// REAL anchor points, instead of hand-authoring 9 numbers per skill (the source of
// the old distribution mess). Mirrors how lifts work: a small set of real standards
// + a curve → all the tiers, automatically sensible (accelerating, no 1-rep creep,
// elite-not-freak top).
//
// Two shapes:
//   • .full(levels)      — GRIND moves with real range (pull-up, dip, hold). The 5
//                          strength levels [Beginner…Elite] map onto tiers 0/2/4/6/8
//                          (Beginner→Initiate … Elite→peak); odd tiers interpolate.
//   • .feat(floor,ladder)— HARD FEATS that don't span 9 honest tiers (one-arm pull-up).
//                          The move's difficulty sets a FLOOR rank: your first rep
//                          jumps you straight there, and the short rep ladder runs
//                          floor→peak. Ranks below the floor are "not yet" — never
//                          padded with other exercises' criteria (no double-downs).
//                          The early-rank journey lives on the separate lead-up nodes.
//
// Anchors come from real data — see docs/strength-standards-harvest.md + docs/standards-*.md.

struct SkillAnchor: Hashable, Sendable {
    enum Metric: Hashable, Sendable { case reps, seconds, bodyweightRatio }

    enum Spec: Hashable, Sendable {
        /// 5 ascending real standards [Beginner, Novice, Intermediate, Advanced, Elite].
        case full([Double])
        /// Feat: the move's first rep earns `floor`; `ladder` is the rep values for
        /// tiers floor…peak (count == 9 - floor.rawValue). Below floor = locked.
        case feat(floor: SkillTier, ladder: [Double])
    }

    let exerciseName: String
    let metric: Metric
    let spec: Spec
}

enum SkillTierGenerator {

    /// 5 real levels → 9 tier values. Levels anchor at ordinals 0,2,4,6,8; the odd
    /// ordinals are the midpoints. The real anchors already encode acceleration, so a
    /// linear fill between them stays sensibly spaced.
    static func interpolate(levels: [Double]) -> [Double] {
        precondition(levels.count == 5, "a full anchor needs exactly 5 levels")
        var t = [Double](repeating: 0, count: 9)
        for (i, ordinal) in [0, 2, 4, 6, 8].enumerated() { t[ordinal] = levels[i] }
        for odd in stride(from: 1, to: 8, by: 2) { t[odd] = (t[odd - 1] + t[odd + 1]) / 2 }
        return t
    }

    /// Generate the full 9-tier ladder for an anchor.
    static func generate(_ anchor: SkillAnchor) -> [SkillTier: TierCriterion] {
        let values: [Double]
        switch anchor.spec {
        case .full(let levels):
            values = climbing(interpolate(levels: levels), metric: anchor.metric)
        case .feat(let floor, let ladder):
            values = featValues(floor: floor, ladder: ladder, metric: anchor.metric)
        }
        var out: [SkillTier: TierCriterion] = [:]
        for (i, tier) in SkillTier.allCases.enumerated() {
            out[tier] = criterion(for: anchor.metric, value: values[i], exercise: anchor.exerciseName)
        }
        return out
    }

    // MARK: Shaping

    /// Round + enforce strictly-increasing (bump any rounding tie). For grind moves.
    private static func climbing(_ raw: [Double], metric: SkillAnchor.Metric) -> [Double] {
        let step = metric == .bodyweightRatio ? 0.05 : 1.0
        var previous = -Double.greatestFiniteMagnitude
        return raw.map { value in
            let v = max(rounded(value, metric), previous + step)
            previous = v
            return v
        }
    }

    /// Feat: tiers 0…floor all equal the first ladder value (so the first rep jumps
    /// you to `floor`); tiers above floor climb strictly. Nothing earnable below floor.
    private static func featValues(floor: SkillTier, ladder: [Double], metric: SkillAnchor.Metric) -> [Double] {
        let f = floor.rawValue
        precondition(ladder.count == 9 - f, "feat ladder must cover floor…peak (\(9 - f) values)")
        let step = metric == .bodyweightRatio ? 0.05 : 1.0
        var vals = [Double](repeating: 0, count: 9)
        let first = rounded(ladder[0], metric)
        for i in 0...f { vals[i] = first }            // 0…floor all the entry value
        var previous = first
        for i in (f + 1)..<9 {
            let v = max(rounded(ladder[i - f], metric), previous + step)
            vals[i] = v
            previous = v
        }
        return vals
    }

    private static func rounded(_ v: Double, _ metric: SkillAnchor.Metric) -> Double {
        metric == .bodyweightRatio ? (v * 20).rounded() / 20 : v.rounded()
    }

    private static func criterion(for metric: SkillAnchor.Metric, value: Double, exercise: String) -> TierCriterion {
        switch metric {
        case .reps:            return .reps(Int(value), exerciseName: exercise)
        case .seconds:         return .exerciseSeconds(Int(value), exerciseName: exercise)
        case .bodyweightRatio: return .exerciseBodyweightRatio(value, exerciseName: exercise)
        }
    }
}

// MARK: - Pull family anchors (canonical nodes — real data)
//
// Keyed by real pp.* node ids. Grind moves use .full (5 strengthlevel levels);
// hard feats use .feat (a floor rank from the move's difficulty + a short rep ladder).
// Variant nodes (5-pullups, slow-pullup, l-sit-pullup, …) added incrementally.

enum PullSkillAnchors {
    static let table: [String: SkillAnchor] = [
        // Grind moves — real range, full 9-tier spread.
        "pp.pullup":          .init(exerciseName: "pullup",          metric: .reps,            spec: .full([1, 6, 13, 23, 32])),
        "pp.chin-up":         .init(exerciseName: "chin-up",         metric: .reps,            spec: .full([1, 7, 13, 22, 30])),
        "pp.wide-pullup":     .init(exerciseName: "wide pullup",     metric: .reps,            spec: .full([1, 4, 9, 17, 24])),
        "pp.muscle-up":       .init(exerciseName: "muscle-up",       metric: .reps,            spec: .full([1, 2, 7, 11, 17])),
        "pp.row":             .init(exerciseName: "row",             metric: .reps,            spec: .full([1, 7, 19, 33, 48])),
        "pp.weighted-pullup": .init(exerciseName: "weighted pullup", metric: .bodyweightRatio, spec: .full([0.10, 0.25, 0.50, 0.75, 1.00])),
        "pp.dead-hang":       .init(exerciseName: "dead hang",       metric: .seconds,         spec: .full([20, 40, 60, 90, 120])),

        // Hard feats — start high (floor from difficulty), short rep ladder floor…peak.
        "pp.archer-pullup":    .init(exerciseName: "archer pullup",    metric: .reps, spec: .feat(floor: .apprentice, ladder: [1, 2, 3, 4, 6, 8, 9])),   // floor 2 → 7 vals
        "pp.strict-muscle-up": .init(exerciseName: "strict muscle-up", metric: .reps, spec: .feat(floor: .forged,     ladder: [1, 2, 3, 5, 8, 12])),     // floor 3 → 6 vals
        "pp.ring-muscle-up":   .init(exerciseName: "ring muscle-up",   metric: .reps, spec: .feat(floor: .veteran,    ladder: [1, 2, 4, 6, 9])),          // floor 4 → 5 vals
        "pp.one-arm-pullup":   .init(exerciseName: "one-arm pullup",   metric: .reps, spec: .feat(floor: .master,     ladder: [1, 2, 3, 5])),             // floor 5 → 4 vals

        // ── Variant + lead-up nodes (added incrementally) ──

        // Basic pull — grind volume / tempo / ROM variants. Scale off pullup [1,6,13,23,32].
        "pp.5-pullups":     .init(exerciseName: "pullup",              metric: .reps, spec: .full([1, 5, 9, 15, 22])),    // volume checkpoint ~5
        "pp.10-pullups":    .init(exerciseName: "pullup",              metric: .reps, spec: .full([3, 7, 13, 19, 25])),   // elite-volume checkpoint ~10
        "pp.strict-pullup": .init(exerciseName: "pullup",              metric: .reps, spec: .full([1, 5, 11, 19, 28])),   // strict, slightly under plain pullup
        "pp.slow-pullup":   .init(exerciseName: "slow pullup",         metric: .reps, spec: .full([1, 4, 9, 16, 24])),    // tempo = harder, fewer reps
        "pp.chest-to-bar":  .init(exerciseName: "chest-to-bar pullup", metric: .reps, spec: .full([1, 4, 9, 16, 24])),    // more ROM = harder
        "pp.l-sit-pullup":  .init(exerciseName: "l-sit pullup",        metric: .reps, spec: .full([1, 3, 7, 13, 20])),    // core + pull = harder
        "pp.negative-pullup": .init(exerciseName: "negative pullup",   metric: .reps, spec: .full([2, 5, 9, 14, 20])),    // eccentric entry, capped ceiling
        "pp.explosive-pullup": .init(exerciseName: "explosive pullup", metric: .reps, spec: .full([1, 3, 7, 12, 18])),    // power, fewer reps

        // Chin chain — scale off chin-up [1,7,13,22,30].
        "pp.strict-chin-up": .init(exerciseName: "chin-up",            metric: .reps, spec: .full([1, 5, 11, 18, 26])),   // strict, under plain chin
        "pp.l-sit-chin-up":  .init(exerciseName: "l-sit chin-up",      metric: .reps, spec: .full([1, 3, 7, 13, 20])),    // core + chin = harder

        // Muscle-up volume — scale off muscle-up [1,2,7,11,17].
        "pp.10-muscle-ups":  .init(exerciseName: "muscle-up",          metric: .reps, spec: .full([3, 6, 10, 14, 20])),   // elite-volume checkpoint ~10

        // Weighted — bodyweight-ratio, Elite ≈ +100% bw (1.0). Checkpoint nodes center lower.
        "pp.weighted-pullup-0.25": .init(exerciseName: "weighted pullup",  metric: .bodyweightRatio, spec: .full([0.05, 0.15, 0.25, 0.40, 0.60])),  // +25% checkpoint
        "pp.weighted-pullup-0.5":  .init(exerciseName: "weighted pullup",  metric: .bodyweightRatio, spec: .full([0.10, 0.25, 0.45, 0.65, 0.85])),  // +50% checkpoint
        "pp.weighted-chin-up":     .init(exerciseName: "weighted chin-up", metric: .bodyweightRatio, spec: .full([0.10, 0.30, 0.50, 0.75, 1.00])),  // chin ~+5–15% over pullup

        // Rows — scale off inverted-row [1,7,19,33,48]. Easier = more reps, harder = fewer.
        "pp.incline-row":  .init(exerciseName: "incline row",  metric: .reps, spec: .full([5, 12, 25, 40, 55])),   // easier angle, more reps
        "pp.decline-row":  .init(exerciseName: "decline row",  metric: .reps, spec: .full([1, 5, 14, 26, 40])),    // harder angle, fewer reps
        "pp.tuck-row":     .init(exerciseName: "tuck row",     metric: .reps, spec: .full([1, 4, 10, 18, 28])),    // tucked lever row
        "pp.straddle-row": .init(exerciseName: "straddle row", metric: .reps, spec: .full([1, 3, 7, 13, 20])),     // straddle lever row, harder

        // Holds — seconds. dead-hang-30 = the 30 s-target variant of the grip gate.
        "pp.dead-hang-30": .init(exerciseName: "dead hang", metric: .seconds, spec: .full([15, 25, 35, 50, 70])),  // 30 s target centered

        // Hard feats — start high, short ladder floor…peak (count == 9 - floor.rawValue).
        "pp.typewriter-pullup":      .init(exerciseName: "typewriter pullup",        metric: .reps, spec: .feat(floor: .forged,     ladder: [1, 2, 4, 6, 8, 10])),     // floor 3 → 6 vals
        "pp.plyometric-pullup":      .init(exerciseName: "plyometric pullup",        metric: .reps, spec: .feat(floor: .forged,     ladder: [1, 2, 3, 5, 8, 12])),     // floor 3 → 6 vals
        "pp.clapping-pullup":        .init(exerciseName: "clapping pullup",          metric: .reps, spec: .feat(floor: .forged,     ladder: [1, 2, 3, 5, 7, 10])),     // floor 3 → 6 vals
        "pp.heighted-chin-up":       .init(exerciseName: "heighted chin-up",         metric: .reps, spec: .feat(floor: .forged,     ladder: [1, 2, 3, 5, 8, 12])),     // floor 3 → 6 vals (one-arm-assist chin)
        "pp.oap-negative":           .init(exerciseName: "one-arm pullup negative",  metric: .reps, spec: .feat(floor: .apprentice, ladder: [1, 3, 4, 5, 6, 9, 12])),  // floor 2 → 7 vals (eccentric entry)
        "pp.one-arm-row":            .init(exerciseName: "one-arm row",              metric: .reps, spec: .feat(floor: .apprentice, ladder: [3, 5, 8, 12, 16, 20, 25])), // floor 2 → 7 vals (unilateral bridge)
        "pp.tuck-front-lever-pullup":.init(exerciseName: "tuck front lever pullup",  metric: .reps, spec: .feat(floor: .veteran,    ladder: [1, 3, 5, 7, 10])),        // floor 4 → 5 vals (lever pull)
        "pp.5-oap-side":             .init(exerciseName: "one-arm pullup",           metric: .reps, spec: .feat(floor: .master,     ladder: [1, 2, 3, 5])),            // floor 5 → 4 vals (OAP volume)
        "pp.one-arm-chin-up":        .init(exerciseName: "one-arm chin-up",          metric: .reps, spec: .feat(floor: .master,     ladder: [1, 2, 3, 5])),            // floor 5 → 4 vals (mythic)
    ]
}
