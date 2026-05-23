# UNBOUND Program Modifier + Movement Library Plan

## Core Decision

The movement library is the core of the app.

Programs, skill training, exercise swaps, workout logging, AP, ranks, trials, deloads, travel weeks, and stats should all resolve through the same movement metadata layer.

The app should not depend on open-ended AI to generate safe workouts. The core engine should be deterministic and testable. AI can exist as an optional structured coach layer for free-text interpretation, summaries, explanations, and flavor.

## Rank Language

UNBOUND uses:

- **Rank**: the standard the user has proven.
- **AP**: Ascension Points, progress toward the next standard.
- **Milestone**: iconic achievements like 225 bench, first muscle-up, 5k PR, etc.

AP should not auto-rank a user by grind alone. Rank-up happens when the next standard is proven.

Example:

```text
Bench Press · Forged
78 AP toward Veteran
Next Standard: 1.0x BW e1RM
Milestone: 225 Bench
```

## Skills vs Exercise Performance

Some movements are both skills and rankable exercises.

Example: Pull-Up

- **Pull-Up Skill Rank**: strict bodyweight rep standards and unlock requirements.
- **Pull-Up Performance Rank**: performance score/rank from reps, weighted pull-up load, and progression history.

The same log can update both systems, but they should not mean the same thing.

## Program Architecture

Do not treat a monthly program as a frozen object.

Use three layers:

```text
Base Monthly Plan
    + Active Program Modifiers
    + Daily Workout Resolver
    = Workout Ready Session
```

### 1. Base Monthly Plan

Generated at the start of a block:

- split
- training days
- exercise slots
- target sets/reps/RPE
- target weights
- progression arc
- deload rule
- default substitutions

### 2. Active Program Modifiers

Can be added mid-cycle:

- skill goal added to program
- trial week
- travel week
- deload
- injury/avoidance
- time constraint
- equipment change
- user preference shift

### 3. Daily Workout Resolver

Every time the user opens today’s workout, resolve:

```text
base plan
+ active modifiers
+ recent logs
+ current equipment
+ favorites/avoids
+ recovery/fatigue
+ rank standards
= final Workout Ready draft
```

This is where “Add Pull-Up Skill” becomes more than a calendar item.

Example:

Base Wednesday:

- Lat Pulldown 3x10
- Cable Row 3x12
- Biceps Curl 3x12

User adds Pull-Up skill Tuesday night.

Resolved Wednesday:

- Skill Block: Active Hang + Assisted Pull-Up + Negative Pull-Up
- Lat Pulldown reduced or swapped so vertical pulling volume does not explode
- Cable Row stays
- Biceps Curl stays or reduces if fatigue is high

## Trial Architecture

Trials should use:

```text
Universal Trial Frame
+ Build Track
+ User-Specific Proofs
```

Everyone can say they are doing the same trial:

- Forged Trial
- Veteran Trial
- Honed Trial
- Vessel Trial
- Unbound Trial
- Ascendant Trial

But the actual proofs adapt to the person’s training context.

Shared:

- trial rank
- trial name
- number of days
- categories tested
- pass/fail structure
- friend/squad comparison surface
- badge

Personalized:

- exercises
- thresholds
- substitutions
- unlocked skill regressions
- equipment
- fatigue/recovery rules

The trial should modify workout days, not rest days. It can replace or upgrade parts of planned sessions. Higher-rank trials can span multiple workout days and should include recovery or deload logic afterward.

## Exercise Preference Strategy

Do not make users rate hundreds of exercises manually.

Use:

- favorites
- avoids
- “not today”
- “hurts/avoid”
- “too hard”
- “too easy”
- “no equipment”
- broad equipment/style preferences
- swap history

The current yes/no exercise preference system can remain as an advanced surface, but it should not be the primary onboarding or discovery path.

## Movement Metadata Required

Every canonical movement should eventually have:

- movement id
- display name
- aliases
- movement role
- rankable flag
- rank family/template
- default metric
- logger mode
- block kind
- body parts / muscle groups
- stat vector
- equipment
- difficulty tier
- substitution group
- skill associations
- contraindication tags where useful
- progression/regression links

This metadata is what makes program generation, swaps, trials, travel weeks, deloads, and skill integration possible without AI owning the logic.

## AI Boundary

AI is optional and should be structured, not a full dependency.

Core deterministic:

- program generation
- skill insertion
- substitutions
- deloads
- travel week resolution
- trials
- AP/ranks
- pass/fail standards
- rest day protection
- volume caps

Optional AI:

- parse messy free text into structured constraints
- explain why workout changed
- summarize progress
- generate trial briefing/flavor
- help choose between multiple valid options

The app should work without AI. AI can make it feel more personal, but should not be required for correctness.

## Implementation Direction

1. Expand `MovementCatalog` metadata beyond the first resolver pass.
2. Add exercise performance rank templates and AP calculation.
3. Replace legacy 5-level skill display truth with 9-rank `SkillTier` standards.
4. Add program modifiers as data.
5. Add Daily Workout Resolver.
6. Wire Skill Detail “Add to Program” into active modifiers.
7. Build trial templates and build-track slot definitions.
8. Use AI only as a validated, optional coach action layer.

