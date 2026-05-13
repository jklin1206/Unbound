# Ascension Tier — 9-Tier Per-Skill Rank Ladder Design

**Status:** Brainstormed 2026-05-13. Awaiting user review before plan-writing.

**Goal:** Replace the codebase's three coexisting rank systems (`SubRank` 18-step E-/S+ ladder, `SkillRank` E-S difficulty chip, `SkillLevel` 1-5 XP ladder) with a single 9-tier per-skill ladder. Every skill on the tree carries its own Initiate→Ascendant ladder with criteria specific to that move. Greenfield swap.

**Sub-project:** #4 of the UNBOUND product redesign.

**Approach:** Per-skill criteria authored as typed data on each `SkillNode`, computed by a single unified `RankService.computeTier(skill:history:)`. ~134 skills × 9 tiers ≈ 1200 `TierCriterion` literals organized into per-cluster authoring files.

**Spec dependency:** Builds on the BuildIdentity system (sub-project #1) and the ScanCheckpoint pipeline (sub-project #3). No dependency on the deleted Gemini grader.

---

## Product directive (governing principles)

These come from the user 2026-05-07 and 2026-05-13:

1. **Per-skill mastery, not aggregate scoring.** Each skill has its own ladder. No fake "user rank" that aggregates across skills. The user advances on the moves they train.
2. **9 named tiers, Apex-style.** Initiate · Novice · Apprentice · Forged · Veteran · Honed · Vessel · **Unbound** · Ascendant. No letter grades. Bottom 4 are quiet trainee tiers; top 5 are brand-flavored. Unbound is the brand moment at rank 8.
3. **Cinematic asymmetry.** Only Vessel/Unbound/Ascendant crossings trigger the full chain-shatter cinematic. Lower tiers use the quiet bloom toast. (Per [[feedback_unbound_cinematic_asymmetry]].)
4. **One vocabulary across all skill types.** Calisthenic skills, barbell lifts, and endurance moves all use the same 9-tier ladder. No parallel SubRank or alternative system.
5. **Earned through training.** Tier advances are driven by `RankService.computeTier(skill:history:)` over the user's actual workout logs — not by self-report, scan-derived state, or LLM grading. (Aligns with [[project_unbound_create_your_own_arc]].)
6. **Profile shows identity + collection, not a score.** BuildIdentity hex is the headline. "Rank-Ups Earned" macro counter and "Ascendant Skills" list are the bragging-rights surfaces. Badge grid shows the user's earned collection.

Memory anchors: [[project_unbound_rank_redesign_2026_05_07]], [[project_unbound_create_your_own_arc]], [[feedback_unbound_cinematic_asymmetry]], [[project_unbound_skill_tree_universal]], [[project_unbound_skill_leveling]] (now stale — superseded by this spec).

---

## Architecture

### Core types

```swift
/// The 9-tier ladder. Ordinal-comparable.
enum SkillTier: Int, Codable, CaseIterable, Sendable, Comparable {
    case initiate    = 0
    case novice      = 1
    case apprentice  = 2
    case forged      = 3
    case veteran     = 4
    case honed       = 5
    case vessel      = 6
    case unbound     = 7
    case ascendant   = 8

    var displayName: String {
        switch self {
        case .initiate:   return "Initiate"
        case .novice:     return "Novice"
        case .apprentice: return "Apprentice"
        case .forged:     return "Forged"
        case .veteran:    return "Veteran"
        case .honed:      return "Honed"
        case .vessel:     return "Vessel"
        case .unbound:    return "Unbound"
        case .ascendant:  return "Ascendant"
        }
    }

    /// Tiers that trigger the full chain-shatter cinematic on crossing.
    /// Bottom 6 use the quiet bloom toast.
    var isFlagshipMoment: Bool { self.rawValue >= SkillTier.vessel.rawValue }

    static func < (lhs: SkillTier, rhs: SkillTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

```swift
/// Typed criterion for a single tier on a single skill. Supports per-skill
/// bespoke shapes — reps, seconds, weight, bw ratio, variant move, or
/// compound (AND across multiple).
enum TierCriterion: Codable, Hashable, Sendable {
    /// Best single-set rep count for `exerciseName` ≥ n.
    case reps(Int, exerciseName: String)
    /// Best held duration ≥ t seconds.
    case seconds(Int)
    /// Best working-set absolute weight ≥ w kg.
    case weightKg(Double)
    /// Best working-set weight ÷ bodyweightKg ≥ r.
    case bodyweightRatio(Double)
    /// Any logged set with exerciseName == this variant.
    case variant(String)
    /// All sub-criteria must pass.
    case compound([TierCriterion])
}
```

```swift
/// User's persisted skill-tier state. Per-skill current tier + macro
/// counters for profile.
struct UserSkillTierState: Codable, Sendable {
    var perSkill: [String: SkillTier]    // keyed by SkillNode.id
    var rankUpsEarned: Int               // total advances across history
    var ascendantSkills: [String]        // skill ids where user hit .ascendant
}
```

### SkillNode model migration

Existing `SkillNode` fields replaced:

```swift
// REMOVED:
//   var rank: SkillRank = .d
//   var levels: [SkillLevel] = []

// ADDED:
let tierCriteria: [SkillTier: TierCriterion]
```

`tierCriteria` MUST have exactly 9 entries (one per `SkillTier` case). Enforced by a coverage-gate test.

### Service layer

```swift
@MainActor
protocol RankServiceProtocol: AnyObject {
    /// Pure: returns the highest tier whose criterion is satisfied by the
    /// user's log history. Defaults to .initiate if nothing matches.
    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier

    /// Stateful: re-evaluate every skill touched by `session`, persist the
    /// new state, and return the advances that occurred. Fires .rankAdvanced
    /// notification per advance.
    @discardableResult
    func ingest(
        session: WorkoutLog,
        userId: String,
        bodyweightKg: Double
    ) async -> [SkillTierAdvance]

    func state(userId: String) -> UserSkillTierState
}

struct SkillTierAdvance: Equatable, Sendable {
    let skillId: String
    let from: SkillTier
    let to: SkillTier
    var isFlagship: Bool { to.isFlagshipMoment }
}
```

**`TierCriterionEvaluator`** — pure helper that evaluates a single `TierCriterion` against an `[ExerciseLogEntry]` history + bodyweightKg. Returns `Bool`. Tested in isolation from the service.

**`UserSkillTierStore`** — persistence layer. UserDefaults JSON, one entry per userId. Mirrors the existing `AttributeProfileStore` pattern.

**Notification**: `.rankAdvanced` continues to fire on tier advances. Payload changes from `RankAdvance` (SubRank-based) to `SkillTierAdvance`. Three existing listeners updated: `UnboundHomeView`, `MuscleHeatmapView`, `BodyMapView`.

### Authoring data layout

```
UNBOUND/Models/SkillTreeContent/
├── SkillTreeContent.swift          (existing — tree topology)
├── ClusterSignatureLadders.swift   (new — Pull/Push/Legs/Core/Lift/Endurance defaults)
└── Tiers/
    ├── PullSkillTiers.swift        (new)
    ├── PushSkillTiers.swift        (new)
    ├── LegsSkillTiers.swift        (new)
    ├── CoreSkillTiers.swift        (new)
    ├── LiftSkillTiers.swift        (new — bench/squat/DL/OHP)
    └── EnduranceSkillTiers.swift   (new)
```

Each per-cluster file exports a `[SkillID: [SkillTier: TierCriterion]]` dictionary. Each `SkillNode` definition reads its entry at construction.

Example:

```swift
// PullSkillTiers.swift
enum PullSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [
        "pull-up": [
            .initiate:   .reps(1, exerciseName: "negative pull-up"),
            .novice:     .reps(1, exerciseName: "pull-up"),
            .apprentice: .reps(3, exerciseName: "pull-up"),
            .forged:     .reps(8, exerciseName: "pull-up"),
            .veteran:    .reps(12, exerciseName: "pull-up"),
            .honed:      .reps(15, exerciseName: "strict pull-up"),
            .vessel:     .reps(3, exerciseName: "weighted pull-up"),
            .unbound:    .variant("muscle-up"),
            .ascendant:  .variant("one-arm pull-up")
        ],
        // ... ~25 more pull skills
    ]
}
```

### Cluster signature ladders as scaffold

The 2026-05-07 memory locked "cluster signature ladders" for Pull/Push/Legs/Core. These become the **default** for that cluster's flagship lineage. Variant skills in the cluster get bespoke criteria that are variations on the signature.

Locked signatures (from memory):

- **Pull**: Incline Row → Dead Hang → Negative Pull-Up → Pull-Up → Strict Pull-Up → Tuck Front Lever → Weighted Pull-Up / Straddle Front Lever → Muscle-Up + Full Front Lever → One-Arm Pull-Up / Strict Muscle-Up
- **Push**: Incline Push-Up → Push-Up → 5 Dips → Diamond Push-Up → Archer Push-Up → Pseudo Planche Push-Up → Wall HSPU / Ring Dip → One-Arm Push-Up → 90° Push-Up / Full Planche
- **Legs**: Goblet Squat → Bulgarian Split Squat → Single-Leg Glute Bridge → Jumping Squat → Shrimp Squat → Pistol Squat → Weighted Pistol → Advancing Nordic Curl → Floor-to-Ceiling Squat
- **Core**: Plank 30s → Hollow Body 30s → Hanging Knee Raise → Hanging Leg Raise → Toes-to-Bar → Standing Ab Rollout → Knee Ab Rollout → Dragon Flag → Levitation Crunch / Inverted Sit-Up

**Lift** signature (new for this spec — anchors barbell skills to absolute weight thresholds; user's bodyweight scales nothing here, but `bodyweightRatio` is still available for body-relative skills):

- **Bench** (Initiate→Ascendant): 20kg → 40kg → 60kg → 80kg → 100kg → 120kg → 140kg → 160kg → 180kg
- **Squat**: 40kg → 60kg → 80kg → 100kg → 130kg → 160kg → 180kg → 200kg → 220kg
- **Deadlift**: 60kg → 80kg → 100kg → 130kg → 160kg → 180kg → 200kg → 220kg → 240kg
- **OHP**: 20kg → 30kg → 40kg → 50kg → 60kg → 70kg → 80kg → 90kg → 100kg

These values are the spec-locked starting thresholds. They reflect the memory's "top reachable, ~285 bench top, not 315" guidance, adjusted to metric and rounded to 10kg increments. The authoring phase ships these; tuning happens via post-ship telemetry, not during implementation.

**Endurance** signature (new — covers running/cycling/swimming type skills if any exist on the tree; authored during implementation if applicable):
- TBD until endurance skill catalog audited during plan-writing. If no endurance nodes exist on the current tree, skip the file.

### Deleted types and services

- `UNBOUND/Models/SubRank.swift` (18-step E-/S+ ladder)
- `UNBOUND/Models/SkillRank.swift` (E-S difficulty chip)
- `UNBOUND/Models/SkillLevel.swift` (1-5 XP ladder)
- `UNBOUND/Services/Ranking/RankService.computeLiftRank` (replaced by `computeTier`)
- `UNBOUND/Services/Ranking/MuscleRankCalculator.swift` (Body Tier feature gone in sub-project #3; verify dead)
- `UNBOUND/Services/Ranking/RankDecayService.swift` (operates on SubRank; re-target to SkillTier or delete per implementation audit)
- `UNBOUND/Models/AttributeRankUpEvent.swift` (if SubRank-coupled; audit during implementation)
- All `SubRank*Tests` and `SkillLevel*Tests`

Standing rule: before any file deletion, grep its body for co-located types using:
```bash
grep -nE "^enum |^struct |^class |^protocol |^extension " path/to/File.swift
```
Per [[feedback_check_colocated_types_before_deleting]].

---

## UI surfaces

### Skill node tier chip

Every `SkillNode` on the tree renders a tier chip showing the user's current tier.

- Reads `UserSkillTierState.perSkill[node.id] ?? .initiate`.
- Tier text + color-coded background.
- **Bottom 4 (Initiate–Forged):** muted gray-violet, quiet treatment.
- **Top 5 (Veteran–Ascendant):** brand-flavored; `Color.unbound.accent` glow intensity scales with `tier.rawValue`.
- Existing `RankBadge` component repurposed to render `SkillTier` instead of `SkillRank`. The 9 `Assets.xcassets/RankTitles/rank_title_<tier>.imageset` PNGs shipped 2026-05-07 are the source.

### Profile rank surface

New section under the BuildIdentity hex on the profile screen:

```
[BuildIdentity hex + displayName]

RANK-UPS EARNED
  47

ASCENDANT SKILLS
  Pull-Up · Pistol Squat · Dragon Flag

BADGES
  [grid of 39 badge slots]
```

- "Rank-Ups Earned" reads `UserSkillTierState.rankUpsEarned`. Increments by 1 per `SkillTierAdvance` event.
- "Ascendant Skills" reads `UserSkillTierState.ascendantSkills`. Hidden if empty.
- "Badges" grid uses the existing 39 `Assets.xcassets/BadgeArt/` PNGs. Locked/unlocked driven by the existing badge service (no changes in this sub-project).

### Cinematic dispatch

`RankUpCinematic` view modifier observes `.rankAdvanced` notification.

- **Initiate→Honed (5 tier transitions: I→N, N→A, A→F, F→V, V→H):** existing `TierBloomToast`-style quiet rank-up. ~1.2s, slide-in chip, no haptic.
- **Vessel/Unbound/Ascendant (H→V, V→U, U→A):** full chain-shatter `RankUpCinematic`. ~4s, heavy haptic, share-card prompt at end.

Listeners (`UnboundHomeView`, `MuscleHeatmapView`, `BodyMapView`) update their handlers to read `SkillTierAdvance` payloads instead of the legacy `RankAdvance`.

### Deleted UI

- 1-5 level chip rendering on skill nodes (was attached to `SkillLevel`)
- E-S `SkillRank` difficulty chip (secondary chip on nodes)
- Any UI reading `SubRank` directly (lift detail screens, etc. — audited during implementation)

---

## Migration strategy — greenfield

Following the same pattern as sub-projects #2 and #3:

- Delete `SubRank`, `SkillRank`, `SkillLevel`, `RankService.computeLiftRank` in one pass.
- Build the new `SkillTier` + `RankService.computeTier` alongside.
- **One-time migration step** on first launch after upgrade: `migrateLegacyState(userId:)` walks every log row, calls `computeTier` for every skill, and seeds `UserSkillTierState`. Idempotent — guarded by `UserDefaults.standard.bool(forKey: "unbound.skillTier.migratedV1")`. After migration, `rankUpsEarned` is set to `perSkill.count` (each non-Initiate tier counts as one earned rank-up since baseline).

Existing users keep their log history (the source of truth). Their new tier values reflect what they've actually trained, not a fake mapping from old SubRank positions.

---

## Testing strategy

- **`SkillTierTests`** — ordinal ordering, `isFlagshipMoment` boundary (only Vessel/Unbound/Ascendant return true), Codable roundtrip.
- **`TierCriterionTests`** — Codable roundtrip for each variant (reps, seconds, weightKg, bodyweightRatio, variant, compound).
- **`TierCriterionEvaluatorTests`** — exhaustive:
  - `reps`: empty history, only warmups, mismatched exerciseName, exact-boundary, exceeds threshold
  - `seconds`: same boundary cases
  - `weightKg`: above/at/below threshold
  - `bodyweightRatio`: bodyweight changes don't break stored tier
  - `variant`: exact-match required, case-insensitive
  - `compound`: all-must-pass, any-fail returns false
- **`RankServiceTests`** — `computeTier` returns the **highest** satisfied tier (not the first). `ingest` only emits `SkillTierAdvance` on actual advances; idempotent on repeated sessions. `rankUpsEarned` increments once per advance. `ascendantSkills` appends without duplicates.
- **`UserSkillTierStoreTests`** — save/load roundtrip, missing-user defaults to empty state.
- **`SkillTreeCoverageGateTests`** — iterates every node in `SkillTreeContent.allNodes`, asserts each has exactly 9 `tierCriteria` entries. Fails CI if any skill is missing tiers.

**Deleted tests:**
- All `SubRank*Tests`
- All `SkillLevel*Tests`
- `MuscleRankCalculatorTests` if present
- `RankService.computeLiftRank` tests

`xcodebuild test` is authoritative (per [[feedback_sourcekit_crossfile_noise_unbound]]).

---

## Authoring scope estimate

| Cluster | Skill count (est.) | Criteria count |
|---|---|---|
| Pull | ~25 | ~225 |
| Push | ~25 | ~225 |
| Legs | ~25 | ~225 |
| Core | ~20 | ~180 |
| Lift (barbell) | ~10 | ~90 |
| Endurance | ~10 (if applicable) | ~90 |
| Misc / utility | ~20 | ~180 |
| **Total** | **~135** | **~1215** |

Exact counts pinned during plan-writing once `SkillTreeContent.allNodes` is audited.

---

## Migration order (informs the plan, not binding on it)

The writing-plans skill will lay out exact phases. Suggested order:

1. New types (`SkillTier`, `TierCriterion`, `UserSkillTierState`) + tests.
2. `TierCriterionEvaluator` + tests.
3. `RankService` rewrite + `UserSkillTierStore` + tests.
4. `SkillNode.tierCriteria` field migration + coverage-gate test.
5. Cluster ladder authoring (one task per cluster: Pull, Push, Legs, Core, Lift, Endurance).
6. UI migration: `RankBadge` re-target, profile rank surface, cinematic listener payload swap.
7. Cinematic split (quiet toast vs chain-shatter) based on `isFlagshipMoment`.
8. Legacy deletion: `SubRank`, `SkillRank`, `SkillLevel`, `MuscleRankCalculator`, `RankDecayService` audit, old tests.
9. One-time migration helper `migrateLegacyState`.
10. Full regression: `xcodebuild test`.

---

## Out of scope (deferred)

- Endurance cluster authoring if no endurance nodes exist on the current tree.
- Server-side rank computation (everything is on-device; cloud sync is a future concern).
- Social comparison features ("your friend hit Ascendant on Pull-Up"). Profile is solo for this sub-project.
- Custom criteria authoring UI for users. The 1215 criteria are static authoring-time content.
- Re-cinematic of badge unlocks (the existing badge service handles this; not touched here).
- Trial system (sub-project #5) consumes `SkillTier` as input but isn't built here.
