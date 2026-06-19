# Models/Standards

Single source of truth for every numeric threshold the app ranks or gates on: bodyweight-relative strength standards (compounds + accessories), bodyweight-skill rank resolution, movement-name resolution, and the pass/fail gate floors (badges, capstones, trials).

| File | What it contains |
| --- | --- |
| `StrengthStandards.swift` | `StrengthStandards` — resolves any LOADED movement to a `RankTier` from a bodyweight-relative load ratio (compound table / accessory family / unranked). |
| `SkillStandards.swift` | `SkillStandards` — THE single source for ranking bodyweight rep/hold movements; maps a logged movement key to its skill node's generated `tierCriteria`. |
| `MovementResolution.swift` | `MovementResolution` — shared movement-name resolution pieces (regression-prefix terms, normalizer) deduplicated from the ranking code. |
| `UnrankedMovements.swift` | `UnrankedMovements` — authority for movements that earn XP but carry NO rank badge; checked first so accessories don't inherit a wrong parent ratio. |
| `Movements/CompoundStandards.swift` | `CompoundStandards` — per-tier bodyweight-multiplier tables (9 tiers, male + female) for squat / bench / deadlift / OHP / barbell row. |
| `Movements/AccessoryStandards.swift` | `AccessoryStandards` — F1–F9 loaded-accessory families, their per-tier ratio tables, family membership by name, dumbbell-pair ×2 rule. |
| `Gates/BadgeStandards.swift` | `BadgeStandards` — numeric floors gating session/strength badge unlocks (BadgeService owns detection; this owns the numbers). |
| `Gates/CapstoneStandards.swift` | `CapstoneCatalog` + `PrestigeCapstoneCatalog` — per-axis and Apex capstone PROOF targets used by Weekly Vows (pass/fail gates, not rank standards). |
| `Gates/TrialStandards.swift` | `TrialStandards` — per-station performance floors for every Overall-Rank Trial (reps, hold seconds, meters, %bw loads, time caps). |

Where to find X:

- "What tier is this barbell lift at X kg?" → `StrengthStandards.swift`, ratio tables in `Movements/CompoundStandards.swift`
- "What tier is this dumbbell/cable accessory?" → `Movements/AccessoryStandards.swift` (via `StrengthStandards`)
- "What tier is this pull-up / plank / bodyweight skill?" → `SkillStandards.swift`
- "Why does this movement have no rank badge?" → `UnrankedMovements.swift`
- Tune a badge / capstone / trial difficulty number → `Gates/BadgeStandards.swift` / `Gates/CapstoneStandards.swift` / `Gates/TrialStandards.swift`
- Regression prefixes ("assisted", "banded", …) and name normalization → `MovementResolution.swift`
