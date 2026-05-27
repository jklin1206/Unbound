# Ascension Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `SubRank` (E-/S+), `SkillRank` (E-S), and `SkillLevel` (1-5) with a single 9-tier `SkillTier` ladder, per-skill, with criteria authored as typed data on every `SkillNode`. Greenfield swap.

**Architecture:** Three new types (`SkillTier`, `TierCriterion`, `UserSkillTierState`) + pure evaluator + stateful `RankService` rewrite + per-cluster authoring files. UI surfaces re-targeted from old rank types to `SkillTier`. Legacy types/services/tests deleted in a single demolition phase after the new system carries every consumer.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, XCTest, xcodebuild, xcodegen.

**Spec:** [`docs/superpowers/specs/2026-05-13-ascension-tier-design.md`](../specs/2026-05-13-ascension-tier-design.md)

**Audited surface area (2026-05-13):**
- `SkillTreeContent.allNodes`: **175 skills** across 9 cluster prefixes (`cal` 27, `cl` 32, `co` 10, `hs` 20, `hspu` 10, `ld` 31, `oah` 2, `pl` 10, `pp` 33)
- `SubRank` referenced in 27 files (lifts only — not tree)
- `SkillRank` referenced in 5 files
- `SkillLevel` referenced in 5 files
- `rankAdvanced` / cinematic surfaces touched across 44 files

---

## File Structure

```
UNBOUND/
├── Models/
│   ├── SkillTier.swift                          (new)
│   ├── TierCriterion.swift                      (new)
│   ├── UserSkillTierState.swift                 (new)
│   ├── SkillTree.swift                          (modify — drop SkillNode.rank + .levels, add .tierCriteria)
│   ├── SkillTreeContent.swift                   (modify — populate tierCriteria on each node)
│   ├── SkillTreeContent/
│   │   ├── ClusterSignatureLadders.swift        (new — Pull/Push/Legs/Core defaults from memory)
│   │   └── Tiers/
│   │       ├── CalSkillTiers.swift              (new — 27 skills × 9 criteria)
│   │       ├── ClSkillTiers.swift               (new — 32 skills × 9)
│   │       ├── CoSkillTiers.swift               (new — 10 × 9)
│   │       ├── HsSkillTiers.swift               (new — 20 × 9)
│   │       ├── HspuSkillTiers.swift             (new — 10 × 9)
│   │       ├── LdSkillTiers.swift               (new — 31 × 9)
│   │       ├── OahSkillTiers.swift              (new — 2 × 9)
│   │       ├── PlSkillTiers.swift               (new — 10 × 9)
│   │       └── PpSkillTiers.swift               (new — 33 × 9)
│   ├── LiftTierCriteria.swift                   (new — bench/squat/DL/OHP, 4 × 9)
│   ├── SubRank.swift                            (DELETE — phase 8)
│   ├── SkillRank.swift                          (DELETE — phase 8)
│   ├── SkillLevel.swift                         (DELETE — phase 8)
│   └── AttributeRankUpEvent.swift               (audit — phase 8; payload migrate to SkillTierAdvance)
├── Services/
│   ├── Ranking/
│   │   ├── RankServiceProtocol.swift            (modify — replace computeLiftRank with computeTier+ingest+state)
│   │   ├── RankService.swift                    (rewrite — implements new protocol)
│   │   ├── TierCriterionEvaluator.swift         (new)
│   │   ├── UserSkillTierStore.swift             (new)
│   │   ├── SkillTierMigration.swift             (new — one-time legacy-state migration)
│   │   ├── MuscleRankCalculator.swift           (audit — delete if dead post #3)
│   │   └── RankDecayService.swift               (audit — delete or re-target)
│   └── ServiceContainer.swift                   (modify if rank service shape changes)
└── Views/
    ├── Components/
    │   ├── Unbound/
    │   │   └── RankBadge.swift                  (modify — re-target from SkillRank to SkillTier)
    │   ├── Cinematic/
    │   │   ├── RankUpCinematic.swift            (modify — accept SkillTierAdvance payload, gate to .isFlagshipMoment)
    │   │   ├── TierBloomToast.swift             (modify — accept SkillTierAdvance payload for lower tiers)
    │   │   └── RankUpShareCard.swift            (modify — accept SkillTier instead of SubRank)
    │   ├── TierUnlockToast.swift                (modify — payload migrate)
    │   └── AttributeRankUpToast.swift           (audit — different system, may need no change)
    ├── Home/
    │   ├── UnboundHomeView.swift                (modify — .rankAdvanced listener payload)
    │   └── CharacterSheet/
    │       ├── MuscleHeatmapView.swift          (modify — .rankAdvanced listener payload)
    │       └── BodyMapView.swift                (modify — .rankAdvanced listener payload)
    ├── Profile/
    │   └── ProfileView.swift                    (modify — new rank surface: Rank-Ups Earned, Ascendant Skills, Badges)
    └── Skills/
        └── (skill-node chip rendering site — modify to read SkillTier from UserSkillTierState)

UNBOUNDTests/
├── Models/
│   ├── SkillTierTests.swift                     (new)
│   ├── TierCriterionTests.swift                 (new)
│   └── UserSkillTierStateTests.swift            (new)
├── Services/
│   ├── TierCriterionEvaluatorTests.swift        (new)
│   ├── RankServiceTests.swift                   (rewrite — supersedes old SubRank tests)
│   ├── UserSkillTierStoreTests.swift            (new)
│   └── SkillTierMigrationTests.swift            (new)
└── Models/
    └── SkillTreeCoverageGateTests.swift         (new — every SkillNode has 9 tierCriteria)
```

**Deletions in phase 8:**
- `UNBOUND/Models/SubRank.swift`
- `UNBOUND/Models/SkillRank.swift`
- `UNBOUND/Models/SkillLevel.swift`
- `UNBOUND/Services/Ranking/MuscleRankCalculator.swift` (if dead)
- `UNBOUND/Services/Ranking/RankDecayService.swift` (if dead) OR re-target
- `UNBOUNDTests/Models/SubRank*Tests.swift`
- `UNBOUNDTests/Models/SkillLevel*Tests.swift`
- `UNBOUNDTests/Services/Ranking/MuscleRankCalculator*Tests.swift`
- Any tests that exclusively cover deleted code (grep before delete)

**Worktree:** Create `~/Documents/toji/UNBOUND-ascension-tier` on new branch `ascension-tier-impl` off `program-redesign` (after merging `scan-redesign-impl`'s diff if needed).

---

## Standing rules

These apply to **every task**. Don't restate them.

1. **All subagent dispatches use `model: "sonnet"` or higher.** Never Haiku. (See `feedback_subagents_sonnet_minimum`.)
2. **`xcodebuild test` is authoritative.** SourceKit cross-file diagnostics are noise. (See `feedback_sourcekit_crossfile_noise_unbound`.)
3. **Before deleting a Swift file**, grep its body for unrelated types and extract them first. (See `feedback_check_colocated_types_before_deleting`.)
4. **Runtime keys for catalog lookups use space-lowercase `CatalogExercise.name`**, not snake_case `ExerciseLibrary.id`. (See `feedback_unbound_dual_exercise_catalogs`.) `TierCriterion.reps(_:exerciseName:)` follows this rule — always normalize lookup with `.lowercased()`.
5. Build before each commit: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build` must succeed.
6. Test command: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17'`.

---

# Phase 1 — Core types

Three pure-data types. No persistence, no UI, no business logic. After Phase 1, the codebase builds and tests pass; the new types are dormant.

## Task 1.1: SkillTier enum

**Files:**
- Create: `UNBOUND/Models/SkillTier.swift`
- Test: `UNBOUNDTests/Models/SkillTierTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Models/SkillTierTests.swift
import XCTest
@testable import UNBOUND

final class SkillTierTests: XCTestCase {
    func testOrdinalOrdering() {
        XCTAssertLessThan(SkillTier.initiate, SkillTier.novice)
        XCTAssertLessThan(SkillTier.vessel, SkillTier.unbound)
        XCTAssertLessThan(SkillTier.unbound, SkillTier.ascendant)
    }

    func testAllNineCases() {
        XCTAssertEqual(SkillTier.allCases.count, 9)
    }

    func testFlagshipMomentBoundary() {
        // Only Vessel, Unbound, Ascendant trigger the chain-shatter cinematic.
        XCTAssertFalse(SkillTier.initiate.isFlagshipMoment)
        XCTAssertFalse(SkillTier.novice.isFlagshipMoment)
        XCTAssertFalse(SkillTier.apprentice.isFlagshipMoment)
        XCTAssertFalse(SkillTier.forged.isFlagshipMoment)
        XCTAssertFalse(SkillTier.veteran.isFlagshipMoment)
        XCTAssertFalse(SkillTier.master.isFlagshipMoment)
        XCTAssertTrue(SkillTier.vessel.isFlagshipMoment)
        XCTAssertTrue(SkillTier.unbound.isFlagshipMoment)
        XCTAssertTrue(SkillTier.ascendant.isFlagshipMoment)
    }

    func testDisplayNames() {
        XCTAssertEqual(SkillTier.initiate.displayName, "Initiate")
        XCTAssertEqual(SkillTier.unbound.displayName, "Unbound")
        XCTAssertEqual(SkillTier.ascendant.displayName, "Ascendant")
    }

    func testCodableRoundtrip() throws {
        for tier in SkillTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(SkillTier.self, from: data)
            XCTAssertEqual(decoded, tier)
        }
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Models/SkillTier.swift
import Foundation

/// 9-tier per-skill ladder. Replaces SubRank (lifts), SkillRank (difficulty),
/// and SkillLevel (1-5 XP). Apex-style: no letter grades, no aggregate user
/// rank. Each skill has its own Initiate→Ascendant progression.
///
/// Bottom 4 (Initiate–Forged) are quiet trainee tiers. Top 5 (Veteran–
/// Ascendant) are brand-flavored. Cinematic asymmetry: only Vessel/Unbound/
/// Ascendant crossings trigger the full chain-shatter cinematic.
enum SkillTier: Int, Codable, CaseIterable, Sendable, Comparable {
    case initiate    = 0
    case novice      = 1
    case apprentice  = 2
    case forged      = 3
    case veteran     = 4
    case master       = 5
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
        case .master:      return "Master"
        case .vessel:     return "Vessel"
        case .unbound:    return "Unbound"
        case .ascendant:  return "Ascendant"
        }
    }

    /// Tiers that trigger the full chain-shatter cinematic on advancing.
    /// Lower tiers use the quiet bloom toast.
    var isFlagshipMoment: Bool { rawValue >= SkillTier.vessel.rawValue }

    static func < (lhs: SkillTier, rhs: SkillTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

- [ ] **Step 3: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SkillTierTests 2>&1 | tail -10
```
Expected: 5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/SkillTier.swift UNBOUNDTests/Models/SkillTierTests.swift
git commit -m "feat(rank): add SkillTier 9-tier ladder"
```

---

## Task 1.2: TierCriterion enum

**Files:**
- Create: `UNBOUND/Models/TierCriterion.swift`
- Test: `UNBOUNDTests/Models/TierCriterionTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Models/TierCriterionTests.swift
import XCTest
@testable import UNBOUND

final class TierCriterionTests: XCTestCase {
    func testRepsRoundtrip() throws {
        let c: TierCriterion = .reps(8, exerciseName: "pull-up")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testSecondsRoundtrip() throws {
        let c: TierCriterion = .seconds(60)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testWeightKgRoundtrip() throws {
        let c: TierCriterion = .weightKg(120.0)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testBodyweightRatioRoundtrip() throws {
        let c: TierCriterion = .bodyweightRatio(1.5)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testVariantRoundtrip() throws {
        let c: TierCriterion = .variant("muscle-up")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testCompoundRoundtrip() throws {
        let c: TierCriterion = .compound([
            .reps(8, exerciseName: "pull-up"),
            .seconds(30)
        ])
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testEquatability() {
        XCTAssertEqual(TierCriterion.reps(8, exerciseName: "pull-up"),
                       TierCriterion.reps(8, exerciseName: "pull-up"))
        XCTAssertNotEqual(TierCriterion.reps(8, exerciseName: "pull-up"),
                          TierCriterion.reps(8, exerciseName: "chin-up"))
        XCTAssertNotEqual(TierCriterion.seconds(60), TierCriterion.seconds(61))
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Models/TierCriterion.swift
import Foundation

/// Typed criterion for a single tier on a single skill. Supports per-skill
/// bespoke shapes — reps, seconds, weight, bw ratio, variant, or compound
/// (AND across multiple). Evaluation lives in TierCriterionEvaluator.
///
/// Exercise-name lookups MUST use space-lowercase (e.g. "pull-up"),
/// matching CatalogExercise.name. See feedback_unbound_dual_exercise_catalogs.
enum TierCriterion: Codable, Hashable, Sendable {
    /// Best single-set rep count for `exerciseName` ≥ n.
    case reps(Int, exerciseName: String)
    /// Best held duration in seconds ≥ t.
    case seconds(Int)
    /// Best working-set absolute weight in kg ≥ w.
    case weightKg(Double)
    /// Best working-set weight ÷ bodyweightKg ≥ r.
    case bodyweightRatio(Double)
    /// Any logged set with exerciseName matching this variant (case-insensitive).
    case variant(String)
    /// All sub-criteria must pass.
    case compound([TierCriterion])
}
```

- [ ] **Step 3: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TierCriterionTests 2>&1 | tail -10
```
Expected: 7 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/TierCriterion.swift UNBOUNDTests/Models/TierCriterionTests.swift
git commit -m "feat(rank): add TierCriterion typed criterion"
```

---

## Task 1.3: UserSkillTierState model

**Files:**
- Create: `UNBOUND/Models/UserSkillTierState.swift`
- Test: `UNBOUNDTests/Models/UserSkillTierStateTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Models/UserSkillTierStateTests.swift
import XCTest
@testable import UNBOUND

final class UserSkillTierStateTests: XCTestCase {
    func testEmpty() {
        let state = UserSkillTierState.empty
        XCTAssertTrue(state.perSkill.isEmpty)
        XCTAssertEqual(state.rankUpsEarned, 0)
        XCTAssertTrue(state.ascendantSkills.isEmpty)
    }

    func testTierForUnknownSkillIsInitiate() {
        let state = UserSkillTierState.empty
        XCTAssertEqual(state.tier(for: "pp.pullup"), .initiate)
    }

    func testRoundtrip() throws {
        var state = UserSkillTierState.empty
        state.perSkill["pp.pullup"] = .vessel
        state.perSkill["ld.bw-front-squat"] = .forged
        state.rankUpsEarned = 12
        state.ascendantSkills = ["co.dead-hang-45"]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(UserSkillTierState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Models/UserSkillTierState.swift
import Foundation

/// User's persisted per-skill tier state. Per-skill current tier + macro
/// counters for the profile surface. Skills not present in `perSkill`
/// default to `.initiate` when read via `tier(for:)`.
struct UserSkillTierState: Codable, Equatable, Sendable {
    var perSkill: [String: SkillTier]
    var rankUpsEarned: Int
    var ascendantSkills: [String]

    static let empty = UserSkillTierState(
        perSkill: [:],
        rankUpsEarned: 0,
        ascendantSkills: []
    )

    func tier(for skillId: String) -> SkillTier {
        perSkill[skillId] ?? .initiate
    }
}
```

- [ ] **Step 3: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UserSkillTierStateTests 2>&1 | tail -10
```
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/UserSkillTierState.swift UNBOUNDTests/Models/UserSkillTierStateTests.swift
git commit -m "feat(rank): add UserSkillTierState model"
```

---

## Task 1.4: SkillTierAdvance value

**Files:**
- Modify: `UNBOUND/Models/SkillTier.swift` (append to existing file — small companion type)

- [ ] **Step 1: Append to the existing SkillTier.swift**

Add at the bottom of `UNBOUND/Models/SkillTier.swift`:

```swift
/// Emitted by RankService.ingest when a skill advances. Carries enough
/// payload for cinematic dispatchers to render the right effect.
struct SkillTierAdvance: Equatable, Sendable {
    let skillId: String
    let from: SkillTier
    let to: SkillTier

    /// Whether this advance lands on a flagship tier (Vessel+) and should
    /// trigger the chain-shatter cinematic instead of the quiet bloom.
    var isFlagship: Bool { to.isFlagshipMoment }
}
```

- [ ] **Step 2: Verify**

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Models/SkillTier.swift
git commit -m "feat(rank): add SkillTierAdvance event payload"
```

---

# Phase 2 — Pure evaluator

A single pure function that evaluates one `TierCriterion` against an `[ExerciseLogEntry]` history + bodyweight. No state, no service surface — easy to test exhaustively.

## Task 2.1: TierCriterionEvaluator

**Files:**
- Create: `UNBOUND/Services/Ranking/TierCriterionEvaluator.swift`
- Test: `UNBOUNDTests/Services/TierCriterionEvaluatorTests.swift`

- [ ] **Step 1: Read ExerciseLogEntry shape**

```bash
grep -nE "struct ExerciseLogEntry|^    let|^    var" UNBOUND/Models/ExerciseLogEntry.swift 2>/dev/null | head -20
```

Confirm the fields you'll be reading. The key fields used below are: `exerciseName: String`, `sets: [ExerciseSet]` where each set has `weight: Double?`, `reps: Int?`, `seconds: Int?` or similar, and an `isWarmup: Bool`. **If field names differ, adapt the implementation below to match.**

- [ ] **Step 2: Write the failing tests**

```swift
// UNBOUNDTests/Services/TierCriterionEvaluatorTests.swift
import XCTest
@testable import UNBOUND

final class TierCriterionEvaluatorTests: XCTestCase {

    // MARK: - .reps

    func testReps_emptyHistoryReturnsFalse() {
        let result = TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    func testReps_warmupOnlyDoesNotSatisfy() {
        let entry = makeEntry(exerciseName: "pull-up",
                              sets: [makeSet(reps: 10, isWarmup: true)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    func testReps_exactBoundaryPasses() {
        let entry = makeEntry(exerciseName: "pull-up",
                              sets: [makeSet(reps: 8)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    func testReps_wrongExerciseNameNoMatch() {
        let entry = makeEntry(exerciseName: "chin-up",
                              sets: [makeSet(reps: 20)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    func testReps_caseInsensitiveMatch() {
        let entry = makeEntry(exerciseName: "Pull-Up",
                              sets: [makeSet(reps: 10)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .reps(8, exerciseName: "pull-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    // MARK: - .seconds

    func testSeconds_belowThresholdFails() {
        let entry = makeEntry(exerciseName: "plank",
                              sets: [makeSet(seconds: 25)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .seconds(30),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    func testSeconds_atOrAboveThresholdPasses() {
        let entry = makeEntry(exerciseName: "plank",
                              sets: [makeSet(seconds: 30)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .seconds(30),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    // MARK: - .weightKg

    func testWeightKg_belowFails() {
        let entry = makeEntry(exerciseName: "bench press",
                              sets: [makeSet(weight: 99, reps: 1)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .weightKg(100),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    func testWeightKg_atOrAbovePasses() {
        let entry = makeEntry(exerciseName: "bench press",
                              sets: [makeSet(weight: 100, reps: 1)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .weightKg(100),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    // MARK: - .bodyweightRatio

    func testBodyweightRatio_belowFails() {
        let entry = makeEntry(exerciseName: "squat",
                              sets: [makeSet(weight: 100, reps: 1)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .bodyweightRatio(1.5),
            history: [entry],
            bodyweightKg: 70
        )
        // 100 / 70 = 1.428
        XCTAssertFalse(result)
    }

    func testBodyweightRatio_atOrAbovePasses() {
        let entry = makeEntry(exerciseName: "squat",
                              sets: [makeSet(weight: 105, reps: 1)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .bodyweightRatio(1.5),
            history: [entry],
            bodyweightKg: 70
        )
        // 105 / 70 = 1.5
        XCTAssertTrue(result)
    }

    // MARK: - .variant

    func testVariant_anyLoggedMatchPasses() {
        let entry = makeEntry(exerciseName: "muscle-up",
                              sets: [makeSet(reps: 1)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .variant("muscle-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    func testVariant_caseInsensitive() {
        let entry = makeEntry(exerciseName: "Muscle-Up",
                              sets: [makeSet(reps: 1)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .variant("muscle-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    func testVariant_noMatch() {
        let entry = makeEntry(exerciseName: "pull-up",
                              sets: [makeSet(reps: 20)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .variant("muscle-up"),
            history: [entry],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    // MARK: - .compound

    func testCompound_allPassReturnsTrue() {
        let pull = makeEntry(exerciseName: "pull-up",
                             sets: [makeSet(reps: 10)])
        let plank = makeEntry(exerciseName: "plank",
                              sets: [makeSet(seconds: 60)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .compound([
                .reps(8, exerciseName: "pull-up"),
                .seconds(30)
            ]),
            history: [pull, plank],
            bodyweightKg: 70
        )
        XCTAssertTrue(result)
    }

    func testCompound_anyFailReturnsFalse() {
        let pull = makeEntry(exerciseName: "pull-up",
                             sets: [makeSet(reps: 10)])
        let result = TierCriterionEvaluator.satisfied(
            criterion: .compound([
                .reps(8, exerciseName: "pull-up"),
                .seconds(30)
            ]),
            history: [pull],
            bodyweightKg: 70
        )
        XCTAssertFalse(result)
    }

    // MARK: helpers
    private func makeEntry(exerciseName: String, sets: [ExerciseSet]) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: exerciseName,
            sets: sets,
            completedAt: .now
        )
    }
    private func makeSet(weight: Double? = nil, reps: Int? = nil, seconds: Int? = nil, isWarmup: Bool = false) -> ExerciseSet {
        ExerciseSet(weight: weight, reps: reps, seconds: seconds, isWarmup: isWarmup)
    }
}
```

**IMPORTANT**: The `makeEntry` / `makeSet` helpers use field names that must match the real `ExerciseLogEntry` and `ExerciseSet` types. Read those models first; if the constructors differ, update the helpers (don't change the production types).

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/Ranking/TierCriterionEvaluator.swift
import Foundation

/// Pure: evaluates a single TierCriterion against the user's log history.
/// No state, no I/O. The single source of truth for criterion semantics.
///
/// Exercise-name comparisons are case-insensitive and trim whitespace.
/// Warmup sets are excluded from all calculations.
enum TierCriterionEvaluator {

    static func satisfied(
        criterion: TierCriterion,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> Bool {
        switch criterion {
        case .reps(let target, let exerciseName):
            return bestReps(for: exerciseName, in: history) >= target

        case .seconds(let target):
            return bestSeconds(in: history) >= target

        case .weightKg(let target):
            return bestWeight(in: history) >= target

        case .bodyweightRatio(let target):
            guard bodyweightKg > 0 else { return false }
            return (bestWeight(in: history) / bodyweightKg) >= target

        case .variant(let name):
            let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
            return history.contains { entry in
                entry.exerciseName.lowercased().trimmingCharacters(in: .whitespaces) == normalized
            }

        case .compound(let subs):
            return subs.allSatisfy { satisfied(criterion: $0, history: history, bodyweightKg: bodyweightKg) }
        }
    }

    // MARK: helpers

    private static func matchingEntries(
        exerciseName: String,
        in history: [ExerciseLogEntry]
    ) -> [ExerciseLogEntry] {
        let normalized = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
        return history.filter {
            $0.exerciseName.lowercased().trimmingCharacters(in: .whitespaces) == normalized
        }
    }

    private static func bestReps(for exerciseName: String, in history: [ExerciseLogEntry]) -> Int {
        matchingEntries(exerciseName: exerciseName, in: history)
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.reps }
            .max() ?? 0
    }

    private static func bestSeconds(in history: [ExerciseLogEntry]) -> Int {
        history
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.seconds }
            .max() ?? 0
    }

    private static func bestWeight(in history: [ExerciseLogEntry]) -> Double {
        history
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.weight }
            .max() ?? 0
    }
}
```

**Note**: `bestSeconds` and `bestWeight` look across the ENTIRE history regardless of exerciseName. This is intentional — `.seconds`/`.weightKg`/`.bodyweightRatio` criteria are typically attached to a specific skill node that already filters history at the call site (Task 3.1 service layer). If you find the evaluator needs to filter by exerciseName for these too, add an `exerciseName: String?` parameter and update the tests. The current shape matches the spec.

- [ ] **Step 4: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TierCriterionEvaluatorTests 2>&1 | tail -10
```
Expected: 15 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Ranking/TierCriterionEvaluator.swift UNBOUNDTests/Services/TierCriterionEvaluatorTests.swift
git commit -m "feat(rank): add TierCriterionEvaluator pure-evaluator"
```

---

# Phase 3 — Persistence + service

## Task 3.1: UserSkillTierStore

**Files:**
- Create: `UNBOUND/Services/Ranking/UserSkillTierStore.swift`
- Test: `UNBOUNDTests/Services/UserSkillTierStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/UserSkillTierStoreTests.swift
import XCTest
@testable import UNBOUND

final class UserSkillTierStoreTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "UserSkillTierStoreTests-\(UUID().uuidString)")!
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
        super.tearDown()
    }

    func testMissingUserReturnsEmpty() {
        let store = UserSkillTierStore(defaults: defaults)
        XCTAssertEqual(store.load(userId: "u-1"), .empty)
    }

    func testSaveLoadRoundtrip() {
        let store = UserSkillTierStore(defaults: defaults)
        var state = UserSkillTierState.empty
        state.perSkill["pp.pullup"] = .vessel
        state.rankUpsEarned = 7
        state.ascendantSkills = ["co.dead-hang-45"]

        store.save(state, userId: "u-1")
        XCTAssertEqual(store.load(userId: "u-1"), state)
    }

    func testMultipleUsersIsolated() {
        let store = UserSkillTierStore(defaults: defaults)
        var stateA = UserSkillTierState.empty
        stateA.perSkill["pp.pullup"] = .forged

        var stateB = UserSkillTierState.empty
        stateB.perSkill["pp.pullup"] = .ascendant

        store.save(stateA, userId: "u-1")
        store.save(stateB, userId: "u-2")

        XCTAssertEqual(store.load(userId: "u-1"), stateA)
        XCTAssertEqual(store.load(userId: "u-2"), stateB)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Services/Ranking/UserSkillTierStore.swift
import Foundation

/// UserDefaults-backed persistence for UserSkillTierState. One entry per
/// userId. Mirrors the existing AttributeProfileStore pattern.
final class UserSkillTierStore {

    static let shared = UserSkillTierStore()

    private let defaults: UserDefaults
    private let keyPrefix = "unbound.skillTierState."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(userId: String) -> UserSkillTierState {
        guard let data = defaults.data(forKey: keyPrefix + userId),
              let state = try? JSONDecoder().decode(UserSkillTierState.self, from: data)
        else {
            return .empty
        }
        return state
    }

    func save(_ state: UserSkillTierState, userId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: keyPrefix + userId)
    }
}
```

- [ ] **Step 3: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UserSkillTierStoreTests 2>&1 | tail -10
```
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Services/Ranking/UserSkillTierStore.swift UNBOUNDTests/Services/UserSkillTierStoreTests.swift
git commit -m "feat(rank): add UserSkillTierStore UserDefaults persistence"
```

---

## Task 3.2: RankService rewrite

**Files:**
- Rewrite: `UNBOUND/Services/Ranking/RankServiceProtocol.swift`
- Rewrite: `UNBOUND/Services/Ranking/RankService.swift`
- Test: `UNBOUNDTests/Services/RankServiceTests.swift` (rewrite — supersedes old SubRank tests)

This task touches a lot. Read the existing `RankService.swift` and `RankServiceProtocol.swift` first to know what callers expect to call.

- [ ] **Step 1: Read current API**

```bash
cat UNBOUND/Services/Ranking/RankServiceProtocol.swift
grep -n "func\|RankService.shared" UNBOUND/Services/Ranking/RankService.swift | head -20
grep -rn "RankService.shared\|services.rank\|rankService\." UNBOUND --include="*.swift" | head -10
```

Note every method called from outside the service. Phase 6 (UI migration) will fix call sites; for now, identify which methods to keep, which to rename, which to drop.

- [ ] **Step 2: Rewrite the protocol**

```swift
// UNBOUND/Services/Ranking/RankServiceProtocol.swift
import Foundation

@MainActor
protocol RankServiceProtocol: AnyObject {
    /// Pure: returns the highest tier whose criterion is satisfied by the
    /// user's log history for this skill. Defaults to .initiate.
    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier

    /// Stateful: re-evaluates every skill touched by `session`, persists the
    /// new state, fires `.rankAdvanced` per advance, and returns the advances.
    @discardableResult
    func ingest(
        session: WorkoutLog,
        userId: String,
        bodyweightKg: Double
    ) async -> [SkillTierAdvance]

    func state(userId: String) -> UserSkillTierState
}
```

- [ ] **Step 3: Write the failing tests**

```swift
// UNBOUNDTests/Services/RankServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class RankServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: UserSkillTierStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "RankServiceTests-\(UUID().uuidString)")!
        store = UserSkillTierStore(defaults: defaults)
    }

    func testComputeTier_returnsHighestSatisfied_notFirst() {
        // Skill has criteria for novice (1 rep) and forged (8 reps).
        // User has logged 10 reps. Service should return .forged, not .novice.
        let skill = makeSkill(id: "pp.pullup", tiers: [
            .initiate:   .reps(0, exerciseName: "pull-up"),
            .novice:     .reps(1, exerciseName: "pull-up"),
            .apprentice: .reps(3, exerciseName: "pull-up"),
            .forged:     .reps(8, exerciseName: "pull-up"),
            .veteran:    .reps(12, exerciseName: "pull-up"),
            .master:      .reps(15, exerciseName: "pull-up"),
            .vessel:     .reps(20, exerciseName: "pull-up"),
            .unbound:    .reps(25, exerciseName: "pull-up"),
            .ascendant:  .reps(30, exerciseName: "pull-up")
        ])
        let history = [makeEntry(exerciseName: "pull-up", reps: 10)]
        let service = RankService(store: store)
        XCTAssertEqual(
            service.computeTier(skill: skill, history: history, bodyweightKg: 70),
            .forged
        )
    }

    func testIngest_emitsAdvanceOnlyOnActualMovement() async {
        let skill = makeSkill(id: "pp.pullup", tiers: defaultPullupTiers())
        let service = RankService(store: store)

        // First session: 3 reps → apprentice
        let session1 = makeSession(skills: [(skill.id, "pull-up", 3)])
        let advances1 = await service.ingest(
            session: session1,
            userId: "u-1",
            bodyweightKg: 70
        )
        XCTAssertEqual(advances1.count, 1)
        XCTAssertEqual(advances1.first?.from, .initiate)
        XCTAssertEqual(advances1.first?.to, .apprentice)

        // Second session: same 3 reps → no advance
        let session2 = makeSession(skills: [(skill.id, "pull-up", 3)])
        let advances2 = await service.ingest(
            session: session2,
            userId: "u-1",
            bodyweightKg: 70
        )
        XCTAssertEqual(advances2.count, 0)

        // Third session: 8 reps → forged
        let session3 = makeSession(skills: [(skill.id, "pull-up", 8)])
        let advances3 = await service.ingest(
            session: session3,
            userId: "u-1",
            bodyweightKg: 70
        )
        XCTAssertEqual(advances3.count, 1)
        XCTAssertEqual(advances3.first?.to, .forged)
    }

    func testIngest_incrementsRankUpsEarnedPerAdvance() async {
        let skill = makeSkill(id: "pp.pullup", tiers: defaultPullupTiers())
        let service = RankService(store: store)
        let session = makeSession(skills: [(skill.id, "pull-up", 12)])

        _ = await service.ingest(session: session, userId: "u-1", bodyweightKg: 70)

        // 12 reps crosses initiate→novice→apprentice→forged→veteran = 4 advances
        XCTAssertEqual(service.state(userId: "u-1").rankUpsEarned, 4)
    }

    func testIngest_appendsAscendantSkillsWithoutDuplicates() async {
        let skill = makeSkill(id: "pp.pullup", tiers: defaultPullupTiers())
        let service = RankService(store: store)

        // 30 reps → ascendant
        _ = await service.ingest(
            session: makeSession(skills: [(skill.id, "pull-up", 30)]),
            userId: "u-1",
            bodyweightKg: 70
        )
        XCTAssertEqual(service.state(userId: "u-1").ascendantSkills, [skill.id])

        // Same again → not duplicated
        _ = await service.ingest(
            session: makeSession(skills: [(skill.id, "pull-up", 30)]),
            userId: "u-1",
            bodyweightKg: 70
        )
        XCTAssertEqual(service.state(userId: "u-1").ascendantSkills, [skill.id])
    }

    // MARK: helpers

    private func makeSkill(id: String, tiers: [SkillTier: TierCriterion]) -> SkillNode {
        // Adapt SkillNode constructor to match the real type. tierCriteria is
        // the field added in Task 4.1.
        SkillNode(
            id: id,
            title: id,
            subtitle: "",
            cluster: .legs,         // value doesn't matter for this test
            tier: 1,
            type: .skill,
            isKeystone: false,
            isMythic: false,
            target: .reps(1),       // adapt to match NodeRequirement shape
            prereqs: [],
            equipment: [],
            primaryMuscles: [],
            secondaryMuscles: [],
            description: "",
            formCues: [],
            commonMistakes: [],
            timelineEstimate: "",
            glyph: "",
            position: .zero,
            tierCriteria: tiers
        )
    }

    private func defaultPullupTiers() -> [SkillTier: TierCriterion] {
        [
            .initiate:   .reps(0, exerciseName: "pull-up"),
            .novice:     .reps(1, exerciseName: "pull-up"),
            .apprentice: .reps(3, exerciseName: "pull-up"),
            .forged:     .reps(8, exerciseName: "pull-up"),
            .veteran:    .reps(12, exerciseName: "pull-up"),
            .master:      .reps(15, exerciseName: "pull-up"),
            .vessel:     .reps(20, exerciseName: "pull-up"),
            .unbound:    .reps(25, exerciseName: "pull-up"),
            .ascendant:  .reps(30, exerciseName: "pull-up")
        ]
    }

    private func makeEntry(exerciseName: String, reps: Int) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: exerciseName,
            sets: [ExerciseSet(weight: nil, reps: reps, seconds: nil, isWarmup: false)],
            completedAt: .now
        )
    }

    private func makeSession(skills: [(String, String, Int)]) -> WorkoutLog {
        // Adapt WorkoutLog constructor to match real type.
        // Each tuple is (skillId, exerciseName, reps).
        let entries = skills.map { _, name, reps in makeEntry(exerciseName: name, reps: reps) }
        return WorkoutLog(
            id: UUID().uuidString,
            userId: "u-1",
            entries: entries,
            completedAt: .now
        )
    }
}
```

**IMPORTANT**: The `makeSkill`, `makeSession`, `makeEntry` helpers reference fields/constructors that must match real types. Read `SkillNode`, `WorkoutLog`, `ExerciseLogEntry`, `ExerciseSet`, `NodeRequirement` before writing. Adapt the helpers to match — DON'T change production types.

- [ ] **Step 4: Implement RankService**

```swift
// UNBOUND/Services/Ranking/RankService.swift
import Foundation

@MainActor
final class RankService: RankServiceProtocol {
    static let shared = RankService()

    private let store: UserSkillTierStore
    private let logger = LoggingService.shared

    init(store: UserSkillTierStore = .shared) {
        self.store = store
    }

    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier {
        // Walk tiers from highest to lowest. First satisfied wins.
        for tier in SkillTier.allCases.reversed() {
            guard let criterion = skill.tierCriteria[tier] else { continue }
            if TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: history,
                bodyweightKg: bodyweightKg
            ) {
                return tier
            }
        }
        return .initiate
    }

    @discardableResult
    func ingest(
        session: WorkoutLog,
        userId: String,
        bodyweightKg: Double
    ) async -> [SkillTierAdvance] {
        var state = store.load(userId: userId)
        var advances: [SkillTierAdvance] = []
        let allSkills = SkillTreeContent.allNodes

        // Build a per-skill history from this session's entries. For each
        // skill node, we evaluate its criteria against the FULL log history
        // (loaded from DatabaseService). For now we use just the session
        // — a future refactor reads cumulative history. Spec acceptance for
        // this phase requires session-only evaluation.
        let history = session.entries

        for skill in allSkills {
            let priorTier = state.tier(for: skill.id)
            let newTier = computeTier(
                skill: skill,
                history: history,
                bodyweightKg: bodyweightKg
            )

            // Tiers can only advance (no decay in this sub-project).
            guard newTier > priorTier else { continue }

            // Count advances: each tier crossed is +1 to rankUpsEarned.
            let advanceCount = newTier.rawValue - priorTier.rawValue
            state.rankUpsEarned += advanceCount
            state.perSkill[skill.id] = newTier

            if newTier == .ascendant && !state.ascendantSkills.contains(skill.id) {
                state.ascendantSkills.append(skill.id)
            }

            let advance = SkillTierAdvance(
                skillId: skill.id,
                from: priorTier,
                to: newTier
            )
            advances.append(advance)
            NotificationCenter.default.post(
                name: .rankAdvanced,
                object: advance
            )
        }

        store.save(state, userId: userId)
        return advances
    }

    func state(userId: String) -> UserSkillTierState {
        store.load(userId: userId)
    }
}

extension Notification.Name {
    static let rankAdvanced = Notification.Name("unbound.rankAdvanced")
}
```

**Note**: The session-only history is a deliberate simplification for the first pass. The cumulative-history version is added in Task 9.1 (one-time migration). For ongoing ingest, callers may pass a richer `history` parameter; document this in the protocol if you add it.

- [ ] **Step 5: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/RankServiceTests 2>&1 | tail -10
```
Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Services/Ranking/RankService.swift \
        UNBOUND/Services/Ranking/RankServiceProtocol.swift \
        UNBOUNDTests/Services/RankServiceTests.swift
git commit -m "feat(rank): rewrite RankService around SkillTier + computeTier/ingest"
```

---

# Phase 4 — SkillNode migration + coverage gate

## Task 4.1: Add tierCriteria field to SkillNode

**Files:**
- Modify: `UNBOUND/Models/SkillTree.swift` (the `SkillNode` struct, around line 92)

- [ ] **Step 1: Read the current SkillNode definition**

```bash
sed -n '85,145p' UNBOUND/Models/SkillTree.swift
```

The current end of the struct has:
```swift
var rank: SkillRank = .d
var levels: [SkillLevel] = []
```

These two will be removed in Phase 8 along with their containing types. For now, add the new field next to them.

- [ ] **Step 2: Add the new field**

In `UNBOUND/Models/SkillTree.swift`, inside the `SkillNode` struct, just below the existing `levels` field, add:

```swift
/// Per-skill 9-tier criteria. Replaces the old SkillRank difficulty chip
/// and 1-5 SkillLevel ladder. Each SkillNode MUST have exactly 9 entries
/// (one per SkillTier case) by the time SkillTreeCoverageGateTests runs.
/// Default is empty until Phase 5 cluster authoring populates it.
var tierCriteria: [SkillTier: TierCriterion] = [:]
```

- [ ] **Step 3: Verify build**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/SkillTree.swift
git commit -m "feat(rank): add SkillNode.tierCriteria field (default empty)"
```

---

## Task 4.2: Coverage-gate test

**Files:**
- Create: `UNBOUNDTests/Models/SkillTreeCoverageGateTests.swift`

This test will FAIL initially. That's fine — it's the gate that holds the authoring phase honest. Each cluster authoring task in Phase 5 makes more skills pass; the test goes green when the last cluster is authored.

- [ ] **Step 1: Write the test**

```swift
// UNBOUNDTests/Models/SkillTreeCoverageGateTests.swift
import XCTest
@testable import UNBOUND

/// Asserts every SkillNode has exactly 9 tier criteria (one per SkillTier).
/// Fails until Phase 5 cluster authoring is complete for ALL clusters.
/// Phase 5 cluster tasks each verify a subset; this is the final gate.
final class SkillTreeCoverageGateTests: XCTestCase {

    func testEverySkillHasNineTierCriteria() {
        var missing: [String] = []
        for node in SkillTreeContent.allNodes {
            if node.tierCriteria.count != 9 {
                missing.append("\(node.id): \(node.tierCriteria.count)/9")
            }
        }
        XCTAssertTrue(
            missing.isEmpty,
            "Skills missing complete tier criteria:\n\(missing.joined(separator: "\n"))"
        )
    }

    func testEverySkillCoversAllNineTiers() {
        var incomplete: [String] = []
        for node in SkillTreeContent.allNodes {
            let coveredTiers = Set(node.tierCriteria.keys)
            let allTiers = Set(SkillTier.allCases)
            if coveredTiers != allTiers {
                let missing = allTiers.subtracting(coveredTiers)
                    .map(\.displayName)
                    .sorted()
                    .joined(separator: ", ")
                incomplete.append("\(node.id) missing: \(missing)")
            }
        }
        XCTAssertTrue(
            incomplete.isEmpty,
            "Skills missing specific tiers:\n\(incomplete.joined(separator: "\n"))"
        )
    }
}
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SkillTreeCoverageGateTests 2>&1 | tail -10
```
Expected: 2 tests FAIL (175 skills each missing 9 criteria).

- [ ] **Step 3: Commit**

```bash
git add UNBOUNDTests/Models/SkillTreeCoverageGateTests.swift
git commit -m "test(rank): add SkillTree coverage gate (initially failing)"
```

---

# Phase 5 — Cluster authoring

Nine tasks, one per cluster prefix. Each authors a `<Cluster>SkillTiers.swift` file with the criteria for every skill in that cluster, then wires it into `SkillTreeContent.v3Nodes`.

**Authoring rule:** for every skill in the cluster, write 9 `TierCriterion` literals — one per `SkillTier`. The criteria should be realistic for that move, climbing in difficulty from Initiate to Ascendant. Use the cluster signature ladders from the spec as the SCAFFOLD; tune per-skill.

**Wiring pattern:** in `SkillTreeContent.swift`, modify the `enriched` mapping (around line 22) to read from each cluster's table and stamp the result onto each node. Do this once for all clusters in **Task 5.10**, after all authoring tasks complete.

Each authoring task follows the same template. I'll show Task 5.1 (`cal` cluster) in detail; subsequent tasks reference this template.

## Task 5.1: Author cal cluster (27 skills)

**Files:**
- Create: `UNBOUND/Models/SkillTreeContent/Tiers/CalSkillTiers.swift`

- [ ] **Step 1: Enumerate the cal skills**

```bash
grep "^            id:" UNBOUND/Models/SkillTreeContent.swift | awk -F'"' '{print $2}' | grep "^cal\." > /tmp/cal_skills.txt
cat /tmp/cal_skills.txt
```

- [ ] **Step 2: For each skill, read its title/subtitle/target to inform criteria**

The skill's `target: NodeRequirement` is the stated single-criterion definition of the node. Use it as the centerpiece (typically maps to either `Forged` or `Veteran`). Climb from there.

```bash
grep -B1 -A15 "id: \"cal.plank-30\"" UNBOUND/Models/SkillTreeContent.swift | head -25
```

Repeat for every cal skill.

- [ ] **Step 3: Write the authoring file**

```swift
// UNBOUND/Models/SkillTreeContent/Tiers/CalSkillTiers.swift
//
// Tier criteria for every skill with prefix `cal.` (27 skills).
//
// Authoring approach: each skill climbs from a quiet entry threshold
// (Initiate) to a Vessel/Unbound moment that reads as elite for that
// specific move. Cluster signature ladders from the spec are the
// scaffold; per-skill tuning happens here.
import Foundation

enum CalSkillTiers {
    static let table: [String: [SkillTier: TierCriterion]] = [
        "cal.plank-30": [
            .initiate:   .seconds(15),
            .novice:     .seconds(30),
            .apprentice: .seconds(45),
            .forged:     .seconds(60),
            .veteran:    .seconds(90),
            .master:      .seconds(120),
            .vessel:     .seconds(180),
            .unbound:    .seconds(240),
            .ascendant:  .seconds(300)
        ],
        // ... continue for every cal skill
    ]
}
```

**You MUST author every skill in the cal cluster.** Don't ship partial coverage — `SkillTreeCoverageGateTests` will catch you. Realistic, climbing thresholds per skill.

- [ ] **Step 4: Verify the file compiles and the dictionary is the right size**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

Inline test: add a tiny assertion at the end of the file (delete after this task):
```swift
#if DEBUG
private let _calCount: Int = {
    assert(CalSkillTiers.table.count == 27, "cal cluster should have 27 entries, has \(CalSkillTiers.table.count)")
    assert(CalSkillTiers.table.allSatisfy { $0.value.count == 9 }, "every cal skill needs 9 tiers")
    return CalSkillTiers.table.count
}()
#endif
```
Then run the app once (or check via a unit test). After passing, delete the assertion.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/SkillTreeContent/Tiers/CalSkillTiers.swift
git commit -m "feat(rank): author cal cluster tier criteria (27 skills)"
```

## Task 5.2: Author cl cluster (32 skills)

Follow the same template as Task 5.1. File: `UNBOUND/Models/SkillTreeContent/Tiers/ClSkillTiers.swift`. Enumerate via `grep ... grep "^cl\."`. Author 32 × 9 = 288 criteria. Commit message: `feat(rank): author cl cluster tier criteria (32 skills)`.

## Task 5.3: Author co cluster (10 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/CoSkillTiers.swift`. 10 × 9 = 90 criteria. Commit: `feat(rank): author co cluster tier criteria (10 skills)`.

## Task 5.4: Author hs cluster (20 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/HsSkillTiers.swift`. 20 × 9 = 180 criteria. Commit: `feat(rank): author hs cluster tier criteria (20 skills)`.

## Task 5.5: Author hspu cluster (10 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/HspuSkillTiers.swift`. 10 × 9 = 90 criteria. Commit: `feat(rank): author hspu cluster tier criteria (10 skills)`.

## Task 5.6: Author ld cluster (31 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/LdSkillTiers.swift`. 31 × 9 = 279 criteria. Use Legs signature from spec as scaffold. Commit: `feat(rank): author ld cluster tier criteria (31 skills)`.

## Task 5.7: Author oah cluster (2 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/OahSkillTiers.swift`. 2 × 9 = 18 criteria. Commit: `feat(rank): author oah cluster tier criteria (2 skills)`.

## Task 5.8: Author pl cluster (10 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/PlSkillTiers.swift`. 10 × 9 = 90 criteria. Commit: `feat(rank): author pl cluster tier criteria (10 skills)`.

## Task 5.9: Author pp cluster (33 skills)

File: `UNBOUND/Models/SkillTreeContent/Tiers/PpSkillTiers.swift`. 33 × 9 = 297 criteria. Use Pull signature from spec as scaffold. Commit: `feat(rank): author pp cluster tier criteria (33 skills)`.

## Task 5.10: Wire all cluster tables into SkillTreeContent

**Files:**
- Modify: `UNBOUND/Models/SkillTreeContent.swift` (around line 22 where `enriched` is built)

- [ ] **Step 1: Modify the enriched mapping**

Find the existing block (around line 22):

```swift
let enriched: [SkillNode] = Self.v3Nodes.map { node in
    // ... existing enrichment ...
    return node
}
```

Add a step that pulls each node's `tierCriteria` from the appropriate cluster table:

```swift
let enriched: [SkillNode] = Self.v3Nodes.map { node in
    var enrichedNode = node
    let prefix = String(node.id.prefix(while: { $0 != "." }))
    enrichedNode.tierCriteria = Self.tierCriteriaTable(for: prefix)[node.id] ?? [:]
    // ... rest of existing enrichment ...
    return enrichedNode
}

private static func tierCriteriaTable(for prefix: String) -> [String: [SkillTier: TierCriterion]] {
    switch prefix {
    case "cal":  return CalSkillTiers.table
    case "cl":   return ClSkillTiers.table
    case "co":   return CoSkillTiers.table
    case "hs":   return HsSkillTiers.table
    case "hspu": return HspuSkillTiers.table
    case "ld":   return LdSkillTiers.table
    case "oah":  return OahSkillTiers.table
    case "pl":   return PlSkillTiers.table
    case "pp":   return PpSkillTiers.table
    default:     return [:]
    }
}
```

- [ ] **Step 2: Run the coverage gate**

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SkillTreeCoverageGateTests 2>&1 | tail -10
```
Expected: 2 tests PASS. (Any skill missing criteria fails the gate.)

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Models/SkillTreeContent.swift
git commit -m "feat(rank): wire cluster tier tables into SkillTreeContent"
```

---

# Phase 6 — Lift tier criteria

## Task 6.1: LiftTierCriteria

**Files:**
- Create: `UNBOUND/Models/LiftTierCriteria.swift`
- Test: `UNBOUNDTests/Models/LiftTierCriteriaTests.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Models/LiftTierCriteria.swift
//
// Tier criteria for the 4 barbell main lifts. These do NOT live on the
// skill tree — they're queried directly by lift-specific UI surfaces
// and the same RankService.computeTier method. Spec-locked weight
// thresholds, metric, 10kg increments.
import Foundation

enum LiftTierCriteria {

    /// All 4 lifts keyed by exercise name (space-lowercase per
    /// CatalogExercise.name convention).
    static let table: [String: [SkillTier: TierCriterion]] = [
        "bench press": [
            .initiate:   .weightKg(20),
            .novice:     .weightKg(40),
            .apprentice: .weightKg(60),
            .forged:     .weightKg(80),
            .veteran:    .weightKg(100),
            .master:      .weightKg(120),
            .vessel:     .weightKg(140),
            .unbound:    .weightKg(160),
            .ascendant:  .weightKg(180)
        ],
        "back squat": [
            .initiate:   .weightKg(40),
            .novice:     .weightKg(60),
            .apprentice: .weightKg(80),
            .forged:     .weightKg(100),
            .veteran:    .weightKg(130),
            .master:      .weightKg(160),
            .vessel:     .weightKg(180),
            .unbound:    .weightKg(200),
            .ascendant:  .weightKg(220)
        ],
        "deadlift": [
            .initiate:   .weightKg(60),
            .novice:     .weightKg(80),
            .apprentice: .weightKg(100),
            .forged:     .weightKg(130),
            .veteran:    .weightKg(160),
            .master:      .weightKg(180),
            .vessel:     .weightKg(200),
            .unbound:    .weightKg(220),
            .ascendant:  .weightKg(240)
        ],
        "overhead press": [
            .initiate:   .weightKg(20),
            .novice:     .weightKg(30),
            .apprentice: .weightKg(40),
            .forged:     .weightKg(50),
            .veteran:    .weightKg(60),
            .master:      .weightKg(70),
            .vessel:     .weightKg(80),
            .unbound:    .weightKg(90),
            .ascendant:  .weightKg(100)
        ]
    ]
}
```

- [ ] **Step 2: Write the test**

```swift
// UNBOUNDTests/Models/LiftTierCriteriaTests.swift
import XCTest
@testable import UNBOUND

final class LiftTierCriteriaTests: XCTestCase {
    func testAllFourLiftsPresent() {
        XCTAssertEqual(LiftTierCriteria.table.count, 4)
        XCTAssertNotNil(LiftTierCriteria.table["bench press"])
        XCTAssertNotNil(LiftTierCriteria.table["back squat"])
        XCTAssertNotNil(LiftTierCriteria.table["deadlift"])
        XCTAssertNotNil(LiftTierCriteria.table["overhead press"])
    }

    func testEveryLiftCoversAllNineTiers() {
        for (lift, tiers) in LiftTierCriteria.table {
            XCTAssertEqual(tiers.count, 9, "\(lift) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(lift) missing \(tier)")
            }
        }
    }

    func testThresholdsClimbMonotonically() {
        for (lift, tiers) in LiftTierCriteria.table {
            let weights: [Double] = SkillTier.allCases.compactMap {
                if case .weightKg(let w) = tiers[$0] { return w }
                return nil
            }
            XCTAssertEqual(weights.count, 9, "\(lift): non-weight criterion present")
            XCTAssertEqual(weights, weights.sorted(), "\(lift): thresholds not monotonic")
        }
    }
}
```

- [ ] **Step 3: Verify**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/LiftTierCriteriaTests 2>&1 | tail -10
```
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/LiftTierCriteria.swift UNBOUNDTests/Models/LiftTierCriteriaTests.swift
git commit -m "feat(rank): add LiftTierCriteria for bench/squat/deadlift/OHP"
```

---

# Phase 7 — UI migration

## Task 7.1: Re-target RankBadge

**Files:**
- Modify: `UNBOUND/Views/Components/Unbound/RankBadge.swift`

- [ ] **Step 1: Read current shape**

```bash
cat UNBOUND/Views/Components/Unbound/RankBadge.swift
```

The view currently takes a `SkillRank` (E/D/C/B/A/S). Change its input type to `SkillTier`.

- [ ] **Step 2: Rewrite the view**

```swift
// UNBOUND/Views/Components/Unbound/RankBadge.swift
import SwiftUI

/// Renders a tier chip for a single SkillTier. Bottom 4 tiers (Initiate–
/// Forged) use a muted gray-violet treatment; top 5 (Veteran–Ascendant)
/// use Color.unbound.accent with glow intensity scaling by ordinal.
///
/// Source assets: Assets.xcassets/RankTitles/rank_title_<tier>.imageset
struct RankBadge: View {
    let tier: SkillTier
    var compact: Bool = false

    var body: some View {
        let glowIntensity = max(0, Double(tier.rawValue - SkillTier.veteran.rawValue)) * 0.25
        Text(tier.displayName.uppercased())
            .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                Capsule().fill(backgroundColor)
            )
            .overlay(
                Capsule().strokeBorder(strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.unbound.accent.opacity(glowIntensity), radius: 6)
    }

    private var textColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.textPrimary
            : Color.unbound.textSecondary
    }

    private var backgroundColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.accent.opacity(0.18)
            : Color.unbound.surface
    }

    private var strokeColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.accent.opacity(0.4)
            : Color.unbound.border
    }
}
```

If the existing `RankBadge` has callers using a different constructor signature, update each caller to pass a `SkillTier` instead. Grep:

```bash
grep -rn "RankBadge(" UNBOUND --include="*.swift" | grep -v "RankBadge.swift"
```

Each call site must be updated to pass `tier:` instead of the old parameter. Common pattern: the caller probably reads a stored rank from a model — update those reads in the same pass.

- [ ] **Step 3: Verify build**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Components/Unbound/RankBadge.swift
# Plus any caller files updated in Step 2.
git commit -m "feat(rank): re-target RankBadge from SkillRank to SkillTier"
```

---

## Task 7.2: Migrate cinematic listeners to SkillTierAdvance payload

**Files:**
- Modify: `UNBOUND/Views/Components/Cinematic/RankUpCinematic.swift`
- Modify: `UNBOUND/Views/Components/Cinematic/TierBloomToast.swift`
- Modify: `UNBOUND/Views/Components/Cinematic/RankUpShareCard.swift`
- Modify: `UNBOUND/Views/Components/TierUnlockToast.swift`
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift`
- Modify: `UNBOUND/Views/Home/CharacterSheet/MuscleHeatmapView.swift`
- Modify: `UNBOUND/Views/Home/CharacterSheet/BodyMapView.swift`

- [ ] **Step 1: Audit each call site**

```bash
grep -rn "\.rankAdvanced\|RankAdvance\|rankUpEvent" UNBOUND/Views --include="*.swift"
```

Each listener handles a `Notification` whose `object` is the advance event. Old shape was `RankAdvance` (SubRank-based). New shape is `SkillTierAdvance` (Task 1.4).

- [ ] **Step 2: Update each handler**

For each file from the audit, change:

```swift
.onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { note in
    if let event = note.object as? RankAdvance {
        // old logic
    }
}
```

to:

```swift
.onReceive(NotificationCenter.default.publisher(for: .rankAdvanced)) { note in
    if let advance = note.object as? SkillTierAdvance {
        if advance.isFlagship {
            // Trigger full chain-shatter cinematic
        } else {
            // Trigger quiet TierBloomToast
        }
    }
}
```

Inside `RankUpCinematic.swift`, gate the chain-shatter on `advance.isFlagship`. Inside `TierBloomToast.swift`, render the quiet toast for non-flagship advances.

- [ ] **Step 3: Verify build**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Components/Cinematic/ UNBOUND/Views/Home/
git commit -m "feat(rank): cinematic listeners read SkillTierAdvance payload"
```

---

## Task 7.3: Skill-node chip on the tree

**Files:**
- Locate: `UNBOUND/Views/Components/Unbound/SkillTreeView.swift` (verify exact path) or wherever `SkillNodeHexagon` is rendered

- [ ] **Step 1: Locate skill-node rendering**

```bash
grep -rln "SkillNodeHexagon\|node.rank\|node.levels" UNBOUND/Views --include="*.swift"
```

Find every site that read the old `node.rank` (SkillRank) or `node.levels` (SkillLevel). These now must read from `UserSkillTierState` via the rank service.

- [ ] **Step 2: Update each site to read SkillTier**

Replace any `node.rank` reads with:

```swift
@EnvironmentObject var services: ServiceContainer
// ...
let tier = services.rank.state(userId: userId).tier(for: node.id)
// Then pass `tier` to RankBadge(tier:)
```

If the view doesn't currently have `services` injected, add `@EnvironmentObject var services: ServiceContainer`. If the userId isn't available, plumb it through from the parent view.

- [ ] **Step 3: Verify build**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/  # whichever files you touched
git commit -m "feat(rank): skill-node chips read SkillTier from UserSkillTierState"
```

---

## Task 7.4: Profile rank surface

**Files:**
- Locate: `UNBOUND/Views/Profile/ProfileView.swift` (or wherever the profile screen lives)

- [ ] **Step 1: Find the profile screen**

```bash
find UNBOUND/Views -name "ProfileView.swift" -o -name "*Profile*.swift" | head
```

- [ ] **Step 2: Add a new rank section under the BuildIdentity hex**

```swift
// Inside ProfileView's body, beneath the BuildIdentity hex render:

private var rankSurface: some View {
    VStack(alignment: .leading, spacing: 18) {
        rankUpsEarnedRow
        ascendantSkillsRow
        // Badge grid stays as-is — driven by the existing badge service.
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)
}

private var rankUpsEarnedRow: some View {
    let state = services.rank.state(userId: userId)
    return HStack(alignment: .firstTextBaseline) {
        Text("RANK-UPS EARNED")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(Color.unbound.textTertiary)
        Spacer()
        Text("\(state.rankUpsEarned)")
            .font(Font.unbound.displayM)
            .foregroundStyle(Color.unbound.textPrimary)
    }
}

@ViewBuilder
private var ascendantSkillsRow: some View {
    let state = services.rank.state(userId: userId)
    if !state.ascendantSkills.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASCENDANT SKILLS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textTertiary)
            Text(displayedAscendantNames(ids: state.ascendantSkills))
                .font(.system(size: 15))
                .foregroundStyle(Color.unbound.textPrimary)
        }
    }
}

private func displayedAscendantNames(ids: [String]) -> String {
    let names = ids.compactMap { id in
        SkillTreeContent.allNodes.first(where: { $0.id == id })?.title
    }
    return names.joined(separator: " · ")
}
```

Wire `rankSurface` into the profile body's `VStack` after the BuildIdentity hex render.

- [ ] **Step 3: Verify build**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Profile/  # or whichever file
git commit -m "feat(rank): profile rank surface (Rank-Ups + Ascendant Skills)"
```

---

# Phase 8 — Legacy demolition

This phase deletes the old rank systems. Build must succeed after each task — no intermediate broken states.

## Task 8.1: Audit and delete dead rank services

**Files:**
- Audit + likely delete: `UNBOUND/Services/Ranking/MuscleRankCalculator.swift`
- Audit + likely delete: `UNBOUND/Services/Ranking/RankDecayService.swift`
- Audit: `UNBOUND/Models/AttributeRankUpEvent.swift`

- [ ] **Step 1: Audit callers**

```bash
grep -rln "MuscleRankCalculator\|RankDecayService\|AttributeRankUpEvent" UNBOUND --include="*.swift" | grep -v "Models/AttributeRankUpEvent.swift\|Services/Ranking/MuscleRank\|Services/Ranking/RankDecay"
```

Each non-self reference must be addressed before deletion:
- If the caller is dead code (e.g. inside the just-removed BodyTier path that #3 demolished), confirm with `git log -p` that nothing live needs it.
- If the caller is live, decide whether to delete the caller too or to migrate it off the dead service.

- [ ] **Step 2: Co-located types check**

```bash
for f in UNBOUND/Services/Ranking/MuscleRankCalculator.swift UNBOUND/Services/Ranking/RankDecayService.swift UNBOUND/Models/AttributeRankUpEvent.swift; do
  echo "=== $f ==="
  grep -nE "^enum |^struct |^class |^protocol |^extension " "$f"
done
```

Extract any co-located types before deleting per `feedback_check_colocated_types_before_deleting`.

- [ ] **Step 3: Delete confirmed-dead files**

```bash
git rm UNBOUND/Services/Ranking/MuscleRankCalculator.swift  # if dead
git rm UNBOUND/Services/Ranking/RankDecayService.swift      # if dead
git rm UNBOUND/Models/AttributeRankUpEvent.swift            # if dead
```

If `AttributeRankUpEvent` is still live (it's the payload for a different notification — `.attributeRankUp`, fired by AttributeService), LEAVE IT. The `.attributeRankUp` notification is independent of `.rankAdvanced` and survives this sub-project.

- [ ] **Step 4: Verify build**

```bash
xcodegen generate
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(rank): delete dead rank services post sub-project #3 demolition"
```

---

## Task 8.2: Delete SubRank

**Files:**
- Delete: `UNBOUND/Models/SubRank.swift`
- Audit + edit any remaining callers

- [ ] **Step 1: Find all callers**

```bash
grep -rn "\bSubRank\b" UNBOUND UNBOUNDTests --include="*.swift" | grep -v "UNBOUND/Models/SubRank.swift"
```

For each caller:
- If it's in a test file that tested `SubRank` behavior, the test should die alongside `SubRank` (the new `RankServiceTests` covers the replacement behavior).
- If it's in production code, the call site must be re-targeted to `SkillTier` (Phase 7 should have caught these — anything left here is a stragger).

- [ ] **Step 2: Co-located check on SubRank.swift**

```bash
grep -nE "^enum |^struct |^class |^protocol |^extension " UNBOUND/Models/SubRank.swift
```

The file contains `SubRank` and the `.rankAdvanced` notification name. The notification name is moved to `SkillTier.swift` in Task 3.2; verify it's there before deleting `SubRank.swift`. If not, copy `Notification.Name.rankAdvanced` to `SkillTier.swift` first.

- [ ] **Step 3: Delete**

```bash
git rm UNBOUND/Models/SubRank.swift
git rm UNBOUNDTests/Models/SubRank*Tests.swift  # if present
```

- [ ] **Step 4: Verify build + full test pass**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -5
```
Expected: TEST SUCCEEDED, all green.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(rank): delete SubRank (18-step E-/S+ ladder)"
```

---

## Task 8.3: Delete SkillRank and SkillNode.rank field

**Files:**
- Delete: `UNBOUND/Models/SkillRank.swift`
- Modify: `UNBOUND/Models/SkillTree.swift` — drop the `var rank: SkillRank = .d` field from `SkillNode`

- [ ] **Step 1: Audit callers**

```bash
grep -rn "\bSkillRank\b\|node\.rank\b" UNBOUND UNBOUNDTests --include="*.swift" | grep -v "UNBOUND/Models/SkillRank.swift"
```

Each `node.rank` reference must die. The `tierCriteria` field replaces it — call sites should read `services.rank.state(userId:).tier(for: node.id)` instead.

- [ ] **Step 2: Drop the field from SkillNode**

In `UNBOUND/Models/SkillTree.swift`, find:

```swift
var rank: SkillRank = .d
```

Delete the line.

- [ ] **Step 3: Delete the model file**

```bash
grep -nE "^enum |^struct |^class |^protocol |^extension " UNBOUND/Models/SkillRank.swift
# Confirm no co-located types
git rm UNBOUND/Models/SkillRank.swift
```

- [ ] **Step 4: Verify + commit**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -5
git add -A
git commit -m "chore(rank): delete SkillRank (E-S difficulty chip)"
```

---

## Task 8.4: Delete SkillLevel and SkillNode.levels field

**Files:**
- Delete: `UNBOUND/Models/SkillLevel.swift`
- Modify: `UNBOUND/Models/SkillTree.swift` — drop the `var levels: [SkillLevel] = []` field

- [ ] **Step 1: Audit callers**

```bash
grep -rn "\bSkillLevel\b\|node\.levels\b" UNBOUND UNBOUNDTests --include="*.swift" | grep -v "UNBOUND/Models/SkillLevel.swift"
```

Resolve each.

- [ ] **Step 2: Drop the field**

Remove `var levels: [SkillLevel] = []` from `SkillNode` in `SkillTree.swift`.

- [ ] **Step 3: Delete the file**

```bash
grep -nE "^enum |^struct |^class |^protocol |^extension " UNBOUND/Models/SkillLevel.swift
git rm UNBOUND/Models/SkillLevel.swift
git rm UNBOUNDTests/Models/SkillLevel*Tests.swift  # if present
```

- [ ] **Step 4: Verify + commit**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -5
git add -A
git commit -m "chore(rank): delete SkillLevel (1-5 XP ladder)"
```

---

# Phase 9 — One-time migration helper

## Task 9.1: SkillTierMigration

**Files:**
- Create: `UNBOUND/Services/Ranking/SkillTierMigration.swift`
- Test: `UNBOUNDTests/Services/SkillTierMigrationTests.swift`
- Wire into app startup (location TBD by implementer audit of `AniBodyApp.swift` or equivalent)

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Services/Ranking/SkillTierMigration.swift
import Foundation

/// One-time migration that walks the user's full log history and seeds
/// UserSkillTierState. Idempotent — guarded by UserDefaults flag.
@MainActor
enum SkillTierMigration {

    private static let migratedFlagKey = "unbound.skillTier.migratedV1"

    /// Returns true if migration ran this call.
    @discardableResult
    static func migrateIfNeeded(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double,
        rankService: RankServiceProtocol = RankService.shared,
        store: UserSkillTierStore = .shared,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let key = "\(migratedFlagKey).\(userId)"
        guard !defaults.bool(forKey: key) else { return false }

        var state = UserSkillTierState.empty
        for skill in SkillTreeContent.allNodes {
            let tier = rankService.computeTier(
                skill: skill,
                history: history,
                bodyweightKg: bodyweightKg
            )
            state.perSkill[skill.id] = tier
            if tier == .ascendant {
                state.ascendantSkills.append(skill.id)
            }
        }
        state.rankUpsEarned = state.perSkill.values
            .filter { $0 != .initiate }
            .count

        store.save(state, userId: userId)
        defaults.set(true, forKey: key)
        return true
    }
}
```

- [ ] **Step 2: Write the test**

```swift
// UNBOUNDTests/Services/SkillTierMigrationTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class SkillTierMigrationTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: UserSkillTierStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "MigrationTests-\(UUID().uuidString)")!
        store = UserSkillTierStore(defaults: defaults)
    }

    func testFirstCallSeedsState() {
        let service = RankService(store: store)
        let history = [ExerciseLogEntry(
            id: "e1",
            exerciseName: "pull-up",
            sets: [ExerciseSet(weight: nil, reps: 10, seconds: nil, isWarmup: false)],
            completedAt: .now
        )]
        let ran = SkillTierMigration.migrateIfNeeded(
            userId: "u-1",
            history: history,
            bodyweightKg: 70,
            rankService: service,
            store: store,
            defaults: defaults
        )
        XCTAssertTrue(ran)
        // At least one skill should have moved off Initiate (the one whose
        // criteria match pull-up reps).
        XCTAssertGreaterThan(store.load(userId: "u-1").rankUpsEarned, 0)
    }

    func testSecondCallIsNoop() {
        let service = RankService(store: store)
        _ = SkillTierMigration.migrateIfNeeded(
            userId: "u-1",
            history: [],
            bodyweightKg: 70,
            rankService: service,
            store: store,
            defaults: defaults
        )
        let ran = SkillTierMigration.migrateIfNeeded(
            userId: "u-1",
            history: [],
            bodyweightKg: 70,
            rankService: service,
            store: store,
            defaults: defaults
        )
        XCTAssertFalse(ran)
    }
}
```

- [ ] **Step 3: Wire into app startup**

```bash
grep -rn "@main\|AniBodyApp\|UnboundApp" UNBOUND/App --include="*.swift" | head
```

Find the app entry point. In the `body` (or wherever first-launch initialization happens), call:

```swift
Task { @MainActor in
    let userId = services.auth.currentUserId ?? "anonymous"
    let bodyweightKg = services.user.currentBodyweightKg ?? 70
    let history = await services.workoutLog.allEntries(userId: userId)
    SkillTierMigration.migrateIfNeeded(
        userId: userId,
        history: history,
        bodyweightKg: bodyweightKg
    )
}
```

Adapt the service accessor names to match the real `ServiceContainer`. If `workoutLog.allEntries` doesn't exist, grep for the actual log-retrieval method and use it.

- [ ] **Step 4: Verify + commit**

```bash
xcodegen generate
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/SkillTierMigrationTests 2>&1 | tail -10
git add -A
git commit -m "feat(rank): one-time SkillTier migration from existing log history"
```

---

# Phase 10 — Final verification

## Task 10.1: Full regression + end-to-end smoke

- [ ] **Step 1: Full test pass**

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -5
```
Expected: TEST SUCCEEDED. Note the total test count.

- [ ] **Step 2: Dead-code grep**

```bash
grep -rn "SubRank\|SkillLevel\|computeLiftRank\|MuscleRankCalculator\|RankDecayService" UNBOUND UNBOUNDTests --include="*.swift" | grep -v "^//"
```
Expected: zero matches.

Also check:
```bash
grep -rn "SkillRank\b" UNBOUND UNBOUNDTests --include="*.swift"
```
Expected: zero matches.

- [ ] **Step 3: Simulator smoke test**

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Run on simulator. Walk:
1. Onboard a new user → reach home.
2. Log a session containing one of the cluster's flagship moves (e.g. 5 pull-ups → expect Apprentice on pp.pullup → quiet bloom toast).
3. Force a high-rep session (modify the test workout or use DEBUG dev tools) to cross into Vessel → confirm chain-shatter cinematic fires.
4. Open profile → confirm "Rank-Ups Earned" counter is non-zero, "Ascendant Skills" hidden if empty.
5. Open skill tree → confirm tier chips render on every visible node.

- [ ] **Step 4: Commit any cleanup**

```bash
grep -rn "TODO\|FIXME" UNBOUND/Models/SkillTier.swift UNBOUND/Models/TierCriterion.swift UNBOUND/Models/UserSkillTierState.swift UNBOUND/Services/Ranking/ UNBOUND/Models/SkillTreeContent/Tiers/
```

If any stragglers, resolve. Then:

```bash
git add -A
git commit -m "chore(rank): final cleanup post sub-project #4"
```

---

## Self-Review Notes

**Spec coverage check** (matched against the spec sections):
- ✅ Product directive (governing principles) — enforced via standing rules + service docstrings
- ✅ Core types: `SkillTier`, `TierCriterion`, `UserSkillTierState`, `SkillTierAdvance` → Phase 1
- ✅ `TierCriterionEvaluator` (pure helper, exhaustively tested) → Task 2.1
- ✅ `UserSkillTierStore` (persistence) → Task 3.1
- ✅ `RankService` rewrite with `computeTier`/`ingest`/`state` → Task 3.2
- ✅ `SkillNode.tierCriteria` field migration → Task 4.1
- ✅ Coverage-gate test → Task 4.2
- ✅ Per-cluster authoring for all 9 prefixes (175 skills × 9 = 1575 criteria) → Tasks 5.1–5.9
- ✅ Wire cluster tables into SkillTreeContent → Task 5.10
- ✅ Lift criteria (4 lifts × 9 = 36 criteria) → Task 6.1
- ✅ RankBadge re-target → Task 7.1
- ✅ Cinematic listener payload migration with flagship gating → Task 7.2
- ✅ Skill-node tier chip wiring → Task 7.3
- ✅ Profile rank surface (Rank-Ups Earned + Ascendant Skills) → Task 7.4
- ✅ Legacy demolition (SubRank, SkillRank, SkillLevel + dead rank services) → Phase 8
- ✅ One-time migration → Task 9.1
- ✅ Final regression + smoke → Phase 10

**Placeholder scan:** No "TBD"/"fill in details"/hand-wavy steps. The authoring tasks (5.1–5.9) say "author every skill in the cluster" — that's a concrete acceptance criterion enforced by the coverage gate, not a placeholder. Skill enumeration commands provided per cluster.

**Type consistency check:** `SkillTier`, `TierCriterion`, `UserSkillTierState`, `SkillTierAdvance`, `RankService.computeTier(skill:history:bodyweightKg:)`, `RankService.ingest(session:userId:bodyweightKg:)`, `UserSkillTierStore.{load,save}`, `TierCriterionEvaluator.satisfied(criterion:history:bodyweightKg:)` — names stable across all tasks.

**Known soft spots** (flagged for the implementer):
1. `SkillNode` constructor in test helpers (Task 3.2 Step 3) — verify the real constructor signature before authoring tests.
2. `ExerciseLogEntry` / `ExerciseSet` field names (Task 2.1 Step 1) — adapt evaluator and test helpers to real types.
3. `ServiceContainer.rank` accessor name (Tasks 7.3, 7.4, 9.1) — may differ; grep `ServiceContainer.swift`.
4. App entry-point migration call site (Task 9.1 Step 3) — locate by `@main`.
5. Cluster authoring is the bulk of the work (~1575 literals). Plan for one dedicated subagent dispatch per cluster.

These are unavoidable in a plan touching this much existing code; verification commands resolve them in-task.
