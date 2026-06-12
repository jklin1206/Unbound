# Models/Skills

Skill-tree graph, tier ladder, training plans, and per-user progress state: everything needed to represent, evaluate, and coach the bodyweight skill progression system.

| File | Purpose |
|------|---------|
| `ExerciseExplainerLibrary.swift` | Static lookup table of one-sentence exercise descriptions and form cues shown in the in-session explainer modal |
| `SkillBlockKind.swift` | `SkillBlockKind` enum (primer / main / accessory / mobility) tagging how a skill block fits inside a session |
| `SkillCluster.swift` | `SkillCluster` enum — the six regions of the unified skill graph (Pull, Push, Legs, Core, Handstand, Planche) |
| `SkillDisplayTree.swift` | `SkillDisplayTree` enum — the top-level trees shown on the Skill Map landing screen, each mapping to one or more clusters |
| `SkillEquipment.swift` | `SkillEquipment` enum — badge metadata declaring what gear each skill node requires |
| `SkillTier.swift` | Canonical 9-tier ladder (Initiate → Ascendant) used for per-skill tiers, attribute rank titles, and overall rank; custom Codable handles legacy Int and String forms |
| `SkillTierGenerator.swift` | `SkillTierGenerator` — generates a full 9-tier `[SkillTier: TierCriterion]` ladder from real anchor points using `.full` (grind) or `.feat` (hard-feat floor) shapes |
| `SkillTree.swift` | Core skill graph model (v3): `SkillGraph`, `SkillNode`, `PrerequisiteGroup` with OR/AND prerequisite logic and two stored states (locked → proven) |
| `SkillTreeContent.swift` | `SkillGraph.shared` singleton — all ~60 authored nodes across 6 clusters, including keystones and mythic nodes |
| `SkillTreeSkin.swift` | `SkillTreeSkin` enum — cosmetic themes for the skill-tree UI (colors, rail styles, node fills) unlocked via the tier ladder |
| `SkillTrainingPlanLibrary.swift` | `SkillTrainingPlanLibrary` — base type + `plan(for:)` dispatcher routing skill ids to authored training plans |
| `SkillTrainingPlanLibrary+Core.swift` | Core/lever skill training plans (plank, L-sit, front lever, back lever, etc.) |
| `SkillTrainingPlanLibrary+Handstand.swift` | Handstand path training plans (wall hold, kick-up, freestanding, press, etc.) |
| `SkillTrainingPlanLibrary+Legs.swift` | Leg-dominance skill training plans (pistol squat, Nordic, shrimp squat, etc.) |
| `SkillTrainingPlanLibrary+Planche.swift` | Planche path training plans (planche lean, tuck, straddle, full, etc.) |
| `SkillTrainingPlanLibrary+Pull.swift` | Pull-power skill training plans (pull-up, muscle-up, one-arm progressions, etc.) |
| `SkillTrainingPlanLibrary+Push.swift` | Push/calisthenic-control skill training plans (push-up, dip, HSPU, etc.) |
| `SkillTrainingReviewAgent.swift` | `SkillTrainingReviewAgent` — evaluates a `PerformanceLog` to produce `SkillTrainingAgentReview` ratings (clean ratio, completion, RPE) |
| `SkillTrainingReviewStore.swift` | `@MainActor` singleton cache for the latest `SkillTrainingAgentReview` per user/skill, backed by the database service |
| `SkillUnlockStandards.swift` | `SkillUnlockRequirement` — defines the minimum tier a prerequisite skill must reach before a dependent node unlocks |
| `TierCriterion.swift` | `TierCriterion` — typed criteria (reps, seconds, weight, bw ratio, variant, compound AND) evaluated by `TierCriterionEvaluator` |
| `UserSkillProgress.swift` | `UserSkillProgress` — per-user node states (locked/proven), proven timestamps, and bookmarks; sole write target is `SkillProgressService` |
| `UserSkillTierState.swift` | `UserSkillTierState` — per-user per-skill tier map plus macro counters (rank-ups earned, ascendant skills) for the profile surface |
| `SkillTrainingPlan.swift` | `SkillTrainingPlan`, `TrainingExercise`, `TrainingPrescription` — value types describing the regression/main/accessory structure of one authored plan |
| `SkillRungResolver.swift` | `SkillRungResolver` — picks the right training rung (regression vs direct) given a skill id, trainability flag, and optional last review |

## Where to find X

| Task | File |
|------|------|
| Look up a skill node, its prerequisites, or cluster membership | `SkillTree.swift` / `SkillTreeContent.swift` |
| Get or generate the 9-tier criterion ladder for a skill | `SkillTierGenerator.swift` / `TierCriterion.swift` |
| Read or update a user's proven nodes and bookmarks | `UserSkillProgress.swift` |
| Find the training plan (regressions + main sets) for a skill | `SkillTrainingPlanLibrary.swift` + the relevant family extension |
| Evaluate how well a user trained a skill last session | `SkillTrainingReviewAgent.swift` |
| Determine what tier a user's skill is at | `UserSkillTierState.swift` / `SkillTier.swift` |
