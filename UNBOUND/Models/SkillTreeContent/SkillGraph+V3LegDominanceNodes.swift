import Foundation

extension SkillGraph {
    static let v3LegDominanceNodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // LEG DOMINANCE (ld) — single-leg / variation squat chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "ld.goblet-20",
            title: "Goblet Squat",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "goblet squat", count: 12, load: "0.25x bw"),
            equipment: [.dumbbells],
            primary: [.legs, .glutes, .core],
            subtitle: "The loaded squat on-ramp.",
            description: "Full-depth squats holding a dumbbell or kettlebell at the chest — elbows inside the knees, chest tall. The loaded squat pattern every leg skill grows from; rank climbs with the weight you can own (% of bodyweight), not endless reps.",
            formCues: [
                "Hold the bell at chest height, elbows tucked in",
                "Feet shoulder-width, toes turned out ~15°",
                "Sit straight down to full depth, knees tracking over toes",
                "Chest tall, weight stays over midfoot",
                "Drive through the heels to stand"
            ],
            commonMistakes: [
                "Bell drifting away from the chest",
                "Heels lifting — ankle mobility or stance too narrow",
                "Knees caving inward on the concentric"
            ],
            timeline: "1-3 weeks to groove the pattern."
        ),
        .simple(
            id: "ld.split-squat",
            title: "Split Squat",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "split squat", count: 10),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Single-leg foundation.",
            description: "10 strict split squats per leg — back foot planted on floor, front foot forward, drive through front heel. The unilateral on-ramp before the bulgarian.",
            formCues: [
                "Back foot 2-3 feet behind",
                "Front knee tracks over toes",
                "Torso upright",
                "Drive through front heel"
            ],
            commonMistakes: [
                "Stance too short for control — heel lifts or knee caves inward",
                "Pushing off the rear foot",
                "Forward lean into a lunge pattern"
            ],
            timeline: "1-3 weeks from goblet squat."
        ),
        .simple(
            id: "ld.bulgarian-split-squat",
            title: "Bulgarian Split Squat",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "bulgarian split squat", count: 10),
            prereqs: [PrerequisiteGroup("ld.split-squat")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "The single-leg on-ramp.",
            description: "Rear-foot-elevated split squat, 10 reps per leg. The humbling unilateral move that preps you for pistols.",
            formCues: [
                "Rear foot on bench/box, laces down",
                "Front foot set so the whole foot stays rooted and knee tracks with toes",
                "Torso upright — not a lunge with a forward lean",
                "Drive through the heel of the front foot",
                "Full depth — rear knee brushes the floor"
            ],
            commonMistakes: [
                "Too short a stance — heel lifts or front knee caves inward",
                "Pushing off the rear foot (it's a balance point, not a driver)",
                "Uneven depth between reps"
            ],
            timeline: "2-4 weeks from split squat."
        ),
        .simple(
            id: "ld.shrimp-squat",
            title: "Shrimp Squat",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "shrimp squat", count: 3),
            prereqs: [PrerequisiteGroup("ld.pistol-squat")],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Single-leg strength after pistol.",
            description: "Single-leg squat where you grab the rear ankle with the opposite hand and sit down until the rear knee touches the floor. The path runs through assisted, beginner, and intermediate shrimp before the strict rep. 3 clean reps per leg.",
            formCues: [
                "Grip rear ankle firmly, other arm out for balance",
                "Descend slow — rear knee lightly touches floor",
                "Working heel stays planted",
                "Torso stays upright"
            ],
            commonMistakes: [
                "Slamming the rear knee down",
                "Working heel rising",
                "Letting the rear leg do the work via hip flexion"
            ],
            timeline: "2-4 months from BSS mastery."
        ),
        .simple(
            id: "ld.pistol-squat",
            title: "Pistol Squat",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "pistol squat", count: 5),
            prereqs: [PrerequisiteGroup(["ld.deep-squat", "ld.bulgarian-split-squat"])],
            isKeystone: true,
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Single-leg mastery.",
            description: "Full-depth single-leg squat. Non-working leg extended straight forward, hips below the working knee, chest up. 5 clean reps per leg.",
            formCues: [
                "Counterweight — arms outstretched forward",
                "Working heel stays planted throughout",
                "Descend slow — 3s eccentric builds the bottom position",
                "Knee tracks over toes, doesn't cave",
                "Chest up at all depths — no collapsing forward"
            ],
            commonMistakes: [
                "Heel rising — need more ankle mobility or box-assisted progression",
                "Bouncing off the bottom — no control in the hole",
                "Non-working leg bent or touching the floor"
            ],
            timeline: "6-18 months from BSS mastery."
        ),
        .simple(
            id: "ld.weighted-pistol",
            title: "Weighted Pistol",
            cluster: .legDominance, tier: 5, type: .strength,
            target: .reps(exercise: "weighted pistol", count: 3, load: "0.5x bw"),
            prereqs: [PrerequisiteGroup("ld.pistol-squat")],
            equipment: [.dumbbells, .kettlebell],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Load the single leg.",
            description: "Pistol squat holding half your bodyweight at chest (dumbbell or kettlebell goblet style). 3 clean reps per leg.",
            formCues: [
                "Weight locked tight to chest — no swinging",
                "Same pistol form as bodyweight — don't lose it under load",
                "Slower descent than BW pistol — 3-4s eccentric",
                "Drive from the heel"
            ],
            commonMistakes: [
                "Load too heavy too fast — pistol form decays",
                "Bouncing off the bottom",
                "Using the weight as a counterbalance instead of a load"
            ],
            timeline: "6-12 months from clean pistol."
        ),

    ]
}
