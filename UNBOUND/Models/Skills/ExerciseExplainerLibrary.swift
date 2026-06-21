import Foundation

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
        "Banana Hold": "Hollow-line floor hold with ribs tucked, low back heavy to the floor, and glutes squeezed.",

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
        "Tuck Planche Hold": "Locked-elbow tuck planche hold with knees floating, shoulders protracted, and feet off the floor.",
        "Band-Assisted Tuck Planche Push-Up": "Tuck planche push-up with a band supporting the hips so the athlete can keep the correct floating shape.",
        "Tuck Planche Negative": "Eccentric tuck planche push-up: start in the hold, bend the elbows under control, then step down before form collapses.",
        "Tuck Planche Push-Up": "Bent-arm press performed while the body stays in a floating tuck planche.",
        "Straddle Planche Volume Hold": "Back-off volume using the hardest straddle or near-straddle planche shape that remains clean.",
        "Serratus Wall Slide": "Wall slide emphasizing upward reach and shoulder blade control for protraction strength.",
        "Reverse Wrist Stretch": "Gentle wrist-flexor stretch used after heavy palm-loaded work.",
        "Knuckle Push-Up": "Push-up performed on the knuckles — wrist conditioning and neutral wrist alignment.",

        // Dip family
        "Bench Tricep Dip": "Tricep dip with hands on a bench behind you and feet on the floor.",
        "Assisted Bench Dip": "Bench dip regression where the legs help only enough to keep the shoulders controlled.",
        "Short-Range Bench Dip": "Bench dip practiced in a reduced pain-free range before adding depth.",
        "Bench Support Hold": "Top bench-dip support with straight arms, hips close to the bench, and shoulders organized.",
        "Bench Dip": "Dip with hands on a stable bench behind the hips, elbows tracking back, and shoulders controlled.",
        "Tempo Bench Dip": "Bench dip performed on a slow cadence to expose shoulder roll, bounce, or leg push.",
        "Negative Dip": "Slow 5-second descent on parallel bars; step or jump back up to recover.",
        "Band-Assisted Dip": "Bar dip with a band looped between the bars and your knees for assistance.",
        "Bar Support Hold": "Static hold at the top of a dip — arms locked, body upright.",
        "Dip AMRAP": "As-many-reps-as-possible strict bar dips in a single set.",
        "Tempo Dip": "Bar dip performed on a fixed cadence — slow descent, brief pause, controlled press.",
        "Tricep Extension (band or DB)": "Overhead or skullcrusher-style elbow extension to load the triceps directly.",
        "Band Tricep Extension": "Band-resisted elbow extension used for direct lockout strength.",
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
        "Bodyweight Leg Extension": "Reverse-Nordic style bodyweight knee extension from tall kneeling with hips open and quads controlling the lean.",
        "Tempo Bodyweight Leg Extension": "Bodyweight leg extension slowed down to keep the hips open and the knees in a pain-free track.",
        "Jumping Squat": "Explosive squat jump where only high, quiet, aligned landings count.",
        "Tempo Jumping Squat": "Controlled squat-jump rehearsal emphasizing the dip and landing mechanics more than fatigue.",
        "Box Jump": "Explosive jump to a box or platform with a quiet, stable landing.",
        "Tempo Box Jump": "Low-volume box-jump patterning with deliberate takeoff and landing positions.",
        "Nordic Curl": "Kneeling hamstring curl with ankles anchored and a straight body line.",
        "Tempo Nordic Curl": "Nordic curl slowed down so the hamstrings own the range without a sudden drop.",
        "Advanced Nordic Hip Hinge": "Harder Nordic progression that increases the forward hinge demand while preserving a straight body line.",
        "Tempo Advanced Nordic Hip Hinge": "Advanced Nordic hinge practiced on cadence for quality exposure.",

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
        "One-Arm Handstand Assisted Hold": "One-arm handstand practice using wall or fingertip support to preserve alignment after max attempts.",

        // Lever / ring arc
        "Feet-Assisted German Hang": "German hang with the feet helping dose shoulder extension so the bottom position stays reversible.",
        "Box-Assisted Skin the Cat": "Skin-the-cat pass-through on low rings or with feet on a box to keep the path controlled.",
        "Reverse Plank Shoulder Extension": "Reverse plank or table support used to prepare shoulder extension before German hangs.",
        "German Hang Hold": "Short controlled hold in shoulder extension, assisted as needed and never forced into pain.",
        "Assisted German Hang Depth": "Assisted German hang range practice that increases depth only when the exit stays smooth.",
        "Skin the Cat": "Straight-arm ring or bar pass-through into German hang and back, performed slowly both directions.",
        "Tuck Pass-Through": "Compact straight-arm pass-through drill for skin-the-cat mechanics.",
        "Tuck Back Lever": "Short-lever back lever hold with elbows locked, ribs controlled, and pelvis tucked.",
        "Front Lever Pull": "Straight-arm front-lever pulling drill that lifts through the lats without bending the elbows.",
        "Assisted 360 Ring Arc": "Feet- or band-assisted 360 ring arc through front-lever and back-lever lanes without releasing the rings.",
        "360 Ring Pull": "Full controlled ring arc through front side, inverted line, back side, and return without release.",
        "Partial 360 Ring Arc": "Shortened 360 ring arc trained only through the range the athlete can reverse.",
        "Tuck Front Lever Hold": "Tuck front lever hold with shoulders depressed, ribs down, and hips level with shoulders."
    ]

    /// Form cues per exercise — used by the explainer sheet when richer cues
    /// than the prescription's notes are available. Falls back to whatever
    /// the plan author included.
    private static let formCues: [String: [String]] = [
        "Active Bar Hang": [
            "Straight elbows with shoulders pulled down away from ears.",
            "Ribs stay quiet; do not swing or hold breath.",
            "Step down before grip failure forces a drop."
        ],
        "Wide Pull-Up": [
            "Choose the widest grip that still feels smooth in the shoulders.",
            "Pull elbows toward ribs, not out behind the body.",
            "Return to a straight-arm active hang before the next rep."
        ],
        "Banana Hold": [
            "Low back stays heavy to the floor; ribs pull toward pelvis.",
            "Reach long through fingers and toes without arching.",
            "Regress the limbs closer if breathing or lumbar contact breaks."
        ],
        "Tuck Planche Hold": [
            "Elbows locked before the feet float.",
            "Protract hard, lean forward, and keep knees tight.",
            "End the hold before shoulders sink or feet brush the floor."
        ],
        "Tuck Planche Push-Up": [
            "Start from the same floating tuck planche used in the hold.",
            "Bend elbows while keeping the lean and scapular push.",
            "Press out without letting the feet touch or the hips collapse."
        ],
        "Band-Assisted Tuck Planche Push-Up": [
            "Band supports the hips so the skill path stays honest.",
            "Keep feet off the floor and knees tucked through the whole rep.",
            "Reduce assistance only after clean depth and lockout are repeatable."
        ],
        "Tuck Planche Negative": [
            "Lower for 3-5 seconds from a real tuck planche.",
            "Step down before the tuck opens or shoulders dump.",
            "Treat the negative as practice for the press path, not survival."
        ],
        "Bench Dip": [
            "Hips stay close to the bench; elbows track back.",
            "Lower only to pain-free depth with shoulders controlled.",
            "Press to lockout without pushing the rep mostly through the legs."
        ],
        "Tempo Bench Dip": [
            "Three-second descent with no shoulder roll.",
            "Pause softly at the deepest controlled point.",
            "Keep feet assistance the same across the set."
        ],
        "Assisted Bench Dip": [
            "Use the legs just enough to keep the shoulders organized.",
            "Hands grip the bench; hips stay close.",
            "Add depth before moving the feet farther away."
        ],
        "German Hang Hold": [
            "Use rings low enough that the feet can assist if needed.",
            "Shoulders open gradually; no sharp pain or forced bottom range.",
            "Reverse out under control before the position feels jammed."
        ],
        "Skin the Cat": [
            "Straight arms and tight tuck through the pass-through.",
            "Lower into German hang slowly; do not drop into the end range.",
            "The return counts as much as the way down."
        ],
        "360 Ring Pull": [
            "Keep holding the rings; this is not a release skill.",
            "Move through front-lever and back-lever lanes with straight arms.",
            "Reverse cleanly before adding range or speed."
        ],
        "Partial 360 Ring Arc": [
            "Use only the arc length you can stop and reverse.",
            "Shoulders stay active through both front and back sides.",
            "No bouncing through German hang."
        ],
        "Hanging Knee Raise": [
            "Start from a still active hang.",
            "Raise knees toward chest, then curl tailbone toward ribs.",
            "Lower slowly enough that the next rep starts quiet."
        ],
        "Hanging Leg Raise": [
            "Straight knees and active shoulders from the bottom.",
            "Raise to at least parallel without throwing the feet.",
            "Control the descent; a swing reload ends the set."
        ],
        "Box Jump": [
            "Jump to a height you can land quietly.",
            "Knees track toes on takeoff and landing.",
            "Stop the set when height, sound, or alignment fades."
        ],
        "Jumping Squat": [
            "Dip with ribs controlled and heels rooted.",
            "Explode vertically; do not fold or twist for height.",
            "Land softly in the same squat track."
        ],
        "Nordic Curl": [
            "Anchor ankles and keep hips open with glutes on.",
            "Lower as one line; catch before the hamstrings drop you.",
            "Progress range slowly and avoid cramping through max volume."
        ],
        "Bodyweight Leg Extension": [
            "Start tall kneeling with glutes on and ribs stacked.",
            "Lean back by opening the knees, not by sitting the hips down.",
            "Use support or shorter range if knees or low back complain."
        ],
        "L-Sit Max Hold": [
            "Press shoulders down before lifting the legs.",
            "Knees stay locked and hips stay off the floor.",
            "Stop at the first form break, then accumulate another clean set."
        ],
        "Headstand Hold": [
            "Hands and crown form a tripod, but palms carry active pressure.",
            "Neck stays long and head contact stays light.",
            "Exit immediately on neck compression, tingling, or headache."
        ],
        "Wall-Supported One-Arm Handstand": [
            "Use the wall as fingertip or side-body feedback, not a backrest.",
            "Support shoulder stays tall while weight shifts into one hand.",
            "Exit before the hip dumps or the elbow bends."
        ],
        "One-Arm Handstand": [
            "Start from a stable straddle handstand, then taper the free hand.",
            "Support shoulder pushes tall; fingers steer tiny balance changes.",
            "Short clean attempts beat long saves with shoulder collapse."
        ],
        "Full One-Arm Handstand": [
            "Narrow toward the final line only after straddle holds are owned.",
            "Keep ribs stacked and support elbow locked.",
            "Count only unsupported seconds without wall or fingertip help."
        ]
    ]
}
