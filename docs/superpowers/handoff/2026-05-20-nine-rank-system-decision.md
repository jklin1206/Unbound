# UNBOUND Rank System Decision

## Decision

UNBOUND uses the 9-rank system everywhere:

1. Initiate
2. Novice
3. Apprentice
4. Forged
5. Veteran
6. Honed
7. Vessel
8. Unbound
9. Ascendant

The older 5-level `SkillLevel` authoring model is deprecated for rank standards. Any remaining 5-level copy should be treated as legacy display/content scaffolding until migrated or removed.

## Why

The app needs one rank language across skills, lifts, cardio, carries, and bodyweight standards. A 5-level skill ladder conflicts with the current rank system and creates mismatches like:

- skill detail copy saying level 5 means one thing
- `SkillTier` criteria saying Ascendant means another
- unlock standards using the 9-rank `SkillTier` model

The 9-rank system is the source of truth.

## Product Rule

- Skill standards use `SkillTier` criteria.
- Exercise/lift standards should use 9-rank performance templates.
- LP can show progress toward the next exercise/lift rank, but the rank itself is only earned by meeting the standard.
- Legacy 5-level `SkillLevel` data should not be used to determine rank, unlocks, or user-facing achievement standards.

## Cleanup Rule

When touching a skill, lift, or movement standard:

1. Verify it has a 9-rank standard.
2. Remove or update conflicting 5-level display copy.
3. Keep skill unlock standards and exercise performance ranks separate, but allow the same log to feed both where appropriate.

