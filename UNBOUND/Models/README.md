# Models

Plain data/model types for UNBOUND, grouped by domain. No views or services live here (a couple of files declare small SwiftUI helper views tightly bound to their model, e.g. cosmetics).

## Subfolders

| Folder | Domain |
| --- | --- |
| `Body/` | Body scans, scan checkpoints/deltas, body regions, muscle groups, progress photos, calibration. |
| `Core/` | Cross-cutting user/account types: `UserProfile`, onboarding answers, `AppError`/`LoadingState`, notification preferences, nutrition/recovery/vitality plans, body-weight progress. |
| `Movements/` | Exercise & movement catalog: `MovementCatalog` + definitions/classification, exercise library items & search, custom exercises, movement resolution/progress. |
| `Program/` | The generated training program (days, waves, arcs), per-exercise progression state, and user knobs: training style/context, weight policy, cut mode, travel override, coach actions. |
| `Ranking/` | Attribute and rank system: `AttributeKey`/`AttributeProfile`, rank state/advances, titles, proof families, overall-level progress. |
| `Rewards/` | What the user earns: XP, badges, reward beats/summaries, the post-workout reward sequence payload, shop cosmetics and rank cosmetics. |
| `Routines/` | Routines / side quests: definitions + built-in library, step kinds, flattened run steps, completion records. |
| `Sessions/` | Live and logged training sessions: `ActiveWorkoutSession` + extensions, workout/cardio logs, training drafts, session editing, rest timer. |
| `Skills/` | Skill-tree mechanics: skill clusters/tiers, tier generation, display tree, training plans per skill family, rung resolution. |
| `SkillTreeContent/` | Generated skill-graph content: `SkillGraph+V3*Nodes` node definitions and per-family tier tables (`Tiers/`). |
| `Squads/` | Squads and friends: squad state/members/missions/leaderboard/presence, friend challenges, weekly honors. |
| `Standards/` | Strength & skill standards (the ranking source data): `StrengthStandards`, `SkillStandards`, movement resolution, gates, unranked movements. |
| `Trials/` | Weekly Vow system (all types are `WeeklyVow*` with legacy `Trial*` typealiases): the committed vow, offered cards, proof evaluation, ledger state. |

## Where to find X

- An exercise's catalog definition or aliases → `Movements/`.
- Rep/weight standards that decide a rank tier → `Standards/` (rank state machinery itself → `Ranking/`).
- The user's current program day or progression for an exercise → `Program/`.
- An in-flight or logged workout → `Sessions/`.
- Post-workout XP/badges/reward sequence → `Rewards/`.
- Skill-tree node content vs. skill mechanics → node data in `SkillTreeContent/`, mechanics/generators in `Skills/`.
- Body-scan and checkpoint types → `Body/`; body-weight log → `Core/Progress.swift`.
- Weekly Vow ("trial") types → `Trials/`.

## Files still at Models/ root

| File | Why |
| --- | --- |
| `VowBet.swift` | `VowBet` — vow bet size (small / medium / large) with associated oweXP and winXP values. |
| `VowLane.swift` | `VowLane` — vow lane enum (recovery / fuel / engine etc.) with per-lane tint colour. |
| `VowSigil.swift` | `VowSigil` — vow sigil model carrying the sigil identifier and render data. |
| `VowTarget.swift` | `VowTarget` — vow target value type (the numeric goal a vow tracks against). |
| `WorkingWeight.swift` | `WorkingWeight` — per-exercise working-weight record (kg, last reps/RPE, per user). Not assigned to a subfolder in the modularization map; it straddles Program (prescription) and Sessions (logging). Flagged for a future owner decision. |
