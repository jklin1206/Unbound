import Foundation

// MARK: - StrengthStandards
//
// Bodyweight-multiple anchors per lift, per letter rank. Values are meant
// to feel attainable at C–B and rare at S. Sub-ranks are interpolated by
// `subRank(forLift:)`.
//
// Lifts covered: back squat, bench press, deadlift, overhead press,
// weighted pullup. Bodyweight-skill lifts (pushup, pullup reps, dip reps,
// holds) map via `subRank(forFamilyTier:)`.

enum StrengthStandards {

    /// Lifts that have an explicit multiplier table.
    static let liftKeys: [String] = [
        "back squat",
        "bench press",
        "deadlift",
        "overhead press",
        "weighted pullup"
    ]

    /// Bodyweight multiplier at each letter rank for each lift.
    /// Key: canonical exerciseKey. Inner key: letter ("E","D","C","B","A","S").
    private static let table: [String: [String: Double]] = [
        "back squat": [
            "E": 0.50, "D": 1.00, "C": 1.25, "B": 1.75, "A": 2.25, "S": 2.75
        ],
        "bench press": [
            "E": 0.50, "D": 0.75, "C": 1.00, "B": 1.25, "A": 1.75, "S": 2.10
        ],
        "deadlift": [
            "E": 0.75, "D": 1.25, "C": 1.50, "B": 2.00, "A": 2.75, "S": 3.25
        ],
        "overhead press": [
            "E": 0.30, "D": 0.45, "C": 0.60, "B": 0.80, "A": 1.00, "S": 1.25
        ]
    ]

    /// Weighted pullup added-load (kg) per letter rank. Bodyweight alone
    /// counts as the "E" anchor (added load = 0).
    private static let weightedPullupAddedKg: [String: Double] = [
        "E": 0.0, "D": 5.0, "C": 15.0, "B": 25.0, "A": 40.0, "S": 60.0
    ]

    /// Aliases that resolve to a canonical lift key.
    private static let aliasMap: [String: String] = [
        "squat": "back squat",
        "bench": "bench press",
        "barbell bench press": "bench press",
        "barbell back squat": "back squat",
        "conventional deadlift": "deadlift",
        "trap bar deadlift": "deadlift",
        "ohp": "overhead press",
        "military press": "overhead press",
        "barbell ohp": "overhead press",
        "weighted pull-up": "weighted pullup",
        "weighted chin": "weighted pullup",
        "weighted chin-up": "weighted pullup",
        "weighted dip": "weighted pullup"
    ]

    /// Canonical key for lookup — matches contains() / alias / normalized name.
    static func canonicalKey(for exerciseKey: String) -> String? {
        let normalized = exerciseKey.trimmingCharacters(in: .whitespaces).lowercased()
        if table[normalized] != nil { return normalized }
        if normalized.contains("weighted pullup") || normalized.contains("weighted pull") {
            return "weighted pullup"
        }
        if let alias = aliasMap[normalized] { return alias }
        for key in table.keys where normalized.contains(key) { return key }
        return nil
    }

    /// True if the exercise is a tracked barbell lift with a standards table.
    static func isBarbellLift(exerciseKey: String) -> Bool {
        canonicalKey(for: exerciseKey) != nil
            && canonicalKey(for: exerciseKey) != "weighted pullup"
    }

    /// Multiplier (bodyweight) anchor for a letter rank on a barbell lift.
    static func multiplier(exerciseKey: String, letter: String) -> Double? {
        guard let key = canonicalKey(for: exerciseKey),
              let row = table[key]
        else { return nil }
        return row[letter.uppercased()]
    }

    /// Sub-rank from a logged top set on a barbell lift. Linear interpolation
    /// between letter anchors, mapped onto the 18-step ladder.
    /// `liftKg` = heaviest working set weight. `bodyweightKg` > 0 required.
    static func subRank(
        liftKg: Double,
        bodyweightKg: Double,
        exerciseKey: String
    ) -> RankTier? {
        guard bodyweightKg > 0, liftKg > 0 else { return nil }
        guard let key = canonicalKey(for: exerciseKey) else { return nil }

        if key == "weighted pullup" {
            let added = max(0, liftKg) // liftKg here is already added-load
            return subRankForWeightedPullup(addedKg: added)
        }

        guard let row = table[key] else { return nil }
        let ratio = liftKg / bodyweightKg
        return interpolate(ratio: ratio, table: row)
    }

    /// Weighted-pullup ladder uses added-kg, not a bodyweight ratio.
    private static func subRankForWeightedPullup(addedKg: Double) -> RankTier {
        let letters = ["E", "D", "C", "B", "A", "S"]
        let anchors = letters.compactMap { weightedPullupAddedKg[$0] }
        return interpolateLetters(value: addedKg, anchors: anchors)
    }

    /// Interpolate a bodyweight ratio against a letter-anchor row.
    private static func interpolate(ratio: Double, table row: [String: Double]) -> RankTier {
        let letters = ["E", "D", "C", "B", "A", "S"]
        let anchors = letters.compactMap { row[$0] }
        return interpolateLetters(value: ratio, anchors: anchors)
    }

    /// Shared interpolation: value → position on 0...5 letter scale, then
    /// mapped to a 0...17 ladder position (1, 4, 7, 10, 13, 16 are anchor
    /// slots) and projected onto the 9-tier RankTier via the 2:1 banding.
    private static func interpolateLetters(value: Double, anchors: [Double]) -> RankTier {
        guard anchors.count >= 2 else { return .initiate }

        if value <= anchors[0] {
            // Below E anchor — scale down toward position 0.
            // At 50% of the E anchor or below, show position 0; ramp to 1 at the anchor.
            let halfE = anchors[0] * 0.5
            if value <= halfE { return .initiate }
            let t = (value - halfE) / max(halfE, 0.0001)
            let position = min(1.0, max(0.0, t))
            return RankTier.nearest(for: position / 2.0)
        }

        if value >= anchors.last! {
            return .ascendant
        }

        // Find bracket [anchors[i], anchors[i+1]] and map to letter slots.
        // Letter i sits at ladder position (1 + 3*i): E=1, D=4, C=7, B=10, A=13, S=16.
        for i in 0..<(anchors.count - 1) {
            let lo = anchors[i]
            let hi = anchors[i + 1]
            if value >= lo && value <= hi {
                let t = (value - lo) / max(hi - lo, 0.0001)
                let loOrd = Double(1 + 3 * i)
                let hiOrd = Double(1 + 3 * (i + 1))
                let pos = loOrd + t * (hiOrd - loOrd)
                return RankTier.nearest(for: pos / 2.0)
            }
        }
        return .ascendant
    }

    // MARK: Bodyweight-skill family mapping

    /// Map a ProgressionFamilyState tier (0–7) to a representative RankTier.
    /// Preserves the old per-tier sub-rank anchors projected through the 2:1
    /// banding: E(1)→initiate, D(4)→apprentice, C(7)→forged, C+(8)→veteran,
    /// B(10)→master, B+(11)→master, A(13)→vessel, S(16)→ascendant.
    static func subRank(forFamilyTier tier: Int) -> RankTier {
        switch max(0, tier) {
        case 0: return RankTier.nearest(for: 1.0 / 2.0)   // E  → initiate
        case 1: return RankTier.nearest(for: 4.0 / 2.0)   // D  → apprentice
        case 2: return RankTier.nearest(for: 7.0 / 2.0)   // C  → forged
        case 3: return RankTier.nearest(for: 8.0 / 2.0)   // C+ → veteran
        case 4: return RankTier.nearest(for: 10.0 / 2.0)  // B  → master
        case 5: return RankTier.nearest(for: 11.0 / 2.0)  // B+ → master
        case 6: return RankTier.nearest(for: 13.0 / 2.0)  // A  → vessel
        default: return RankTier.nearest(for: 16.0 / 2.0) // S  → ascendant
        }
    }
}
