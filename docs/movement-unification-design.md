# Movement Unification Design

One physical movement is currently modelled by up to four separate records with four ids and (sometimes) three different names.
This doc is the checkpoint artifact for collapsing that duplication into one canonical identity, one name, and one rank/XP ledger per movement.
Ground truth comes from `MovementFoldMapDumpTests` -> `docs/asset-sets/movement-fold-map.json` (the real `movementFoldsIntoShownSkill` logic, not a hand-guessed list).

## Goal

Logging a movement from any surface - library exercise, skill drill, or skill block - advances the one rank the user sees, shows one name everywhere, and banks into one XP ledger.
No user-visible (or persisted) duplication of the same movement.

## Current state

A single movement (hollow body) exists as four records:
- `exercise.hollow-hold` (canonical loggable exercise, "Hollow Hold")
- `cl.hollow-body-30` (skill-tree node, the rank source, "Hollow Body")
- `skill-drill.hollow-body-hold` (drill / plan step, "Hollow Body Hold")
- `skill.cl.hollow-body-30` (auto-derived skill-target wrapper, `rankable: false`)

Already unified earlier this session: logging any surface advances the displayed tier (`evaluateTierCrossings` wired into `TrainingCompletionService.completeOnce`, cross-surface matching via `owningSkillId` in `MovementProofMatcher`).

Still fragmented:
1. Names diverge for a few true twins (the user's "multiple names" complaint).
2. The XP / `movement_progress` ledger still keys per id, so the same skill banks AP into separate rows depending on which surface logged it.
3. The authoritative join is incomplete: `exerciseSkillTwins` has one entry (hollow); other families work only by name coincidence.

## The distinction that drives everything: true twin vs regression

The fold groups two very different things under one skill row, and they must be treated differently:

- **True twin** - the same physical movement as the skill, just recorded in another subsystem under another id/name.
  Example: node `cal.l-sit-10` "L-Sit" and `exercise.l-sit` "L-Sit"; node `cl.hollow-body-30` and `skill-drill.hollow-body-hold`.
  These collapse to one canonical id and one name.

- **Regression / drill** - a genuinely different (usually easier) movement that builds toward the skill.
  Example: `skill-drill.tuck-l-sit` "Tuck L-Sit", `skill-drill.band-assisted-full-planche`, `skill-drill.kick-up-practice`.
  These keep their own id and their own distinct name; they route rank *evidence* to the skill but are not renamed or merged.

A folded movement is a true twin when its name matches the skill's criterion movement (the node `target` / `tierCriteria` exercise name); otherwise it is a regression.

## Naming reconciliation (the genuine renames)

From the ground-truth dump, only three movements have a true twin whose name conflicts with the skill.
Every other folded movement either already shares the name (e.g. Push-Up, Pull-Up, Pistol Squat) or is a distinct regression that keeps its name.

| Skill node | Current names (node / exercise / drill) | Proposed one name | Why |
|---|---|---|---|
| `cl.hollow-body-30` | "Hollow Body" / "Hollow Hold" / "Hollow Body Hold" | **Hollow Body Hold** | Standard, descriptive; "Hollow Hold" is colloquial, "Hollow Body" is incomplete |
| `hs.freestanding-hs-30` | "Handstand" / - / "Freestanding Handstand" | **Freestanding Handstand** | Disambiguates from `hs.wall-handstand-30` "Wall Handstand"; bare "Handstand" is ambiguous |
| `ld.weighted-pistol` | "Weighted Pistol" / "Weighted Pistol Squat" / - | **Weighted Pistol Squat** | Complete name; matches sibling `ld.pistol-squat` "Pistol Squat" |

The other eight "divergent" groups are regressions/drills (Tuck L-Sit, Single-Leg L-Sit, Advanced Tuck Back Lever, One-Leg Front Lever, Wall Shoulder Tap, the planche/OAH drill ladders) and are intentionally left with distinct names.

## Target model

One canonical id per physical movement:
- Skill movement: canonical id = the skill node id (e.g. `cl.hollow-body-30`). The twin exercise + twin drill collapse onto it.
- Non-skill movement (bench press, most accessories): canonical id = the exercise id, unchanged.
- Regression drills: keep their own id; they carry a `skillId` that routes rank evidence to the canonical skill but are never merged.

Both persisted stores key on the canonical id:
- `UserSkillTierState.perSkill` already keys on node id (the displayed tier).
- `movement_progress` (the AP/XP ledger) migrates to the canonical id, merging the split rows.

The display layer iterates one canonical list, so `movementFoldsIntoShownSkill` and the twin/alias maps it leans on are deleted, not maintained.
AP-earning rules are preserved: skill-target wrappers stay non-AP; logging a twin earns AP into the one canonical standard exactly as the canonical exercise does today (locked by `SkillStandardConsistencyTests`).

## Migration design (merge on upgrade)

One-time local migration (`movement_progress` and any per-id skill records are local collections, so no server migration):
- For each set of ids that collapse to one canonical id, merge their `movement_progress` docs: sum `totalAP`, max every `best*`, union `contributingMovementIds` / `processedSourceLogIds`, max `provenTier`.
- Historical log entries that carry an old id resolve forward via an id-alias map (same mechanism as `foldedVariantIdAliases`), so old logs still count and never double-count (`processedSourceLogIds` guard).
- Idempotent and guarded by a UserDefaults version flag, beside `SkillTierMigration`.

## Phase plan (checkpointed, build + test green per phase)

- **P0** (this doc) - ground-truth twin table + design + naming proposal. Checkpoint with jlin.
- **P1** - apply the three approved renames across node title + exercise/drill displayName; test that no true-twin pair shows two names.
- **P2** - canonical-id model + complete the exercise->skill twin map for every family with a per-pair metric-compatibility audit; add a catalog invariant test (every movement resolves to exactly one standard).
- **P3** - route all twins to one canonical rank standard + the merge migration; live sandbox rollback test per the data-layer rule.
- **P4** - retire `movementFoldsIntoShownSkill` and the now-redundant twin/association infra; the library iterates one canonical list. Delete old code in the same change.
- **P5** - on-sim end-to-end (log via library / drill / skill block -> one name, one rank, one merged XP row), device-arch build, README freshness, commit per phase.

## Risk register

| Risk | Impact | Mitigation |
|---|---|---|
| Persisted-id collapse drops/strands existing user XP | High | Merge migration is idempotent, version-flagged, summed not overwritten; live sandbox before/after test |
| Historical logs carry retired ids | Med | Id-alias forward-resolution (proven pattern: `foldedVariantIdAliases`) + `processedSourceLogIds` dedupe |
| Regression drill mistakenly merged into its skill | Med | True-twin gate = name matches the skill criterion; regressions keep own id; invariant test |
| ~47 files hardcode skill-node ids; renames touch titles only (id-safe) | Med | Renames are display-string only; id changes confined to the alias map + migration, greped repo-wide incl. tests |
| AP economy shifts (skill blocks suddenly earn AP) | Med | Preserve `rankable: false` on skill targets; `SkillStandardConsistencyTests` stays green |

## Verification

- Unit: rename-consistency test; one-standard-per-movement invariant; migration merge test (sum/union/idempotent); `SkillStandardConsistencyTests`, `CrossSurfaceRankAdvanceTests`, `LiveSkillRankAdvanceTests`, `ProgramRankLibraryFoldTests` stay green (Fold test is retired/replaced in P4).
- On-sim: reproduce one movement logged three ways -> one name, one advancing rank, one merged `movement_progress` row (inspect sandbox JSON before/after).
- Device-arch build green per phase; README freshness; commit per phase.
