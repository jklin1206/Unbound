# UNBOUND Architecture Map

Start here for product architecture. This page maps each subsystem to the active code owner and the current deep-dive doc, so a reviewer does not have to rediscover the maze from old plans.

For repository layout, generated artifacts, and legacy-code hygiene, start with [FILE_STRUCTURE.md](FILE_STRUCTURE.md).

For the current three-agent simplification review and roadmap, read [SIMPLIFICATION-AUDIT.md](SIMPLIFICATION-AUDIT.md).

## The Product Loop

UNBOUND is: collect intent -> prescribe training -> record proof -> award progress -> make tomorrow better -> connect the user to their squad.

## The Metric Model

| Signal | Meaning | Source of truth |
| --- | --- | --- |
| Rank | How good the user is at a movement/skill | `RankTier`, `RankService`, `StrengthStandards` |
| LVL | Total training effort over time | `OverallLevelProgress`, `OverallLevelService` |
| Streak | Consistency | `SessionXPService` |
| Attributes | Six-axis hex from completed work | `AttributeValue`, `AttributeService`, `AttributeIngest` |
| Recovery | Muscle status, not rank | `MuscleHeatGroup` |

Legacy note: some internal symbols still say AP (`rawAP`, `MovementAPGain`) because the work ledger predates the XP naming pass. User-facing language should be XP/LVL/rank; AP wording is a cleanup target, not a new pattern.

## Subsystem Map

| Subsystem | What it owns | Active code | Deep-dive |
| --- | --- | --- | --- |
| App shell | launch, auth routing, onboarding/home handoff, foreground work | `UNBOUND/App/UnboundApp.swift`, `UNBOUND/App/AppDelegate.swift` | [FILE_STRUCTURE.md](FILE_STRUCTURE.md) |
| Ranking | movement rank, skill proof, aggregate rank | `UNBOUND/Models/SkillTier.swift`, `UNBOUND/Models/StrengthStandards.swift`, `UNBOUND/Services/Ranking/` | [ranking.md](architecture/ranking.md) |
| Skills | graph nodes, prerequisites, placement difficulty, proven state | `UNBOUND/Models/SkillTree.swift`, `UNBOUND/Models/SkillTreeContent.swift`, `UNBOUND/Services/SkillProgress/` | [skills.md](architecture/skills.md) |
| Movements | exercise catalog, rank templates, movement standards | `UNBOUND/Models/MovementCatalog.swift`, `UNBOUND/Models/ExerciseCatalog.swift`, `UNBOUND/Models/MovementProgress.swift` | [movements.md](architecture/movements.md) |
| Logging | the one completion ingest path and reward receipt inputs | `UNBOUND/Services/TrainingCompletionService.swift` | [logging.md](architecture/logging.md) |
| Progression | program state, deloads, movement progress, generated plans | `UNBOUND/Services/Progression/`, `UNBOUND/Services/ProgramGeneration/`, `UNBOUND/Services/Program/` | [progression.md](architecture/progression.md) |
| Levels | LVL curve, level XP, streak | `UNBOUND/Models/MovementProgress.swift`, `UNBOUND/Services/Progression/MovementProgressService.swift`, `UNBOUND/Services/Ranking/SessionXPService.swift` | [levels.md](architecture/levels.md) |
| Attributes | hex XP, level curve, reward deltas | `UNBOUND/Models/AttributeValue.swift`, `UNBOUND/Services/Attributes/` | [attributes.md](architecture/attributes.md) |
| Recovery | trained/recovered muscle state | `UNBOUND/Models/MuscleHeatGroup.swift` | [recovery.md](architecture/recovery.md) |
| Rewards | post-workout summary and cinematic sequence | `UNBOUND/Models/WorkoutRewardSequence.swift`, `UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView.swift`, `UNBOUND/Views/Components/Unbound/WorkoutRewardComponents.swift` | [logging.md](architecture/logging.md) |
| Sync | field-level merge, outbox, Supabase transport | `UNBOUND/Services/Sync/`, `supabase/` | [FILE_STRUCTURE.md](FILE_STRUCTURE.md) |
| Squads | missions, feed, chat, friend challenges, honors | `UNBOUND/Services/Squads/`, `UNBOUND/Models/Squad*.swift`, `UNBOUND/Models/FriendChallenge.swift` | [squads.md](architecture/squads.md) |

## Current Simplification Backlog

| Lane | What remains | Proof |
| --- | --- | --- |
| Reward language | Finish AP-to-XP naming and show per-exercise `+X XP` plus `% to next rank` in the reward flow. | Completion/reward tests plus simulator reward walkthrough. |
| UI boundaries | Finish typed routing in Program and Home. Skill Detail, Settings debug tools, Program focus/ranks, and Reward visual components now have named file boundaries. | Focused UI model tests where possible, then simulator smoke. |
| Domain boundaries | Keep safety behavior but name rule owners: completion receipt store, movement ledger, reward receipt builder, scan cadence policy. | Idempotency and replay tests stay green. |
| Repo truth | Keep active source under active folders, archive old platforms under `docs/legacy/`, keep this map current. | `rg` for old paths/names should only hit legacy or dated docs. |

## Rules

- Views render snapshots and send typed commands. They should not own persistence, reward math, or generated content libraries.
- Services own one rule family. If a service needs "also" in its one-sentence description, split the rule owner.
- Catalogs define data. Resolvers, validators, and legacy bridges get named files.
- Historical docs are context, not instructions. Current code plus this map wins.
- Every simplification pass updates the relevant `architecture/*.md` doc and the test map when ownership changes.
