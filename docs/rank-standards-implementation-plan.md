# Rank Standards & Skill-Tree Overhaul - Implementation Plan

Branch: `worktree-claude+rank-library-redesign`.
Source of truth for the intended result: `docs/rank-standards-bare.html` (the preview).
This plan turns that preview into code, in phases, building and testing between each.

## Principles (locked)

Every node ranks on a single loggable real movement.
A node's rank ladder is its own exercise, never a different one.
For a feat, Initiate = 1 rep (or 1 second) of the actual movement, scaled up to an insane Unbound, 9 distinct ranks, no repeats, no blanks.
The path to reach a feat (negatives, partials, band work) is programming, not a rank: it lives in the unlock gate and `SkillTrainingPlanLibrary`, never in the rank criteria.
Unlock gates are separate from rank ladders: the gate says how good you must be at the lead-up before a node opens; the ladder says how good you are at the node's own movement once it is open.
Clusters need no code change: the levers, crow/crane, plank, L-sit, and one-arm-handstand nodes already carry the correct `cluster:` field. The earlier mis-grouping was a preview-only labeling bug.

## Phase 1 - Feat rank ladders

Goal: the 28 feat skills rank on their own movement, Initiate = 1, scaled to an insane ceiling.

### 1a. `Models/Skills/SkillTierGenerator.swift`

Add a spec case to `SkillAnchor.Spec`:

```swift
case scaled(to: Double)   // 1 -> ceiling, geometric, strictly increasing over the 9 tiers
```

Generation rule (matches the preview exactly):

```
value(i) = max(round(ceiling ^ (i / 8)), previous + step)   for i in 0...8
step = 1 for reps/seconds
```

Wire `.scaled` into `generate(_:)` alongside `.full` and `.feat`.
Keep `.feat` and `.full` working (other anchors still use them).

### 1b. The six `*SkillTiers.swift` anchor files

Convert each feat anchor from `.feat(floor:ladder:)` to `.scaled(to: <ceiling>)`.
Metric stays as-is (reps or seconds).

| Movement | Metric | Ceiling (Unbound) |
|---|---|---|
| Full Front Lever | seconds | 40 |
| Full Back Lever | seconds | 45 |
| Full Planche | seconds | 18 |
| Straddle Planche | seconds | 35 |
| Half-Lay Planche | seconds | 26 |
| One-Arm Elbow Lever | seconds | 30 |
| Wall-Supported One-Arm Handstand | seconds | 35 |
| One-Arm Handstand (5s) | seconds | 30 |
| Full One-Arm Handstand | seconds | 28 |
| One-Arm Pull-Up | reps | 12 |
| One-Arm Chin-Up | reps | 12 |
| Strict Muscle-Up | reps | 14 |
| Ring Muscle-Up | reps | 11 |
| Archer Pull-Up | reps | 12 |
| Clapping Pull-Up | reps | 15 |
| Heighted Chin-Up | reps | 20 |
| Tuck Front Lever Pull-Up | reps | 10 |
| One-Arm Pull-Up Negative | reps | 8 |
| Handstand Push-Up | reps | 20 |
| One-Arm Push-Up | reps | 25 |
| Bent Arm Press | reps | 12 |
| Ninety-Degree Push-Up | reps | 13 |
| Clapping Handstand Push-Up | reps | 10 |
| 360-Degree Pulls | reps | 13 |
| Triple Clap Push-Up | reps | 5, then harder clap at the top (see Decisions) |

Press line (`Tuck Press`, `Straddle Press`, `Press to Handstand`) already scales sensibly; align them to `.scaled(to: 24 / 21 / 18)` so they follow the same rule.

## Phase 2 - Unlock gates

### `Models/Skills/SkillUnlockStandards.swift`

Soften `inferredTier(from:to:)` so basic next-steps are not gated at Forged:

```
if child.isMythic || child.tier >= 6      -> .master      // elite / mythic
if child.title is a hard feat (keyword)   -> .veteran      // one-arm, full, strict, 90, clapping, triple, press to handstand
base by child.tier: <=2 -> .initiate, 3 -> .novice, 4 -> .apprentice, 5 -> .forged
if child.tier > parent.tier + 1           -> bump base one notch (cap .forged)
```

Keyword list unchanged from today.
Remove the explicit edge `"pp.ring-muscle-up->pp.strict-muscle-up"` (strict muscle-up no longer routes through rings).
Leave all other `explicitEdgeTiers` as-is (the hand-tuned muscle-up, planche, lever, one-arm-pull lines stay).

## Phase 3 - Tree structure

### `Models/SkillTreeContent/*.swift` node definitions

Re-parents (change `prereqs:`):

| Node | New prereq(s) | Was |
|---|---|---|
| Wide Pull-Up | `pp.pullup` | Strict Pull-Up |
| Pistol Squat | `ld.bulgarian-split-squat` | root-open |
| Tuck Front Lever Pull-Up | `cl.tuck-front-lever` | root-open |
| Tuck Front Lever | `pp.strict-pullup` + `pp.decline-row` | Decline Row only |
| Muscle-Up | add `cal.5-dips` (keep `pp.explosive-pullup`) | pulling only |
| Tuck Planche | add `cal.pseudo-planche-pushup` + `cal.l-sit-10` (keep `hs.crane-pose`) | crane only |
| L-Sit Chin-Up | `pp.chin-up` + `cal.l-sit-10` | root-open |
| Tuck Planche Push-Up | `pl.tuck-planche` | root-open |
| Strict Muscle-Up | `pp.muscle-up` | Ring Muscle-Up |

Tier change: Full Back Lever `tier: 5 -> 6` (removes the straddle/full same-tier collision).

`isMythic` set (the endgame of each line):
Add: Full Front Lever, Full Back Lever, Full Planche, Muscle-Up, Strict Muscle-Up, One-Arm Pull-Up, One-Arm Chin-Up, One-Arm Handstand, Full One-Arm Handstand, Press to Handstand.
Remove: Floor-to-Ceiling Squat, Clapping Handstand Push-Up, Triple-Clap Push-Up.

Flow check after edits: re-parenting must stay additive where a lead-up is also a flow connection.
Tuck Planche keeps Crane Pose, Tuck Front Lever keeps Decline Row, so Crow->Crane and the row line stay connected.
Confirm no node is left orphaned (Ring Muscle-Up becomes a terminal skill, which is fine).

## Phase 4 - Weighted = 1-rep display

The weighted skills (`pp.weighted-pullup`, `pp.weighted-chin-up`, and weighted leg variants) already rank on load.
In the rank-library view that renders a weighted skill's standard, surface the rep basis so it reads `+X% x 1` for upper-body 1RM standards (and the existing rep target for the weighted leg variants).
View-layer only; no standards-data change.

## Phase 5 - Tests & verification

Update `SkillTierGenerator` tests for the new `.scaled` spec (1 -> ceiling, strictly increasing, 9 distinct).
Update `SkillUnlockStandards` tests for the softened `inferredTier` and the removed ring->strict edge.
Re-check `SkillRankConsistencyTests` and any test that hardcodes a feat ladder value (the feat numbers all change).
Run `ReadmeFreshnessTests` if any file is added or moved.
Build sim and `generic/platform=iOS` (device-arch gate).
Screenshot the rank library on-sim to confirm the ladders and unlock copy read correctly.

## Decisions locked

Triple-Clap Push-Up: option B - scale the triple-clap reps to its real max (~5), then the top ranks become a harder clap expression (quad-clap / behind-the-back) so Unbound stays insane and every rank is real. This is the only exercise whose own-rep range is shorter than 9 ranks.
Clusters: no code change (already correct).
Mythic: redefined as the endgame of each line (set above).

## Status: SHIPPED (all phases)

All five phases are implemented, built, and tested on branch `worktree-claude+rank-library-redesign`.
Full suite green: 1322 tests, 0 failures.
Sim build, device-arch build (`generic/platform=iOS`), and an on-sim render of a re-laddered feat (one-arm pull-up: reps ruler from 1) all pass.

Deviations from the plan as written, decided during implementation:

- Triple-Clap landed as option A (scale to 9, aspirational top), not B.
  B needed non-catalog harder-clap variants, which reintroduces the un-loggable-exercise problem the whole design is meant to avoid; A keeps it one loggable exercise and 9 reps is already past any human, so Unbound stays insane.
- Four "root-open" fixes from the preview were dropped: pistol squat, tuck-front-lever pull-up, L-sit chin-up, and tuck-planche push-up were already correctly gated.
  The preview's parser misread the `PrerequisiteGroup([...])` array form as root-open; the real code was fine, so no change was needed.
- Phase 4 (weighted = 1-rep) needed no new code: the existing weight-scroller work already titles the weighted rail "Added 1RM" / "1RM".
- Clusters needed no change (confirmed: the `cluster:` field was already correct).

## Execution order

Phase 1 -> build + test -> Phase 2 -> build + test -> Phase 3 -> build + test -> Phase 4 -> Phase 5.
Each phase is committed separately so nothing lands broken.
The preview `docs/rank-standards-bare.html` is the visual acceptance check at the end.
