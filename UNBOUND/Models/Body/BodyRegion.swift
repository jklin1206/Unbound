import Foundation

// MARK: - BodyRegion
//
// Granular muscle partition for the home character-sheet figure. Named
// `BodyRegion` (not `MuscleGroup`) because a coarser `MuscleGroup` enum
// already drives ExerciseCatalog tagging and BuildIdentity priority groups.
// The two live in parallel: this one is purely a UI gauge.

enum BodyRegion: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    var id: String { rawValue }

    // Upper — front
    case chest, upperChest, midLowerChest, shoulders, frontSideDelts, biceps, triceps, forearms
    // Upper — back
    case traps, rearDelts, rhomboids, lats
    // Core
    case abs, obliques, lowerBack
    // Lower
    case quads, adductors, abductors, hamstrings, glutes, calves

    var displayName: String {
        switch self {
        case .chest:      return "Chest"
        case .upperChest: return "Upper Chest"
        case .midLowerChest:
            return "Mid/Lower Chest"
        case .shoulders:  return "Shoulders"
        case .frontSideDelts:
            return "Front/Side Delts"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .traps:      return "Traps"
        case .rearDelts:  return "Rear Delts"
        case .rhomboids:  return "Rhomboids"
        case .lats:       return "Lats"
        case .abs:        return "Abs"
        case .obliques:   return "Obliques"
        case .lowerBack:  return "Lower Back"
        case .quads:      return "Quads"
        case .adductors:  return "Adductors"
        case .abductors:  return "Abductors"
        case .hamstrings: return "Hamstrings"
        case .glutes:     return "Glutes"
        case .calves:     return "Calves"
        }
    }

    enum Side: Sendable { case front, back, both }

    /// Primary side where this region is rendered on the body map.
    var primarySide: Side {
        switch self {
        case .chest, .upperChest, .midLowerChest, .shoulders, .frontSideDelts, .biceps, .abs, .obliques, .quads, .adductors, .forearms:
            return .front
        case .traps, .rearDelts, .rhomboids, .lats, .triceps, .lowerBack, .abductors, .glutes, .hamstrings:
            return .back
        case .calves:
            return .both
        }
    }

    /// Canonical lowercase exercise keys (matching ExerciseCatalog exerciseKey
    /// conventions) that contribute to this region's rank. Keys are
    /// substring-matched, so "bench press" will match both "bench press"
    /// and "incline bench press" lifts.
    var contributingLifts: [String] {
        switch self {
        case .chest:
            return [
                "bench press", "incline bench press", "dumbbell bench press",
                "incline dumbbell press", "pushup", "dip", "chest fly",
                "cable fly", "dumbbell fly", "decline bench press",
                "machine chest press", "pec dec"
            ]
        case .upperChest:
            return [
                "incline bench press", "incline dumbbell press",
                "machine incline chest press", "smith machine incline press",
                "low-to-high cable fly", "incline cable fly"
            ]
        case .midLowerChest:
            return [
                "bench press", "dumbbell bench press", "machine chest press",
                "pushup", "dip",
                "decline bench press", "cable fly", "dumbbell fly",
                "high-to-low cable fly", "pec dec"
            ]
        case .lats:
            return [
                "pullup", "chin-up", "chinup", "lat pulldown",
                "wide grip lat pulldown", "close grip lat pulldown",
                "reverse grip lat pulldown", "barbell row", "bent-over row",
                "dumbbell row", "single arm row", "cable row (seated)",
                "machine row", "chest supported row", "seal row",
                "meadows row", "pendlay row", "inverted row",
                "straight arm pulldown", "single arm pulldown",
                "machine pullover", "weighted pullup", "muscle-up"
            ]
        case .rhomboids:
            return [
                "barbell row", "bent-over row", "dumbbell row",
                "single arm row", "cable row (seated)", "machine row",
                "chest supported row", "seal row", "meadows row",
                "pendlay row", "inverted row", "face pull",
                "rear delt fly", "reverse pec deck", "band pull apart"
            ]
        case .rearDelts:
            return [
                "rear delt fly", "rear delt fly (db)",
                "rear delt fly (machine)", "reverse pec deck",
                "reverse fly", "face pull", "band pull apart",
                "high row"
            ]
        case .traps:
            return [
                "deadlift", "shrug", "upright row", "face pull",
                "trap bar deadlift", "romanian deadlift",
                "farmer carry", "suitcase carry"
            ]
        case .shoulders:
            return [
                "overhead press", "ohp", "military press",
                "dumbbell overhead press", "arnold press",
                "seated machine press", "landmine press",
                "pike pushup", "wall handstand pushup",
                "lateral raise (db)", "lateral raise (cable)",
                "rear delt fly (db)", "rear delt fly (machine)"
            ]
        case .frontSideDelts:
            return [
                "overhead press", "ohp", "military press",
                "dumbbell overhead press", "arnold press",
                "seated machine press", "landmine press",
                "pike pushup", "wall handstand pushup",
                "lateral raise (db)", "lateral raise (cable)",
                "machine lateral raise", "front raise", "y raise",
                "upright row"
            ]
        case .biceps:
            return [
                "barbell curl", "dumbbell curl", "hammer curl",
                "chin-up", "chinup", "incline dumbbell curl",
                "cable curl", "preacher curl"
            ]
        case .triceps:
            return [
                "tricep pushdown", "close grip bench press",
                "overhead tricep extension", "skull crushers",
                "dip", "close-grip bench", "skullcrusher"
            ]
        case .forearms:
            return [
                "weighted pullup", "deadlift", "farmer carry",
                "hammer curl", "trap bar deadlift"
            ]
        case .abs:
            return [
                "plank", "ab wheel", "hanging leg raise", "l-sit",
                "hollow hold", "dragon flag", "cable crunch",
                "hanging knee raise", "hollow rock", "l-sit (tucked)",
                "tuck front lever"
            ]
        case .obliques:
            return [
                "side plank", "russian twist", "pallof press",
                "landmine rotation"
            ]
        case .lowerBack:
            return [
                "deadlift", "good morning", "back extension",
                "romanian deadlift", "rdl", "trap bar deadlift"
            ]
        case .quads:
            return [
                "squat", "front squat", "back squat", "safety bar squat",
                "hack squat", "leg press", "leg extension", "walking lunge",
                "bulgarian split squat", "pistol squat", "goblet squat",
                "bodyweight squat", "jump squat", "step up",
                "assisted pistol squat", "assisted shrimp squat",
                "shrimp squat"
            ]
        case .adductors:
            return [
                "hip adductor", "adductor machine", "cable adduction",
                "cossack squat", "sumo squat", "sumo deadlift",
                "lateral lunge"
            ]
        case .abductors:
            return [
                "hip abductor", "abductor machine", "cable abduction",
                "band abduction", "lateral band walk", "monster walk",
                "clamshell", "side lying leg raise"
            ]
        case .hamstrings:
            return [
                "deadlift", "romanian deadlift", "rdl", "leg curl (lying)",
                "leg curl (seated)", "good morning", "nordic curl",
                "single-leg rdl", "trap bar deadlift"
            ]
        case .glutes:
            return [
                "hip thrust", "squat", "back squat", "front squat",
                "deadlift", "rdl", "romanian deadlift",
                "bulgarian split squat", "glute bridge",
                "cable pull through", "kettlebell swing", "walking lunge"
            ]
        case .calves:
            return [
                "standing calf raise", "seated calf raise",
                "leg press calf raise"
            ]
        }
    }

    /// Single-sentence directive shown on the home "Needs Work" tile.
    /// Kept terse and action-first so the card reads like a game objective.
    var needsWorkDirective: String {
        switch self {
        case .chest:      return "Log a push day"
        case .upperChest: return "Incline press or low-to-high flys"
        case .midLowerChest:
            return "Flat press, pushups, or flys"
        case .lats:       return "Hit pullups or rows this week"
        case .rhomboids:  return "Rows and reverse flys"
        case .rearDelts:  return "Face pulls or rear-delt flys"
        case .traps:      return "Add shrugs or carries"
        case .shoulders:  return "Press overhead, chase lateral volume"
        case .frontSideDelts:
            return "Press overhead or hit lateral raises"
        case .biceps:     return "Curl variations — time under tension"
        case .triceps:    return "Pushdowns or skullcrushers"
        case .forearms:   return "Heavy carries and hammer curls"
        case .abs:        return "Weighted core — hanging leg raises"
        case .obliques:   return "Side planks and rotational work"
        case .lowerBack:  return "Good mornings or back extensions"
        case .quads:      return "Squats would help"
        case .adductors:  return "Adductor machine or Cossack squats"
        case .abductors:  return "Abductor machine or lateral walks"
        case .hamstrings: return "Time for RDLs or leg curls"
        case .glutes:     return "Hip thrusts and split squats"
        case .calves:     return "Calf raises — straight and bent knee"
        }
    }
}
