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
        "cl.straddle-l-sit":       "Raised Work",

        "cl.dragon-flag":          "Flag Path",
        "cl.dragon-flag-hip-raise": "Flag Path",

        "cl.tuck-front-lever":     "Front Lever",
        "cl.straddle-front-lever": "Front Lever",
        "cl.full-front-lever":     "Front Lever",

        "cl.tuck-back-lever":      "Back Lever",
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
    ]
}

// MARK: - All v3 nodes

import Foundation

extension SkillGraph {
    static let v3Nodes: [SkillNode] =
        v3LegDominanceNodes
        + v3PullingPowerNodes
        + v3CalisthenicFoundationNodes
        + v3StrengthGapNodes
        + v3CarryMobilityNodes
        + v3CoreLeverAdditionNodes
        + v3HandbalanceAdditionNodes
        + v3PlancheAdditionNodes
        + v3PullAdditionNodes
        + v3PushLegGapNodes
        + v3CoreHierarchyAdditionNodes
        + v3HandstandWallPathNodes
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
