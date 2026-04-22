import Foundation

// MARK: - SkillGraph.shared — v3 content
//
// Single source of truth for the unified skill graph. ~60 nodes across 6
// clusters, including keystones (Elite, reachable in 2–5 years) and
// mythic nodes (legendary, mostly aspirational).
//
// Node-id convention: `{cluster-slug}.{kebab-slug}` (e.g. "pp.muscle-up").
//
// Form cues + common mistakes are populated for a handful of marquee
// nodes; the rest ship with bare-minimum descriptions and get filled in
// on a subsequent content pass.

extension SkillGraph {
    static let shared = SkillGraph(nodes: Self.v3Nodes)
}

// MARK: - All v3 nodes

extension SkillGraph {
    fileprivate static let v3Nodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // LEG DOMINANCE (ld) — single-leg / variation squat chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "ld.goblet-20",
            title: "Goblet Squat",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "goblet squat", count: 20, load: "0.5x bw"),
            equipment: [.dumbbells, .kettlebell],
            primary: [.legs, .glutes, .core],
            subtitle: "The squat on-ramp.",
            description: "20 full-depth squats holding a dumbbell or kettlebell at chest (half bodyweight). Builds the quad + glute + core base every leg skill grows from.",
            formCues: [
                "Bell held tight to chest, elbows tucked",
                "Feet shoulder-width, toes turned out ~15°",
                "Hips below knees at the bottom — full depth",
                "Drive knees out over toes (not past)",
                "Chest up, eyes forward throughout"
            ],
            commonMistakes: [
                "Heels lifting — ankle mobility or weight too heavy",
                "Knees caving inward on the concentric",
                "Partial depth (stopping at parallel)"
            ],
            timeline: "3-6 weeks once the squat pattern grooves.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .reps(10), criterion: "10 goblet squats with 0.5x bw", xpReward: 50),
                SkillLevel(level: 2, target: .reps(15), criterion: "15 goblet squats with 0.5x bw", xpReward: 100),
                SkillLevel(level: 3, target: .reps(20), criterion: "20 goblet squats with 0.5x bw", xpReward: 150),
                SkillLevel(level: 4, target: .reps(25), criterion: "25 goblet squats with 0.5x bw", xpReward: 200),
                SkillLevel(level: 5, target: .reps(30), criterion: "30 goblet squats with 0.5x bw", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.tempo-squat",
            title: "Tempo Squat",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "tempo squat", count: 10),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            primary: [.legs, .glutes],
            subtitle: "Slow exposes weak.",
            description: "10 BW squats with 3s descent, 1s pause at the bottom, then stand. Builds control and bottom-position strength.",
            formCues: [
                "Count 3s on the descent — mental metronome",
                "Hold the pause without bouncing",
                "Drive up smooth, not explosive",
                "Maintain depth for every rep"
            ],
            commonMistakes: [
                "Bouncing out of the hole",
                "Rushing the eccentric when it burns",
                "Losing chest position at the bottom"
            ],
            timeline: "2-4 weeks from BW squat.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean tempo squat to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict tempo squat", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict tempo squat", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict tempo squat", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict tempo squat", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.bulgarian-split-squat",
            title: "Bulgarian Split Squat",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "bulgarian split squat", count: 10),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "The single-leg on-ramp.",
            description: "Rear-foot-elevated split squat, 10 reps per leg. The humbling unilateral move that preps you for pistols.",
            formCues: [
                "Rear foot on bench/box, laces down",
                "Front foot far enough that knee doesn't push past toes",
                "Torso upright — not a lunge with a forward lean",
                "Drive through the heel of the front foot",
                "Full depth — rear knee brushes the floor"
            ],
            commonMistakes: [
                "Too short a stance — front knee tracks past toes",
                "Pushing off the rear foot (it's a balance point, not a driver)",
                "Uneven depth between reps"
            ],
            timeline: "2-4 weeks from goblet squats.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean bulgarian split squat per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict bulgarian split squat per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict bulgarian split squat per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict bulgarian split squat per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict bulgarian split squat per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.100-lunges",
            title: "Lunge Walk",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .steps(exercise: "walking lunge", count: 100),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            primary: [.legs, .glutes],
            subtitle: "Endurance that keeps mass functional.",
            description: "100 walking lunge steps unbroken. Conditioning benchmark for leg capacity and knee tracking consistency.",
            formCues: [
                "Long stride — front shin close to vertical at depth",
                "Rear knee brushes the floor each rep",
                "Torso upright, no forward lean",
                "Drive through the front heel to stand"
            ],
            commonMistakes: [
                "Short stride — becomes a squat, not a lunge",
                "Front knee crashing inward or over toes",
                "Stopping to rest and calling it unbroken"
            ],
            timeline: "2-6 weeks once lunge pattern is solid.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(40), criterion: "40 unbroken walking lunge steps", xpReward: 50),
                SkillLevel(level: 2, target: .reps(60), criterion: "60 unbroken walking lunge steps", xpReward: 100),
                SkillLevel(level: 3, target: .reps(80), criterion: "80 unbroken walking lunge steps", xpReward: 150),
                SkillLevel(level: 4, target: .reps(100), criterion: "100 unbroken walking lunge steps", xpReward: 200),
                SkillLevel(level: 5, target: .reps(150), criterion: "150 unbroken walking lunge steps", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.bw-front-squat",
            title: "Front Squat",
            cluster: .legDominance, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "front squat", multiplier: 1.0),
            prereqs: [PrerequisiteGroup(["ld.goblet-20", "ld.tempo-squat"])],
            equipment: [.barbell],
            primary: [.legs, .core], secondary: [.glutes, .back],
            subtitle: "Quads + core mastery combined.",
            description: "Front squat at bodyweight. Bar sits in the front rack, more quad-dominant than back squat, punishes any loss of upper back position.",
            formCues: [
                "Bar sits in the shoulder shelf, fingertips on the bar",
                "Elbows HIGH throughout — rack position defines this lift",
                "Chest UP, vertical torso",
                "Full depth — easier with the more upright posture",
                "Drive up chest-first, elbows stay high"
            ],
            commonMistakes: [
                "Elbows dropping — bar rolls forward",
                "Not enough shoulder/wrist mobility to hold rack",
                "Treating it like a back squat (leaning forward)"
            ],
            timeline: "3-12 months after solid back squat.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.75), criterion: "0.75x bodyweight front squat, clean ROM", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.9), criterion: "0.9x bodyweight front squat, clean ROM", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 1.0), criterion: "1.0x bodyweight front squat, clean ROM", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 1.15), criterion: "1.15x bodyweight front squat, clean ROM", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 1.3), criterion: "1.3x bodyweight front squat, clean ROM", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.shrimp-squat",
            title: "Shrimp Squat",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "shrimp squat", count: 3),
            prereqs: [PrerequisiteGroup("ld.bulgarian-split-squat")],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Single-leg gateway to pistol.",
            description: "Single-leg squat where you grab the rear ankle with the opposite hand and sit down until the rear knee touches the floor. 3 clean reps per leg.",
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
            timeline: "2-4 months from BSS mastery.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean shrimp squat per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict shrimp squat per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict shrimp squat per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict shrimp squat per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict shrimp squat per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.assisted-pistol",
            title: "Assisted Pistol",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "assisted pistol", count: 5),
            prereqs: [PrerequisiteGroup(["ld.100-lunges", "ld.bulgarian-split-squat"])],
            primary: [.legs, .glutes],
            subtitle: "Pistol on training wheels.",
            description: "Single-leg squat with a pole, band, or TRX for balance/light assistance. 5 reps per leg. Builds the bottom-position strength for the full pistol.",
            formCues: [
                "Use the assist for BALANCE, not to pull yourself up",
                "Full depth — hips below working knee",
                "Non-working leg straight out, no floor touch",
                "Slow 3s descent to build the bottom"
            ],
            commonMistakes: [
                "Pulling hard on the pole/band — turns it into a pullup-squat",
                "Partial depth",
                "Working heel rising"
            ],
            timeline: "2-4 months from shrimp squat.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean assisted pistol per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict assisted pistol per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict assisted pistol per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(10), criterion: "10 strict assisted pistol per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict assisted pistol per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.single-leg-rdl",
            title: "Single-Leg RDL",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "single-leg rdl", count: 10),
            prereqs: [PrerequisiteGroup("ld.100-lunges")],
            primary: [.glutes, .back], secondary: [.legs, .core],
            subtitle: "Glute isolator. Balance forge.",
            description: "Single-leg Romanian deadlift at bodyweight. 10 reps per leg hinging at the hip, opposite leg extended back, spine neutral.",
            formCues: [
                "Hinge from the hips, not the lower back",
                "Free leg extended back, toes pointed",
                "Torso and free leg form a straight line at the bottom",
                "Standing leg stays slightly bent throughout",
                "Hips stay square — don't rotate open"
            ],
            commonMistakes: [
                "Bending the knee of the standing leg too much (becomes a squat)",
                "Rotating hips open for balance",
                "Rounding the back"
            ],
            timeline: "2-6 weeks from lunges.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean single-leg RDL per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict single-leg RDL per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict single-leg RDL per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict single-leg RDL per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict single-leg RDL per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.pistol-squat",
            title: "Pistol Squat",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "pistol squat", count: 5),
            prereqs: [PrerequisiteGroup("ld.assisted-pistol")],
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
            timeline: "6-18 months from BSS mastery.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pistol squat per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict pistol squat per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict pistol squat per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict pistol squat per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict pistol squat per leg", xpReward: 250),
            ]
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
            timeline: "6-12 months from clean pistol.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.25), criterion: "Pistol with 0.25x bw load", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.35), criterion: "Pistol with 0.35x bw load", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 0.5), criterion: "Pistol with 0.5x bw load", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 0.65), criterion: "Pistol with 0.65x bw load", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 0.75), criterion: "Pistol with 0.75x bw load", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.dragon-pistol",
            title: "Dragon Pistol",
            cluster: .legDominance, tier: 6, type: .skill,
            target: .reps(exercise: "dragon pistol", count: 1),
            prereqs: [PrerequisiteGroup("ld.weighted-pistol")],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Pistol through the leg.",
            description: "Pistol squat where the free leg threads UNDER the working leg and reaches back. Demands hip mobility on top of pistol strength.",
            formCues: [
                "Demands open hips — mobility work is prerequisite",
                "Descend with free leg tucking through and back",
                "Working heel planted, as in standard pistol",
                "Rise while unthreading — coordination wins"
            ],
            commonMistakes: [
                "Attempting without adequate hip mobility — hurts the knee",
                "Rushed descent loses control mid-thread",
                "Dropping the free leg instead of controlling it"
            ],
            timeline: "1-3 years from weighted pistol.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean dragon pistol per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict dragon pistol per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict dragon pistol per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict dragon pistol per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict dragon pistol per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.jumping-pistol",
            title: "Jumping Pistol",
            cluster: .legDominance, tier: 7, type: .skill,
            target: .reps(exercise: "jumping pistol", count: 3),
            prereqs: [PrerequisiteGroup("ld.weighted-pistol")],
            isMythic: true,
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Single-leg explosive.",
            description: "Full-depth pistol squat, explode up into a jump that clears the floor with both feet — land on the same foot, absorb, go again. Three clean reps per side.",
            formCues: [
                "Full-depth descent with control",
                "Explosive concentric — propel through the roof",
                "Land in the same pistol position, absorb with bent knee",
                "Torso upright throughout — no forward fold"
            ],
            commonMistakes: [
                "Partial depth on the descent",
                "Landing with both feet — not a jumping pistol",
                "Torso collapse in the loaded-leg landing"
            ],
            timeline: "5+ years of single-leg work. Very rare in the wild.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean jumping pistol per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict jumping pistol per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict jumping pistol per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict jumping pistol per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict jumping pistol per leg", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // PULLING POWER (pp) — bar skills + pullup chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pp.dead-hang-30",
            title: "Dead Hang",
            cluster: .pullingPower, tier: 1, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 30),
            equipment: [.pullupBar],
            primary: [.forearms, .lats],
            subtitle: "Before you pull, you learn to hang.",
            description: "Passive hang from a pullup bar, straight arms, shoulders engaged. Grip and shoulder foundation every pulling skill sits on.",
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
            timeline: "2-6 weeks for most healthy adults.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold dead hang for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold dead hang for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold dead hang for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold dead hang for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold dead hang for 60s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.negative-pullup",
            title: "Negative Pull-Up",
            cluster: .pullingPower, tier: 2, type: .skill,
            target: .reps(exercise: "negative pullup", count: 3),
            prereqs: [PrerequisiteGroup("pp.dead-hang-30")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back],
            subtitle: "Slow descent builds the pull.",
            description: "Jump or step to the top of a pullup, then lower yourself with control over 5 seconds. 3 reps. Eccentric loading that bridges hang and first pullup.",
            formCues: [
                "Start at the top — chin over bar, straight-arm position",
                "5-second count on the descent",
                "Shoulders active the whole way down",
                "Full dead hang at bottom before the next rep",
                "Step back to the top — don't jump repeatedly"
            ],
            commonMistakes: [
                "Uncontrolled drop past halfway",
                "Starting below the bar (not a real negative)",
                "Shrugged shoulders at the bottom"
            ],
            timeline: "2-6 weeks from dead hang.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean 5-second negative pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict 5-second negative pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict 5-second negative pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict 5-second negative pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict 5-second negative pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.pullup",
            title: "First Pull-Up",
            cluster: .pullingPower, tier: 2, type: .skill,
            target: .reps(exercise: "pullup", count: 1),
            prereqs: [PrerequisiteGroup("pp.negative-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "The move that separates gym-curious from gym-able.",
            description: "One strict pullup from a full dead hang — chin over bar, no kip or leg swing. The foundation for every bar skill that follows.",
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
            timeline: "6 weeks to 6 months depending on starting strength.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.5-pullups",
            title: "Pull-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back],
            subtitle: "Consistent pull strength.",
            description: "5 strict pullups unbroken from dead hang. The first real volume checkpoint.",
            formCues: [
                "Same form as single pullup — just sustained",
                "Don't rush — rhythm beats speed",
                "Full dead hang between reps",
                "Breathe at the top, don't hold"
            ],
            commonMistakes: [
                "Partial reps on 4 and 5 as fatigue sets in",
                "Starting to kip to squeeze out reps",
                "Shoulders shrugging up at the top"
            ],
            timeline: "1-6 months from first pullup.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(7), criterion: "7 strict pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(10), criterion: "10 strict pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.10-pullups",
            title: "Pull-Up Volume",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "pullup", count: 10),
            prereqs: [PrerequisiteGroup("pp.5-pullups")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back],
            subtitle: "Back density benchmark.",
            description: "10 strict pullups unbroken. The volume threshold that opens weighted pullup training, the one-arm pullup chain, and the muscle-up.",
            formCues: [
                "Same form as a single pullup — just sustained",
                "Every rep from a full dead hang",
                "Even tempo — don't burn fast then fail",
                "Breathe at the top, not held through the set"
            ],
            commonMistakes: [
                "Half-reps as you fatigue — don't cheat the last 3-4",
                "Kipping to squeeze out final reps — counts as a different skill",
                "Death-gripping the bar early and burning out grip"
            ],
            timeline: "3-12 months from first pullup.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(7), criterion: "First clean pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(10), criterion: "10 strict pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(12), criterion: "12 strict pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.slow-pullup",
            title: "Tempo Pull-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "slow pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.5-pullups")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "Tempo forges control.",
            description: "Pullup with a 3-second concentric and 3-second eccentric. Burns out weaknesses the fast version hides.",
            formCues: [
                "Count the tempo — mental metronome, not a feel",
                "Never release tension at top or bottom",
                "Keep shoulders packed throughout",
                "Breathe at the bottom, hold during the pull"
            ],
            commonMistakes: [
                "Dropping pace on the eccentric when it burns",
                "Partial ROM at the top — not breaking chin line",
                "Cheating the 3-second count with a 1.5-second rep"
            ],
            timeline: "2-4 months after strict 5 pullups.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(2), criterion: "First clean slow (3s/3s) pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict slow (3s/3s) pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict slow (3s/3s) pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict slow (3s/3s) pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict slow (3s/3s) pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.chest-to-bar",
            title: "Chest-to-Bar Pull-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "chest-to-bar pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.5-pullups")],
            equipment: [.pullupBar],
            primary: [.lats, .back], secondary: [.arms, .core],
            subtitle: "Fuller range. Denser back.",
            description: "Pullup pulling the CHEST to the bar instead of just the chin. 5 reps. Builds the upper back and sets you up for muscle-up mechanics.",
            formCues: [
                "Think 'chest at the bar' not 'chin over the bar'",
                "Arch slightly at the top to get chest contact",
                "Pull elbows aggressively down and back",
                "Drive scaps together at the top"
            ],
            commonMistakes: [
                "Chin-up range called chest-to-bar",
                "Kipping to squeeze the top few inches",
                "Shrugging shoulders at the top"
            ],
            timeline: "2-6 months from 5 pullups.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(2), criterion: "First clean chest-to-bar pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict chest-to-bar pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict chest-to-bar pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict chest-to-bar pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict chest-to-bar pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.l-sit-pullup",
            title: "L-Sit Pull-Up",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "l-sit pullup", count: 5),
            prereqs: [PrerequisiteGroup(["pp.slow-pullup", "cal.l-sit-10"])],
            equipment: [.pullupBar],
            primary: [.lats, .core, .arms],
            subtitle: "Lats + core, simultaneously.",
            description: "Pullup performed with legs held in L-sit position (parallel to floor) throughout the rep. 5 reps. Fuses upper-body pull strength with hollow-body core demand.",
            formCues: [
                "Legs LOCKED in L-sit before initiating the pull",
                "Don't let legs drop as you pull — the challenge IS holding them up",
                "Slower tempo works better here than explosive",
                "Dead hang still clean at the bottom"
            ],
            commonMistakes: [
                "Legs dropping or swinging through the pull",
                "Partial ROM to cheat the core demand",
                "Bent legs instead of straight"
            ],
            timeline: "3-9 months from clean L-sit + slow pullup.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean L-sit pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict L-sit pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict L-sit pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict L-sit pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict L-sit pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.archer-pullup",
            title: "Archer Pull-Up",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "archer pullup", count: 3),
            prereqs: [PrerequisiteGroup("pp.slow-pullup")],
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
            timeline: "2-6 months from slow pullup mastery.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean archer pullup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict archer pullup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict archer pullup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict archer pullup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict archer pullup per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.weighted-pullup-0.25",
            title: "Weighted Pull-Up",
            cluster: .pullingPower, tier: 4, type: .strength,
            target: .weightMultiplier(exercise: "weighted pullup", multiplier: 0.25),
            prereqs: [PrerequisiteGroup("pp.10-pullups")],
            equipment: [.pullupBar, .dumbbells],
            primary: [.lats, .arms], secondary: [.back],
            subtitle: "Load the pull.",
            description: "Strict pullup with added weight equal to 25% of your bodyweight (belt + plate, or dumbbell between feet). Opens the weighted-pullup progression.",
            formCues: [
                "Secure the load first — dip belt is best",
                "Full dead hang as always",
                "Chin clears the bar clean",
                "Slow eccentric with load to build tendon tolerance"
            ],
            commonMistakes: [
                "Jumping straight to big weights without a buildup",
                "Partial ROM under load",
                "Not warming up the biceps tendon before heavy work"
            ],
            timeline: "3-9 months from 10 pullups.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.15), criterion: "0.15x bodyweight weighted pullup, clean ROM", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.25), criterion: "0.25x bodyweight weighted pullup, clean ROM", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 0.35), criterion: "0.35x bodyweight weighted pullup, clean ROM", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 0.5), criterion: "0.5x bodyweight weighted pullup, clean ROM", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 0.65), criterion: "0.65x bodyweight weighted pullup, clean ROM", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.weighted-pullup-0.5",
            title: "Heavy Pull-Up",
            cluster: .pullingPower, tier: 5, type: .strength,
            target: .weightMultiplier(exercise: "weighted pullup", multiplier: 0.5),
            prereqs: [PrerequisiteGroup("pp.weighted-pullup-0.25")],
            equipment: [.pullupBar, .dumbbells],
            primary: [.lats, .arms], secondary: [.back, .forearms],
            subtitle: "Half your bodyweight hanging from your waist.",
            description: "Strict pullup with added weight equal to 50% of your bodyweight. The volume-strength gate for the one-arm pullup.",
            formCues: [
                "Dip belt with plates beats dumbbells at this load",
                "Full dead hang each rep, no kip",
                "Chin clears clean — partial reps don't count",
                "Slower eccentric to build connective-tissue tolerance",
                "Brace core — load pulls hips forward if you're soft"
            ],
            commonMistakes: [
                "Jumping load faster than the biceps tendon adapts",
                "Kipping to grind out the final inches",
                "Skipping warmup pullups before loaded singles"
            ],
            timeline: "1-2 years from 0.25× weighted pullup.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.35), criterion: "0.35x bodyweight weighted pullup, clean ROM", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.5), criterion: "0.5x bodyweight weighted pullup, clean ROM", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 0.65), criterion: "0.65x bodyweight weighted pullup, clean ROM", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 0.75), criterion: "0.75x bodyweight weighted pullup, clean ROM", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 1.0), criterion: "1.0x bodyweight weighted pullup, clean ROM", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.typewriter-pullup",
            title: "Typewriter Pull-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "typewriter pullup", count: 3),
            prereqs: [PrerequisiteGroup("pp.archer-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.core],
            subtitle: "Lateral strength meets pull.",
            description: "Pull up, then slide chin side-to-side at the top while staying at bar level. Like a typewriter carriage — smooth lateral movement at the peak.",
            formCues: [
                "Pull all the way up FIRST, then traverse",
                "Chin stays at bar height throughout the slide",
                "Hips square — resist rotating with the lateral movement",
                "Return to the other side with control, not a drop"
            ],
            commonMistakes: [
                "Dropping below bar during the lateral slide",
                "Bending the 'straight' side arm",
                "Rushing the traverse rather than slow lateral control"
            ],
            timeline: "3-6 months from archer mastery.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean typewriter pullup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict typewriter pullup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict typewriter pullup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict typewriter pullup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(7), criterion: "7 strict typewriter pullup per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.oap-negative",
            title: "One-Arm Pull-Up Negative",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "one-arm pullup negative", count: 3),
            prereqs: [PrerequisiteGroup("pp.typewriter-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.core, .back],
            subtitle: "Eccentric builds the path.",
            description: "One-arm pullup lowering only. Start at the top, lower with control over 5 seconds, step or band-assist back up. The eccentric loads the exact motor pattern of the full OAP.",
            formCues: [
                "Start fully locked out at the top with one arm",
                "Control the full 5 seconds — don't let the last 2 inches slip",
                "Free hand doesn't grip bar or body",
                "Core + lats engaged to prevent rotation"
            ],
            commonMistakes: [
                "Dropping through the bottom half — no control where it matters",
                "Holding the free arm at the bar (accidental assist)",
                "Skipping the top half of the ROM"
            ],
            timeline: "3-9 months from typewriter pullup.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean 5-second one-arm pullup negative to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict 5-second one-arm pullup negative", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict 5-second one-arm pullup negative", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict 5-second one-arm pullup negative", xpReward: 200),
                SkillLevel(level: 5, target: .reps(7), criterion: "7 strict 5-second one-arm pullup negative", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.one-arm-pullup",
            title: "One-Arm Pull-Up",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "one-arm pullup", count: 1),
            prereqs: [PrerequisiteGroup(["pp.oap-negative", "pp.weighted-pullup-0.5"])],
            isKeystone: true,
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core, .forearms],
            subtitle: "The pulling ceiling most will never touch.",
            description: "One strict pullup with a single arm — full dead hang to chin-over-bar, no kip, no momentum. The pulling ceiling for 95%+ of humans.",
            formCues: [
                "Dead hang with active shoulder — no slack",
                "Pull elbow DOWN aggressively — think curl at the top",
                "Body angled slightly toward the working side",
                "Free arm provides no momentum — across chest or behind back",
                "Explosive intent on the concentric, slow eccentric"
            ],
            commonMistakes: [
                "Kipping — legs swinging forward for lift",
                "Free hand gripping shirt/bar/body as secret assist",
                "Partial ROM — chin not fully over bar"
            ],
            timeline: "3-5+ years of dedicated pull programming.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean one-arm pullup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict one-arm pullup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict one-arm pullup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict one-arm pullup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict one-arm pullup per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.muscle-up",
            title: "Muscle-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "muscle-up", count: 1),
            prereqs: [
                PrerequisiteGroup(["pp.10-pullups", "cal.5-dips"]),
                PrerequisiteGroup(["pp.weighted-pullup-0.25", "cal.l-sit-20"])
            ],
            isKeystone: true,
            equipment: [.pullupBar],
            primary: [.lats, .chest, .arms], secondary: [.core, .shoulders],
            subtitle: "The gateway between pulling and pushing.",
            description: "Explosive high-pull transitioning over the bar into a clean dip lockout.",
            formCues: [
                "False-grip BEFORE starting, not mid-rep",
                "Pull explosive to low chest — not chin",
                "Fast hip drive to get chest over bar",
                "Catch in a deep dip, then press out",
                "Lock elbows fully at top"
            ],
            commonMistakes: [
                "Kipping — legs flying forward for momentum",
                "Chicken-winging (one arm transitions first, the other lags)",
                "Stopping at bar-level instead of pressing through to full lockout"
            ],
            timeline: "6-18 months from first pullup, if dips are trained in parallel.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean bar muscle-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict bar muscle-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict bar muscle-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict bar muscle-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict bar muscle-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.10-muscle-ups",
            title: "Muscle-Up Volume",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "muscle-up", count: 10),
            prereqs: [PrerequisiteGroup("pp.muscle-up")],
            equipment: [.pullupBar],
            primary: [.lats, .chest, .arms],
            subtitle: "Volume unlocks the move.",
            description: "10 strict muscle-ups unbroken. The difference between 'I can do a MU' and 'I own muscle-ups'.",
            formCues: [
                "Pacing matters more than raw strength here",
                "Every rep starts from a full dead hang",
                "Full dip lockout at the top of each rep",
                "Breathe at the dip position, not mid-transition"
            ],
            commonMistakes: [
                "Losing form on reps 7-10 — kipping in",
                "Skipping the dip lockout on later reps",
                "Going too fast and burning out early"
            ],
            timeline: "6-18 months from first MU.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean bar muscle-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(7), criterion: "7 strict bar muscle-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict bar muscle-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict bar muscle-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict bar muscle-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.ring-muscle-up",
            title: "Ring Muscle-Up",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "ring muscle-up", count: 1),
            prereqs: [PrerequisiteGroup("pp.muscle-up")],
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
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean ring muscle-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict ring muscle-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict ring muscle-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict ring muscle-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict ring muscle-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.5-oap-side",
            title: "One-Arm Pull-Up Volume",
            cluster: .pullingPower, tier: 7, type: .skill,
            target: .reps(exercise: "one-arm pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.one-arm-pullup")],
            isMythic: true,
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back],
            subtitle: "Pulling volume most never sniff.",
            description: "Five clean one-arm pullups per side. The volume benchmark above the single OAP — the difference between 'I have done it' and 'I own it'.",
            formCues: [
                "Each rep from a complete dead hang with no swing carry-over",
                "Chin fully over the bar each rep",
                "Rest a full minute between sides",
                "Maintain form — last rep should look like the first"
            ],
            commonMistakes: [
                "Swinging to chain reps",
                "Half-reps on the last 2-3",
                "Switching sides too fast to allow recovery"
            ],
            timeline: "1-3 years past the first clean OAP.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean one-arm pullup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict one-arm pullup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict one-arm pullup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict one-arm pullup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(7), criterion: "7 strict one-arm pullup per side", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // CALISTHENIC CONTROL (cal) — pushups + planche + handstand + rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.plank-30",
            title: "Plank",
            cluster: .calisthenicControl, tier: 1, type: .hold,
            target: .hold(exercise: "plank", seconds: 30),
            primary: [.core, .shoulders],
            subtitle: "The core foundation. Cannot skip this.",
            description: "Full-body plank on forearms or hands. Straight line head to heels, core braced, 30 seconds unbroken.",
            formCues: [
                "Elbows under shoulders (forearm) or hands under shoulders",
                "Squeeze glutes HARD — prevents lower-back sag",
                "Draw belly button toward spine",
                "Neck neutral, eyes at the floor",
                "Heels driving back, crown reaching forward"
            ],
            commonMistakes: [
                "Hips sagging — breaks the line",
                "Butt in the air — shortens the lever and cheats",
                "Holding breath instead of breathing steady"
            ],
            timeline: "1-4 weeks from zero to 30s clean.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 15), criterion: "Hold plank for 15s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 30), criterion: "Hold plank for 30s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 45), criterion: "Hold plank for 45s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 60), criterion: "Hold plank for 60s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 90), criterion: "Hold plank for 90s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.l-sit-10",
            title: "L-Sit",
            cluster: .calisthenicControl, tier: 2, type: .hold,
            target: .hold(exercise: "l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup(["cal.plank-30", "cl.hanging-knee-raise"])],
            equipment: [.parallettes, .bodyweight],
            primary: [.core, .shoulders], secondary: [.arms, .legs],
            subtitle: "The move that makes people stop scrolling.",
            description: "Seated on parallettes or floor with hands flat, press body up, legs straight out at 90° from torso. Hold 10 seconds.",
            formCues: [
                "Hands PRESS DOWN — shoulders depressed, not shrugged",
                "Legs locked, toes pointed, quads engaged",
                "Hollow body — ribs pulled down, pelvis tilted back",
                "Breathe normally — don't hold breath to cheat tension"
            ],
            commonMistakes: [
                "Shrugged shoulders — instant failure position",
                "Bent knees",
                "Hips dropping below parallel to hands"
            ],
            timeline: "1-3 months from solid compressed leg raises.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold L-sit for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold L-sit for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold L-sit for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold L-sit for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold L-sit for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.l-sit-20",
            title: "L-Sit Hold",
            cluster: .calisthenicControl, tier: 3, type: .hold,
            target: .hold(exercise: "l-sit", seconds: 20),
            prereqs: [PrerequisiteGroup("cal.l-sit-10")],
            equipment: [.parallettes, .bodyweight],
            primary: [.core, .shoulders], secondary: [.arms, .legs],
            subtitle: "20 seconds of violent core tension.",
            description: "Double the L-sit hold time. 20 seconds demands actual conditioning on top of the basic position.",
            formCues: [
                "Same form as 10s, sustained — the burn is the test",
                "Don't let legs sag in the back half of the hold",
                "Posterior pelvic tilt throughout",
                "Accumulate multiple shorter sets before chasing the full 20"
            ],
            commonMistakes: [
                "Legs creeping downward in seconds 12-20",
                "Shoulders shrugging up as grip fails",
                "Holding breath — destroys the last few seconds"
            ],
            timeline: "2-6 months from L-Sit 10s.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold L-sit for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold L-sit for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 20), criterion: "Hold L-sit for 20s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 30), criterion: "Hold L-sit for 30s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold L-sit for 45s, clean form", xpReward: 250),
            ]
        ),

        .simple(
            id: "cal.pushup",
            title: "Push-Up",
            cluster: .calisthenicControl, tier: 1, type: .skill,
            target: .reps(exercise: "pushup", count: 10),
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "The upper-body foundation.",
            description: "Full-range pushup from plank — chest touches the floor, elbows tuck at ~45°, full lockout. Target 10 clean reps.",
            formCues: [
                "Hands slightly wider than shoulders, under chest",
                "Elbows at 45° — not flared out, not pinned to ribs",
                "Body rigid as plank — no head-lead",
                "Chest touches down, don't stop halfway",
                "Full lockout at top"
            ],
            commonMistakes: [
                "Sagging hips — breaks the plank line",
                "Flared elbows (90°) — beats up the shoulders",
                "Partial ROM — bouncing off the top without lockout",
                "Head jutting forward before the chest"
            ],
            timeline: "2-6 weeks for first 10 clean reps.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(10), criterion: "10 strict pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(20), criterion: "20 strict pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(30), criterion: "30 strict pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(50), criterion: "50 strict pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.slow-pushup",
            title: "Tempo Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "slow pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pushup")],
            primary: [.chest, .arms, .shoulders],
            subtitle: "Tempo exposes weakness.",
            description: "10 pushups with a 3s descent and 3s press-up. Tempo forces genuine strength through every inch of the range.",
            formCues: [
                "Count the tempo aloud or in your head",
                "Chest touches the floor at the bottom",
                "No rest at top — maintain tension",
                "Body rigid throughout"
            ],
            commonMistakes: [
                "Cheating the tempo at the top half",
                "Sagging hips by rep 6",
                "Pausing at the bottom to catch breath"
            ],
            timeline: "2-4 weeks from 10 standard pushups.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean slow (3s/3s) pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict slow (3s/3s) pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict slow (3s/3s) pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict slow (3s/3s) pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict slow (3s/3s) pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.5-dips",
            title: "Dip",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.slow-pushup")],
            equipment: [.parallettes, .elevatedSurface],
            primary: [.chest, .arms, .shoulders],
            subtitle: "Vertical press, meet bodyweight.",
            description: "5 strict dips on parallel bars or rings. Shoulders below elbows at the bottom, full lockout at the top.",
            formCues: [
                "Shoulders pull BELOW elbows at the bottom",
                "Lean slightly forward for chest emphasis, or stay upright for tricep",
                "Full lockout at the top — elbows straight",
                "Control the descent (2s min)"
            ],
            commonMistakes: [
                "Partial ROM — not reaching full shoulder depth",
                "Shrugging at the bottom",
                "Swinging legs for momentum"
            ],
            timeline: "1-3 months from solid pushups.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict dip", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.ring-support-10",
            title: "Ring Support Hold",
            cluster: .calisthenicControl, tier: 3, type: .hold,
            target: .hold(exercise: "ring support hold", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.slow-pushup")],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .arms, .chest], secondary: [.core],
            subtitle: "Own the top of the ring dip.",
            description: "Straight-arm support hold on gymnastic rings — body vertical, arms locked at the sides, rings turned out. 10 seconds unbroken.",
            formCues: [
                "Rings turned outward (thumbs-up position) — protects shoulders",
                "Arms fully locked straight, no bent-arm cheat",
                "Shoulders packed down, not shrugged up",
                "Hollow body — core tight, ribs tucked",
                "Breathe normally through the hold"
            ],
            commonMistakes: [
                "Rings splayed outward — leaks shoulder stability",
                "Shrugged shoulders under the load",
                "Breaking the lock when rings start to shake"
            ],
            timeline: "2-4 months of ring exposure.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold ring support for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold ring support for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold ring support for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 20), criterion: "Hold ring support for 20s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 30), criterion: "Hold ring support for 30s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.ring-dip",
            title: "Ring Dip",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "ring dip", count: 5),
            prereqs: [PrerequisiteGroup(["cal.ring-support-10", "cal.5-dips"])],
            equipment: [.gymnasticRings],
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "Strict dip on unstable rings.",
            description: "5 strict dips on gymnastic rings, starting and ending with rings turned out in full support. Rings demand more stabilizer work than bars at every inch of the ROM.",
            formCues: [
                "Start and end each rep in a locked-out ring support",
                "Turn rings out at the top — wrists rotate, palms forward",
                "Descend with control — shoulders pull below elbows",
                "Rings stay close to the body, not drifting outward",
                "Press up smooth — no kipping"
            ],
            commonMistakes: [
                "Rings flaring wide at the bottom",
                "Partial ROM — not reaching full shoulder depth",
                "Skipping the turn-out at the top — loses the strict standard"
            ],
            timeline: "3-6 months from 5 bar dips + ring support.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean ring dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict ring dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict ring dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict ring dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict ring dip", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.diamond-pushup",
            title: "Diamond Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "diamond pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.slow-pushup")],
            primary: [.arms, .chest],
            subtitle: "Triceps on notice.",
            description: "10 pushups with hands together, thumbs and index fingers forming a diamond. Elbows track close to the body. Tricep-dominant.",
            formCues: [
                "Hands touch under sternum, fingers splayed",
                "Elbows drive back past the ribs, not out",
                "Chest touches the hands (or the backs of them)",
                "Keep plank alignment — no piking"
            ],
            commonMistakes: [
                "Hands too low — turns into a regular pushup",
                "Flared elbows — defeats the triceps emphasis",
                "Partial depth to keep reps moving"
            ],
            timeline: "2-6 weeks from slow pushup.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean diamond pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict diamond pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict diamond pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict diamond pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(25), criterion: "25 strict diamond pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.pseudo-planche-pushup",
            title: "Pseudo-Planche Push-Up",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "pseudo-planche pushup", count: 5),
            prereqs: [PrerequisiteGroup("cal.diamond-pushup")],
            primary: [.shoulders, .chest, .arms], secondary: [.core],
            subtitle: "Planche prep.",
            description: "Pushup with hands at hips (fingers pointing back toward feet), leaning weight forward so shoulders travel past the hands. 5 reps.",
            formCues: [
                "Hands pointed BACKWARD at hip level",
                "Lean weight forward — shoulders over/past hands",
                "Body rigid like plank, not piked",
                "Protract scaps — shoulders spread apart"
            ],
            commonMistakes: [
                "Not enough forward lean — just a pushup",
                "Hands not turned backward enough — shoulder strain",
                "Piking hips to cheat the lean"
            ],
            timeline: "1-3 months from diamond pushup.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean pseudo-planche pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict pseudo-planche pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict pseudo-planche pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict pseudo-planche pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict pseudo-planche pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.tuck-planche",
            title: "Tuck Planche",
            cluster: .calisthenicControl, tier: 3, type: .hold,
            target: .hold(exercise: "tuck planche", seconds: 5),
            prereqs: [PrerequisiteGroup("cal.pseudo-planche-pushup")],
            equipment: [.parallettes],
            primary: [.shoulders, .core], secondary: [.chest, .arms],
            subtitle: "The planche on-ramp.",
            description: "Knees tucked tight to chest, weight balanced on straight arms, feet off the floor. Hold for 5 seconds. First real planche position.",
            formCues: [
                "Protract scaps HARD — shoulders spread apart",
                "Hips lift to at least shoulder height",
                "Knees tucked tight, heels near glutes",
                "Fingers turned slightly outward for shoulder safety",
                "Arms locked STRAIGHT throughout"
            ],
            commonMistakes: [
                "Bent arms — wrong skill, builds wrong patterns",
                "Hips drooping below shoulders",
                "Tucked legs come away from torso"
            ],
            timeline: "3-9 months from pseudo-planche pushup.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold tuck planche for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold tuck planche for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold tuck planche for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold tuck planche for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold tuck planche for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.tuck-planche-pushup",
            title: "Tuck Planche Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "tuck planche pushup", count: 3),
            prereqs: [PrerequisiteGroup(["cal.pseudo-planche-pushup", "cal.tuck-planche"])],
            equipment: [.parallettes],
            primary: [.shoulders, .chest, .core],
            subtitle: "Planche meets press.",
            description: "From a tuck planche hold, bend and press back up while keeping feet off the floor. 3 reps. Shoulder-dominant pressing.",
            formCues: [
                "Enter from a rock-solid tuck planche hold",
                "Descend with control — elbows point back",
                "Keep the tuck tight throughout the descent",
                "Press back to locked-arm planche position"
            ],
            commonMistakes: [
                "Feet touching the floor on the descent",
                "Losing the tuck and collapsing hips",
                "Bouncing out of the bottom"
            ],
            timeline: "6-12 months from tuck planche.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean tuck planche pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict tuck planche pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict tuck planche pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict tuck planche pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict tuck planche pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.straddle-planche",
            title: "Straddle Planche",
            cluster: .calisthenicControl, tier: 5, type: .hold,
            target: .hold(exercise: "straddle planche", seconds: 5),
            prereqs: [PrerequisiteGroup("cal.tuck-planche")],
            equipment: [.parallettes],
            primary: [.shoulders, .core],
            subtitle: "Legs split, body horizontal.",
            description: "Planche with legs split wide and extended — reduces the lever compared to full planche but still demands horizontal hold. 5 seconds.",
            formCues: [
                "Start from the tuck and extend legs wide, NOT straight back",
                "Wider split = easier; tighten gradually over months",
                "Point toes, squeeze legs even though they're split",
                "Hips stay at shoulder height"
            ],
            commonMistakes: [
                "Legs drooping below shoulder line",
                "Lazy split — legs drift together",
                "Banana back (lumbar arch, hips drop)"
            ],
            timeline: "1-2 years from tuck planche.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold straddle planche for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold straddle planche for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 8), criterion: "Hold straddle planche for 8s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 12), criterion: "Hold straddle planche for 12s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 15), criterion: "Hold straddle planche for 15s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.full-planche",
            title: "Full Planche",
            cluster: .calisthenicControl, tier: 6, type: .hold,
            target: .hold(exercise: "full planche", seconds: 5),
            prereqs: [PrerequisiteGroup("cal.straddle-planche")],
            isKeystone: true,
            equipment: [.parallettes, .bodyweight],
            primary: [.shoulders, .core, .chest, .arms], secondary: [.forearms, .lats],
            subtitle: "Horizontal ceiling.",
            description: "Full horizontal hold. Body straight and parallel to the ground, supported only by straight arms.",
            formCues: [
                "Protract shoulders HARD — scaps apart",
                "Hips above shoulder height (piking = failure)",
                "Point toes, squeeze glutes, hollow body",
                "Hands turned outward for shoulder safety",
                "Breathe — don't brace statically"
            ],
            commonMistakes: [
                "Banana back (lower back arches, hips drop)",
                "Shoulders rolling forward (scapular collapse)",
                "Bent arms — at this tier, arms MUST stay locked"
            ],
            timeline: "2-4 years from first tuck planche.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 2), criterion: "Hold full planche for 2s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 3), criterion: "Hold full planche for 3s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 5), criterion: "Hold full planche for 5s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 8), criterion: "Hold full planche for 8s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 12), criterion: "Hold full planche for 12s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.full-planche-pushup",
            title: "Full Planche Push-Up",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "full planche pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.full-planche")],
            equipment: [.parallettes],
            primary: [.shoulders, .chest, .core],
            subtitle: "Push while horizontal.",
            description: "From a full planche, bend elbows and press back up while maintaining horizontal body position. One clean rep.",
            formCues: [
                "Start and end in crisp full planche",
                "Descend SLOW — control is the skill",
                "Keep body line through the descent",
                "Elbows track back, not out"
            ],
            commonMistakes: [
                "Losing horizontal body line mid-descent",
                "Piking hips to reduce demand",
                "Arm break (partial rep)"
            ],
            timeline: "1-2 years from full planche hold.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean full planche pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict full planche pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict full planche pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict full planche pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict full planche pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.ninety-degree-pushup",
            title: "Ninety-Degree Push-Up",
            cluster: .calisthenicControl, tier: 7, type: .skill,
            target: .reps(exercise: "90 degree pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.full-planche-pushup")],
            isMythic: true,
            equipment: [.parallettes],
            primary: [.shoulders, .arms, .chest], secondary: [.core],
            subtitle: "Pushup with elbows tucked to the hips.",
            description: "Pushup where the elbows bend to 90°, body stays horizontal, arms pressed close to the torso. No lean forward. Near-impossible press ratio.",
            formCues: [
                "Descent is slow and controlled — no bounce",
                "Elbows tuck to the sides, arms pinned to the body",
                "Body held in a pristine horizontal line throughout",
                "Requires the full planche pushup as a baseline"
            ],
            commonMistakes: [
                "Leaning forward to cheat the angle (then it's just a planche pushup)",
                "Elbows flaring out to find leverage",
                "Piking hips to reduce body-line demand"
            ],
            timeline: "5+ years past the full planche pushup.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 90-degree pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict 90-degree pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict 90-degree pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict 90-degree pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict 90-degree pushup", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // HANDSTAND (hs) — wrists, wall holds, freestanding, walks
        // Tree 1 of the split former "Handbalance" cluster.
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "hs.wrist-conditioning",
            title: "Reverse-Hand Plank",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "reverse-hand plank", seconds: 30),
            prereqs: [],
            primary: [.forearms], secondary: [],
            subtitle: "First wrist milestone.",
            description: "Hold a reverse-hand plank (fingers pointing at your feet) for 30 seconds. Built over 2-3 weeks of daily wrist prep — the gate before your wrists are ready for planche and HSPU work.",
            formCues: [
                "Wrist circles both directions, 10 each",
                "Knuckle pushups: stack wrists over shoulders",
                "Reverse-hand plank: fingers toward your feet, hold 30s",
                "Progress only when fully pain-free"
            ],
            commonMistakes: [
                "Skipping daily wrist prep",
                "Loading too fast (tendons adapt slower than muscle)",
                "Stopping before it's pain-free"
            ],
            timeline: "2 weeks of daily prep before moving to pressing work.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold reverse-hand plank for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold reverse-hand plank for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold reverse-hand plank for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold reverse-hand plank for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold reverse-hand plank for 60s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.pike-pushup-10",
            title: "Pike Push-Up",
            cluster: .handstandPushup, tier: 2, type: .skill,
            target: .reps(exercise: "pike pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pushup")],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "The vertical pressing pattern HSPU will test.",
            description: "10 strict pike pushups. Hips high, back rounded, head descends between hands. Trains the HSPU motor pattern without the balance demand.",
            formCues: [
                "Hips over shoulders, not over hips",
                "Head lowers between hands, not in front",
                "Elbows track around 45°, not flared",
                "Full ROM — top of head kisses floor"
            ],
            commonMistakes: [
                "Hips too low (regresses to regular pushup)",
                "Elbows flared wide",
                "Cutting range of motion"
            ],
            timeline: "3–8 weeks from 10 strict pushups.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean pike pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict pike pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict pike pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict pike pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict pike pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.elevated-pike-pushup-10",
            title: "Elevated Pike Push-Up",
            cluster: .handstandPushup, tier: 3, type: .skill,
            target: .reps(exercise: "elevated pike pushup", count: 10),
            prereqs: [PrerequisiteGroup("hspu.pike-pushup-10")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Steeper angle — halfway to vertical pressing.",
            description: "Feet on a box or bench, hips stacked higher. 10 strict reps. The bridge between pike pushup and wall HSPU.",
            formCues: [
                "Box height around mid-shin or higher",
                "Shoulders directly over hands",
                "Head descends between the hands",
                "Slow, controlled descent"
            ],
            commonMistakes: [
                "Going too high too soon — spikes injury risk",
                "Hips dropping mid-set",
                "Rushing reps"
            ],
            timeline: "4–8 weeks after pike pushup × 10.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean elevated pike pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict elevated pike pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict elevated pike pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict elevated pike pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict elevated pike pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.wall-handstand-30",
            title: "Wall Handstand",
            cluster: .handstand, tier: 2, type: .hold,
            target: .hold(exercise: "wall handstand", seconds: 30),
            prereqs: [PrerequisiteGroup(["cal.plank-30", "hs.wrist-conditioning"])],
            primary: [.shoulders, .core], secondary: [.arms],
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 15), criterion: "Hold wall handstand for 15s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 30), criterion: "Hold wall handstand for 30s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 45), criterion: "Hold wall handstand for 45s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 60), criterion: "Hold wall handstand for 60s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 90), criterion: "Hold wall handstand for 90s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.wall-handstand-60",
            title: "Wall Handstand Hold",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "wall handstand", seconds: 60),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-30")],
            primary: [.shoulders, .core],
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 30), criterion: "Hold wall handstand for 30s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 45), criterion: "Hold wall handstand for 45s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 60), criterion: "Hold wall handstand for 60s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 90), criterion: "Hold wall handstand for 90s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 120), criterion: "Hold wall handstand for 120s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.wall-hspu-negative-5s",
            title: "Wall HSPU Negative",
            cluster: .handstandPushup, tier: 4, type: .skill,
            target: .reps(exercise: "wall hspu negative", count: 3),
            prereqs: [PrerequisiteGroup(["hs.wall-handstand-60", "hspu.elevated-pike-pushup-10"])],
            primary: [.shoulders, .arms], secondary: [.core, .back],
            subtitle: "Eccentric strength before concentric.",
            description: "From full wall handstand, lower your head to the floor over 5 seconds. Step out, kick back up, repeat. 3 reps × 5s eccentric. Builds the strength to eventually press up.",
            formCues: [
                "Full 5-count descent — no dropping",
                "Head touches gently",
                "Bail by stepping down one leg at a time",
                "Don't try to press up yet"
            ],
            commonMistakes: [
                "Dropping the last 6 inches (cheating the eccentric)",
                "Bailing forward in a collapse",
                "Skipping this to rep-chase a full HSPU"
            ],
            timeline: "2–6 weeks from elevated pike pushup × 10.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean 5-second wall HSPU negative to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict 5-second wall HSPU negative", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict 5-second wall HSPU negative", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict 5-second wall HSPU negative", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict 5-second wall HSPU negative", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.first-wall-hspu",
            title: "First Wall HSPU",
            cluster: .handstandPushup, tier: 5, type: .skill,
            target: .reps(exercise: "wall hspu", count: 1),
            prereqs: [PrerequisiteGroup("hspu.wall-hspu-negative-5s")],
            primary: [.shoulders, .arms], secondary: [.core, .back],
            subtitle: "First press to full lockout overhead.",
            description: "One strict wall HSPU from head-on-floor to full elbow lockout. No kipping, no bridge, no partial rep.",
            formCues: [
                "Start at head-down (not from top)",
                "Hands shoulder-width, fingers slightly spread",
                "Press evenly — don't favor one side",
                "Lockout: elbows straight, body stacked"
            ],
            commonMistakes: [
                "Kipping legs off the wall",
                "Partial lockout",
                "Falling back onto the wall mid-press"
            ],
            timeline: "4–12 weeks after wall HSPU negative.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict wall HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.wall-hspu-3",
            title: "Wall HSPU",
            cluster: .handstandPushup, tier: 6, type: .skill,
            target: .reps(exercise: "wall hspu", count: 3),
            prereqs: [PrerequisiteGroup("hspu.first-wall-hspu")],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Making the skill repeatable.",
            description: "3 unbroken strict wall HSPUs. First taste of HSPU as a real training lift.",
            formCues: [
                "Same form as first HSPU, sustained across 3",
                "Brief rest only at top lockout",
                "Full ROM every rep",
                "If form breaks, set ends"
            ],
            commonMistakes: [
                "Reps 2–3 losing ROM",
                "Using the wall for support mid-rep",
                "Resting in a partial position"
            ],
            timeline: "4–8 weeks after first wall HSPU.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict wall HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.wall-hspu-5",
            title: "Wall HSPU Volume",
            cluster: .handstandPushup, tier: 7, type: .skill,
            target: .reps(exercise: "wall hspu", count: 5),
            prereqs: [PrerequisiteGroup("hspu.wall-hspu-3")],
            primary: [.shoulders, .arms], secondary: [.chest, .core],
            subtitle: "Gateway to freestanding HSPU work.",
            description: "5 unbroken strict wall HSPUs. Standard strength benchmark that clears you for freestanding HSPU training.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(10), criterion: "10 strict wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict wall HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.deficit-wall-hspu-3",
            title: "Deficit Wall HSPU",
            cluster: .handstandPushup, tier: 8, type: .skill,
            target: .reps(exercise: "deficit wall hspu", count: 3),
            prereqs: [PrerequisiteGroup("hspu.wall-hspu-5")],
            equipment: [.bodyweight, .parallettes],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "More ROM than a floor HSPU will ever demand.",
            description: "3 strict wall HSPUs with hands elevated on 4-inch blocks. Head descends below hand level into a deficit. Builds surplus ROM so regular HSPU feels easier.",
            formCues: [
                "Head descends below hand level",
                "Blocks wide enough for head to clear",
                "Full press back to lockout",
                "Control the deficit — don't slam"
            ],
            commonMistakes: [
                "Going too deep too soon (6\"+ blocks before 4\" feels solid)",
                "Kipping out of the bottom"
            ],
            timeline: "8–16 weeks after wall HSPU × 5.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean deficit wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict deficit wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict deficit wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict deficit wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict deficit wall HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.freestanding-hs-10",
            title: "Freestanding Handstand Opener",
            cluster: .handstand, tier: 4, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 10),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-60")],
            primary: [.shoulders, .core], secondary: [.forearms],
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold freestanding handstand for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold freestanding handstand for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold freestanding handstand for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold freestanding handstand for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold freestanding handstand for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.freestanding-hs-30",
            title: "Steady Handstand",
            cluster: .handstand, tier: 4, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.freestanding-hs-10")],
            primary: [.shoulders, .core], secondary: [.forearms],
            subtitle: "From survival to steady state.",
            description: "30 seconds of freestanding handstand. The hold stops being a scramble and becomes a stable shape you can breathe inside.",
            formCues: [
                "Stack wrists → shoulders → hips → ankles",
                "Finger-pressure micro-corrections, not whole-arm shoves",
                "Ribs tucked, glutes squeezed, hollow line",
                "Breathe at the top — do not hold breath",
                "Eyes between the hands, not at the floor in front"
            ],
            commonMistakes: [
                "Chasing the time count instead of the line",
                "Bailing out of every drift instead of correcting",
                "Bananaing the low back once the shoulders fatigue"
            ],
            timeline: "6–18 months of consistent freestanding practice.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 15), criterion: "Hold freestanding handstand for 15s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold freestanding handstand for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold freestanding handstand for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold freestanding handstand for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold freestanding handstand for 60s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.freestanding-hspu-negative-5s",
            title: "Freestanding HSPU Negative",
            cluster: .handstandPushup, tier: 9, type: .skill,
            target: .reps(exercise: "freestanding hspu negative", count: 3),
            prereqs: [PrerequisiteGroup(["hs.freestanding-hs-10", "hspu.wall-hspu-5"])],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Balance + strength — eccentric only.",
            description: "From freestanding handstand, lower to head over 5 seconds. Bail at bottom (cartwheel or pike out). 3 reps. Combines balance control with eccentric pressing.",
            formCues: [
                "Balance BEFORE descent — don't start if you're drifting",
                "Slow 5-count",
                "Bail safely, don't force a press up yet",
                "Kick back into full HS between reps"
            ],
            commonMistakes: [
                "Starting the descent while still drifting",
                "Treating bail as failure (it's part of the rep)",
                "Trying to press up and failing hard"
            ],
            timeline: "6–16 weeks after wall HSPU × 5 + free HS 10s.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean 5-second freestanding HSPU negative to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict 5-second freestanding HSPU negative", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict 5-second freestanding HSPU negative", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict 5-second freestanding HSPU negative", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict 5-second freestanding HSPU negative", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.first-freestanding-hspu",
            title: "Freestanding HSPU",
            cluster: .handstandPushup, tier: 10, type: .skill,
            target: .reps(exercise: "freestanding hspu", count: 1),
            prereqs: [PrerequisiteGroup("hspu.freestanding-hspu-negative-5s")],
            isKeystone: true,
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Push the whole body against gravity.",
            description: "One strict freestanding HSPU — head-to-floor to full lockout. No wall, no support, no kipping.",
            formCues: [
                "Kick up to a stable freestanding position FIRST",
                "Lower with control — head touches the mat lightly",
                "Hands slightly wider than shoulder-width",
                "Drive up through the heels of the palms",
                "Keep the line — don't pike the hips"
            ],
            commonMistakes: [
                "Piking mid-descent to cheat the press out",
                "Losing balance on the way down — bail before head taps",
                "Partial ROM — stopping above head level"
            ],
            timeline: "2–4 years from wall HSPU.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean freestanding HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict freestanding HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict freestanding HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict freestanding HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict freestanding HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hspu.freestanding-hspu-3",
            title: "Freestanding HSPU Volume",
            cluster: .handstandPushup, tier: 11, type: .skill,
            target: .reps(exercise: "freestanding hspu", count: 3),
            prereqs: [PrerequisiteGroup("hspu.first-freestanding-hspu")],
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "When it stops being a fluke.",
            description: "3 unbroken freestanding HSPUs. Real strength + real balance, sustained.",
            formCues: [
                "Rest in full HS lockout between reps, not in pike",
                "Consistent ROM across all 3",
                "Small corrections in the lockout are fine"
            ],
            commonMistakes: [
                "Reps 2–3 lose balance",
                "Dropping into shortcut ROM"
            ],
            timeline: "6–18 months after first freestanding HSPU.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean freestanding HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict freestanding HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict freestanding HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict freestanding HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict freestanding HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.freestanding-hs-60",
            title: "Freestanding Handstand",
            cluster: .handstand, tier: 5, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 60),
            prereqs: [PrerequisiteGroup("hs.freestanding-hs-30")],
            isKeystone: true,
            primary: [.shoulders, .core], secondary: [.forearms],
            subtitle: "Balance is the skill.",
            description: "60 seconds of freestanding handstand. Not just a strength benchmark — it's a balance mastery benchmark. Most never get past 10-15s free.",
            formCues: [
                "Stack wrists → shoulders → hips → ankles — straight line",
                "Micro-correct with fingertips, not the whole hand",
                "Hollow body posture, no banana back",
                "Ribs tucked, glutes squeezed",
                "Breathe — holding breath kills balance"
            ],
            commonMistakes: [
                "Over-correcting instead of micro-adjusting",
                "Looking at the floor too late to catch an overbalance",
                "Loose core — letting the body bend into a banana"
            ],
            timeline: "1-3 years of daily practice.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 30), criterion: "Hold freestanding handstand for 30s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 45), criterion: "Hold freestanding handstand for 45s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 60), criterion: "Hold freestanding handstand for 60s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 90), criterion: "Hold freestanding handstand for 90s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 120), criterion: "Hold freestanding handstand for 120s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.handstand-walk-10m",
            title: "Handstand Walk",
            cluster: .handstand, tier: 5, type: .skill,
            target: .steps(exercise: "handstand walk", count: 10),
            prereqs: [PrerequisiteGroup("hs.freestanding-hs-10")],
            primary: [.shoulders, .core],
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .distance(meters: 2), criterion: "Walk 2m on hands", xpReward: 50),
                SkillLevel(level: 2, target: .distance(meters: 5), criterion: "Walk 5m on hands", xpReward: 100),
                SkillLevel(level: 3, target: .distance(meters: 10), criterion: "Walk 10m on hands", xpReward: 150),
                SkillLevel(level: 4, target: .distance(meters: 15), criterion: "Walk 15m on hands", xpReward: 200),
                SkillLevel(level: 5, target: .distance(meters: 25), criterion: "Walk 25m on hands", xpReward: 250),
            ]
        ),
        .simple(
            id: "oah.one-arm-handstand-5s",
            title: "One-Arm Handstand",
            cluster: .oneArmHandstand, tier: 7, type: .hold,
            target: .hold(exercise: "one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.freestanding-hs-60")],
            isKeystone: true,
            isMythic: true,
            primary: [.shoulders, .core],
            subtitle: "Balance at the limit.",
            description: "Freestanding handstand on a single hand, body vertical, 5 seconds held. Balance requirement is higher than the strength requirement.",
            formCues: [
                "Start from a rock-solid two-hand handstand (60s+)",
                "Shift weight GRADUALLY to the working hand over weeks of drilling",
                "Finger-pressure corrections — the entire hand is your rudder",
                "Free arm counterbalances, doesn't touch the floor",
                "Practice daily, most days in the learning phase"
            ],
            commonMistakes: [
                "Attempting before 60s+ two-hand freestanding",
                "Jumping into it rather than progressive weight shifts",
                "Not letting body re-learn balance — rushes the nervous system"
            ],
            timeline: "3-7 years of daily handstand work.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 2), criterion: "Hold one-arm handstand for 2s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 3), criterion: "Hold one-arm handstand for 3s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 5), criterion: "Hold one-arm handstand for 5s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 7), criterion: "Hold one-arm handstand for 7s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 10), criterion: "Hold one-arm handstand for 10s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "oah.one-arm-hspu",
            title: "One-Arm HSPU",
            cluster: .oneArmHandstand, tier: 7, type: .skill,
            target: .reps(exercise: "one-arm hspu", count: 1),
            prereqs: [PrerequisiteGroup(["oah.one-arm-handstand-5s", "hspu.first-freestanding-hspu"])],
            isMythic: true,
            primary: [.shoulders, .arms, .core],
            subtitle: "The pinnacle of shoulder strength.",
            description: "One handstand pushup on a single arm — lower to head-tap, press back to lockout. Both the OA handstand AND the freestanding HSPU are required baselines.",
            formCues: [
                "Attempt only after both prerequisite skills are rock-solid for months",
                "Usually first achieved wall-assisted (legs against wall)",
                "Free hand stays off the floor throughout",
                "Balance is the limiter, not raw pressing strength",
                "Expect months of partial-range failed attempts"
            ],
            commonMistakes: [
                "Any approach that skips the OA handstand baseline",
                "Using the free arm to 'catch' mid-rep",
                "Partial ROM"
            ],
            timeline: "Most who reach OA-HS never complete this. 7+ years.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean one-arm HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict one-arm HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict one-arm HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict one-arm HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict one-arm HSPU", xpReward: 250),
            ]
        ),

        .simple(
            id: "cal.iron-cross-3s",
            title: "Iron Cross",
            cluster: .calisthenicControl, tier: 5, type: .hold,
            target: .hold(exercise: "iron cross", seconds: 3),
            prereqs: [PrerequisiteGroup(["cal.ring-dip", "cl.full-back-lever", "pp.ring-muscle-up"])],
            equipment: [.gymnasticRings],
            primary: [.chest, .shoulders, .arms, .lats],
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 1), criterion: "Hold iron cross for 1s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 2), criterion: "Hold iron cross for 2s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 3), criterion: "Hold iron cross for 3s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 5), criterion: "Hold iron cross for 5s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 8), criterion: "Hold iron cross for 8s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.iron-cross-10s",
            title: "Iron Cross Hold",
            cluster: .calisthenicControl, tier: 6, type: .hold,
            target: .hold(exercise: "iron cross", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.iron-cross-3s")],
            isKeystone: true,
            equipment: [.gymnasticRings],
            primary: [.chest, .shoulders, .arms, .lats],
            subtitle: "The gymnast's signature.",
            description: "Suspended upright on rings with arms straight out to the sides — the Christian cross shape — for 10 seconds. Requires years of ring-specific connective tissue prep.",
            formCues: [
                "Straight arms ALWAYS — bent arms = wrong skill, big shoulder risk",
                "Rings turned slightly out (thumbs-up position)",
                "Chest up, body vertical",
                "Build hold time VERY slowly — 1s → 3s → 5s → 10s over many months",
                "Never attempt without solid back lever + ring-strength base"
            ],
            commonMistakes: [
                "Rushing progression — this is a years-long skill",
                "Bent-arm cross — beats up elbows and biceps tendon",
                "Skipping the pull-out eccentric work that builds tolerance"
            ],
            timeline: "4-6 years of dedicated ring work.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold iron cross for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold iron cross for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 8), criterion: "Hold iron cross for 8s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 10), criterion: "Hold iron cross for 10s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 15), criterion: "Hold iron cross for 15s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.maltese",
            title: "Maltese",
            cluster: .calisthenicControl, tier: 7, type: .hold,
            target: .hold(exercise: "maltese", seconds: 1),
            prereqs: [PrerequisiteGroup(["cal.iron-cross-10s", "cal.full-planche"])],
            isMythic: true,
            equipment: [.gymnasticRings],
            primary: [.chest, .shoulders, .arms, .core], secondary: [.lats, .forearms],
            subtitle: "The pinnacle of straight-arm strength.",
            timeline: "5-10 years of serious ring work. <500 humans hold it cleanly.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 1), criterion: "Hold maltese for 1s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 2), criterion: "Hold maltese for 2s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 3), criterion: "Hold maltese for 3s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 5), criterion: "Hold maltese for 5s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 8), criterion: "Hold maltese for 8s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.azarian",
            title: "Azarian Press",
            cluster: .calisthenicControl, tier: 7, type: .skill,
            target: .reps(exercise: "azarian", count: 1),
            prereqs: [PrerequisiteGroup("cal.iron-cross-10s")],
            isMythic: true,
            equipment: [.gymnasticRings],
            primary: [.chest, .shoulders, .arms],
            subtitle: "Roll into a cross.",
            description: "From a back lever position, press up through straight arms into an iron cross. Straight-arm strength from lats, chest, and shoulders working in concert.",
            formCues: [
                "Not a skill you program — a skill you earn after the iron cross",
                "Full body tension throughout the roll",
                "Locked elbows under heavy tension",
                "Controlled tempo — momentum does not help here"
            ],
            commonMistakes: [
                "Attempting without a solid 10s iron cross first",
                "Bending arms mid-roll",
                "Losing control of rings (outward drift)"
            ],
            timeline: "5-10 years. Competitive gymnasts and dedicated specialists only.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean azarian press to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict azarian press", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict azarian press", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict azarian press", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict azarian press", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // CORE & LEVER (cl) — dynamic core + levers
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.hollow-body-30",
            title: "Hollow Body Hold",
            cluster: .coreLever, tier: 1, type: .hold,
            target: .hold(exercise: "hollow body hold", seconds: 30),
            prereqs: [],
            primary: [.core], secondary: [],
            subtitle: "The universal core position behind every advanced skill.",
            description: "Lie on your back, arms overhead, legs straight, lower back pressed to floor. Ribs tucked, chin to chest. Hold 30 seconds. Foundation for front lever, planche, dragon flag, HSPU.",
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
            timeline: "2–6 weeks from untrained.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 15), criterion: "Hold hollow body for 15s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 30), criterion: "Hold hollow body for 30s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 45), criterion: "Hold hollow body for 45s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 60), criterion: "Hold hollow body for 60s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 90), criterion: "Hold hollow body for 90s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.hollow-body-60",
            title: "Heavy Hollow Body Hold",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "hollow body hold", seconds: 60),
            prereqs: [PrerequisiteGroup("cl.hollow-body-30")],
            primary: [.core], secondary: [],
            subtitle: "Mandatory gate before lever and planche work.",
            description: "Hollow body hold, sustained 60 seconds. Universally cited prereq for front lever, planche, dragon flag. Tests core endurance, not just strength.",
            formCues: [
                "Same position as 30s — just longer",
                "Breathing stays normal (don't hold breath)",
                "Micro-adjustments are OK, major form breaks end the set"
            ],
            commonMistakes: [
                "Losing lumbar contact as fatigue sets in",
                "Cheating with shoulder shrug"
            ],
            timeline: "4–12 weeks from hollow body 30s.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 30), criterion: "Hold hollow body for 30s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 45), criterion: "Hold hollow body for 45s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 60), criterion: "Hold hollow body for 60s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 90), criterion: "Hold hollow body for 90s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 120), criterion: "Hold hollow body for 120s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.hanging-knee-raise",
            title: "Hanging Knee Raise",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "hanging knee raise", count: 10),
            prereqs: [PrerequisiteGroup("pp.dead-hang-30")],
            equipment: [.pullupBar],
            primary: [.core], secondary: [.lats, .forearms],
            subtitle: "Where visible abs start.",
            description: "10 hanging knee raises. Dead hang from the bar, raise knees to chest, lower with control.",
            formCues: [
                "Start from a full dead hang — no swinging",
                "Raise knees to chest, not just to waist",
                "Control the descent — no freefall",
                "Squeeze core at the top of each rep"
            ],
            commonMistakes: [
                "Swinging to use momentum",
                "Partial ROM — knees stop at 90°",
                "Shrugged shoulders while hanging"
            ],
            timeline: "2-8 weeks from first dead hang.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean hanging knee raise to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict hanging knee raise", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict hanging knee raise", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict hanging knee raise", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict hanging knee raise", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.hanging-leg-raise",
            title: "Hanging Leg Raise",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "hanging leg raise", count: 10),
            prereqs: [PrerequisiteGroup("cl.hanging-knee-raise")],
            equipment: [.pullupBar],
            primary: [.core], secondary: [.lats],
            subtitle: "Full lower-ab control.",
            description: "10 hanging leg raises. Straight legs from dead hang to parallel or higher.",
            formCues: [
                "Legs straight throughout — locked knees",
                "Raise legs to parallel minimum, higher for clean reps",
                "Toes pointed",
                "Controlled 2s descent"
            ],
            commonMistakes: [
                "Bent knees mid-rep — that's a knee raise",
                "Kipping at the top for extra height",
                "Quickly dropping the eccentric"
            ],
            timeline: "1-3 months from knee raises.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(5), criterion: "First clean hanging leg raise to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(8), criterion: "8 strict hanging leg raise", xpReward: 100),
                SkillLevel(level: 3, target: .reps(10), criterion: "10 strict hanging leg raise", xpReward: 150),
                SkillLevel(level: 4, target: .reps(15), criterion: "15 strict hanging leg raise", xpReward: 200),
                SkillLevel(level: 5, target: .reps(20), criterion: "20 strict hanging leg raise", xpReward: 250),
            ]
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
                "Initiate with a lat pull to stabilize",
                "Legs straight, compress hips to bring toes up",
                "Toes CONTACT the bar, not just near it",
                "Control the descent"
            ],
            commonMistakes: [
                "Kipping — a different CrossFit skill",
                "Bent knees to cheat the compression",
                "Toes clearly short of the bar"
            ],
            timeline: "1-4 months from leg raises.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean strict toes-to-bar to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict strict toes-to-bar", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict strict toes-to-bar", xpReward: 150),
                SkillLevel(level: 4, target: .reps(10), criterion: "10 strict strict toes-to-bar", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict strict toes-to-bar", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.ab-wheel",
            title: "Standing Ab Wheel",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "ab wheel standing", count: 5),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.core, .shoulders], secondary: [.lats],
            subtitle: "Core + shoulder stability.",
            description: "5 ab wheel rollouts from standing position — toes down, hands on wheel, roll all the way out and come back.",
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
            timeline: "3-12 months from kneeling ab wheel.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .reps(3), criterion: "First clean standing ab wheel rollout to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict standing ab wheel rollout", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict standing ab wheel rollout", xpReward: 150),
                SkillLevel(level: 4, target: .reps(10), criterion: "10 strict standing ab wheel rollout", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict standing ab wheel rollout", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.dragon-flag-negative",
            title: "Dragon Flag Negative",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "dragon flag negative", count: 3),
            prereqs: [PrerequisiteGroup(["cl.hanging-leg-raise", "cal.l-sit-20"])],
            primary: [.core], secondary: [.lats, .glutes],
            subtitle: "Eccentric bridge to the full flag.",
            description: "3 dragon flag negatives. Lying on a bench, grip behind head, start vertical, lower body as one rigid line over 3-5 seconds.",
            formCues: [
                "Grip hard behind the head — don't let shoulders shrug",
                "Start vertical (or close)",
                "Lower as one rigid unit — no hip pike",
                "3-5 second descent minimum",
                "Reset at the top, don't bounce"
            ],
            commonMistakes: [
                "Piking at the hips under load",
                "Dropping fast when it burns",
                "Losing shoulder position at the top"
            ],
            timeline: "3-9 months from L-sit 20s + hanging leg raises.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean 5-second dragon flag negative to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict 5-second dragon flag negative", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict 5-second dragon flag negative", xpReward: 150),
                SkillLevel(level: 4, target: .reps(7), criterion: "7 strict 5-second dragon flag negative", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict 5-second dragon flag negative", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.dragon-flag",
            title: "Dragon Flag",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "dragon flag", count: 5),
            prereqs: [PrerequisiteGroup("cl.dragon-flag-negative")],
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
            timeline: "6-18 months from leg raises.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .reps(1), criterion: "First clean dragon flag to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict dragon flag", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict dragon flag", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict dragon flag", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict dragon flag", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.tuck-front-lever",
            title: "Tuck Front Lever",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "tuck front lever", seconds: 10),
            prereqs: [PrerequisiteGroup(["pp.10-pullups", "cl.hanging-leg-raise"])],
            equipment: [.pullupBar],
            primary: [.lats, .core],
            subtitle: "Front lever on-ramp.",
            description: "Hanging from the bar, knees tucked tight to chest, body pulled to horizontal. 10-second hold.",
            formCues: [
                "Depress and retract scaps — lats take the load",
                "Knees tucked tight, heels near glutes",
                "Body horizontal — hips at shoulder height",
                "Arms straight and locked",
                "Breathe — don't hold your breath"
            ],
            commonMistakes: [
                "Bent arms — instantly easier but wrong skill",
                "Hips drooping below horizontal",
                "Shrugged shoulders (scap retraction lost)"
            ],
            timeline: "3-9 months from 10 pullups + solid hanging core.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold tuck front lever for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold tuck front lever for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold tuck front lever for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 20), criterion: "Hold tuck front lever for 20s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 30), criterion: "Hold tuck front lever for 30s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.straddle-front-lever",
            title: "Straddle Front Lever",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "straddle front lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.tuck-front-lever")],
            equipment: [.pullupBar],
            primary: [.lats, .core],
            subtitle: "Legs split. Lever longer.",
            description: "Front lever with legs extended wide in a split. Reduces the lever slightly vs full but still demands horizontal hold. 5 seconds.",
            formCues: [
                "Extend legs wide — wider = easier",
                "Tighten the split over months",
                "Hips stay level — don't tilt with the spread",
                "Point toes, squeeze the straddle even though split"
            ],
            commonMistakes: [
                "Lazy split — legs drift together mid-hold",
                "Piking hips upward",
                "Losing scap retraction as fatigue sets in"
            ],
            timeline: "6-18 months from tuck front lever.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold straddle front lever for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold straddle front lever for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 8), criterion: "Hold straddle front lever for 8s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 12), criterion: "Hold straddle front lever for 12s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 15), criterion: "Hold straddle front lever for 15s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.full-front-lever",
            title: "Full Front Lever",
            cluster: .coreLever, tier: 6, type: .hold,
            target: .hold(exercise: "front lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.straddle-front-lever")],
            isKeystone: true,
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.lats, .core], secondary: [.back, .arms],
            subtitle: "Horizontal lats, horizontal body.",
            description: "Hang from a bar or rings, body horizontal, face up, legs together and straight. Five seconds unbroken.",
            formCues: [
                "Depress and retract scaps aggressively — lats do the work",
                "Posterior pelvic tilt — squeeze glutes, ribs tucked",
                "Point toes, legs glued together",
                "Arms straight, elbows locked — no bent-arm cheat",
                "Breathe — don't hold breath"
            ],
            commonMistakes: [
                "Bent arms as fatigue sets in",
                "Hips piking upward — hip-flexor dominant hold instead of lat",
                "Anterior pelvic tilt — lower back arches, legs drop"
            ],
            timeline: "1-3 years from tuck front lever.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold full front lever for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold full front lever for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 8), criterion: "Hold full front lever for 8s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 12), criterion: "Hold full front lever for 12s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 15), criterion: "Hold full front lever for 15s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.tuck-back-lever",
            title: "Tuck Back Lever",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "tuck back lever", seconds: 5),
            prereqs: [PrerequisiteGroup(["pp.10-pullups", "cl.hanging-leg-raise"])],
            equipment: [.pullupBar],
            primary: [.shoulders, .chest, .core], secondary: [.lats, .arms],
            subtitle: "First taste of horizontal pulling.",
            description: "Hanging inverted, knees tucked tight to chest, lowered to a horizontal body position face-down with straight arms. 5-second hold.",
            formCues: [
                "Arms lock fully straight — no bent-arm cheat",
                "Shoulders protract HARD — scaps spread apart",
                "Knees tucked tight, heels near glutes",
                "Body horizontal — hips at shoulder height",
                "Breathe normally — don't brace statically"
            ],
            commonMistakes: [
                "Bent arms once the biceps tendon loads up",
                "Tucked legs drifting away from chest",
                "Piking hips upward — scapular collapse"
            ],
            timeline: "3-9 months from 10 pullups + solid hanging core.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold tuck back lever for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold tuck back lever for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold tuck back lever for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold tuck back lever for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold tuck back lever for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.straddle-back-lever",
            title: "Straddle Back Lever",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "straddle back lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.tuck-back-lever")],
            equipment: [.pullupBar],
            primary: [.shoulders, .chest, .core], secondary: [.lats, .arms],
            subtitle: "Legs split. Lever longer.",
            description: "Back lever with legs extended wide in a split. Reduces the lever vs full back lever but still demands straight-arm horizontal hold. 5 seconds.",
            formCues: [
                "Extend legs wide — wider = easier",
                "Tighten the split over months as strength climbs",
                "Arms lock fully straight under tension",
                "Hips stay at shoulder height — no downward pike",
                "Shoulders protract throughout"
            ],
            commonMistakes: [
                "Lazy split — legs drift together mid-hold",
                "Bent arms as fatigue sets in",
                "Hips dropping below shoulder line"
            ],
            timeline: "6-18 months from tuck back lever.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold straddle back lever for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold straddle back lever for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 8), criterion: "Hold straddle back lever for 8s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 12), criterion: "Hold straddle back lever for 12s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 15), criterion: "Hold straddle back lever for 15s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.full-back-lever",
            title: "Full Back Lever",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "back lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.straddle-back-lever")],
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.shoulders, .chest, .core],
            subtitle: "Horizontal, face down, straight arms.",
            description: "Hanging inverted from bar or rings, lower to horizontal body position face-down. Arms straight, body rigid. 5-second hold.",
            formCues: [
                "Build up slowly — big biceps-tendon load",
                "Arms lock fully straight",
                "Body stays in one horizontal line",
                "Shoulders protract HARD",
                "Glutes + quads squeezed to prevent sag"
            ],
            commonMistakes: [
                "Rushing progression — connective tissue needs months",
                "Bent arms under load — injury risk",
                "Piking hips downward"
            ],
            timeline: "6-18 months from tuck back lever.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold full back lever for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold full back lever for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 8), criterion: "Hold full back lever for 8s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 12), criterion: "Hold full back lever for 12s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 15), criterion: "Hold full back lever for 15s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.victorian",
            title: "Victorian",
            cluster: .coreLever, tier: 7, type: .hold,
            target: .hold(exercise: "victorian", seconds: 1),
            prereqs: [PrerequisiteGroup(["cl.full-front-lever", "cal.iron-cross-10s"])],
            isMythic: true,
            equipment: [.gymnasticRings],
            primary: [.lats, .core, .shoulders],
            subtitle: "Front lever with arms at your sides.",
            description: "Body horizontal as in a front lever, but arms extended down to hip level instead of overhead. Combines front lever lat strength with iron cross adduction. F-difficulty in gymnastics.",
            formCues: [
                "You do not program toward Victorian — it's a by-product of many years",
                "Requires pristine shoulder health",
                "Full body tension, no breaks in form",
                "Coach-spotted partial attempts for years before freestanding"
            ],
            commonMistakes: [
                "Any attempt before full FL + 10s Iron Cross + 5+ years of ring work",
                "Bending arms under load",
                "Rushing progression — Victorian breaks bodies when rushed"
            ],
            timeline: "5-10+ years. Fewer than 50 humans hold it cleanly.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 1), criterion: "Hold victorian for 1s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 2), criterion: "Hold victorian for 2s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 3), criterion: "Hold victorian for 3s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 5), criterion: "Hold victorian for 5s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 8), criterion: "Hold victorian for 8s, clean form", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // CONDITIONING (co) — carries, grip, capacity
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "co.bw-farmer-carry",
            title: "Farmer Carry",
            cluster: .conditioning, tier: 2, type: .skill,
            target: .carry(exercise: "farmer carry", seconds: 60, load: "bw"),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            equipment: [.dumbbells, .kettlebell],
            primary: [.forearms, .traps, .core], secondary: [.legs],
            subtitle: "Real-world carry density.",
            description: "60-second unbroken farmer carry at total load = bodyweight (split evenly across both hands). Grip, traps, core, and legs all taxed together.",
            formCues: [
                "Chest up, shoulders packed down",
                "Neutral spine — don't slump forward",
                "Short, even strides",
                "Full-hand grip (all 4 fingers + thumb)",
                "Breathe rhythmically — don't hold breath"
            ],
            commonMistakes: [
                "Slumped shoulders — shrug DOWN, not up",
                "Dropping early = no counted rep",
                "Uneven loading between hands"
            ],
            timeline: "2-6 months from BW deadlift.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 30), criterion: "30s bw farmer carry unbroken", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 45), criterion: "45s bw farmer carry unbroken", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 60), criterion: "60s bw farmer carry unbroken", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 90), criterion: "90s bw farmer carry unbroken", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 120), criterion: "120s bw farmer carry unbroken", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.1.5x-farmer-carry",
            title: "Heavy Farmer Carry",
            cluster: .conditioning, tier: 4, type: .skill,
            target: .carry(exercise: "farmer carry", seconds: 60, load: "1.5x bw"),
            prereqs: [PrerequisiteGroup(["co.bw-farmer-carry"])],
            equipment: [.dumbbells, .kettlebell],
            primary: [.forearms, .traps, .core],
            subtitle: "Strongman-adjacent grip.",
            description: "60 seconds of unbroken farmer carry at 1.5× bodyweight. Grip becomes the limiter at this load.",
            formCues: [
                "Chalk the hands — grip is the real test",
                "Short, fast steps to keep momentum",
                "Full 60s or fail — no passing bells hand-to-hand",
                "Pull shoulders down the whole walk"
            ],
            commonMistakes: [
                "Dropping on second 55 because grip gives out",
                "Forward lean under load",
                "Mis-loading hands"
            ],
            timeline: "1-3 years from BW farmer carry.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 30), criterion: "30s 1.5x bw farmer carry", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 45), criterion: "45s 1.5x bw farmer carry", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 60), criterion: "60s 1.5x bw farmer carry", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 75), criterion: "75s 1.5x bw farmer carry", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 90), criterion: "90s 1.5x bw farmer carry", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.dead-hang-45",
            title: "Long Dead Hang",
            cluster: .conditioning, tier: 2, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 45),
            prereqs: [PrerequisiteGroup("pp.dead-hang-30")],
            equipment: [.pullupBar],
            primary: [.forearms, .lats],
            subtitle: "Grip endurance step-up.",
            description: "45 seconds of unbroken dead hang from a pullup bar. Active shoulders, full grip, no kipping.",
            formCues: [
                "Active shoulders — pull them down away from ears",
                "All 4 fingers + thumb wrapped",
                "Breathe normally",
                "Legs neutral — no kipping for extra seconds"
            ],
            commonMistakes: [
                "Passive shoulders as you fatigue",
                "Gripping with 3 fingers",
                "Dropping early instead of lowering with control"
            ],
            timeline: "2-6 weeks from dead hang 30s.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 20), criterion: "Hold dead hang for 20s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 30), criterion: "Hold dead hang for 30s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 45), criterion: "Hold dead hang for 45s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 60), criterion: "Hold dead hang for 60s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 90), criterion: "Hold dead hang for 90s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.dead-hang-60",
            title: "Max Dead Hang",
            cluster: .conditioning, tier: 3, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 60),
            prereqs: [PrerequisiteGroup("co.dead-hang-45")],
            equipment: [.pullupBar],
            primary: [.forearms, .lats],
            subtitle: "Grip endurance benchmark.",
            description: "One full minute of active dead hang. Crosses from beginner grip capacity into real endurance territory.",
            formCues: [
                "At 60s the grip is doing real work — don't death-clench early",
                "Controlled breathing prevents premature failure",
                "Shoulders pack down throughout",
                "Stay relaxed where you can — tension only where needed"
            ],
            commonMistakes: [
                "Over-gripping the first 20s and burning out",
                "Holding breath",
                "Letting shoulders shrug as fatigue builds"
            ],
            timeline: "1-3 months from 45s.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 30), criterion: "Hold dead hang for 30s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 45), criterion: "Hold dead hang for 45s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 60), criterion: "Hold dead hang for 60s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 90), criterion: "Hold dead hang for 90s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 120), criterion: "Hold dead hang for 120s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.sled-push",
            title: "Sled Push",
            cluster: .conditioning, tier: 3, type: .skill,
            target: .carry(exercise: "sled push", seconds: 30, load: "2x bw"),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            equipment: [.sled],
            primary: [.legs, .glutes],
            subtitle: "Engine-builder.",
            description: "30 seconds of sustained sled push at 2× bodyweight of loaded sled. Brutal on legs + cardio without the eccentric damage of running.",
            formCues: [
                "Forward lean — chest drives into the handles",
                "Short, powerful strides",
                "Arms stay straight, transferring force to the sled",
                "Glutes drive each step"
            ],
            commonMistakes: [
                "Standing too upright — losing leverage",
                "Huge strides stall momentum",
                "Sprinting out the first 10s and dying"
            ],
            timeline: "Develops naturally alongside squat programming.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 15), criterion: "15s sled push at 2x bw load", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 20), criterion: "20s sled push at 2x bw load", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 30), criterion: "30s sled push at 2x bw load", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 45), criterion: "45s sled push at 2x bw load", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 60), criterion: "60s sled push at 2x bw load", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.400m-row",
            title: "Rower Sprint",
            cluster: .conditioning, tier: 3, type: .skill,
            target: .steps(exercise: "row 400m", count: 1),
            equipment: [.rower],
            primary: [.back, .legs], secondary: [.arms],
            subtitle: "Short-burst conditioning.",
            description: "400 meters on a rowing ergometer in under 1:30. Taxes legs, lungs, and back simultaneously.",
            formCues: [
                "Catch: shins vertical, arms straight, compressed",
                "Drive: legs first, then hips, then arms — sequence matters",
                "Recovery: arms out first, then hips, then legs",
                "Long, powerful strokes — not short frantic ones"
            ],
            commonMistakes: [
                "Arm-pulling too early — loses leg drive",
                "Short strokes sacrifice distance per effort",
                "Burning out in the first 200m"
            ],
            timeline: "2-6 months of rowing practice.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 120), criterion: "400m row in under 2:00", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 105), criterion: "400m row in under 1:45", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 90), criterion: "400m row in under 1:30", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 80), criterion: "400m row in under 1:20", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 75), criterion: "400m row in under 1:15", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.mile-sub-7",
            title: "Fast Mile",
            cluster: .conditioning, tier: 3, type: .skill,
            target: .steps(exercise: "run 1 mile", count: 1),
            primary: [.legs], secondary: [.core],
            subtitle: "Run a mile under 7 minutes.",
            description: "One mile run in under 7 minutes. Aerobic capacity benchmark most lifters skip — the first test that keeps strength training honest.",
            formCues: [
                "Warm up 5-10 minutes easy before the effort",
                "Even pacing beats fast-start-then-die",
                "Cadence around 170-180 steps/min",
                "Breathe in two, out two — find a rhythm",
                "Relax the shoulders — tension wastes energy"
            ],
            commonMistakes: [
                "Sprinting the first 400m and paying for it",
                "No base aerobic miles in the weeks before — cramps mid-effort",
                "Heel-striking hard — rolls into stride over midfoot"
            ],
            timeline: "2-4 months of 2-3 runs per week from untrained.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 540), criterion: "1 mile under 9:00", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 480), criterion: "1 mile under 8:00", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 420), criterion: "1 mile under 7:00", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 390), criterion: "1 mile under 6:30", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 360), criterion: "1 mile under 6:00", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.5k-sub-22",
            title: "Fast 5K",
            cluster: .conditioning, tier: 4, type: .skill,
            target: .steps(exercise: "run 5k", count: 1),
            prereqs: [PrerequisiteGroup("co.mile-sub-7")],
            primary: [.legs], secondary: [.core],
            subtitle: "5 kilometers under 22 minutes.",
            description: "5K run in under 22 minutes (~7:00/mi pace). Real aerobic engine — puts you in the top third of recreational runners.",
            formCues: [
                "Target a negative split — second half slightly faster",
                "Build mileage base (15-20 mi/week) before chasing the time",
                "Stay on pace in the first mile — don't race the start",
                "Breathe steady, mouth + nose — keep CO2 flushed",
                "Relaxed arms, tight core, efficient stride"
            ],
            commonMistakes: [
                "Treating it like a max-effort 5K every session",
                "No long runs in the build — blows up in mile 2",
                "Ignoring easy days — every run hard = no adaptation"
            ],
            timeline: "3-9 months from sub-7 mile.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 1620), criterion: "5K under 27:00", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 1500), criterion: "5K under 25:00", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 1320), criterion: "5K under 22:00", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 1200), criterion: "5K under 20:00", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 1080), criterion: "5K under 18:00", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.2x-farmer-carry",
            title: "Elite Farmer Carry",
            cluster: .conditioning, tier: 5, type: .strength,
            target: .weightMultiplier(exercise: "farmer carry", multiplier: 2.0),
            prereqs: [PrerequisiteGroup("co.1.5x-farmer-carry")],
            isKeystone: true,
            equipment: [.dumbbells, .kettlebell],
            primary: [.forearms, .traps, .core], secondary: [.legs, .back],
            subtitle: "Two times your bodyweight, 60 seconds, no drop.",
            description: "60 seconds of unbroken farmer carry at 2× bodyweight total load. Strongman-territory grip + postural endurance — one of the rarest carry benchmarks.",
            formCues: [
                "Chalk hands, hook-grip optional at this load",
                "Brace HARD before the pickup — don't yank",
                "Short fast steps, aggressive shoulder pack-down",
                "Every rep of the carry is a micro-max deadlift",
                "Set the implements down with control — no drop"
            ],
            commonMistakes: [
                "Dropping at 55s because grip gave out",
                "Picking up with a rounded back",
                "Walking too slow — grip fails before the clock"
            ],
            timeline: "2-4 years from 1.5× farmer carry.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 20), criterion: "20s 2x bw farmer carry", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 30), criterion: "30s 2x bw farmer carry", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 45), criterion: "45s 2x bw farmer carry", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 60), criterion: "60s 2x bw farmer carry", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 75), criterion: "75s 2x bw farmer carry", xpReward: 250),
            ]
        ),
        .simple(
            id: "co.assault-bike-30",
            title: "Assault Bike Sprint",
            cluster: .conditioning, tier: 3, type: .skill,
            target: .steps(exercise: "assault bike 30 cal", count: 1),
            equipment: [.bodyweight],
            primary: [.legs, .shoulders], secondary: [.core, .back],
            subtitle: "30 calories, under a minute.",
            description: "30 calories on the assault bike in under 60 seconds. MetCon-style capacity test — exposes the gap between strength and sustained output.",
            formCues: [
                "Drive with the legs first, let the arms follow the rhythm",
                "Stay seated — standing costs more than it gains on short efforts",
                "Pick a sustainable cadence, don't flail",
                "Breathe big, nose + mouth — flush the CO2",
                "Accept the discomfort — it's a 45-60s effort, not a mile"
            ],
            commonMistakes: [
                "Arm-dominant start — legs disappear by calorie 15",
                "Holding breath through the middle",
                "Pacing like a 5-minute effort — leaves calories on the table"
            ],
            timeline: "2-6 months of bike intervals.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .duration(seconds: 75), criterion: "30 cal under 1:15", xpReward: 50),
                SkillLevel(level: 2, target: .duration(seconds: 65), criterion: "30 cal under 1:05", xpReward: 100),
                SkillLevel(level: 3, target: .duration(seconds: 60), criterion: "30 cal under 1:00", xpReward: 150),
                SkillLevel(level: 4, target: .duration(seconds: 55), criterion: "30 cal under 0:55", xpReward: 200),
                SkillLevel(level: 5, target: .duration(seconds: 50), criterion: "30 cal under 0:50", xpReward: 250),
            ]
        )
    ]
}

// MARK: - Legacy SkillTree content access (keeps old callers compiling)
//
// Synthesized per-archetype views over SkillGraph.shared.

extension SkillTree {
    static var unitTree:     SkillTree { .tree(for: .heavyDuty) }
    static var leanCutTree:  SkillTree { .tree(for: .leanCut) }
    static var carvedTree:   SkillTree { .tree(for: .shredded) }
    static var vTaperTree:   SkillTree { .tree(for: .vTaper) }

    static let allTrees: [Archetype: SkillTree] = [
        .heavyDuty: .tree(for: .heavyDuty),
        .leanCut:   .tree(for: .leanCut),
        .shredded:  .tree(for: .shredded),
        .vTaper:    .tree(for: .vTaper)
    ]
}
