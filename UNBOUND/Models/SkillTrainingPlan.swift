import Foundation

// MARK: - SkillTrainingPlan
//
// Per-skill training methodology. Surfaced in the SkillSessionView modal
// when the user taps TRAIN on a skill detail page. NOT a skill tree concept —
// these exercises are drills, not milestones.

struct SkillTrainingPlan {
    let skillId: String
    let regressions: [TrainingExercise]      // for users below Lv1 of the skill
    let mainSets: [TrainingPrescription]     // direct training — the bulk of the work
    let accessories: [TrainingExercise]      // supporting strength / mobility / structure
}

struct TrainingExercise: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let cues: [String]              // 1-3 short cues
}

struct TrainingPrescription: Identifiable, Hashable {
    var id: String { exerciseName + "_\(sets)x\(targetDescription)" }
    let exerciseName: String
    let sets: Int
    let target: PrescriptionTarget
    let restSeconds: Int
    let notes: String?              // e.g. "Add weight when 5 strict, RPE 8"
}

// MARK: - Exercise descriptions
//
// One-sentence "what is this exercise?" copy used in the in-session explainer
// modal. Keys are exercise names (case-sensitive, exactly as authored in the
// SkillTrainingPlanLibrary). Missing entries fall back to the cues only.

enum ExerciseExplainerLibrary {
    static func description(for exerciseName: String) -> String? {
        descriptions[exerciseName]
    }

    static func cues(for exerciseName: String, fallback: [String]) -> [String] {
        formCues[exerciseName] ?? fallback
    }

    private static let descriptions: [String: String] = [
        // Pull / hang family
        "Active Bar Hang": "Hanging from a bar with shoulders packed down — not a passive dangle.",
        "Scapular Pulls": "Shrug-style pulls from a dead hang where only the shoulder blades move; elbows stay locked.",
        "Australian Row": "An inverted bodyweight row under a low bar — feet on the floor, body straight.",
        "Negative Pull-Up": "Jump or step to the top of a pull-up, then lower yourself slowly under control.",
        "Band-Assisted Pull-Up": "Pull-up with a resistance band looped under the foot or knee to offset bodyweight.",
        "Pull-Up AMRAP": "As-many-reps-as-possible strict pull-ups in a single set.",
        "Tempo Pull-Up": "Pull-up performed on a fixed cadence — slow descent, brief hang, controlled pull.",
        "Inverted Row": "Underhand or overhand horizontal pull beneath a bar, body straight, heels on floor.",
        "Lat Pulldown (if equipped)": "Cable or machine vertical pull, used as load-volume work for the back.",

        "Strict Pull-Up": "Pull-up with no kip, swing, or momentum — fully controlled top-to-bottom.",
        "Pause Pull-Up (3s top)": "Pull-up with a 3-second hold at the top of every rep, chin over bar.",
        "Backpack-Loaded Hang": "Dead hang with extra load (a backpack of plates or sandbag) on the back.",
        "Bent-Arm Hang": "Static hold at the top of a pull-up — chin over bar, elbows bent, shoulders engaged.",
        "Banana Hold": "Floor hold with body in a slight banana-line: lower back arched, glutes squeezed.",

        "10 Strict Pull-Ups": "Foundation volume — 10 strict reps owned before chasing the muscle-up.",
        "10 Strict Dips": "Foundation volume — 10 strict bar dips owned for muscle-up catch strength.",
        "False-Grip Hang": "Hang with the wrists rolled over the bar/rings — sets up the muscle-up transition.",
        "Chest-to-Bar Pull-Up": "Explosive pull-up where the upper chest, not the chin, contacts the bar.",
        "Russian Dip": "Dip on parallettes/bars where you lower into a deep elbow-shelf catch and press out.",
        "Banded Muscle-Up": "Full muscle-up motion with a heavy band assisting through the transition.",
        "Jumping Muscle-Up (low bar)": "Bar at chest height — jump, pull, and press through the transition in one motion.",
        "Muscle-Up Singles": "Single-rep muscle-up attempts with full rest — quality over quantity.",
        "Explosive Chest-to-Bar Pull-Up": "Pull-up driven as high as possible — sternum to bar, builds the muscle-up launch.",
        "Ring Transitions (low / band-assisted)": "Slow muscle-up transitions on low rings or with a band, drilling the catch.",
        "Close-Grip Push-Up": "Push-up with hands inside shoulder-width, elbows tracking back — triceps lockout focus.",

        // Push family
        "Wall Push-Up": "Push-up with hands on a wall, body angled — the easiest push regression.",
        "Incline Push-Up (bench/box)": "Push-up with hands elevated on a bench or box, easier than floor reps.",
        "Knee Push-Up": "Push-up with knees on the floor, body still straight from head to knees.",
        "Negative Push-Up": "Slow 5-second descent into a push-up; drop to knees to recover up.",
        "Push-Up AMRAP": "As-many-reps-as-possible strict push-ups in a single set.",
        "Backpack Push-Up": "Push-up performed with a weighted backpack on the upper back for extra load.",
        "Tempo Push-Up": "Push-up performed on a fixed cadence — slow descent, brief pause, controlled press.",
        "Pseudo-Planche Lean": "Push-up plank with hands by the hips — lean forward to load the shoulders like a planche.",
        "Knuckle Push-Up": "Push-up performed on the knuckles — wrist conditioning and neutral wrist alignment.",

        // Dip family
        "Bench Tricep Dip": "Tricep dip with hands on a bench behind you and feet on the floor.",
        "Negative Dip": "Slow 5-second descent on parallel bars; step or jump back up to recover.",
        "Band-Assisted Dip": "Bar dip with a band looped between the bars and your knees for assistance.",
        "Bar Support Hold": "Static hold at the top of a dip — arms locked, body upright.",
        "Dip AMRAP": "As-many-reps-as-possible strict bar dips in a single set.",
        "Tempo Dip": "Bar dip performed on a fixed cadence — slow descent, brief pause, controlled press.",
        "Tricep Extension (band or DB)": "Overhead or skullcrusher-style elbow extension to load the triceps directly.",
        "Front-Leaning Ring Support": "Ring support hold with the body leaned forward — builds shoulder and core stability.",

        "Bar Dip — 5 Strict": "Foundation: 5 strict bar dips owned before adding rings.",
        "Ring Support Hold (RTO)": "Top-of-dip ring hold with rings turned out — palms facing forward.",
        "Ring Tucks": "From ring support, tuck both knees up to chest, then return.",
        "Top-of-Dip Lockout Hold": "Static lockout at the top of a ring dip — arms straight, rings turned out.",
        "Strict Ring Dip": "Ring dip with no swinging — descent and press fully controlled.",
        "RTO Tempo Ring Dip": "Tempo ring dip with rings turned out the entire time.",
        "Ring Push-Up": "Push-up performed on rings hanging just off the floor — instability load.",

        // Legs
        "Deep Goblet Squat Hold": "Squat to full depth holding a kettlebell or dumbbell at chest, held isometrically.",
        "Rear-Foot Elevated Lunge": "Split squat with the rear foot elevated on a bench (Bulgarian style, drilled).",
        "Skater Squat": "Single-leg squat with the rear leg held back behind you — hip-dominant pattern.",
        "Box Pistol (sit-to-stand)": "Pistol squat to a box — sit down on one leg, stand up without using the other.",
        "Counterbalance Pistol (KB held forward)": "Pistol squat holding a kettlebell straight out in front — easier than unloaded.",
        "Pistol Squat (per leg)": "Full single-leg squat to depth, opposite leg held straight in front.",
        "Tempo Pistol (per leg)": "Pistol squat on a fixed cadence — slow descent, brief pause, controlled rise.",
        "Calf Raise": "Standing single- or double-leg calf raise to full plantar flexion.",
        "Single-Leg RDL": "Single-leg Romanian deadlift — hinge at the hip, back leg trails to balance.",
        "Cossack Squat": "Lateral squat — shift weight onto one bent leg while the other extends straight to the side.",

        // Plank / core
        "Knee Plank": "Plank with knees on the floor — body still straight head-to-knees.",
        "Wall Plank": "Plank with hands on a wall, body angled — the easiest plank progression.",
        "Plank Max Hold": "Front plank held until form breaks — hips drop or shoulders shake.",
        "Perfect Plank": "Submaximal plank holding strict form — drilling the brace, not the limit.",
        "Dead Bug": "Lying on the back, alternating opposite arm and leg extension — anti-extension core.",
        "Bird Dog": "From hands and knees, extend opposite arm and leg — anti-rotation core.",
        "Side Plank": "Lateral plank on one forearm — obliques and lateral chain.",

        // L-sit / hollow
        "Tuck L-Sit": "L-sit with knees pulled in to chest — easier compression demand.",
        "Single-Leg L-Sit": "L-sit with one leg extended and the other tucked.",
        "Floor L-Sit on Parallettes": "L-sit on parallettes — hips lifted off the ground, legs straight out.",
        "L-Sit Max Hold": "L-sit held to failure with strict form.",
        "L-Sit Cluster (5s on / 5s off)": "Repeated 5-second L-sit holds with 5-second rests inside one set.",
        "Compression Sit": "Seated with legs straight, fold chest forward over thighs — compression strength.",
        "Pike Compression": "Seated pike fold — hands reach for toes, pulling chest down with active core.",
        "Toe-Touch Crunch": "Lying crunch reaching for the toes with straight legs lifted — direct compression.",

        "Tuck Hollow": "Hollow body hold with knees tucked into chest — easier core demand.",
        "Banana (single-arm-leg)": "Hollow hold with only one arm and opposite leg extended — easier than full hollow.",
        "Hollow Rocks": "Hollow body position rocking head-to-foot in a small range — keeps the line tight.",
        "Hollow + Arch Superset": "Alternating 10s hollow body hold and 10s superman arch — both ends of the brace.",
        "V-Up": "Lying V-fold — legs and torso rise to meet, fingers reach toes.",

        // Handstand family
        "Wrist Conditioning": "Daily wrist warm-up — knuckle push-ups, circles, stretches — to support handstand load.",
        "Pike Hold (hips high)": "Inverted pike hold with hips stacked over shoulders, head between hands.",
        "Crow Pose": "Yoga arm balance — knees rest on the triceps, balance on the hands.",
        "Wall Handstand (chest-to-wall)": "Handstand with the chest facing the wall — fully stacked, shoulders open.",
        "Wall Walk": "From a push-up, walk feet up the wall and hands toward the wall to a handstand.",
        "Shoulder Dislocates (band/dowel)": "Pass a band or dowel from front to back of the body with straight arms — shoulder mobility.",
        "Hollow Body Hold": "Lying on the back, lower back pressed to floor, legs and shoulders lifted — core line drill.",

        "Wall Handstand 60s": "Foundation: 60 seconds of wall handstand owned before chasing freestanding.",
        "Kick-Up Practice (against wall)": "Practice kicking up to handstand with the wall behind — find the balance point.",
        "Wall Shoulder Tap": "From a wall handstand, shift weight to one hand and tap the opposite shoulder.",
        "Freestanding Handstand Attempts": "Free-balance handstand attempts away from a wall.",
        "Heel Pull (kick-up + balance)": "Kick up, then pull the heels back toward the body to find balance.",
        "Tuck Handstand Drill": "Mid-handstand, pull the legs into a tuck and back out — control under inverted load."
    ]

    /// Form cues per exercise — used by the explainer sheet when richer cues
    /// than the prescription's notes are available. Falls back to whatever
    /// the plan author included.
    private static let formCues: [String: [String]] = [:]
}

enum PrescriptionTarget: Hashable {
    case reps(Int)                                       // "8 reps"
    case repsRange(Int, Int)                             // "5-8 reps"
    case amrap                                           // as many as possible
    case hold(seconds: Int)                              // "30s hold"
    case tempo(reps: Int, eccentric: Int, hold: Int, concentric: Int)  // "5 reps @ 3-1-3"
}

extension TrainingPrescription {
    var targetDescription: String {
        switch target {
        case .reps(let r):                            return "\(r) reps"
        case .repsRange(let lo, let hi):              return "\(lo)–\(hi) reps"
        case .amrap:                                  return "AMRAP"
        case .hold(let s):                            return "\(s)s hold"
        case .tempo(let r, let e, let h, let c):      return "\(r) reps @ \(e)-\(h)-\(c)"
        }
    }
}

// MARK: - SessionLog (persisted)

struct SessionLog: Codable, Identifiable {
    let id: String                  // UUID
    let userId: String
    let skillId: String             // the goal being trained
    let createdAt: Date
    let durationSeconds: Int
    let exercises: [LoggedExercise]
    let xpAwarded: Int
}

struct LoggedExercise: Codable, Hashable {
    let name: String
    let sets: [LoggedSet]
}

struct LoggedSet: Codable, Hashable {
    let reps: Int                   // for reps/amrap/tempo
    let holdSeconds: Int?           // for hold-target sets
    let weightKg: Double?           // optional load
    let rpe: Int?                   // 1-10 perceived effort
}
