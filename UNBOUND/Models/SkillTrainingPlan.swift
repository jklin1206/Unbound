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
        "Wrist Prep Flow": "Short wrist conditioning circuit for hand-balancing load: palm rocks, fist rocks, finger pulses, and gentle extension work.",
        "Scapular Push-Up Plus": "Straight-arm push-up plank drill where the shoulder blades move from relaxed to fully protracted.",
        "Planche Lean": "Straight-arm plank with shoulders deliberately leaned past the wrists to build planche-specific shoulder load.",
        "Feet-Elevated Planche Lean": "Planche lean with feet raised on a box so the torso approaches a more horizontal planche angle.",
        "Raised Planche Lean": "Feet-supported lean with the body elevated, used to practice forward shoulder travel before the feet float.",
        "Planche Lean Hold": "Isometric planche lean held with elbows locked, shoulders protracted, ribs down, and glutes tight.",
        "Crane One-Knee Float": "Crane-position drill where one knee lifts off the arm at a time to bridge toward no-knee-support tuck planche.",
        "Band-Assisted Tuck Planche": "Tuck planche with a resistance band supporting the hips so the correct straight-arm shape can be held longer.",
        "Band-Assisted Full Planche": "Full planche line practiced with band support at the hips to preserve locked elbows and hollow body position.",
        "Advanced Tuck Planche": "Tuck planche variation with knees opened away from the chest to increase the lever.",
        "Straddle Planche Hold": "Straight-arm planche hold with legs wide in a straddle to reduce the lever compared with full planche.",
        "Half-Lay Planche Hold": "Planche bridge between straddle and full, with legs partially narrowed toward parallel.",
        "Full Planche Attempts": "Fresh short attempts at the full straight-body planche standard.",
        "Tuck Planche Attempts": "Fresh short attempts at a locked-elbow tuck planche with knees floating free.",
        "Straddle Planche Volume Hold": "Back-off volume using the hardest straddle or near-straddle planche shape that remains clean.",
        "Serratus Wall Slide": "Wall slide emphasizing upward reach and shoulder blade control for protraction strength.",
        "Reverse Wrist Stretch": "Gentle wrist-flexor stretch used after heavy palm-loaded work.",
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
        "Wrist Conditioning": "Wrist rocks, palm lifts, fingertip pulses, and gentle extension loading so the hands can tolerate and steer the handstand.",
        "Pike Hold (hips high)": "Inverted pike hold with hips stacked high, head between arms, elbows locked, and shoulders pushing tall.",
        "Crow Pose": "Arm balance with knees on triceps; teaches finger-pressure balance before the body goes fully inverted.",
        "Wall Handstand (chest-to-wall)": "Chest-to-wall handstand used to build the straight line: hands shoulder-width, shoulders active, ribs down, toes light.",
        "Wall Walk": "From a push-up, walk feet up the wall and hands toward the wall while keeping ribs tucked and elbows locked.",
        "Shoulder Dislocates (band/dowel)": "Straight-arm band or dowel pass-throughs for shoulder flexion and overhead comfort.",
        "Hollow Body Hold": "Floor line drill with low back pressed down, ribs tucked, glutes tight, and limbs reaching long.",

        "Wall Handstand 60s": "Foundation: a 60-second chest-to-wall line held while breathing before chasing long freestanding holds.",
        "Kick-Up Practice (against wall)": "Controlled kick-up to the balance point with the wall as a quiet target, not something to crash into.",
        "Wall Shoulder Tap": "From a wall handstand, shift weight fully into one hand before tapping the opposite shoulder.",
        "Freestanding Handstand Attempts": "Free-balance attempts where only stacked, quiet seconds count toward the target.",
        "Heel Pull (kick-up + balance)": "From a wall line, peel the heels away and catch overbalance with the fingertips.",
        "Tuck Handstand Drill": "In a handstand, pull knees toward the chest and extend again without losing shoulder push.",
        "Bear Hold Shoulder Shift": "Quadruped shoulder-loading drill with knees hovering low while the shoulders shift over each hand.",
        "Box Pike Hold": "Feet-elevated pike handstand regression with hips high, arms straight, and shoulders actively pushed tall.",
        "Partial Wall Walk": "Controlled wall-walk rep that stops before full vertical so the athlete can own the shoulder line.",
        "Tripod Base Hold": "Headstand setup drill where both hands and the crown of the head form a stable triangle.",
        "Tripod Knee Shelf": "Headstand entry drill where the knees rest high on the upper arms before the feet leave the floor.",
        "Tuck Headstand": "Compact headstand variation with knees drawn in, used to learn balance without kicking the legs up.",
        "Headstand Hold": "Tripod or supported headstand held with active hands and a long, unloaded neck.",
        "Headstand Tuck Extension": "Headstand control drill moving from tuck toward straight legs and back before exiting.",
        "Wall Tuck Handstand": "Wall handstand variation where the knees bend into tuck while the shoulders keep pushing tall.",
        "Box Tuck Handstand": "Box-supported tuck inversion with hips over hands and feet elevated, bridging toward a true tuck handstand.",
        "Tuck Handstand Negative": "Controlled descent from wall handstand into a tuck shape, emphasizing straight arms and slow hip travel.",
        "Tuck Handstand Hold": "Freestanding or wall-assisted tuck handstand held with hips stacked over the hands.",
        "Elevated-Hand Press Drill": "Press-to-handstand regression on blocks or parallettes that gives the hips room to float the feet.",
        "Crow to Tuck Float": "Bent-to-straight-arm bridge drill where the knees stay tight and the feet become light without jumping.",
        "Compression Lift": "Active pike or straddle lift drill that trains the hips and legs to rise from compression.",
        "Wall Press Negative": "Eccentric press-to-handstand drill lowering from a wall handstand through compression under control.",
        "Tuck Press to Handstand": "Straight-arm press from a tucked start into handstand with no jump or bent-elbow save.",
        "Straddle Press to Handstand": "Straight-arm press from a wide straddle fold into a stacked handstand.",
        "Press to Handstand": "Strict straight-arm press where the feet float from the floor into handstand without momentum.",
        "Press Negative": "Slow reverse press from handstand toward the floor, used to build the exact hip path and compression strength.",
        "Fingertip Weight Shift": "One-arm handstand preparation where the free hand lightens to fingertips while the support shoulder stays tall.",
        "Wall-Supported One-Arm Handstand": "One-arm handstand regression using the wall for position feedback and fingertip assistance.",
        "Wall One-Arm Weight Shift": "Wall handstand drill shifting weight into one support hand while the free hand gradually unloads.",
        "Straddle Handstand Hold": "Two-hand freestanding handstand in a straddle, used as the stable base for one-arm balance work.",
        "One-Arm Fingertip Hover": "Advanced one-arm drill where the free hand briefly hovers after tapering down from fingertip support.",
        "One-Arm Handstand": "Freestanding one-arm balance attempt with a tall support shoulder and no bent-arm save.",
        "Full One-Arm Handstand": "Strict one-arm handstand held without wall or fingertip support for the target duration.",
        "One-Arm Handstand Assisted Hold": "One-arm handstand practice using wall or fingertip support to preserve alignment after max attempts."
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
