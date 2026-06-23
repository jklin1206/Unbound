import Foundation

extension SkillGraph {
    static let v3StrengthGapNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // CORE & LEVER (cl) — dynamic core + levers
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.hollow-body-30",
            title: "Hollow Body Hold",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "hollow body hold", seconds: 30),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.core], secondary: [],
            subtitle: "The universal core position behind every advanced skill.",
            description: "Lie on your back, arms overhead, legs straight, lower back pressed to floor. Ribs tucked, chin to chest. Foundation for front lever, planche, dragon flag, HSPU.",
            formCues: [
                "Lumbar spine glued to the floor",
                "Ribs tucked, not flaring",
                "Chin to chest",
                "Legs straight, toes pointed",
                "Arms overhead if possible"
            ],
            commonMistakes: [
                "Lumbar pulling off floor (back arch)",
                "Rib flare",
                "Legs bent to cheat"
            ],
            timeline: "2–6 weeks from untrained."
        ),
        .simple(
            id: "cl.hanging-knee-raise",
            title: "Hanging Knee Raise",
            cluster: .coreLever, tier: 5, type: .skill,
            target: .reps(exercise: "hanging knee raise", count: 10),
            prereqs: [PrerequisiteGroup("cl.leg-raise")],
            equipment: [.pullupBar],
            primary: [.core], secondary: [.lats, .forearms],
            subtitle: "Where visible abs start.",
            description: "10 hanging knee raises. Active hang from the bar, raise knees to chest, curl the pelvis, then lower with control.",
            formCues: [
                "Start from a still active hang — no swinging",
                "Raise knees to chest, not just to waist",
                "Curl tailbone toward ribs at the top",
                "Lower slowly enough that the descent does not create the next swing"
            ],
            commonMistakes: [
                "Swinging to use momentum",
                "Partial ROM — knees stop at 90°",
                "Shrugged shoulders while hanging"
            ],
            timeline: "2-8 weeks from first dead hang."
        ),
        .simple(
            id: "cl.hanging-leg-raise",
            title: "Hanging Leg Raise",
            cluster: .coreLever, tier: 6, type: .skill,
            target: .reps(exercise: "hanging leg raise", count: 10),
            prereqs: [PrerequisiteGroup("cl.hanging-knee-raise")],
            equipment: [.pullupBar],
            primary: [.core], secondary: [.lats],
            subtitle: "Strict hanging compression.",
            description: "10 hanging leg raises. Straight legs from dead hang to parallel or higher.",
            formCues: [
                "Start from a still active hang",
                "Legs straight throughout — locked knees",
                "Raise legs to parallel minimum, higher for clean reps",
                "Curl pelvis; do not throw feet for momentum",
                "Controlled 2s descent with no swing reload"
            ],
            commonMistakes: [
                "Bent knees mid-rep — that's a knee raise",
                "Kipping at the top for extra height",
                "Quickly dropping the eccentric"
            ],
            timeline: "1-3 months from knee raises.",
            isParallelToParent: true
        ),
        .simple(
            id: "cl.toes-to-bar",
            title: "Toes-to-Bar",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "toes to bar", count: 5),
            prereqs: [PrerequisiteGroup("cl.hanging-leg-raise")],
            equipment: [.pullupBar],
            primary: [.core, .lats],
            subtitle: "Compression test.",
            description: "5 strict toes-to-bar reps. Legs straight, toes touch the bar between your hands at the top.",
            formCues: [
                "Start from a still active hang, not a pendulum",
                "Initiate with a lat pull and pelvic curl",
                "Legs straight, compress hips to bring toes up",
                "Toes CONTACT the bar, not just near it",
                "Control the descent"
            ],
            commonMistakes: [
                "Kipping — a different CrossFit skill",
                "Bent knees to cheat the compression",
                "Toes clearly short of the bar"
            ],
            timeline: "1-4 months from leg raises."
        ),
        .simple(
            id: "cl.standing-ab-rollout",
            title: "Standing Ab Rollout",
            cluster: .coreLever, tier: 5, type: .skill,
            target: .reps(exercise: "standing ab rollout", count: 5),
            prereqs: [PrerequisiteGroup("cl.knee-ab-rollout")],
            primary: [.core, .shoulders], secondary: [.lats],
            subtitle: "Core + shoulder stability.",
            description: "5 standing ab rollouts from feet — toes down, hands on wheel, roll all the way out and come back. Beyond the kneeling rollout.",
            formCues: [
                "Hollow body throughout the rollout",
                "Shoulders stay protracted and active",
                "Glutes squeezed to prevent lumbar sag",
                "Build range slowly — don't chase full rollout on day one"
            ],
            commonMistakes: [
                "Lumbar sag — lower back arches under load",
                "Full rollout before you have the strength (injury risk)",
                "Holding breath instead of breathing through the rep"
            ],
            timeline: "3-12 months from kneeling rollout.",
            isParallelToParent: true
        ),
        .simple(
            id: "cl.dragon-flag",
            title: "Dragon Flag",
            cluster: .coreLever, tier: 5, type: .skill,
            target: .reps(exercise: "dragon flag", count: 5),
            prereqs: [PrerequisiteGroup("cl.dragon-flag-hip-raise")],
            primary: [.core], secondary: [.lats, .glutes],
            subtitle: "Bruce Lee's signature.",
            description: "Lying on a bench, grip behind head, body lifts to vertical then lowers as a single rigid line. Five clean reps with no hip-pike.",
            formCues: [
                "Grip hard behind the head — bench or pole",
                "Body rigid as plank — whole body lifts as one unit",
                "Shoulder blades stay pinned down — don't shrug",
                "Lower slow, 3-4s eccentric",
                "Don't touch the bench between reps at the bottom"
            ],
            commonMistakes: [
                "Piking at the hips — cheating the lever length",
                "Shoulders shrug up toward ears",
                "Swinging through reps instead of controlled reps"
            ],
            timeline: "6-18 months from leg raises."
        ),
        .simple(
            id: "cl.tuck-front-lever",
            title: "Tuck Front Lever",
            cluster: .pullingPower, tier: 4, type: .hold,
            target: .hold(exercise: "tuck front lever", seconds: 10),
            prereqs: [PrerequisiteGroup("pp.decline-row")],
            equipment: [.pullupBar],
            primary: [.lats, .core],
            subtitle: "Front lever on-ramp.",
            description: "Straight-arm tuck front lever from a bar or rings. Knees stay tight, hips rise to shoulder height, shoulders stay depressed, and the body holds face-up without elbow bend.",
            formCues: [
                "Set active shoulders first — down from the ears, then pull hands toward hips",
                "Lock elbows before the hips lift; no hidden row",
                "Keep knees tight to chest and heels close to glutes",
                "Bring hips to shoulder height, ribs down, pelvis tucked",
                "Breathe shallow and controlled without losing the hollow shape"
            ],
            commonMistakes: [
                "Bent arms — instantly easier but no longer the lever standard",
                "Hips drooping below shoulder line",
                "Shrugged shoulders that let the lats switch off",
                "Opening the tuck before the short lever is still"
            ],
            timeline: "3-9 months from 10 pullups + solid hanging core."
        ),
        .simple(
            id: "cl.straddle-front-lever",
            title: "Straddle Front Lever",
            cluster: .pullingPower, tier: 5, type: .hold,
            target: .hold(exercise: "straddle front lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.tuck-front-lever")],
            equipment: [.pullupBar],
            primary: [.lats, .core],
            subtitle: "Legs split. Lever longer.",
            description: "Front lever with legs extended wide in a split. Reduces the lever slightly vs full but still demands horizontal hold. 5 seconds.",
            formCues: [
                "Open from an owned tuck; do not kick into the straddle",
                "Keep elbows locked and shoulders depressed before the legs lengthen",
                "Extend legs wide and point toes; wider is easier but still strict",
                "Hips stay level with shoulders — no pike, no twist",
                "Close ribs and squeeze glutes so the low back does not arch"
            ],
            commonMistakes: [
                "Lazy split — legs drift together mid-hold",
                "Piking hips upward",
                "Losing shoulder depression as fatigue sets in",
                "Letting one leg carry higher than the other"
            ],
            timeline: "6-18 months from tuck front lever."
        ),
        .simple(
            id: "cl.full-front-lever",
            title: "Full Front Lever",
            cluster: .pullingPower, tier: 6, type: .hold,
            target: .hold(exercise: "front lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.straddle-front-lever")],
            isKeystone: true,
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.lats, .core], secondary: [.back, .arms],
            subtitle: "Horizontal lats, horizontal body.",
            description: "Hang from a bar or rings, body horizontal, face up, legs together and straight. Five seconds unbroken.",
            formCues: [
                "Depress the shoulders and drive straight arms toward the hips",
                "Posterior pelvic tilt — squeeze glutes, ribs tucked",
                "Point toes and glue legs together only after straddle stays level",
                "Elbows stay locked from entry through exit",
                "Use short crisp holds; stop before the line turns into a fight"
            ],
            commonMistakes: [
                "Bent arms as fatigue sets in",
                "Hips piking upward — hip-flexor dominant hold instead of lat",
                "Anterior pelvic tilt — lower back arches, legs drop",
                "Trying full before straddle seconds are calm"
            ],
            timeline: "1-3 years from tuck front lever."
        ),
        .simple(
            id: "cl.tuck-back-lever",
            title: "Tuck Back Lever",
            cluster: .pullingPower, tier: 4, type: .hold,
            target: .hold(exercise: "tuck back lever", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.skin-the-cat")],
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.shoulders, .chest, .core], secondary: [.lats, .arms],
            subtitle: "Back lever starts compact.",
            description: "A straight-arm tuck back lever from a controlled skin-the-cat route. Knees stay tight, shoulders tolerate extension, elbows stay locked, and the body pauses face-down before any straddle or full lever attempt.",
            formCues: [
                "Enter through German hang or skin the cat slowly",
                "Lock elbows before lowering toward horizontal",
                "Tuck knees tight to shorten the lever",
                "Keep shoulders active instead of dropping into the joint",
                "Exit under control through the same path"
            ],
            commonMistakes: [
                "Dropping into shoulder extension",
                "Bending elbows to survive the hold",
                "Opening the tuck before the shoulder line is calm",
                "Counting painful range as progress"
            ],
            timeline: "3-9 months from controlled skin-the-cat."
        ),
        .simple(
            id: "cl.straddle-back-lever",
            title: "Straddle Back Lever",
            cluster: .pullingPower, tier: 5, type: .hold,
            target: .hold(exercise: "straddle back lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.tuck-back-lever")],
            equipment: [.pullupBar],
            primary: [.shoulders, .chest, .core], secondary: [.lats, .arms],
            subtitle: "Legs split. Lever longer.",
            description: "Back lever from a controlled skin-the-cat path with legs extended wide. The body is face-down and horizontal while the shoulders tolerate extension and the elbows stay locked.",
            formCues: [
                "Enter through German hang or tuck back lever slowly",
                "Lock elbows and keep the shoulder angle active, never dropped",
                "Open to a wide straddle only as far as the body line survives",
                "Hips stay at shoulder height — no downward pike",
                "Squeeze glutes and close ribs so the low back stays quiet"
            ],
            commonMistakes: [
                "Lazy split — legs drift together mid-hold",
                "Bent arms as fatigue sets in",
                "Hips dropping below shoulder line",
                "Treating shoulder stretch discomfort as something to push through"
            ],
            timeline: "6-18 months from tuck back lever.",
            isParallelToParent: true
        ),
        .simple(
            id: "cl.full-back-lever",
            title: "Full Back Lever",
            cluster: .pullingPower, tier: 5, type: .hold,
            target: .hold(exercise: "back lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.straddle-back-lever")],
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.shoulders, .chest, .core],
            subtitle: "Horizontal, face down, straight arms.",
            description: "Hanging inverted from bar or rings, lower to horizontal body position face-down. Arms straight, body rigid. 5-second hold.",
            formCues: [
                "Build up slowly — shoulders and elbow tendons adapt slower than muscles",
                "Arms lock fully straight before the body lengthens",
                "Lower from tuck or straddle with control, not a drop",
                "Body stays in one face-down horizontal line",
                "Glutes, quads, and ribs stay braced until the exit is complete"
            ],
            commonMistakes: [
                "Rushing progression — connective tissue needs months",
                "Bent arms under load — injury risk",
                "Piking hips downward",
                "Counting a hold that can only be entered by falling into it"
            ],
            timeline: "6-18 months from tuck back lever."
        ),

        // ════════════════════════════════════════════════════════════════════
        // PHASE 2K — CONTENT AUDIT ADDITIONS
        //
        // Missing exercises added to approach parity with the Sport Is My
        // Game bodyweight reference infographic. Each batch is grouped by
        // cluster and ordered roughly by difficulty.
        // ════════════════════════════════════════════════════════════════════

        // ────────────────────────────────────────────────────────────────
        // PULL ADDITIONS — chin-up family + crossover plyometrics
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pp.chin-up",
            title: "Chin-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "chin-up", count: 5),
            prereqs: [PrerequisiteGroup("pp.dead-hang")],
            equipment: [.pullupBar],
            primary: [.arms, .lats], secondary: [.back],
            subtitle: "Underhand grip. Biceps join the pull.",
            description: "Strict chin-up — palms facing you, chin clears the bar from a full dead hang. Biceps-dominant cousin of the pullup.",
            formCues: [
                "Supinated grip — palms face your body",
                "Start at dead hang with active shoulders",
                "Drive elbows down and back",
                "Chest rises toward the bar",
                "Control the descent, no drop"
            ],
            commonMistakes: [
                "Kipping with the knees",
                "Not reaching dead hang between reps",
                "Shrugging shoulders at the top"
            ],
            timeline: "4-10 weeks from first chin-up attempt."
        ),
        .simple(
            id: "pp.strict-chin-up",
            title: "Strict Chin-Up",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "chin-up", count: 8),
            prereqs: [PrerequisiteGroup("pp.chin-up")],
            equipment: [.pullupBar],
            primary: [.arms, .lats], secondary: [.back, .core],
            subtitle: "Chin-up volume benchmark.",
            description: "Strict chin-ups unbroken from dead hang. First real capacity test on the underhand grip.",
            formCues: [
                "Full dead hang each rep",
                "No kipping — hips stay still",
                "Slow eccentric to preserve form late in the set",
                "Breathe at the dead hang, not the top"
            ],
            commonMistakes: [
                "Partial reps as fatigue sets in",
                "Letting the elbows flare out",
                "Bouncing out of the dead hang"
            ],
            timeline: "2-6 months from first chin-up."
        ),
        .simple(
            id: "pp.weighted-chin-up",
            title: "Weighted Chin-Up",
            cluster: .pullingPower, tier: 5, type: .strength,
            target: .weightMultiplier(exercise: "weighted chin-up", multiplier: 0.5),
            prereqs: [PrerequisiteGroup("pp.strict-chin-up")],
            equipment: [.pullupBar, .dumbbells],
            primary: [.arms, .lats], secondary: [.back],
            subtitle: "Load the underhand pull.",
            description: "Chin-up with a weighted belt or dumbbell held between the feet. Sweeps from 0.1× bodyweight up to a full bodyweight chin-up.",
            formCues: [
                "Same strict form as bodyweight chin-up",
                "Add load in small increments",
                "Dead hang reset between reps",
                "Slow eccentric — load destroys sloppy descents"
            ],
            commonMistakes: [
                "Adding too much weight too fast",
                "Kipping to fight the load",
                "Losing dead hang reset when fatigue hits"
            ],
            timeline: "1-2 years from strict chin-up × 8."
        ),
        .simple(
            id: "pp.l-sit-chin-up",
            title: "L-Sit Chin-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "l-sit chin-up", count: 5),
            prereqs: [PrerequisiteGroup(["pp.strict-chin-up", "cal.l-sit-10"])],
            equipment: [.pullupBar],
            primary: [.arms, .lats, .core], secondary: [.back],
            subtitle: "Chin-up while holding an L-sit.",
            description: "Chin-up from a dead hang with legs locked out horizontally in L-sit position. 3 clean reps — combines pulling strength with core compression.",
            formCues: [
                "Enter in full L-sit before the pull",
                "Legs stay locked and parallel throughout",
                "Drive elbows down, keep the L-sit shape",
                "Slow descent — no leg drop on the eccentric"
            ],
            commonMistakes: [
                "Legs dropping mid-rep to steal reps",
                "Bent knees — loses the L-sit standard",
                "Kipping with the core to lift the body"
            ],
            timeline: "4-12 months from strict chin-up + L-sit."
        ),
        .simple(
            id: "pp.wide-pullup",
            title: "Wide Pull-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "wide pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.strict-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .back], secondary: [.arms],
            subtitle: "Wider grip, more lat.",
            description: "Strict pullups with hands set outside shoulder width only as far as the shoulders stay smooth. Lat-dominant — emphasizes back width without turning width into joint strain.",
            formCues: [
                "Grip slightly to moderately outside shoulder width, palms away",
                "Drive elbows DOWN to the ribs",
                "Chest to the bar, not chin",
                "Return to a straight-arm active hang each rep"
            ],
            commonMistakes: [
                "Going too wide — shoulders grind",
                "Partial ROM because leverage drops at width",
                "Shrugging to cheat the last inch"
            ],
            timeline: "1-4 months from strict pullup × 5."
        ),
        .simple(
            id: "pp.explosive-pullup",
            title: "Explosive Pull-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "explosive pullup", count: 3),
            prereqs: [PrerequisiteGroup("pp.strict-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "Pull hard enough the hands come off.",
            description: "Pullups where the concentric is explosive enough that hands briefly leave the bar at the top. Bridge between strict pullup and muscle-up.",
            formCues: [
                "Full dead hang start",
                "Accelerate aggressively on the concentric",
                "Pull chest to bar, let hands release briefly",
                "Re-grip and lower with control"
            ],
            commonMistakes: [
                "Kipping for height instead of pulling",
                "Missing the re-grip and dropping",
                "Partial ROM under the explosive cue"
            ],
            timeline: "2-6 months from strict pullup mastery."
        ),
        .simple(
            id: "pp.clapping-pullup",
            title: "Clapping Pull-Up",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "clapping pullup", count: 1),
            prereqs: [PrerequisiteGroup("pp.explosive-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core],
            subtitle: "Pull high enough to clap before catching.",
            description: "Clapping pullup — pull explosively enough to release the bar, clap hands at chest, and re-grip before the descent. Bar-muscle-up prerequisite for most athletes.",
            formCues: [
                "Explosive pullup first, then add the clap",
                "Clap at chest level, not overhead",
                "Re-grip with both hands simultaneously",
                "Absorb the catch, don't crash into dead hang"
            ],
            commonMistakes: [
                "Missing the re-grip and dropping",
                "Kipping to fake the height",
                "Shrugging shoulders on the re-catch"
            ],
            timeline: "6-18 months from explosive pullup."
        ),

    ]
}
