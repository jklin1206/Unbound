# UNBOUND Movement Library Implementation Plan

## Decision

Do not turn every audited row into an `ExerciseCatalog` exercise.

The app needs a `MovementCatalog` / `MovementResolver` layer in front of the unified workout spine:

`raw source item -> resolved movement role -> TrainingBlock -> PerformanceLog -> stat rewards`

`ExerciseCatalog` stays the canonical strength and gym movement source. The resolver wraps it and adds the missing movement families: skill targets, skill drills, cardio, carry/sled, mobility, and routine steps.

## Proposed Model

```swift
enum MovementRole: String, Codable, Sendable {
    case canonicalExercise
    case alias
    case skillTarget
    case skillDrill
    case cardioModality
    case carrySled
    case mobilityDuration
    case routineContainer
    case routineStep
}

enum MovementLoggerMode: String, Codable, Sendable {
    case strengthSets
    case bodyweightSets
    case skillAttempts
    case hold
    case cardio
    case carry
    case mobility
    case routinePlayer
}

struct MovementDefinition: Identifiable, Codable, Sendable {
    let id: String
    var displayName: String
    var role: MovementRole
    var blockKind: TrainingBlockKind
    var loggerMode: MovementLoggerMode
    var aliases: [String]
    var attributeWeights: [AttributeKey: Double]
    var canonicalExerciseName: String?
    var skillId: String?
    var cardioType: CardioType?
    var defaultMetric: TrainingMetricKind
}

struct ResolvedMovement: Codable, Sendable {
    var rawName: String
    var movementId: String
    var displayName: String
    var role: MovementRole
    var blockKind: TrainingBlockKind
    var loggerMode: MovementLoggerMode
    var canonicalExerciseName: String?
    var variationTags: Set<String>
}
```

## Resolver Rules

1. If the raw name matches an `ExerciseCatalog` canonical name, return `canonicalExercise`.
2. If the raw name matches an alias, return the target movement and preserve variation tags.
3. If the item is a `SkillGraph` node, return `skillTarget`; do not convert it into a normal exercise.
4. If the item is a `CardioType`, return `cardioModality`.
5. If the item contains carry/sled work, return `carrySled`.
6. If the item is stretch/mobility/duration work, return `mobilityDuration`.
7. If the item is a routine title, return `routineContainer`.
8. If the item is a routine step that cannot cleanly resolve, keep it as `routineStep` and render through the routine player.

## Reward Rules

- Strength and gym movements: existing exercise vectors from `AttributeContributions.json`.
- Bodyweight/calisthenics movements: same vector shape, but canonicalized through `MovementCatalog`.
- Skill targets: `skill_nodes` vectors, used only when completing skill sessions or rank-relevant blocks.
- Cardio: duration/intensity-based contribution using `CardioType.intensityFactor`.
- Carry/sled: load + distance/duration contribution, generally power/control/endurance.
- Mobility: duration + quality contribution, generally mobility/control with low total reward velocity.
- Routine containers: no direct vector except optional completion bonus; rewards come from resolved steps.

## First Implementation Patch

1. Add `MovementDefinition`, `MovementRole`, `MovementLoggerMode`, and `ResolvedMovement`.
2. Add `MovementResolver` seeded from:
   - `ExerciseCatalog`
   - `CardioType`
   - a hand-authored carry/sled list
   - a hand-authored mobility list
   - alias rules for obvious skill drill variations
3. Add tests proving:
   - `Band-Assisted Pull-Up` resolves to pull-up family with `.assisted`
   - `Wall Handstand 60s` resolves to skill/bodyweight hold mode
   - `Run`, `Bike`, `Row` resolve to cardio mode
   - `Farmer Carry` and `Sled Push` resolve to carry mode
   - routine containers do not pretend to be exercises
4. Keep `AttributeCatalog.contribution(forExerciseName:)` intact and add a movement-aware lookup as an additive path.

## Cleanup Standard

Do not delete old direct exercise-name lookups yet.

Only remove a path after the screen or service has switched to `MovementResolver`, has tests, and still produces compatible `WorkoutLog` / `SessionLog` side effects through the unified completion pipeline.

