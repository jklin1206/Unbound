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
        // F8 mis-routed isolation glute
        "cable glute kickback", "machine glute kickback",
        "hip abductor machine", "hip adductor machine", "cable hip abduction",
        // F9 anti-rotation / positional
        "pallof press", "landmine rotation",
        // ballistic
        "kettlebell swing"
    ]

    /// True if `normalizedKey` (space-lowercase) is explicitly unranked.
    static func contains(_ normalizedKey: String) -> Bool {
        names.contains(normalizedKey)
    }
}
