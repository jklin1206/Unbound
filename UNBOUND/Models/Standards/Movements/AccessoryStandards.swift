import Foundation

// MARK: - AccessoryStandards
//
// The single source for loaded ACCESSORY rank standards: the F1–F9 families,
// their per-tier bodyweight-ratio tables (male + female), family membership by
// exercise name, and the dumbbell-pair ×2 rule. StrengthStandards resolves a
// logged accessory to a Family here and reads the sex-correct ratio table.
// (PHASE3-ACCESSORY-RATIOS §1/§3/§4.)

enum AccessoryStandards {

    /// Loaded accessory families (PHASE3-ACCESSORY-RATIOS §1). Each has a
    /// 9-tier total-load ratio table, except F3 which is per-hand (unranked).
    enum Family {
        case curl            // F1 — total barbell/cable load (DB ×2 rule applies)
        case triceps         // F2 — total stack
        case legExtension    // F4 — total stack
        case legCurl         // F5 — total stack
        case calfRaise       // F6 — added load excl. bodyweight
        case verticalPull    // F7 — machine vertical pull, total stack
        case hipThrust       // F8 — total load incl. bar
        case loadedAb        // F9 — total stack
    }

    /// MALE per-tier ratios for each accessory family. Index = ordinal 0…8.
    static let male: [Family: [Double]] = [
        //                   0     1     2     3     4     5     6     7     8
        .curl:           [0.00, 0.20, 0.30, 0.40, 0.50, 0.60, 0.73, 0.85, 1.15],
        .triceps:        [0.00, 0.25, 0.38, 0.50, 0.63, 0.75, 0.88, 1.00, 1.50],
        .legExtension:   [0.00, 0.50, 0.63, 0.75, 1.00, 1.25, 1.50, 1.75, 2.50],
        .legCurl:        [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 2.00],
        .calfRaise:      [0.00, 0.25, 0.50, 0.75, 1.00, 1.25, 1.63, 2.00, 3.00],
        .verticalPull:   [0.00, 0.50, 0.63, 0.75, 0.88, 1.00, 1.25, 1.50, 1.75],
        .hipThrust:      [0.00, 0.50, 0.75, 1.00, 1.38, 1.75, 2.13, 2.50, 3.50],
        .loadedAb:       [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.25, 1.50, 2.25]
    ]

    /// FEMALE per-tier ratios, authored from the cited per-family female bands
    /// (PHASE3-ACCESSORY-RATIOS §2 female / §4), same anchoring rule. Index 0…8.
    static let female: [Family: [Double]] = [
        //                   0     1     2     3     4     5     6     7     8
        .curl:           [0.00, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.60, 0.85],
        .triceps:        [0.00, 0.15, 0.20, 0.25, 0.38, 0.50, 0.63, 0.75, 1.05],
        .legExtension:   [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.13, 1.25, 2.00],
        .legCurl:        [0.00, 0.25, 0.35, 0.45, 0.60, 0.75, 0.90, 1.05, 1.45],
        .calfRaise:      [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.38, 1.75, 2.50],
        .verticalPull:   [0.00, 0.30, 0.38, 0.45, 0.58, 0.70, 0.83, 0.95, 1.30],
        .hipThrust:      [0.00, 0.50, 0.75, 1.00, 1.25, 1.50, 1.88, 2.25, 3.00],
        .loadedAb:       [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.25, 1.50, 2.25]
    ]

    /// Accessory family members, keyed by normalized exercise name.
    static let membership: [String: Family] = {
        var map: [String: Family] = [:]
        func add(_ names: [String], _ family: Family) {
            for name in names { map[name] = family }
        }
        // F1 — biceps curl (total)
        add([
            "barbell curl", "ez bar curl", "dumbbell curl", "incline dumbbell curl",
            "concentration curl", "spider curl", "cable curl", "rope cable curl",
            "hammer curl", "rope hammer curl", "preacher curl", "machine biceps curl",
            "band curl"
        ], .curl)
        // F2 — triceps extension (total)
        add([
            "tricep pushdown", "rope tricep pushdown", "straight bar tricep pushdown",
            "overhead tricep extension", "rope overhead tricep extension",
            "machine triceps extension", "band tricep extension", "skull crushers"
        ], .triceps)
        // F4 — leg extension (total)
        add(["leg extension", "single-leg extension"], .legExtension)
        // F5 — leg curl (total)
        add(["leg curl (lying)", "leg curl (seated)", "single-leg curl"], .legCurl)
        // F6 — calf raise (added load)
        add([
            "standing calf raise", "seated calf raise", "leg press calf raise",
            "smith machine calf raise", "donkey calf raise", "tibialis raise"
        ], .calfRaise)
        // F7 — machine vertical pull (total)
        add([
            "lat pulldown", "lat pulldown (neutral)", "wide grip lat pulldown",
            "close grip lat pulldown", "reverse grip lat pulldown", "single arm pulldown",
            "straight arm pulldown", "machine pullover", "band lat pull",
            "assisted pullup machine"
        ], .verticalPull)
        // F8 — hip thrust / glute (total incl. bar)
        add([
            "hip thrust", "smith machine hip thrust", "glute bridge", "cable pull through"
        ], .hipThrust)
        // F9 — loaded ab / trunk (total)
        add(["cable crunch", "machine crunch"], .loadedAb)
        return map
    }()

    /// Dumbbell-pair movements logged per-hand that compare to a TOTAL-load
    /// family table → multiply logged load ×2 (PHASE3-ACCESSORY-RATIOS §3.1).
    /// Only F1 curls need this; F3 lateral stays per-hand (and is unranked).
    static let dumbbellPairs: Set<String> = [
        "dumbbell curl", "incline dumbbell curl", "hammer curl"
    ]
}
