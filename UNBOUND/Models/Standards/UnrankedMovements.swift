import Foundation

// MARK: - UnrankedMovements
//
// The single authority for movements that earn XP but carry NO rank badge —
// momentum / isolation / ballistic accessories that don't map to a strength
// standard (PHASE3-ACCESSORY-RATIOS §6). They must NOT inherit a wrong parent
// ratio, so resolution checks here first and returns "unranked".

enum UnrankedMovements {

    /// Normalized exercise names that are explicitly unranked.
    static let names: Set<String> = [
        // F3 lateral / front / upright (momentum, not strength)
        "lateral raise (db)", "lateral raise (cable)", "machine lateral raise",
        "dumbbell front raise", "cable front raise", "cable y raise", "upright row",
        "leaning cable lateral raise", "dumbbell upright row",
        // flys / rear delts / face pulls — positional isolation, same F3 rationale
        "cable fly", "incline cable fly", "dumbbell fly", "pec deck", "pec dec",
        "high-to-low cable fly", "low-to-high cable fly",
        "rear delt fly (db)", "rear delt fly (machine)", "cable rear delt fly",
        "band face pull", "face pull (cable)", "face pull",
        // assistance stack is inverted load (more weight = easier)
        "assisted dip machine",
        // F8 mis-routed isolation glute
        "cable glute kickback", "machine glute kickback",
        "hip abductor machine", "hip adductor machine", "cable hip abduction",
        // F9 anti-rotation / positional
        "pallof press", "landmine rotation", "cable woodchopper",
        // ballistic / hybrid (plank-limited row)
        "kettlebell swing", "renegade row"
    ]

    /// True if `normalizedKey` (space-lowercase) is explicitly unranked.
    static func contains(_ normalizedKey: String) -> Bool {
        names.contains(normalizedKey)
    }
}
