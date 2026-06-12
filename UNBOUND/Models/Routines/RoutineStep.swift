import Foundation

/// Styles the timed-step ring: work uses the routine's category accent;
/// rest uses a recovery (muted) treatment.
enum TimedStyle: String, Codable, Hashable, Sendable {
    case work
    case rest
}

/// One segment of an interval block, e.g. WORK 20s / REST 10s.
struct IntervalSegment: Codable, Hashable, Sendable {
    let label: String
    let seconds: Int

    init(label: String, seconds: Int) {
        self.label = label
        self.seconds = seconds
    }
}

/// A typed routine step. Replaces the old free-text `[String]` + regex
/// parser. The player renders each kind in its own face; `.note` is never
/// advanced through (it is context), `.circuit` is expanded at runtime.
indirect enum RoutineStep: Codable, Hashable, Sendable {
    case instruction(text: String, cue: String?)
    case timed(label: String, seconds: Int, style: TimedStyle)
    case interval(label: String, rounds: Int, segments: [IntervalSegment])
    /// `target == nil` ⇒ AMRAP (open tally, user ends manually).
    case repTarget(name: String, target: Int?, cue: String?)
    case circuit(rounds: Int, restBetweenSeconds: Int, steps: [RoutineStep])
    case note(text: String)
}

enum MobilityReferenceVisualType: String, Hashable, Sendable {
    case singlePose
    case startEnd
}

struct MobilityReference: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let targetArea: String
    let cue: String
    let aliases: [String]
    let visualType: MobilityReferenceVisualType
    let cameraAngle: String
    let primaryPose: String
    let secondaryPose: String?

    var assetName: String { "mobility_reference_\(id)" }
    var startAssetName: String { "\(assetName)_start" }
    var endAssetName: String { "\(assetName)_end" }
    var expectedAssetNames: [String] {
        switch visualType {
        case .singlePose:
            return [assetName]
        case .startEnd:
            return [startAssetName, endAssetName]
        }
    }
}

enum MobilityReferenceLibrary {
    static let all: [MobilityReference] = [
        ref(
            "cat_cow",
            "Cat-Cow",
            area: "Spine",
            cue: "Move segment by segment. Exhale to round, inhale to arch.",
            aliases: ["cat cow", "cat-cow"],
            frames: [
                ("SET", "Hands under shoulders, knees under hips."),
                ("CAT", "Push the floor away and round the upper back."),
                ("COW", "Drop the ribs gently and open the chest."),
                ("FLOW", "Cycle slowly without rushing the neck.")
            ]
        ),
        ref(
            "worlds_greatest_stretch",
            "World's Greatest Stretch",
            area: "Hips + T-Spine",
            cue: "Long lunge, hand inside foot, rotate through the ribs.",
            aliases: ["worlds greatest stretch", "world s greatest stretch"],
            frames: [
                ("LUNGE", "Front foot flat, back leg long."),
                ("ELBOW", "Sink the inside elbow toward the instep."),
                ("ROTATE", "Reach the same-side arm to the ceiling."),
                ("SWITCH", "Step back cleanly and repeat the other side.")
            ]
        ),
        ref(
            "thread_the_needle",
            "Thread the Needle",
            area: "T-Spine",
            cue: "Rotate the rib cage, not the low back.",
            aliases: ["thread the needle"],
            frames: [
                ("TABLE", "Start square on hands and knees."),
                ("REACH", "Slide one arm under the chest."),
                ("OPEN", "Reverse and reach upward through the ribs."),
                ("RESET", "Return to square before switching sides.")
            ]
        ),
        ref(
            "thoracic_rotation",
            "Thoracic Rotation",
            area: "T-Spine + Chest",
            cue: "Keep the lower body quiet so the upper back does the work.",
            aliases: ["thoracic rotation", "open book", "side lying rotation"],
            frames: [
                ("SIDE", "Stack shoulders and hips."),
                ("PIN", "Keep the top knee grounded."),
                ("OPEN", "Rotate the shoulder blade toward the floor."),
                ("BREATHE", "Pause without forcing the end range.")
            ]
        ),
        ref(
            "hip_90_90_switch",
            "90-90 Hip Switch",
            area: "Hips",
            cue: "Keep the chest tall and rotate from the hips.",
            aliases: ["hip 90 90", "90 90 switch", "90-90", "shin box"],
            frames: [
                ("SIT", "Both knees bent around 90 degrees."),
                ("TALL", "Chest up, hands light if needed."),
                ("SWITCH", "Rotate both knees to the other side."),
                ("CONTROL", "Land softly without collapsing.")
            ]
        ),
        ref(
            "shoulder_cars",
            "Shoulder CARs",
            area: "Shoulders",
            cue: "Make the biggest pain-free circle while ribs stay down.",
            aliases: ["shoulder car", "shoulder cars", "shoulder circles"],
            frames: [
                ("TALL", "Stand tall with ribs stacked."),
                ("FRONT", "Reach forward and up."),
                ("OVER", "Circle overhead without shrugging hard."),
                ("BACK", "Sweep behind the body and reset.")
            ]
        ),
        ref(
            "deep_squat_hold",
            "Deep Squat Hold",
            area: "Ankles + Hips",
            cue: "Tripod feet, knees track toes, breathe into the bottom.",
            aliases: ["deep squat hold", "squat hold"],
            frames: [
                ("STANCE", "Feet under shoulders, toes slightly out."),
                ("SINK", "Knees track over toes as hips descend."),
                ("HOLD", "Chest open, heels down if possible."),
                ("RISE", "Stand without knees collapsing inward.")
            ]
        ),
        ref(
            "hip_flexor_stretch",
            "Hip Flexor Stretch",
            area: "Hip Flexors",
            cue: "Tuck the pelvis first, then glide forward lightly.",
            aliases: ["hip flexor stretch", "deep lunge hold", "kneeling hip flexor"],
            frames: [
                ("KNEEL", "Back knee down, front foot flat."),
                ("TUCK", "Squeeze the rear glute and tuck pelvis."),
                ("GLIDE", "Move forward without arching the low back."),
                ("REACH", "Add an overhead reach if it stays clean.")
            ]
        ),
        ref(
            "couch_stretch",
            "Couch Stretch",
            area: "Quads + Hip Flexors",
            cue: "Rear glute on, ribs down. Do not dump into the low back.",
            aliases: ["couch stretch"],
            frames: [
                ("SET", "Back shin against wall or couch."),
                ("KNEEL", "Front foot steps into a lunge."),
                ("STACK", "Torso rises with ribs down."),
                ("BREATHE", "Hold the clean range, then switch.")
            ]
        ),
        ref(
            "hamstring_fold",
            "Hamstring Fold",
            area: "Hamstrings",
            cue: "Hinge from the hips and keep the knee softly unlocked.",
            aliases: ["hamstring fold", "standing hamstring", "toe touch"],
            frames: [
                ("HINGE", "Push hips back with a long spine."),
                ("FOLD", "Let the torso lower without bouncing."),
                ("BREATHE", "Hold tension you can breathe through."),
                ("RISE", "Stand by driving hips forward.")
            ]
        ),
        ref(
            "half_kneeling_hamstring_rock",
            "Hamstring Rock",
            area: "Hamstrings",
            cue: "Rock back until the stretch appears, then return smooth.",
            aliases: ["hamstring rock", "half kneeling hamstring"],
            frames: [
                ("KNEEL", "One knee down, front heel forward."),
                ("FLEX", "Pull the toes toward the shin."),
                ("ROCK", "Shift hips back with spine long."),
                ("RETURN", "Come forward without losing control.")
            ]
        ),
        ref(
            "figure_four",
            "Figure-4 Stretch",
            area: "Glutes + Hips",
            cue: "Keep the ankle crossed above the knee, not on the knee.",
            aliases: ["figure 4", "figure-4", "piriformis"],
            frames: [
                ("CROSS", "Cross ankle above the opposite knee."),
                ("DRAW", "Pull the support leg toward the chest."),
                ("HOLD", "Keep the crossed foot active."),
                ("SWITCH", "Uncross slowly and repeat.")
            ]
        ),
        ref(
            "pigeon_pose",
            "Pigeon Pose",
            area: "Glutes + Hips",
            cue: "Square the hips enough to feel the glute, not the knee.",
            aliases: ["pigeon pose", "pigeon"],
            frames: [
                ("SET", "Front shin angled across the body."),
                ("SQUARE", "Back leg long, hips heavy."),
                ("FOLD", "Lower only as far as the knee stays quiet."),
                ("EXIT", "Press back out before switching sides.")
            ]
        ),
        ref(
            "seated_forward_fold",
            "Seated Forward Fold",
            area: "Hamstrings + Back",
            cue: "Reach long first, then fold. Do not yank on the toes.",
            aliases: ["seated forward fold", "seated fold"],
            frames: [
                ("SIT", "Legs long, toes up."),
                ("REACH", "Lengthen through crown and fingertips."),
                ("FOLD", "Hinge forward while breathing."),
                ("RESET", "Roll up slowly with control.")
            ]
        ),
        ref(
            "spinal_twist",
            "Spinal Twist",
            area: "Spine + Hips",
            cue: "Rotate gradually and keep the breath easy.",
            aliases: ["spinal twist", "supine twist", "seated twist"],
            frames: [
                ("SET", "Lie back or sit tall."),
                ("CROSS", "Guide one knee across the body."),
                ("OPEN", "Reach the opposite arm wide."),
                ("SWITCH", "Return through center before changing sides.")
            ]
        ),
        ref(
            "frog_stretch",
            "Frog Stretch",
            area: "Adductors",
            cue: "Knees wide, shins parallel, hips shift back gently.",
            aliases: ["frog stretch"],
            frames: [
                ("WIDE", "Set knees wide with padding if needed."),
                ("SHINS", "Keep shins roughly parallel."),
                ("BACK", "Rock hips back until adductors load."),
                ("BREATHE", "Hold without collapsing the low back.")
            ]
        ),
        ref(
            "lat_prayer_stretch",
            "Lat Prayer Stretch",
            area: "Lats + Shoulders",
            cue: "Hips back, ribs down, arms long.",
            aliases: ["lat prayer", "prayer stretch", "child pose reach", "child's pose reach"],
            frames: [
                ("KNEEL", "Hands forward, knees under hips."),
                ("REACH", "Walk hands long on the floor."),
                ("SINK", "Hips drift back without shrugging."),
                ("ANGLE", "Reach to either side for lats.")
            ]
        ),
        ref(
            "wall_pec_stretch",
            "Wall Pec Stretch",
            area: "Chest + Shoulders",
            cue: "Shoulder stays down as the torso turns away.",
            aliases: ["wall pec", "pec stretch", "doorway stretch"],
            frames: [
                ("PLANT", "Forearm or palm on wall."),
                ("STEP", "Step the same-side foot forward."),
                ("TURN", "Rotate chest away gently."),
                ("RESET", "Back out before switching angles.")
            ]
        ),
        ref(
            "wrist_rocks",
            "Wrist Rocks",
            area: "Wrists",
            cue: "Small rocks, full palm contact, no sharp pressure.",
            aliases: ["wrist rocks", "wrist prep", "wrist circles"],
            frames: [
                ("PALMS", "Hands flat under shoulders."),
                ("FORWARD", "Rock shoulders past wrists softly."),
                ("BACK", "Shift hips back and unload."),
                ("REVERSE", "Turn fingers back only if pain-free.")
            ]
        ),
        ref(
            "knee_to_wall_ankle",
            "Knee-to-Wall Ankle Rock",
            area: "Ankles",
            cue: "Heel down, knee tracks over the middle toes.",
            aliases: ["knee to wall", "ankle rock", "ankle dorsiflexion"],
            frames: [
                ("STANCE", "Front foot near wall, heel down."),
                ("TRACK", "Knee moves over second and third toe."),
                ("TOUCH", "Tap wall without heel lift."),
                ("STEP", "Move foot back as range improves.")
            ]
        ),
        ref(
            "calf_pedal",
            "Calf Pedal",
            area: "Calves + Ankles",
            cue: "Alternate heels down while pressing the floor away.",
            aliases: ["calf pedal", "downward dog calf", "calf stretch"],
            frames: [
                ("PIKE", "Hands down, hips high."),
                ("LEFT", "Bend one knee, press opposite heel down."),
                ("RIGHT", "Switch sides smoothly."),
                ("FLOW", "Keep shoulders long and breathing steady.")
            ]
        ),
        ref(
            "quad_stretch",
            "Quad Stretch",
            area: "Quads",
            cue: "Knees close, glute lightly on, ribs stacked.",
            aliases: ["quad stretch", "stretch quads"],
            frames: [
                ("BALANCE", "Stand tall, use support if needed."),
                ("GRAB", "Hold ankle without cranking the knee."),
                ("TUCK", "Squeeze glute and stack ribs."),
                ("SWITCH", "Release slowly before changing sides.")
            ]
        ),
        ref(
            "hip_circles",
            "Hip Circles",
            area: "Hips",
            cue: "Draw the circle from the hip socket, not the low back.",
            aliases: ["hip circles", "hip cars", "hip car"],
            frames: [
                ("STAND", "Tall posture, light support."),
                ("LIFT", "Knee comes forward."),
                ("OPEN", "Rotate out to the side."),
                ("SWEEP", "Circle back and reset.")
            ]
        ),
        ref(
            "side_lying_clamshell",
            "Side-Lying Clamshell",
            area: "Glute Med",
            cue: "Hips stacked, feet together, open from the side hip.",
            aliases: ["side lying clamshell", "side-lying clamshell", "clamshell"],
            frames: [
                ("STACK", "Lie on side with knees bent."),
                ("BRACE", "Keep hips from rolling back."),
                ("OPEN", "Lift top knee while feet stay together."),
                ("LOWER", "Return slowly with control.")
            ]
        ),
        ref(
            "lateral_band_walk",
            "Lateral Band Walk",
            area: "Glutes + Hips",
            cue: "Soft knees, toes forward, constant band tension.",
            aliases: ["lateral band walk", "lateral walk", "side steps"],
            frames: [
                ("SET", "Band above knees or ankles."),
                ("ATHLETIC", "Soft knees, hips back."),
                ("STEP", "Step sideways without feet snapping together."),
                ("RETURN", "Keep tension as you travel back.")
            ]
        ),
        ref(
            "glute_bridge",
            "Glute Bridge",
            area: "Glutes + Hips",
            cue: "Ribs down, drive through heels, stop before low-back arch.",
            aliases: ["glute bridge", "bridge"],
            frames: [
                ("SET", "Feet flat, knees bent."),
                ("BRACE", "Ribs down, pelvis neutral."),
                ("LIFT", "Drive hips up by squeezing glutes."),
                ("LOWER", "Return one segment at a time.")
            ]
        )
    ]

    static func reference(for text: String) -> MobilityReference? {
        let textKey = normalized(text)
        guard !textKey.isEmpty else { return nil }

        return all.first { reference in
            reference.matchKeys.contains { key in
                textKey.contains(key) || key.contains(textKey)
            }
        }
    }

    private static func ref(
        _ id: String,
        _ title: String,
        area: String,
        cue: String,
        aliases: [String],
        frames: [(String, String)]
    ) -> MobilityReference {
        MobilityReference(
            id: id,
            title: title,
            targetArea: area,
            cue: cue,
            aliases: aliases,
            visualType: visualType(for: id),
            cameraAngle: cameraAngle(for: id),
            primaryPose: primaryPose(from: frames, visualType: visualType(for: id)),
            secondaryPose: secondaryPose(from: frames, visualType: visualType(for: id))
        )
    }

    private static func visualType(for id: String) -> MobilityReferenceVisualType {
        let dynamicIds: Set<String> = [
            "cat_cow",
            "worlds_greatest_stretch",
            "thread_the_needle",
            "thoracic_rotation",
            "hip_90_90_switch",
            "shoulder_cars",
            "half_kneeling_hamstring_rock",
            "wrist_rocks",
            "knee_to_wall_ankle",
            "calf_pedal",
            "hip_circles",
            "side_lying_clamshell",
            "lateral_band_walk",
            "glute_bridge"
        ]
        return dynamicIds.contains(id) ? .startEnd : .singlePose
    }

    private static func cameraAngle(for id: String) -> String {
        switch id {
        case "deep_squat_hold", "frog_stretch", "figure_four", "hip_90_90_switch":
            return "front three-quarter view"
        case "wall_pec_stretch", "lat_prayer_stretch", "spinal_twist":
            return "side three-quarter view"
        case "thread_the_needle", "thoracic_rotation":
            return "top/front oblique view"
        default:
            return "clean side view"
        }
    }

    private static func primaryPose(
        from frames: [(String, String)],
        visualType: MobilityReferenceVisualType
    ) -> String {
        switch visualType {
        case .singlePose:
            return frames.dropFirst().dropLast().last?.1 ?? frames.last?.1 ?? ""
        case .startEnd:
            return frames.first?.1 ?? ""
        }
    }

    private static func secondaryPose(
        from frames: [(String, String)],
        visualType: MobilityReferenceVisualType
    ) -> String? {
        guard visualType == .startEnd else { return nil }
        return frames.dropFirst().dropLast().last?.1 ?? frames.last?.1
    }

    private static func normalized(_ value: String) -> String {
        let tokens = value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return tokens.joined(separator: " ")
    }
}

enum RoutineStepVisualLibrary {
    struct Match: Hashable, Sendable {
        let phrases: [String]
        let assetName: String
    }

    static let matches: [Match] = [
        Match(phrases: ["weighted pull up", "weighted pullup"], assetName: "exercise_visual_exercise_weighted-pullup"),
        Match(phrases: ["negative pull up", "negative pullup", "eccentric pull up"], assetName: "exercise_visual_exercise_negative-pullup"),
        Match(phrases: ["wide grip pull up", "wide grip pullup"], assetName: "exercise_visual_exercise_wide-grip-pullup"),
        Match(phrases: ["pull up", "pullup"], assetName: "exercise_visual_exercise_pullup"),
        Match(phrases: ["chin up", "chinup"], assetName: "exercise_visual_exercise_chin-up"),
        Match(phrases: ["australian row", "inverted row", "bodyweight row"], assetName: "exercise_visual_exercise_inverted-row"),
        Match(phrases: ["band row", "banded row"], assetName: "exercise_visual_exercise_band-row"),
        Match(phrases: ["db bent over row", "dumbbell bent over row", "single arm db row", "single arm dumbbell row", "db row", "dumbbell row"], assetName: "exercise_visual_exercise_dumbbell-row"),
        Match(phrases: ["bent over row"], assetName: "exercise_visual_exercise_bent-over-row"),

        Match(phrases: ["diamond push up", "diamond pushup"], assetName: "exercise_visual_exercise_diamond-pushup"),
        Match(phrases: ["pike push up", "pike pushup"], assetName: "exercise_visual_exercise_pike-pushup"),
        Match(phrases: ["incline push up", "incline pushup"], assetName: "exercise_visual_exercise_incline-pushup"),
        Match(phrases: ["decline push up", "decline pushup"], assetName: "exercise_visual_exercise_decline-pushup"),
        Match(phrases: ["push up", "pushup"], assetName: "exercise_visual_exercise_pushup"),
        Match(phrases: ["dips", "dip "], assetName: "exercise_visual_exercise_dip"),
        Match(phrases: ["bench press", "chest press"], assetName: "exercise_visual_exercise_dumbbell-bench-press"),
        Match(phrases: ["db shoulder press", "dumbbell shoulder press", "db overhead press", "dumbbell overhead press"], assetName: "exercise_visual_exercise_dumbbell-overhead-press"),
        Match(phrases: ["overhead press", "shoulder press"], assetName: "exercise_visual_exercise_overhead-press"),

        Match(phrases: ["goblet squat"], assetName: "exercise_visual_exercise_goblet-squat"),
        Match(phrases: ["jump squat"], assetName: "exercise_visual_exercise_jump-squat"),
        Match(phrases: ["front squat"], assetName: "exercise_visual_exercise_front-squat"),
        Match(phrases: ["back squat"], assetName: "exercise_visual_exercise_back-squat"),
        Match(phrases: ["bodyweight squat", "air squat"], assetName: "exercise_visual_exercise_bodyweight-squat"),
        Match(phrases: ["walking lunge", "reverse lunge", "lunges", "lunge"], assetName: "exercise_visual_exercise_walking-lunge"),
        Match(phrases: ["step up", "step-up"], assetName: "exercise_visual_exercise_step-up"),

        Match(phrases: ["db romanian deadlift", "dumbbell romanian deadlift"], assetName: "exercise_visual_exercise_dumbbell-romanian-deadlift"),
        Match(phrases: ["romanian deadlift", "rdl"], assetName: "exercise_visual_exercise_romanian-deadlift"),
        Match(phrases: ["deadlift"], assetName: "exercise_visual_exercise_deadlift"),
        Match(phrases: ["kettlebell swing"], assetName: "exercise_visual_exercise_kettlebell-swing"),
        Match(phrases: ["glute bridge", "glute bridges"], assetName: "exercise_visual_exercise_glute-bridge"),
        Match(phrases: ["hip thrust"], assetName: "exercise_visual_exercise_hip-thrust"),

        Match(phrases: ["hanging knee raise"], assetName: "exercise_visual_exercise_hanging-knee-raise"),
        Match(phrases: ["hanging leg raise"], assetName: "exercise_visual_exercise_hanging-leg-raise"),
        Match(phrases: ["hollow body hold", "hollow hold"], assetName: "exercise_visual_exercise_hollow-hold"),
        Match(phrases: ["hollow rock"], assetName: "exercise_visual_exercise_hollow-rock"),
        Match(phrases: ["plank"], assetName: "exercise_visual_exercise_plank"),
        Match(phrases: ["l sit", "l-sit"], assetName: "exercise_visual_exercise_l-sit"),
        Match(phrases: ["ab wheel"], assetName: "exercise_visual_exercise_ab-wheel"),
        Match(phrases: ["pallof press"], assetName: "exercise_visual_exercise_pallof-press"),

        Match(phrases: ["db curl", "dumbbell curl"], assetName: "exercise_visual_exercise_dumbbell-curl")
    ]

    static var expectedAssetNames: [String] {
        Array(Set(matches.map(\.assetName))).sorted()
    }

    static func assetName(for text: String) -> String? {
        let key = normalized(text)
        guard !key.isEmpty else { return nil }
        return matches.first { match in
            match.phrases.contains { phrase in
                key.contains(normalized(phrase))
            }
        }?.assetName
    }

    private static func normalized(_ value: String) -> String {
        let tokens = value
            .lowercased()
            .replacingOccurrences(of: "db", with: "dumbbell")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return tokens.joined(separator: " ")
    }
}

private extension MobilityReference {
    var matchKeys: [String] {
        ([title] + aliases).map(MobilityReferenceLibrary.normalizedForMatching)
    }
}

private extension MobilityReferenceLibrary {
    static func normalizedForMatching(_ value: String) -> String {
        normalized(value)
    }
}
