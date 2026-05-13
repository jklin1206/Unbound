# Scan Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the AI-body-rating scan with a monthly transformation checkpoint that reads BuildIdentity from the trained attribute system, layer hex-tilt seeding into existing onboarding steps, and delete the Gemini grader entirely.

**Architecture:** One-shot swap (Approach A from spec). New types (`BuildSeed`, `ScanCheckpoint`, `BuildIdentityDelta`) + four new services (`BuildSeedingService`, `ScanNarrativeService`, `ScanCheckpointService`, `ScanCheckpointStore`) + six new views (`BuildHexHUD`, `ScanCadenceGate`, `ScanWritingArcView`, `FirstScanArcCard`, `NthScanEvolutionCard`, rewritten `ScanPayoffView`). `AttributeHex`, `ScanBuildDeltaCard`, `ClaudeClient`, and `OnboardingFlowViewModel` are reused. Final phase deletes `BodyAnalysisService`, `BodyAnalysisPrompt`, `BodyAnalysis`, and `Step_Verdict`.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, XCTest, xcodebuild, xcodegen, `ClaudeClient` (Anthropic Messages API).

**Spec:** [`docs/superpowers/specs/2026-05-13-scan-redesign-design.md`](../specs/2026-05-13-scan-redesign-design.md)

---

## File Structure

```
UNBOUND/
├── Models/
│   ├── BuildSeed.swift                          (new)
│   ├── BuildIdentityDelta.swift                 (new)
│   └── ScanCheckpoint.swift                     (new)
├── Services/
│   ├── Attributes/
│   │   └── AttributeService.swift               (modify — add applyBuildSeed)
│   ├── Onboarding/
│   │   └── BuildSeedingService.swift            (new)
│   └── Scan/
│       ├── ScanNarrativeService.swift           (new)
│       ├── ScanCheckpointService.swift          (new)
│       └── ScanCheckpointStore.swift            (new)
├── ViewModels/
│   └── OnboardingFlowViewModel.swift            (modify — call BuildSeedingService)
└── Views/
    ├── Components/
    │   └── BuildHexHUD.swift                    (new)
    ├── Onboarding/
    │   ├── OnboardingContainerView.swift        (modify — replace Step_Verdict route)
    │   └── Steps/
    │       ├── Step_BuildSeed.swift             (modify — add HUD)
    │       ├── Step_Goals.swift                 (modify — add HUD)
    │       ├── Step_ExerciseStyle.swift         (modify — add HUD)
    │       ├── Step11_Experience.swift          (modify — add HUD)
    │       ├── Step_ScanLive.swift              (modify — drop side angle)
    │       ├── Step_ScanReview.swift            (modify — drop side angle)
    │       ├── Step_ScanAnalyzing.swift         (modify — rename + restructure)
    │       └── Step_Verdict.swift               (DELETE — phase 9)
    ├── Scan/
    │   ├── ScanCadenceGate.swift                (new)
    │   ├── ScanWritingArcView.swift             (new, replaces analyzing)
    │   ├── FirstScanArcCard.swift               (new)
    │   ├── NthScanEvolutionCard.swift           (new)
    │   └── ScanPayoffView.swift                 (rewrite body)
    └── Home/
        └── HomeScanTile.swift                   (modify — cadence states)
└── ...

UNBOUNDTests/
├── Models/
│   ├── BuildSeedTests.swift                     (new)
│   ├── BuildIdentityDeltaTests.swift            (new)
│   └── ScanCheckpointTests.swift                (new)
├── Services/
│   ├── BuildSeedingServiceTests.swift           (new)
│   ├── ScanNarrativeServiceTests.swift          (new)
│   ├── ScanCheckpointServiceTests.swift         (new)
│   └── ScanCheckpointStoreTests.swift           (new)
└── Views/
    ├── ScanCadenceGateTests.swift               (new — gate logic)
    ├── FirstScanArcCardSnapshotTests.swift      (new)
    └── NthScanEvolutionCardSnapshotTests.swift  (new)
```

**Deletions (Phase 9):**
- `UNBOUND/Models/BodyAnalysis.swift`
- `UNBOUND/Services/BodyAnalysis/BodyAnalysisService.swift`
- `UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift`
- `UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift`
- `UNBOUND/Services/BodyAnalysis/MockBodyAnalysisService.swift`
- `UNBOUND/Views/Onboarding/Steps/Step_Verdict.swift`
- `UNBOUNDTests/Services/BodyAnalysis*` (any tests)

**Worktree:** Create a fresh worktree at `~/Documents/toji/UNBOUND-scan-redesign` on a new branch `scan-redesign-impl` off `program-redesign`. The spec already lives on `program-redesign`; cherry-pick or rebase as appropriate when ready to merge.

---

## Standing rules

These rules apply to **every task** in this plan. Don't restate them in each task; the implementer is responsible for following them.

1. **All subagent dispatches use `model: "sonnet"` or higher.** Never Haiku. (See `feedback_subagents_sonnet_minimum` memory.)
2. **`xcodebuild test` is authoritative.** SourceKit cross-file diagnostics are noise. (See `feedback_sourcekit_crossfile_noise_unbound`.)
3. **Before deleting a Swift file**, grep for unrelated types in its body and extract them first. (See `feedback_check_colocated_types_before_deleting`.)
4. **Runtime keys for catalog lookups use the space-lowercase `CatalogExercise.name`**, not `ExerciseLibrary.id`. (See `feedback_unbound_dual_exercise_catalogs`.)
5. **Setbacks are never surfaced** as regression copy. Filter or replace with quiet "Focus area" pills. (See `project_unbound_scans_never_show_setbacks`.)
6. **Apple Vision-derived body grading is out** — photos are visual proof only.
7. Build before each commit: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build` must succeed.
8. Test command: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16'`.

---

# Phase 1 — Foundations (models + seeding)

No UI in this phase. New types, extended AttributeService, the seeding service. After Phase 1, the codebase builds and tests pass; the new types are dormant — nothing calls them yet.

## Task 1.1: BuildSeed model

**Files:**
- Create: `UNBOUND/Models/BuildSeed.swift`
- Test: `UNBOUNDTests/Models/BuildSeedTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Models/BuildSeedTests.swift
import XCTest
@testable import UNBOUND

final class BuildSeedTests: XCTestCase {
    func testZeroSeedAllAxesZero() {
        let seed = BuildSeed.zero
        for key in AttributeKey.allCases {
            XCTAssertEqual(seed.value(for: key), 0)
        }
    }

    func testSettingValueRoundtrips() {
        var seed = BuildSeed.zero
        seed.set(.power, to: 7)
        XCTAssertEqual(seed.value(for: .power), 7)
        XCTAssertEqual(seed.value(for: .agility), 0)
    }

    func testAddingAccumulates() {
        var seed = BuildSeed.zero
        seed.add(2, to: .power)
        seed.add(3, to: .power)
        XCTAssertEqual(seed.value(for: .power), 5)
    }

    func testCodableRoundtrip() throws {
        var seed = BuildSeed.zero
        seed.set(.power, to: 8)
        seed.set(.endurance, to: 4)
        let data = try JSONEncoder().encode(seed)
        let decoded = try JSONDecoder().decode(BuildSeed.self, from: data)
        XCTAssertEqual(decoded, seed)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Models/BuildSeed.swift
import Foundation

/// Per-axis tendency adjustments produced by onboarding answers.
/// Added to the baseline BuildIdentity (35/100 per axis) to seed the user's
/// starting build. Caps live in BuildSeedingService, not here.
struct BuildSeed: Codable, Equatable {
    private var values: [AttributeKey: Int]

    static let zero = BuildSeed(values: [:])

    private init(values: [AttributeKey: Int]) {
        self.values = values
    }

    func value(for key: AttributeKey) -> Int {
        values[key] ?? 0
    }

    mutating func set(_ key: AttributeKey, to value: Int) {
        values[key] = value
    }

    mutating func add(_ delta: Int, to key: AttributeKey) {
        values[key, default: 0] += delta
    }
}
```

- [ ] **Step 3: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/BuildSeedTests`
Expected: 4 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/BuildSeed.swift UNBOUNDTests/Models/BuildSeedTests.swift
git commit -m "feat(scan): add BuildSeed model"
```

---

## Task 1.2: BuildIdentityDelta model

**Files:**
- Create: `UNBOUND/Models/BuildIdentityDelta.swift`
- Test: `UNBOUNDTests/Models/BuildIdentityDeltaTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Models/BuildIdentityDeltaTests.swift
import XCTest
@testable import UNBOUND

final class BuildIdentityDeltaTests: XCTestCase {
    func testPositiveDeltasOnly() {
        let delta = BuildIdentityDelta(perAxis: [
            .power: 12, .agility: -3, .control: 0, .endurance: 5,
            .mobility: -1, .explosiveness: 8
        ])
        XCTAssertEqual(delta.positiveDeltas[.power], 12)
        XCTAssertEqual(delta.positiveDeltas[.endurance], 5)
        XCTAssertEqual(delta.positiveDeltas[.explosiveness], 8)
        XCTAssertNil(delta.positiveDeltas[.agility])
        XCTAssertNil(delta.positiveDeltas[.mobility])
        XCTAssertNil(delta.positiveDeltas[.control])
    }

    func testRegressedAxesExposesNegatives() {
        let delta = BuildIdentityDelta(perAxis: [
            .power: 12, .agility: -3, .mobility: -1
        ])
        XCTAssertEqual(Set(delta.regressedAxes), Set([.agility, .mobility]))
    }

    func testPrimaryGrowthAxisPicksMaxPositive() {
        let delta = BuildIdentityDelta(perAxis: [
            .power: 12, .endurance: 5, .explosiveness: 8
        ])
        XCTAssertEqual(delta.primaryGrowthAxis, .power)
    }

    func testPrimaryGrowthAxisNilWhenNoPositive() {
        let delta = BuildIdentityDelta(perAxis: [
            .power: -1, .agility: -5
        ])
        XCTAssertNil(delta.primaryGrowthAxis)
    }

    func testCodableRoundtrip() throws {
        let delta = BuildIdentityDelta(perAxis: [.power: 12, .agility: -3])
        let data = try JSONEncoder().encode(delta)
        let decoded = try JSONDecoder().decode(BuildIdentityDelta.self, from: data)
        XCTAssertEqual(decoded, delta)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Models/BuildIdentityDelta.swift
import Foundation

/// Per-axis change between two BuildIdentity snapshots. UI filters to
/// positive deltas only — regressions never appear as negative numbers
/// (see project_unbound_scans_never_show_setbacks). The `regressedAxes`
/// list exists so the UI can render quiet "Focus area" pills instead.
struct BuildIdentityDelta: Codable, Equatable {
    let perAxis: [AttributeKey: Int]

    init(perAxis: [AttributeKey: Int]) {
        self.perAxis = perAxis
    }

    var positiveDeltas: [AttributeKey: Int] {
        perAxis.filter { $0.value > 0 }
    }

    var regressedAxes: [AttributeKey] {
        perAxis.filter { $0.value < 0 }.map(\.key)
    }

    var primaryGrowthAxis: AttributeKey? {
        positiveDeltas.max(by: { $0.value < $1.value })?.key
    }
}
```

- [ ] **Step 3: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/BuildIdentityDeltaTests`
Expected: 5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/BuildIdentityDelta.swift UNBOUNDTests/Models/BuildIdentityDeltaTests.swift
git commit -m "feat(scan): add BuildIdentityDelta with positive-only filter"
```

---

## Task 1.3: Extend AttributeService with applyBuildSeed

**Files:**
- Modify: `UNBOUND/Services/Attributes/AttributeService.swift`
- Test: `UNBOUNDTests/Services/AttributeServiceBuildSeedTests.swift` (new)

The existing `applySeed(Set<AttributeKey>, userId:)` flattens picks to peak=current=15. The new `applyBuildSeed` lets `BuildSeedingService` write graduated per-axis values that respect a baseline + caps.

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/AttributeServiceBuildSeedTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class AttributeServiceBuildSeedTests: XCTestCase {
    func testApplyBuildSeedWritesPerAxisValues() {
        let store = InMemoryAttributeProfileStore()
        let service = AttributeService(catalog: AttributeCatalog.shared, store: store)
        var seed = BuildSeed.zero
        seed.set(.power, to: 12)
        seed.set(.control, to: 8)

        service.applyBuildSeed(seed, baseline: 35, userId: "u-1")

        let profile = service.profile(userId: "u-1")
        XCTAssertEqual(profile.value(for: .power).current, 47)
        XCTAssertEqual(profile.value(for: .power).peak, 47)
        XCTAssertEqual(profile.value(for: .control).current, 43)
        XCTAssertEqual(profile.value(for: .agility).current, 35)
        XCTAssertEqual(profile.value(for: .endurance).current, 35)
    }

    func testApplyBuildSeedClampsTo100() {
        let store = InMemoryAttributeProfileStore()
        let service = AttributeService(catalog: AttributeCatalog.shared, store: store)
        var seed = BuildSeed.zero
        seed.set(.power, to: 200)
        service.applyBuildSeed(seed, baseline: 35, userId: "u-1")
        XCTAssertEqual(service.profile(userId: "u-1").value(for: .power).current, 100)
    }

    func testApplyBuildSeedClampsAtZero() {
        let store = InMemoryAttributeProfileStore()
        let service = AttributeService(catalog: AttributeCatalog.shared, store: store)
        var seed = BuildSeed.zero
        seed.set(.power, to: -50)
        service.applyBuildSeed(seed, baseline: 35, userId: "u-1")
        XCTAssertEqual(service.profile(userId: "u-1").value(for: .power).current, 0)
    }
}
```

- [ ] **Step 2: Add `applyBuildSeed` to the protocol and both implementations**

In `UNBOUND/Services/Attributes/AttributeService.swift`, add to `AttributeServiceProtocol`:

```swift
/// Apply a graduated build seed to the user's profile. Each axis is set
/// to (baseline + seed.value(for: key)), clamped to [0, 100]. Both `peak`
/// and `current` are written to the same value. Persists.
func applyBuildSeed(_ seed: BuildSeed, baseline: Int, userId: String)
```

In `AttributeService` (the real impl):

```swift
func applyBuildSeed(_ seed: BuildSeed, baseline: Int, userId: String) {
    var profile = profile(userId: userId)
    let now = Date()
    for key in AttributeKey.allCases {
        let raw = baseline + seed.value(for: key)
        let clamped = max(0, min(100, raw))
        profile.set(key, AttributeValue(peak: clamped, current: clamped, lastContributionAt: now))
    }
    profile.computedAt = now
    store.save(profile)
}
```

In `MockAttributeService`:

```swift
var lastBuildSeed: BuildSeed? = nil
var lastBaseline: Int? = nil
func applyBuildSeed(_ seed: BuildSeed, baseline: Int, userId: String) {
    lastBuildSeed = seed
    lastBaseline = baseline
    var profile = profileByUser[userId] ?? .empty(userId: userId, at: .now)
    for key in AttributeKey.allCases {
        let raw = baseline + seed.value(for: key)
        let clamped = max(0, min(100, raw))
        profile.set(key, AttributeValue(peak: clamped, current: clamped, lastContributionAt: .now))
    }
    profileByUser[userId] = profile
}
```

- [ ] **Step 3: Provide an `InMemoryAttributeProfileStore` test helper if it doesn't exist**

If `UNBOUNDTests/Helpers/InMemoryAttributeProfileStore.swift` does not exist, create it:

```swift
// UNBOUNDTests/Helpers/InMemoryAttributeProfileStore.swift
import Foundation
@testable import UNBOUND

@MainActor
final class InMemoryAttributeProfileStore: AttributeProfileStoreProtocol {
    private var profiles: [String: AttributeProfile] = [:]
    private var pinned: [String: AttributeProfile] = [:]
    private var historyByUser: [String: [AttributeProfile]] = [:]

    func load(userId: String) -> AttributeProfile? { profiles[userId] }
    func save(_ profile: AttributeProfile) { profiles[profile.userId] = profile }
    func pin(_ profile: AttributeProfile, toScan scanId: String) {
        pinned[scanId] = profile
        historyByUser[profile.userId, default: []].append(profile)
    }
    func history(userId: String) -> [AttributeProfile] {
        historyByUser[userId] ?? []
    }
}
```

(If the protocol surface differs, match the existing protocol exactly — read `AttributeProfileStore.swift` first.)

- [ ] **Step 4: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/AttributeServiceBuildSeedTests`
Expected: 3 tests pass. Run the full test suite as a regression: existing `applySeed` tests must still pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Attributes/AttributeService.swift UNBOUNDTests/Services/AttributeServiceBuildSeedTests.swift UNBOUNDTests/Helpers/InMemoryAttributeProfileStore.swift
git commit -m "feat(scan): add AttributeService.applyBuildSeed for graduated per-axis seeding"
```

---

## Task 1.4: BuildSeedingService

The orchestrator that converts onboarding answers → `BuildSeed`. Inputs are POD enums/sets so the service is testable without a flow VM.

**Files:**
- Create: `UNBOUND/Services/Onboarding/BuildSeedingService.swift`
- Test: `UNBOUNDTests/Services/BuildSeedingServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/BuildSeedingServiceTests.swift
import XCTest
@testable import UNBOUND

final class BuildSeedingServiceTests: XCTestCase {

    func testZeroInputProducesZeroSeed() {
        let seed = BuildSeedingService.seed(
            experience: nil,
            exerciseStyles: [],
            goals: [],
            seededAttributes: []
        )
        for key in AttributeKey.allCases {
            XCTAssertEqual(seed.value(for: key), 0)
        }
    }

    func testCalisthenicsStyleTiltsControlAndMobility() {
        let seed = BuildSeedingService.seed(
            experience: .twoToFive,
            exerciseStyles: [.calisthenics],
            goals: [],
            seededAttributes: []
        )
        XCTAssertGreaterThan(seed.value(for: .control), 0)
        XCTAssertGreaterThan(seed.value(for: .mobility), 0)
        XCTAssertEqual(seed.value(for: .power), 0)
    }

    func testHeavyLiftingStyleTiltsPower() {
        let seed = BuildSeedingService.seed(
            experience: .twoToFive,
            exerciseStyles: [.heavyLifting],
            goals: [],
            seededAttributes: []
        )
        XCTAssertGreaterThan(seed.value(for: .power), 0)
        XCTAssertEqual(seed.value(for: .endurance), 0)
    }

    func testGoalsContribute() {
        let seed = BuildSeedingService.seed(
            experience: .twoToFive,
            exerciseStyles: [],
            goals: [.buildPower, .improveMobility],
            seededAttributes: []
        )
        XCTAssertGreaterThan(seed.value(for: .power), 0)
        XCTAssertGreaterThan(seed.value(for: .mobility), 0)
    }

    func testBuildSeedAttributesContribute() {
        let seed = BuildSeedingService.seed(
            experience: .twoToFive,
            exerciseStyles: [],
            goals: [],
            seededAttributes: [.endurance, .agility]
        )
        XCTAssertGreaterThan(seed.value(for: .endurance), 0)
        XCTAssertGreaterThan(seed.value(for: .agility), 0)
    }

    func testExperienceMultiplierScalesMagnitude() {
        // Same picks at different experience levels — seed magnitudes scale.
        let beginner = BuildSeedingService.seed(
            experience: .justStarting,
            exerciseStyles: [.heavyLifting],
            goals: [.buildPower],
            seededAttributes: [.power]
        )
        let veteran = BuildSeedingService.seed(
            experience: .fivePlus,
            exerciseStyles: [.heavyLifting],
            goals: [.buildPower],
            seededAttributes: [.power]
        )
        XCTAssertLessThan(beginner.value(for: .power), veteran.value(for: .power))
    }

    func testGlobalCapAt18() {
        // Max-stack: heavy lifting + build-power goal + build-seed power +
        // 5+ years veteran multiplier. Should never exceed +18 per axis.
        let seed = BuildSeedingService.seed(
            experience: .fivePlus,
            exerciseStyles: [.heavyLifting],
            goals: [.buildPower],
            seededAttributes: [.power]
        )
        XCTAssertLessThanOrEqual(seed.value(for: .power), 18)
    }

    func testJustStartingExperienceProducesSmallerSeed() {
        let seed = BuildSeedingService.seed(
            experience: .justStarting,
            exerciseStyles: [.heavyLifting],
            goals: [.buildPower],
            seededAttributes: [.power]
        )
        // Multiplier 0.4× × max-stack-22-raw = 8 (rounded down).
        XCTAssertLessThanOrEqual(seed.value(for: .power), 10)
    }
}
```

- [ ] **Step 2: Read `Goal.swift` and `ExerciseStyle.swift` and `Experience.swift` to confirm enum case names**

```bash
grep -n "case " UNBOUND/Models/Goal.swift UNBOUND/Models/ExerciseStyle.swift UNBOUND/Models/Experience.swift
```

If case names differ from the test values (`.calisthenics`, `.heavyLifting`, `.buildPower`, `.improveMobility`, `.justStarting`, `.twoToFive`, `.fivePlus`), update the test enum references AND the service mapping to match the real names. Don't rename existing enums.

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/Onboarding/BuildSeedingService.swift
import Foundation

/// Computes a BuildSeed from onboarding answers. Pure deterministic math —
/// no LLM, no photo, no I/O. Per-source caps + global cap of +18 ensure
/// every user stays near baseline (35 + 18 = 53 max on any single axis).
///
/// See spec section "Seeding math" for the rationale.
enum BuildSeedingService {

    private static let exerciseStyleCap = 8
    private static let goalsCap = 6
    private static let buildSeedCap = 8
    private static let globalCap = 18

    static func seed(
        experience: Experience?,
        exerciseStyles: Set<ExerciseStyle>,
        goals: Set<Goal>,
        seededAttributes: Set<AttributeKey>
    ) -> BuildSeed {

        var raw = BuildSeed.zero

        // Exercise style — cap +8 per axis per style.
        for style in exerciseStyles {
            for (key, contribution) in styleContributions(for: style) {
                raw.add(min(contribution, exerciseStyleCap), to: key)
            }
        }

        // Goals — cap +6 per axis per goal.
        for goal in goals {
            for (key, contribution) in goalContributions(for: goal) {
                raw.add(min(contribution, goalsCap), to: key)
            }
        }

        // Build seed picks — cap +8 per axis.
        for key in seededAttributes {
            raw.add(min(8, buildSeedCap), to: key)
        }

        let multiplier = experienceMultiplier(for: experience)
        var scaled = BuildSeed.zero
        for key in AttributeKey.allCases {
            let value = Int(Double(raw.value(for: key)) * multiplier)
            scaled.set(key, to: min(value, globalCap))
        }
        return scaled
    }

    // MARK: - Contributions

    private static func styleContributions(for style: ExerciseStyle) -> [AttributeKey: Int] {
        switch style {
        case .calisthenics:   return [.control: 8, .mobility: 6]
        case .heavyLifting:   return [.power: 8]
        case .olympic:        return [.explosiveness: 8, .power: 6]
        case .cardio:         return [.endurance: 8]
        case .yoga:           return [.mobility: 8]
        case .sports:         return [.agility: 6, .endurance: 6]
        case .notTraining:    return [:]
        }
    }

    private static func goalContributions(for goal: Goal) -> [AttributeKey: Int] {
        switch goal {
        case .buildPower:        return [.power: 6]
        case .improveMovement:   return [.agility: 6]
        case .becomeExplosive:   return [.explosiveness: 6]
        case .increaseEndurance: return [.endurance: 6]
        case .improveMobility:   return [.mobility: 6]
        case .developControl:    return [.control: 6]
        }
    }

    private static func experienceMultiplier(for experience: Experience?) -> Double {
        switch experience {
        case .justStarting: return 0.4
        case .sixMoToTwo:   return 0.7
        case .twoToFive:    return 1.0
        case .fivePlus:     return 1.2
        case .none:         return 0.7  // unknown defaults to moderate
        }
    }
}
```

**IMPORTANT**: If `Goal` / `ExerciseStyle` / `Experience` case names in the codebase differ from the names above, **adjust the switches to match the real enum cases**. Don't rename the enums. The test enum references must also match the real cases. The plan author confirmed these enums exist but did not verify exact case spellings — Step 2 above is the verification step.

- [ ] **Step 4: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/BuildSeedingServiceTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Onboarding/BuildSeedingService.swift UNBOUNDTests/Services/BuildSeedingServiceTests.swift
git commit -m "feat(scan): add BuildSeedingService — deterministic onboarding-answers-to-BuildSeed"
```

---

# Phase 2 — Narrative service (Claude Haiku)

`ScanNarrativeService` writes 2-3 sentence flavor narratives around already-derived BuildIdentity data. It never sees a photo and never grades anything.

## Task 2.1: ScanNarrativeService + deterministic fallback

**Files:**
- Create: `UNBOUND/Services/Scan/ScanNarrativeService.swift`
- Test: `UNBOUNDTests/Services/ScanNarrativeServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/ScanNarrativeServiceTests.swift
import XCTest
@testable import UNBOUND

final class ScanNarrativeServiceTests: XCTestCase {

    func testFirstScanFallbackTemplate_balanced() {
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let result = ScanNarrativeService.fallbackFirstScanNarrative(for: identity)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("balanced") || result.contains("Balanced"))
    }

    func testFirstScanFallbackTemplate_powerSpecialist() {
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let result = ScanNarrativeService.fallbackFirstScanNarrative(for: identity)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.lowercased().contains("power"))
    }

    func testEvolutionFallbackHighlightsPositiveGrowth() {
        let prior = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let current = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let delta = BuildIdentityDelta(perAxis: [.power: 12, .control: 5, .agility: -2])
        let result = ScanNarrativeService.fallbackEvolutionNarrative(
            prior: prior, current: current, delta: delta
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("Power") || result.contains("power"))
        // Never mentions the negative axis.
        XCTAssertFalse(result.lowercased().contains("agility decline"))
        XCTAssertFalse(result.contains("-2"))
    }

    func testEvolutionFallbackHandlesNoPositiveGrowth() {
        let prior = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let current = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let delta = BuildIdentityDelta(perAxis: [.power: 0, .control: 0])
        let result = ScanNarrativeService.fallbackEvolutionNarrative(
            prior: prior, current: current, delta: delta
        )
        XCTAssertFalse(result.isEmpty)
        // Holding-the-line copy — no negative framing.
        XCTAssertTrue(result.lowercased().contains("held") || result.lowercased().contains("steady"))
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Services/Scan/ScanNarrativeService.swift
import Foundation

/// Writes lightweight narrative copy around already-derived BuildIdentity
/// data. NEVER sees a photo. NEVER grades the body. Uses Claude Haiku 4.5
/// for the live path and a deterministic template as fallback.
///
/// See project_unbound_scan_not_source_of_truth + project_unbound_create_your_own_arc.
enum ScanNarrativeService {

    static func firstScanNarrative(
        for identity: BuildIdentity,
        client: ClaudeClient = .shared
    ) async -> String {
        let system = """
        You are writing 2-3 sentences of flavor copy for a fitness app's \
        first body-scan checkpoint. The user just seeded a starting build \
        tendency through onboarding — the scan is the visual anchor for \
        their training arc. NEVER grade the body. NEVER mention body fat, \
        muscle mass, or appearance. NEVER claim medical or scientific \
        authority. Frame the moment as "your arc begins" — earned through \
        training, not assigned.
        """
        let userText = """
        Build shape: \(identity.shape.rawValue)
        Primary axis: \(identity.primary?.rawValue ?? "none")
        Secondary axis: \(identity.secondary?.rawValue ?? "none")
        Display name: \(identity.displayName)
        Tagline: \(identity.tagline)

        Write 2-3 sentences anchoring this starting point. Address the \
        reader as "you". No headings, no bullets, no quotes.
        """
        do {
            return try await client.sendText(
                model: .haiku45, system: system, userText: userText, maxTokens: 256
            )
        } catch {
            return fallbackFirstScanNarrative(for: identity)
        }
    }

    static func evolutionNarrative(
        prior: BuildIdentity,
        current: BuildIdentity,
        delta: BuildIdentityDelta,
        client: ClaudeClient = .shared
    ) async -> String {
        let system = """
        You are writing 2-3 sentences for a fitness app's monthly scan. The \
        user has trained for ~30 days. Their BuildIdentity moved per the \
        delta. ONLY mention positive growth. If an axis regressed, do not \
        mention it. NEVER grade the body or talk about appearance. NEVER \
        mention body fat or muscle mass. Tone: earned, specific, quietly \
        proud. End on a forward-looking line.
        """
        let positives = delta.positiveDeltas
            .map { "\($0.key.rawValue): +\($0.value)" }
            .joined(separator: ", ")
        let userText = """
        Prior build: \(prior.displayName)
        Current build: \(current.displayName)
        Positive deltas: \(positives.isEmpty ? "none — user held the line" : positives)

        Write 2-3 sentences on the evolution. Address the reader as "you". \
        No headings, no bullets, no quotes.
        """
        do {
            return try await client.sendText(
                model: .haiku45, system: system, userText: userText, maxTokens: 256
            )
        } catch {
            return fallbackEvolutionNarrative(prior: prior, current: current, delta: delta)
        }
    }

    // MARK: - Deterministic fallbacks

    static func fallbackFirstScanNarrative(for identity: BuildIdentity) -> String {
        switch identity.shape {
        case .balancedAthlete:
            return "Your arc begins balanced across every axis. No single specialty yet — that's a starting line, not a verdict. Come back in 30 days and we'll see where you've tilted."
        case .hybridAthlete:
            return "Your arc begins as a hybrid athlete — multiple strengths, no single specialty. The next 30 days of training will start sharpening the lines."
        case .specialist:
            let axis = identity.primary?.buildVocab ?? "Balanced"
            return "Your arc begins tilted toward \(axis). That's where you walked in — now we'll see how it compounds with training. Come back in 30 days."
        case .hybrid:
            let primary = identity.primary?.buildVocab ?? "Balanced"
            let secondary = identity.secondary?.buildVocab ?? ""
            let secondaryText = secondary.isEmpty ? "" : " with strong \(secondary)"
            return "Your arc begins as a \(primary) hybrid\(secondaryText). Two strengths to lean into, room everywhere else. The next checkpoint shows what 30 days does."
        case .lean:
            let axis = identity.primary?.buildVocab ?? "Balanced"
            return "Your arc begins trending \(axis). A clear direction, but plenty of room to grow elsewhere. Come back in 30 days."
        }
    }

    static func fallbackEvolutionNarrative(
        prior: BuildIdentity,
        current: BuildIdentity,
        delta: BuildIdentityDelta
    ) -> String {
        let positives = delta.positiveDeltas
        guard !positives.isEmpty else {
            return "Your build held steady this month. Consistency is its own kind of win — keep the work going and the next checkpoint will show more."
        }
        if let primary = delta.primaryGrowthAxis,
           let value = positives[primary] {
            let other = positives.keys.filter { $0 != primary }.first
            let secondaryClause: String
            if let other, let v = positives[other], v > 0 {
                secondaryClause = " \(other.buildVocab) climbed +\(v) alongside it."
            } else {
                secondaryClause = ""
            }
            return "Your \(primary.buildVocab) grew +\(value) over the last month.\(secondaryClause) The arc is compounding — keep training and the next checkpoint will keep moving."
        }
        return "Your build moved this month. Keep training — the next checkpoint will show more."
    }
}
```

- [ ] **Step 3: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/ScanNarrativeServiceTests`
Expected: 4 tests pass. (We're not testing the live Haiku path here — that needs a mocked client, covered next task.)

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Services/Scan/ScanNarrativeService.swift UNBOUNDTests/Services/ScanNarrativeServiceTests.swift
git commit -m "feat(scan): add ScanNarrativeService with Haiku live path + deterministic fallback"
```

---

# Phase 3 — Checkpoint model + service + persistence

## Task 3.1: ScanCheckpoint model

**Files:**
- Create: `UNBOUND/Models/ScanCheckpoint.swift`
- Test: `UNBOUNDTests/Models/ScanCheckpointTests.swift`

- [ ] **Step 1: Read existing photo persistence pattern**

```bash
grep -n "PhotoAsset\|jpegData\|saveScanPhoto" UNBOUND/Services/ImageCapture/*.swift UNBOUND/Services/Storage/*.swift | head -20
```

The existing scan persistence stores photos as on-disk JPEGs keyed by scan id. Mirror that pattern — `ScanCheckpoint` references the photo by id/path, not as raw `Data` in the struct.

- [ ] **Step 2: Write the failing tests**

```swift
// UNBOUNDTests/Models/ScanCheckpointTests.swift
import XCTest
@testable import UNBOUND

final class ScanCheckpointTests: XCTestCase {
    func testCodableRoundtripFirstCheckpoint() throws {
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let checkpoint = ScanCheckpoint(
            id: "scan-1",
            userId: "u-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "scan-1-front.jpg",
            buildIdentitySnapshot: identity,
            narrative: "Your arc begins.",
            deltaFromPrior: nil
        )
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ScanCheckpoint.self, from: data)
        XCTAssertEqual(decoded, checkpoint)
    }

    func testCodableRoundtripWithDelta() throws {
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let delta = BuildIdentityDelta(perAxis: [.power: 12, .agility: -2])
        let checkpoint = ScanCheckpoint(
            id: "scan-2",
            userId: "u-1",
            createdAt: Date(timeIntervalSince1970: 1_702_592_000),
            photoFilename: "scan-2-front.jpg",
            buildIdentitySnapshot: identity,
            narrative: "Your Power grew +12.",
            deltaFromPrior: delta
        )
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ScanCheckpoint.self, from: data)
        XCTAssertEqual(decoded, checkpoint)
        XCTAssertEqual(decoded.deltaFromPrior?.positiveDeltas[.power], 12)
    }

    func testIsFirstScan() {
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let first = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: .now,
            photoFilename: "p.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        XCTAssertTrue(first.isFirstScan)
    }
}
```

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Models/ScanCheckpoint.swift
import Foundation

/// Monthly scan record. Replaces BodyAnalysis (deleted in Phase 9).
/// Photos are visual proof; the BuildIdentity snapshot is read FROM the
/// attribute system, never derived from the photo.
struct ScanCheckpoint: Codable, Equatable, Identifiable {
    let id: String
    let userId: String
    let createdAt: Date
    /// Filename of the JPEG on disk. Resolved by ScanCheckpointStore /
    /// ImageCaptureService. Never raw photo data inside the model.
    let photoFilename: String
    let buildIdentitySnapshot: BuildIdentity
    let narrative: String
    let deltaFromPrior: BuildIdentityDelta?

    var isFirstScan: Bool { deltaFromPrior == nil }
}

// MARK: - BuildIdentity Codable conformance
//
// BuildIdentity currently isn't Codable (verify with grep before assuming).
// If it isn't, add conformance via this extension. Keep the conformance in
// THIS file (next to ScanCheckpoint) so it's discoverable from the persistence
// touchpoint.

extension BuildIdentity: Codable {
    enum CodingKeys: String, CodingKey { case primary, secondary, shape }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let primary = try c.decodeIfPresent(AttributeKey.self, forKey: .primary)
        let secondary = try c.decodeIfPresent(AttributeKey.self, forKey: .secondary)
        let shape = try c.decode(Shape.self, forKey: .shape)
        self.init(primary: primary, secondary: secondary, shape: shape)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(primary, forKey: .primary)
        try c.encodeIfPresent(secondary, forKey: .secondary)
        try c.encode(shape, forKey: .shape)
    }
}
```

Before adding the `BuildIdentity: Codable` extension, verify with:
```bash
grep -n "extension BuildIdentity.*Codable\|: .*Codable" UNBOUND/Models/BuildIdentity.swift
```

If conformance already exists, **remove that extension from `ScanCheckpoint.swift`** to avoid duplicate-conformance compile errors.

- [ ] **Step 4: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/ScanCheckpointTests`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/ScanCheckpoint.swift UNBOUNDTests/Models/ScanCheckpointTests.swift
git commit -m "feat(scan): add ScanCheckpoint model + BuildIdentity Codable"
```

---

## Task 3.2: ScanCheckpointStore (persistence)

**Files:**
- Create: `UNBOUND/Services/Scan/ScanCheckpointStore.swift`
- Test: `UNBOUNDTests/Services/ScanCheckpointStoreTests.swift`

- [ ] **Step 1: Read existing scan persistence to confirm directory + iCloud sync pattern**

```bash
grep -rn "FileManager\|cachesDirectory\|documentsDirectory" UNBOUND/Services/Scan UNBOUND/Services/ImageCapture --include="*.swift" | head -20
```

Match the existing storage location for scan-related artifacts. If a `ScanArtifactStore` or similar exists already, study it before defining the new store.

- [ ] **Step 2: Write the failing tests**

```swift
// UNBOUNDTests/Services/ScanCheckpointStoreTests.swift
import XCTest
@testable import UNBOUND

final class ScanCheckpointStoreTests: XCTestCase {
    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func testSaveAndLoadRoundtrip() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        let identity = BuildIdentity(primary: .power, secondary: nil, shape: .specialist)
        let checkpoint = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "s1-front.jpg", buildIdentitySnapshot: identity,
            narrative: "Your arc begins.", deltaFromPrior: nil
        )
        try store.save(checkpoint)
        let loaded = try store.load(id: "s1")
        XCTAssertEqual(loaded, checkpoint)
    }

    func testHistoryOrderedNewestLast() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let older = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "a.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        let newer = ScanCheckpoint(
            id: "s2", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_702_000_000),
            photoFilename: "b.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        try store.save(older)
        try store.save(newer)
        let history = try store.history(userId: "u-1")
        XCTAssertEqual(history.map(\.id), ["s1", "s2"])
    }

    func testMostRecentReturnsNewest() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        let identity = BuildIdentity(primary: nil, secondary: nil, shape: .balancedAthlete)
        let older = ScanCheckpoint(
            id: "s1", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoFilename: "a.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        let newer = ScanCheckpoint(
            id: "s2", userId: "u-1", createdAt: Date(timeIntervalSince1970: 1_702_000_000),
            photoFilename: "b.jpg", buildIdentitySnapshot: identity,
            narrative: "", deltaFromPrior: nil
        )
        try store.save(older)
        try store.save(newer)
        XCTAssertEqual(try store.mostRecent(userId: "u-1")?.id, "s2")
    }

    func testMostRecentNilWhenEmpty() throws {
        let store = ScanCheckpointStore(directory: tmpDir)
        XCTAssertNil(try store.mostRecent(userId: "u-1"))
    }
}
```

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/Scan/ScanCheckpointStore.swift
import Foundation

/// Filesystem-backed persistence for ScanCheckpoint. JSON files on disk,
/// one per checkpoint. History queries scan and filter by userId.
/// Mirrors the existing scan-artifact storage pattern.
final class ScanCheckpointStore {

    static let shared = ScanCheckpointStore()

    private let directory: URL
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        if let directory {
            self.directory = directory
        } else {
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.directory = docs.appendingPathComponent("scan-checkpoints", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    func save(_ checkpoint: ScanCheckpoint) throws {
        let data = try encoder.encode(checkpoint)
        try data.write(to: url(for: checkpoint.id), options: .atomic)
    }

    func load(id: String) throws -> ScanCheckpoint {
        let data = try Data(contentsOf: url(for: id))
        return try decoder.decode(ScanCheckpoint.self, from: data)
    }

    func history(userId: String) throws -> [ScanCheckpoint] {
        let files = try fileManager.contentsOfDirectory(at: directory,
                                                       includingPropertiesForKeys: nil)
        var checkpoints: [ScanCheckpoint] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let cp = try? decoder.decode(ScanCheckpoint.self, from: data),
               cp.userId == userId {
                checkpoints.append(cp)
            }
        }
        return checkpoints.sorted { $0.createdAt < $1.createdAt }
    }

    func mostRecent(userId: String) throws -> ScanCheckpoint? {
        try history(userId: userId).last
    }
}
```

- [ ] **Step 4: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/ScanCheckpointStoreTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Scan/ScanCheckpointStore.swift UNBOUNDTests/Services/ScanCheckpointStoreTests.swift
git commit -m "feat(scan): add ScanCheckpointStore JSON persistence"
```

---

## Task 3.3: ScanCheckpointService (orchestrator)

**Files:**
- Create: `UNBOUND/Services/Scan/ScanCheckpointService.swift`
- Test: `UNBOUNDTests/Services/ScanCheckpointServiceTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/ScanCheckpointServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class ScanCheckpointServiceTests: XCTestCase {

    private var tmpDir: URL!
    private var store: ScanCheckpointStore!
    private var attribute: MockAttributeService!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        store = ScanCheckpointStore(directory: tmpDir)
        attribute = MockAttributeService()
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func testFirstCommitProducesNoDelta() async throws {
        // Seed mock attribute with a power-tilted profile.
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(peak: 53, current: 53, lastContributionAt: .now))
        attribute.profileByUser["u-1"] = profile

        let service = ScanCheckpointService(
            store: store,
            attribute: attribute,
            photoWriter: StubPhotoWriter(),
            narrative: { _ in "first arc narrative" },
            evolutionNarrative: { _, _, _ in "should not be called" }
        )
        let checkpoint = try await service.commit(
            userId: "u-1",
            photoData: Data([0xFF, 0xD8]),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(checkpoint.isFirstScan)
        XCTAssertNil(checkpoint.deltaFromPrior)
        XCTAssertEqual(checkpoint.narrative, "first arc narrative")
        XCTAssertEqual(checkpoint.buildIdentitySnapshot.primary, .power)
    }

    func testSecondCommitProducesPositiveDelta() async throws {
        // First scan: power=50.
        var first = AttributeProfile.empty(userId: "u-1", at: .now)
        first.set(.power, AttributeValue(peak: 50, current: 50, lastContributionAt: .now))
        attribute.profileByUser["u-1"] = first

        let service = ScanCheckpointService(
            store: store, attribute: attribute, photoWriter: StubPhotoWriter(),
            narrative: { _ in "n1" },
            evolutionNarrative: { _, _, _ in "n2-evolution" }
        )
        _ = try await service.commit(
            userId: "u-1", photoData: Data([0xFF]),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        // Second scan: power=62.
        var second = AttributeProfile.empty(userId: "u-1", at: .now)
        second.set(.power, AttributeValue(peak: 62, current: 62, lastContributionAt: .now))
        attribute.profileByUser["u-1"] = second

        let cp = try await service.commit(
            userId: "u-1", photoData: Data([0xFF]),
            now: Date(timeIntervalSince1970: 1_702_592_000)
        )
        XCTAssertFalse(cp.isFirstScan)
        XCTAssertEqual(cp.deltaFromPrior?.positiveDeltas[.power], 12)
        XCTAssertEqual(cp.narrative, "n2-evolution")
    }

    func testCommitPersistsPhotoAndCheckpoint() async throws {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        profile.set(.power, AttributeValue(peak: 50, current: 50, lastContributionAt: .now))
        attribute.profileByUser["u-1"] = profile

        let writer = StubPhotoWriter()
        let service = ScanCheckpointService(
            store: store, attribute: attribute, photoWriter: writer,
            narrative: { _ in "n" },
            evolutionNarrative: { _, _, _ in "n2" }
        )
        let cp = try await service.commit(
            userId: "u-1", photoData: Data([0xFF, 0xD8, 0xFF]),
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(writer.written.count, 1)
        XCTAssertEqual(writer.written.first?.filename, cp.photoFilename)
        let reloaded = try store.load(id: cp.id)
        XCTAssertEqual(reloaded, cp)
    }
}

// MARK: - Test stub

private final class StubPhotoWriter: ScanPhotoWriting {
    var written: [(filename: String, data: Data)] = []
    func write(_ data: Data, filename: String) throws {
        written.append((filename, data))
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Services/Scan/ScanCheckpointService.swift
import Foundation

/// Minimal protocol for writing photo bytes to disk. Real impl wires
/// through the existing image-capture/storage pipeline; tests inject a stub.
protocol ScanPhotoWriting {
    func write(_ data: Data, filename: String) throws
}

/// Orchestrates the new scan flow: reads BuildIdentity from the attribute
/// system (never from the photo), persists photo + checkpoint, calls Claude
/// Haiku for narrative copy. Never grades the body.
@MainActor
final class ScanCheckpointService {

    static let shared = ScanCheckpointService(
        store: .shared,
        attribute: AttributeService.shared,
        photoWriter: DefaultScanPhotoWriter(),
        narrative: ScanNarrativeService.firstScanNarrative,
        evolutionNarrative: ScanNarrativeService.evolutionNarrative
    )

    private let store: ScanCheckpointStore
    private let attribute: AttributeServiceProtocol
    private let photoWriter: ScanPhotoWriting
    private let firstNarrative: (BuildIdentity) async -> String
    private let evolutionNarrative: (BuildIdentity, BuildIdentity, BuildIdentityDelta) async -> String

    init(
        store: ScanCheckpointStore,
        attribute: AttributeServiceProtocol,
        photoWriter: ScanPhotoWriting,
        narrative: @escaping (BuildIdentity) async -> String,
        evolutionNarrative: @escaping (BuildIdentity, BuildIdentity, BuildIdentityDelta) async -> String
    ) {
        self.store = store
        self.attribute = attribute
        self.photoWriter = photoWriter
        self.firstNarrative = narrative
        self.evolutionNarrative = evolutionNarrative
    }

    @discardableResult
    func commit(userId: String, photoData: Data, now: Date = .now) async throws -> ScanCheckpoint {
        let snapshot = attribute.snapshot(userId: userId, asOf: now)
        let identity = snapshot.buildIdentity

        let prior = try? store.mostRecent(userId: userId)

        let scanId = UUID().uuidString
        let filename = "\(scanId)-front.jpg"
        try photoWriter.write(photoData, filename: filename)

        let delta = prior.map { computeDelta(prior: $0.buildIdentitySnapshot, current: identity, priorSnapshot: snapshot) }
        let narrative: String
        if let prior, let delta {
            narrative = await evolutionNarrative(prior.buildIdentitySnapshot, identity, delta)
        } else {
            narrative = await firstNarrative(identity)
        }

        let checkpoint = ScanCheckpoint(
            id: scanId,
            userId: userId,
            createdAt: now,
            photoFilename: filename,
            buildIdentitySnapshot: identity,
            narrative: narrative,
            deltaFromPrior: delta
        )
        try store.save(checkpoint)

        // Pin the snapshot to this scan id so the attribute system's existing
        // history APIs see this checkpoint as a comparison anchor.
        await attribute.snapshotForScan(scanId: scanId, userId: userId)

        return checkpoint
    }

    /// Compute per-axis Δ between prior and current. We have the current
    /// AttributeProfile via `priorSnapshot`, but for the prior identity we
    /// only have BuildIdentity (primary/secondary/shape) — that's not enough
    /// to recover per-axis values. So this implementation reads per-axis
    /// values from the CURRENT AttributeService (which already retains
    /// pinned per-scan snapshots) and the prior pinned snapshot.
    private func computeDelta(
        prior: BuildIdentity,
        current: BuildIdentity,
        priorSnapshot: AttributeProfile
    ) -> BuildIdentityDelta {
        // Pull prior pinned profile from attribute system history.
        let history = attribute.scanHistory(userId: priorSnapshot.userId)
        guard history.count >= 2 else {
            return BuildIdentityDelta(perAxis: [:])
        }
        let priorPinned = history[history.count - 2]
        var perAxis: [AttributeKey: Int] = [:]
        for key in AttributeKey.allCases {
            let before = priorPinned.value(for: key).current
            let after = priorSnapshot.value(for: key).current
            perAxis[key] = after - before
        }
        return BuildIdentityDelta(perAxis: perAxis)
    }
}

/// Default writer — sends photo bytes through the existing image-capture
/// service. If that service exposes a different signature, adapt this
/// wrapper. Don't change the protocol.
final class DefaultScanPhotoWriter: ScanPhotoWriting {
    func write(_ data: Data, filename: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("scan-photos", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent(filename))
    }
}
```

- [ ] **Step 3: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/ScanCheckpointServiceTests`
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Services/Scan/ScanCheckpointService.swift UNBOUNDTests/Services/ScanCheckpointServiceTests.swift
git commit -m "feat(scan): add ScanCheckpointService orchestrator"
```

---

# Phase 4 — New view components

Six views. Each is a standalone presentational shell at this stage; wiring into the existing flow happens in Phase 5.

## Task 4.1: BuildHexHUD

**Files:**
- Create: `UNBOUND/Views/Components/BuildHexHUD.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Components/BuildHexHUD.swift
import SwiftUI

/// Compact hex used as an overlay on onboarding steps that participate in
/// hex tilt. Reuses AttributeHex; renders without axis labels for a tighter
/// footprint. Spring-animates when the values change.
struct BuildHexHUD: View {
    let values: [AttributeKey: Double]
    var radius: CGFloat = 48

    var body: some View {
        AttributeHex(
            current: values,
            peak: nil,
            showLabels: false,
            radius: radius
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: values)
        .padding(.all, 4)
        .background(
            Circle()
                .fill(Color.unbound.bg.opacity(0.85))
                .overlay(Circle().strokeBorder(Color.unbound.border, lineWidth: 1))
        )
    }
}

#Preview {
    BuildHexHUD(values: [
        .power: 53, .agility: 35, .control: 45,
        .endurance: 38, .mobility: 35, .explosiveness: 41
    ])
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Components/BuildHexHUD.swift
git commit -m "feat(scan): add BuildHexHUD overlay component"
```

---

## Task 4.2: ScanCadenceGate

**Files:**
- Create: `UNBOUND/Views/Scan/ScanCadenceGate.swift`
- Test: `UNBOUNDTests/Views/ScanCadenceGateTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Views/ScanCadenceGateTests.swift
import XCTest
@testable import UNBOUND

final class ScanCadenceGateTests: XCTestCase {
    func testNoPriorScanIsUnlocked() {
        let state = ScanCadenceState.compute(lastScanAt: nil, now: .now)
        XCTAssertTrue(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 0)
    }

    func testThirtyDaysExactlyIsUnlocked() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(30 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertTrue(state.isUnlocked)
    }

    func testTwentyNineDaysIsLocked() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(29 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 1)
    }

    func testTwentyThreeDayWindowAddsPulse() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(23 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 7)
        XCTAssertTrue(state.urgencyPulse)
    }

    func testEarlyDaysAreMuted() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        let now = last.addingTimeInterval(5 * 86400)
        let state = ScanCadenceState.compute(lastScanAt: last, now: now)
        XCTAssertFalse(state.isUnlocked)
        XCTAssertEqual(state.daysUntilNext, 25)
        XCTAssertFalse(state.urgencyPulse)
    }
}
```

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Views/Scan/ScanCadenceGate.swift
import SwiftUI

/// Pure value describing the home-tile + gate appearance at a given moment.
struct ScanCadenceState: Equatable {
    let isUnlocked: Bool
    let daysUntilNext: Int
    let urgencyPulse: Bool

    static func compute(lastScanAt: Date?, now: Date) -> ScanCadenceState {
        guard let last = lastScanAt else {
            return ScanCadenceState(isUnlocked: true, daysUntilNext: 0, urgencyPulse: false)
        }
        let elapsed = Int(now.timeIntervalSince(last) / 86400)
        if elapsed >= 30 {
            return ScanCadenceState(isUnlocked: true, daysUntilNext: 0, urgencyPulse: false)
        }
        let remaining = max(0, 30 - elapsed)
        let pulse = remaining <= 7
        return ScanCadenceState(isUnlocked: false, daysUntilNext: remaining, urgencyPulse: pulse)
    }
}

/// Soft-lock card shown when the user opens the scan from home before
/// the 30-day cadence has elapsed. Includes a tertiary "Scan anyway"
/// override so power users aren't blocked.
struct ScanCadenceGate: View {
    let state: ScanCadenceState
    let onProceed: () -> Void
    let onOverride: () -> Void

    var body: some View {
        if state.isUnlocked {
            // Defer rendering to the parent — the parent should bypass the gate.
            Color.clear.onAppear(perform: onProceed)
        } else {
            VStack(spacing: 24) {
                Spacer()
                Text("NEXT CHECKPOINT IN")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text("\(state.daysUntilNext) DAYS")
                    .font(Font.unbound.displayM)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .tracking(2)
                Text("Monthly cadence keeps the change visible.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button(action: onOverride) {
                    Text("Scan anyway")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .underline()
                }
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.unbound.bg.ignoresSafeArea())
        }
    }
}
```

- [ ] **Step 3: Verify**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/ScanCadenceGateTests`
Expected: 5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Scan/ScanCadenceGate.swift UNBOUNDTests/Views/ScanCadenceGateTests.swift
git commit -m "feat(scan): add ScanCadenceGate with soft-lock + override"
```

---

## Task 4.3: ScanWritingArcView

**Files:**
- Create: `UNBOUND/Views/Scan/ScanWritingArcView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Scan/ScanWritingArcView.swift
import SwiftUI

/// ~2.5s cinematic beat that replaces the old Gemini "analyzing" view.
/// Calls ScanCheckpointService.commit and holds until it resolves. Falls
/// through to onComplete with the resulting ScanCheckpoint.
struct ScanWritingArcView: View {
    let photoData: Data
    let userId: String
    let service: ScanCheckpointService
    let onComplete: (ScanCheckpoint) -> Void

    @State private var phase: Phase = .opening
    @State private var startedAt: Date?
    @State private var commitResult: ScanCheckpoint?
    @State private var commitFailed = false

    private enum Phase { case opening, locking, done }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            OnboardingAtmosphere(intensity: 1.2)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(phaseText)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .id(phase)
                    .transition(.opacity)
            }
        }
        .task {
            startedAt = .now
            // Drive the cinematic phases independent of network latency.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { withAnimation(.easeInOut(duration: 0.4)) { phase = .locking } }
            // Fire the commit; await its result.
            do {
                let cp = try await service.commit(userId: userId, photoData: photoData)
                commitResult = cp
            } catch {
                commitFailed = true
            }
            // Floor at 2.5s so the beat has weight.
            let elapsed = Date.now.timeIntervalSince(startedAt ?? .now)
            if elapsed < 2.5 {
                try? await Task.sleep(nanoseconds: UInt64((2.5 - elapsed) * 1_000_000_000))
            }
            if let cp = commitResult {
                onComplete(cp)
            } else if commitFailed {
                // Defensive: if commit truly failed, fall through with a
                // synthetic empty checkpoint — the payoff view will degrade
                // gracefully. In practice, ScanNarrativeService already
                // falls back to a deterministic template, so the only path
                // here is photo-write failure, which is rare.
                onComplete(ScanCheckpoint(
                    id: UUID().uuidString, userId: userId, createdAt: .now,
                    photoFilename: "", buildIdentitySnapshot: BuildIdentity(
                        primary: nil, secondary: nil, shape: .balancedAthlete
                    ),
                    narrative: "Your arc begins.", deltaFromPrior: nil
                ))
            }
        }
    }

    private var phaseText: String {
        switch phase {
        case .opening: return "WRITING YOUR ARC…"
        case .locking: return "LOCKING THE CHECKPOINT…"
        case .done:    return ""
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Scan/ScanWritingArcView.swift
git commit -m "feat(scan): add ScanWritingArcView cinematic beat"
```

---

## Task 4.4: FirstScanArcCard

**Files:**
- Create: `UNBOUND/Views/Scan/FirstScanArcCard.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Scan/FirstScanArcCard.swift
import SwiftUI

/// First-scan payoff. "Your arc begins" — photo + seeded hex + narrative +
/// 30-day cadence anchor. NO grading, NO strengths/weaknesses, NO focus
/// pills. See spec section "FirstScanArcCard."
struct FirstScanArcCard: View {
    let checkpoint: ScanCheckpoint
    let photoImage: UIImage?
    let buildAxisValues: [AttributeKey: Double]
    let onPrimary: () -> Void
    let onShare: () -> Void

    @State private var photoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var hexAppeared = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                heroPhoto
                titleBlock
                hexBlock
                narrativeBlock
                cadenceAnchor
                ctaBlock
            }
            .padding(.bottom, 32)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { photoOpacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.45)) { titleOpacity = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                hexAppeared = true
            }
        }
    }

    private var heroPhoto: some View {
        Group {
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.unbound.surface)
                    .frame(height: 360)
            }
        }
        .opacity(photoOpacity)
    }

    private var titleBlock: some View {
        Text("YOUR ARC BEGINS")
            .font(Font.unbound.displayM)
            .foregroundStyle(Color.unbound.textPrimary)
            .tracking(3)
            .animeGlow(color: Color.unbound.accent, radius: 14, intensity: 0.5)
            .opacity(titleOpacity)
    }

    private var hexBlock: some View {
        AttributeHex(
            current: buildAxisValues,
            peak: nil,
            showLabels: true,
            radius: 130
        )
        .scaleEffect(hexAppeared ? 1.0 : 0.85)
        .opacity(hexAppeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: hexAppeared)
    }

    private var narrativeBlock: some View {
        Text(checkpoint.narrative)
            .font(.system(size: 15))
            .foregroundStyle(Color.unbound.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .padding(.horizontal, 20)
    }

    private var cadenceAnchor: some View {
        Text("Come back in 30 days to see how your arc evolves.")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.unbound.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            UnboundButton(title: "BEGIN TRAINING", action: onPrimary)
                .padding(.horizontal, 20)
            Button(action: onShare) {
                Text("Share your start")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .underline()
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Scan/FirstScanArcCard.swift
git commit -m "feat(scan): add FirstScanArcCard payoff view"
```

---

## Task 4.5: NthScanEvolutionCard

**Files:**
- Create: `UNBOUND/Views/Scan/NthScanEvolutionCard.swift`

- [ ] **Step 1: Confirm ScanBuildDeltaCard signature**

```bash
grep -n "struct ScanBuildDeltaCard\|init(" UNBOUND/Views/Scan/ScanBuildDeltaCard.swift | head
```

Match its initializer in the new card.

- [ ] **Step 2: Implement**

```swift
// UNBOUND/Views/Scan/NthScanEvolutionCard.swift
import SwiftUI

/// Nth-scan payoff. Before/after photo split + ScanBuildDeltaCard +
/// Claude evolution narrative. Setbacks NEVER appear as negative numbers —
/// regressed axes become quiet "Focus area" pills via BuildIdentityDelta.
struct NthScanEvolutionCard: View {
    let priorCheckpoint: ScanCheckpoint
    let currentCheckpoint: ScanCheckpoint
    let priorImage: UIImage?
    let currentImage: UIImage?
    let priorAttributeProfile: AttributeProfile
    let currentAttributeProfile: AttributeProfile
    let onPrimary: () -> Void
    let onShare: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                photoSplit
                titleBlock
                ScanBuildDeltaCard(
                    firstScan: priorAttributeProfile,
                    latestScan: currentAttributeProfile
                )
                .padding(.horizontal, 20)
                focusAreaPills
                narrativeBlock
                cadenceAnchor
                ctaBlock
            }
            .padding(.bottom, 32)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
    }

    private var photoSplit: some View {
        VStack(spacing: 0) {
            photoRow(image: priorImage, label: "30 DAYS AGO")
            photoRow(image: currentImage, label: "TODAY")
        }
    }

    private func photoRow(image: UIImage?, label: String) -> some View {
        ZStack(alignment: .topLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Rectangle().fill(Color.unbound.surface).frame(height: 220)
            }
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.unbound.bg.opacity(0.7)))
                .padding(12)
        }
    }

    private var titleBlock: some View {
        Text("YOUR ARC EVOLVED")
            .font(Font.unbound.displayM)
            .foregroundStyle(Color.unbound.textPrimary)
            .tracking(3)
            .animeGlow(color: Color.unbound.accent, radius: 14, intensity: 0.5)
    }

    private var focusAreaPills: some View {
        let regressed = currentCheckpoint.deltaFromPrior?.regressedAxes ?? []
        return Group {
            if !regressed.isEmpty {
                HStack(spacing: 8) {
                    ForEach(regressed, id: \.self) { axis in
                        Text("Focus area · \(axis.buildVocab)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.unbound.surface))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var narrativeBlock: some View {
        Text(currentCheckpoint.narrative)
            .font(.system(size: 15))
            .foregroundStyle(Color.unbound.textSecondary)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.surface))
            .padding(.horizontal, 20)
    }

    private var cadenceAnchor: some View {
        Text("Next checkpoint in 30 days.")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.unbound.textTertiary)
    }

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            UnboundButton(title: "BACK TO TRAINING", action: onPrimary)
                .padding(.horizontal, 20)
            Button(action: onShare) {
                Text("Share evolution")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .underline()
            }
        }
    }
}
```

If `ScanBuildDeltaCard`'s initializer takes different parameters than `(firstScan:latestScan:)`, adjust the call site here — the card was shipped in sub-project #1 Phase 1d.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Scan/NthScanEvolutionCard.swift
git commit -m "feat(scan): add NthScanEvolutionCard payoff view"
```

---

## Task 4.6: Rewrite ScanPayoffView

**Files:**
- Modify: `UNBOUND/Views/Scan/ScanPayoffView.swift`

- [ ] **Step 1: Read current ScanPayoffView body**

```bash
cat UNBOUND/Views/Scan/ScanPayoffView.swift
```

This is the wholesale-replacement step. The old body (header / photoCard / narrativeCard / focusPill / retakeHint / `BodyAnalysis` reads) goes away.

- [ ] **Step 2: Replace the body**

```swift
// UNBOUND/Views/Scan/ScanPayoffView.swift
import SwiftUI
import UIKit

struct ScanPayoffView: View {
    let checkpoint: ScanCheckpoint
    let onDone: () -> Void
    let onShare: () -> Void

    @EnvironmentObject var services: ServiceContainer
    @State private var photoImage: UIImage?
    @State private var priorCheckpoint: ScanCheckpoint?
    @State private var priorImage: UIImage?
    @State private var currentProfile: AttributeProfile?
    @State private var priorProfile: AttributeProfile?

    var body: some View {
        Group {
            if let priorCheckpoint, let currentProfile, let priorProfile {
                NthScanEvolutionCard(
                    priorCheckpoint: priorCheckpoint,
                    currentCheckpoint: checkpoint,
                    priorImage: priorImage,
                    currentImage: photoImage,
                    priorAttributeProfile: priorProfile,
                    currentAttributeProfile: currentProfile,
                    onPrimary: onDone,
                    onShare: onShare
                )
            } else if let currentProfile {
                FirstScanArcCard(
                    checkpoint: checkpoint,
                    photoImage: photoImage,
                    buildAxisValues: currentProfile.hexValues,
                    onPrimary: onDone,
                    onShare: onShare
                )
            } else {
                Color.unbound.bg.ignoresSafeArea()
            }
        }
        .task { await loadAuxiliary() }
    }

    private func loadAuxiliary() async {
        photoImage = ScanPhotoLoader.load(filename: checkpoint.photoFilename)
        let userId = services.auth.currentUserId ?? checkpoint.userId
        currentProfile = services.attribute.snapshot(userId: userId, asOf: .now)
        if let prior = try? ScanCheckpointStore.shared.history(userId: userId)
            .dropLast() // exclude current
            .last
        {
            priorCheckpoint = prior
            priorImage = ScanPhotoLoader.load(filename: prior.photoFilename)
            let history = services.attribute.scanHistory(userId: userId)
            if history.count >= 2 {
                priorProfile = history[history.count - 2]
            }
        }
    }
}

/// Loads a scan photo from disk by filename. Lives at module scope so
/// FirstScan / NthScan / share-sheet code paths can share it.
enum ScanPhotoLoader {
    static func load(filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("scan-photos").appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

/// Convenience for converting AttributeProfile → [AttributeKey: Double]
/// used by AttributeHex / BuildHexHUD. Lives next to ScanPayoffView since
/// it's the primary consumer.
extension AttributeProfile {
    var hexValues: [AttributeKey: Double] {
        var dict: [AttributeKey: Double] = [:]
        for key in AttributeKey.allCases {
            dict[key] = Double(value(for: key).current)
        }
        return dict
    }
}
```

If `services.attribute` or `services.auth` don't exist with those exact names, adjust to match `ServiceContainer`'s real fields. Don't rename the container.

- [ ] **Step 3: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED. (Some call sites that constructed the old `ScanPayoffView(analysis:photos:onDone:)` will now break — those call sites get fixed in Phase 5.)

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Scan/ScanPayoffView.swift
git commit -m "feat(scan): rewrite ScanPayoffView body around ScanCheckpoint + new payoff cards"
```

If the build fails due to broken call sites, that's expected — DO NOT commit until the new file at least compiles in isolation. Pin the temporarily-broken call sites with one-line `#if false` blocks if needed; Phase 5 fixes them properly.

---

# Phase 5 — Rewire scan flow

The new types and views exist. Now wire them into the onboarding scan path.

## Task 5.1: Replace Step_ScanAnalyzing with ScanWritingArcView wrapper

**Files:**
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_ScanAnalyzing.swift`
- Modify: `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` (case `.scanAnalyzing`)

- [ ] **Step 1: Replace `Step_ScanAnalyzing` body**

Replace its current body with a thin wrapper around `ScanWritingArcView`:

```swift
// UNBOUND/Views/Onboarding/Steps/Step_ScanAnalyzing.swift
import SwiftUI

struct Step_ScanAnalyzing: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onComplete: () -> Void

    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        if let front = flow.capturedPhotos[.front], let jpeg = front.jpegData(compressionQuality: 0.9) {
            ScanWritingArcView(
                photoData: jpeg,
                userId: services.auth.currentUserId ?? "anonymous",
                service: ScanCheckpointService.shared,
                onComplete: { checkpoint in
                    flow.lastScanCheckpoint = checkpoint
                    onComplete()
                }
            )
        } else {
            // No photo — fall through to next step.
            Color.unbound.bg.ignoresSafeArea().onAppear(perform: onComplete)
        }
    }
}
```

- [ ] **Step 2: Add `lastScanCheckpoint` field to OnboardingFlowViewModel**

In `UNBOUND/ViewModels/OnboardingFlowViewModel.swift`, alongside the other captured fields:

```swift
/// The most recent ScanCheckpoint committed during onboarding. Populated by
/// Step_ScanAnalyzing's wrapper; consumed by the post-scan verdict slot
/// (now FirstScanArcCard via the rewritten Step_Verdict route).
var lastScanCheckpoint: ScanCheckpoint? = nil
```

- [ ] **Step 3: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step_ScanAnalyzing.swift UNBOUND/ViewModels/OnboardingFlowViewModel.swift
git commit -m "feat(scan): wire ScanWritingArcView into Step_ScanAnalyzing"
```

---

## Task 5.2: Replace Step_Verdict with FirstScanArcCard wrapper

**Files:**
- Modify: `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` (case `.verdict`)
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_Verdict.swift` (temporarily rewrite, deleted in Phase 9)

Strategy: keep the `.verdict` case alive in the router but swap its rendering. Phase 9 deletes the file entirely once nothing references it.

- [ ] **Step 1: Replace `Step_Verdict` body**

```swift
// UNBOUND/Views/Onboarding/Steps/Step_Verdict.swift
import SwiftUI

struct Step_Verdict: View {
    @Bindable var flow: OnboardingFlowViewModel
    let onContinue: () -> Void

    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        if let checkpoint = flow.lastScanCheckpoint {
            ScanPayoffView(
                checkpoint: checkpoint,
                onDone: onContinue,
                onShare: { /* feature-flagged; no-op for now */ }
            )
            .environmentObject(services)
        } else {
            // No checkpoint — pass through.
            Color.unbound.bg.ignoresSafeArea().onAppear(perform: onContinue)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step_Verdict.swift
git commit -m "feat(scan): swap Step_Verdict body to ScanPayoffView/FirstScanArcCard"
```

---

## Task 5.3: Drop side-angle capture in Step_ScanLive / Step_ScanReview

**Files:**
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_ScanLive.swift`
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_ScanReview.swift`

- [ ] **Step 1: Read both files and identify the side-angle branch**

```bash
grep -n "side\|\\.side\|sideAngle\|ScanAngle.side" UNBOUND/Views/Onboarding/Steps/Step_ScanLive.swift UNBOUND/Views/Onboarding/Steps/Step_ScanReview.swift
```

- [ ] **Step 2: Remove the side-angle branch from both files**

Strip every code path that handles `.side` capture. Keep `.front` flow intact. If any state machine references `.side`, either remove the state or short-circuit it to `.front`.

- [ ] **Step 3: Verify build + run any existing scan tests**

Run: `xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:UNBOUNDTests/ScanCadenceGateTests`
Plus a full build: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED, tests pass.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step_ScanLive.swift UNBOUND/Views/Onboarding/Steps/Step_ScanReview.swift
git commit -m "feat(scan): drop side-angle capture — front photo only"
```

---

# Phase 6 — Onboarding hex tilt overlay

Layer `BuildHexHUD` onto the four steps that participate in seeding, and route the answers through `BuildSeedingService` at the end of onboarding.

## Task 6.1: Live-tilt helper on OnboardingFlowViewModel

**Files:**
- Modify: `UNBOUND/ViewModels/OnboardingFlowViewModel.swift`

- [ ] **Step 1: Add a computed `currentBuildSeed`**

Right under `var seededAttributes: Set<AttributeKey> = []`:

```swift
/// Live BuildSeed computed from current onboarding answers. Re-evaluated
/// every time a relevant field changes; the BuildHexHUD on Step_BuildSeed /
/// Step_Goals / Step_ExerciseStyle / Step11_Experience reads this and
/// renders the in-progress tilt.
var currentBuildSeed: BuildSeed {
    BuildSeedingService.seed(
        experience: experience,
        exerciseStyles: exerciseStyles,
        goals: goals,
        seededAttributes: seededAttributes
    )
}

/// Per-axis values for the HUD: baseline (35) + currentBuildSeed.
var currentBuildHexValues: [AttributeKey: Double] {
    var dict: [AttributeKey: Double] = [:]
    for key in AttributeKey.allCases {
        let raw = 35 + currentBuildSeed.value(for: key)
        dict[key] = Double(max(0, min(100, raw)))
    }
    return dict
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/ViewModels/OnboardingFlowViewModel.swift
git commit -m "feat(onboarding): add live BuildSeed/hex values on flow VM"
```

---

## Task 6.2: Add BuildHexHUD to Step_BuildSeed

**Files:**
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_BuildSeed.swift`

- [ ] **Step 1: Insert the HUD above the chip list**

```swift
// Inside OnboardingScaffold's content closure, BEFORE the VStack of chips:
BuildHexHUD(values: flow.currentBuildHexValues, radius: 72)
    .frame(maxWidth: .infinity)
    .padding(.top, 6)
    .padding(.bottom, 14)
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step_BuildSeed.swift
git commit -m "feat(onboarding): add BuildHexHUD to Step_BuildSeed"
```

---

## Task 6.3: Add BuildHexHUD to Step_Goals / Step_ExerciseStyle / Step11_Experience

**Files:**
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_Goals.swift`
- Modify: `UNBOUND/Views/Onboarding/Steps/Step_ExerciseStyle.swift`
- Modify: `UNBOUND/Views/Onboarding/Steps/Step11_Experience.swift`

- [ ] **Step 1: Insert a smaller HUD pill near the top of each step**

In each file, at the top of the scaffold's content closure:

```swift
BuildHexHUD(values: flow.currentBuildHexValues, radius: 44)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(.trailing, 20)
    .padding(.top, 2)
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step_Goals.swift UNBOUND/Views/Onboarding/Steps/Step_ExerciseStyle.swift UNBOUND/Views/Onboarding/Steps/Step11_Experience.swift
git commit -m "feat(onboarding): add BuildHexHUD to Goals/ExerciseStyle/Experience steps"
```

---

## Task 6.4: Route onboarding answers through BuildSeedingService on finish

**Files:**
- Modify: `UNBOUND/ViewModels/OnboardingFlowViewModel.swift` (the `finish` method)

- [ ] **Step 1: Replace the current `applySeed` call**

Find:
```swift
AttributeService.shared.applySeed(seededAttributes, userId: userId)
```

Replace with:
```swift
let seed = BuildSeedingService.seed(
    experience: experience,
    exerciseStyles: exerciseStyles,
    goals: goals,
    seededAttributes: seededAttributes
)
AttributeService.shared.applyBuildSeed(seed, baseline: 35, userId: userId)
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/ViewModels/OnboardingFlowViewModel.swift
git commit -m "feat(onboarding): route finish through BuildSeedingService.applyBuildSeed"
```

---

# Phase 7 — Home cadence countdown

## Task 7.1: Update HomeScanTile (or equivalent) to read cadence state

**Files:**
- Locate: `UNBOUND/Views/Home/HomeScanTile.swift` (verify exact filename)
- Modify: that file

- [ ] **Step 1: Locate the scan tile**

```bash
grep -rln "scan\b.*tile\|HomeScan\|ScanTile" UNBOUND/Views/Home --include="*.swift"
```

The exact filename may differ — could be `HomeScanCard.swift`, `ScanTileView.swift`, etc. Use whichever file currently renders the scan entry on home.

- [ ] **Step 2: Update the tile to consume `ScanCadenceState`**

Inject `lastScanAt` (read from `ScanCheckpointStore.shared.mostRecent(userId:)?.createdAt`). Compute state via `ScanCadenceState.compute(lastScanAt:now:)`. Render three visual states:

```swift
// Pseudocode for the tile body — adapt to the existing tile structure.
let state = ScanCadenceState.compute(lastScanAt: lastScanAt, now: .now)

ZStack {
    RoundedRectangle(cornerRadius: 18)
        .fill(state.isUnlocked ? Color.unbound.accent.opacity(0.18) : Color.unbound.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    state.isUnlocked ? Color.unbound.accent : (state.urgencyPulse ? Color.unbound.accent.opacity(0.6) : Color.unbound.border),
                    lineWidth: 1
                )
        )
    VStack(alignment: .leading) {
        // ...existing title/subtitle...
        Text(state.isUnlocked
             ? "CHECKPOINT READY"
             : "NEXT CHECKPOINT · \(state.daysUntilNext) DAYS")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(state.isUnlocked ? Color.unbound.accent : Color.unbound.textTertiary)
    }
}
.scaleEffect(state.urgencyPulse ? 1.0 : 1.0) // No physical scale — pulse is on the border opacity above
```

- [ ] **Step 3: Wire the tap to push `ScanCadenceGate`**

When the tile is tapped: present `ScanCadenceGate(state: state, onProceed: { presentCaptureFlow() }, onOverride: { presentCaptureFlow() })`.

If the user is unlocked, `ScanCadenceGate` immediately proceeds via its `Color.clear.onAppear` shortcut.

- [ ] **Step 4: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Views/Home/HomeScanTile.swift  # or whichever file you modified
git commit -m "feat(scan): home scan tile reflects 30-day cadence countdown"
```

---

# Phase 8 — Trajectory retarget (or punt)

`Step28_Trajectory` currently leans on photo-derived projection. Retarget it to use the attribute system + target frequency. If complexity balloons, flag-disable and defer.

## Task 8.1: Read existing trajectory step

**Files:**
- Read: `UNBOUND/Views/Onboarding/Steps/Step28_Trajectory.swift`

- [ ] **Step 1: Read and assess**

```bash
cat UNBOUND/Views/Onboarding/Steps/Step28_Trajectory.swift
```

If the file is <150 lines and its inputs are simple (one chart, one projected vector), retarget. If it's a multi-component visualization deeply coupled to `BodyAnalysis`, **punt to a future sub-project** — wrap the step's body in a feature flag and pass through:

```swift
// At top of Step28_Trajectory body:
if !FeatureFlags.shared.trajectoryEnabled {
    Color.unbound.bg.ignoresSafeArea().onAppear(perform: onContinue)
    return AnyView(EmptyView())
}
```

Decision is the implementer's call based on what they read. Document the choice in the commit message.

## Task 8.2: Retarget OR punt

Pick one path based on Task 8.1's assessment:

**Path A — Retarget (preferred if cheap):**

Replace `BodyAnalysis`-derived projection inputs with:
- Current per-axis values from `AttributeService.shared.snapshot(userId:asOf:).hexValues`
- Target frequency from `flow.targetFrequency`
- 90-day projection per axis: `current + (frequency.weeklyMultiplier * 12)`, clamped to 100. Use a stub multiplier of 1.5/week if no contribution data is wired yet.

**Path B — Punt:**

Add `FeatureFlags.shared.trajectoryEnabled = false` and pass-through behavior. Commit message must clearly note "deferred".

- [ ] **Step 1: Apply chosen path**

- [ ] **Step 2: Verify build**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step28_Trajectory.swift  # plus any feature-flag file
git commit -m "feat(scan): retarget trajectory step to attribute-system projection"
# OR
git commit -m "feat(scan): defer trajectory step behind feature flag pending later sub-project"
```

---

# Phase 9 — Demolition

Delete the Gemini grader and its model. This phase only runs after Phases 1–8 are committed and the build is clean.

## Task 9.1: Pre-delete colocated-types audit

**Files:**
- Audit: `UNBOUND/Models/BodyAnalysis.swift`
- Audit: `UNBOUND/Services/BodyAnalysis/*.swift`

- [ ] **Step 1: Grep for unrelated types**

```bash
for f in UNBOUND/Models/BodyAnalysis.swift UNBOUND/Services/BodyAnalysis/*.swift; do
  echo "=== $f ==="
  grep -nE "^enum |^struct |^class |^protocol |^extension " "$f"
done
```

- [ ] **Step 2: For each load-bearing type found in a doomed file**

If `BodyAnalysis.swift` (or any service file in `Services/BodyAnalysis/`) contains a type that's used outside the body-analysis path, extract that type to its own file. Common candidates: `BodyScanInsights`, `MuscleAssessment`, `ScanFocusArea`, anything else co-located.

For each extracted type:

```bash
git mv -k existing path/to/ExtractedType.swift  # if a clean home exists
# or hand-create the new file with just that type
```

Commit each extraction as its own small commit before deleting anything:

```bash
git commit -m "refactor(scan): extract <TypeName> from BodyAnalysis.swift pre-deletion"
```

## Task 9.2: Find and replace remaining `BodyAnalysis` references

**Files:**
- All UNBOUND/ source files

- [ ] **Step 1: Find every reference**

```bash
grep -rn "BodyAnalysis\|bodyAnalysis\|LocalBodyInsightsService\|scanInsights" UNBOUND --include="*.swift" | grep -v "// removed\|^//"
```

- [ ] **Step 2: For each reference, replace with the new pipeline equivalent**

Common mappings:
- `BodyAnalysis` model → `ScanCheckpoint`
- `BodyAnalysisService` → `ScanCheckpointService`
- `BodyAnalysisServiceProtocol` → (delete consumer; not replaced)
- `scanInsights` field reads → delete the call site or replace with `lastScanCheckpoint`

For ServiceContainer wiring, if `services.bodyAnalysis` exists, remove the property. Replace its initialization in `ServiceContainer.init` if present.

- [ ] **Step 3: Verify build before deletion**

Run: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(scan): replace all BodyAnalysis call sites with ScanCheckpoint pipeline"
```

## Task 9.3: Delete the files

**Files:**
- Delete: `UNBOUND/Models/BodyAnalysis.swift`
- Delete: `UNBOUND/Services/BodyAnalysis/BodyAnalysisService.swift`
- Delete: `UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift`
- Delete: `UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift`
- Delete: `UNBOUND/Services/BodyAnalysis/MockBodyAnalysisService.swift`
- Delete: `UNBOUND/Services/BodyAnalysis/LocalBodyInsightsService.swift` (if unused after extraction)
- Delete: `UNBOUND/Views/Onboarding/Steps/Step_Verdict.swift` (now that its body is the FirstScanArcCard wrapper, the wrapper is small enough to inline into the router — see Step 4)

- [ ] **Step 1: Delete the body-analysis files**

```bash
cd UNBOUND
git rm UNBOUND/Models/BodyAnalysis.swift
git rm UNBOUND/Services/BodyAnalysis/BodyAnalysisService.swift
git rm UNBOUND/Services/BodyAnalysis/BodyAnalysisServiceProtocol.swift
git rm UNBOUND/Services/BodyAnalysis/BodyAnalysisPrompt.swift
git rm UNBOUND/Services/BodyAnalysis/MockBodyAnalysisService.swift
git rm UNBOUND/Services/BodyAnalysis/LocalBodyInsightsService.swift  # only if unused
```

- [ ] **Step 2: Inline Step_Verdict into the router and delete the file**

In `OnboardingContainerView.swift`, replace:

```swift
case .verdict:
    Step_Verdict(flow: flow, onContinue: advance)
        .transition(.opacity)
```

with:

```swift
case .verdict:
    Group {
        if let checkpoint = flow.lastScanCheckpoint {
            ScanPayoffView(checkpoint: checkpoint, onDone: advance, onShare: {})
        } else {
            Color.unbound.bg.ignoresSafeArea().onAppear(perform: advance)
        }
    }
    .transition(.opacity)
```

Then:
```bash
git rm UNBOUND/Views/Onboarding/Steps/Step_Verdict.swift
```

- [ ] **Step 3: Delete any body-analysis tests**

```bash
git rm -r UNBOUNDTests/Services/BodyAnalysis* 2>/dev/null || true
git rm UNBOUNDTests/**/*BodyAnalysis* 2>/dev/null || true
```

- [ ] **Step 4: Verify full build + full test suite**

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: BUILD SUCCEEDED, ALL TESTS PASSED.

- [ ] **Step 5: Regenerate xcodeproj if you use xcodegen**

```bash
xcodegen generate
```

Expected: project regenerates without errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(scan): delete BodyAnalysisService + Step_Verdict — Gemini grading path removed"
```

---

# Phase 10 — Final pass

## Task 10.1: End-to-end smoke test

- [ ] **Step 1: Run on simulator**

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16' build
open -a Simulator
xcrun simctl install booted /path/to/build.app  # or hit Run in Xcode
```

Walk the onboarding from start. Verify:
1. `BuildHexHUD` tilts in real time on `Step_BuildSeed`, `Step_Goals`, `Step_ExerciseStyle`, `Step11_Experience`.
2. Scan capture takes ONE photo (front only).
3. `ScanWritingArcView` shows ~2.5s beat with copy fading from "WRITING YOUR ARC…" to "LOCKING THE CHECKPOINT…".
4. `FirstScanArcCard` displays: photo, "YOUR ARC BEGINS" title, hex with seeded values, narrative card, 30-day cadence anchor, "BEGIN TRAINING" CTA.
5. No "Strengths/Weaknesses", "Body Fat", "AI analysis", or numeric match% appear anywhere.

## Task 10.2: Dev-skip simulation of Nth scan

- [ ] **Step 1: Use the existing #DEBUG dev-skip button**

Tap dev-skip past onboarding. From home, manipulate `lastScanAt` to >30 days ago (e.g. by deleting the scan-checkpoints directory or via a debug action). Tap the scan tile.

- [ ] **Step 2: Walk the Nth-scan path**

After capturing a second photo (in DEBUG, you can backdate the first checkpoint by hand), confirm `NthScanEvolutionCard` renders with:
- before/after split
- `ScanBuildDeltaCard`
- positive-only deltas; if you forced a regression in dev, only "Focus area · …" pills appear

## Task 10.3: Cleanup pass

- [ ] **Step 1: Search for dead code**

```bash
grep -rn "TODO\|FIXME" UNBOUND/Services/Scan UNBOUND/Views/Scan UNBOUND/Models/ScanCheckpoint.swift UNBOUND/Models/BuildSeed.swift UNBOUND/Models/BuildIdentityDelta.swift UNBOUND/Services/Onboarding/BuildSeedingService.swift
```

If any remain, resolve them before final commit.

- [ ] **Step 2: Final test run**

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: all tests pass.

- [ ] **Step 3: Final commit (if cleanup happened)**

```bash
git add -A
git commit -m "chore(scan): final cleanup post-implementation"
```

---

## Self-Review Notes

**Spec coverage check** (matched against the spec sections):
- ✅ Product directive (governing principles) → enforced via Standing Rules + service docstrings
- ✅ Architecture → New types/services/views → Phase 1, 2, 3, 4
- ✅ BuildSeed model → Task 1.1
- ✅ BuildIdentityDelta → Task 1.2 (positive-only filter explicit)
- ✅ BuildSeedingService → Task 1.4 (caps, multiplier, global cap all tested)
- ✅ ScanNarrativeService (Haiku) + fallback → Task 2.1
- ✅ ScanCheckpoint model → Task 3.1
- ✅ ScanCheckpointStore → Task 3.2
- ✅ ScanCheckpointService orchestrator → Task 3.3
- ✅ BuildHexHUD → Task 4.1
- ✅ ScanCadenceGate → Task 4.2 (5 boundary tests)
- ✅ ScanWritingArcView → Task 4.3
- ✅ FirstScanArcCard → Task 4.4
- ✅ NthScanEvolutionCard with setback filter → Task 4.5
- ✅ ScanPayoffView rewrite → Task 4.6
- ✅ Onboarding hex tilt layer on 4 specified steps → Tasks 6.2, 6.3
- ✅ Route through BuildSeedingService.applyBuildSeed → Task 6.4
- ✅ Drop side-angle capture → Task 5.3
- ✅ Replace Step_ScanAnalyzing with ScanWritingArcView → Task 5.1
- ✅ Replace Step_Verdict body → Task 5.2 (later inlined in Phase 9)
- ✅ Home cadence countdown → Task 7.1
- ✅ Trajectory retarget OR punt → Task 8.1–8.2 (explicit escape hatch)
- ✅ Delete BodyAnalysisService + Step_Verdict → Task 9.3

**Placeholder scan:** No "TBD", "fill in details", or hand-wavy steps. The two soft spots (Task 1.4 enum case names, Task 7.1 tile filename) have explicit verification commands and instructions to adapt.

**Type consistency:** `BuildSeed`, `BuildIdentityDelta`, `ScanCheckpoint`, `ScanCheckpointService.commit(userId:photoData:now:)`, `BuildSeedingService.seed(experience:exerciseStyles:goals:seededAttributes:)`, `AttributeService.applyBuildSeed(_:baseline:userId:)`, `ScanCadenceState.compute(lastScanAt:now:)` — names are stable across all tasks.

**Known soft spots** (flagged for the implementer):
1. Existing enum case names (`ExerciseStyle`, `Goal`, `Experience`) need verification in Task 1.4 Step 2.
2. `BuildIdentity: Codable` conformance presence — verify in Task 3.1 Step 3.
3. Trajectory step complexity is unknown — Task 8.1 includes an explicit "punt" path.
4. Home scan tile filename — Task 7.1 starts with a grep.

These are unavoidable for a plan that touches existing code; the verification commands make them resolvable in-task.
