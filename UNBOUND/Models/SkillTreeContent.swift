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
        // HEAVY LIFTING (hl) — barbell multipliers
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "hl.bw-deadlift",
            title: "BW Deadlift",
            cluster: .heavyLifting, tier: 2, type: .strength,
            target: .weightMultiplier(exercise: "deadlift", multiplier: 1.0),
            equipment: [.barbell],
            primary: [.back, .glutes, .legs], secondary: [.forearms, .core],
            subtitle: "Pull what you weigh.",
            description: "The foundation of every posterior-chain skill. Conventional pull from the floor at bodyweight.",
            formCues: [
                "Feet hip-width, bar over mid-foot",
                "Hinge hips back, bend knees to grip",
                "Chest up, shoulders over bar, neutral spine",
                "Push floor away — legs drive first, then hips",
                "Lockout with glutes squeezed"
            ],
            commonMistakes: [
                "Round back at setup or through the pull",
                "Hips shooting up before the bar moves",
                "Bar drifting away from body"
            ],
            timeline: "Most reach this within 3-6 months of training."
        ),
        .simple(
            id: "hl.1.5x-deadlift",
            title: "1.5× Deadlift",
            cluster: .heavyLifting, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "deadlift", multiplier: 1.5),
            prereqs: [PrerequisiteGroup("hl.bw-deadlift")],
            equipment: [.barbell],
            primary: [.back, .glutes, .legs], secondary: [.forearms, .traps],
            subtitle: "Separator from casuals.",
            description: "Conventional deadlift at 1.5× bodyweight. The strength threshold that separates recreational lifters from genuinely strong ones.",
            formCues: [
                "Bar over mid-foot BEFORE you set up",
                "Hips push down, chest up — build tension before bar moves",
                "Drive the floor away, don't yank the bar",
                "Keep the bar close to shins and thighs",
                "Full hip extension at lockout, no hyperextension"
            ],
            commonMistakes: [
                "Bar drifting forward on the way up",
                "Yanking off the floor without building tension",
                "Hitching — dragging bar up the body instead of a single pull"
            ],
            timeline: "6-18 months from BW DL."
        ),
        .simple(
            id: "hl.2x-deadlift",
            title: "2× Deadlift",
            cluster: .heavyLifting, tier: 4, type: .strength,
            target: .weightMultiplier(exercise: "deadlift", multiplier: 2.0),
            prereqs: [
                PrerequisiteGroup(["hl.1.5x-deadlift", "co.bw-farmer-carry"]),
                PrerequisiteGroup(["hl.1.5x-deadlift", "pp.10-pullups"])
            ],
            isKeystone: true,
            equipment: [.barbell],
            primary: [.back, .glutes, .legs], secondary: [.forearms, .traps, .lats],
            subtitle: "Elite recreational strength.",
            timeline: "2-4 years of consistent pulling."
        ),

        .simple(
            id: "hl.bw-back-squat",
            title: "BW Back Squat",
            cluster: .heavyLifting, tier: 2, type: .strength,
            target: .weightMultiplier(exercise: "back squat", multiplier: 1.0),
            equipment: [.barbell],
            primary: [.legs, .glutes], secondary: [.core, .back],
            subtitle: "The entry checkpoint for leg mass.",
            description: "Barbell back squat at bodyweight. Full depth, braced core, bar secure on upper traps (high-bar) or rear delts (low-bar).",
            formCues: [
                "Bar position locked — choose high or low, stay consistent",
                "Feet shoulder-width, toes turned out 15°",
                "Break hips AND knees simultaneously — sit down, not back",
                "Depth: crease of hip below top of knee",
                "Drive up chest-first, knees tracking over toes"
            ],
            commonMistakes: [
                "Butt wink at the bottom — pelvis tucking from tight hips",
                "Knees caving on the way up",
                "Quarter-squatting to chase heavier loads"
            ],
            timeline: "3-9 months from untrained."
        ),
        .simple(
            id: "hl.1.5x-back-squat",
            title: "1.5× Back Squat",
            cluster: .heavyLifting, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "back squat", multiplier: 1.5),
            prereqs: [PrerequisiteGroup("hl.bw-back-squat")],
            equipment: [.barbell],
            primary: [.legs, .glutes], secondary: [.core, .back],
            subtitle: "Legs that fill out jeans.",
            description: "Back squat at 1.5× bodyweight. The threshold where visible leg development shows up.",
            formCues: [
                "Belt + brace before unracking",
                "Walk out in 2-3 steps, feet set, then descend",
                "Full depth every rep — sets the pattern",
                "Knees drive out on the way up, not in",
                "Complete hip extension at top"
            ],
            commonMistakes: [
                "Losing depth as load climbs",
                "Good morning squat (chest drops, hips rise first)",
                "Gripping the bar with death-clench and burning shoulders"
            ],
            timeline: "1-2 years from first BW squat."
        ),
        .simple(
            id: "hl.2x-back-squat",
            title: "2× Back Squat",
            cluster: .heavyLifting, tier: 4, type: .strength,
            target: .weightMultiplier(exercise: "back squat", multiplier: 2.0),
            prereqs: [
                PrerequisiteGroup(["hl.1.5x-back-squat", "ld.bw-front-squat"]),
                PrerequisiteGroup(["hl.1.5x-back-squat", "ld.pistol-squat"])
            ],
            isKeystone: true,
            equipment: [.barbell],
            primary: [.legs, .glutes], secondary: [.core, .back],
            subtitle: "Most gym regulars never get here.",
            description: "Full-depth barbell back squat at 2× bodyweight. Competitive strength territory — fewer than 5% of lifetime gym-goers hit this.",
            formCues: [
                "Heavy single needs months of programming — don't test cold",
                "Brace hard BEFORE unracking — breath and belt in place",
                "Descend with control, no bouncing off the bottom",
                "Knees track over toes under max load",
                "Complete hip extension at top"
            ],
            commonMistakes: [
                "Testing max without proper warmup pyramid",
                "Partial depth at heavy loads",
                "Good-morning squat (hips rising before chest at bottom)"
            ],
            timeline: "3-6+ years of dedicated squat programming."
        ),

        .simple(
            id: "hl.0.75x-bench",
            title: "0.75× Bench",
            cluster: .heavyLifting, tier: 2, type: .strength,
            target: .weightMultiplier(exercise: "bench press", multiplier: 0.75),
            equipment: [.barbell, .elevatedSurface],
            primary: [.chest, .shoulders, .arms],
            subtitle: "First real press milestone.",
            description: "Barbell bench press at 75% of bodyweight. The on-ramp where bench press becomes a real strength lift.",
            formCues: [
                "Shoulder blades pinched tight into the bench",
                "Slight arch — lumbar stays on the bench, upper back arches",
                "Feet planted hard, leg drive into the floor",
                "Bar touches lower chest (not neck)",
                "Elbows at ~45° to torso, not flared"
            ],
            commonMistakes: [
                "Flared elbows — 90° setup hurts shoulders",
                "Bouncing the bar off the chest",
                "Partial ROM — not touching chest"
            ],
            timeline: "2-4 months from untrained."
        ),
        .simple(
            id: "hl.bw-bench",
            title: "BW Bench",
            cluster: .heavyLifting, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "bench press", multiplier: 1.0),
            prereqs: [PrerequisiteGroup("hl.0.75x-bench")],
            equipment: [.barbell, .elevatedSurface],
            primary: [.chest, .shoulders, .arms],
            subtitle: "The classic threshold every gym-goer wants.",
            description: "Bench press at your bodyweight. Bars-and-plates gym benchmark that opens intermediate programming.",
            formCues: [
                "Same setup as 0.75×, just more intent",
                "Pause on chest each rep unless speed work",
                "Controlled descent (2s), aggressive drive up",
                "Wrists stacked over elbows under the bar"
            ],
            commonMistakes: [
                "Bar path drifting toward face",
                "Butt lifts off the bench — cheats depth",
                "Feet moving mid-set — breaks leg drive"
            ],
            timeline: "6-18 months from first bench."
        ),
        .simple(
            id: "hl.1.25x-bench",
            title: "1.25× Bench",
            cluster: .heavyLifting, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "bench press", multiplier: 1.25),
            prereqs: [PrerequisiteGroup("hl.bw-bench")],
            equipment: [.barbell, .elevatedSurface],
            primary: [.chest, .shoulders, .arms],
            subtitle: "Legitimate intermediate.",
            description: "Bench press at 1.25× bodyweight. The load where technique quirks get exposed — setup matters now.",
            formCues: [
                "Spot recommended above this load",
                "Belt optional but helps brace",
                "Pause bench shows real strength",
                "Stay tight through the set — no resets between reps on singles"
            ],
            commonMistakes: [
                "Losing upper-back tightness as load climbs",
                "Ego touch-and-go when form is failing",
                "Training without a spotter on maxes"
            ],
            timeline: "1-3 years from first bench."
        ),

        // ────────────────────────────────────────────────────────────────
        // LEG DOMINANCE (ld) — single-leg / variation squat chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "ld.goblet-20",
            title: "20 Goblet Squats",
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
            timeline: "3-6 weeks once the squat pattern grooves."
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
            timeline: "2-4 weeks from BW squat."
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
            timeline: "2-4 weeks from goblet squats."
        ),
        .simple(
            id: "ld.100-lunges",
            title: "100 Lunge Steps",
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
            timeline: "2-6 weeks once lunge pattern is solid."
        ),
        .simple(
            id: "ld.bw-front-squat",
            title: "BW Front Squat",
            cluster: .legDominance, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "front squat", multiplier: 1.0),
            prereqs: [PrerequisiteGroup(["ld.goblet-20", "hl.1.5x-back-squat"])],
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
            timeline: "3-12 months after solid back squat."
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
            timeline: "2-4 months from BSS mastery."
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
            timeline: "2-4 months from shrimp squat."
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
            timeline: "2-6 weeks from lunges."
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
            timeline: "6-18 months from BSS mastery."
        ),
        .simple(
            id: "ld.weighted-pistol",
            title: "Weighted Pistol 0.5× BW",
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
            timeline: "1-3 years from weighted pistol."
        ),
        .simple(
            id: "ld.jumping-pistol",
            title: "Jumping Pistol",
            cluster: .legDominance, tier: 7, type: .skill,
            target: .reps(exercise: "jumping pistol", count: 3),
            prereqs: [PrerequisiteGroup("ld.dragon-pistol")],
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
            timeline: "5+ years of single-leg work. Very rare in the wild."
        ),

        // ────────────────────────────────────────────────────────────────
        // PULLING POWER (pp) — bar skills + pullup chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pp.dead-hang-30",
            title: "Dead Hang 30s",
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
            timeline: "2-6 weeks for most healthy adults."
        ),
        .simple(
            id: "pp.negative-pullup",
            title: "Negative Pullup × 3",
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
            timeline: "2-6 weeks from dead hang."
        ),
        .simple(
            id: "pp.pullup",
            title: "First Pullup",
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
            timeline: "6 weeks to 6 months depending on starting strength."
        ),
        .simple(
            id: "pp.5-pullups",
            title: "5 Pullups",
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
            timeline: "1-6 months from first pullup."
        ),
        .simple(
            id: "pp.10-pullups",
            title: "10 Pullups",
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
            timeline: "3-12 months from first pullup."
        ),
        .simple(
            id: "pp.slow-pullup",
            title: "Slow Pullup (3s/3s)",
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
            timeline: "2-4 months after strict 5 pullups."
        ),
        .simple(
            id: "pp.chest-to-bar",
            title: "Chest-to-Bar × 5",
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
            timeline: "2-6 months from 5 pullups."
        ),
        .simple(
            id: "pp.l-sit-pullup",
            title: "L-Sit Pullup × 5",
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
            timeline: "3-9 months from clean L-sit + slow pullup."
        ),
        .simple(
            id: "pp.archer-pullup",
            title: "Archer Pullup",
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
            timeline: "2-6 months from slow pullup mastery."
        ),
        .simple(
            id: "pp.weighted-pullup-0.25",
            title: "Weighted Pullup 0.25× BW",
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
            timeline: "3-9 months from 10 pullups."
        ),
        .simple(
            id: "pp.typewriter-pullup",
            title: "Typewriter Pullup",
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
            timeline: "3-6 months from archer mastery."
        ),
        .simple(
            id: "pp.oap-negative",
            title: "One-Arm Pullup Negative",
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
            timeline: "3-9 months from typewriter pullup."
        ),
        .simple(
            id: "pp.one-arm-pullup",
            title: "One-Arm Pullup",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "one-arm pullup", count: 1),
            prereqs: [PrerequisiteGroup("pp.oap-negative")],
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
            timeline: "3-5+ years of dedicated pull programming."
        ),
        .simple(
            id: "pp.muscle-up",
            title: "Muscle-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
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
            timeline: "6-18 months from first pullup, if dips are trained in parallel."
        ),
        .simple(
            id: "pp.10-muscle-ups",
            title: "10 Muscle-Ups",
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
            timeline: "6-18 months from first MU."
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
            timeline: "3-12 months from bar MU."
        ),
        .simple(
            id: "pp.5-oap-side",
            title: "5 One-Arm Pullups / side",
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
            timeline: "1-3 years past the first clean OAP."
        ),

        // ────────────────────────────────────────────────────────────────
        // CALISTHENIC CONTROL (cal) — pushups + planche + handstand + rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.plank-30",
            title: "30s Plank",
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
            timeline: "1-4 weeks from zero to 30s clean."
        ),
        .simple(
            id: "cal.l-sit-10",
            title: "L-Sit 10s",
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
            timeline: "1-3 months from solid compressed leg raises."
        ),
        .simple(
            id: "cal.l-sit-20",
            title: "L-Sit 20s",
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
            timeline: "2-6 months from L-Sit 10s."
        ),

        .simple(
            id: "cal.pushup",
            title: "Pushup",
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
            timeline: "2-6 weeks for first 10 clean reps."
        ),
        .simple(
            id: "cal.slow-pushup",
            title: "Slow Pushup (3s/3s)",
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
            timeline: "2-4 weeks from 10 standard pushups."
        ),
        .simple(
            id: "cal.5-dips",
            title: "5 Dips",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.pushup")],
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
            timeline: "1-3 months from solid pushups."
        ),
        .simple(
            id: "cal.diamond-pushup",
            title: "Diamond Pushup × 10",
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
            timeline: "2-6 weeks from slow pushup."
        ),
        .simple(
            id: "cal.pseudo-planche-pushup",
            title: "Pseudo-Planche Pushup",
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
            timeline: "1-3 months from diamond pushup."
        ),
        .simple(
            id: "cal.tuck-planche",
            title: "Tuck Planche 5s",
            cluster: .calisthenicControl, tier: 3, type: .hold,
            target: .hold(exercise: "tuck planche", seconds: 5),
            prereqs: [PrerequisiteGroup(["cal.plank-30", "pp.pullup"])],
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
            timeline: "3-9 months from pseudo-planche pushup."
        ),
        .simple(
            id: "cal.tuck-planche-pushup",
            title: "Tuck Planche Pushup",
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
            timeline: "6-12 months from tuck planche."
        ),
        .simple(
            id: "cal.straddle-planche",
            title: "Straddle Planche 5s",
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
            timeline: "1-2 years from tuck planche."
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
            timeline: "2-4 years from first tuck planche."
        ),
        .simple(
            id: "cal.full-planche-pushup",
            title: "Full Planche Pushup",
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
            timeline: "1-2 years from full planche hold."
        ),
        .simple(
            id: "cal.ninety-degree-pushup",
            title: "90° Pushup",
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
            timeline: "5+ years past the full planche pushup."
        ),

        .simple(
            id: "cal.wall-handstand-30",
            title: "Wall Handstand 30s",
            cluster: .calisthenicControl, tier: 2, type: .hold,
            target: .hold(exercise: "wall handstand", seconds: 30),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.shoulders, .core], secondary: [.arms]
        ),
        .simple(
            id: "cal.wall-handstand-60",
            title: "Wall Handstand 60s",
            cluster: .calisthenicControl, tier: 3, type: .hold,
            target: .hold(exercise: "wall handstand", seconds: 60),
            prereqs: [PrerequisiteGroup("cal.wall-handstand-30")],
            primary: [.shoulders, .core]
        ),
        .simple(
            id: "cal.freestanding-handstand-10",
            title: "Freestanding HS 10s",
            cluster: .calisthenicControl, tier: 4, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.wall-handstand-60")],
            primary: [.shoulders, .core], secondary: [.forearms]
        ),
        .simple(
            id: "cal.freestanding-handstand-60",
            title: "Freestanding HS 60s",
            cluster: .calisthenicControl, tier: 5, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 60),
            prereqs: [PrerequisiteGroup("cal.freestanding-handstand-10")],
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
            timeline: "1-3 years of daily practice."
        ),
        .simple(
            id: "cal.wall-hspu",
            title: "Wall HSPU × 5",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "wall hspu", count: 5),
            prereqs: [PrerequisiteGroup("cal.wall-handstand-60")],
            primary: [.shoulders, .arms], secondary: [.chest, .core]
        ),
        .simple(
            id: "cal.freestanding-hspu",
            title: "Freestanding HSPU",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "freestanding hspu", count: 1),
            prereqs: [PrerequisiteGroup(["cal.wall-hspu", "cal.freestanding-handstand-10"])],
            isKeystone: true,
            primary: [.shoulders, .arms], secondary: [.core],
            subtitle: "Push the whole body against gravity.",
            description: "One freestanding handstand pushup. Lower to head tap, press back to full lockout. No wall, no support.",
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
            timeline: "2-4 years from wall HSPU."
        ),
        .simple(
            id: "cal.handstand-walk",
            title: "Handstand Walk 10m",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .steps(exercise: "handstand walk", count: 10),
            prereqs: [PrerequisiteGroup("cal.freestanding-handstand-10")],
            primary: [.shoulders, .core]
        ),
        .simple(
            id: "cal.one-arm-handstand",
            title: "One-Arm Handstand 5s",
            cluster: .calisthenicControl, tier: 7, type: .hold,
            target: .hold(exercise: "one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("cal.freestanding-handstand-60")],
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
            timeline: "3-7 years of daily handstand work."
        ),
        .simple(
            id: "cal.one-arm-hspu",
            title: "One-Arm HSPU",
            cluster: .calisthenicControl, tier: 7, type: .skill,
            target: .reps(exercise: "one-arm hspu", count: 1),
            prereqs: [PrerequisiteGroup(["cal.one-arm-handstand", "cal.freestanding-hspu"])],
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
            timeline: "Most who reach OA-HS never complete this. 7+ years."
        ),

        .simple(
            id: "cal.iron-cross-3s",
            title: "Iron Cross 3s",
            cluster: .calisthenicControl, tier: 5, type: .hold,
            target: .hold(exercise: "iron cross", seconds: 3),
            prereqs: [PrerequisiteGroup(["cl.full-back-lever", "pp.ring-muscle-up"])],
            equipment: [.gymnasticRings],
            primary: [.chest, .shoulders, .arms, .lats]
        ),
        .simple(
            id: "cal.iron-cross-10s",
            title: "Iron Cross 10s",
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
            timeline: "4-6 years of dedicated ring work."
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
            timeline: "5-10 years of serious ring work. <500 humans hold it cleanly."
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
            timeline: "5-10 years. Competitive gymnasts and dedicated specialists only."
        ),

        // ────────────────────────────────────────────────────────────────
        // CORE & LEVER (cl) — dynamic core + levers
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.hanging-knee-raise",
            title: "Hanging Knee Raise × 10",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "hanging knee raise", count: 10),
            prereqs: [PrerequisiteGroup("pp.dead-hang-30")],
            equipment: [.pullupBar],
            primary: [.core], secondary: [.lats, .forearms]
        ),
        .simple(
            id: "cl.hanging-leg-raise",
            title: "Hanging Leg Raise × 10",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "hanging leg raise", count: 10),
            prereqs: [PrerequisiteGroup("cl.hanging-knee-raise")],
            equipment: [.pullupBar],
            primary: [.core], secondary: [.lats]
        ),
        .simple(
            id: "cl.toes-to-bar",
            title: "Toes-to-Bar × 5",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "toes to bar", count: 5),
            prereqs: [PrerequisiteGroup("cl.hanging-leg-raise")],
            equipment: [.pullupBar],
            primary: [.core, .lats]
        ),
        .simple(
            id: "cl.ab-wheel",
            title: "Ab Wheel Standing × 5",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "ab wheel standing", count: 5),
            primary: [.core, .shoulders], secondary: [.lats]
        ),
        .simple(
            id: "cl.dragon-flag-negative",
            title: "Dragon Flag Negative × 3",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "dragon flag negative", count: 3),
            prereqs: [PrerequisiteGroup(["cl.hanging-leg-raise", "cal.l-sit-20"])],
            primary: [.core], secondary: [.lats, .glutes]
        ),
        .simple(
            id: "cl.dragon-flag",
            title: "Dragon Flag × 5",
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
            timeline: "6-18 months from leg raises."
        ),
        .simple(
            id: "cl.tuck-front-lever",
            title: "Tuck Front Lever 10s",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "tuck front lever", seconds: 10),
            prereqs: [PrerequisiteGroup(["pp.10-pullups", "cl.hanging-leg-raise"])],
            equipment: [.pullupBar],
            primary: [.lats, .core]
        ),
        .simple(
            id: "cl.straddle-front-lever",
            title: "Straddle Front Lever 5s",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "straddle front lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.tuck-front-lever")],
            equipment: [.pullupBar],
            primary: [.lats, .core]
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
            timeline: "1-3 years from tuck front lever."
        ),
        .simple(
            id: "cl.full-back-lever",
            title: "Full Back Lever",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "back lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.tuck-front-lever")],
            equipment: [.pullupBar, .gymnasticRings],
            primary: [.shoulders, .chest, .core]
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
            timeline: "5-10+ years. Fewer than 50 humans hold it cleanly."
        ),

        // ────────────────────────────────────────────────────────────────
        // CONDITIONING (co) — carries, grip, capacity
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "co.bw-farmer-carry",
            title: "BW Farmer Carry 60s",
            cluster: .conditioning, tier: 2, type: .skill,
            target: .carry(exercise: "farmer carry", seconds: 60, load: "bw"),
            prereqs: [PrerequisiteGroup("hl.bw-deadlift")],
            equipment: [.dumbbells, .kettlebell],
            primary: [.forearms, .traps, .core], secondary: [.legs]
        ),
        .simple(
            id: "co.1.5x-farmer-carry",
            title: "1.5× BW Farmer Carry 60s",
            cluster: .conditioning, tier: 4, type: .skill,
            target: .carry(exercise: "farmer carry", seconds: 60, load: "1.5x bw"),
            prereqs: [PrerequisiteGroup(["co.bw-farmer-carry", "hl.1.5x-deadlift"])],
            equipment: [.dumbbells, .kettlebell],
            primary: [.forearms, .traps, .core]
        ),
        .simple(
            id: "co.dead-hang-45",
            title: "Dead Hang 45s",
            cluster: .conditioning, tier: 2, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 45),
            prereqs: [PrerequisiteGroup("pp.dead-hang-30")],
            equipment: [.pullupBar],
            primary: [.forearms, .lats]
        ),
        .simple(
            id: "co.dead-hang-60",
            title: "Dead Hang 60s",
            cluster: .conditioning, tier: 3, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 60),
            prereqs: [PrerequisiteGroup("co.dead-hang-45")],
            equipment: [.pullupBar],
            primary: [.forearms, .lats]
        ),
        .simple(
            id: "co.sled-push",
            title: "Sled Push 2× BW 30s",
            cluster: .conditioning, tier: 3, type: .skill,
            target: .carry(exercise: "sled push", seconds: 30, load: "2x bw"),
            prereqs: [PrerequisiteGroup("hl.bw-back-squat")],
            equipment: [.sled],
            primary: [.legs, .glutes]
        ),
        .simple(
            id: "co.400m-row",
            title: "400m Row Sub-1:30",
            cluster: .conditioning, tier: 3, type: .skill,
            target: .steps(exercise: "row 400m", count: 1),
            prereqs: [PrerequisiteGroup("co.bw-farmer-carry")],
            equipment: [.rower],
            primary: [.back, .legs], secondary: [.arms]
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
