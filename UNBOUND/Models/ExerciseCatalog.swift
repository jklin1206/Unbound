import Foundation

// MARK: - ExerciseCatalog
//
// Hand-authored exercise library mirroring Hawks' thread structure. Grouped
// by movement pattern. Each entry has a canonical name (used as the key
// everywhere — logs, progression state, skill tree) + display name + muscle
// groups + optional default substitution.
//
// User marks each exercise YES/SUB/NO via `ExercisePreferenceService`. The
// `LocalProgramGenerator` filters against this catalog when generating
// sessions: exclude `.avoid`, prefer `.available`, apply `.substitute`
// replacements automatically.

struct CatalogExercise: Identifiable, Hashable, Sendable {
    var id: String { name }
    /// Canonical name, lowercase, used as the key everywhere. Treated as stable.
    let name: String
    /// Display name for UI (Title Case, kept human-readable).
    let displayName: String
    let muscleGroups: [MuscleGroup]
    /// When marked `.substitute`, this is the default replacement the user
    /// would prefer (user can override in detail view).
    let defaultSubstitute: String?
    /// Progression family key (e.g. "push", "pull", "legs-single", "core-lever").
    /// Non-progressable lifts leave this nil.
    var progressionFamily: String? = nil
    /// Tier within the progression family. 0 = entry, higher = harder.
    var progressionTier: Int? = nil

    init(
        name: String,
        displayName: String,
        muscleGroups: [MuscleGroup],
        defaultSubstitute: String?,
        progressionFamily: String? = nil,
        progressionTier: Int? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.muscleGroups = muscleGroups
        self.defaultSubstitute = defaultSubstitute
        self.progressionFamily = progressionFamily
        self.progressionTier = progressionTier
    }
}

enum MovementPattern: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case legsQuad           = "Legs — quad dominant"
    case legsPosterior      = "Legs — posterior chain"
    case pushHorizontal     = "Push — horizontal"
    case pushVertical       = "Push — vertical"
    case pullHorizontal     = "Pull — horizontal"
    case pullVertical       = "Pull — vertical"
    case arms               = "Arms"
    case core               = "Core"
    case calves             = "Calves"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .legsQuad:       return "figure.strengthtraining.traditional"
        case .legsPosterior:  return "figure.stand"
        case .pushHorizontal: return "figure.arms.open"
        case .pushVertical:   return "arrow.up.to.line"
        case .pullHorizontal: return "arrow.down.to.line"
        case .pullVertical:   return "figure.climbing"
        case .arms:           return "dumbbell.fill"
        case .core:           return "figure.core.training"
        case .calves:         return "figure.walk"
        }
    }
}

enum ExerciseCatalog {

    static let exercisesByPattern: [MovementPattern: [CatalogExercise]] = [
        .legsQuad: [
            .init(name: "back squat", displayName: "Barbell Back Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "goblet squat"),
            .init(name: "front squat", displayName: "Barbell Front Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "goblet squat"),
            .init(name: "safety bar squat", displayName: "Safety Bar Squat", muscleGroups: [.legs, .glutes, .back], defaultSubstitute: "back squat"),
            .init(name: "hack squat", displayName: "Hack Squat (Machine)", muscleGroups: [.legs, .glutes], defaultSubstitute: "leg press"),
            .init(name: "leg press", displayName: "Leg Press", muscleGroups: [.legs, .glutes], defaultSubstitute: "goblet squat"),
            .init(name: "bodyweight squat", displayName: "Bodyweight Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: nil, progressionFamily: "legs-single", progressionTier: 0),
            .init(name: "bulgarian split squat", displayName: "Bulgarian Split Squat", muscleGroups: [.legs, .glutes], defaultSubstitute: "walking lunge", progressionFamily: "legs-single", progressionTier: 1),
            .init(name: "jump squat", displayName: "Jump Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "bodyweight squat", progressionFamily: "legs-single", progressionTier: 2),
            .init(name: "assisted shrimp squat", displayName: "Shrimp Squat (Assisted)", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "bulgarian split squat", progressionFamily: "legs-single", progressionTier: 3),
            .init(name: "assisted pistol squat", displayName: "Pistol Squat (Assisted)", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "bulgarian split squat", progressionFamily: "legs-single", progressionTier: 4),
            .init(name: "pistol squat", displayName: "Pistol Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "assisted pistol squat", progressionFamily: "legs-single", progressionTier: 5),
            .init(name: "shrimp squat", displayName: "Shrimp Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: "assisted shrimp squat", progressionFamily: "legs-single", progressionTier: 6),
            .init(name: "walking lunge", displayName: "Walking Lunge", muscleGroups: [.legs, .glutes], defaultSubstitute: "step up"),
            .init(name: "step up", displayName: "Step Up", muscleGroups: [.legs, .glutes], defaultSubstitute: "walking lunge"),
            .init(name: "goblet squat", displayName: "Goblet Squat", muscleGroups: [.legs, .glutes, .core], defaultSubstitute: nil)
        ],
        .legsPosterior: [
            .init(name: "deadlift", displayName: "Conventional Deadlift", muscleGroups: [.back, .legs, .glutes, .forearms], defaultSubstitute: "romanian deadlift"),
            .init(name: "trap bar deadlift", displayName: "Trap Bar Deadlift", muscleGroups: [.back, .legs, .glutes], defaultSubstitute: "deadlift"),
            .init(name: "romanian deadlift", displayName: "Romanian Deadlift", muscleGroups: [.legs, .glutes, .back], defaultSubstitute: "good morning"),
            .init(name: "single-leg rdl", displayName: "Single-Leg RDL", muscleGroups: [.legs, .glutes], defaultSubstitute: "romanian deadlift"),
            .init(name: "leg curl (lying)", displayName: "Leg Curl (Lying)", muscleGroups: [.legs], defaultSubstitute: "nordic curl"),
            .init(name: "leg curl (seated)", displayName: "Leg Curl (Seated)", muscleGroups: [.legs], defaultSubstitute: "leg curl (lying)"),
            .init(name: "nordic curl", displayName: "Nordic Curl", muscleGroups: [.legs, .glutes], defaultSubstitute: "leg curl (lying)"),
            .init(name: "good morning", displayName: "Good Morning", muscleGroups: [.back, .legs, .glutes], defaultSubstitute: "romanian deadlift"),
            .init(name: "cable pull through", displayName: "Cable Pull Through", muscleGroups: [.glutes, .back], defaultSubstitute: "kettlebell swing"),
            .init(name: "glute bridge", displayName: "Glute Bridge", muscleGroups: [.glutes, .core], defaultSubstitute: "hip thrust"),
            .init(name: "hip thrust", displayName: "Hip Thrust", muscleGroups: [.glutes, .legs], defaultSubstitute: "glute bridge"),
            .init(name: "kettlebell swing", displayName: "Kettlebell Swing", muscleGroups: [.glutes, .back, .core], defaultSubstitute: "cable pull through")
        ],
        .pushHorizontal: [
            .init(name: "bench press", displayName: "Barbell Bench Press", muscleGroups: [.chest, .shoulders, .arms], defaultSubstitute: "dumbbell bench press"),
            .init(name: "dumbbell bench press", displayName: "Dumbbell Bench Press", muscleGroups: [.chest, .shoulders, .arms], defaultSubstitute: nil),
            .init(name: "incline bench press", displayName: "Incline Barbell Press", muscleGroups: [.chest, .shoulders, .arms], defaultSubstitute: "incline dumbbell press"),
            .init(name: "incline dumbbell press", displayName: "Incline Dumbbell Press", muscleGroups: [.chest, .shoulders, .arms], defaultSubstitute: nil),
            .init(name: "decline bench press", displayName: "Decline Press", muscleGroups: [.chest, .arms], defaultSubstitute: "bench press"),
            .init(name: "machine chest press", displayName: "Machine Chest Press", muscleGroups: [.chest, .shoulders, .arms], defaultSubstitute: "dumbbell bench press"),
            .init(name: "cable fly", displayName: "Cable Fly", muscleGroups: [.chest], defaultSubstitute: "dumbbell fly"),
            .init(name: "dumbbell fly", displayName: "Dumbbell Fly", muscleGroups: [.chest], defaultSubstitute: "cable fly"),
            .init(name: "pec dec", displayName: "Pec Dec (Machine)", muscleGroups: [.chest], defaultSubstitute: "cable fly"),
            .init(name: "incline pushup", displayName: "Incline Pushup", muscleGroups: [.chest, .shoulders, .arms, .core], defaultSubstitute: nil, progressionFamily: "push", progressionTier: 0),
            .init(name: "pushup", displayName: "Pushup", muscleGroups: [.chest, .shoulders, .arms, .core], defaultSubstitute: "incline pushup", progressionFamily: "push", progressionTier: 1),
            .init(name: "diamond pushup", displayName: "Diamond Pushup", muscleGroups: [.chest, .arms, .core], defaultSubstitute: "pushup", progressionFamily: "push", progressionTier: 2),
            .init(name: "decline pushup", displayName: "Decline Pushup", muscleGroups: [.chest, .shoulders, .arms], defaultSubstitute: "pushup", progressionFamily: "push", progressionTier: 3),
            .init(name: "pseudo planche pushup", displayName: "Pseudo-Planche Pushup", muscleGroups: [.chest, .shoulders, .arms, .core], defaultSubstitute: "decline pushup", progressionFamily: "push", progressionTier: 4),
            .init(name: "archer pushup", displayName: "Archer Pushup", muscleGroups: [.chest, .shoulders, .arms, .core], defaultSubstitute: "pseudo planche pushup", progressionFamily: "push", progressionTier: 6)
        ],
        .pushVertical: [
            .init(name: "overhead press", displayName: "Barbell OHP", muscleGroups: [.shoulders, .arms, .core], defaultSubstitute: "dumbbell overhead press"),
            .init(name: "dumbbell overhead press", displayName: "Dumbbell OHP", muscleGroups: [.shoulders, .arms], defaultSubstitute: nil),
            .init(name: "arnold press", displayName: "Arnold Press", muscleGroups: [.shoulders, .arms], defaultSubstitute: "dumbbell overhead press"),
            .init(name: "seated machine press", displayName: "Seated Machine Press", muscleGroups: [.shoulders, .arms], defaultSubstitute: "dumbbell overhead press"),
            .init(name: "landmine press", displayName: "Landmine Press", muscleGroups: [.shoulders, .chest, .core], defaultSubstitute: "dumbbell overhead press"),
            .init(name: "lateral raise (db)", displayName: "Lateral Raise (DB)", muscleGroups: [.shoulders], defaultSubstitute: "lateral raise (cable)"),
            .init(name: "lateral raise (cable)", displayName: "Lateral Raise (Cable)", muscleGroups: [.shoulders], defaultSubstitute: "lateral raise (db)"),
            .init(name: "rear delt fly (db)", displayName: "Rear Delt Fly (DB)", muscleGroups: [.shoulders, .back], defaultSubstitute: "face pull"),
            .init(name: "rear delt fly (machine)", displayName: "Rear Delt Fly (Machine)", muscleGroups: [.shoulders, .back], defaultSubstitute: "rear delt fly (db)"),
            .init(name: "face pull", displayName: "Face Pull (Cable)", muscleGroups: [.shoulders, .back, .traps], defaultSubstitute: "rear delt fly (db)"),
            .init(name: "pike pushup", displayName: "Pike Pushup", muscleGroups: [.shoulders, .arms, .core], defaultSubstitute: "dumbbell overhead press", progressionFamily: "push", progressionTier: 5),
            .init(name: "wall handstand pushup", displayName: "Wall Handstand Pushup", muscleGroups: [.shoulders, .arms, .core], defaultSubstitute: "pike pushup", progressionFamily: "push", progressionTier: 7)
        ],
        .pullHorizontal: [
            .init(name: "bent-over row", displayName: "Barbell Bent-Over Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "dumbbell row"),
            .init(name: "dumbbell row", displayName: "Dumbbell Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: nil),
            .init(name: "cable row (seated)", displayName: "Cable Row (Seated)", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "machine row"),
            .init(name: "machine row", displayName: "Machine Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "cable row (seated)"),
            .init(name: "chest supported row", displayName: "Chest Supported Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "dumbbell row"),
            .init(name: "meadows row", displayName: "Meadows Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "dumbbell row"),
            .init(name: "pendlay row", displayName: "Pendlay Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "bent-over row"),
            .init(name: "inverted row", displayName: "Inverted Row", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "dumbbell row")
        ],
        .pullVertical: [
            .init(name: "negative pullup", displayName: "Negative Pull-Up", muscleGroups: [.back, .lats, .arms], defaultSubstitute: nil, progressionFamily: "pull", progressionTier: 0),
            .init(name: "assisted pullup (band)", displayName: "Assisted Pull-Up (Band)", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "negative pullup", progressionFamily: "pull", progressionTier: 1),
            .init(name: "chin-up", displayName: "Chin-Up", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "assisted pullup (band)", progressionFamily: "pull", progressionTier: 2),
            .init(name: "pullup", displayName: "Pull-Up (Bodyweight)", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "chin-up", progressionFamily: "pull", progressionTier: 3),
            .init(name: "lat pulldown (neutral)", displayName: "Lat Pulldown (Neutral)", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "lat pulldown", progressionFamily: "pull", progressionTier: 4),
            .init(name: "wide grip pullup", displayName: "Wide-Grip Pull-Up", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "pullup", progressionFamily: "pull", progressionTier: 5),
            .init(name: "weighted pullup", displayName: "Weighted Pull-Up (5kg)", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "pullup", progressionFamily: "pull", progressionTier: 6),
            .init(name: "straight bar dip", displayName: "Straight Bar Dip", muscleGroups: [.chest, .arms, .shoulders], defaultSubstitute: "dip", progressionFamily: "pull", progressionTier: 7),
            .init(name: "banded muscle-up", displayName: "Banded Muscle-Up", muscleGroups: [.back, .lats, .arms, .chest, .core], defaultSubstitute: "chest-to-bar pullup", progressionFamily: "pull", progressionTier: 8),
            .init(name: "low-bar muscle-up transition", displayName: "Low-Bar Muscle-Up Transition", muscleGroups: [.back, .lats, .arms, .chest, .core], defaultSubstitute: "banded muscle-up", progressionFamily: "pull", progressionTier: 9),
            .init(name: "assisted turnover freeze", displayName: "Assisted Turnover Freeze", muscleGroups: [.back, .lats, .arms, .chest, .core], defaultSubstitute: "low-bar muscle-up transition", progressionFamily: "pull", progressionTier: 10),
            .init(name: "muscle-up", displayName: "Muscle-Up", muscleGroups: [.back, .lats, .arms, .chest], defaultSubstitute: "banded muscle-up", progressionFamily: "pull", progressionTier: 11),
            .init(name: "lat pulldown", displayName: "Lat Pulldown (Bar)", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "pullup"),
            .init(name: "single arm pulldown", displayName: "Single-Arm Pulldown", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "lat pulldown"),
            .init(name: "straight arm pulldown", displayName: "Straight-Arm Pulldown", muscleGroups: [.lats], defaultSubstitute: "lat pulldown"),
            .init(name: "chest-to-bar pullup", displayName: "Chest-to-Bar Pullup", muscleGroups: [.back, .lats, .arms], defaultSubstitute: "pullup")
        ],
        .arms: [
            .init(name: "barbell curl", displayName: "Barbell Curl", muscleGroups: [.arms], defaultSubstitute: "dumbbell curl"),
            .init(name: "dumbbell curl", displayName: "Dumbbell Curl", muscleGroups: [.arms], defaultSubstitute: nil),
            .init(name: "incline dumbbell curl", displayName: "Incline Dumbbell Curl", muscleGroups: [.arms], defaultSubstitute: "dumbbell curl"),
            .init(name: "cable curl", displayName: "Cable Curl", muscleGroups: [.arms], defaultSubstitute: "dumbbell curl"),
            .init(name: "hammer curl", displayName: "Hammer Curl", muscleGroups: [.arms, .forearms], defaultSubstitute: "dumbbell curl"),
            .init(name: "preacher curl", displayName: "Preacher Curl (Machine)", muscleGroups: [.arms], defaultSubstitute: "dumbbell curl"),
            .init(name: "close grip bench press", displayName: "Close Grip Bench", muscleGroups: [.arms, .chest], defaultSubstitute: "tricep pushdown"),
            .init(name: "tricep pushdown", displayName: "Tricep Pushdown (Cable)", muscleGroups: [.arms], defaultSubstitute: "skull crushers"),
            .init(name: "overhead tricep extension", displayName: "Overhead Tricep Ext (Cable)", muscleGroups: [.arms], defaultSubstitute: "tricep pushdown"),
            .init(name: "skull crushers", displayName: "Skull Crushers", muscleGroups: [.arms], defaultSubstitute: "tricep pushdown"),
            .init(name: "dip", displayName: "Dip (Tricep)", muscleGroups: [.arms, .chest, .shoulders], defaultSubstitute: "close grip bench press")
        ],
        .core: [
            .init(name: "plank", displayName: "Plank", muscleGroups: [.core], defaultSubstitute: nil, progressionFamily: "core-lever", progressionTier: 0),
            .init(name: "hollow hold", displayName: "Hollow Hold", muscleGroups: [.core], defaultSubstitute: "plank", progressionFamily: "core-lever", progressionTier: 1),
            .init(name: "l-sit (tucked)", displayName: "L-Sit (Tucked)", muscleGroups: [.core, .shoulders, .arms], defaultSubstitute: "hollow hold", progressionFamily: "core-lever", progressionTier: 2),
            .init(name: "l-sit", displayName: "L-Sit", muscleGroups: [.core, .shoulders, .arms], defaultSubstitute: "l-sit (tucked)", progressionFamily: "core-lever", progressionTier: 3),
            .init(name: "tuck front lever", displayName: "Tuck Front Lever", muscleGroups: [.core, .lats, .back], defaultSubstitute: "l-sit", progressionFamily: "core-lever", progressionTier: 4),
            .init(name: "advanced tuck front lever", displayName: "Advanced Tuck Front Lever", muscleGroups: [.core, .lats, .back], defaultSubstitute: "tuck front lever", progressionFamily: "core-lever", progressionTier: 5),
            .init(name: "dragon flag", displayName: "Dragon Flag", muscleGroups: [.core], defaultSubstitute: "hanging leg raise", progressionFamily: "core-lever", progressionTier: 6),
            .init(name: "cable crunch", displayName: "Cable Crunch", muscleGroups: [.core], defaultSubstitute: "hanging knee raise"),
            .init(name: "hanging leg raise", displayName: "Hanging Leg Raise", muscleGroups: [.core], defaultSubstitute: "hanging knee raise"),
            .init(name: "hanging knee raise", displayName: "Hanging Knee Raise", muscleGroups: [.core], defaultSubstitute: "cable crunch"),
            .init(name: "ab wheel", displayName: "Ab Wheel", muscleGroups: [.core], defaultSubstitute: "plank"),
            .init(name: "pallof press", displayName: "Pallof Press", muscleGroups: [.core], defaultSubstitute: "plank"),
            .init(name: "landmine rotation", displayName: "Landmine Rotation", muscleGroups: [.core, .shoulders], defaultSubstitute: "pallof press"),
            .init(name: "hollow rock", displayName: "Hollow Rock", muscleGroups: [.core], defaultSubstitute: "plank")
        ],
        .calves: [
            .init(name: "standing calf raise", displayName: "Standing Calf Raise", muscleGroups: [.calves], defaultSubstitute: nil),
            .init(name: "seated calf raise", displayName: "Seated Calf Raise", muscleGroups: [.calves], defaultSubstitute: "standing calf raise"),
            .init(name: "leg press calf raise", displayName: "Leg Press Calf Raise", muscleGroups: [.calves], defaultSubstitute: "standing calf raise")
        ]
    ]

    /// Flat list of every exercise in the catalog.
    static var allExercises: [CatalogExercise] {
        MovementPattern.allCases.flatMap { exercisesByPattern[$0] ?? [] }
    }

    /// Lookup a single exercise by canonical name (case-insensitive).
    static func exercise(named name: String) -> CatalogExercise? {
        let key = name.lowercased()
        return allExercises.first { $0.name == key }
    }

    /// All exercises in a given progression family, sorted ascending by tier.
    static func progressionFamily(_ family: String) -> [CatalogExercise] {
        allExercises
            .filter { $0.progressionFamily == family }
            .sorted { ($0.progressionTier ?? 0) < ($1.progressionTier ?? 0) }
    }

    /// Highest-tier unlocked exercise in a family at or below `maxTier`.
    /// V1 default is entry tier (0). Chunk 2B wires per-user tier.
    static func calisthenicsPick(family: String, maxTier: Int = 0) -> CatalogExercise? {
        progressionFamily(family)
            .filter { ($0.progressionTier ?? 0) <= maxTier }
            .last
    }

    /// Exercises in the same pattern, excluding one. Used for swap suggestions.
    static func alternatives(to exerciseName: String) -> [CatalogExercise] {
        let key = exerciseName.lowercased()
        for pattern in MovementPattern.allCases {
            let list = exercisesByPattern[pattern] ?? []
            if list.contains(where: { $0.name == key }) {
                return list.filter { $0.name != key }
            }
        }
        return []
    }
}
