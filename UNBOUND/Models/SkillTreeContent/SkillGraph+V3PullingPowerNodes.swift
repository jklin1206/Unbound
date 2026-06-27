import Foundation

extension SkillGraph {
    static let v3PullingPowerNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // PULLING POWER (pp) — bar skills + pullup chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pp.dead-hang",
            title: "Dead Hang",
            cluster: .pullingPower, tier: 2, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 30),
            prereqs: [PrerequisiteGroup("pp.incline-row")],
            equipment: [.pullupBar],
            primary: [.forearms, .lats],
            subtitle: "Before you pull, you learn to hang.",
            description: "Controlled active hang from a pullup bar: straight arms, shoulders organized, ribs quiet, and no swinging. Grip and shoulder foundation every pulling skill sits on.",
            formCues: [
                "Active shoulders — pull them down away from ears",
                "Straight arms, no bent-elbow cheat",
                "Core engaged, no swinging",
                "Breathe normally — this isn't a breath hold",
                "Full grip — all four fingers, thumb wrapped"
            ],
            commonMistakes: [
                "Passive hanging with shoulders collapsed — rotator cuff risk",
                "Swinging legs to buy time",
                "Dropping when grip fails instead of lowering with control"
            ],
            timeline: "2-6 weeks for most healthy adults."
        ),
        .simple(
            id: "pp.pullup",
            title: "Pull-Up",
            cluster: .pullingPower, tier: 2, type: .skill,
            target: .reps(exercise: "pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.dead-hang")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "The move that separates gym-curious from gym-able.",
            description: "Strict pullup from a full dead hang — chin over bar, no kip or leg swing. The foundation for every bar skill that follows.",
            formCues: [
                "Start from a dead hang — straight arms, shoulders active",
                "Pull elbows DOWN, not back",
                "Chin clears the bar — full ROM",
                "Control the descent — don't drop",
                "Drive chest toward the bar"
            ],
            commonMistakes: [
                "Kipping — bending knees and thrusting hips for momentum",
                "Not reaching full dead hang between reps",
                "Chin-over-bar via neck-craning rather than a real pull"
            ],
            timeline: "6 weeks to 6 months depending on starting strength."
        ),
        .simple(
            id: "pp.strict-pullup",
            title: "Strict Pull-Up",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "strict pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.pullup")],
            isKeystone: true,
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "The strict pull-up is the gateway to the rest of the tree.",
            description: "Strict pull-ups — dead hang start, chin clears the bar, no kip, no swing, controlled descent. The volume gate that opens weighted pulling, explosive pulling, and the muscle-up.",
            formCues: [
                "Full dead hang each rep — no bounce",
                "Pull elbows down and back",
                "Chin fully clears the bar",
                "3-second eccentric to keep form honest",
                "No leg swing, no hip thrust"
            ],
            commonMistakes: [
                "Half-reps as fatigue sets in",
                "Kipping to grind out the last reps",
                "Skipping the dead hang reset"
            ],
            timeline: "3-12 months from first pullup."
        ),
        .simple(
            id: "pp.archer-pullup",
            title: "Archer Pull-Up",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "archer pullup", count: 3),
            prereqs: [PrerequisiteGroup(["pp.weighted-pullup", "pp.pullup"])],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.core],
            subtitle: "The bridge to one-arm work.",
            description: "Pullup where one arm bends fully while the other stays extended along the bar. The extended arm assists just enough to keep you honest. Alternates sides.",
            formCues: [
                "Extended arm is taut — actively assisting, not dangling",
                "Pull chin toward the bending arm's hand",
                "Slow eccentric — eccentric builds the one-arm strength",
                "Body stays square to the bar, not rotating"
            ],
            commonMistakes: [
                "Bending the 'straight' arm to cheat",
                "Not clearing chin to the working hand",
                "Rotating through the hips to lever up"
            ],
            timeline: "2-6 months from weighted pullup mastery.",
            isParallelToParent: true
        ),
        .simple(
            id: "pp.weighted-pullup",
            title: "Weighted Pull-Up",
            cluster: .pullingPower, tier: 5, type: .strength,
            target: .weightMultiplier(exercise: "weighted pullup", multiplier: 0.5),
            prereqs: [PrerequisiteGroup(["pp.strict-pullup", "pp.pullup"])],
            equipment: [.pullupBar, .dumbbells],
            primary: [.lats, .arms], secondary: [.back, .forearms],
            subtitle: "Load the pull.",
            description: "Strict pullup with added external load (belt + plate, or dumbbell between feet). Sweeps from 0.1× bodyweight up to a full bodyweight pull-up. Gateway to one-arm pulling.",
            formCues: [
                "Secure the load first — dip belt is best",
                "Full dead hang as always",
                "Chin clears the bar clean",
                "Slow eccentric with load to build tendon tolerance",
                "Brace core — load pulls hips forward if you're soft"
            ],
            commonMistakes: [
                "Jumping straight to big weights without a buildup",
                "Partial ROM under load",
                "Not warming up the biceps tendon before heavy work"
            ],
            timeline: "1-2 years from strict pullup × 5."
        ),
        .simple(
            id: "pp.oap-negative",
            title: "One-Arm Pull-Up Negative",
            cluster: .pullingPower, tier: 7, type: .skill,
            target: .reps(exercise: "one-arm pullup negative", count: 3),
            prereqs: [PrerequisiteGroup(["pp.archer-pullup", "pp.weighted-pullup"])],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core, .forearms],
            subtitle: "Lower yourself with one arm — the bridge to the full one-arm.",
            description: "3 strict 5s eccentric one-arm pull-up negatives per side. Slow lower from the top, no jerk.",
            formCues: [
                "Start at chin-over-bar with measurable assistance if needed",
                "Lower every inch under control — 5s minimum",
                "Keep shoulder active; no jerking or tendon-yanking drops",
                "Stop on rising elbow, biceps, or shoulder pain"
            ],
            commonMistakes: [
                "Dropping out of the negative once the hard range appears",
                "Using secret free-hand assistance instead of a measurable band/towel/pulley assist",
                "Training through tendon pain or cutting the eccentric short"
            ],
            timeline: "6-12 months of dedicated pull work."
        ),
        .simple(
            id: "pp.one-arm-pullup",
            title: "One-Arm Pull-Up",
            cluster: .pullingPower, tier: 8, type: .skill,
            target: .reps(exercise: "one-arm pullup", count: 1),
            prereqs: [PrerequisiteGroup(["pp.oap-negative", "pp.weighted-pullup", "pp.archer-pullup"])],
            isMythic: true,
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core, .forearms],
            subtitle: "The pulling ceiling most will never touch.",
            description: "One strict pullup with a single arm — full dead hang to chin-over-bar, no kip, no momentum. The pulling ceiling for 95%+ of humans.",
            formCues: [
                "Dead hang with active shoulder — no slack",
                "Pull elbow DOWN aggressively — think curl at the top",
                "Body angled slightly toward the working side",
                "Free arm provides no momentum — across chest or behind back",
                "Stop attempts if elbow or biceps tendon pain rises"
            ],
            commonMistakes: [
                "Kipping — legs swinging forward for lift",
                "Free hand gripping shirt/bar/body as secret assist",
                "Partial ROM — chin not fully over bar",
                "Grinding daily max attempts instead of low-volume assisted practice"
            ],
            timeline: "3-5+ years of dedicated pull programming."
        ),
        .simple(
            id: "pp.muscle-up",
            title: "Muscle-Up",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "muscle-up", count: 1),
            prereqs: [PrerequisiteGroup(["pp.explosive-pullup", "cal.5-dips", "pp.pullup"])],
            isKeystone: true,
            isMythic: true,
            equipment: [.pullupBar],
            primary: [.lats, .chest, .arms], secondary: [.core, .shoulders],
            subtitle: "The gateway between pulling and pushing.",
            description: "Bar muscle-up: explosive high pull, close bar path, chest over hands, then a clean straight-bar dip lockout. A controlled hollow-to-arch swing or hip drive is allowed here; strict zero-momentum reps belong to the strict muscle-up node.",
            formCues: [
                "High wrist or false-grip helps, but clean height matters more",
                "Pull explosive to low chest — not chin",
                "Use controlled hip drive, not a knee bicycle or wild kip",
                "Turn both elbows through together — no chicken wing",
                "Lock elbows fully at top"
            ],
            commonMistakes: [
                "Chaotic kip — legs flying forward instead of controlled rhythm",
                "Chicken-winging (one arm transitions first, the other lags)",
                "Stopping at bar-level instead of pressing through to full lockout"
            ],
            timeline: "6-18 months from first pullup, if dips are trained in parallel."
        ),
        .simple(
            id: "pp.ring-muscle-up",
            title: "Ring Muscle-Up",
            cluster: .pullingPower, tier: 7, type: .skill,
            target: .reps(exercise: "ring muscle-up", count: 1),
            prereqs: [PrerequisiteGroup(["pp.muscle-up", "cal.ring-dip"])],
            equipment: [.gymnasticRings],
            primary: [.lats, .chest, .arms, .shoulders],
            subtitle: "Muscle-up, harder canvas.",
            description: "One strict muscle-up on gymnastic rings. The instability demands more from every stabilizer than the bar version.",
            formCues: [
                "False grip — wrap wrist over the ring before the pull",
                "Pull low and deep, bring rings to lower chest",
                "Fast turnover — don't linger in transition",
                "Press to full ring lockout at the top"
            ],
            commonMistakes: [
                "Abandoning false grip mid-rep",
                "Pulling to chin level (bar-MU habit) — rings need lower",
                "Rings splayed outward at the top (poor lockout)"
            ],
            timeline: "3-12 months from bar MU.",
            isParallelToParent: true
        ),

    ]
}
