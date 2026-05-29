# UNBOUND — Architecture Map

**Start here.** This is the one-screen index of how the app's progression model fits together: each subsystem → its current source-of-truth in code → the planned deep-dive doc. It exists so a future traversal references one map instead of re-discovering the maze.

> Status (2026-05-29): mid–ONE-METRIC-cleanup (see `ONE-METRIC-CLEANUP-PLAN.md` + `ONE-METRIC-EXECUTION-LOG.md`). The `architecture/*.md` deep-dives are **planned, not yet written** — until they exist, the linked **code** is the source of truth. Doc links are marked ⏳ when pending.

## The metric model in one breath
One **rank** per movement/skill = `RankTier` (Initiate→Ascendant, 0–8). One **LVL** = AP-derived `OverallLevel` (total work). **Streak** = consistency. **Attributes** = the hex (one number/axis). **Recovery** = `MuscleHeatGroup` (NOT a rank). Everything else that scored a movement is being deleted.

## Subsystem → code → doc

| Subsystem | What it owns | Source-of-truth in code | Deep-dive doc |
|---|---|---|---|
| **Ranking** | `RankTier` = the one ladder; per-lift/rep/hold rank; the aggregate rank | `Models/SkillTier.swift` (`RankTier`), `Services/Ranking/RankService.swift` (`aggregateRank`, lift/rep/hold rank), `Services/Ranking/ProofEngine.swift` | ⏳ `architecture/ranking.md` |
| **Skills (tree)** | skill nodes, unlock gating, proven/locked state | `Models/SkillTree.swift`, `Models/SkillTreeContent.swift`, `Services/SkillProgress/SkillProgressService.swift` | ⏳ `architecture/skills.md` |
| **Movements / standards** | exercise catalog + strength standards → rank | `Models/StrengthStandards.swift`, `Models/MovementProgress.swift` | ⏳ `architecture/movements.md` |
| **Progression engine** | program / arc / checkpoint / auto-deload ingest | `Services/Progression/ProgressionEngine.swift`, `Services/Progression/MovementProgressService.swift`, `Services/Progression/AutoDeloadService*` | ⏳ `architecture/progression.md` |
| **Logging (the ONE ingest)** | what a finished workout updates | `Services/TrainingCompletionService.swift` → **`complete()`** (canonical). Modern callers: ProgramViewModel, SkillSessionView, SkillDetailView, LogCardioView, ActiveWorkoutContainerView, ProgramOverviewView. ⚠️ legacy `WorkoutLoggingView` → `recordProgressionForLegacyWorkout` is side-effect-free (Blocker B1). | ⏳ `architecture/logging.md` |
| **Levels (LVL)** | overall level from total XP + streak | `Models/MovementProgress.swift` (`OverallLevelProgress`, `OverallLevelCurve`), `OverallLevelService` (in `MovementProgressService.swift`), `Services/Ranking/SessionXPService.swift` (streak) | ⏳ `architecture/levels.md` |
| **Attributes (hex)** | one number/axis, grow-from-tiny, maxable | `Models/AttributeValue.swift`, `Services/Attributes/AttributeService.swift`, `Services/Attributes/AttributeIngest.swift` | ⏳ `architecture/attributes.md` |
| **Recovery / muscle status** | how trained/recovered a muscle is (NOT a rank) | `Models/MuscleHeatGroup.swift` | ⏳ `architecture/recovery.md` |

## Where the cleanup stands
| | Shipped |
|---|---|
| Dead E–S muscle-rank trio (`MuscleGroupTier*`) + 336KB stale dupe | `212a40c` |
| **Phase 1 — one LVL** (display = AP-derived `OverallLevel`; `unbound.gains` deleted) | `b0dbbf4` |
| **D1** — photos/scans/routines grant a bit of LVL via `OverallLevel` | `4602491` |

**Still entangled / decision-gated:** `SubRank` (18→9 cadence + test-oracle coupling, Phase 2/B2), bodyweight-relative standards from StrengthLevel (Phase 3/B3), hex curve (Phase 5/B4), AP→XP + "% to next rank" (Phase 6, depends on Phase 3), Ascension ceremony (Phase 7/B5). See `ONE-METRIC-EXECUTION-LOG.md` for the live status + verified specs.

## Conventions
- One subsystem → one current doc. When a subsystem changes, update its row here + its deep-dive in the same commit; delete any doc it supersedes (git is the archive).
- `RankTier` is the only "how good" scale. If you find code ranking a movement on anything else, it's a cleanup target, not a pattern to copy.
