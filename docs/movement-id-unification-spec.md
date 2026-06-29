# Movement ID Unification - Cleanup Spec

## Goal

Every physical movement should have **one canonical id and one name**.
"Is it loggable / a ranked skill / a progression drill" should be **attributes of that one movement, not separate catalog entities** with their own ids.

This spec is the one-row-per-movement canonical list, generated from the live catalog (`MovementCatalog.definitions` + `SkillGraph`).
It is the target state; the bridging code added for the rank work (`MovementCatalog.exerciseSkillTwins`, `MovementProofMatcher`'s owning-skill clause) exists **only** to paper over the split ids and can be deleted once ids are unified.

## The numbers

| | Count |
|---|---|
| Distinct physical movements | **328** |
| Already canonical (one id) | **202** |
| Genuine cross-namespace duplicates (the real cleanup) | **39** |
| Skill node + its `skill.*` movement wrapper (structural, lower priority) | **87** |

The library (`exercise.*`) has **zero duplicate names** within itself.
All redundancy is the skill tree (`ld.* cl.* pp.* hs.* pl.* cal.* oah.*`) and drills (`skill-drill.*`) being **parallel id namespaces** for movements that already exist elsewhere.

## Root cause worth fixing first: spelling drift

7 of the 39 duplicates exist purely because the exercise catalog and the skill tree spell the same movement differently - the catalog writes "**Pushup**" while the skill tree writes "**Push-Up**":
`Push-Up`, `Archer`, `Decline`, `Diamond`, `Incline`, `Pike`, `Pseudo-Planche` push-ups.
**Step 0 of the cleanup: standardize one spelling everywhere ("Push-Up").**
Doing this alone collapses 7 duplicates and stops the library and skill tree from re-diverging.
(Note: "Row" is NOT one of these - the inverted-row skill `pp.row` and the rowing-machine cardio `cardio.row` share a loose name but are genuinely different movements, so they stay separate.)

## Canonical id rule

For each movement group, the canonical id is chosen in this order:
1. the loggable `exercise.*` id (it is what users log, and it carries the art), else
2. the skill node id (`ld.* cl.* …`) for movements that are skill-only, else
3. the drill id.

The `skill.<nodeId>` movement wrapper is always redundant - the node already is the rank; it should reference the canonical movement directly instead of minting a `skill.*` twin.

## Cluster prefixes (for reading the ids)

| Prefix | Cluster |
|---|---|
| `cal` | calisthenic control - **Push** (dip → HSPU) |
| `pp` | pulling power - **Pull** (pull-up → muscle-up) |
| `cl` | core lever - **Core** (hollow, L-sit, levers) |
| `ld` | leg dominance - **Legs** (pistol, shrimp, Nordic) |
| `hs` / `oah` / `pl` | handstand / one-arm-HS / planche |
| `co` | conditioning - endurance/grip |
| `exercise.` | the loggable exercise library (not a skill) |

## Table 1 - Genuine duplicates to collapse (39)

Same physical movement living under 2-3 real ids. Collapse the redundant ids into the canonical one.

| Movement | Canonical id | Collapse these ids | Kinds |
|---|---|---|---|
| Archer Push-Up | `exercise.archer-pushup` | `cal.archer-pushup` `skill.cal.archer-pushup` | exercise + skill |
| Bodyweight Leg Extension | `exercise.bodyweight-leg-extension` | `ld.leg-extensions` `skill.ld.leg-extensions` | exercise + skill |
| Bulgarian Split Squat | `exercise.bulgarian-split-squat` | `ld.bulgarian-split-squat` `skill.ld.bulgarian-split-squat` | exercise + skill |
| Chin-Up | `exercise.chin-up` | `pp.chin-up` `skill.pp.chin-up` | exercise + skill |
| Crow Pose | `hs.crow-pose` | `skill-drill.crow-pose` `skill.hs.crow-pose` | drill + skill |
| Decline Push-Up | `exercise.decline-pushup` | `cal.decline-pushup` `skill.cal.decline-pushup` | exercise + skill |
| Decline Sit-Up | `exercise.decline-situp` | `cl.decline-situp` `skill.cl.decline-situp` | exercise + skill |
| Diamond Push-Up | `exercise.diamond-pushup` | `cal.diamond-pushup` `skill.cal.diamond-pushup` | exercise + skill |
| Dragon Flag | `exercise.dragon-flag` | `cl.dragon-flag` `skill.cl.dragon-flag` | exercise + skill |
| Full Planche | `pl.full-planche` | `skill-drill.band-assisted-full-planche` `skill.pl.full-planche` | drill + skill |
| Glute Bridge | `exercise.glute-bridge` | `ld.glute-bridge` `skill.ld.glute-bridge` | exercise + skill |
| Goblet Squat | `exercise.goblet-squat` | `ld.goblet-20` `skill.ld.goblet-20` | exercise + skill |
| Handstand | `hs.freestanding-hs-30` | `skill-drill.freestanding-handstand` `skill-drill.kick-up-practice` `skill.hs.freestanding-hs-30` | drill + skill |
| Hanging Knee Raise | `exercise.hanging-knee-raise` | `cl.hanging-knee-raise` `skill.cl.hanging-knee-raise` | exercise + skill |
| Hanging Leg Raise | `exercise.hanging-leg-raise` | `cl.hanging-leg-raise` `skill.cl.hanging-leg-raise` | exercise + skill |
| Headstand | `hs.headstand` | `skill-drill.headstand` `skill.hs.headstand` | drill + skill |
| Hollow Hold | `exercise.hollow-hold` | `cl.hollow-body-30` `skill-drill.hollow-body-hold` `skill.cl.hollow-body-30` | drill + exercise + skill |
| Incline Push-Up | `exercise.incline-pushup` | `cal.incline-pushup` `skill.cal.incline-pushup` | exercise + skill |
| L-Sit | `exercise.l-sit` | `cal.l-sit-10` `skill-drill.foot-supported-l-sit` `skill-drill.single-leg-l-sit` `skill-drill.tuck-l-sit` `skill.cal.l-sit-10` | drill + exercise + skill |
| Muscle-Up | `exercise.muscle-up` | `pp.muscle-up` `skill.pp.muscle-up` | exercise + skill |
| Nordic Curl | `exercise.nordic-curl` | `ld.nordic-curl` `skill.ld.nordic-curl` | exercise + skill |
| One-Arm Handstand | `oah.one-arm-handstand-5s` | `skill-drill.off-hand-float` `skill-drill.one-finger-tent` `skill-drill.two-finger-tent` `skill.oah.one-arm-handstand-5s` | drill + skill |
| Pike Push-Up | `exercise.pike-pushup` | `cal.pike-pushup` `skill.cal.pike-pushup` | exercise + skill |
| Pistol Squat | `exercise.pistol-squat` | `ld.pistol-squat` `skill.ld.pistol-squat` | exercise + skill |
| Plank | `exercise.plank` | `cal.plank-30` `skill.cal.plank-30` | exercise + skill |
| Pseudo-Planche Push-Up | `exercise.pseudo-planche-pushup` | `cal.pseudo-planche-pushup` `skill.cal.pseudo-planche-pushup` | exercise + skill |
| Push-Up | `exercise.pushup` | `cal.pushup` `skill.cal.pushup` | exercise + skill |
| Shrimp Squat | `exercise.shrimp-squat` | `ld.shrimp-squat` `skill.ld.shrimp-squat` | exercise + skill |
| Split Squat | `exercise.split-squat` | `ld.split-squat` `skill.ld.split-squat` | exercise + skill |
| Step Up | `exercise.step-up` | `ld.step-up` `skill.ld.step-up` | exercise + skill |
| Straddle Back Lever | `cl.straddle-back-lever` | `skill-drill.advanced-tuck-back-lever` `skill-drill.one-leg-back-lever` `skill.cl.straddle-back-lever` | drill + skill |
| Straddle Front Lever | `cl.straddle-front-lever` | `skill-drill.one-leg-front-lever` `skill.cl.straddle-front-lever` | drill + skill |
| Straddle Planche | `pl.straddle-planche` | `skill-drill.advanced-tuck-planche` `skill.pl.straddle-planche` | drill + skill |
| Tuck Front Lever | `exercise.tuck-front-lever` | `cl.tuck-front-lever` `skill.cl.tuck-front-lever` | exercise + skill |
| Tuck Planche | `pl.tuck-planche` | `skill-drill.band-assisted-tuck-planche` `skill-drill.frog-stand` `skill-drill.planche-lean` `skill.pl.tuck-planche` | drill + skill |
| Wall Handstand | `hs.wall-handstand-30` | `skill-drill.wall-handstand` `skill.hs.wall-handstand-30` | drill + skill |
| Wall Plank | `hs.wall-plank` | `skill-drill.wall-plank` `skill.hs.wall-plank` | drill + skill |
| Wall Supported One-Arm Handstand | `hs.wall-supported-oah` | `skill-drill.close-hand-straddle-handstand` `skill-drill.one-arm-handstand-weight-shift` `skill-drill.wall-shoulder-tap` `skill.hs.wall-supported-oah` | drill + skill |
| Weighted Pull-Up | `exercise.weighted-pullup` | `pp.weighted-pullup` `skill.pp.weighted-pullup` | exercise + skill |

Breakdown: 25 `exercise + skill`, 12 `drill + skill`, 2 `drill + exercise + skill`.

### Read carefully - the drills are NOT all the same movement

For the `drill + skill` rows, some drills are the **literal movement** (e.g. `skill-drill.wall-handstand` == the Wall Handstand skill) and should collapse.
Others are **progression sub-steps** (`skill-drill.frog-stand`, `skill-drill.two-finger-tent`, `skill-drill.band-assisted-tuck-planche`) - distinct easier movements that train toward the skill.
Those should **keep their own id** (they are real, separate movements); they only appear here because they share a `skillId`.
Each drill row needs a one-line human call: "is this the movement, or a sub-step?" before collapsing.

## Table 2 - Skill node + `skill.*` wrapper (87, lower priority)

Every skill-only movement (no library exercise) carries two ids: the node id and a `skill.<nodeId>` movement wrapper - e.g. `pp.pullup` + `skill.pp.pullup`, `cal.pushup` + `skill.cal.pushup`.
This is structural, not a naming mess: the node is the rank, the `skill.*` entry is its loggable wrapper.
The clean fix is to drop the `skill.*` wrapper and let the node reference its movement once.
This is bulk/mechanical and can follow Table 1.
(Full list is in the visual library; not enumerated here to keep this scannable.)

## What stays separate (do NOT collapse)

Progression variants are genuinely different movements and keep their own id even though they feed a skill:
`exercise.assisted-pistol-squat`, `exercise.partial-pistol-squat`, `exercise.beginner-shrimp-squat`, `exercise.nordic-curl-negative`, etc.
Difficulty stages of one skill are also genuinely distinct ranks: tuck → straddle → full back lever; straddle vs full one-arm handstand.
The 202 already-canonical movements are untouched.

## What unifying buys us

- Logging, ranking, art, and the skill tree all key off **one id per movement** - no parallel namespaces.
- Delete the bridging code: `MovementCatalog.exerciseSkillTwins`, the owning-skill clause in `MovementProofMatcher`, and the per-movement standard maps become unnecessary.
- The XP-record fragmentation (the deferred "Stage 3") disappears for free, because there is only one rank-standard id per movement.

## Suggested order

0. **Standardize push-up spelling** ("Push-Up" everywhere) - collapses 7 duplicates and stops re-divergence.
1. Table 1 `exercise + skill` rows (25) - point each skill node's movement at the canonical `exercise.*` id; drop the `skill.*` twin.
2. Table 1 `drill + skill` rows (14) - per-drill human call (movement vs sub-step), collapse the literal-movement drills.
3. Table 2 (87) - mechanical: drop the `skill.*` wrappers.
4. Delete the now-dead bridging code and its tests.
