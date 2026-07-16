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
        case shrug           // F10 — total bar/stack load (DB ×2 rule applies); StrengthLevel barbell shrug, 372,602 lifts
        case wristCurl       // F11 — total bar load (DB ×2 rule applies); StrengthLevel wrist curl, 176,595 lifts
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
        .loadedAb:       [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.25, 1.50, 2.25],
        .shrug:          [0.00, 0.66, 0.86, 1.06, 1.32, 1.58, 1.89, 2.19, 2.88],
        .wristCurl:      [0.00, 0.09, 0.18, 0.26, 0.41, 0.55, 0.74, 0.93, 1.38]
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
        .loadedAb:       [0.00, 0.25, 0.38, 0.50, 0.75, 1.00, 1.25, 1.50, 2.25],
        .shrug:          [0.00, 0.28, 0.43, 0.58, 0.80, 1.02, 1.30, 1.58, 2.23],
        .wristCurl:      [0.00, 0.02, 0.08, 0.13, 0.25, 0.37, 0.55, 0.72, 1.13]
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
            "band curl",
            "seated dumbbell curl", "alternating dumbbell curl", "drag curl",
            "reverse curl", "zottman curl", "high cable curl",
            "behind the back cable curl", "cross-body hammer curl",
            "ez bar preacher curl"
        ], .curl)
        // F2 — triceps extension (total)
        // "dumbbell skull crusher" is a per-hand pair movement → ×2 via
        // dumbbellPairs. StrengthLevel lying-dumbbell-tricep-extension
        // (165,627 lifts; male @80kg: 6/12/21/33/47 kg per DB) runs lighter
        // than the F2 stack bands — same accepted approximation as the F1
        // dumbbell curls.
        add([
            "tricep pushdown", "rope tricep pushdown", "straight bar tricep pushdown",
            "overhead tricep extension", "rope overhead tricep extension",
            "machine triceps extension", "band tricep extension", "skull crushers",
            "dumbbell skull crusher",
            "reverse grip tricep pushdown", "single-arm tricep pushdown",
            "dumbbell overhead tricep extension",
            "single-arm overhead tricep extension",
            "dumbbell tricep kickback", "cable tricep kickback"
        ], .triceps)
        // F4 — leg extension (total)
        add(["leg extension", "single-leg extension"], .legExtension)
        // F5 — leg curl (total; glute-ham raise is the same knee-flexion
        // pattern with plate load)
        add(["leg curl (lying)", "leg curl (seated)", "single-leg curl", "glute ham raise"], .legCurl)
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
            "assisted pullup machine",
            "lat pullover", "dumbbell pullover"
        ], .verticalPull)
        // F8 — hip thrust / glute / loaded hinge-extension (total incl. bar)
        add([
            "hip thrust", "smith machine hip thrust", "glute bridge", "cable pull through",
            "back extension", "reverse hyper"
        ], .hipThrust)
        // F9 — loaded ab / trunk (total)
        add(["cable crunch", "machine crunch"], .loadedAb)
        // F10 — shrug (total)
        add([
            "barbell shrug", "trap bar shrug", "smith machine shrug",
            "cable shrug", "dumbbell shrug"
        ], .shrug)
        // F11 — wrist curl (total)
        add([
            "barbell wrist curl", "reverse wrist curl", "dumbbell wrist curl"
        ], .wristCurl)
        return map
    }()

    /// Per-limb movements that compare to a TOTAL-load family table →
    /// multiply logged load ×2 (PHASE3-ACCESSORY-RATIOS §3.1). Covers
    /// dumbbell pairs and single-arm cable work; F3 lateral stays per-hand
    /// (and is unranked). Two-hands-one-dumbbell moves (dumbbell overhead
    /// tricep extension, dumbbell pullover) log total load and stay out.
    static let dumbbellPairs: Set<String> = [
        "dumbbell curl", "incline dumbbell curl", "hammer curl",
        "dumbbell skull crusher",
        "seated dumbbell curl", "alternating dumbbell curl", "zottman curl",
        "cross-body hammer curl",
        "single-arm tricep pushdown", "single-arm overhead tricep extension",
        "dumbbell tricep kickback", "cable tricep kickback",
        "dumbbell shrug", "dumbbell wrist curl"
    ]
}
