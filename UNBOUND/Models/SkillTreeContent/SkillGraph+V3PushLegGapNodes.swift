import Foundation

extension SkillGraph {
    static let v3PushLegGapNodes: [SkillNode] = [
        // MARK: Push — Bent Arm Press (distinct from Bent Arm Planche)
        .simple(
            id: "cal.bent-arm-press",
            title: "Bent Arm Press",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "bent arm press", count: 3),
            prereqs: [PrerequisiteGroup(["cal.floating-pike-pushup", "hs.wall-handstand-30"])],
            primary: [.shoulders, .triceps], secondary: [.core, .chest],
            subtitle: "Tripod or tuck press to handstand.",
            description: "A bent-arm press to handstand: start from a controlled tripod, tuck, or straddle setup, shift shoulders forward, float the hips first, then press through bent arms to a stacked handstand without jumping.",
            formCues: [
                "Start from a stable tripod, tuck, or straddle base",
                "Float hips before the legs open",
                "Press through the arms instead of jumping off the feet",
                "Finish in a tall handstand with ribs tucked"
            ],
            commonMistakes: [
                "Using momentum from a jump instead of pressing",
                "Dumping weight into the head or neck",
                "Opening the legs early before the hips stack"
            ],
            timeline: "3-9 months from floating pike push-up."
        ),

        // MARK: Legs — Foundation gap nodes
        .simple(
            id: "ld.step-up",
            title: "Step Up",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "step up", count: 15),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            equipment: [.elevatedSurface],
            primary: [.quads, .glutes], secondary: [.core],
            subtitle: "The most skipped entry.",
            description: "Step up onto a knee-height box, drive through the heel, control the descent. Hidden gold for quad/glute strength and single-leg control without needing pistol-level mobility.",
            formCues: [
                "Full foot on the box — not just the ball",
                "Drive through the heel to stand",
                "Don't push off the trailing leg",
                "Lower with control — no dropping"
            ],
            commonMistakes: [
                "Pushing off the ground leg for momentum",
                "Leaning forward instead of stepping up tall",
                "Box too low to matter, or too high to form-check"
            ],
            timeline: "Immediate."
        ),
        .simple(
            id: "ld.deep-squat",
            title: "Deep Squat",
            cluster: .legDominance, tier: 3, type: .hold,
            target: .hold(exercise: "deep squat", seconds: 60),
            prereqs: [PrerequisiteGroup("ld.step-up")],
            primary: [.quads, .glutes], secondary: [.core],
            subtitle: "The squat your body forgot.",
            description: "Sit in a full-depth bodyweight squat — hips below knees, feet flat, chest up — for the duration. Ankle, hip, and knee mobility floor that every squat progression depends on.",
            formCues: [
                "Feet flat — if heels lift, ankle mobility first",
                "Hips below knees — full depth, no inch lost",
                "Chest up and open, not collapsed",
                "Breathe slow — this is a mobility hold, not a struggle"
            ],
            commonMistakes: [
                "Heels lifting — pushes out of the position",
                "Chest collapsing — turns it into a rest squat",
                "Holding breath through the entire time"
            ],
            timeline: "Immediate to 6 weeks for rusty adults."
        ),
        .simple(
            id: "ld.glute-bridge",
            title: "Glute Bridge",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "glute bridge", count: 15),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            primary: [.glutes], secondary: [.core],
            subtitle: "The glute wake-up.",
            description: "Lying on your back, drive through the heels to lift the hips until the body forms a straight line from shoulders to knees. 15 reps with a 1-second squeeze at the top.",
            formCues: [
                "Heels under knees, feet planted",
                "Drive through heels, not toes",
                "Squeeze the glutes at the top — pause 1 second",
                "Don't hyperextend the lower back"
            ],
            commonMistakes: [
                "Pushing through the toes instead of heels",
                "Arching lumbar to fake hip height",
                "Rushing — no top squeeze"
            ],
            timeline: "Immediate."
        ),
        .simple(
            id: "ld.weighted-bss",
            title: "Weighted Bulgarian Split Squat",
            cluster: .legDominance, tier: 4, type: .strength,
            target: .weightMultiplier(exercise: "weighted bss", multiplier: 0.5),
            prereqs: [PrerequisiteGroup("ld.bulgarian-split-squat")],
            equipment: [.dumbbells, .kettlebell, .elevatedSurface],
            primary: [.quads, .glutes], secondary: [.core],
            subtitle: "Load the single leg.",
            description: "Bulgarian split squat holding dumbbells or kettlebells — 0.5x bodyweight total load. 8 reps per leg. Direct strength path toward the pistol and weighted pistol.",
            formCues: [
                "Same BSS form as bodyweight — depth doesn't change under load",
                "Hold weights at the sides — no swinging",
                "Rear foot loose on bench — balance point only",
                "Drive through the front heel to stand"
            ],
            commonMistakes: [
                "Load too heavy too fast — form decays",
                "Weights drifting forward, shifting balance",
                "Partial depth to cheat the load"
            ],
            timeline: "3-6 months from bodyweight BSS mastery."
        ),
        .simple(
            id: "ld.sissy-squat",
            title: "Sissy Squat",
            cluster: .legDominance, tier: 5, type: .skill,
            target: .reps(exercise: "sissy squat", count: 8),
            prereqs: [PrerequisiteGroup("ld.leg-extensions")],
            primary: [.quads], secondary: [.core],
            subtitle: "Pure quad isolation.",
            description: "Lean back, bend at the knees only (hips stay extended), drop the heels — torso, hips, and knees stay in a straight line. The brutal quad-only movement that gym bros sleep on.",
            formCues: [
                "Heels rise — knees push forward and down",
                "Straight line from knees to shoulders throughout",
                "No hip flexion — zero sit-back",
                "Use a pole for balance assist if needed"
            ],
            commonMistakes: [
                "Hinging at the hips — becomes a regular squat",
                "Knees caving in under the load",
                "Too-aggressive knee travel before ready — patellar issues"
            ],
            timeline: "4-8 weeks of quad-specific work."
        ),
        .simple(
            id: "ld.nordic-hip-hinge",
            title: "Nordic Hip Hinge",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "nordic hip hinge", count: 8),
            prereqs: [PrerequisiteGroup("ld.single-leg-glute-bridge")],
            equipment: [.elevatedSurface],
            primary: [.hamstrings, .glutes], secondary: [.core],
            subtitle: "Hamstrings meet hip hinge.",
            description: "Kneeling hip hinge with feet anchored — lean forward from the knees, hinge at the hips mid-rep, then return. The on-ramp to the full Nordic curl that teaches the exact motor pattern.",
            formCues: [
                "Feet and shins fully anchored",
                "Quads vertical at the start",
                "Hinge at the hips, not the spine",
                "Control the descent — no falling"
            ],
            commonMistakes: [
                "Rounding through the back instead of hinging",
                "Ankles unanchored — position breaks",
                "Using hands for a third contact point"
            ],
            timeline: "2-6 weeks from single-leg glute bridge."
        ),
        .simple(
            id: "ld.nordic-curl",
            title: "Nordic Curl",
            cluster: .legDominance, tier: 6, type: .skill,
            target: .reps(exercise: "nordic curl", count: 3),
            prereqs: [PrerequisiteGroup(["ld.advancing-nordic-curl", "ld.single-leg-glute-bridge"])],
            equipment: [.elevatedSurface],
            primary: [.hamstrings, .glutes], secondary: [.core],
            subtitle: "The hamstring holy grail.",
            description: "Kneeling, ankles anchored, lower the torso to the floor using only hamstring strength — then pull yourself back up with no hand assist. The hardest bodyweight hamstring move in existence.",
            formCues: [
                "Ankles and calves fully anchored",
                "Body rigid — straight line from knees to head",
                "Slow the descent all the way down",
                "Drive up using hamstrings only — hands only catch a failure"
            ],
            commonMistakes: [
                "Pushing off with the hands (that's advanced nordic hip hinge)",
                "Breaking at the hips to cheat",
                "Dropping the last 6 inches of descent"
            ],
            timeline: "1-3 years from advanced nordic hip hinge."
        ),
    ]
}
