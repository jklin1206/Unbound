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
    static let shared: SkillGraph = {
        // Apply the Phase 2h sub-chapter map on top of the raw content
        // declarations. Keeping the assignments in one table (rather than
        // threading `subChapter:` through every .simple call) makes it
        // trivial to audit what's in which chapter and to rename a chapter
        // without touching 80+ lines.
        let enriched: [SkillNode] = Self.v3Nodes
            .filter { $0.cluster != .conditioning }
            .map { node in
                var copy = node
                // Stamp tier criteria from the cluster-specific authoring table.
                copy.tierCriteria = Self.tierCriteriaTable(for: node.id)[node.id] ?? [:]
                if let chapter = SkillSubChapterMap.chapter(for: node.id) {
                    copy.subChapter = chapter
                }
                return copy
            }
        return SkillGraph(nodes: enriched)
    }()

    /// Routes a skill id to its cluster's tier-criteria table by prefix.
    /// Empty dict for unknown prefixes — SkillTreeCoverageGateTests catches drift.
    private static func tierCriteriaTable(for skillId: String) -> [String: [SkillTier: TierCriterion]] {
        let prefix = String(skillId.prefix(while: { $0 != "." }))
        switch prefix {
        case "cal":  return CalSkillTiers.table
        case "cl":   return ClSkillTiers.table
        case "co":   return CoSkillTiers.table
        case "hs":   return HsSkillTiers.table
        case "ld":   return LdSkillTiers.table
        case "oah":  return OahSkillTiers.table
        case "pl":   return PlSkillTiers.table
        case "pp":   return PpSkillTiers.table
        default:     return [:]
        }
    }
}

// MARK: - Phase 2h sub-chapter map
//
// Every non-mythic node is assigned a short, anime/gym-neutral chapter
// name scoped to its owning cluster. Mythic nodes are intentionally
// chapter-less: they render in the MYTHIC section below the tree and
// carry their own "MYTHIC" chip — a chapter label would be noise.
//
// Names are our own (never lifted from the "Muscle Up Summit / Pull Up
// Dungeon" inspiration infographic) and steer clear of character names,
// any anime IP, and the app's archetype vocabulary.

enum SkillSubChapterMap {
    static func chapter(for nodeId: String) -> String? { map[nodeId] }

    static let map: [String: String] = [
        // ──────────────────────────────────────────────────────────────
        // PULL (pp) — four paths: grip, the pull, muscle-up crossover,
        // then the solo-arm finale. Canonical Pull Up Dungeon + Muscle
        // Up Summit + Levers University hierarchy.
        // ──────────────────────────────────────────────────────────────
        "pp.dead-hang":            "The Grip",

        "pp.pullup":               "Ascent",
        "pp.strict-pullup":        "Ascent",
        "pp.archer-pullup":        "Ascent",
        "pp.weighted-pullup":      "Ascent",
        "pp.chin-up":              "Ascent",
        "pp.strict-chin-up":       "Ascent",
        "pp.weighted-chin-up":     "Ascent",
        "pp.l-sit-chin-up":        "Ascent",
        "pp.wide-pullup":          "Ascent",
        "pp.oap-negative":         "Solo Arm",
        "pp.heighted-chin-up":     "Solo Arm",

        "pp.muscle-up":            "Crossover",
        "pp.ring-muscle-up":       "Crossover",
        "pp.clapping-pullup":      "Crossover",
        "pp.explosive-pullup":     "Crossover",
        // pp.strict-muscle-up is mythic (T8, .s) — chapter-less.

        // pp.one-arm-pullup + pp.one-arm-chin-up are mythic (T8, .s) — chapter-less.

        // Row family — distinct pull-pattern progression at the base
        // of the Pull axis.
        "pp.incline-row":          "The Row",
        "pp.row":                  "The Row",
        "pp.decline-row":          "The Row",
        "pp.one-arm-row":          "The Row",
        "pp.tuck-row":             "The Row",
        "pp.straddle-row":         "The Row",
        "pp.tuck-front-lever-pullup": "The Row",

        // ──────────────────────────────────────────────────────────────
        // PUSH / CALISTHENIC CONTROL (cal) — pressing + ring holds.
        // ──────────────────────────────────────────────────────────────
        "cal.pushup":              "Ground Work",
        "cal.diamond-pushup":      "Ground Work",
        "cal.incline-pushup":      "Ground Work",
        "cal.decline-pushup":      "Ground Work",
        "cal.sphinx-pushup":       "Vertical Press",
        "cal.archer-pushup":       "Ground Work",
        "cal.one-arm-pushup":      "Ground Work",
        "cal.explosive-pushup":    "Ground Work",
        "cal.clapping-pushup":     "Ground Work",
        "cal.pike-pushup":         "Vertical Press",
        "cal.elevated-pike-pushup": "Vertical Press",
        "cal.floating-pike-pushup": "Vertical Press",
        "cal.pseudo-planche-pushup": "Lean Path",
        "cal.tuck-planche-pushup": "Lean Path",
        "cal.handstand-pushup":    "Vertical Press",
        // cal.ninety-degree-pushup + cal.clapping-handstand-pushup are mythic/keystone — chapter-less.

        "cal.5-dips":              "The Dip",
        "cal.ring-dip":            "The Dip",
        "cal.bench-dip":           "The Dip",

        "cal.plank-30":            "Lock-In",
        "cal.l-sit-10":            "Lock-In",

        "cal.bent-arm-press":      "Ground Work",

        // Ring family — pass-throughs in the Pull tree.
        "cl.skin-the-cat":         "Ring King",
        "cl.german-hang":          "Ring King",
        "cl.three-sixty-pulls":    "Ring King",

        // ──────────────────────────────────────────────────────────────
        // LEGS (ld) — squat base → unilateral bridge → pistol chain →
        // a one-off strength branch.
        // ──────────────────────────────────────────────────────────────
        "ld.goblet-20":            "Foundation",
        "ld.step-up":              "Foundation",
        "ld.deep-squat":           "Foundation",
        "ld.glute-bridge":         "Foundation",
        "ld.calf-raise":           "Foundation",

        "ld.split-squat":          "Unilateral",
        "ld.bulgarian-split-squat": "Unilateral",
        "ld.weighted-split-squat": "Unilateral",
        "ld.weighted-bss":         "Unilateral",

        "ld.shrimp-squat":         "Pistol Path",
        "ld.pistol-squat":         "Pistol Path",
        "ld.weighted-pistol":      "Pistol Path",
        "ld.weighted-sl-calf":     "Pistol Path",
        "ld.sissy-squat":          "Pistol Path",
        "ld.leg-extensions":       "Pistol Path",

        "ld.box-jump":             "Power",
        "ld.jumping-squat":        "Power",

        "ld.fire-hydrant":         "Glute Work",
        "ld.single-leg-glute-bridge": "Glute Work",
        "ld.flying-kickback":      "Glute Work",

        "ld.advancing-nordic-curl": "Hamstring Forge",
        "ld.nordic-hip-hinge":     "Hamstring Forge",
        "ld.nordic-curl":          "Hamstring Forge",
        // ld.floor-to-ceiling-squat is mythic — chapter-less.

        // ──────────────────────────────────────────────────────────────
        // CORE (cl) — hollow → raised / hanging → flag. Pull-owned lever
        // families still keep their `cl.*` ids so existing progress survives.
        // ──────────────────────────────────────────────────────────────
        "cl.hollow-body-30":       "The Spine",
        "cl.crunch":               "The Spine",
        "cl.reverse-crunch":       "The Spine",
        "cl.superman-plank":       "The Spine",
        "cl.extended-plank":       "The Spine",
        "cl.levitation-crunch":    "The Spine",
        "cl.bird-dog-plank":       "The Spine",

        "cl.knee-raise":           "Raised Work",
        "cl.leg-raise":            "Raised Work",
        "cl.hanging-knee-raise":   "Raised Work",
        "cl.hanging-leg-raise":    "Raised Work",
        "cl.toes-to-bar":          "Raised Work",
        "cl.knee-ab-rollout":      "Rollout Path",
        "cl.standing-ab-rollout":  "Rollout Path",
        "cl.inverted-situp":       "Raised Work",
        "cl.decline-situp":        "Raised Work",
        "cl.semi-straddle-l-sit":  "Raised Work",
        "cl.v-sit":                "Raised Work",
        "cl.vertical-l-sit":       "Raised Work",
        "cl.straddle-l-sit":       "Raised Work",

        "cl.dragon-flag":          "Flag Path",
        "cl.dragon-flag-hip-raise": "Flag Path",

        "cl.tuck-front-lever":     "Front Lever",
        "cl.straddle-front-lever": "Front Lever",
        "cl.full-front-lever":     "Front Lever",

        "cl.straddle-back-lever":  "Back Lever",
        "cl.full-back-lever":      "Back Lever",

        // ──────────────────────────────────────────────────────────────
        // HANDSTAND — inversion balance, press entries, and one-arm work.
        // ──────────────────────────────────────────────────────────────
        "hs.wall-plank":           "Wall Path",
        "hs.wall-handstand-30":    "Wall Path",
        "hs.headstand":            "Wall Path",
        "hs.wall-supported-oah":   "Wall Path",

        "hs.freestanding-hs-30":   "Freestanding",
        "hs.tuck-handstand":       "Freestanding",
        "hs.tuck-press":           "Freestanding",
        "hs.straddle-press":       "Freestanding",
        "hs.press-to-handstand":   "Freestanding",

        // hspu — Handstand Push-Up cluster collapsed into Push tree (cal.handstand-pushup).
        // No remaining nodes ship in `.handstandPushup`; cluster kept in the enum for legacy compat.

        // oah — One-Arm Handstand. The OAH 5s entry is mythic (S-tier
        // keystone of the cluster); the Full One-Arm Handstand mythic
        // sits above it. Neither bears a chapter label.
        // (oah.one-arm-handstand-5s + oah.full-one-arm-handstand are both mythic.)

        // ──────────────────────────────────────────────────────────────
        // PLANCHE (pl)
        // ──────────────────────────────────────────────────────────────
        "hs.crow-pose":             "Foundation",
        "hs.crane-pose":            "Arm Balance",
        "hs.flying-crow":           "Arm Balance",
        "hs.elbow-lever":           "Arm Balance",
        "hs.one-arm-elbow-lever":   "Arm Balance",
        "pl.tuck-planche":          "Tuck Path",
        "pl.bent-arm-planche":      "Tuck Path",
        "pl.half-lay-planche":      "Float",
        "pl.straddle-planche":      "Float",
        "pl.full-planche":          "Float",

        // ──────────────────────────────────────────────────────────────
        // ENDURANCE / CONDITIONING (co)
        // ──────────────────────────────────────────────────────────────
        "co.dead-hang-45":         "Grip Engine",
        "co.dead-hang-60":         "Grip Engine",

        "co.mile-sub-7":           "Distance Run",
        "co.5k-sub-22":            "Distance Run",

        "co.400m-row":             "Engine",
        "co.assault-bike-30":      "Engine",

        "co.bw-farmer-carry":      "Loaded Carry",
        "co.1.5x-farmer-carry":    "Loaded Carry",
        "co.2x-farmer-carry":      "Loaded Carry",
        "co.sled-push":            "Loaded Carry",
    ]
}

// MARK: - All v3 nodes

extension SkillGraph {
    fileprivate static let v3Nodes: [SkillNode] = [
        // ────────────────────────────────────────────────────────────────
        // LEG DOMINANCE (ld) — single-leg / variation squat chain
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "ld.goblet-20",
            title: "Half Squat",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "half squat", count: 15),
            primary: [.legs, .glutes, .core],
            subtitle: "The squat on-ramp.",
            description: "Half-depth bodyweight squats — thighs to roughly parallel, knees track over toes, chest up. The squat pattern entry point every leg skill grows from.",
            formCues: [
                "Feet shoulder-width, toes turned out ~15°",
                "Drop until thighs are parallel to floor",
                "Knees track over the second/third toe; forward travel is fine if heels stay rooted",
                "Chest up, eyes forward throughout",
                "Drive through the heels to stand"
            ],
            commonMistakes: [
                "Heels lifting — ankle mobility or stance too narrow",
                "Knees caving inward on the concentric",
                "Bouncing out of the bottom"
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
            timeline: "1-3 weeks from half squat."
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
            id: "ld.pistol-squat",
            title: "Pistol Squat",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "pistol squat", count: 5),
            prereqs: [PrerequisiteGroup("ld.deep-squat")],
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
            prereqs: [PrerequisiteGroup("pp.weighted-pullup")],
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
            prereqs: [PrerequisiteGroup("pp.strict-pullup")],
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
            prereqs: [PrerequisiteGroup("pp.archer-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core, .forearms],
            subtitle: "Lower yourself with one arm — the bridge to the full one-arm.",
            description: "3 strict 5s eccentric one-arm pull-up negatives per side. Slow lower from the top, no jerk.",
            formCues: [
                "Start at chin-over-bar with one arm",
                "Lower under control — 5s minimum",
                "No jerking or dropping",
                "Free arm across chest, no assist"
            ],
            commonMistakes: [
                "Dropping out of the negative",
                "Free hand assisting",
                "Cutting eccentric short of full extension"
            ],
            timeline: "6-12 months of dedicated pull work."
        ),
        .simple(
            id: "pp.one-arm-pullup",
            title: "One-Arm Pull-Up",
            cluster: .pullingPower, tier: 8, type: .skill,
            target: .reps(exercise: "one-arm pullup", count: 1),
            prereqs: [PrerequisiteGroup("pp.oap-negative")],
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
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "muscle-up", count: 1),
            prereqs: [PrerequisiteGroup("pp.explosive-pullup")],
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
            id: "pp.ring-muscle-up",
            title: "Ring Muscle-Up",
            cluster: .pullingPower, tier: 7, type: .skill,
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
            isParallelToParent: true
        ),

        // ────────────────────────────────────────────────────────────────
        // CALISTHENIC CONTROL (cal) — pushups + planche + handstand + rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.plank-30",
            title: "Plank",
            cluster: .coreLever, tier: 1, type: .hold,
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
            title: "L-Sit",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.knee-raise")],
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
            id: "cal.pushup",
            title: "Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.incline-pushup")],
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
            id: "cal.5-dips",
            title: "Dip",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.bench-dip")],
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
            id: "cal.ring-dip",
            title: "Ring Dip",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "ring dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.5-dips")],
            isKeystone: true,
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
            timeline: "3-6 months from 5 bar dips."
        ),
        .simple(
            id: "cal.diamond-pushup",
            title: "Diamond Push-Up",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "diamond pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pushup")],
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
            timeline: "2-6 weeks from the strict push-up."
        ),
        .simple(
            id: "cal.pseudo-planche-pushup",
            title: "Pseudo-Planche Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "pseudo-planche pushup", count: 5),
            prereqs: [PrerequisiteGroup("cal.decline-pushup")],
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
            id: "pl.tuck-planche",
            title: "Tuck Planche",
            cluster: .planche, tier: 5, type: .hold,
            target: .hold(exercise: "tuck planche", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.crane-pose")],
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
            timeline: "3-9 months from crane pose."
        ),
        .simple(
            id: "cal.tuck-planche-pushup",
            title: "Tuck Planche Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "tuck planche pushup", count: 3),
            prereqs: [PrerequisiteGroup("cal.pseudo-planche-pushup")],
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
            id: "pl.straddle-planche",
            title: "Straddle Planche",
            cluster: .planche, tier: 6, type: .hold,
            target: .hold(exercise: "straddle planche", seconds: 5),
            prereqs: [PrerequisiteGroup("pl.tuck-planche")],
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
            id: "pl.full-planche",
            title: "Full Planche",
            cluster: .planche, tier: 7, type: .hold,
            target: .hold(exercise: "full planche", seconds: 5),
            prereqs: [PrerequisiteGroup("pl.half-lay-planche")],
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
            id: "cal.handstand-pushup",
            title: "Handstand Push-Up",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "handstand pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.elevated-pike-pushup")],
            isKeystone: true,
            primary: [.shoulders, .arms], secondary: [.core, .chest],
            subtitle: "Pressing your bodyweight from upside down.",
            description: "One strict handstand push-up — wall-supported acceptable for the early levels, freestanding for mastery. Forehead lightly contacts ground at the bottom, arms lock at the top.",
            formCues: [
                "Wall-supported is fine for L1-L3, freestanding for L4-L5",
                "Hands shoulder-width, fingers spread for balance",
                "Forehead touches floor lightly at the bottom",
                "Drive evenly through both palms — no favored side",
                "Lockout at the top with ribs tucked, no banana arch"
            ],
            commonMistakes: [
                "Kipping legs off the wall to cheat the press",
                "Partial lockout at the top",
                "Falling out of balance instead of bailing safely"
            ],
            timeline: "2-4 years from bent arm press."
        ),
        .simple(
            id: "cal.ninety-degree-pushup",
            title: "Ninety-Degree Push-Up",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "90 degree pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.handstand-pushup")],
            equipment: [.parallettes],
            primary: [.shoulders, .arms, .chest], secondary: [.core],
            subtitle: "Handstand into a bent-arm planche line.",
            description: "Start from a controlled handstand, lean the shoulders forward, lower as one piece into a bent-arm horizontal line, then press back to handstand without kicking or piking.",
            formCues: [
                "Start from a stacked handstand with shoulders tall",
                "Lean forward as elbows bend — the shoulder shift is part of the skill",
                "Body reaches a horizontal 90-degree bent-arm line",
                "Press back to handstand without kicking the legs"
            ],
            commonMistakes: [
                "Treating it like only a deeper handstand pushup",
                "Elbows flaring out to find leverage",
                "Piking hips or kicking back to handstand"
            ],
            timeline: "5+ years of vertical pressing work.",
            isParallelToParent: true
        ),
        .simple(
            id: "cal.clapping-handstand-pushup",
            title: "Clapping Handstand Push-Up",
            cluster: .calisthenicControl, tier: 7, type: .skill,
            target: .reps(exercise: "clapping handstand pushup", count: 1),
            prereqs: [PrerequisiteGroup("cal.ninety-degree-pushup")],
            isMythic: true,
            primary: [.shoulders, .arms], secondary: [.core, .chest],
            subtitle: "Push the floor away hard enough to clap upside down.",
            description: "One freestanding handstand push-up explosive enough that the hands leave the floor and clap before catching. Power-to-weight on a different planet.",
            formCues: [
                "Start from a stable freestanding handstand",
                "Descend with control to forehead-on-floor",
                "Drive explosively — hands fully leave the ground",
                "Clap once at the bottom of the airborne phase",
                "Catch with slightly bent elbows and rebalance"
            ],
            commonMistakes: [
                "Catching with locked arms — shoulder injury risk",
                "Fake clap that barely separates the hands",
                "Bailing instead of catching the rep"
            ],
            timeline: "Mostly aspirational. 7+ years past first HSPU."
        ),

        // ────────────────────────────────────────────────────────────────
        // HANDSTAND (hs) — wrists, wall holds, freestanding, walks
        // Handstand now owns the inversion path directly on the map.
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cal.pike-pushup",
            title: "Pike Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "pike pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.diamond-pushup")],
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
            timeline: "3–8 weeks from diamond pushup."
        ),
        .simple(
            id: "cal.elevated-pike-pushup",
            title: "Elevated Pike Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "elevated pike pushup", count: 10),
            prereqs: [PrerequisiteGroup("cal.pike-pushup")],
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
            timeline: "4–8 weeks after pike pushup × 10."
        ),
        .simple(
            id: "hs.wall-handstand-30",
            title: "Wall Handstand",
            cluster: .handstand, tier: 2, type: .hold,
            target: .hold(exercise: "wall handstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wall-plank")],
            equipment: [.bodyweight],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Build the line before you chase balance.",
            description: "Chest-to-wall handstand hold with hands close enough to stack wrists, shoulders, hips, and ankles. The wall removes the balance fight so you can build wrist tolerance, locked elbows, active shoulders, hollow tension, and calm breathing upside down.",
            formCues: [
                "Walk in chest-to-wall, not banana-back first",
                "Hands shoulder-width, fingers spread and gripping the floor",
                "Push tall through locked elbows until shoulders cover the ears",
                "Ribs down, glutes tight, toes pointed lightly into the wall",
                "Breathe for the whole hold; do not brace by holding air"
            ],
            commonMistakes: [
                "Stopping too far from the wall and arching into a banana",
                "Soft elbows or shrugged, collapsed shoulders",
                "Counting time after the ribs flare or the low back dumps",
                "Letting the head crane forward instead of staying between the arms"
            ],
            timeline: "4-12 weeks from wall plank if wrists and shoulders are trained consistently."
        ),
        .simple(
            id: "hs.freestanding-hs-30",
            title: "Handstand",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "freestanding handstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-30")],
            isKeystone: true,
            primary: [.shoulders, .core], secondary: [.forearms],
            subtitle: "Balance is the skill.",
            description: "Freestanding handstand with a stacked body line, active shoulders, quiet legs, and balance corrected through the hands instead of panic steps. The 30-second standard means the hold has stopped being a lucky save and has become a shape you can breathe inside.",
            formCues: [
                "Kick only hard enough to arrive stacked, not crash past vertical",
                "Hands shoulder-width; fingers spread and ready to brake",
                "Push tall through locked elbows so shoulders stay by the ears",
                "Ribs tucked, glutes squeezed, legs together in a hollow line",
                "Use fingertips for overbalance and heel-of-hand pressure for underbalance"
            ],
            commonMistakes: [
                "Chasing seconds after the body bends into a banana",
                "Kicking so hard every attempt becomes a bailout drill",
                "Looking far ahead on the floor and closing the shoulders",
                "Trying to balance with shoulder swings instead of hand pressure",
                "Holding breath to fake stability"
            ],
            timeline: "6-24 months from a clean 60s wall handstand for most consistent athletes; faster if shoulder mobility and wrist tolerance are already built."
        ),
        .simple(
            id: "oah.one-arm-handstand-5s",
            title: "One-Arm Handstand",
            cluster: .oneArmHandstand, tier: 6, type: .hold,
            target: .hold(exercise: "one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.wall-supported-oah")],
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
            timeline: "3-7 years of daily handstand work."
        ),
        .simple(
            id: "oah.full-one-arm-handstand",
            title: "Full One-Arm Handstand",
            cluster: .oneArmHandstand, tier: 7, type: .hold,
            target: .hold(exercise: "full one arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("oah.one-arm-handstand-5s")],
            isMythic: true,
            primary: [.shoulders, .core],
            subtitle: "Free balance on one hand.",
            description: "5+ seconds freestanding on one arm — body straight, vertical line through wrist, no wall contact. Years of practice.",
            formCues: [
                "Body stacked over the support hand",
                "Free shoulder pulled up away from floor",
                "Long line from wrist through heels",
                "Breathe through the hold"
            ],
            timeline: "5-10+ years of daily handstand work. Aspirational."
        ),


        // ────────────────────────────────────────────────────────────────
        // CORE & LEVER (cl) — dynamic core + levers
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.hollow-body-30",
            title: "Hollow Body",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "hollow body hold", seconds: 30),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
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
            timeline: "2-8 weeks from first dead hang."
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
            id: "cl.straddle-back-lever",
            title: "Straddle Back Lever",
            cluster: .pullingPower, tier: 5, type: .hold,
            target: .hold(exercise: "straddle back lever", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.skin-the-cat")],
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
            timeline: "2-6 months from BW deadlift."
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
            timeline: "1-3 years from BW farmer carry."
        ),
        .simple(
            id: "co.dead-hang-45",
            title: "Long Dead Hang",
            cluster: .conditioning, tier: 2, type: .hold,
            target: .hold(exercise: "dead hang", seconds: 45),
            prereqs: [PrerequisiteGroup("pp.dead-hang")],
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
            timeline: "2-6 weeks from dead hang 30s."
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
            timeline: "1-3 months from 45s."
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
            timeline: "Develops naturally alongside squat programming."
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
            timeline: "2-6 months of rowing practice."
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
            timeline: "2-4 months of 2-3 runs per week from untrained."
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
            timeline: "3-9 months from sub-7 mile."
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
            timeline: "2-4 years from 1.5× farmer carry."
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
            timeline: "2-6 months of bike intervals."
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
            description: "Strict pullups with hands set well outside shoulder width. Lat-dominant — emphasizes back width over arm pull.",
            formCues: [
                "Grip 1.5× shoulder width, palms facing away",
                "Drive elbows DOWN to the ribs",
                "Chest to the bar, not chin",
                "Full dead hang each rep"
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
            isMythic: true,
            primary: [.chest, .arms, .shoulders], secondary: [.core],
            subtitle: "Three claps. One rep. No excuses.",
            description: "One clean pushup where the airtime is so violent you fit three claps before landing. Famed for being essentially impossible without elite power-to-weight.",
            formCues: [
                "Explode from a rigid plank",
                "Clap three times at chest level mid-air",
                "Catch with soft elbows, reset in plank",
                "Only program once clapping pushup is trivial"
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
                "Forward lean on the concentric"
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
                "Front knee tracking past toes",
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
            title: "Leg Extensions",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "leg extensions", count: 15),
            prereqs: [PrerequisiteGroup("ld.deep-squat")],
            primary: [.legs], secondary: [.core],
            subtitle: "Quad isolation.",
            description: "15 strict bodyweight or banded leg extensions — knee stays still, lower leg moves through full ROM, controlled descent.",
            formCues: [
                "Knee stays put",
                "Full extension at top",
                "Slow eccentric (3s)",
                "No swinging"
            ],
            commonMistakes: [
                "Knee drifting during the rep",
                "Bouncing out of the bottom",
                "Cutting ROM short at the top"
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
            isMythic: true,
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

        // ────────────────────────────────────────────────────────────────
        // CORE & LEVERS ADDITIONS — crunch variants, plank variants, rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.crunch",
            title: "Crunch",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "crunch", count: 20),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.core],
            subtitle: "Starting point for ab-specific work.",
            description: "20 strict crunches — lying on your back, knees bent, curl shoulder blades off the floor, touch fingertips toward knees. Short-range, ab-isolated.",
            formCues: [
                "Lower back pressed to floor throughout",
                "Chin tucked, eyes on the ceiling",
                "Lift shoulder blades off the floor — no more",
                "Hands light on head, don't pull neck"
            ],
            commonMistakes: [
                "Yanking on the neck to sit up",
                "Sitting all the way up — that's a sit-up, not a crunch",
                "Feet lifting off the floor"
            ],
            timeline: "Immediate."
        ),
        .simple(
            id: "cl.reverse-crunch",
            title: "Reverse Crunch",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "reverse crunch", count: 15),
            prereqs: [PrerequisiteGroup("cl.crunch")],
            primary: [.core], secondary: [.legs],
            subtitle: "Lower abs emphasis.",
            description: "15 reverse crunches — lie on back, curl hips off the floor by pulling knees toward chest. Targets lower ab engagement the standard crunch misses.",
            formCues: [
                "Start with knees stacked over hips",
                "Curl hips off the floor, don't just swing legs",
                "Lower slowly, no momentum",
                "Shoulders stay down, don't shrug"
            ],
            commonMistakes: [
                "Swinging the legs instead of curling the hips",
                "Using momentum from the eccentric",
                "Lumbar arching at the bottom"
            ],
            timeline: "1-2 weeks from crunches."
        ),
        .simple(
            id: "cl.superman-plank",
            title: "Superman Plank",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "superman plank", seconds: 15),
            prereqs: [PrerequisiteGroup("cl.extended-plank")],
            primary: [.core, .shoulders], secondary: [.back, .glutes],
            subtitle: "Plank with limbs extended.",
            description: "15-second plank with one arm extended forward and the opposite leg extended back. Hold, switch. Anti-rotation challenge.",
            formCues: [
                "Start in a rigid plank",
                "Extend opposite arm and leg without hips twisting",
                "Hold — don't lose the plank line",
                "Return slowly, switch sides"
            ],
            commonMistakes: [
                "Hips rotating as the limbs extend",
                "Arm and leg on the same side — cancels the anti-rotation",
                "Dropping the extended limb to the floor"
            ],
            timeline: "1-4 weeks from 30s plank."
        ),
        .simple(
            id: "cl.extended-plank",
            title: "Extended Plank",
            cluster: .coreLever, tier: 3, type: .hold,
            target: .hold(exercise: "extended plank", seconds: 15),
            prereqs: [PrerequisiteGroup("cl.bird-dog-plank")],
            primary: [.core, .shoulders], secondary: [.arms],
            subtitle: "Hands way out front of the shoulders.",
            description: "15-second plank with hands reached forward past the shoulders — long lever demands more core tension than a standard plank.",
            formCues: [
                "Hands reach 6-12 inches past shoulders",
                "Body rigid as plank — no sag, no pike",
                "Shoulders stay packed down",
                "Gaze at the floor, neck neutral"
            ],
            commonMistakes: [
                "Reaching hands too far too soon",
                "Hip sag as the lever gets long",
                "Shrugged shoulders under the load"
            ],
            timeline: "2-4 weeks from plank 30s."
        ),
        .simple(
            id: "cl.knee-ab-rollout",
            title: "Kneeling Ab Rollout",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "ab wheel kneeling", count: 8),
            prereqs: [PrerequisiteGroup("cl.extended-plank")],
            primary: [.core, .shoulders], secondary: [.lats],
            subtitle: "Ab wheel on ramp.",
            description: "8 kneeling ab wheel rollouts. Roll out as far as core can control, roll back. Gateway to the standing rollout.",
            formCues: [
                "Kneel with hands on the wheel under shoulders",
                "Roll out keeping a hollow body",
                "Pause at the end range before rolling back",
                "Control both directions"
            ],
            commonMistakes: [
                "Lumbar sag at the end range",
                "Rolling too far too soon (injury risk)",
                "Holding breath instead of breathing"
            ],
            timeline: "1-4 weeks from solid plank."
        ),
        .simple(
            id: "cl.levitation-crunch",
            title: "Levitation Crunch",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "levitation crunch", count: 8),
            prereqs: [PrerequisiteGroup("cl.crunch")],
            primary: [.core], secondary: [.glutes],
            subtitle: "Lift the whole body off the floor.",
            description: "8 reps — lying on back, knees bent, curl hips and upper back off the floor simultaneously, only the mid-back stays in contact. Brutal on the rectus abdominis.",
            formCues: [
                "Curl both ends of the body toward the ceiling",
                "Only mid-back stays in contact",
                "Arms reach toward the knees",
                "Slow descent — no crashing down"
            ],
            commonMistakes: [
                "Yanking with the neck",
                "Using the arms to swing up",
                "Not fully levitating — partial ROM"
            ],
            timeline: "1-3 months from reverse crunch."
        ),
        .simple(
            id: "cl.inverted-situp",
            title: "Inverted Sit-Up",
            cluster: .coreLever, tier: 5, type: .skill,
            target: .reps(exercise: "inverted sit-up", count: 5),
            prereqs: [PrerequisiteGroup("cl.decline-situp")],
            equipment: [.pullupBar],
            primary: [.core, .lats], secondary: [.arms],
            subtitle: "Sit-up while hanging upside down.",
            description: "5 hanging sit-ups — hook legs over a pullup bar so you hang inverted, curl the torso toward the knees, return slowly. Demands real core strength.",
            formCues: [
                "Secure the legs over the bar before the first rep",
                "Curl the torso up, don't swing",
                "Touch knees or elbows",
                "Slow descent to avoid whipping the spine"
            ],
            commonMistakes: [
                "Swinging for momentum",
                "Legs slipping off the bar",
                "Partial ROM"
            ],
            timeline: "2-6 months from hanging leg raise."
        ),
        .simple(
            id: "cl.skin-the-cat",
            title: "Skin the Cat",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "skin the cat", count: 3),
            prereqs: [PrerequisiteGroup("cl.german-hang")],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .core, .lats], secondary: [.arms],
            subtitle: "Rings pass-through. Shoulder opener.",
            description: "Controlled ring pass-through from hang to inverted hang to German hang and back. The rep proves shoulder extension tolerance, straight-arm control, and a calm reverse path.",
            formCues: [
                "Start from a quiet hang with straight arms and rings still",
                "Tuck or pike the legs overhead without yanking the elbows",
                "Pass through slowly until the shoulders open into German hang",
                "Pause only in a pain-free range, then reverse the same path",
                "Keep ribs tucked so the pass-through is controlled by shoulders and core"
            ],
            commonMistakes: [
                "Dropping into the german hang — shoulder shock",
                "Bent arms during the pass-through",
                "Skipping warm-up — shoulders need prep",
                "Going deeper than can be reversed under control"
            ],
            timeline: "2-6 months from german hang."
        ),
        .simple(
            id: "cl.german-hang",
            title: "German Hang",
            cluster: .pullingPower, tier: 3, type: .hold,
            target: .hold(exercise: "german hang", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.tuck-front-lever")],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .chest], secondary: [.core, .arms],
            subtitle: "The rings position only mobile shoulders own.",
            description: "Pain-free hold at the bottom of a skin-the-cat path. The arms are behind the body, shoulders are open, rings stay quiet, and the athlete can exit without panic.",
            formCues: [
                "Enter slowly through an assisted or controlled skin-the-cat path",
                "Keep arms straight while the shoulders open behind the torso",
                "Let the chest open without dumping into sharp anterior shoulder pain",
                "Breathe calmly; the position should feel loaded, not panicked",
                "Exit the same way you entered before the shoulders lose control"
            ],
            commonMistakes: [
                "Attempting without shoulder warm-up",
                "Bent arms — wrong skill, injury risk",
                "Holding through shoulder pain",
                "Dropping too deep because the rings are set too high"
            ],
            timeline: "3-9 months from tuck front lever.",
            isParallelToParent: true
        ),
        .simple(
            id: "cl.three-sixty-pulls",
            title: "360-Degree Pulls",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "360-degree pulls", count: 1),
            prereqs: [PrerequisiteGroup("cl.skin-the-cat")],
            equipment: [.gymnasticRings, .pullupBar],
            primary: [.lats, .arms, .core], secondary: [.back, .shoulders],
            subtitle: "Pull, release, rotate 360°, re-grip, pull again.",
            description: "From a pullup, release with enough height to rotate 360° in the air before re-catching the bar, then continue into the next pullup. Power plus spatial control.",
            formCues: [
                "Only train over a safe mat with a spotter or controlled progression",
                "Load from an active hang and pull explosively above bar height",
                "Tuck hard once airborne to speed rotation",
                "Spot the bar early and reach with prepared shoulders",
                "Absorb the re-catch with active lats; do not slam into a dead hang"
            ],
            commonMistakes: [
                "Missing the re-catch and dropping",
                "Under-rotating and landing sideways",
                "Shrugged shoulders on the re-catch",
                "Trying it without first owning high pulls, release drills, and safe landing practice"
            ],
            timeline: "5+ years of dedicated explosive pulling. Very rare."
        ),

        // ────────────────────────────────────────────────────────────────
        // HANDBALANCE ADDITIONS — poses, elbow lever, press progressions
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "hs.headstand",
            title: "Headstand",
            cluster: .handstand, tier: 2, type: .hold,
            target: .hold(exercise: "headstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wall-plank")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "The easier inversion.",
            description: "30-second headstand — tripod on hands and head against a wall, body stacked vertical. First real taste of inverted balance.",
            formCues: [
                "Tripod: hands and head form a triangle",
                "Bodyweight distributed across all three contact points",
                "Body stacked vertical against or near a wall",
                "Breathe through the hold"
            ],
            commonMistakes: [
                "All weight on the head — neck strain",
                "Arching the spine to stay up",
                "Kicking up too hard against the wall"
            ],
            timeline: "1-4 weeks from wall plank."
        ),
        .simple(
            id: "hs.tuck-handstand",
            title: "Tuck Handstand",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "tuck handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-30")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Freestanding on-ramp.",
            description: "5-second freestanding tuck handstand — balance on hands with knees pulled tight to chest. Easier lever than full handstand, teaches the balance.",
            formCues: [
                "Press into the floor through straight arms",
                "Knees tucked tight to chest, heels near glutes",
                "Balance with the fingers, not the shoulders",
                "Micro-adjust — don't try to stand statue still"
            ],
            commonMistakes: [
                "Losing the tuck to try to balance",
                "Bent arms when balance shifts",
                "Over-kicking into the position"
            ],
            timeline: "1-3 months from wall handstand."
        ),
        .simple(
            id: "hs.crow-pose",
            title: "Crow Pose",
            cluster: .planche, tier: 2, type: .hold,
            target: .hold(exercise: "crow pose", seconds: 15),
            prereqs: [PrerequisiteGroup("hs.wall-plank")],
            primary: [.shoulders, .arms, .core],
            subtitle: "Knees on the triceps. Balance on the hands.",
            description: "15-second crow pose — squat, plant hands, rest knees on the backs of the triceps, shift weight forward until feet leave the floor.",
            formCues: [
                "Hands shoulder-width, fingers spread wide",
                "Knees pin onto the triceps, not just touching",
                "Shift weight forward until feet float",
                "Gaze slightly ahead, not straight down"
            ],
            commonMistakes: [
                "Knees slipping off the triceps",
                "Keeping weight over the feet — won't float",
                "Tipping forward onto the head — yes, put a pillow down"
            ],
            timeline: "1-4 weeks from wall plank."
        ),
        .simple(
            id: "hs.crane-pose",
            title: "Crane Pose",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "crane pose", seconds: 10),
            prereqs: [PrerequisiteGroup("hs.crow-pose")],
            primary: [.shoulders, .arms, .core],
            subtitle: "Crow, but arms straight.",
            description: "10-second crane pose — same knees-on-triceps position as crow, but arms are fully locked out. Harder balance and a real strength challenge.",
            formCues: [
                "Enter from crow, slowly press arms straight",
                "Knees stay on triceps as the arms straighten",
                "Hips climb higher as arms lock",
                "Balance shifts — fingers press into the floor"
            ],
            commonMistakes: [
                "Losing the knee-tricep contact as arms straighten",
                "Bending arms as soon as balance shifts",
                "Hips dropping — arms not vertical"
            ],
            timeline: "1-3 months from crow pose."
        ),
        .simple(
            id: "hs.flying-crow",
            title: "Flying Crow Pose",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "flying crow", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.crow-pose")],
            primary: [.shoulders, .arms, .core],
            subtitle: "One leg extended straight back.",
            description: "5-second flying crow — from crane or crow, extend one leg straight back into the air. Full body engagement with a long lever fighting the balance.",
            formCues: [
                "Enter stable crane first",
                "Extend one leg straight back, toe pointed",
                "Press through fingers to counter the lever shift",
                "Keep the knee on the tricep of the bent leg"
            ],
            commonMistakes: [
                "Extending too fast — tips forward",
                "Leg drifting out to the side",
                "Losing knee-tricep contact on the bent leg"
            ],
            timeline: "3-9 months from crow."
        ),
        .simple(
            id: "hs.elbow-lever",
            title: "Elbow Lever",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "elbow lever", seconds: 10),
            prereqs: [PrerequisiteGroup("hs.crow-pose")],
            primary: [.shoulders, .core, .arms],
            subtitle: "Body horizontal, elbows into the hips.",
            description: "10-second elbow lever — hands plant on the floor, elbows drive into the ribs or hip crease, body extends horizontal. Parlor trick that builds serious core.",
            formCues: [
                "Hands shoulder-width, fingers spread wide",
                "Elbows dig into the iliac crest / hip bones",
                "Lean weight forward until legs lift",
                "Body rigid and horizontal"
            ],
            commonMistakes: [
                "Elbows not tucked into the hips — no support",
                "Legs sagging below horizontal",
                "Bent knees to cheat the lever"
            ],
            timeline: "2-8 weeks from crow pose."
        ),
        .simple(
            id: "hs.one-arm-elbow-lever",
            title: "One-Arm Elbow Lever",
            cluster: .planche, tier: 4, type: .hold,
            target: .hold(exercise: "one-arm elbow lever", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.elbow-lever")],
            primary: [.shoulders, .core, .arms],
            subtitle: "Same lever. Half the supports.",
            description: "5-second one-arm elbow lever. Same position as the two-arm version but supported by a single arm — the elbow of the working side presses into the hip crease.",
            formCues: [
                "Enter from a two-arm elbow lever, shift weight to one side",
                "Free arm extends straight out for balance",
                "Working elbow stays locked into the hip",
                "Shoulders stay square to the floor"
            ],
            commonMistakes: [
                "Free arm bracing on the floor",
                "Body rotating open as weight shifts",
                "Working arm collapsing"
            ],
            timeline: "6-18 months from elbow lever."
        ),
        .simple(
            id: "hs.tuck-press",
            title: "Tuck Press to Handstand",
            cluster: .handstand, tier: 5, type: .skill,
            target: .reps(exercise: "tuck press", count: 3),
            prereqs: [PrerequisiteGroup("hs.tuck-handstand")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Press up from tuck to handstand.",
            description: "3 tuck presses — from an L-sit or compressed tuck on the floor, press through straight arms to a tuck handstand without kipping.",
            formCues: [
                "Start compressed — chest close to thighs",
                "Arms straight throughout, no bending to cheat",
                "Hips climb through the straight arms",
                "Tuck stays tight until the handstand is achieved"
            ],
            commonMistakes: [
                "Kipping the legs for momentum",
                "Bent arms once weight shifts",
                "Losing the tuck as hips rise"
            ],
            timeline: "6-18 months from tuck handstand."
        ),
        .simple(
            id: "hs.straddle-press",
            title: "Straddle Press to Handstand",
            cluster: .handstand, tier: 6, type: .skill,
            target: .reps(exercise: "straddle press", count: 3),
            prereqs: [PrerequisiteGroup("hs.tuck-press")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Legs split. Straight arms all the way.",
            description: "3 straddle presses to handstand — from a straddle pike compression on the floor, press through straight arms and a split-leg shape up to handstand. Hamstring flexibility + pressing strength.",
            formCues: [
                "Start pike compressed, chest on thighs",
                "Arms straight throughout",
                "Legs stay wide in the straddle as hips rise",
                "Close the straddle only once handstand is held"
            ],
            commonMistakes: [
                "Bent arms as fatigue sets in",
                "Closing the straddle too early",
                "Hamstring flexibility limits not addressed in warm-up"
            ],
            timeline: "1-3 years from tuck press."
        ),
        .simple(
            id: "hs.press-to-handstand",
            title: "Press to Handstand",
            cluster: .handstand, tier: 7, type: .skill,
            target: .reps(exercise: "press to handstand", count: 1),
            prereqs: [PrerequisiteGroup("hs.straddle-press")],
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Legs glued. Straight up.",
            description: "One clean pike press to handstand — legs together, arms straight, press from floor pike to vertical handstand without momentum. Gymnastic standard.",
            formCues: [
                "Start pike, legs together, chest on thighs",
                "Arms straight, hands planted firm",
                "Hips rise first, legs follow",
                "No kip, no bent arm, no swing"
            ],
            commonMistakes: [
                "Swinging legs for momentum",
                "Bent arms once the hips rise",
                "Losing the pike shape — hips lead too early"
            ],
            timeline: "2-4 years from straddle press."
        ),

        // ────────────────────────────────────────────────────────────────
        // PLANCHE ADDITIONS — bent arm + half-lay + one-arm (mythic)
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pl.bent-arm-planche",
            title: "Bent Arm Planche",
            cluster: .planche, tier: 4, type: .hold,
            target: .hold(exercise: "bent arm planche", seconds: 3),
            prereqs: [PrerequisiteGroup("hs.elbow-lever")],
            equipment: [.parallettes],
            primary: [.shoulders, .chest, .core],
            subtitle: "Planche before the straight-arm demand.",
            description: "3-second bent arm planche — legs extended behind the body, arms bent at roughly 90°, body horizontal. Easier shoulder leverage than straight-arm but still brutal.",
            formCues: [
                "Arms bend to ~90°, elbows into the ribs",
                "Body horizontal, legs extended",
                "Shoulders protract hard",
                "Chest drives forward toward the floor"
            ],
            commonMistakes: [
                "Losing the horizontal line — hips drop",
                "Arms bending too much — turns into a pushup",
                "Not extending the legs fully"
            ],
            timeline: "6-18 months from elbow lever."
        ),
        .simple(
            id: "pl.half-lay-planche",
            title: "Half-Lay Planche",
            cluster: .planche, tier: 6, type: .hold,
            target: .hold(exercise: "half-lay planche", seconds: 3),
            prereqs: [PrerequisiteGroup("pl.straddle-planche")],
            equipment: [.parallettes],
            primary: [.shoulders, .core],
            subtitle: "Half-straddle. Half-closed.",
            description: "3-second half-lay planche — straddle planche with legs narrowed toward the full position. The bridge between straddle and full planche.",
            formCues: [
                "Start from rock-solid straddle planche",
                "Close the legs halfway toward parallel",
                "Hips stay at shoulder height",
                "Toes pointed, legs squeeze even at narrower angle"
            ],
            commonMistakes: [
                "Closing legs too fast — lever jumps",
                "Hip drop as the lever tightens",
                "Banana back"
            ],
            timeline: "6-18 months from straddle planche."
        ),

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
                "Full dead hang at the bottom each rep"
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
                "Body straight head-to-heels",
                "Free arm tucked or held out",
                "Pull elbow to ribs, no twist",
                "Squeeze shoulder blade at top"
            ],
            commonMistakes: [
                "Twisting torso to cheat",
                "Bent body instead of straight",
                "Partial ROM"
            ],
            timeline: "2-6 months from decline row.",
            isParallelToParent: true
        ),
        .simple(
            id: "pp.tuck-row",
            title: "Tuck Row",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "tuck row", count: 8),
            prereqs: [PrerequisiteGroup("pp.decline-row")],
            equipment: [.pullupBar],
            primary: [.back, .lats], secondary: [.arms, .core],
            subtitle: "The front-lever on-ramp.",
            description: "Inverted row with knees tucked tight to chest, body parallel to floor. 8 reps. Builds the lat-and-core coordination that every front lever progression depends on.",
            formCues: [
                "Knees pulled tight to chest throughout",
                "Body parallel to the floor — not angled",
                "Pull sternum to bar",
                "Full extension at the bottom before next rep"
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
                "Pull sternum to bar",
                "Stable body throughout — no rotation"
            ],
            commonMistakes: [
                "Legs drifting together (reverts to full lever row)",
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
            prereqs: [PrerequisiteGroup("pp.one-arm-row")],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .core], secondary: [.back],
            subtitle: "Pull-up while holding the front lever.",
            description: "Pull-ups performed while holding a tuck front lever — body horizontal, knees tucked. Combines pulling strength with lever core demand.",
            formCues: [
                "Enter tuck front lever before initiating the pull",
                "Hold knees tight to chest throughout",
                "Pull sternum to bar, body stays horizontal",
                "Slow eccentric — re-load the lever"
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
                "Slow eccentric, no drop"
            ],
            commonMistakes: [
                "Kipping for momentum",
                "Free hand grabbing shirt/wrist as secret assist",
                "Chin not fully clearing the bar"
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
                "Pull from dead hang to chest-to-bar before transition",
                "Slow turnover — strength over speed",
                "Press to full lockout at the top"
            ],
            commonMistakes: [
                "Any hip drive — that's a regular muscle-up",
                "Piking the legs at the transition",
                "Using momentum from the eccentric of a previous rep"
            ],
            timeline: "6-18 months from first muscle-up."
        ),

        // MARK: Push — Bent Arm Press (distinct from Bent Arm Planche)
        .simple(
            id: "cal.bent-arm-press",
            title: "Bent Arm Press",
            cluster: .calisthenicControl, tier: 6, type: .skill,
            target: .reps(exercise: "bent arm press", count: 3),
            prereqs: [PrerequisiteGroup("cal.floating-pike-pushup")],
            primary: [.shoulders, .arms], secondary: [.core, .chest],
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
            primary: [.legs, .glutes], secondary: [.core],
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
            primary: [.legs, .glutes], secondary: [.core],
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
            primary: [.legs, .glutes], secondary: [.core],
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
            primary: [.legs], secondary: [.core],
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
            primary: [.legs, .glutes], secondary: [.core],
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
            prereqs: [PrerequisiteGroup("ld.advancing-nordic-curl")],
            equipment: [.elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
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

        // MARK: Core — Spine/Raised gap nodes
        .simple(
            id: "cl.bird-dog-plank",
            title: "Bird Dog Plank",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "bird dog plank", seconds: 30),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            primary: [.core, .glutes], secondary: [.back, .shoulders],
            subtitle: "Anti-rotation under tension.",
            description: "From a full plank, extend the opposite arm and leg simultaneously. Hold 30 seconds per side without hip or shoulder drift. The anti-rotation benchmark that separates owned cores from surface-deep planks.",
            formCues: [
                "Plank position first — straight line, braced",
                "Extended arm at shoulder height, leg at hip height",
                "Hips and shoulders stay SQUARE — no tilt",
                "Breathe — this is a steady-state hold"
            ],
            commonMistakes: [
                "Hips tilting toward the unsupported side",
                "Free leg rising above hip line",
                "Shoulders rotating open"
            ],
            timeline: "2-6 weeks from plank."
        ),
        .simple(
            id: "cl.v-sit",
            title: "V-Sit",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "v-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.l-sit-10")],
            primary: [.core, .arms], secondary: [.shoulders],
            subtitle: "L-Sit, compressed upward.",
            description: "From a seated push-up position, lift the legs until they're above horizontal — body forms a V shape. 10 seconds. The compression and hip-flexor strength benchmark beyond the L-sit.",
            formCues: [
                "Hands planted on floor or parallettes, arms locked",
                "Legs dead straight and ABOVE horizontal",
                "Compress torso toward thighs",
                "Keep shoulders depressed — not shrugged"
            ],
            commonMistakes: [
                "Legs only at L-sit angle — not above horizontal",
                "Bent knees to fake the compression",
                "Shoulders creeping up toward ears"
            ],
            timeline: "6-18 months from clean L-sit."
        ),
        .simple(
            id: "cl.straddle-l-sit",
            title: "Straddle L-Sit",
            cluster: .coreLever, tier: 6, type: .hold,
            target: .hold(exercise: "straddle l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.semi-straddle-l-sit")],
            primary: [.core, .arms], secondary: [.shoulders],
            subtitle: "Wide. Horizontal. Humbling.",
            description: "L-sit with legs split into a wide straddle — legs parallel to floor, toes pointed outward. 10 seconds. The lateral compression demand the standard L-sit doesn't test.",
            formCues: [
                "Legs locked straight, wide straddle",
                "Toes pointed outward, not up",
                "Legs parallel to floor — not dropping down",
                "Active shoulders, arms locked"
            ],
            commonMistakes: [
                "Legs drooping below horizontal",
                "Bent knees to cheat the width",
                "Hip flexors tight — legs won't open wide"
            ],
            timeline: "6-12 months from clean L-sit."
        ),
        .simple(
            id: "cl.dragon-flag-hip-raise",
            title: "Dragon Flag Hip Raise",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "dragon flag hip raise", count: 8),
            prereqs: [PrerequisiteGroup("cl.reverse-crunch")],
            equipment: [.elevatedSurface],
            primary: [.core], secondary: [.back, .shoulders],
            subtitle: "Dragon flag's missing link.",
            description: "Lying on a bench gripping behind the head, drive the hips up until the body forms a straight line pointing at the ceiling — then lower with control. 8 reps. The concentric piece the dragon flag negative doesn't train.",
            formCues: [
                "Grip hard behind the head — two anchor points",
                "Drive hips straight up, not toward the face",
                "Body stays rigid — no pike at the top",
                "Lower with control, don't drop"
            ],
            commonMistakes: [
                "Piking at the hips to fake the top position",
                "Kipping with the legs for momentum",
                "Releasing the grip before the rep is done"
            ],
            timeline: "2-4 months from reverse crunch."
        ),
        .simple(
            id: "cl.decline-situp",
            title: "Decline Sit-Up",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "decline sit-up", count: 15),
            prereqs: [PrerequisiteGroup("cl.levitation-crunch")],
            equipment: [.elevatedSurface],
            primary: [.core], secondary: [.legs],
            subtitle: "More range. More burn.",
            description: "Sit-up on a decline bench — feet anchored above the head, full ROM from fully extended to torso at the knees. 15 reps.",
            formCues: [
                "Feet anchored above hip height — steeper = harder",
                "Full ROM — torso all the way back, then up to knees",
                "Arms crossed on chest, don't pull on the neck",
                "Control the eccentric — don't slam back"
            ],
            commonMistakes: [
                "Using momentum to pop up",
                "Yanking the head forward",
                "Partial ROM — cutting the descent short"
            ],
            timeline: "2-4 weeks from crunch."
        ),

        // MARK: Core — Canonical hierarchy additions
        .simple(
            id: "cl.knee-raise",
            title: "Knee Raise",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "knee raise", count: 12),
            prereqs: [PrerequisiteGroup("cl.hollow-body-30")],
            primary: [.core], secondary: [.shoulders],
            subtitle: "Supported knee lifts.",
            description: "12 knee raises while supporting body on parallel bars or dip station — keep torso upright, drive knees up to chest, control the descent. Floor variant acceptable for early levels.",
            formCues: [
                "Shoulders depressed, body supported",
                "Drive knees toward chest, not just up",
                "No swinging or kipping",
                "Slow eccentric"
            ],
            commonMistakes: [
                "Swinging for momentum",
                "Partial ROM — knees stop at 90°",
                "Shrugged shoulders under support"
            ],
            timeline: "1-4 weeks from hollow body."
        ),
        .simple(
            id: "cl.leg-raise",
            title: "Leg Raise",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "leg raise", count: 12),
            prereqs: [PrerequisiteGroup("cl.knee-raise")],
            primary: [.core], secondary: [.legs],
            subtitle: "Straight legs, full ROM.",
            description: "12 strict leg raises — supine on floor or supported on dip bars. Legs locked straight, lower back pressed down, raise legs to vertical, controlled descent.",
            formCues: [
                "Lower back pressed flat throughout",
                "Legs locked straight",
                "Raise to perpendicular, no further",
                "No bouncing or kipping"
            ],
            commonMistakes: [
                "Bent knees mid-rep — that's a knee raise",
                "Lumbar arching off the floor",
                "Using momentum on the way down"
            ],
            timeline: "2-6 weeks from knee raise."
        ),
        .simple(
            id: "cl.semi-straddle-l-sit",
            title: "Semi Straddle L-Sit",
            cluster: .coreLever, tier: 5, type: .hold,
            target: .hold(exercise: "semi straddle l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.l-sit-10")],
            primary: [.core, .arms], secondary: [.shoulders, .legs],
            subtitle: "L-sit with one leg straddled out.",
            description: "10s hold with one leg in standard L-sit position, the other leg opened to the side at ~45°. Bridges L-sit to full straddle.",
            formCues: [
                "Hands press down, shoulders depressed",
                "One leg locked forward, one leg opened ~45°",
                "Both legs above hand line",
                "Switch sides each set"
            ],
            commonMistakes: [
                "Open leg drops below hand line",
                "Bent knees on either leg",
                "Shoulders shrugging up"
            ],
            timeline: "2-6 months from clean L-sit."
        ),
        .simple(
            id: "cl.vertical-l-sit",
            title: "Vertical L-Sit",
            cluster: .coreLever, tier: 6, type: .hold,
            target: .hold(exercise: "vertical l-sit", seconds: 5),
            prereqs: [PrerequisiteGroup("cl.v-sit")],
            primary: [.core, .arms], secondary: [.shoulders],
            subtitle: "Legs go past vertical.",
            description: "5s hold with hands pressed on parallel bars or floor, legs lifted past vertical so the body forms a V — extreme compression and pressing strength. Beyond V-sit.",
            formCues: [
                "Arms locked, shoulders depressed",
                "Compress hard — torso folds toward thighs",
                "Legs lift past vertical, not just to vertical",
                "Toes pointed, no bend in knees"
            ],
            commonMistakes: [
                "Legs only at vertical (that's a V-sit)",
                "Bent arms cheat the press",
                "Hips drop below hand line"
            ],
            timeline: "1-2 years from clean V-sit."
        ),

        // MARK: Handstand — Wall Path gaps
        .simple(
            id: "hs.wall-plank",
            title: "Wall Plank",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "wall plank", seconds: 30),
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Handstand starts horizontal.",
            description: "Plank position with feet walked up the wall until shoulders stack over wrists. 30 seconds. The shared root for wall handstand, headstand, and early planche balance.",
            formCues: [
                "Hands shoulder-width, fingers spread",
                "Walk feet UP the wall until hips over shoulders",
                "Shoulders stacked over wrists",
                "Core tight, ribs tucked"
            ],
            commonMistakes: [
                "Hands too far from the wall — sags the position",
                "Piked hips instead of stacked",
                "Shrugged shoulders into the ears"
            ],
            timeline: "Immediate to 2 weeks."
        ),
        .simple(
            id: "hs.wall-supported-oah",
            title: "Wall Supported One-Arm Handstand",
            cluster: .handstand, tier: 5, type: .hold,
            target: .hold(exercise: "wall-supported one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.freestanding-hs-30")],
            primary: [.shoulders, .core], secondary: [.forearms, .arms],
            subtitle: "One arm. Wall for insurance.",
            description: "One-arm handstand with the back against the wall providing light balance insurance. 5 seconds per side. The bridge between freestanding handstand and a freestanding one-arm handstand.",
            formCues: [
                "Back to wall — touches only as safety, not a lean",
                "Shift weight slow to the working arm",
                "Free arm stays tight to body or out to counterbalance",
                "Ribs tucked, glutes squeezed — rigid tower"
            ],
            commonMistakes: [
                "Leaning into the wall for active support",
                "Losing the line — banana-ing into the wall",
                "Rushing the weight shift before balance is set"
            ],
            timeline: "1-2 years from freestanding handstand."
        ),
    ]
}

// MARK: - Legacy SkillTree content access (keeps old callers compiling)
//
// referenced the old per-archetype trees. All resolve to .universal.

extension SkillTree {
    static var unitTree:     SkillTree { .universal }
    static var leanCutTree:  SkillTree { .universal }
    static var carvedTree:   SkillTree { .universal }
    static var vTaperTree:   SkillTree { .universal }
}
