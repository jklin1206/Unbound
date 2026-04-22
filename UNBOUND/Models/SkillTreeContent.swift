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
        let enriched: [SkillNode] = Self.v3Nodes.map { node in
            guard let chapter = SkillSubChapterMap.chapter(for: node.id) else {
                return node
            }
            var copy = node
            copy.subChapter = chapter
            return copy
        }
        return SkillGraph(nodes: enriched)
    }()
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
        // then the solo-arm finale.
        // ──────────────────────────────────────────────────────────────
        "pp.dead-hang-30":         "The Grip",
        "pp.negative-pullup":      "The Grip",

        "pp.pullup":               "Ascent",
        "pp.5-pullups":            "Ascent",
        "pp.10-pullups":           "Ascent",
        "pp.slow-pullup":          "Ascent",
        "pp.chest-to-bar":         "Ascent",
        "pp.l-sit-pullup":         "Ascent",
        "pp.archer-pullup":        "Ascent",
        "pp.weighted-pullup-0.25": "Ascent",
        "pp.weighted-pullup-0.5":  "Ascent",
        "pp.chin-up":              "Ascent",
        "pp.strict-chin-up":       "Ascent",
        "pp.weighted-chin-up":     "Ascent",
        "pp.l-sit-chin-up":        "Ascent",
        "pp.wide-pullup":          "Ascent",

        "pp.muscle-up":            "Crossover",
        "pp.10-muscle-ups":        "Crossover",
        "pp.ring-muscle-up":       "Crossover",
        "pp.clapping-pullup":      "Crossover",
        "pp.explosive-pullup":     "Crossover",
        "pp.plyometric-pullup":    "Crossover",

        "pp.typewriter-pullup":    "Solo Arm",
        "pp.oap-negative":         "Solo Arm",
        "pp.one-arm-pullup":       "Solo Arm",
        "pp.heighted-chin-up":     "Solo Arm",
        "pp.one-arm-chin-up":      "Solo Arm",
        // pp.5-oap-side is mythic — chapter-less.

        // Row family — reference infographic adds rows as a distinct
        // pull-pattern progression at the base of the Pull axis.
        "pp.incline-row":          "The Row",
        "pp.decline-row":          "The Row",
        "pp.tuck-row":             "The Row",
        "pp.straddle-row":         "The Row",

        "pp.strict-muscle-up":     "Crossover",

        // ──────────────────────────────────────────────────────────────
        // PUSH / CALISTHENIC CONTROL (cal) — pressing + ring holds. Iron
        // Cross family moved to Core & Levers (Phase 2j) — Ring King
        // chapter still maps those node ids, just under the coreLever
        // tree now.
        // ──────────────────────────────────────────────────────────────
        "cal.pushup":              "Ground Work",
        "cal.slow-pushup":         "Ground Work",
        "cal.diamond-pushup":      "Ground Work",
        "cal.incline-pushup":      "Ground Work",
        "cal.decline-pushup":      "Ground Work",
        "cal.sphinx-pushup":       "Ground Work",
        "cal.archer-pushup":       "Ground Work",
        "cal.one-arm-pushup":      "Ground Work",
        "cal.explosive-pushup":    "Ground Work",
        "cal.clapping-pushup":     "Ground Work",
        "cal.floating-pike-pushup": "Ground Work",

        "cal.5-dips":              "The Dip",
        "cal.ring-support-10":     "The Dip",
        "cal.ring-dip":            "The Dip",
        "cal.bench-dip":           "The Dip",
        "cal.l-sit-dip":           "The Dip",
        "cal.weighted-dip":        "The Dip",
        "cal.tempo-dip":           "The Dip",

        "cal.plank-30":            "Lock-In",
        "cal.l-sit-10":            "Lock-In",
        "cal.l-sit-20":            "Lock-In",

        "cal.bent-arm-press":      "Ground Work",

        // Iron Cross family — now lives in `.coreLever` cluster.
        "cal.iron-cross-3s":       "Ring King",
        "cal.iron-cross-10s":      "Ring King",
        "cl.skin-the-cat":         "Ring King",
        "cl.german-hang":          "Ring King",
        // cal.maltese + cal.azarian + cl.three-sixty-pulls are mythic — chapter-less.

        // ──────────────────────────────────────────────────────────────
        // LEGS (ld) — squat base → unilateral bridge → pistol chain →
        // a one-off strength branch.
        // ──────────────────────────────────────────────────────────────
        "ld.goblet-20":            "Foundation",
        "ld.tempo-squat":          "Foundation",
        "ld.calf-raise":           "Foundation",
        "ld.hip-hinge":            "Foundation",
        "ld.step-up":              "Foundation",
        "ld.deep-squat":           "Foundation",
        "ld.glute-bridge":         "Foundation",
        "ld.bw-front-squat":       "Loaded Stance",

        "ld.bulgarian-split-squat": "Unilateral",
        "ld.100-lunges":           "Unilateral",
        "ld.single-leg-rdl":       "Unilateral",
        "ld.assisted-pistol":      "Unilateral",
        "ld.heighted-split-squat": "Unilateral",
        "ld.weighted-bss":         "Unilateral",

        "ld.shrimp-squat":         "Pistol Path",
        "ld.pistol-squat":         "Pistol Path",
        "ld.weighted-pistol":      "Pistol Path",
        "ld.dragon-pistol":        "Pistol Path",
        "ld.heighted-pistol":      "Pistol Path",
        "ld.weighted-sl-calf":     "Pistol Path",
        "ld.sissy-squat":          "Pistol Path",
        // ld.jumping-pistol is mythic — chapter-less.

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
        // CORE & LEVERS (cl) — hollow → raised / hanging → flag → two
        // lever families.
        // ──────────────────────────────────────────────────────────────
        "cl.hollow-body-30":       "The Spine",
        "cl.hollow-body-60":       "The Spine",
        "cl.crunch":               "The Spine",
        "cl.reverse-crunch":       "The Spine",
        "cl.superman-plank":       "The Spine",
        "cl.standing-plank":       "The Spine",
        "cl.extended-plank":       "The Spine",
        "cl.levitation-crunch":    "The Spine",
        "cl.straight-crunch":      "The Spine",
        "cl.bird-dog-plank":       "The Spine",

        "cl.hanging-knee-raise":   "Raised Work",
        "cl.hanging-leg-raise":    "Raised Work",
        "cl.toes-to-bar":          "Raised Work",
        "cl.ab-wheel":             "Raised Work",
        "cl.knee-ab-rollout":      "Raised Work",
        "cl.inverted-situp":       "Raised Work",
        "cl.decline-situp":        "Raised Work",
        "cl.v-sit":                "Raised Work",
        "cl.straddle-l-sit":       "Raised Work",

        "cl.dragon-flag-negative": "Flag Path",
        "cl.dragon-flag":          "Flag Path",
        "cl.dragon-flag-hip-raise": "Flag Path",

        "cl.tuck-front-lever":     "Front Lever",
        "cl.straddle-front-lever": "Front Lever",
        "cl.full-front-lever":     "Front Lever",

        "cl.tuck-back-lever":      "Back Lever",
        "cl.straddle-back-lever":  "Back Lever",
        "cl.full-back-lever":      "Back Lever",
        // cl.victorian is mythic — chapter-less.

        // ──────────────────────────────────────────────────────────────
        // HANDBALANCE — three sub-clusters; each gets its own chapters.
        // ──────────────────────────────────────────────────────────────
        // hs — Handstand
        "hs.wrist-conditioning":   "Wall Path",
        "hs.wall-handstand-30":    "Wall Path",
        "hs.wall-handstand-60":    "Wall Path",
        "hs.headstand":            "Wall Path",
        "hs.wall-plank":           "Wall Path",
        "hs.wall-supported-oah":   "Wall Path",

        "hs.freestanding-hs-10":   "Freestanding",
        "hs.freestanding-hs-30":   "Freestanding",
        "hs.freestanding-hs-60":   "Freestanding",
        "hs.handstand-walk-10m":   "Freestanding",
        "hs.tuck-handstand":       "Freestanding",
        "hs.tuck-press":           "Freestanding",
        "hs.straddle-press":       "Freestanding",
        "hs.press-to-handstand":   "Freestanding",

        "hs.crow-pose":            "Hand Poses",
        "hs.crane-pose":           "Hand Poses",
        "hs.frog-pose":            "Hand Poses",
        "hs.flying-crow":          "Hand Poses",
        "hs.elbow-lever":          "Hand Poses",
        "hs.one-arm-elbow-lever":  "Hand Poses",

        // hspu — Handstand Push-Up
        "hspu.pike-pushup-10":     "Wall Press",
        "hspu.elevated-pike-pushup-10": "Wall Press",
        "hspu.wall-hspu-negative-5s":   "Wall Press",
        "hspu.first-wall-hspu":    "Wall Press",
        "hspu.wall-hspu-3":        "Wall Press",
        "hspu.wall-hspu-5":        "Wall Press",
        "hspu.deficit-wall-hspu-3": "Wall Press",

        "hspu.freestanding-hspu-negative-5s": "Free Press",
        "hspu.first-freestanding-hspu":       "Free Press",
        "hspu.freestanding-hspu-3":           "Free Press",

        // oah — One-Arm Handstand. Both non-mythic entries are mythic,
        // so this sub-cluster has no chapter-bearing nodes.
        // (oah.one-arm-handstand-5s + oah.one-arm-hspu are both mythic.)

        // ──────────────────────────────────────────────────────────────
        // PLANCHE (pl)
        // ──────────────────────────────────────────────────────────────
        "pl.pseudo-planche-pushup": "Lean Path",
        "pl.tuck-planche":          "Tuck Path",
        "pl.tuck-planche-pushup":   "Tuck Path",
        "pl.bent-arm-planche":      "Tuck Path",
        "pl.straddle-planche":      "Float",
        "pl.full-planche":          "Float",
        "pl.full-planche-pushup":   "Float",
        "pl.half-lay-planche":      "Float",
        // pl.ninety-degree-pushup + pl.one-arm-planche are mythic — chapter-less.

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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean goblet squats to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict goblet squats", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict goblet squats", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict goblet squats", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict goblet squats", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean tempo squat to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict tempo squat", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict tempo squat", xpReward: 150),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean bulgarian split squat per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict bulgarian split squat per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict bulgarian split squat per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict bulgarian split squat per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict bulgarian split squat per leg", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean unbroken walking lunge steps to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict unbroken walking lunge steps", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict unbroken walking lunge steps", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict unbroken walking lunge steps", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict unbroken walking lunge steps", xpReward: 250),
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
                SkillLevel(level: 1, target: .weight(multiplier: 0.5), criterion: "0.5x bodyweight front squat, clean ROM", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.81), criterion: "0.81x bodyweight front squat, clean ROM", xpReward: 100),
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
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict shrimp squat per leg", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean assisted pistol per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict assisted pistol per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict assisted pistol per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict assisted pistol per leg", xpReward: 200),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean single-leg RDL per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict single-leg RDL per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict single-leg RDL per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict single-leg RDL per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict single-leg RDL per leg", xpReward: 250),
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
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict pistol squat per leg", xpReward: 250),
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
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict dragon pistol per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict dragon pistol per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict dragon pistol per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict dragon pistol per leg", xpReward: 250),
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
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict jumping pistol per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict jumping pistol per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict jumping pistol per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict jumping pistol per leg", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 5-second negative pullup to standard", xpReward: 50),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict pullup", xpReward: 200),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict pullup", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean slow (3s/3s) pullup to standard", xpReward: 50),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean chest-to-bar pullup to standard", xpReward: 50),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean L-sit pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict L-sit pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict L-sit pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict L-sit pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict L-sit pullup", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean archer pullup per side to standard", xpReward: 50),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean typewriter pullup per side to standard", xpReward: 50),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 5-second one-arm pullup negative to standard", xpReward: 50),
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
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict one-arm pullup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict one-arm pullup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict one-arm pullup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict one-arm pullup per side", xpReward: 250),
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
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict bar muscle-up", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean bar muscle-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict bar muscle-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict bar muscle-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict bar muscle-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict bar muscle-up", xpReward: 250),
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
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict ring muscle-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict ring muscle-up", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean one-arm pullup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict one-arm pullup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict one-arm pullup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict one-arm pullup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict one-arm pullup per side", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold plank for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold plank for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold plank for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold plank for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold plank for 60s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold L-sit for 8s, clean form", xpReward: 50),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict pushup", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean slow (3s/3s) pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict slow (3s/3s) pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict slow (3s/3s) pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict slow (3s/3s) pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict slow (3s/3s) pushup", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict dip", xpReward: 250),
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
            timeline: "3-6 months from 5 bar dips + ring support.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean ring dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict ring dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict ring dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict ring dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict ring dip", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean diamond pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict diamond pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict diamond pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict diamond pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict diamond pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pl.pseudo-planche-pushup",
            title: "Pseudo-Planche Push-Up",
            cluster: .planche, tier: 3, type: .skill,
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pseudo-planche pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict pseudo-planche pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict pseudo-planche pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict pseudo-planche pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict pseudo-planche pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pl.tuck-planche",
            title: "Tuck Planche",
            cluster: .planche, tier: 3, type: .hold,
            target: .hold(exercise: "tuck planche", seconds: 5),
            prereqs: [PrerequisiteGroup("pl.pseudo-planche-pushup")],
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
            id: "pl.tuck-planche-pushup",
            title: "Tuck Planche Push-Up",
            cluster: .planche, tier: 4, type: .skill,
            target: .reps(exercise: "tuck planche pushup", count: 3),
            prereqs: [PrerequisiteGroup(["pl.pseudo-planche-pushup", "pl.tuck-planche"])],
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean tuck planche pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict tuck planche pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict tuck planche pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict tuck planche pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict tuck planche pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pl.straddle-planche",
            title: "Straddle Planche",
            cluster: .planche, tier: 5, type: .hold,
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
            id: "pl.full-planche",
            title: "Full Planche",
            cluster: .planche, tier: 6, type: .hold,
            target: .hold(exercise: "full planche", seconds: 5),
            prereqs: [PrerequisiteGroup("pl.straddle-planche")],
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
            id: "pl.full-planche-pushup",
            title: "Full Planche Push-Up",
            cluster: .planche, tier: 6, type: .skill,
            target: .reps(exercise: "full planche pushup", count: 1),
            prereqs: [PrerequisiteGroup("pl.full-planche")],
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
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict full planche pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict full planche pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict full planche pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict full planche pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pl.ninety-degree-pushup",
            title: "Ninety-Degree Push-Up",
            cluster: .planche, tier: 7, type: .skill,
            target: .reps(exercise: "90 degree pushup", count: 1),
            prereqs: [PrerequisiteGroup("pl.full-planche-pushup")],
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
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict 90-degree pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict 90-degree pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict 90-degree pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict 90-degree pushup", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean pike pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict pike pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict pike pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict pike pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict pike pushup", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean elevated pike pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict elevated pike pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict elevated pike pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict elevated pike pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict elevated pike pushup", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold wall handstand for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold wall handstand for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold wall handstand for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold wall handstand for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold wall handstand for 45s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold wall handstand for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold wall handstand for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold wall handstand for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold wall handstand for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold wall handstand for 45s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 5-second wall HSPU negative to standard", xpReward: 50),
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
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict wall HSPU", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict wall HSPU", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict wall HSPU", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean deficit wall HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict deficit wall HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict deficit wall HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict deficit wall HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict deficit wall HSPU", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold freestanding handstand for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold freestanding handstand for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold freestanding handstand for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold freestanding handstand for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold freestanding handstand for 45s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 5-second freestanding HSPU negative to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict 5-second freestanding HSPU negative", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict 5-second freestanding HSPU negative", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict 5-second freestanding HSPU negative", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict 5-second freestanding HSPU negative", xpReward: 250),
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
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict freestanding HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict freestanding HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict freestanding HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict freestanding HSPU", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean freestanding HSPU to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict freestanding HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict freestanding HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict freestanding HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict freestanding HSPU", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.freestanding-hs-60",
            title: "Full Handstand",
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
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold freestanding handstand for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold freestanding handstand for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold freestanding handstand for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 22), criterion: "Hold freestanding handstand for 22s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 30), criterion: "Hold freestanding handstand for 30s, clean form", xpReward: 250),
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
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict one-arm HSPU", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict one-arm HSPU", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict one-arm HSPU", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict one-arm HSPU", xpReward: 250),
            ]
        ),

        .simple(
            id: "cal.iron-cross-3s",
            title: "Iron Cross",
            cluster: .coreLever, tier: 5, type: .hold,
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
            cluster: .coreLever, tier: 6, type: .hold,
            target: .hold(exercise: "iron cross", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.iron-cross-3s")],
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
                SkillLevel(level: 3, target: .hold(seconds: 5), criterion: "Hold iron cross for 5s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 8), criterion: "Hold iron cross for 8s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 10), criterion: "Hold iron cross for 10s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.maltese",
            title: "Maltese",
            cluster: .coreLever, tier: 7, type: .hold,
            target: .hold(exercise: "maltese", seconds: 1),
            prereqs: [PrerequisiteGroup(["cal.iron-cross-10s", "pl.full-planche"])],
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
            cluster: .coreLever, tier: 7, type: .skill,
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
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict azarian press", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict azarian press", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict azarian press", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict azarian press", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold hollow body for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold hollow body for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold hollow body for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold hollow body for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold hollow body for 60s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold hollow body for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold hollow body for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold hollow body for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold hollow body for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold hollow body for 45s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean hanging knee raise to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict hanging knee raise", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict hanging knee raise", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict hanging knee raise", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict hanging knee raise", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean hanging leg raise to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict hanging leg raise", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict hanging leg raise", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict hanging leg raise", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict hanging leg raise", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean strict toes-to-bar to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict strict toes-to-bar", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict strict toes-to-bar", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict strict toes-to-bar", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict strict toes-to-bar", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean standing ab wheel rollout to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict standing ab wheel rollout", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict standing ab wheel rollout", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict standing ab wheel rollout", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict standing ab wheel rollout", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 5-second dragon flag negative to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict 5-second dragon flag negative", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict 5-second dragon flag negative", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict 5-second dragon flag negative", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict 5-second dragon flag negative", xpReward: 250),
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
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean dragon flag to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict dragon flag", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict dragon flag", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict dragon flag", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict dragon flag", xpReward: 250),
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
                SkillLevel(level: 4, target: .hold(seconds: 11), criterion: "Hold full front lever for 11s, clean form", xpReward: 200),
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
                SkillLevel(level: 4, target: .hold(seconds: 11), criterion: "Hold full back lever for 11s, clean form", xpReward: 200),
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
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold dead hang for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold dead hang for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold dead hang for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold dead hang for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold dead hang for 60s, clean form", xpReward: 250),
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
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold dead hang for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold dead hang for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold dead hang for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold dead hang for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold dead hang for 45s, clean form", xpReward: 250),
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
            cluster: .pullingPower, tier: 2, type: .skill,
            target: .reps(exercise: "chin-up", count: 1),
            prereqs: [PrerequisiteGroup("pp.negative-pullup")],
            equipment: [.pullupBar],
            primary: [.arms, .lats], secondary: [.back],
            subtitle: "Underhand grip. Biceps join the pull.",
            description: "One strict chin-up — palms facing you, chin clears the bar from a full dead hang. Biceps-dominant cousin of the pullup.",
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
            timeline: "4-10 weeks from first pullup attempt.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean chin-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict chin-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict chin-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict chin-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict chin-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.strict-chin-up",
            title: "Strict Chin-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "chin-up", count: 8),
            prereqs: [PrerequisiteGroup("pp.chin-up")],
            equipment: [.pullupBar],
            primary: [.arms, .lats], secondary: [.back, .core],
            subtitle: "Chin-up volume benchmark.",
            description: "8 unbroken strict chin-ups from dead hang. First real capacity test on the underhand grip.",
            formCues: [
                "Full dead hang each rep",
                "No kipping — hips stay still",
                "Slow eccentric to preserve form late in the set",
                "Breathe at the dead hang, not the top"
            ],
            commonMistakes: [
                "Reps 6-8 going partial",
                "Letting the elbows flare out",
                "Bouncing out of the dead hang"
            ],
            timeline: "2-6 months from first chin-up.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean chin-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict chin-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict chin-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict chin-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict chin-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.weighted-chin-up",
            title: "Weighted Chin-Up",
            cluster: .pullingPower, tier: 4, type: .strength,
            target: .weightMultiplier(exercise: "weighted chin-up", multiplier: 0.25),
            prereqs: [PrerequisiteGroup("pp.strict-chin-up")],
            equipment: [.pullupBar, .dumbbells],
            primary: [.arms, .lats], secondary: [.back],
            subtitle: "Load the underhand pull.",
            description: "Chin-up with a weighted belt or dumbbell held between the feet. Quarter bodyweight added load, clean ROM.",
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
            timeline: "2-6 months from strict chin-up × 8.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.15), criterion: "Chin-up with 0.15x bw load", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.25), criterion: "Chin-up with 0.25x bw load", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 0.4), criterion: "Chin-up with 0.4x bw load", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 0.5), criterion: "Chin-up with 0.5x bw load", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 0.65), criterion: "Chin-up with 0.65x bw load", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.l-sit-chin-up",
            title: "L-Sit Chin-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "l-sit chin-up", count: 3),
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
            timeline: "4-12 months from strict chin-up + L-sit.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean L-sit chin-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict L-sit chin-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict L-sit chin-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict L-sit chin-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict L-sit chin-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.wide-pullup",
            title: "Wide Pull-Up",
            cluster: .pullingPower, tier: 3, type: .skill,
            target: .reps(exercise: "wide pullup", count: 5),
            prereqs: [PrerequisiteGroup("pp.5-pullups")],
            equipment: [.pullupBar],
            primary: [.lats, .back], secondary: [.arms],
            subtitle: "Lats first. Arms second.",
            description: "5 strict pullups with hands set well outside shoulder width. Lat-dominant — emphasizes back width over arm pull.",
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
            timeline: "1-4 months from 5 standard pullups.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean wide pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict wide pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict wide pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict wide pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict wide pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.explosive-pullup",
            title: "Explosive Pull-Up",
            cluster: .pullingPower, tier: 4, type: .skill,
            target: .reps(exercise: "explosive pullup", count: 3),
            prereqs: [PrerequisiteGroup("pp.10-pullups")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "Pull hard enough the hands come off.",
            description: "3 pullups where the concentric is explosive enough that hands briefly leave the bar at the top. Bridge between strict pullup and muscle-up.",
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
            timeline: "2-6 months from 10 pullups.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean explosive pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict explosive pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict explosive pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict explosive pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict explosive pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.plyometric-pullup",
            title: "Plyometric Pull-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "plyometric pullup", count: 3),
            prereqs: [PrerequisiteGroup("pp.explosive-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core],
            subtitle: "Release, catch, drop, repeat.",
            description: "3 explosive pullups with the catch on the way down turning into a loaded eccentric that rebounds into the next rep. True plyometric pulling.",
            formCues: [
                "Explode up, release briefly, catch bar on the descent",
                "Absorb eccentric with control, load the lats",
                "Rebound immediately into the next rep",
                "Reset if rhythm breaks — don't force continuity"
            ],
            commonMistakes: [
                "Missing the bar catch",
                "No eccentric control — just dropping",
                "Shrugged shoulders on the catch (shoulder risk)"
            ],
            timeline: "3-9 months from explosive pullup.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean plyometric pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict plyometric pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict plyometric pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict plyometric pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict plyometric pullup", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.clapping-pullup",
            title: "Clapping Pull-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "clapping pullup", count: 1),
            prereqs: [PrerequisiteGroup("pp.explosive-pullup")],
            equipment: [.pullupBar],
            primary: [.lats, .arms, .back], secondary: [.core],
            subtitle: "Pull high enough to clap before catching.",
            description: "One clean clapping pullup — pull explosively enough to release the bar, clap hands at chest, and re-grip before the descent. Bar-muscle-up prerequisite for most athletes.",
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
            timeline: "6-18 months from explosive pullup.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clapping pullup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clapping pullup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clapping pullup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict clapping pullup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict clapping pullup", xpReward: 250),
            ]
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
            timeline: "1-4 weeks for most beginners.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean incline pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict incline pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict incline pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict incline pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict incline pushup", xpReward: 250),
            ]
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
            timeline: "2-4 weeks from 10 standard pushups.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean decline pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict decline pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict decline pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict decline pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict decline pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.sphinx-pushup",
            title: "Sphinx Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "sphinx pushup", count: 8),
            prereqs: [PrerequisiteGroup("cal.pushup")],
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
            timeline: "2-4 weeks from 10 pushups.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean sphinx pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict sphinx pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict sphinx pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict sphinx pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict sphinx pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.archer-pushup",
            title: "Archer Push-Up",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "archer pushup", count: 3),
            prereqs: [PrerequisiteGroup("cal.diamond-pushup")],
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
            timeline: "2-6 months from diamond pushup.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean archer pushup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict archer pushup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict archer pushup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict archer pushup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict archer pushup per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.one-arm-pushup",
            title: "One-Arm Push-Up",
            cluster: .calisthenicControl, tier: 4, type: .skill,
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
            timeline: "6-18 months from archer pushup.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean one-arm pushup per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict one-arm pushup per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict one-arm pushup per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict one-arm pushup per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict one-arm pushup per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.explosive-pushup",
            title: "Explosive Push-Up",
            cluster: .calisthenicControl, tier: 2, type: .skill,
            target: .reps(exercise: "explosive pushup", count: 5),
            prereqs: [PrerequisiteGroup("cal.pushup")],
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
            timeline: "2-6 weeks from 10 pushups.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean explosive pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict explosive pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict explosive pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict explosive pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict explosive pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.clapping-pushup",
            title: "Clapping Push-Up",
            cluster: .calisthenicControl, tier: 3, type: .skill,
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
            timeline: "1-4 months from explosive pushup.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clapping pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clapping pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clapping pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clapping pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict clapping pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.floating-pike-pushup",
            title: "Floating Pike Push-Up",
            cluster: .calisthenicControl, tier: 5, type: .skill,
            target: .reps(exercise: "floating pike pushup", count: 3),
            prereqs: [PrerequisiteGroup(["cal.archer-pushup", "hspu.elevated-pike-pushup-10"])],
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
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean floating pike pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict floating pike pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict floating pike pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict floating pike pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict floating pike pushup", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.bench-dip",
            title: "Bench Dip",
            cluster: .calisthenicControl, tier: 1, type: .skill,
            target: .reps(exercise: "bench dip", count: 10),
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.arms], secondary: [.chest, .shoulders],
            subtitle: "The dip on-ramp.",
            description: "10 bench dips — hands on a bench behind you, feet on the floor, lower hips toward the ground, press back up. Tricep-dominant starter.",
            formCues: [
                "Hands grip bench edge, fingers pointing forward",
                "Elbows track straight back, not flared",
                "Descend until upper arms parallel or deeper",
                "Press through the palms to lockout"
            ],
            commonMistakes: [
                "Elbows flaring wide — shoulder strain",
                "Dropping hips forward away from the bench",
                "Partial ROM — stopping well short of parallel"
            ],
            timeline: "1-3 weeks for most beginners.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean bench dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict bench dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict bench dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict bench dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict bench dip", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.tempo-dip",
            title: "Tempo Dip",
            cluster: .calisthenicControl, tier: 3, type: .skill,
            target: .reps(exercise: "tempo dip", count: 5),
            prereqs: [PrerequisiteGroup("cal.5-dips")],
            equipment: [.parallettes, .elevatedSurface],
            primary: [.chest, .arms, .shoulders],
            subtitle: "Slow exposes weak.",
            description: "5 dips with a 3-second descent and 1-second hold at the bottom before pressing back up. Tempo burns out every rep to the last inch.",
            formCues: [
                "Count 3 on the way down",
                "Full pause at the bottom — shoulders below elbows",
                "No bounce out of the hole",
                "Control the press, don't explode up"
            ],
            commonMistakes: [
                "Bouncing out of the pause",
                "Cheating tempo on reps 4-5",
                "Losing ROM as fatigue sets in"
            ],
            timeline: "4-10 weeks from 5 clean dips.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean tempo (3s/1s) dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict tempo (3s/1s) dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict tempo (3s/1s) dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict tempo (3s/1s) dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict tempo (3s/1s) dip", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.weighted-dip",
            title: "Weighted Dip",
            cluster: .calisthenicControl, tier: 3, type: .strength,
            target: .weightMultiplier(exercise: "weighted dip", multiplier: 0.25),
            prereqs: [PrerequisiteGroup("cal.5-dips")],
            equipment: [.parallettes, .dumbbells],
            primary: [.chest, .arms, .shoulders],
            subtitle: "Load the dip.",
            description: "Dip with added weight via belt or dumbbell between the feet. Quarter bodyweight, clean reps and ROM.",
            formCues: [
                "Same strict form as bodyweight dip",
                "Add load in small 5-10 lb steps",
                "Shoulders below elbows at the bottom",
                "Full lockout top"
            ],
            commonMistakes: [
                "Loading too heavy and losing ROM",
                "Swinging the dumbbell for momentum",
                "Shrugged shoulders under load"
            ],
            timeline: "2-6 months from 5 bodyweight dips.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.15), criterion: "Dip with 0.15x bw load", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.25), criterion: "Dip with 0.25x bw load", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 0.4), criterion: "Dip with 0.4x bw load", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 0.5), criterion: "Dip with 0.5x bw load", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 0.75), criterion: "Dip with 0.75x bw load", xpReward: 250),
            ]
        ),
        .simple(
            id: "cal.l-sit-dip",
            title: "L-Sit Dip",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "l-sit dip", count: 3),
            prereqs: [PrerequisiteGroup(["cal.5-dips", "cal.l-sit-10"])],
            equipment: [.parallettes],
            primary: [.chest, .arms, .shoulders, .core],
            subtitle: "Dip while holding an L-sit.",
            description: "3 strict dips with legs locked out parallel in an L-sit. Combines the pressing of the dip with the core compression of the L-sit.",
            formCues: [
                "Enter top position in a full L-sit",
                "Legs stay parallel throughout",
                "Dip to full depth — shoulders below elbows",
                "No leg drop on the eccentric"
            ],
            commonMistakes: [
                "Legs drooping as fatigue sets in",
                "Bent knees — loses L-sit standard",
                "Partial ROM on the dip"
            ],
            timeline: "3-12 months from 5 dips + L-sit 10s.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean L-sit dip to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict L-sit dip", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict L-sit dip", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict L-sit dip", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict L-sit dip", xpReward: 250),
            ]
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
            timeline: "5+ years of power training. Very rare.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean triple clap pushup to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict triple clap pushup", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict triple clap pushup", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict triple clap pushup", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict triple clap pushup", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // LEGS ADDITIONS — calves, jumps, glute work, hamstring forge
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "ld.calf-raise",
            title: "Calf Raise",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "calf raise", count: 20),
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
            timeline: "1-2 weeks from zero.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean calf raise to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean calf raise", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean calf raise", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean calf raise", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean calf raise", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.weighted-sl-calf",
            title: "Weighted Single-Leg Calf Raise",
            cluster: .legDominance, tier: 3, type: .strength,
            target: .reps(exercise: "single-leg calf raise", count: 10, load: "0.5x bw"),
            prereqs: [PrerequisiteGroup("ld.calf-raise")],
            equipment: [.dumbbells, .kettlebell],
            primary: [.calves],
            subtitle: "Unilateral calf strength.",
            description: "10 single-leg calf raises per side holding half bodyweight at the hip. Eliminates the stronger leg compensation that kills calf hypertrophy.",
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
            timeline: "2-6 months from bodyweight calf raises.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean single-leg calf raise at 0.25x bw to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict single-leg calf raise at 0.5x bw", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict single-leg calf raise at 0.5x bw", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict single-leg calf raise at 0.75x bw", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict single-leg calf raise at 1x bw", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.hip-hinge",
            title: "Hip Hinge",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "hip hinge", count: 15),
            primary: [.glutes, .back], secondary: [.legs, .core],
            subtitle: "The pattern behind every pull from the floor.",
            description: "15 bodyweight hip hinges — push hips back, soft knee bend, neutral spine, return. Teaches the hinge pattern before it gets loaded.",
            formCues: [
                "Push hips back like shutting a car door with your butt",
                "Soft knee bend — not a squat",
                "Neutral spine throughout — no rounding",
                "Feel the stretch in the hamstrings at the bottom"
            ],
            commonMistakes: [
                "Squatting instead of hinging",
                "Rounding the lower back",
                "Knees drifting forward"
            ],
            timeline: "1-2 weeks to groove the pattern.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean hip hinge to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean hip hinge", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean hip hinge", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean hip hinge", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean hip hinge", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.box-jump",
            title: "Box Jump",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "box jump", count: 5),
            prereqs: [PrerequisiteGroup("ld.tempo-squat")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.calves, .core],
            subtitle: "Explosive triple extension.",
            description: "5 clean box jumps to a box at knee height or higher. Land soft, stand tall, step down — never jump down.",
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
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean box jumps to knee height to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean box jumps to mid-thigh", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean box jumps to hip height", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean box jumps to waist height", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 clean box jumps to chest height", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.jumping-squat",
            title: "Jumping Squat",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "jumping squat", count: 10),
            prereqs: [PrerequisiteGroup("ld.tempo-squat")],
            primary: [.legs, .glutes], secondary: [.calves, .core],
            subtitle: "Squat, then launch.",
            description: "10 bodyweight jumping squats — full-depth squat, explode to jump, land soft, re-descend into the next rep. Power endurance.",
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
            timeline: "1-3 weeks from solid tempo squats.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean jumping squat to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean jumping squat", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean jumping squat", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean jumping squat", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean jumping squat", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.heighted-split-squat",
            title: "Elevated Bulgarian Split Squat",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "elevated bulgarian split squat", count: 8),
            prereqs: [PrerequisiteGroup("ld.bulgarian-split-squat")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "More range. More burn.",
            description: "8 reps per leg with the front foot elevated on a plate or low box. Deepens the split squat ROM and hits glutes harder.",
            formCues: [
                "Front foot on a 2-4 inch plate or low box",
                "Rear foot on a bench, laces down",
                "Torso upright, drive through front heel",
                "Full depth — deeper than floor split squat"
            ],
            commonMistakes: [
                "Going too high on the front elevation",
                "Front knee diving over toes",
                "Partial ROM"
            ],
            timeline: "2-4 months from floor bulgarian split squat.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean elevated bulgarian split squat per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict elevated bulgarian split squat per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict elevated bulgarian split squat per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict elevated bulgarian split squat per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict elevated bulgarian split squat per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.heighted-pistol",
            title: "Elevated Pistol Squat",
            cluster: .legDominance, tier: 5, type: .skill,
            target: .reps(exercise: "elevated pistol", count: 3),
            prereqs: [PrerequisiteGroup("ld.pistol-squat")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Pistol with free leg below the working foot.",
            description: "Pistol squat performed on a raised platform so the free leg can drop below the foot — forces deeper hip flexion and real ankle mobility. 3 per side.",
            formCues: [
                "Box or plate 6-12 inches tall",
                "Free leg drops below the platform",
                "Full pistol depth on the working leg",
                "Slow descent to keep heel planted"
            ],
            commonMistakes: [
                "Free leg resting on the box for support",
                "Cheating depth by not dropping below",
                "Heel lifting under the depth"
            ],
            timeline: "3-9 months from clean pistol squat.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean elevated pistol squat per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict elevated pistol squat per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict elevated pistol squat per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict elevated pistol squat per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict elevated pistol squat per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.fire-hydrant",
            title: "Fire Hydrant",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "fire hydrant", count: 15),
            primary: [.glutes], secondary: [.core],
            subtitle: "Hip abduction activator.",
            description: "15 fire hydrants per side — on hands and knees, raise one bent leg out to the side, keeping the knee bent at 90°. Targets the glute medius.",
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
            timeline: "Immediate — activation drill.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean fire hydrant per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean fire hydrant per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean fire hydrant per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean fire hydrant per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean fire hydrant per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.single-leg-glute-bridge",
            title: "Single-Leg Glute Bridge",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "single-leg glute bridge", count: 10),
            prereqs: [PrerequisiteGroup("ld.fire-hydrant")],
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
            timeline: "1-3 weeks.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean single-leg glute bridge per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean single-leg glute bridge per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean single-leg glute bridge per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean single-leg glute bridge per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean single-leg glute bridge per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.flying-kickback",
            title: "Fire Kickback",
            cluster: .legDominance, tier: 2, type: .skill,
            target: .reps(exercise: "fire kickback", count: 12),
            prereqs: [PrerequisiteGroup("ld.fire-hydrant")],
            primary: [.glutes], secondary: [.back, .core],
            subtitle: "Explosive glute extension.",
            description: "12 fire kickbacks per side — on hands and knees, drive one leg straight back aggressively, squeeze glute hard, return with control.",
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
            timeline: "Immediate.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean fire kickback per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean fire kickback per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean fire kickback per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean fire kickback per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean fire kickback per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.advancing-nordic-curl",
            title: "Advancing Nordic Curl",
            cluster: .legDominance, tier: 4, type: .skill,
            target: .reps(exercise: "nordic curl", count: 3),
            prereqs: [PrerequisiteGroup("ld.single-leg-rdl")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "The hamstring eccentric destroyer.",
            description: "3 Nordic curls — kneeling with ankles anchored, lower the torso toward the floor with hamstrings, catch with the hands, push back up. Eccentric hamstring dominance.",
            formCues: [
                "Ankles anchored under a bar, bench, or partner",
                "Knees, hips, shoulders stay in one line",
                "Lower as slow as possible — 5s+ descent",
                "Catch with hands, push back up to start"
            ],
            commonMistakes: [
                "Piking at the hips to cheat",
                "Falling the second the hamstrings fatigue",
                "Anchor slipping mid-rep"
            ],
            timeline: "6-18 months from single-leg RDL.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean Nordic curl to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict Nordic curl", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict Nordic curl", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict Nordic curl", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict Nordic curl", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.floor-to-ceiling-squat",
            title: "Floor to Ceiling Squat",
            cluster: .legDominance, tier: 7, type: .skill,
            target: .reps(exercise: "floor to ceiling squat", count: 1),
            prereqs: [PrerequisiteGroup(["ld.jumping-pistol", "ld.advancing-nordic-curl"])],
            isMythic: true,
            primary: [.legs, .glutes], secondary: [.core, .calves],
            subtitle: "From flat on the floor, jump up and touch ceiling.",
            description: "Lie supine on the floor, stand up in one motion, and explode into a jump high enough to touch an 8-foot ceiling. One rep. Full-body explosive power.",
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
            timeline: "5+ years of explosive leg training. Very rare.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean floor to ceiling squat to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict floor to ceiling squat", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict floor to ceiling squat", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict floor to ceiling squat", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict floor to ceiling squat", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // CORE & LEVERS ADDITIONS — crunch variants, plank variants, rings
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "cl.crunch",
            title: "Crunch",
            cluster: .coreLever, tier: 1, type: .skill,
            target: .reps(exercise: "crunch", count: 20),
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
            timeline: "Immediate.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean crunch to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean crunch", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean crunch", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean crunch", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean crunch", xpReward: 250),
            ]
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
            timeline: "1-2 weeks from crunches.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean reverse crunch to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean reverse crunch", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean reverse crunch", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean reverse crunch", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean reverse crunch", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.superman-plank",
            title: "Superman Plank",
            cluster: .coreLever, tier: 3, type: .hold,
            target: .hold(exercise: "superman plank", seconds: 15),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
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
            timeline: "1-4 weeks from 30s plank.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold superman plank for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold superman plank for 15s per side", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 20), criterion: "Hold superman plank for 20s per side", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 30), criterion: "Hold superman plank for 30s per side", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold superman plank for 45s per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.standing-plank",
            title: "Standing Plank",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "standing plank", seconds: 20),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
            equipment: [.bodyweight, .elevatedSurface],
            primary: [.core, .shoulders], secondary: [.back],
            subtitle: "Plank with hands on a bench, feet on floor.",
            description: "20-second inclined plank — forearms on a bench, feet back, body straight. Teaches the plank line with less load before the standing dial-up.",
            formCues: [
                "Forearms flat on the bench, elbows under shoulders",
                "Body straight head to heel",
                "Squeeze glutes to hold the line",
                "Breathe normally"
            ],
            commonMistakes: [
                "Hips sagging toward the floor",
                "Piking up to rest",
                "Holding breath"
            ],
            timeline: "Immediate from plank 30s.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold standing plank for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold standing plank for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold standing plank for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold standing plank for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold standing plank for 45s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.extended-plank",
            title: "Extended Plank",
            cluster: .coreLever, tier: 3, type: .hold,
            target: .hold(exercise: "extended plank", seconds: 15),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
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
            timeline: "2-4 weeks from plank 30s.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold extended plank for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold extended plank for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 20), criterion: "Hold extended plank for 20s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 30), criterion: "Hold extended plank for 30s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold extended plank for 45s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.knee-ab-rollout",
            title: "Knee Ab Rollout",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "ab wheel kneeling", count: 8),
            prereqs: [PrerequisiteGroup("cal.plank-30")],
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
            timeline: "1-4 weeks from solid plank.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean kneeling ab rollout to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict kneeling ab rollout", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict kneeling ab rollout", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict kneeling ab rollout", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict kneeling ab rollout", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.levitation-crunch",
            title: "Levitation Crunch",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "levitation crunch", count: 8),
            prereqs: [PrerequisiteGroup("cl.reverse-crunch")],
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
            timeline: "1-3 months from reverse crunch.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean levitation crunch to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict levitation crunch", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict levitation crunch", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict levitation crunch", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict levitation crunch", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.inverted-situp",
            title: "Inverted Sit-Up",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "inverted sit-up", count: 5),
            prereqs: [PrerequisiteGroup("cl.hanging-leg-raise")],
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
            timeline: "2-6 months from hanging leg raise.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean inverted sit-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict inverted sit-up", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict inverted sit-up", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict inverted sit-up", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict inverted sit-up", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.skin-the-cat",
            title: "Skin the Cat",
            cluster: .coreLever, tier: 4, type: .skill,
            target: .reps(exercise: "skin the cat", count: 3),
            prereqs: [PrerequisiteGroup(["cal.ring-support-10", "cl.hanging-leg-raise"])],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .core, .lats], secondary: [.arms],
            subtitle: "Rings pass-through. Shoulder opener.",
            description: "3 strict skin-the-cats on rings — from a hang, tuck or pike legs overhead, roll through to a german hang, reverse the path back. Shoulder mobility plus core control.",
            formCues: [
                "Start in a dead hang, arms straight",
                "Tuck or pike the legs overhead",
                "Roll through slowly — no dropping into the bottom",
                "Reverse the path back to hang"
            ],
            commonMistakes: [
                "Dropping into the german hang — shoulder shock",
                "Bent arms during the pass-through",
                "Skipping warm-up — shoulders need prep"
            ],
            timeline: "2-6 months from ring support hold.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean skin the cat to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict skin the cat", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict skin the cat", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict skin the cat", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict skin the cat", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.german-hang",
            title: "German Hang",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "german hang", seconds: 10),
            prereqs: [PrerequisiteGroup("cl.skin-the-cat")],
            equipment: [.gymnasticRings],
            primary: [.shoulders, .chest], secondary: [.core, .arms],
            subtitle: "The rings position only mobile shoulders own.",
            description: "10-second hold in the bottom of the skin-the-cat — hanging face down, arms behind the body, shoulders open. Serious shoulder mobility demand.",
            formCues: [
                "Enter slowly through a skin-the-cat",
                "Arms stay straight throughout",
                "Breathe — don't tense the shoulders",
                "Exit the same way you entered"
            ],
            commonMistakes: [
                "Attempting without shoulder warm-up",
                "Bent arms — wrong skill, injury risk",
                "Holding through shoulder pain"
            ],
            timeline: "3-9 months from skin the cat.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold german hang for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold german hang for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold german hang for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 20), criterion: "Hold german hang for 20s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 30), criterion: "Hold german hang for 30s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.three-sixty-pulls",
            title: "360-Degree Pulls",
            cluster: .coreLever, tier: 7, type: .skill,
            target: .reps(exercise: "360-degree pulls", count: 1),
            prereqs: [PrerequisiteGroup(["cl.german-hang", "pp.one-arm-pullup"])],
            isMythic: true,
            equipment: [.gymnasticRings, .pullupBar],
            primary: [.lats, .arms, .core], secondary: [.back, .shoulders],
            subtitle: "Pull, release, rotate 360°, re-grip, pull again.",
            description: "One rep — from a pullup, release with enough height to rotate 360° in the air before re-catching the bar, then continue into the next pullup. Power plus spatial control.",
            formCues: [
                "Explosive enough pullup to clear head and then some",
                "Tuck hard to speed the rotation",
                "Track the bar through the spin",
                "Absorb on re-catch, don't slam to dead hang"
            ],
            commonMistakes: [
                "Missing the re-catch and dropping",
                "Under-rotating and landing sideways",
                "Shrugged shoulders on the re-catch"
            ],
            timeline: "5+ years of dedicated explosive pulling. Very rare.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean 360-degree pulls to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(1), criterion: "1 strict 360-degree pulls", xpReward: 100),
                SkillLevel(level: 3, target: .reps(2), criterion: "2 strict 360-degree pulls", xpReward: 150),
                SkillLevel(level: 4, target: .reps(3), criterion: "3 strict 360-degree pulls", xpReward: 200),
                SkillLevel(level: 5, target: .reps(3), criterion: "3 strict 360-degree pulls", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // HANDBALANCE ADDITIONS — poses, elbow lever, press progressions
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "hs.headstand",
            title: "Headstand",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "headstand", seconds: 30),
            prereqs: [PrerequisiteGroup("hs.wrist-conditioning")],
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
            timeline: "1-4 weeks from wrist conditioning.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold headstand for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold headstand for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold headstand for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold headstand for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold headstand for 45s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.tuck-handstand",
            title: "Tuck Handstand",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "tuck handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.wall-handstand-60")],
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
            timeline: "1-3 months from 60s wall handstand.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold tuck handstand for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold tuck handstand for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold tuck handstand for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold tuck handstand for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold tuck handstand for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.crow-pose",
            title: "Crow Pose",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "crow pose", seconds: 15),
            prereqs: [PrerequisiteGroup("hs.wrist-conditioning")],
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
            timeline: "1-4 weeks from wrist conditioning.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold crow pose for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold crow pose for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold crow pose for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 30), criterion: "Hold crow pose for 30s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold crow pose for 45s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.crane-pose",
            title: "Crane Pose",
            cluster: .handstand, tier: 2, type: .hold,
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
            timeline: "1-3 months from crow pose.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold crane pose for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold crane pose for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold crane pose for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 20), criterion: "Hold crane pose for 20s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 30), criterion: "Hold crane pose for 30s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.frog-pose",
            title: "Frog Pose",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "frog pose", seconds: 15),
            prereqs: [PrerequisiteGroup("hs.wrist-conditioning")],
            primary: [.shoulders, .arms, .core],
            subtitle: "The crow's cousin.",
            description: "15-second frog pose — wide hand stance, knees rest on the outside of the upper arms, feet lift off the floor. Easier balance than crow for some.",
            formCues: [
                "Hands wider than shoulders, fingers spread",
                "Knees out, shins press against the outside of biceps",
                "Shift weight forward until feet float",
                "Keep arms bent ~90° throughout"
            ],
            commonMistakes: [
                "Knees slipping off the arms",
                "Gazing straight down — easier to tip",
                "Fingers not gripping the floor"
            ],
            timeline: "1-4 weeks.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold frog pose for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold frog pose for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold frog pose for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 30), criterion: "Hold frog pose for 30s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold frog pose for 45s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.flying-crow",
            title: "Flying Crow Pose",
            cluster: .handstand, tier: 3, type: .hold,
            target: .hold(exercise: "flying crow", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.crane-pose")],
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
            timeline: "3-9 months from crane.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold flying crow for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold flying crow for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold flying crow for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold flying crow for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold flying crow for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.elbow-lever",
            title: "Elbow Lever",
            cluster: .handstand, tier: 2, type: .hold,
            target: .hold(exercise: "elbow lever", seconds: 10),
            prereqs: [PrerequisiteGroup("hs.wrist-conditioning")],
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
            timeline: "2-8 weeks from wrist conditioning.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 5), criterion: "Hold elbow lever for 5s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 10), criterion: "Hold elbow lever for 10s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 15), criterion: "Hold elbow lever for 15s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 20), criterion: "Hold elbow lever for 20s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 30), criterion: "Hold elbow lever for 30s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.one-arm-elbow-lever",
            title: "One-Arm Elbow Lever",
            cluster: .handstand, tier: 4, type: .hold,
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
            timeline: "6-18 months from elbow lever.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold one-arm elbow lever for 3s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold one-arm elbow lever for 5s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold one-arm elbow lever for 10s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold one-arm elbow lever for 15s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold one-arm elbow lever for 20s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.tuck-press",
            title: "Tuck Press to Handstand",
            cluster: .handstand, tier: 5, type: .skill,
            target: .reps(exercise: "tuck press", count: 3),
            prereqs: [PrerequisiteGroup(["hs.tuck-handstand", "hs.freestanding-hs-30"])],
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
            timeline: "6-18 months from tuck handstand.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean tuck press to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict tuck press", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict tuck press", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict tuck press", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict tuck press", xpReward: 250),
            ]
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
            timeline: "1-3 years from tuck press.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean straddle press to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict straddle press", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict straddle press", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict straddle press", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict straddle press", xpReward: 250),
            ]
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
            timeline: "2-4 years from straddle press.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean press to handstand to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict press to handstand", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict press to handstand", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict press to handstand", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict press to handstand", xpReward: 250),
            ]
        ),

        // ────────────────────────────────────────────────────────────────
        // PLANCHE ADDITIONS — bent arm + half-lay + one-arm (mythic)
        // ────────────────────────────────────────────────────────────────

        .simple(
            id: "pl.bent-arm-planche",
            title: "Bent Arm Planche",
            cluster: .planche, tier: 4, type: .hold,
            target: .hold(exercise: "bent arm planche", seconds: 3),
            prereqs: [PrerequisiteGroup("pl.tuck-planche")],
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
            timeline: "6-18 months from tuck planche.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 1), criterion: "Hold bent arm planche for 1s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 3), criterion: "Hold bent arm planche for 3s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 5), criterion: "Hold bent arm planche for 5s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 8), criterion: "Hold bent arm planche for 8s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 12), criterion: "Hold bent arm planche for 12s, clean form", xpReward: 250),
            ]
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
            description: "3-second half-lay planche — straddle planche with legs narrower than full straddle but wider than closed. The intermediate between straddle and full planche.",
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
            timeline: "6-18 months from straddle planche.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 1), criterion: "Hold half-lay planche for 1s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 3), criterion: "Hold half-lay planche for 3s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 5), criterion: "Hold half-lay planche for 5s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 8), criterion: "Hold half-lay planche for 8s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 12), criterion: "Hold half-lay planche for 12s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "pl.one-arm-planche",
            title: "One-Arm Planche",
            cluster: .planche, tier: 7, type: .hold,
            target: .hold(exercise: "one-arm planche", seconds: 1),
            prereqs: [PrerequisiteGroup("pl.full-planche")],
            isMythic: true,
            equipment: [.parallettes],
            primary: [.shoulders, .core, .chest, .arms],
            subtitle: "Full planche. One arm.",
            description: "One-second one-arm planche — full horizontal planche supported by a single arm. A handful of humans have ever held it cleanly. F-difficulty territory.",
            formCues: [
                "Never attempt without years of rock-solid full planche",
                "Shift weight slowly to one arm, free arm stays off the floor",
                "Body stays horizontal — no compensatory lean",
                "Protract the working shoulder hard"
            ],
            commonMistakes: [
                "Attempting without freakish full planche strength base",
                "Rotating the body to cheat the lever",
                "Any loss of straight-arm position"
            ],
            timeline: "5-10+ years. Fewer than 20 humans hold it cleanly.",
            rank: .s,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 1), criterion: "Hold one-arm planche for 1s per side, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 2), criterion: "Hold one-arm planche for 2s per side, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 3), criterion: "Hold one-arm planche for 3s per side, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 5), criterion: "Hold one-arm planche for 5s per side, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 8), criterion: "Hold one-arm planche for 8s per side, clean form", xpReward: 250),
            ]
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
            timeline: "2-4 weeks for most untrained adults.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean incline rows to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean incline rows", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean incline rows", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean incline rows", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean incline rows", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.decline-row",
            title: "Decline Row",
            cluster: .pullingPower, tier: 2, type: .skill,
            target: .reps(exercise: "decline row", count: 10),
            prereqs: [PrerequisiteGroup("pp.incline-row")],
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
            timeline: "2-6 weeks from incline row.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean decline rows to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean decline rows", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean decline rows", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean decline rows", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean decline rows", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.tuck-row",
            title: "Tuck Row",
            cluster: .pullingPower, tier: 3, type: .skill,
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
            timeline: "2-4 months from decline row.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean tuck rows to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean tuck rows", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean tuck rows", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean tuck rows", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict clean tuck rows", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.straddle-row",
            title: "Straddle Row",
            cluster: .pullingPower, tier: 4, type: .skill,
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
            timeline: "3-6 months from tuck row.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean straddle rows to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 clean straddle rows", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 clean straddle rows", xpReward: 150),
                SkillLevel(level: 4, target: .reps(6), criterion: "6 strict clean straddle rows", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict clean straddle rows", xpReward: 250),
            ]
        ),

        // MARK: Pull — Ascent / Crossover / Solo Arm additions
        .simple(
            id: "pp.heighted-chin-up",
            title: "Heighted Chin-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "heighted chin-up", count: 3),
            prereqs: [PrerequisiteGroup("pp.weighted-chin-up")],
            equipment: [.pullupBar],
            primary: [.lats, .arms], secondary: [.back, .core],
            subtitle: "Bar above the collarbones.",
            description: "Chin-up where you pull the bar below the sternum — collarbones-to-bar or deeper. 3 clean reps. Extra range, extra bicep demand, direct bridge to one-arm chin-up work.",
            formCues: [
                "Explosive pull — build momentum early",
                "Drive elbows down hard to hit the extra ROM",
                "Let the chest rise to the bar, don't crane the neck",
                "Slow eccentric from the top each rep"
            ],
            commonMistakes: [
                "Kipping to buy the extra height",
                "Letting the chin clear the bar and calling it done",
                "Shrugged shoulders at the top"
            ],
            timeline: "3-9 months from weighted chin-up mastery.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean heighted chin-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict heighted chin-ups", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict heighted chin-ups", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict heighted chin-ups", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict heighted chin-ups", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.one-arm-chin-up",
            title: "One-Arm Chin-Up",
            cluster: .pullingPower, tier: 6, type: .skill,
            target: .reps(exercise: "one-arm chin-up", count: 1),
            prereqs: [PrerequisiteGroup(["pp.heighted-chin-up", "pp.oap-negative"])],
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
            timeline: "3-5+ years of dedicated pull work.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean one-arm chin-up per side to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict one-arm chin-ups per side", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict one-arm chin-ups per side", xpReward: 150),
                SkillLevel(level: 4, target: .reps(4), criterion: "4 strict one-arm chin-ups per side", xpReward: 200),
                SkillLevel(level: 5, target: .reps(5), criterion: "5 strict one-arm chin-ups per side", xpReward: 250),
            ]
        ),
        .simple(
            id: "pp.strict-muscle-up",
            title: "Strict Muscle-Up",
            cluster: .pullingPower, tier: 5, type: .skill,
            target: .reps(exercise: "strict muscle-up", count: 1),
            prereqs: [PrerequisiteGroup("pp.muscle-up")],
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
            timeline: "6-18 months from first muscle-up.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean strict muscle-up to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict muscle-ups", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict muscle-ups", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict muscle-ups", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict muscle-ups", xpReward: 250),
            ]
        ),

        // MARK: Push — Bent Arm Press (distinct from Bent Arm Planche)
        .simple(
            id: "cal.bent-arm-press",
            title: "Bent Arm Press",
            cluster: .calisthenicControl, tier: 4, type: .skill,
            target: .reps(exercise: "bent arm press", count: 3),
            prereqs: [PrerequisiteGroup("hspu.elevated-pike-pushup-10")],
            primary: [.shoulders, .arms], secondary: [.core, .chest],
            subtitle: "Vertical press without a wall.",
            description: "Standing strict overhead press of your full bodyweight equivalent via a bent-arm press pattern — from a pike/elevated pike start, press up through bent arms to full overhead lockout. 3 reps. Bridge between elevated pike work and freestanding HSPU strength.",
            formCues: [
                "Start in an elevated pike — hands planted wide",
                "Press through the bent arms with control",
                "Lock out overhead with ribs tucked and core tight",
                "Keep the path vertical, not drifting forward"
            ],
            commonMistakes: [
                "Using momentum from a jump instead of pressing",
                "Arching through the lumbar to lock out",
                "Soft lockout — elbows not fully extended"
            ],
            timeline: "3-9 months from elevated pike push-up.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean bent arm press to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict bent arm presses", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict bent arm presses", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict bent arm presses", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict bent arm presses", xpReward: 250),
            ]
        ),

        // MARK: Legs — Foundation gap nodes
        .simple(
            id: "ld.step-up",
            title: "Step Up",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "step up", count: 15),
            equipment: [.elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "The most skipped entry.",
            description: "Step up onto a knee-height box, drive through the heel, control the descent. 15 reps per leg. Hidden gold for quad/glute strength and single-leg control without needing pistol-level mobility.",
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
            timeline: "Immediate.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean step ups per leg to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean step ups per leg", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean step ups per leg", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean step ups per leg", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean step ups per leg", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.deep-squat",
            title: "Deep Squat",
            cluster: .legDominance, tier: 1, type: .hold,
            target: .hold(exercise: "deep squat", seconds: 60),
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "The squat your body forgot.",
            description: "Sit in a full-depth bodyweight squat — hips below knees, feet flat, chest up — for 60 seconds. Ankle, hip, and knee mobility floor that every squat progression depends on.",
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
            timeline: "Immediate to 6 weeks for rusty adults.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold deep squat for 10s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold deep squat for 20s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold deep squat for 30s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold Hold deep squat for 2 minutes for 45s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold Hold deep squat for 5 minutes for 60s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.glute-bridge",
            title: "Glute Bridge",
            cluster: .legDominance, tier: 1, type: .skill,
            target: .reps(exercise: "glute bridge", count: 15),
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
            timeline: "Immediate.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean glute bridges with top squeeze to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean glute bridges", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean glute bridges", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean glute bridges", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean glute bridges unbroken", xpReward: 250),
            ]
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
            timeline: "3-6 months from bodyweight BSS mastery.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .weight(multiplier: 0.25), criterion: "0.25x bw weighted BSS per leg, 8 reps", xpReward: 50),
                SkillLevel(level: 2, target: .weight(multiplier: 0.35), criterion: "0.35x bw weighted BSS per leg, 8 reps", xpReward: 100),
                SkillLevel(level: 3, target: .weight(multiplier: 0.5), criterion: "0.5x bw weighted BSS per leg, 8 reps", xpReward: 150),
                SkillLevel(level: 4, target: .weight(multiplier: 0.65), criterion: "0.65x bw weighted BSS per leg, 8 reps", xpReward: 200),
                SkillLevel(level: 5, target: .weight(multiplier: 0.8), criterion: "0.8x bw weighted BSS per leg, 8 reps", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.sissy-squat",
            title: "Sissy Squat",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "sissy squat", count: 8),
            prereqs: [PrerequisiteGroup("ld.goblet-20")],
            primary: [.legs], secondary: [.core],
            subtitle: "Pure quad isolation.",
            description: "Lean back, bend at the knees only (hips stay extended), drop the heels — torso, hips, and knees stay in a straight line. 8 reps. The brutal quad-only movement that gym bros sleep on.",
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
            timeline: "4-8 weeks of quad-specific work.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean sissy squats to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean sissy squats", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean sissy squats", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean sissy squats", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict clean sissy squats", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.nordic-hip-hinge",
            title: "Nordic Hip Hinge",
            cluster: .legDominance, tier: 3, type: .skill,
            target: .reps(exercise: "nordic hip hinge", count: 8),
            prereqs: [PrerequisiteGroup("ld.single-leg-rdl")],
            equipment: [.elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "Hamstrings meet hip hinge.",
            description: "Kneeling hip hinge with feet anchored — lean forward from the knees, hinge at the hips mid-rep, then return. 8 reps. The on-ramp to the full Nordic curl that teaches the exact motor pattern.",
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
            timeline: "2-6 weeks from single-leg RDL.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean nordic hip hinges to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean nordic hip hinges", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean nordic hip hinges", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean nordic hip hinges", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean nordic hip hinges", xpReward: 250),
            ]
        ),
        .simple(
            id: "ld.nordic-curl",
            title: "Nordic Curl",
            cluster: .legDominance, tier: 5, type: .skill,
            target: .reps(exercise: "nordic curl", count: 3),
            prereqs: [PrerequisiteGroup("ld.advancing-nordic-curl")],
            equipment: [.elevatedSurface],
            primary: [.legs, .glutes], secondary: [.core],
            subtitle: "The hamstring holy grail.",
            description: "Kneeling, ankles anchored, lower the torso to the floor using only hamstring strength — then pull yourself back up with no hand assist. 3 clean reps. The hardest bodyweight hamstring move in existence.",
            formCues: [
                "Ankles and calves fully anchored",
                "Body rigid — straight line from knees to head",
                "Slow the descent all the way down",
                "Drive up using hamstrings only — hands only catch a failure"
            ],
            commonMistakes: [
                "Pushing off with the hands (that's advancing nordic curl)",
                "Breaking at the hips to cheat",
                "Dropping the last 6 inches of descent"
            ],
            timeline: "1-3 years from advancing nordic curl.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean nordic curl to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(2), criterion: "2 strict nordic curls", xpReward: 100),
                SkillLevel(level: 3, target: .reps(3), criterion: "3 strict nordic curls", xpReward: 150),
                SkillLevel(level: 4, target: .reps(5), criterion: "5 strict nordic curls", xpReward: 200),
                SkillLevel(level: 5, target: .reps(8), criterion: "8 strict nordic curls", xpReward: 250),
            ]
        ),

        // MARK: Core — Spine/Raised gap nodes
        .simple(
            id: "cl.straight-crunch",
            title: "Straight Crunch",
            cluster: .coreLever, tier: 1, type: .skill,
            target: .reps(exercise: "straight crunch", count: 20),
            primary: [.core],
            subtitle: "Legs locked, abs only.",
            description: "Crunch performed with legs fully extended and heels hovering just off the floor. 20 reps. The hip-flexor-off variant that isolates the rectus abdominis.",
            formCues: [
                "Legs locked straight, heels 2 inches off floor",
                "Crunch the rib cage toward the pelvis",
                "Don't pull on the neck",
                "Lower with control — don't slam"
            ],
            commonMistakes: [
                "Feet touching floor — kills the ab demand",
                "Yanking the head with the hands",
                "Bending knees to make it easier"
            ],
            timeline: "Immediate.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean straight crunches to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(5), criterion: "5 strict clean straight crunches", xpReward: 100),
                SkillLevel(level: 3, target: .reps(8), criterion: "8 strict clean straight crunches", xpReward: 150),
                SkillLevel(level: 4, target: .reps(12), criterion: "12 strict clean straight crunches", xpReward: 200),
                SkillLevel(level: 5, target: .reps(15), criterion: "15 strict clean straight crunches", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.bird-dog-plank",
            title: "Bird Dog Plank",
            cluster: .coreLever, tier: 2, type: .hold,
            target: .hold(exercise: "bird dog plank", seconds: 30),
            prereqs: [PrerequisiteGroup("cl.hollow-body-30")],
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
            timeline: "2-6 weeks from plank.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 8), criterion: "Hold bird dog plank for 8s, clean form", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 15), criterion: "Hold bird dog plank for 15s, clean form", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 22), criterion: "Hold bird dog plank for 22s, clean form", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 34), criterion: "Hold bird dog plank for 34s, clean form", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 45), criterion: "Hold bird dog plank for 45s, clean form", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.v-sit",
            title: "V-Sit",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "v-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.l-sit-20")],
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
            timeline: "6-18 months from clean L-sit.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold V-sit for 3s, legs above horizontal", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold V-sit for 5s, legs above horizontal", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold V-sit for 10s, legs above horizontal", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold V-sit for 15s, legs above horizontal", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold V-sit for 20s, legs above horizontal", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.straddle-l-sit",
            title: "Straddle L-Sit",
            cluster: .coreLever, tier: 4, type: .hold,
            target: .hold(exercise: "straddle l-sit", seconds: 10),
            prereqs: [PrerequisiteGroup("cal.l-sit-20")],
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
            timeline: "6-12 months from clean L-sit.",
            rank: .b,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 3), criterion: "Hold straddle L-sit for 3s", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 5), criterion: "Hold straddle L-sit for 5s", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 10), criterion: "Hold straddle L-sit for 10s", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 15), criterion: "Hold straddle L-sit for 15s", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 20), criterion: "Hold straddle L-sit for 20s", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.dragon-flag-hip-raise",
            title: "Dragon Flag Hip Raise",
            cluster: .coreLever, tier: 3, type: .skill,
            target: .reps(exercise: "dragon flag hip raise", count: 8),
            prereqs: [PrerequisiteGroup("cl.dragon-flag-negative")],
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
            timeline: "2-4 months from dragon flag negative.",
            rank: .c,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean dragon flag hip raises to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean dragon flag hip raises", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean dragon flag hip raises", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean dragon flag hip raises", xpReward: 200),
                SkillLevel(level: 5, target: .reps(10), criterion: "10 strict clean dragon flag hip raises", xpReward: 250),
            ]
        ),
        .simple(
            id: "cl.decline-situp",
            title: "Decline Sit-Up",
            cluster: .coreLever, tier: 2, type: .skill,
            target: .reps(exercise: "decline sit-up", count: 15),
            prereqs: [PrerequisiteGroup("cl.crunch")],
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
            timeline: "2-4 weeks from crunch.",
            rank: .d,
            levels: [
                SkillLevel(level: 1, target: .firstRep, criterion: "First clean clean decline sit-ups to standard", xpReward: 50),
                SkillLevel(level: 2, target: .reps(3), criterion: "3 strict clean decline sit-ups", xpReward: 100),
                SkillLevel(level: 3, target: .reps(5), criterion: "5 strict clean decline sit-ups", xpReward: 150),
                SkillLevel(level: 4, target: .reps(8), criterion: "8 strict clean decline sit-ups", xpReward: 200),
                SkillLevel(level: 5, target: .reps(12), criterion: "12 strict clean decline sit-ups", xpReward: 250),
            ]
        ),

        // MARK: Handstand — Wall Path gaps
        .simple(
            id: "hs.wall-plank",
            title: "Wall Plank",
            cluster: .handstand, tier: 1, type: .hold,
            target: .hold(exercise: "wall plank", seconds: 30),
            primary: [.shoulders, .core], secondary: [.arms],
            subtitle: "Handstand starts horizontal.",
            description: "Plank position with feet walked up the wall until the body is vertical — a pseudo-handstand with the wall doing the balance work. 30 seconds. The starting point for every handstand progression.",
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
            timeline: "Immediate to 2 weeks.",
            rank: .e,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 10), criterion: "Hold wall plank for 10s, shoulders stacked", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 20), criterion: "Hold wall plank for 20s", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 30), criterion: "Hold wall plank for 30s", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 45), criterion: "Hold wall plank for 45s", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 60), criterion: "Hold wall plank for 60s", xpReward: 250),
            ]
        ),
        .simple(
            id: "hs.wall-supported-oah",
            title: "Wall Supported One-Arm Handstand",
            cluster: .handstand, tier: 6, type: .hold,
            target: .hold(exercise: "wall-supported one-arm handstand", seconds: 5),
            prereqs: [PrerequisiteGroup("hs.freestanding-hs-60")],
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
            timeline: "1-2 years from freestanding handstand.",
            rank: .a,
            levels: [
                SkillLevel(level: 1, target: .hold(seconds: 2), criterion: "Hold wall-supported one-arm handstand 2s per side", xpReward: 50),
                SkillLevel(level: 2, target: .hold(seconds: 3), criterion: "Hold wall-supported one-arm handstand 3s per side", xpReward: 100),
                SkillLevel(level: 3, target: .hold(seconds: 5), criterion: "Hold wall-supported one-arm handstand 5s per side", xpReward: 150),
                SkillLevel(level: 4, target: .hold(seconds: 8), criterion: "Hold wall-supported one-arm handstand 8s per side", xpReward: 200),
                SkillLevel(level: 5, target: .hold(seconds: 12), criterion: "Hold wall-supported one-arm handstand 12s per side", xpReward: 250),
            ]
        ),
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
