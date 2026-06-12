The single authority for every numeric threshold the app uses to rank a movement or gate an unlock. Ranking logic (RankService, BadgeService, TrialGenerator) reads from here; these files own the numbers, not the decision logic.

| File | Purpose |
|---|---|
| `StrengthStandards.swift` | Per-gender, bodyweight-relative ratio tables for all LOADED movements (compounds, weighted pull/dip, accessories F1–F9); returns a `RankTier` or nil for unranked movements |
| `SkillStandards.swift` | Single source for ranking bodyweight rep/hold movements — maps a logged movement key to its skill-graph `tierCriteria` so `RankService` and the "% to next" bar produce the same tier |
| `MovementResolution.swift` | Shared movement-name utilities: `regressionTerms` (assisted/banded/negative prefixes) and `normalizedKey` (trim + lowercase), previously duplicated across `MovementProofMatcher` and `RankService` |
| `UnrankedMovements.swift` | Explicit set of movements that earn XP but carry no rank badge (isolation/momentum/ballistic accessories); resolution checks here first to prevent wrong-parent inheritance |

### Gates/

Tunable numeric floors for session/achievement gates. `BadgeService`, `TrialGenerator`, and `WeeklyVowGenerator` still own how a gate is evaluated; these files own only the seed numbers they read.

| File | Purpose |
|---|---|
| `Gates/BadgeStandards.swift` | Numeric floors that gate session and strength badge unlocks, extracted from `BadgeService` detection logic |
| `Gates/CapstoneStandards.swift` | Per-axis and Apex (wildcard) capstone proof targets used by Weekly Vows — pass/fail gates, not rank standards |
| `Gates/TrialStandards.swift` | Per-station performance floors for every Overall-Rank Trial (reps, hold seconds, %bw carry loads, time caps, qualifying sets) |

## Where to find X

| Task | File |
|---|---|
| Look up the rank tier for a barbell/dumbbell lift | `StrengthStandards.swift` |
| Look up the rank tier for a bodyweight skill (pull-up, push-up, plank…) | `SkillStandards.swift` |
| Check whether a movement is explicitly unranked | `UnrankedMovements.swift` |
| Normalize a movement name or test for regression variants | `MovementResolution.swift` |
| Tune badge unlock thresholds | `Gates/BadgeStandards.swift` |
| Tune Weekly Vow or Trial difficulty numbers | `Gates/CapstoneStandards.swift` / `Gates/TrialStandards.swift` |
