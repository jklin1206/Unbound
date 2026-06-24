import Foundation

extension SkillGraph {
    static let v3CarryMobilityNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // PUSH ADDITIONS — pushup regressions, variants, plyos, dip family
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.incline-pushup",
            title: "Incline Push-Up",
            cluster: .calisthenicControl, tier: 1, type: .skill,
            target: .reps(exercise: "incline pushup", count: 10),
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "The pushup on-ramp.",
            description: "Hands on a bench or box, feet on the floor. 10 clean reps at a reduced lever — the starting point for anyone who can't yet hit a strict floor pushup.",
            formCues: [
                "Hands slightly wider than shoulders on the bench",
                "Body rigid as plank from head to heel",
                "Chest touches the bench",
                "Elbows tuck to ~45°, not flared"
            ],
            commonMistakes: [
                "Hips sagging under the bench",
                "Partial ROM — not touching the bench",
                "Using a bench too tall — reduces useful loading"
            ],
            timeline: "1-4 weeks for most beginners."
        ),
        .simple(
            id: "cal.decline-pushup",
            title: "Decline Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "decline pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pushup")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.chest, .shoulders, .arms], secondary: [.core],
            subtitle: "Feet up. Shoulders light up.",
            description: "Feet elevated on a bench or box, hands on floor. 10 clean reps — shifts the load onto the upper chest and front delts.",
            formCues: [
                "Feet elevated around knee height or higher",
                "Hands under shoulders, elbows ~45°",
                "Body rigid — don't let hips pike",
                "Full ROM: chest kisses floor"
            ],
            commonMistakes: [
                "Piking the hips to shorten lever",
                "Going too tall on the elevation too soon",
                "Elbow flare under the shoulder load"
            ],
            timeline: "2-4 weeks from 10 standard pushups."
        ),
        .simple(
            id: "cal.sphinx-pushup",
            title: "Sphinx Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "sphinx pushup", count: 8),
            prereqs: [PrerequisiteGroup("cal.pike-pushup")],
            primary: [.arms], secondary: [.chest, .shoulders, .core],
            subtitle: "Triceps in isolation.",
            description: "Pushup on forearms — start from elbow plank, press up through the forearms until elbows lock out. 8 clean reps. Direct tricep hypertrophy.",
            formCues: [
                "Start elbow plank, forearms flat",
                "Press through the forearms until arms lock",
                "Body rigid — no hip sag or pike",
                "Control the descent back to forearm plank"
            ],
            commonMistakes: [
                "Hips rising for leverage",
                "Partial ROM — not full elbow lockout at top",
                "Rushing the eccentric"
            ],
            timeline: "2-4 weeks from 10 pike pushups."
        ),
        .simple(
            id: "cal.archer-pushup",
            title: "Archer Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "archer pushup", count: 3),
            prereqs: [PrerequisiteGroup("cal.decline-pushup")],
            primary: [.chest, .arms], secondary: [.shoulders, .core],
            subtitle: "Unilateral pushup on-ramp.",
            description: "Hands wide, weight shifts to one side as you descend — working arm bends deep, off arm stays straight. 3 reps per side. Bridge to the one-arm pushup.",
            formCues: [
                "Hands well outside shoulders",
                "Shift weight to one hand, descend on that side",
                "Off arm stays straight, acts as support",
                "Alternate sides each rep or finish one side first"
            ],
            commonMistakes: [
                "Not committing the weight shift — pushup stays centered",
                "Off arm bending to assist",
                "Chest not touching on the working side"
            ],
            timeline: "2-6 months from decline pushup."
        ),
        .simple(
            id: "cal.one-arm-pushup",
            title: "One-Arm Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "one-arm pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.archer-pushup")],
            primary: [.chest, .arms, .shoulders, .core],
            subtitle: "Full bodyweight on one arm.",
            description: "One strict one-arm pushup. Feet wide for balance, body rigid, chest touches the floor, arm locks out at the top.",
            formCues: [
                "Feet wider than shoulders for base",
                "Free hand behind the back or at hip",
                "Hips don't rotate — body stays flat",
                "Full chest-to-floor, full lockout top"
            ],
            commonMistakes: [
                "Rotating the hips to cheat the lever",
                "Partial ROM",
                "Using free arm as secret support"
            ],
            timeline: "6-18 months from archer pushup."
        ),
        .simple(
            id: "cal.explosive-pushup",
            title: "Explosive Push-Up",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "explosive pushup", count: 5),
            prereqs: [PrerequisiteGroup("cal.decline-pushup")],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "Ballistic pressing. Airtime included.",
            description: "5 pushups with an aggressive concentric that launches the hands off the floor. Bridge to the clapping pushup.",
            formCues: [
                "Regular pushup descent with control",
                "Explode up so hands leave the ground",
                "Land with elbows slightly bent to absorb",
                "Maintain rigid plank through each rep"
            ],
            commonMistakes: [
                "Landing with locked elbows — shoulder risk",
                "Half-committing the launch",
                "Piking the hips to push off higher"
            ],
            timeline: "2-6 weeks from decline pushup.",
            isParallelToParent: true
        ),
        .simple(
            id: "cal.clapping-pushup",
            title: "Clapping Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "clapping pushup", count: 3),
            prereqs: [PrerequisiteGroup("cal.explosive-pushup")],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "Push high enough to clap.",
            description: "3 pushups where the concentric is explosive enough to clap the hands at chest before landing. Classic plyometric benchmark.",
            formCues: [
                "Explode up, clap once at chest level",
                "Catch with slightly bent elbows",
                "Plank remains rigid — no pike during the clap",
                "Reset between reps if rhythm breaks"
            ],
            commonMistakes: [
                "Clapping at hips (not enough airtime)",
                "Landing stiff-armed",
                "Cheating with hip dip for liftoff"
            ],
            timeline: "1-4 months from explosive pushup."
        ),
        .simple(
            id: "cal.floating-pike-pushup",
            title: "Floating Pike Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "floating pike pushup", count: 3),
            prereqs: [PrerequisiteGroup("cal.elevated-pike-pushup")],
            equipment: [.parallettes],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Pike pushup with feet off the ground.",
            description: "Pike pushup on parallettes where the feet never touch the floor — legs tucked or straddled. 3 reps of pure shoulder pressing.",
            formCues: [
                "Start from tuck or straddle support on parallettes",
                "Hips stack over the shoulders",
                "Head descends between the hands",
                "Press back up without touching down"
            ],
            commonMistakes: [
                "Feet brushing the floor mid-rep",
                "Collapsing the tuck under load",
                "Partial ROM — not bringing head down"
            ],
            timeline: "6-18 months from elevated pike pushup.",
            isParallelToParent: true
        ),
        .simple(
            id: "cal.bench-dip",
            title: "Bench Dip",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "bench dip", count: 10),
            prereqs: [PrerequisiteGroup("cal.incline-pushup")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.arms], secondary: [.chest, .shoulders],
            subtitle: "The dip on-ramp.",
            description: "10 controlled bench dips — hands on a stable bench behind the hips, elbows track back, shoulders stay organized, lower only to a safe pain-free depth, then press to full lockout.",
            formCues: [
                "Hands grip bench edge, fingers pointing forward",
                "Elbows track straight back, not flared",
                "Keep hips close to the bench",
                "Descend to about 90° or deepest pain-free range",
                "Press through the palms to lockout"
            ],
            commonMistakes: [
                "Elbows flaring wide — shoulder strain",
                "Dropping too deep with shoulders rolled forward",
                "Pushing mostly with the legs"
            ],
            timeline: "1-3 weeks for most beginners."
        ),
        .simple(
            id: "cal.triple-clap-pushup",
            title: "Triple Clap Push-Up",
            cluster: .calisthenicControl, tier: 7, type: .skill,
            target: .reps(exercise: "triple clap pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.clapping-pushup")],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "Three claps. One rep. No excuses.",
            description: "One clean pushup where the airtime is so violent you fit three claps before landing. Famed for being essentially impossible without elite power-to-weight.",
            formCues: [
                "Explode from a rigid plank",
                "Clap three times at chest level mid-air",
                "Catch with soft elbows, reset in plank",
                "Train as singles with full reset — never as sloppy volume"
            ],
            commonMistakes: [
                "Landing with locked arms — shoulder injury risk",
                "Fake claps that barely touch",
                "Piking hips for cheat airtime"
            ],
            timeline: "5+ years of power training. Very rare."
        ),

        // ────────────────────────────────────────────────────────────────
        // LEGS ADDITIONS — calves, jumps, glute work, hamstring forge
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "ld.calf-raise",
            title: "Calf Raise",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "calf raise", count: 20),
            prereqs: [PrerequisiteGroup("ld.step-up")],
            primary: [.calves],
            subtitle: "The skipped muscle group.",
            description: "20 double-leg calf raises — rise onto the balls of the feet, control the descent, heels touch the floor each rep.",
            formCues: [
                "Rise as high as possible — full plantar flexion",
                "Pause 1s at the top",
                "Lower slowly, heels kiss the floor",
                "Feet parallel, knees locked"
            ],
            commonMistakes: [
                "Bouncing through reps — no ROM",
                "Partial ROM at the top",
                "Rushing the eccentric"
            ],
            timeline: "1-2 weeks from zero."
        ),
        .simple(
            id: "ld.weighted-sl-calf",
            title: "Weighted Single-Leg Calf Raise",
            cluster: .legDominance, tier: 4, type: .strength,
            target: .reps(exercise: "single-leg calf raise", count: 10, load: "0.5x bw"),
            prereqs: [PrerequisiteGroup("ld.calf-raise")],
            equipment: [.dumbbells, .kettlebell],
            primary: [.calves],
            subtitle: "Unilateral calf strength.",
            description: "Single-leg calf raises per side holding half bodyweight at the hip. Eliminates the stronger leg compensation that kills calf hypertrophy.",
            formCues: [
                "Load hangs on the working-side hand",
                "Free leg bent, toes off the ground",
                "Full plantar flexion at the top",
                "Slow, controlled descent to heel-drop below toes"
            ],
            commonMistakes: [
                "Bouncing out of the stretch",
                "Partial ROM",
                "Free leg sneaking assistance"
            ],
            timeline: "2-6 months from bodyweight calf raises."
        ),
        .simple(
            id: "ld.box-jump",
            title: "Box Jump",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "box jump", count: 5),
            prereqs: [PrerequisiteGroup("ld.jumping-squat")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.calves, .core],
            subtitle: "Explosive triple extension.",
            description: "Clean box jumps to a box at knee height or higher. Land soft, stand tall, step down — never jump down.",
            formCues: [
                "Arms swing for momentum",
                "Hips, knees, ankles extend together",
                "Land in a partial squat, absorb softly",
                "Step down off the box — no ankle trauma"
            ],
            commonMistakes: [
                "Landing stiff-legged — joints take the hit",
                "Using a box that's too tall to land clean",
                "Jumping down off the box"
            ],
            timeline: "1-3 weeks to groove the jump.",
            isParallelToParent: true
        ),
        .simple(
            id: "ld.jumping-squat",
            title: "Jumping Squat",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "jumping squat", count: 10),
            prereqs: [PrerequisiteGroup("ld.deep-squat")],
            primary: [.legs, .glutes], secondary: [.calves, .core],
            subtitle: "Squat, then launch.",
            description: "Bodyweight jumping squats — full-depth squat, explode to jump, land soft, re-descend into the next rep. Power endurance.",
            formCues: [
                "Full-depth squat each rep",
                "Explode straight up on the concentric",
                "Land in the next rep's squat — absorb softly",
                "Chest up, no forward collapse"
            ],
            commonMistakes: [
                "Partial depth between jumps",
                "Landing stiff — joints take a beating",
                "Forward lean on the concentric",
                "Continuing after jump height or landing quality fades"
            ],
            timeline: "1-3 weeks from deep squat."
        ),
        .simple(
            id: "ld.weighted-split-squat",
            title: "Weighted Split Squat",
            cluster: .legDominance, tier: 3, type: .strength,
            target: .reps(exercise: "weighted split squat", count: 8, load: "0.25x bw"),
            prereqs: [PrerequisiteGroup("ld.split-squat")],
            equipment: [.dumbbells, .kettlebell],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Load the lead leg.",
            description: "Split squat holding dumbbells or kettlebells at the sides. 8 reps per leg under load. Bridge between bodyweight split squat and the bulgarian split squat.",
            formCues: [
                "Back foot 2-3 feet behind, planted on floor",
                "Hold weights at the sides — no swinging",
                "Torso upright, drive through front heel",
                "Full depth — back knee brushes the floor"
            ],
            commonMistakes: [
                "Load too heavy too fast — form decays",
                "Front heel lifts, knee caves inward, or knee travel exceeds control",
                "Pushing off the rear foot"
            ],
            timeline: "2-4 weeks from bodyweight split squat."
        ),
        .simple(
            id: "ld.fire-hydrant",
            title: "Fire Hydrant",
            cluster: .legDominance, tier: 5, type: .skill,
            target: .reps(exercise: "fire hydrant", count: 15),
            prereqs: [PrerequisiteGroup("ld.flying-kickback")],
            primary: [.glutes], secondary: [.core],
            subtitle: "Hip abduction activator.",
            description: "Fire hydrants per side — on hands and knees, raise one bent leg out to the side, keeping the knee bent at 90°. Targets the glute medius.",
            formCues: [
                "Back flat, hips square to the floor",
                "Raise leg straight out to the side, knee bent",
                "Squeeze glute at the top",
                "Control the descent"
            ],
            commonMistakes: [
                "Rotating the spine to lift higher",
                "Hips dropping to the opposite side",
                "Rushing reps"
            ],
            timeline: "Immediate — activation drill."
        ),
        .simple(
            id: "ld.single-leg-glute-bridge",
            title: "Single-Leg Glute Bridge",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "single-leg glute bridge", count: 10),
            prereqs: [PrerequisiteGroup("ld.glute-bridge")],
            primary: [.glutes], secondary: [.core, .legs],
            subtitle: "Glute isolation. No quads allowed.",
            description: "10 single-leg glute bridges per side — lying on back, foot planted, raise hips driving through the heel. Other leg extended.",
            formCues: [
                "Working foot flat, heel under knee",
                "Free leg extended straight",
                "Squeeze glute to drive hips up",
                "Full hip extension at the top, no lumbar arch"
            ],
            commonMistakes: [
                "Using the free leg for momentum",
                "Lumbar arch instead of glute squeeze",
                "Partial ROM — hips not reaching lockout"
            ],
            timeline: "1-3 weeks."
        ),
        .simple(
            id: "ld.flying-kickback",
            title: "Leg Kickback",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "leg kickback", count: 12),
            prereqs: [PrerequisiteGroup("ld.single-leg-glute-bridge")],
            primary: [.glutes], secondary: [.back, .core],
            subtitle: "Explosive glute extension.",
            description: "12 leg kickbacks per side — on hands and knees, drive one leg straight back aggressively, squeeze glute hard, return with control.",
            formCues: [
                "Back flat, core braced",
                "Drive the leg back fast, glute leads",
                "Full hip extension — toe points back, not up",
                "Controlled return, don't crash"
            ],
            commonMistakes: [
                "Lumbar arching to fake glute extension",
                "Leg drifting out to the side",
                "Swinging instead of driving"
            ],
            timeline: "Immediate."
        ),
        .simple(
            id: "ld.leg-extensions",
            title: "Bodyweight Leg Extension",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "bodyweight leg extension", count: 8),
            prereqs: [PrerequisiteGroup("ld.deep-squat")],
            primary: [.legs], secondary: [.core],
            subtitle: "Reverse-Nordic quad isolation.",
            description: "Kneeling bodyweight leg extension / reverse-Nordic pattern: hips stay open, ribs down, knees bend as the body leans back in one line, then quads extend the body tall again through a pain-free arc.",
            formCues: [
                "Kneel tall with hips open and ribs down",
                "Lean back from the knees; do not sit the hips back",
                "Use a pain-free arc and slow eccentric",
                "Drive tall through the quads without lumbar arch"
            ],
            commonMistakes: [
                "Turning it into a hip hinge or sissy squat",
                "Dropping into sharp anterior knee pain",
                "Arching the low back to escape the quad load"
            ],
            timeline: "1-3 weeks."
        ),
        .simple(
            id: "ld.advancing-nordic-curl",
            title: "Advanced Nordic Hip Hinge",
            cluster: .legDominance, tier: 5, type: .skill,
            target: .reps(exercise: "advanced nordic hip hinge", count: 5),
            prereqs: [PrerequisiteGroup("ld.nordic-hip-hinge")],
            equipment: [.elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Deeper hinge, no curl yet.",
            description: "Kneeling, ankles anchored — hinge further forward than the basic nordic hip hinge, breaking the hip-shoulder line slightly to extend ROM. The eccentric stepping stone before the full nordic curl pattern.",
            formCues: [
                "Ankles anchored under a bar, bench, or partner",
                "Hinge deeper than the basic nordic hip hinge",
                "Slow eccentric — 4s+ descent",
                "Return without crashing or pushing off"
            ],
            commonMistakes: [
                "Piking the hips to cheat range",
                "Pushing off with hands (that's a nordic curl regression)",
                "Anchor slipping mid-rep"
            ],
            timeline: "1-3 months from nordic hip hinge."
        ),
        .simple(
            id: "ld.floor-to-ceiling-squat",
            title: "Floor to Ceiling Squat",
            cluster: .legDominance, tier: 5, type: .skill,
            target: .reps(exercise: "floor to ceiling squat", count: 1),
            prereqs: [PrerequisiteGroup("ld.jumping-squat")],
            primary: [.legs, .glutes], secondary: [.core, .calves],
            subtitle: "From flat on the floor, jump up and touch ceiling.",
            description: "Lie supine on the floor, stand up in one motion, and explode into a jump high enough to touch an 8-foot ceiling. Full-body explosive power.",
            formCues: [
                "Sit-up plus stand in one smooth motion",
                "No push-off with the hands on the floor",
                "Full-depth squat into an explosive vertical jump",
                "Aim for fingertips to ceiling, not just wall mark"
            ],
            commonMistakes: [
                "Rolling to the side to cheat the standup",
                "Partial squat before the jump",
                "Stopping short on the leap"
            ],
            timeline: "5+ years of explosive leg training. Very rare."
        ),

    ]
}
