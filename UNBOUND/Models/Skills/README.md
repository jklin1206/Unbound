# Models/Skills

Skill-system model layer: the unified skill graph and its content, the canonical 9-tier rank ladder and per-tier criteria, per-user skill progress/tier state, and the authored skill-training plans plus the rung-selection/review machinery that runs them. (Generated per-family tier tables live in the sibling `Models/SkillTreeContent/` directory.)

## Files

| File | What it is |
|---|---|
| `ExerciseExplainerLibrary.swift` | One-sentence "what is this exercise?" copy + form cues for the in-session explainer modal, keyed by exercise name as authored in `SkillTrainingPlanLibrary`. |
| `SessionLog.swift` | `SessionLog`/`LoggedExercise`/`LoggedSet` — persisted log of a skill training session (skill id, selected rung, exercises, XP). |
| `SkillBlockKind.swift` | `SkillBlockKind` — block kinds within a skill session: primer / main / accessory / mobility. |
| `SkillCluster.swift` | `SkillCluster` — the regions of the unified skill graph; every node belongs to exactly one cluster. |
| `SkillDisplayTree.swift` | `SkillDisplayTree` — the top-level trees on the Skill Map landing screen (pull/push/legs/coreLevers/handstand/...), each mapping to clusters + display copy. |
| `SkillEquipment.swift` | `SkillEquipment` enum + `UserSkillEquipmentProfile` — equipment availability for skill training. |
| `SkillRungResolver.swift` | `SkillRungResolver.resolve(...)` — picks the training rung (direct vs regression) for a skill from its plan, trainability, and last agent review. |
| `SkillTier.swift` | The canonical 9-tier ladder (Initiate → Ascendant) — the one rank/tier type for the whole app; merged the former `SkillTier` (Int) and `RankTitle` (String) enums, old names kept as typealiases. |
| `SkillTierGenerator.swift` | `SkillAnchor` + `SkillTierGenerator` — generates a skill's full 9-tier `[SkillTier: TierCriterion]` ladder from a few real anchors; `.full` (grind moves) and `.feat` (floor-rank hard feats) shapes. |
| `SkillTrainingPlan.swift` | `SkillTrainingPlan` (regressions / mainSets / accessories) + `TrainingExercise`, `TrainingPrescription`, rung-source/decision and `SkillTrainingAgentReview` types. |
| `SkillTrainingPlanLibrary.swift` | `SkillTrainingPlanLibrary` — authored, hand-tuned training plans for keystone skills; content rules + shared lookup, family tables live in the `+Family` extensions. |
| `SkillTrainingPlanLibrary+Core.swift` | Core-family authored plans (extension of `SkillTrainingPlanLibrary`). |
| `SkillTrainingPlanLibrary+Handstand.swift` | Handstand-family authored plans. |
| `SkillTrainingPlanLibrary+Legs.swift` | Legs-family authored plans. |
| `SkillTrainingPlanLibrary+Planche.swift` | Planche-family authored plans. |
| `SkillTrainingPlanLibrary+Pull.swift` | Pull-family authored plans. |
| `SkillTrainingPlanLibrary+Push.swift` | Push-family authored plans. |
| `SkillTrainingReviewAgent.swift` | `SkillTrainingReviewAgent.evaluate(performanceLog:)` — scores a session's skill blocks (clean-set / completion ratios) into `SkillTrainingAgentReview`s. |
| `SkillTrainingReviewStore.swift` | `@MainActor SkillTrainingReviewStore` — cache + database fetch/persist of the latest agent review per user+skill. |
| `SkillTree.swift` | Skill graph model v3: `NodeType`, `NodeState` (locked → proven), `SkillGraph`, OR-logic prerequisite groups, plus the legacy `SkillTree` compatibility view. |
| `SkillTreeContent.swift` | `SkillGraph.shared` — single source of truth for the unified graph content (~60 nodes across 6 clusters) + `SkillSubChapterMap`. |
| `SkillTreeSkin.swift` | `SkillTreeSkin` — cosmetic themes for the skill-tree UI (rails, node fills, rings, share cards); unlocks track the named `SkillTier` ladder. |
| `SkillUnlockStandards.swift` | `SkillUnlockRequirement`/`Group` + `SkillUnlockStandards` — how *owned* (which tier) a prerequisite skill must be before a node unlocks. |
| `TierCriterion.swift` | `TierCriterion` — typed per-tier criterion shapes (reps, seconds, weight, bw ratio, variant, compound AND); exercise-name lookups must use space-lowercase catalog names. |
| `UserSkillProgress.swift` | `UserSkillProgress` — per-user node states + first-proven timestamps + bookmarked node ids; `SkillProgressService` is the only writer. |
| `UserSkillTierState.swift` | `UserSkillTierState` — per-user persisted per-skill current tier + macro counters; absent skills default to `.initiate`. |

## Where to find X

- **The skill graph's nodes and prerequisites:** structure in `SkillTree.swift`, actual content in `SkillTreeContent.swift` (sub-chapter map applied on top); per-family tier criteria tables are in `../SkillTreeContent/`
- **The 9 rank names and tier math:** `SkillTier.swift`; per-tier requirements in `TierCriterion.swift`; ladder generation from anchors in `SkillTierGenerator.swift`
- **What a user has proven / what tier they hold:** `UserSkillProgress.swift` (node states), `UserSkillTierState.swift` (per-skill tier)
- **What unlocks a node (beyond graph edges):** `SkillUnlockStandards.swift`
- **The TRAIN flow for a skill (plan → rung → session → review):** `SkillTrainingPlanLibrary*.swift` → `SkillRungResolver.swift` → `SessionLog.swift` → `SkillTrainingReviewAgent.swift` / `SkillTrainingReviewStore.swift`
- **Landing-screen tree list and skill-tree theming:** `SkillDisplayTree.swift`, `SkillTreeSkin.swift`
