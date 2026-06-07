import Foundation

extension SkillGraph {
    static let v3PullAdditionNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // PHASE 2L — REFERENCE AUDIT ADDITIONS
        // ────────────────────────────────────────────────────────────────
        // Row family, Heighted/One-Arm Chin-Up variants, Strict Muscle-Up,
        // Bent Arm Press, Leg-axis gap nodes (step-up, deep squat, glute
        // bridge, weighted BSS, sissy squat, Nordic curl chain), Core gap
        // nodes (straight crunch, bird-dog, V-sit, straddle L-sit, dragon
        // flag hip raise, decline sit-up), Handstand gap (wall plank,
        // wall-supported OAH). All calibrated per reference infographic.
        // ────────────────────────────────────────────────────────────────

        // MARK: Pull — The Row sub-chapter
        .simple(
            id: "pp.incline-row",
            title: "Incline Row",
            cluster: .pullingPower, tier: 1, type: .skill,
            target: .reps(exercise: "incline row", count: 12),
            equipment: [.pullupBar],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "The row on-ramp.",
            description: "Bar set high — body near-vertical — pull chest to bar. 12 reps. The simplest pulling entry point before the first pull-up is reachable.",
            formCues: [
                "Bar chest-height or higher — more vertical = easier",
                "Straight line from heels to shoulders",
                "Pull chest to bar, elbows back and down",
                "Squeeze scaps at the top"
            ],
            commonMistakes: [
                "Hips sagging — breaks the line",
                "Chin reaching instead of chest pulling to bar",
                "Bar set too low before ready — skip the progression"
            ],
            timeline: "2-4 weeks for most untrained adults."
        ),
        .simple(
            id: "pp.row",
            title: "Row",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "inverted row", count: 10),
            prereqs: [PrerequisiteGroup("pp.incline-row")],
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "The clean horizontal pull.",
            description: "Bodyweight inverted row on a low bar or rings. Body stays in one plank line, heels on the floor, ribs pull to the implement, and every rep returns to straight arms.",
            formCues: [
                "Set the bar or rings low enough that the body is close to horizontal",
                "Lock ribs down, glutes on, and legs straight before pulling",
                "Pull lower chest or ribs to the bar, not the chin",
                "Pause briefly at the top, then lower to straight arms"
            ],
            commonMistakes: [
                "Hips sagging at the bottom or piking at the top",
                "Neck reaching to fake the final inches",
                "Short reps that never return to straight arms"
            ],
            timeline: "2-6 weeks from incline rows."
        ),
        .simple(
            id: "pp.decline-row",
            title: "Decline Row",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "decline row", count: 10),
            prereqs: [PrerequisiteGroup("pp.row")],
            equipment: [.pullupBar, .elevatedSurface],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "Feet up. Back lights up.",
            description: "Inverted row with feet elevated on a bench or box. 10 reps. The bridge between a standing row and a full horizontal pull.",
            formCues: [
                "Feet on bench or box at hip height",
                "Body in a hollow straight line, no sag",
                "Pull chest to bar — not the chin",
                "Return to straight arms with shoulders still active"
            ],
            commonMistakes: [
                "Hips piking up as you pull",
                "Partial ROM — not touching bar",
                "Feet too elevated before ready — skip the progression"
            ],
            timeline: "2-6 weeks from incline row."
        ),
        .simple(
            id: "pp.one-arm-row",
            title: "One-Arm Row",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "one arm row", count: 5),
            prereqs: [PrerequisiteGroup("pp.decline-row")],
            equipment: [.pullupBar],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "Pull your bodyweight on one arm.",
            description: "Strict one-arm rows on rings or a low bar — bodyweight horizontal, single arm pulls chest to the implement, control the descent.",
            formCues: [
                "Set handle height and foot width so torso stays square",
                "Start with straight arm plus active shoulder, not a loose hang",
                "Pull lower ribs/chest to the handle without torso twist",
                "Free hand may assist lightly on the strap, but pressure must be obvious"
            ],
            commonMistakes: [
                "Twisting torso or hips to turn the rep into rotation",
                "Using hidden free-hand pressure instead of a measurable assist",
                "Partial ROM or losing the straight-arm bottom"
            ],
            timeline: "2-6 months from decline row.",
            isParallelToParent: true
        ),
        .simple(
            id: "pp.tuck-row",
            title: "Tuck Lever Row",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "tuck row", count: 8),
            prereqs: [PrerequisiteGroup("pp.decline-row")],
            equipment: [.pullupBar],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "The front-lever on-ramp.",
            description: "Low-bar or ring row with knees tucked tight to chest and hips high. 8 reps. Builds the lat-and-core coordination that every front lever progression depends on.",
            formCues: [
                "Set the tuck lever before rowing",
                "Knees pulled tight and hips near shoulder height",
                "Shoulders stay depressed; ribs down, pelvis tucked",
                "Pull sternum to bar",
                "Return to the same lever shape on the eccentric"
            ],
            commonMistakes: [
                "Feet drifting down instead of tucked",
                "Arching the lower back to cheat",
                "Partial reps — chin over bar instead of sternum"
            ],
            timeline: "2-4 months from decline row."
        ),
        .simple(
            id: "pp.straddle-row",
            title: "Straddle Row",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "straddle row", count: 5),
            prereqs: [PrerequisiteGroup("pp.tuck-row")],
            equipment: [.pullupBar],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "Legs split. Lever longer.",
            description: "Inverted row with legs extended in a wide straddle, body parallel to floor. 5 reps. Harder than tuck row — direct bridge toward straddle front lever row.",
            formCues: [
                "Wide straddle — legs locked and pointing out",
                "Hollow hold — ribs tucked, no lumbar arch",
                "Hips stay level with shoulders through the row",
                "Pull sternum to bar",
                "Same straddle lever on the eccentric — no vertical pullup"
            ],
            commonMistakes: [
                "Legs not actually opening into a straddle",
                "Hips dropping to cheat",
                "Kipping to squeeze late reps"
            ],
            timeline: "3-6 months from tuck row."
        ),
        .simple(
            id: "pp.tuck-front-lever-pullup",
            title: "Tuck Front Lever Pull-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "tuck front lever pullup", count: 3),
            prereqs: [PrerequisiteGroup(["pp.one-arm-row", "cl.tuck-front-lever"])],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .core], secondary: [.back],
            subtitle: "Pull-up while holding the front lever.",
            description: "Hanging pull-up performed while holding a tuck front lever — body horizontal, knees tucked. Harder and stricter than the low-bar tuck lever row.",
            formCues: [
                "Enter tuck front lever before initiating the pull",
                "Hold knees tight, hips level, ribs down",
                "Pull sternum to bar, body stays horizontal",
                "Slow eccentric returns to the same tuck lever"
            ],
            commonMistakes: [
                "Losing the lever shape mid-rep",
                "Vertical pullup with bent legs (different skill)",
                "Bent arms at the bottom"
            ],
            timeline: "6-18 months from one-arm row + tuck front lever."
        ),

        // MARK: Pull — Ascent / Crossover / Solo Arm additions
        .simple(
            id: "pp.heighted-chin-up",
            title: "Heighted Chin-Up",
            cluster: .pullingPower, tier: 7, type: .skill,
            target: .reps(exercise: "heighted chin-up", count: 3),
            prereqs: [PrerequisiteGroup("pp.weighted-chin-up")],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core, .forearms],
            subtitle: "Beyond chin-to-bar — pull collarbones to the bar.",
            description: "3 strict chin-ups where the collarbones (sternum) clear the bar — extreme ROM, requires explosive pull off a base of weighted chin-up strength.",
            formCues: [
                "Underhand grip, dead hang start",
                "Pull until collarbones clear the bar",
                "No kip, no leg drive",
                "Slow eccentric to dead hang"
            ],
            commonMistakes: [
                "Stopping at chin-over-bar (that's a regular chin-up)",
                "Kipping for the extra height",
                "Partial ROM at the bottom"
            ],
            timeline: "6-12 months from weighted chin-up."
        ),
        .simple(
            id: "pp.one-arm-chin-up",
            title: "One-Arm Chin-Up",
            cluster: .pullingPower, tier: 8, type: .skill,
            target: .reps(exercise: "one-arm chin-up", count: 1),
            prereqs: [PrerequisiteGroup("pp.heighted-chin-up")],
            isMythic: true,
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core, .forearms],
            subtitle: "Supinated ceiling.",
            description: "One strict chin-up with a single arm — full dead hang to chin-over-bar, underhand grip, no kip. The supinated counterpart to the one-arm pull-up.",
            formCues: [
                "Underhand grip locked tight — no slack",
                "Free arm across chest or behind back — no assist",
                "Pull elbow DOWN aggressively",
                "Body angled slightly toward the working side",
                "Stop on wrist, elbow, or biceps-tendon pain"
            ],
            commonMistakes: [
                "Kipping for momentum",
                "Free hand grabbing shirt/wrist as secret assist",
                "Chin not fully clearing the bar",
                "Ignoring tendon pain because the rep is close"
            ],
            timeline: "3-5+ years of dedicated pull work."
        ),
        .simple(
            id: "pp.strict-muscle-up",
            title: "Strict Muscle-Up",
            cluster: .pullingPower, tier: 8, type: .skill,
            target: .reps(exercise: "strict muscle-up", count: 1),
            prereqs: [PrerequisiteGroup("pp.ring-muscle-up")],
            isMythic: true,
            equipment: [.pullupBar],
            primary: [.lats, .chest, .arms], secondary: [.core, .shoulders],
            subtitle: "No hips. No kip.",
            description: "Muscle-up with zero lower-body contribution — legs stay dead straight, hips pass through the bar from pure upper-body strength. 1 clean rep.",
            formCues: [
                "Legs locked straight throughout — no knee bend, no hip thrust",
                "Use high wrist/false grip if needed to shorten the turnover",
                "Pull from dead hang toward low chest before transition",
                "Elbows stay close through a smooth turnover",
                "Press to full lockout at the top"
            ],
            commonMistakes: [
                "Any hip drive — that's a regular muscle-up",
                "Piking the legs at the transition",
                "Using momentum from the eccentric of a previous rep"
            ],
            timeline: "6-18 months from first muscle-up."
        ),
    ]
}
