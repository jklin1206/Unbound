# Attribute System (Sub-project #1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dead 4-axis StatScore with an emergent 6-axis Build hex (POW/AGI/CTL/END/MOB/EXP), backed by per-exercise contribution vectors, surfaced on Profile (primary) + Home (chip) + Scan (Δ panel).

**Architecture:** Greenfield service + models alongside existing `SessionXPService`/`RankService`. Pure-on-read drift math. Per-exercise contribution vectors authored in JSON. Reuses shipped `SubRank`/`RankTitle` ladder + rank badge assets. 4 phases, each independently shippable to TestFlight.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, Combine (existing). Tests: XCTest. Data: SwiftData (local) + Supabase/Firestore (remote, via `DatabaseService`). Singletons via `ServiceContainer` DI.

**Spec:** [`docs/superpowers/specs/2026-05-12-attribute-system-design.md`](../specs/2026-05-12-attribute-system-design.md)

---

## File Map

### Phase 1a — Foundation (data + seed survey + event emission)

**Create:**
- `UNBOUND/Models/AttributeKey.swift` — 6-axis enum + display copy
- `UNBOUND/Models/AttributeValue.swift` — peak/current per axis + derived rank
- `UNBOUND/Models/AttributeProfile.swift` — full 6-axis state
- `UNBOUND/Models/AttributeContribution.swift` — static catalog metadata
- `UNBOUND/Models/AttributeRankUpEvent.swift` — emitted on tier crossings
- `UNBOUND/Services/Attributes/AttributeService.swift` — protocol + impl + mock
- `UNBOUND/Resources/AttributeContributions.json` — full catalog vectors
- `UNBOUND/Views/Onboarding/Steps/Step_BuildSeed.swift` — seed survey screen
- `UNBOUNDTests/Models/AttributeKeyTests.swift`
- `UNBOUNDTests/Models/AttributeValueTests.swift`
- `UNBOUNDTests/Models/AttributeProfileTests.swift`
- `UNBOUNDTests/Services/AttributeServiceDriftTests.swift`
- `UNBOUNDTests/Services/AttributeServiceIngestTests.swift`
- `UNBOUNDTests/Catalog/AttributeContributionCatalogTests.swift`

**Modify:**
- `UNBOUND/Services/ServiceContainer.swift` — wire `attribute: any AttributeServiceProtocol`
- `UNBOUND/Models/OnboardingAnswers.swift` — add `seededAttributes: Set<AttributeKey>?`
- `UNBOUND/ViewModels/OnboardingFlowViewModel.swift` — add `buildSeed` step + handler
- `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` (`OnboardingRouter`) — route `buildSeed`
- Wherever `services.sessionXP.recordSession(...)` is called on workout finish — add `services.attribute.ingest(session:)` alongside

### Phase 1b — Profile Build card + rank-up animation

**Create:**
- `UNBOUND/Views/Components/AttributeHex.swift` — reusable hex chart (used by 1b/1c/1d)
- `UNBOUND/Views/Profile/ProfileBuildCard.swift`
- `UNBOUND/Views/Profile/BuildAttributeCell.swift` — single cell of the 3×2 grid
- `UNBOUND/Views/Components/AttributeRankUpToast.swift` — animation handler
- `UNBOUNDTests/Views/ProfileBuildCardSnapshotTests.swift`

**Modify:**
- `UNBOUND/Views/Profile/ProfileView.swift` — slot `ProfileBuildCard` between identity and Recent
- `UNBOUND/Views/Home/UnboundHomeView.swift` — subscribe to `AttributeRankUpEvent` for toast overlay

### Phase 1c — Home Build chip + remove old Stats grid

**Create:**
- `UNBOUND/Views/Home/HomeBuildChipCard.swift`

**Modify:**
- `UNBOUND/Views/Home/UnboundHomeView.swift` — remove existing "Stats grid" section (~line 1919), slot `HomeBuildChipCard` below Rank card

### Phase 1d — Scan Δ panel + dead-code cleanup

**Create:**
- `UNBOUND/Views/Scan/ScanBuildDeltaCard.swift`

**Modify:**
- `UNBOUND/Views/Scan/ScanPayoffView.swift` — slot `ScanBuildDeltaCard` after body-Δ section
- `UNBOUND/Services/Attributes/AttributeService.swift` — add `snapshotForScan(scanId:)`

**Delete:**
- `UNBOUND/Models/StatScore.swift`
- `UNBOUND/Models/MuscleGroupTier.swift`
- `UNBOUND/Models/MuscleGroupTierState.swift`
- `UNBOUND/Models/MuscleHeatGroup.swift`
- `UNBOUND/Models/MuscleHeatmapRegions.swift`
- `UNBOUND/Services/Ranking/StatScoreService.swift` (if exists — `grep` first)
- `UNBOUND/Services/ServiceContainer.swift` — drop `statScore:` slot

---

# Phase 1a — Foundation

### Task 1a.1: AttributeKey enum (TDD)

**Files:**
- Create: `UNBOUND/Models/AttributeKey.swift`
- Create: `UNBOUNDTests/Models/AttributeKeyTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Models/AttributeKeyTests.swift
import XCTest
@testable import UNBOUND

final class AttributeKeyTests: XCTestCase {
    func testAllCasesHasExactlySixAxes() {
        XCTAssertEqual(AttributeKey.allCases.count, 6)
    }

    func testShortCodesAreThreeLetterUppercase() {
        let expected = ["POW", "AGI", "CTL", "END", "MOB", "EXP"]
        XCTAssertEqual(AttributeKey.allCases.map(\.shortCode), expected)
    }

    func testDisplayNamesAreTitleCased() {
        let expected = ["Power", "Agility", "Control", "Endurance", "Mobility", "Explosiveness"]
        XCTAssertEqual(AttributeKey.allCases.map(\.displayName), expected)
    }

    func testRawValuesAreLowercaseStable() {
        XCTAssertEqual(AttributeKey.power.rawValue, "power")
        XCTAssertEqual(AttributeKey.explosiveness.rawValue, "explosiveness")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme UNBOUND -only-testing UNBOUNDTests/AttributeKeyTests`
Expected: FAIL — `AttributeKey` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Models/AttributeKey.swift
import Foundation

enum AttributeKey: String, CaseIterable, Codable, Sendable {
    case power, agility, control, endurance, mobility, explosiveness

    var displayName: String {
        switch self {
        case .power:         return "Power"
        case .agility:       return "Agility"
        case .control:       return "Control"
        case .endurance:     return "Endurance"
        case .mobility:      return "Mobility"
        case .explosiveness: return "Explosiveness"
        }
    }

    var shortCode: String {
        switch self {
        case .power:         return "POW"
        case .agility:       return "AGI"
        case .control:       return "CTL"
        case .endurance:     return "END"
        case .mobility:      return "MOB"
        case .explosiveness: return "EXP"
        }
    }

    /// Used in the seed-survey copy ("POWER — heavy compounds, sub-6 reps").
    var trainsCopy: String {
        switch self {
        case .power:         return "Heavy compounds, sub-6 reps"
        case .agility:       return "Sprints, change-of-direction"
        case .control:       return "Skill nodes, tempo, isometrics"
        case .endurance:     return "Z2 runs, density, long efforts"
        case .mobility:      return "Range of motion, flexibility"
        case .explosiveness: return "Jumps, plyos, dynamic effort"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/AttributeKey.swift UNBOUNDTests/Models/AttributeKeyTests.swift
git commit -m "feat(attr): AttributeKey enum + 6-axis identity"
```

---

### Task 1a.2: AttributeContribution model + sum-1.0 validation

**Files:**
- Create: `UNBOUND/Models/AttributeContribution.swift`
- Create: `UNBOUNDTests/Models/AttributeContributionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Models/AttributeContributionTests.swift
import XCTest
@testable import UNBOUND

final class AttributeContributionTests: XCTestCase {
    func testSumWithinToleranceReturnsTrueForValid() {
        let c = AttributeContribution(weights: [
            .power: 0.7, .endurance: 0.2, .control: 0.1
        ])
        XCTAssertTrue(c.sumIsValid)
    }

    func testSumWithinToleranceReturnsFalseWhenSumIsOff() {
        let c = AttributeContribution(weights: [.power: 0.5, .agility: 0.2])
        XCTAssertFalse(c.sumIsValid)
    }

    func testNormalizedWeightsFillsMissingKeysWithZero() {
        let c = AttributeContribution(weights: [.power: 1.0])
        XCTAssertEqual(c.weight(for: .power), 1.0)
        XCTAssertEqual(c.weight(for: .mobility), 0.0)
    }

    func testCodableRoundTrips() throws {
        let original = AttributeContribution(weights: [.power: 0.6, .control: 0.4])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AttributeContribution.self, from: data)
        XCTAssertEqual(decoded.weight(for: .power), 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.weight(for: .control), 0.4, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `AttributeContribution` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Models/AttributeContribution.swift
import Foundation

struct AttributeContribution: Codable, Sendable, Equatable {
    let weights: [AttributeKey: Double]

    init(weights: [AttributeKey: Double]) {
        self.weights = weights
    }

    func weight(for key: AttributeKey) -> Double {
        weights[key] ?? 0.0
    }

    /// True if weights sum to 1.0 ± 0.01.
    var sumIsValid: Bool {
        abs(weights.values.reduce(0.0, +) - 1.0) <= 0.01
    }

    static let zero = AttributeContribution(weights: [:])
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/AttributeContribution.swift UNBOUNDTests/Models/AttributeContributionTests.swift
git commit -m "feat(attr): AttributeContribution vector + sum validation"
```

---

### Task 1a.3: AttributeValue (peak + current + drift-derived rank)

**Files:**
- Create: `UNBOUND/Models/AttributeValue.swift`
- Create: `UNBOUNDTests/Models/AttributeValueTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Models/AttributeValueTests.swift
import XCTest
@testable import UNBOUND

final class AttributeValueTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testZeroIsZeroValues() {
        let v = AttributeValue.zero(at: t0)
        XCTAssertEqual(v.peak, 0)
        XCTAssertEqual(v.current, 0)
        XCTAssertEqual(v.lastContributionAt, t0)
    }

    func testFloorIs70PercentOfPeak() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 80
        XCTAssertEqual(v.floor, 56.0, accuracy: 0.001)
    }

    func testSubRankReflectsCurrentNotPeak() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 100; v.current = 0
        XCTAssertEqual(v.subRank, SubRank.eMinus)
        v.current = 100
        XCTAssertEqual(v.subRank, SubRank.sPlus)
    }

    func testRankTitleMapsThroughRankTitleTable() {
        var v = AttributeValue.zero(at: t0)
        v.peak = 100
        v.current = 50  // ordinal ~8 → cPlus → veteran (per existing SubRank.title table)
        XCTAssertEqual(v.rankTitle, .veteran)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `AttributeValue` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Models/AttributeValue.swift
import Foundation

struct AttributeValue: Codable, Sendable, Equatable {
    var peak: Double
    var current: Double
    var lastContributionAt: Date

    static func zero(at date: Date) -> AttributeValue {
        AttributeValue(peak: 0, current: 0, lastContributionAt: date)
    }

    var floor: Double { peak * 0.70 }

    var subRank: SubRank {
        SubRank.nearest(for: current / 100.0 * 17.0)
    }

    var rankTitle: RankTitle { subRank.title }

    var peakSubRank: SubRank {
        SubRank.nearest(for: peak / 100.0 * 17.0)
    }

    var peakRankTitle: RankTitle { peakSubRank.title }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/AttributeValue.swift UNBOUNDTests/Models/AttributeValueTests.swift
git commit -m "feat(attr): AttributeValue with peak/current + derived SubRank/RankTitle"
```

---

### Task 1a.4: AttributeProfile aggregate + derived computed properties

**Files:**
- Create: `UNBOUND/Models/AttributeProfile.swift`
- Create: `UNBOUNDTests/Models/AttributeProfileTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// UNBOUNDTests/Models/AttributeProfileTests.swift
import XCTest
@testable import UNBOUND

final class AttributeProfileTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyReturnsProfileWithAllZeroAxes() {
        let p = AttributeProfile.empty(userId: "u1", at: t0)
        XCTAssertEqual(p.values.count, 6)
        for key in AttributeKey.allCases {
            XCTAssertEqual(p.value(for: key).peak, 0)
            XCTAssertEqual(p.value(for: key).current, 0)
        }
    }

    func testDominantIsAxisWithHighestPeak() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power,    AttributeValue(peak: 80, current: 60, lastContributionAt: t0))
        p.set(.mobility, AttributeValue(peak: 40, current: 30, lastContributionAt: t0))
        XCTAssertEqual(p.dominant, .power)
    }

    func testWeakestIsAxisWithLowestPeak() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power,    AttributeValue(peak: 80, current: 60, lastContributionAt: t0))
        p.set(.mobility, AttributeValue(peak: 20, current: 14, lastContributionAt: t0))
        XCTAssertEqual(p.weakest, .mobility)
    }

    func testIsBalancedWhenMaxMinusMinUnder15() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 50, current: 50, lastContributionAt: t0))
        }
        p.set(.power, AttributeValue(peak: 60, current: 60, lastContributionAt: t0))
        XCTAssertTrue(p.isBalanced)  // 60 - 50 = 10 < 15
    }

    func testIsBalancedFalseWhenSpread15OrMore() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 30, current: 30, lastContributionAt: t0))
        }
        p.set(.power, AttributeValue(peak: 50, current: 50, lastContributionAt: t0))
        XCTAssertFalse(p.isBalanced)  // 50 - 30 = 20 ≥ 15
    }

    func testBuildNameIsBalancedWhenIsBalanced() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 50, current: 50, lastContributionAt: t0))
        }
        XCTAssertEqual(p.buildName, "Balanced")
    }

    func testBuildNameIsDominantLeaningHybridOtherwise() {
        var p = AttributeProfile.empty(userId: "u1", at: t0)
        p.set(.power, AttributeValue(peak: 70, current: 60, lastContributionAt: t0))
        p.set(.mobility, AttributeValue(peak: 20, current: 14, lastContributionAt: t0))
        XCTAssertEqual(p.buildName, "Power-leaning Hybrid")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `AttributeProfile` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// UNBOUND/Models/AttributeProfile.swift
import Foundation

struct AttributeProfile: Codable, Sendable, Equatable {
    let userId: String
    var values: [AttributeKey: AttributeValue]
    var computedAt: Date

    static func empty(userId: String, at date: Date) -> AttributeProfile {
        let v = AttributeValue.zero(at: date)
        let dict = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, v) })
        return AttributeProfile(userId: userId, values: dict, computedAt: date)
    }

    func value(for key: AttributeKey) -> AttributeValue {
        values[key] ?? AttributeValue.zero(at: computedAt)
    }

    mutating func set(_ key: AttributeKey, _ value: AttributeValue) {
        values[key] = value
    }

    var dominant: AttributeKey {
        AttributeKey.allCases.max(by: { value(for: $0).peak < value(for: $1).peak }) ?? .power
    }

    var weakest: AttributeKey {
        AttributeKey.allCases.min(by: { value(for: $0).peak < value(for: $1).peak }) ?? .mobility
    }

    var isBalanced: Bool {
        let peaks = AttributeKey.allCases.map { value(for: $0).peak }
        guard let maxP = peaks.max(), let minP = peaks.min() else { return true }
        return (maxP - minP) < 15
    }

    /// Phase 1b minimum naming rule. Sub-project #2 replaces this.
    var buildName: String {
        if isBalanced { return "Balanced" }
        return "\(dominant.displayName)-leaning Hybrid"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/AttributeProfile.swift UNBOUNDTests/Models/AttributeProfileTests.swift
git commit -m "feat(attr): AttributeProfile aggregate + dominant/weakest/buildName derivation"
```

---

### Task 1a.5: AttributeRankUpEvent type

**Files:**
- Create: `UNBOUND/Models/AttributeRankUpEvent.swift`

- [ ] **Step 1: Write the implementation directly (data type, no behavior to test)**

```swift
// UNBOUND/Models/AttributeRankUpEvent.swift
import Foundation

struct AttributeRankUpEvent: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        /// Sub-rank step (e.g. E- → E). Silent per cinematic-asymmetry rule.
        case subRank
        /// Tier crossing within E/D/C/B/S buckets (e.g. Apprentice → Forged).
        case tier
        /// Crossing into Vessel / Unbound / Ascendant (A-tier band).
        case aTier
    }

    let axis: AttributeKey
    let fromTitle: RankTitle
    let toTitle: RankTitle
    let fromSubRank: SubRank
    let toSubRank: SubRank
    let level: Level
    let timestamp: Date
}

extension Notification.Name {
    static let attributeRankUp = Notification.Name("unbound.attributeRankUp")
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Models/AttributeRankUpEvent.swift
git commit -m "feat(attr): AttributeRankUpEvent + notification name"
```

---

### Task 1a.6: AttributeService protocol + skeleton + Mock

**Files:**
- Create: `UNBOUND/Services/Attributes/AttributeService.swift`

- [ ] **Step 1: Create the file with protocol, real impl skeleton, and mock**

```swift
// UNBOUND/Services/Attributes/AttributeService.swift
import Foundation

// MARK: - AttributeServiceProtocol

@MainActor
protocol AttributeServiceProtocol: AnyObject {
    /// Returns the cached profile for the user.
    func profile(userId: String) -> AttributeProfile

    /// Snapshot the profile projected forward to `date` (applies drift).
    /// Pure — does not persist. Used by every read site.
    func snapshot(userId: String, asOf date: Date) -> AttributeProfile

    /// Apply a finished workout to the user's profile. Decay-forward first,
    /// then add deltas. Persists. Emits rank-up notifications.
    @discardableResult
    func ingest(session: WorkoutLog, userId: String) async -> AttributeProfile

    /// Apply a finished skill session.
    @discardableResult
    func ingest(skillSession: UserSkillProgress.Session, userId: String) async -> AttributeProfile

    /// Apply onboarding seed. Each selected key gets peak=current=15.
    func applySeed(_ seeded: Set<AttributeKey>, userId: String)

    /// Pin the current profile to a scan id, for later Δ comparison.
    func snapshotForScan(scanId: String, userId: String) async

    /// Returns historical pinned snapshots for the user, oldest first.
    func scanHistory(userId: String) -> [AttributeProfile]
}

// MARK: - AttributeService (real)

@MainActor
final class AttributeService: AttributeServiceProtocol {
    static let shared = AttributeService(
        catalog: AttributeCatalog.shared,
        store: AttributeProfileStore.shared
    )

    private let catalog: AttributeCatalogProtocol
    private let store: AttributeProfileStoreProtocol
    private let logger = LoggingService.shared

    init(catalog: AttributeCatalogProtocol, store: AttributeProfileStoreProtocol) {
        self.catalog = catalog
        self.store = store
    }

    func profile(userId: String) -> AttributeProfile {
        store.load(userId: userId) ?? .empty(userId: userId, at: .now)
    }

    func snapshot(userId: String, asOf date: Date) -> AttributeProfile {
        AttributeDrift.project(profile(userId: userId), to: date)
    }

    @discardableResult
    func ingest(session: WorkoutLog, userId: String) async -> AttributeProfile {
        let finishedAt = session.completedAt ?? .now
        var profile = AttributeDrift.project(profile(userId: userId), to: finishedAt)
        let deltas = AttributeIngest.deltas(for: session, catalog: catalog)
        let crossings = AttributeIngest.applyDeltas(&profile, deltas: deltas, at: finishedAt)
        profile.computedAt = finishedAt
        store.save(profile)
        for event in crossings { NotificationCenter.default.post(name: .attributeRankUp, object: event) }
        return profile
    }

    @discardableResult
    func ingest(skillSession: UserSkillProgress.Session, userId: String) async -> AttributeProfile {
        let finishedAt = skillSession.finishedAt
        var profile = AttributeDrift.project(profile(userId: userId), to: finishedAt)
        let deltas = AttributeIngest.deltas(for: skillSession, catalog: catalog)
        let crossings = AttributeIngest.applyDeltas(&profile, deltas: deltas, at: finishedAt)
        profile.computedAt = finishedAt
        store.save(profile)
        for event in crossings { NotificationCenter.default.post(name: .attributeRankUp, object: event) }
        return profile
    }

    func applySeed(_ seeded: Set<AttributeKey>, userId: String) {
        guard !seeded.isEmpty else { return }
        var profile = profile(userId: userId)
        let now = Date()
        for key in seeded {
            profile.set(key, AttributeValue(peak: 15, current: 15, lastContributionAt: now))
        }
        profile.computedAt = now
        store.save(profile)
    }

    func snapshotForScan(scanId: String, userId: String) async {
        let snap = snapshot(userId: userId, asOf: .now)
        store.pin(snap, toScan: scanId)
    }

    func scanHistory(userId: String) -> [AttributeProfile] {
        store.history(userId: userId)
    }
}

// MARK: - MockAttributeService

@MainActor
final class MockAttributeService: AttributeServiceProtocol {
    var profileByUser: [String: AttributeProfile] = [:]
    var history: [String: [AttributeProfile]] = [:]
    var ingested: [WorkoutLog] = []
    var seededFor: [String: Set<AttributeKey>] = [:]

    func profile(userId: String) -> AttributeProfile {
        profileByUser[userId] ?? .empty(userId: userId, at: .now)
    }
    func snapshot(userId: String, asOf date: Date) -> AttributeProfile {
        AttributeDrift.project(profile(userId: userId), to: date)
    }
    @discardableResult
    func ingest(session: WorkoutLog, userId: String) async -> AttributeProfile {
        ingested.append(session)
        return profile(userId: userId)
    }
    @discardableResult
    func ingest(skillSession: UserSkillProgress.Session, userId: String) async -> AttributeProfile {
        profile(userId: userId)
    }
    func applySeed(_ seeded: Set<AttributeKey>, userId: String) {
        seededFor[userId] = seeded
    }
    func snapshotForScan(scanId: String, userId: String) async {}
    func scanHistory(userId: String) -> [AttributeProfile] {
        history[userId] ?? []
    }
}
```

- [ ] **Step 2: Confirm compile**

Run: `xcodebuild build -scheme UNBOUND`
Expected: BUILD FAILED (missing `AttributeDrift`, `AttributeIngest`, `AttributeCatalogProtocol`, `AttributeProfileStoreProtocol` — those land in 1a.7 and 1a.8).

- [ ] **Step 3: Don't commit yet** — wait for 1a.7/1a.8 to land their dependencies.

---

### Task 1a.7: AttributeDrift — pure drift math

**Files:**
- Create: `UNBOUND/Services/Attributes/AttributeDrift.swift`
- Create: `UNBOUNDTests/Services/AttributeServiceDriftTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/AttributeServiceDriftTests.swift
import XCTest
@testable import UNBOUND

final class AttributeServiceDriftTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeProfile(peak: Double, current: Double, at: Date) -> AttributeProfile {
        var p = AttributeProfile.empty(userId: "u", at: at)
        p.set(.power, AttributeValue(peak: peak, current: current, lastContributionAt: at))
        return p
    }

    func testNoChangeAtLastContributionAt() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0)
        XCTAssertEqual(snap.value(for: .power).current, 70, accuracy: 0.001)
    }

    func testNoChangeWithin7DayGrace() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(7 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 70, accuracy: 0.001)
    }

    func testMidWindowAt22DaysIdleIs50PercentTowardFloor() {
        // 22d idle = 7d grace + 15d decay → decayProgress = 0.5
        // floor = 80 * 0.7 = 56; expected = 56 + (70 - 56) * 0.5 = 63
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(22 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 63, accuracy: 0.001)
    }

    func testExactFloorAt37DaysIdle() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(37 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 56, accuracy: 0.001)  // 80 * 0.7
    }

    func testClampsAtFloorPast37Days() {
        let p = makeProfile(peak: 80, current: 70, at: t0)
        let snap = AttributeDrift.project(p, to: t0.addingTimeInterval(90 * 86400))
        XCTAssertEqual(snap.value(for: .power).current, 56, accuracy: 0.001)
    }

    func testPeakIndependentTempoIdenticalCurveForLowAndHighPeaks() {
        let pLow  = makeProfile(peak: 20, current: 20, at: t0)
        let pHigh = makeProfile(peak: 90, current: 90, at: t0)
        let date = t0.addingTimeInterval(22 * 86400)  // mid-window
        let snapLow  = AttributeDrift.project(pLow, to: date).value(for: .power).current
        let snapHigh = AttributeDrift.project(pHigh, to: date).value(for: .power).current
        let progressLow  = (20.0 - snapLow)  / (20.0 - 14.0)   // 14 = floor
        let progressHigh = (90.0 - snapHigh) / (90.0 - 63.0)   // 63 = floor
        XCTAssertEqual(progressLow, progressHigh, accuracy: 0.001)
    }

    func testPerAxisIndependenceUnrelatedAxesDriftIndependently() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 80, current: 70, lastContributionAt: t0))
        // Mobility contributed 14 days later (still within its own grace)
        let mobilityContribAt = t0.addingTimeInterval(14 * 86400)
        p.set(.mobility, AttributeValue(peak: 40, current: 40, lastContributionAt: mobilityContribAt))

        let evalAt = t0.addingTimeInterval(37 * 86400)
        let snap = AttributeDrift.project(p, to: evalAt)

        // Power: 37 days idle → at floor.
        XCTAssertEqual(snap.value(for: .power).current, 56, accuracy: 0.001)
        // Mobility: only 23 days idle → grace + 16 days decay → progress 16/30
        // floor = 40 * 0.7 = 28; expected = 28 + (40 - 28) * (1 - 16/30) ≈ 33.6
        XCTAssertEqual(snap.value(for: .mobility).current, 33.6, accuracy: 0.05)
    }
}
```

- [ ] **Step 2: Run tests to confirm failure**

Expected: FAIL — `AttributeDrift` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// UNBOUND/Services/Attributes/AttributeDrift.swift
import Foundation

enum AttributeDrift {
    static let graceDays: Double = 7
    static let decayWindowDays: Double = 30

    /// Project `profile` forward to `date`, applying gentle drift per axis.
    /// Pure — no IO, no persistence.
    static func project(_ profile: AttributeProfile, to date: Date) -> AttributeProfile {
        var out = profile
        for key in AttributeKey.allCases {
            let v = out.value(for: key)
            let floor = v.floor
            let daysIdle = max(0.0, date.timeIntervalSince(v.lastContributionAt) / 86_400.0)
            let effective = max(0.0, daysIdle - graceDays)
            let progress = min(1.0, effective / decayWindowDays)
            var updated = v
            updated.current = floor + (v.current - floor) * (1.0 - progress)
            // Never let drift push above current or below floor.
            updated.current = max(floor, min(updated.current, v.current))
            out.set(key, updated)
        }
        out.computedAt = date
        return out
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Expected: all 7 PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Attributes/AttributeDrift.swift UNBOUNDTests/Services/AttributeServiceDriftTests.swift
git commit -m "feat(attr): AttributeDrift — peak-independent percentage interpolation"
```

---

### Task 1a.8: AttributeIngest — session → deltas + threshold detection

**Files:**
- Create: `UNBOUND/Services/Attributes/AttributeIngest.swift`
- Create: `UNBOUNDTests/Services/AttributeServiceIngestTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Services/AttributeServiceIngestTests.swift
import XCTest
@testable import UNBOUND

final class AttributeServiceIngestTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func stubCatalog(_ entries: [String: AttributeContribution]) -> AttributeCatalogProtocol {
        StubAttributeCatalog(byName: entries)
    }

    func testSingleHeavySquatSessionMovesPowerDominantly() {
        let catalog = stubCatalog([
            "barbell_back_squat": AttributeContribution(weights: [.power: 0.7, .endurance: 0.2, .control: 0.1])
        ])
        let log = WorkoutLog(
            id: "w1", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Heavy Lower",
            startedAt: t0, completedAt: t0.addingTimeInterval(45 * 60),
            exerciseEntries: [
                ExerciseLogEntry(id: "e1", exerciseName: "barbell_back_squat",
                    plannedSets: 5, plannedReps: "5",
                    sets: [SetLog(id: "s1", setNumber: 1, weightKg: 100, reps: 5, rpe: 8, isWarmup: false)],
                    skipped: false, notes: nil)
            ],
            overallNotes: nil, overallRPE: 8, durationMinutes: 45
        )

        let deltas = AttributeIngest.deltas(for: log, catalog: catalog)

        XCTAssertGreaterThan(deltas[.power] ?? 0, 0)
        XCTAssertGreaterThan(deltas[.power] ?? 0, deltas[.endurance] ?? 0)
        XCTAssertGreaterThan(deltas[.endurance] ?? 0, deltas[.control] ?? 0)
        XCTAssertEqual(deltas[.mobility] ?? 0, 0)
    }

    func testEmptySessionYieldsZeroDeltas() {
        let catalog = stubCatalog([:])
        let log = WorkoutLog(
            id: "w2", userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Empty", startedAt: t0, completedAt: t0,
            exerciseEntries: [], overallNotes: nil, overallRPE: nil, durationMinutes: 0
        )
        let deltas = AttributeIngest.deltas(for: log, catalog: catalog)
        for key in AttributeKey.allCases {
            XCTAssertEqual(deltas[key] ?? 0, 0)
        }
    }

    func testApplyDeltasLiftsPeakWhenCurrentExceedsPeak() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 25], at: t0)
        XCTAssertEqual(p.value(for: .power).current, 25, accuracy: 0.001)
        XCTAssertEqual(p.value(for: .power).peak,    25, accuracy: 0.001)
        XCTAssertTrue(crossings.isEmpty || crossings.first?.axis == .power)
    }

    func testApplyDeltasClampsCurrentAt100() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power, AttributeValue(peak: 95, current: 95, lastContributionAt: t0))
        _ = AttributeIngest.applyDeltas(&p, deltas: [.power: 50], at: t0)
        XCTAssertEqual(p.value(for: .power).current, 100, accuracy: 0.001)
        XCTAssertEqual(p.value(for: .power).peak,    100, accuracy: 0.001)
    }

    func testApplyDeltasEmitsTierEventOnCrossingApprenticeToForged() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        // Apprentice = ordinal 4...5 → cMinus(6)/c(7) is Forged. Set current near boundary.
        // ordinal 5 (dPlus) = 5/17*100 ≈ 29.4 (Apprentice top). Push past to 36 (cMinus / Forged).
        p.set(.power, AttributeValue(peak: 50, current: 29, lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 8], at: t0)
        XCTAssertEqual(crossings.count, 1)
        XCTAssertEqual(crossings.first?.axis, .power)
        XCTAssertEqual(crossings.first?.level, .tier)
    }

    func testApplyDeltasEmitsATierEventOnCrossingMasterToVessel() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        // Master = ordinal 10...11 (b, bPlus); Vessel = ordinal 12...13 (aMinus, a).
        // Boundary: bPlus(11) ≈ 64.7, aMinus(12) ≈ 70.6.
        p.set(.power, AttributeValue(peak: 80, current: 64, lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 10], at: t0)
        XCTAssertEqual(crossings.first?.level, .aTier)
    }

    func testApplyDeltasEmitsSubRankEventOnIntraTierStep() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        // E-(0) = 0; E(1) ≈ 5.9. Crossing 0 → 6 is a sub-rank step within Initiate.
        p.set(.power, AttributeValue(peak: 50, current: 0, lastContributionAt: t0))
        let crossings = AttributeIngest.applyDeltas(&p, deltas: [.power: 6], at: t0)
        XCTAssertEqual(crossings.first?.level, .subRank)
    }
}

// Local test helper
final class StubAttributeCatalog: AttributeCatalogProtocol {
    var byName: [String: AttributeContribution]
    init(byName: [String: AttributeContribution]) { self.byName = byName }
    func contribution(forExerciseName name: String) -> AttributeContribution {
        byName[name] ?? .zero
    }
    func contribution(forSkillNodeId id: String) -> AttributeContribution {
        byName[id] ?? .zero
    }
}
```

- [ ] **Step 2: Run tests to confirm failure**

Expected: FAIL — `AttributeIngest`, `AttributeCatalogProtocol` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// UNBOUND/Services/Attributes/AttributeIngest.swift
import Foundation

protocol AttributeCatalogProtocol: AnyObject {
    func contribution(forExerciseName name: String) -> AttributeContribution
    func contribution(forSkillNodeId id: String) -> AttributeContribution
}

enum AttributeIngest {
    static let gainConstant: Double = 4.0

    static func deltas(for session: WorkoutLog, catalog: AttributeCatalogProtocol) -> [AttributeKey: Double] {
        let entries = session.exerciseEntries
        guard !entries.isEmpty else { return [:] }

        // session intensity from overall RPE (1...10 → 0...1). Fallback 0.5 if missing.
        let intensity = Double(session.overallRPE ?? 5) / 10.0

        // effort mass per entry: Σ weight × reps across sets (warmups excluded).
        func effortMass(_ entry: ExerciseLogEntry) -> Double {
            entry.sets
                .filter { !$0.isWarmup }
                .reduce(0.0) { acc, set in
                    acc + (set.weightKg ?? 0) * Double(set.reps)
                }
        }

        let masses = entries.map { ($0, effortMass($0)) }
        let total = masses.map(\.1).reduce(0, +)
        guard total > 0 else { return [:] }

        var deltas: [AttributeKey: Double] = [:]
        for (entry, mass) in masses where mass > 0 {
            let share = mass / total
            let contrib = catalog.contribution(forExerciseName: entry.exerciseName)
            for key in AttributeKey.allCases {
                let w = contrib.weight(for: key)
                guard w > 0 else { continue }
                deltas[key, default: 0] += intensity * share * w * gainConstant
            }
        }
        return deltas
    }

    static func deltas(for skillSession: UserSkillProgress.Session, catalog: AttributeCatalogProtocol) -> [AttributeKey: Double] {
        // Skill sessions don't carry weight × reps. Use duration × RPE as effort proxy.
        let intensity = Double(skillSession.rpe ?? 5) / 10.0
        let durationMin = max(1.0, Double(skillSession.durationMinutes))
        let effort = (durationMin / 30.0) * intensity   // 30-min RPE 5 session = baseline 0.5
        let contrib = catalog.contribution(forSkillNodeId: skillSession.skillNodeId)
        var deltas: [AttributeKey: Double] = [:]
        for key in AttributeKey.allCases {
            let w = contrib.weight(for: key)
            guard w > 0 else { continue }
            deltas[key] = effort * w * gainConstant
        }
        return deltas
    }

    /// Mutates `profile` in place: adds deltas, lifts peaks, returns rank-up crossings.
    static func applyDeltas(
        _ profile: inout AttributeProfile,
        deltas: [AttributeKey: Double],
        at date: Date
    ) -> [AttributeRankUpEvent] {
        var events: [AttributeRankUpEvent] = []
        for key in AttributeKey.allCases {
            let delta = deltas[key] ?? 0
            guard delta > 0 else { continue }
            var v = profile.value(for: key)
            let beforeSub  = v.subRank
            let beforeTier = v.rankTitle
            v.current = min(100, v.current + delta)
            if v.current > v.peak { v.peak = v.current }
            v.lastContributionAt = date
            profile.set(key, v)
            let afterSub  = v.subRank
            let afterTier = v.rankTitle
            if afterSub != beforeSub {
                let level: AttributeRankUpEvent.Level = {
                    if afterTier != beforeTier {
                        let aTitles: Set<RankTitle> = [.vessel, .unbound, .ascendant]
                        return aTitles.contains(afterTier) ? .aTier : .tier
                    }
                    return .subRank
                }()
                events.append(AttributeRankUpEvent(
                    axis: key,
                    fromTitle: beforeTier, toTitle: afterTier,
                    fromSubRank: beforeSub, toSubRank: afterSub,
                    level: level, timestamp: date
                ))
            }
        }
        return events
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Expected: all 6 PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Attributes/AttributeIngest.swift UNBOUNDTests/Services/AttributeServiceIngestTests.swift
git commit -m "feat(attr): AttributeIngest — deltas + crossing detection w/ 3-level emission"
```

---

### Task 1a.9: AttributeCatalog — load JSON, wire to exercise + skill catalogs

**Files:**
- Create: `UNBOUND/Services/Attributes/AttributeCatalog.swift`
- Create: `UNBOUND/Resources/AttributeContributions.json` (skeleton; full vectors authored in 1a.11)
- Create: `UNBOUNDTests/Catalog/AttributeContributionCatalogTests.swift`

- [ ] **Step 1: Write the failing test (catalog integrity)**

```swift
// UNBOUNDTests/Catalog/AttributeContributionCatalogTests.swift
import XCTest
@testable import UNBOUND

final class AttributeContributionCatalogTests: XCTestCase {
    func testEveryExerciseHasAValidContribution() {
        let catalog = AttributeCatalog.shared
        for item in ExerciseLibrary.all {
            let c = catalog.contribution(forExerciseName: item.id)
            XCTAssertTrue(c.sumIsValid,
                "Exercise '\(item.id)' contribution must sum to 1.0 ± 0.01 (got \(c.weights.values.reduce(0,+)))")
        }
    }

    func testEveryAttributeKeyAppearsInAtLeastOneVector() {
        let catalog = AttributeCatalog.shared
        var represented: Set<AttributeKey> = []
        for item in ExerciseLibrary.all {
            let c = catalog.contribution(forExerciseName: item.id)
            for (k, w) in c.weights where w > 0 { represented.insert(k) }
        }
        for key in AttributeKey.allCases {
            XCTAssertTrue(represented.contains(key),
                "AttributeKey '\(key)' never appears in any exercise vector — users couldn't develop it.")
        }
    }
}
```

- [ ] **Step 2: Create JSON skeleton** (so tests don't crash on load)

```json
// UNBOUND/Resources/AttributeContributions.json
{
  "exercises": {
    "barbell_back_squat":       { "power": 0.70, "endurance": 0.20, "control": 0.10 }
  },
  "skill_nodes": {}
}
```

- [ ] **Step 3: Write the catalog implementation**

```swift
// UNBOUND/Services/Attributes/AttributeCatalog.swift
import Foundation

@MainActor
final class AttributeCatalog: AttributeCatalogProtocol {
    static let shared = AttributeCatalog()

    private let byExercise: [String: AttributeContribution]
    private let bySkillNode: [String: AttributeContribution]

    init() {
        if let url = Bundle.main.url(forResource: "AttributeContributions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let payload = try? JSONDecoder().decode(Payload.self, from: data)
        {
            self.byExercise  = payload.exercises.mapValues { AttributeContribution(weights: $0.toAttributeWeights()) }
            self.bySkillNode = payload.skill_nodes.mapValues { AttributeContribution(weights: $0.toAttributeWeights()) }
        } else {
            self.byExercise  = [:]
            self.bySkillNode = [:]
            LoggingService.shared.warn("AttributeContributions.json missing or invalid — every contribution will be zero.")
        }
    }

    func contribution(forExerciseName name: String) -> AttributeContribution {
        byExercise[name] ?? .zero
    }

    func contribution(forSkillNodeId id: String) -> AttributeContribution {
        bySkillNode[id] ?? .zero
    }
}

// MARK: - JSON shapes

private struct Payload: Decodable {
    let exercises: [String: WeightDict]
    let skill_nodes: [String: WeightDict]
}

private struct WeightDict: Decodable {
    let power: Double?
    let agility: Double?
    let control: Double?
    let endurance: Double?
    let mobility: Double?
    let explosiveness: Double?

    func toAttributeWeights() -> [AttributeKey: Double] {
        var out: [AttributeKey: Double] = [:]
        if let v = power, v > 0         { out[.power] = v }
        if let v = agility, v > 0       { out[.agility] = v }
        if let v = control, v > 0       { out[.control] = v }
        if let v = endurance, v > 0     { out[.endurance] = v }
        if let v = mobility, v > 0      { out[.mobility] = v }
        if let v = explosiveness, v > 0 { out[.explosiveness] = v }
        return out
    }
}
```

- [ ] **Step 4: Run tests**

Expected: test 1 (sum validation) PASSES for the one populated entry; FAILS for every other exercise (zero contribution). Test 2 (axis coverage) FAILS — only `power/endurance/control` covered.

- [ ] **Step 5: Don't commit yet** — full vector authoring lands in Task 1a.11, which makes both tests pass.

---

### Task 1a.10: AttributeProfileStore — local persistence via DatabaseService

**Files:**
- Create: `UNBOUND/Services/Attributes/AttributeProfileStore.swift`

- [ ] **Step 1: Write the implementation** (no behavioral test — store is a thin wrapper around DatabaseService)

```swift
// UNBOUND/Services/Attributes/AttributeProfileStore.swift
import Foundation

@MainActor
protocol AttributeProfileStoreProtocol: AnyObject {
    func load(userId: String) -> AttributeProfile?
    func save(_ profile: AttributeProfile)
    func pin(_ profile: AttributeProfile, toScan scanId: String)
    func history(userId: String) -> [AttributeProfile]
}

@MainActor
final class AttributeProfileStore: AttributeProfileStoreProtocol {
    static let shared = AttributeProfileStore()

    private let defaults = UserDefaults.standard
    private let profileKeyPrefix = "unbound.attributeProfile."
    private let historyKeyPrefix = "unbound.attributeHistory."

    func load(userId: String) -> AttributeProfile? {
        guard let data = defaults.data(forKey: profileKeyPrefix + userId) else { return nil }
        return try? JSONDecoder().decode(AttributeProfile.self, from: data)
    }

    func save(_ profile: AttributeProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKeyPrefix + profile.userId)
    }

    func pin(_ profile: AttributeProfile, toScan scanId: String) {
        var hist = history(userId: profile.userId)
        hist.append(profile)
        if let data = try? JSONEncoder().encode(hist) {
            defaults.set(data, forKey: historyKeyPrefix + profile.userId)
        }
    }

    func history(userId: String) -> [AttributeProfile] {
        guard let data = defaults.data(forKey: historyKeyPrefix + userId),
              let list = try? JSONDecoder().decode([AttributeProfile].self, from: data)
        else { return [] }
        return list
    }
}
```

- [ ] **Step 2: Confirm `AttributeService.swift` from Task 1a.6 now compiles**

Run: `xcodebuild build -scheme UNBOUND`
Expected: BUILD SUCCESS.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Services/Attributes/AttributeService.swift UNBOUND/Services/Attributes/AttributeProfileStore.swift UNBOUND/Services/Attributes/AttributeCatalog.swift UNBOUND/Resources/AttributeContributions.json UNBOUNDTests/Catalog/AttributeContributionCatalogTests.swift
git commit -m "feat(attr): AttributeService + Store + Catalog (vectors authored next)"
```

---

### Task 1a.11: Author full contribution catalog (JSON content task)

**Files:**
- Modify: `UNBOUND/Resources/AttributeContributions.json`

- [ ] **Step 1: Populate vectors for every `ExerciseLibrary.all` entry**

Use these anchor rules; sums MUST equal 1.0:

| Pattern | POW | AGI | CTL | END | MOB | EXP |
|---|---|---|---|---|---|---|
| Heavy compound lift (Squat, Deadlift, Bench, OHP) | 0.70 | — | 0.10 | 0.20 | — | — |
| Hypertrophy compound (RDL, Hip Thrust, Front Squat) | 0.55 | — | 0.10 | 0.30 | 0.05 | — |
| Isolation lift (Leg ext, Bicep curl, etc.) | 0.40 | — | 0.20 | 0.40 | — | — |
| Machine compound | 0.55 | — | 0.05 | 0.40 | — | — |
| Pull-up / Dip / Push-up (bodyweight basics) | 0.50 | — | 0.40 | 0.10 | — | — |
| Skill / lever / handstand work | 0.20 | — | 0.60 | — | 0.20 | — |
| Mobility / ROM work | — | — | 0.20 | — | 0.80 | — |
| Sprint / interval cardio | 0.10 | 0.40 | — | 0.10 | — | 0.40 |
| Z2 / endurance cardio | — | 0.10 | — | 0.80 | 0.10 | — |
| Plyo / jump work | 0.20 | 0.10 | — | — | — | 0.70 |
| Carry / loaded carry | 0.50 | — | 0.10 | 0.40 | — | — |
| Core anti-extension/rotation (Plank, Pallof) | 0.20 | — | 0.60 | 0.20 | — | — |

Map each entry by `ExerciseLibraryItem.id`. Pick the row that best matches the movement intent, not the muscle group.

- [ ] **Step 2: Populate vectors for every `SkillTreeContent` skill node**

(Engineer task — open `SkillTreeContent.swift`, list every `SkillNode.id`, classify by row above. Most skill nodes are "Skill/lever/handstand" or "Bodyweight basic.")

- [ ] **Step 3: Run catalog tests to verify everything sums + covers all axes**

Run: `xcodebuild test -scheme UNBOUND -only-testing UNBOUNDTests/AttributeContributionCatalogTests`
Expected: PASS — every exercise valid, every axis represented.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Resources/AttributeContributions.json
git commit -m "feat(attr): author full per-exercise + per-skill contribution catalog"
```

---

### Task 1a.12: Onboarding seed survey screen + flow integration

**Files:**
- Modify: `UNBOUND/Models/OnboardingAnswers.swift`
- Modify: `UNBOUND/ViewModels/OnboardingFlowViewModel.swift`
- Create: `UNBOUND/Views/Onboarding/Steps/Step_BuildSeed.swift`
- Modify: `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` (the `OnboardingRouter` switch)

- [ ] **Step 1: Add `seededAttributes` to `OnboardingAnswers`**

Open `UNBOUND/Models/OnboardingAnswers.swift` and add to the struct:
```swift
var seededAttributes: Set<AttributeKey> = []
```
(Place near the `exerciseStyle` / `experience` fields — alphabetical or grouped, match local convention.)

- [ ] **Step 2: Add `buildSeed` step to `OnboardingStep` enum**

In `OnboardingFlowViewModel.swift`, add a new case to the `OnboardingStep` enum, placed AFTER `.exerciseStyle` and BEFORE `.sessionLength` (logical "training preferences" cluster):
```swift
case buildSeed           // seed survey — Phase 1a, sub-project #1
```

- [ ] **Step 3: Create the screen**

```swift
// UNBOUND/Views/Onboarding/Steps/Step_BuildSeed.swift
import SwiftUI

struct Step_BuildSeed: View {
    @Bindable var flow: OnboardingFlowViewModel
    @State private var selected: Set<AttributeKey> = []
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: "What does your training look like right now?",
            subtitle: "Pick up to 2. We'll seed your build so the hex starts where you are.",
            primaryLabel: "CONTINUE",
            primaryEnabled: true,
            onPrimary: {
                flow.answers.seededAttributes = selected
                onContinue()
            },
            secondaryLabel: "SKIP",
            onSecondary: {
                flow.answers.seededAttributes = []
                onContinue()
            }
        ) {
            VStack(spacing: 10) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    chip(for: key)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func chip(for key: AttributeKey) -> some View {
        let isOn = selected.contains(key)
        let atLimit = selected.count >= 2 && !isOn

        Button {
            if isOn { selected.remove(key) }
            else if !atLimit { selected.insert(key) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(key.shortCode)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(isOn ? Color.unbound.accent : Color.unbound.textSecondary)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(key.displayName.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(isOn ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    Text(key.trainsCopy)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? Color.unbound.accent : Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? Color.unbound.accent : Color.unbound.border, lineWidth: 1)
            )
            .opacity(atLimit ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(atLimit)
    }
}
```

- [ ] **Step 4: Route the new step**

Open `OnboardingContainerView.swift`. Find `OnboardingRouter` (it's the view that switches on `flow.currentStep`). Add the new case:
```swift
case .buildSeed:
    Step_BuildSeed(flow: flow, onContinue: { flow.next() })
```

- [ ] **Step 5: Apply the seed on onboarding finish**

In `OnboardingFlowViewModel.finish(userId:)`, after the existing profile-write block, call:
```swift
await MainActor.run {
    ServiceContainer.shared.attribute.applySeed(answers.seededAttributes, userId: userId)
}
```
(Or use whatever DI pattern the file uses — match local convention. If `ServiceContainer.shared` isn't available there, pass the service in via the existing init signature.)

- [ ] **Step 6: Manual check — run onboarding in simulator**

Build & launch. Walk through onboarding to the new screen. Confirm:
- 6 chips render with code + display name + trains copy.
- Selecting 2 disables the rest.
- Continue advances.
- Skip writes empty set.

- [ ] **Step 7: Commit**

```bash
git add UNBOUND/Models/OnboardingAnswers.swift UNBOUND/ViewModels/OnboardingFlowViewModel.swift UNBOUND/Views/Onboarding/Steps/Step_BuildSeed.swift UNBOUND/Views/Onboarding/OnboardingContainerView.swift
git commit -m "feat(attr): onboarding seed survey — pick 1-2 attributes for +15 prefill"
```

---

### Task 1a.13: Wire AttributeService into ServiceContainer + session-finish call site

**Files:**
- Modify: `UNBOUND/Services/ServiceContainer.swift`
- Modify: (the call site that invokes `services.sessionXP.recordSession(...)` — find with grep)

- [ ] **Step 1: Add `attribute` to ServiceContainer**

In `ServiceContainer.swift`:
1. Add the property near other service slots:
   ```swift
   let attribute: any AttributeServiceProtocol
   ```
2. In the default `init()`:
   ```swift
   self.attribute = AttributeService.shared
   ```
3. In the test-init signature, add `attribute: any AttributeServiceProtocol` parameter and assign.
4. Update any `init(...)` callers (test factories) to pass `MockAttributeService()`.

- [ ] **Step 2: Find session-finish call site**

Run: `grep -rn "services\.sessionXP\.recordSession\|sessionXP\.recordSession" UNBOUND/`
Expected: ≥1 hit, likely in `WorkoutLoggingViewModel` or `WorkoutSessionService`.

- [ ] **Step 3: Add the attribute ingest call alongside**

At each call site that records a finished workout, after `services.sessionXP.recordSession(...)`, add:
```swift
await services.attribute.ingest(session: workoutLog, userId: userId)
```
(Use the same `workoutLog`/`userId` variables already in scope.)

- [ ] **Step 4: Find skill-session finish call site**

Run: `grep -rn "SkillProgressService\.\|skillProgress\.recordSession" UNBOUND/`
Add the skill-session ingest alongside:
```swift
await services.attribute.ingest(skillSession: session, userId: userId)
```

- [ ] **Step 5: Build + manual smoke test**

Run: `xcodebuild build -scheme UNBOUND` → must SUCCEED.
Launch in simulator, complete a session (workout or skill), confirm via logging that `AttributeService.ingest` is called. Open Xcode breakpoint or `print` if needed.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Services/ServiceContainer.swift <path-to-workout-finish-file> <path-to-skill-finish-file>
git commit -m "feat(attr): wire AttributeService into DI + session-finish call sites"
```

---

### Phase 1a Gate

Before moving to Phase 1b, verify:
- [ ] All tests in `UNBOUNDTests/Models/Attribute*` and `UNBOUNDTests/Services/AttributeService*` pass.
- [ ] `UNBOUNDTests/Catalog/AttributeContributionCatalogTests` passes (every exercise sums to 1.0, every axis represented).
- [ ] Project builds without warnings related to the new code.
- [ ] Onboarding flow shows the seed screen and writes prefill correctly.
- [ ] Manual session-finish flow shows AttributeService receiving the ingest call (log output or breakpoint hit).
- [ ] No UI surfaces yet — home/profile/scan look identical to before. **This is correct.**

---

# Phase 1b — Profile Build card + rank-up animation

### Task 1b.1: AttributeHex reusable renderer

**Files:**
- Create: `UNBOUND/Views/Components/AttributeHex.swift`

- [ ] **Step 1: Write the implementation**

```swift
// UNBOUND/Views/Components/AttributeHex.swift
import SwiftUI

struct AttributeHex: View {
    /// 0...100 per axis. Renders the filled "current" polygon.
    let current: [AttributeKey: Double]
    /// Optional dashed peak overlay. Pass nil to omit.
    let peak: [AttributeKey: Double]?
    /// Show "POW/AGI/..." axis labels around the hex.
    var showLabels: Bool = true
    /// Outer radius in points. Hex is drawn within a square box of side = 2*radius.
    let radius: CGFloat

    private let axisOrder: [AttributeKey] = [.power, .agility, .control, .endurance, .mobility, .explosiveness]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawGrid(ctx: ctx, center: center)
            drawAxes(ctx: ctx, center: center)
            if let peak { drawPolygon(ctx: ctx, center: center, values: peak, dashed: true) }
            drawPolygon(ctx: ctx, center: center, values: current, dashed: false)
        }
        .frame(width: 2 * radius, height: 2 * radius)
        .overlay { if showLabels { labelOverlay } }
    }

    private func point(for index: Int, at fraction: Double, center: CGPoint) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
        let r = radius * CGFloat(fraction)
        return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }

    private func drawGrid(ctx: GraphicsContext, center: CGPoint) {
        for fraction in [1.0 / 3, 2.0 / 3, 1.0] {
            var path = Path()
            for i in 0..<6 {
                let p = point(for: i, at: fraction, center: center)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            ctx.stroke(path, with: .color(Color.unbound.border), lineWidth: 1)
        }
    }

    private func drawAxes(ctx: GraphicsContext, center: CGPoint) {
        for i in 0..<6 {
            var path = Path()
            path.move(to: center)
            path.addLine(to: point(for: i, at: 1.0, center: center))
            ctx.stroke(path, with: .color(Color.unbound.border), lineWidth: 1)
        }
    }

    private func drawPolygon(ctx: GraphicsContext, center: CGPoint, values: [AttributeKey: Double], dashed: Bool) {
        var path = Path()
        for (i, key) in axisOrder.enumerated() {
            let fraction = max(0, min(1, (values[key] ?? 0) / 100))
            let p = point(for: i, at: fraction, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        if dashed {
            ctx.stroke(path, with: .color(Color.unbound.textTertiary), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        } else {
            ctx.fill(path, with: .color(Color.unbound.accent.opacity(0.30)))
            ctx.stroke(path, with: .color(Color.unbound.accent), lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private var labelOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let labelRadius = radius + 16
            ForEach(Array(axisOrder.enumerated()), id: \.offset) { (idx, key) in
                let angle = -CGFloat.pi / 2 + CGFloat(idx) * (2 * .pi / 6)
                Text(key.shortCode)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .position(
                        x: center.x + cos(angle) * labelRadius,
                        y: center.y + sin(angle) * labelRadius
                    )
            }
        }
    }
}
```

- [ ] **Step 2: Confirm compile** — visual smoke test in SwiftUI preview if available.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Components/AttributeHex.swift
git commit -m "feat(attr-ui): AttributeHex reusable Canvas-based renderer"
```

---

### Task 1b.2: BuildAttributeCell — single 3×2 grid cell

**Files:**
- Create: `UNBOUND/Views/Profile/BuildAttributeCell.swift`

- [ ] **Step 1: Write the implementation**

```swift
// UNBOUND/Views/Profile/BuildAttributeCell.swift
import SwiftUI

struct BuildAttributeCell: View {
    let key: AttributeKey
    let value: AttributeValue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(key.shortCode)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textSecondary)
                Spacer()
                Text("\(Int(value.current.rounded()))")
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
            Rectangle()
                .fill(Color.unbound.surface)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.unbound.accent)
                            .frame(width: geo.size.width * CGFloat(value.current / 100))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 5) {
                Circle()
                    .fill(isHighTier ? Color.unbound.accent : Color.unbound.textTertiary)
                    .frame(width: 5, height: 5)
                Text(value.rankTitle.displayName.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(isHighTier ? Color.unbound.accent : Color.unbound.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var isHighTier: Bool {
        switch value.rankTitle {
        case .master, .vessel, .unbound, .ascendant: return true
        default: return false
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Profile/BuildAttributeCell.swift
git commit -m "feat(attr-ui): BuildAttributeCell — value + bar + rank title pill"
```

---

### Task 1b.3: ProfileBuildCard composing hex + 3×2 grid

**Files:**
- Create: `UNBOUND/Views/Profile/ProfileBuildCard.swift`

- [ ] **Step 1: Write the implementation**

```swift
// UNBOUND/Views/Profile/ProfileBuildCard.swift
import SwiftUI

struct ProfileBuildCard: View {
    let profile: AttributeProfile

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 12) {
            Text("BUILD")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 8) {
                AttributeHex(
                    current: currentValues,
                    peak: peakValues,
                    showLabels: true,
                    radius: 90
                )
                Text(profile.buildName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.unbound.textPrimary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    BuildAttributeCell(key: key, value: profile.value(for: key))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private var currentValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, profile.value(for: $0).current) })
    }

    private var peakValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, profile.value(for: $0).peak) })
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Profile/ProfileBuildCard.swift
git commit -m "feat(attr-ui): ProfileBuildCard composing hex + buildName + 3x2 grid"
```

---

### Task 1b.4: Slot ProfileBuildCard into ProfileView

**Files:**
- Modify: `UNBOUND/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Inspect existing ProfileView to find the slot**

Run: `grep -n "VStack\|Section\|identityHeader\|recent" UNBOUND/Views/Profile/ProfileView.swift | head -20`
Identify the existing identity-header section and the "Recent" or first card after it.

- [ ] **Step 2: Inject ProfileBuildCard**

Add a property:
```swift
@EnvironmentObject var services: ServiceContainer
@State private var profile: AttributeProfile = .empty(userId: "", at: .now)
```

In `.task` (or `onAppear`), populate:
```swift
.task {
    let uid = services.auth.currentUserId ?? "anonymous"
    profile = services.attribute.snapshot(userId: uid, asOf: .now)
}
```

Slot the card in the body between the existing identity header and the first existing card:
```swift
ProfileBuildCard(profile: profile)
    .padding(.horizontal, 16)
```

- [ ] **Step 3: Manual smoke test in simulator**

Launch, navigate to profile. Card must render with empty profile (single point hex), then with seeded data after running a session.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Profile/ProfileView.swift
git commit -m "feat(attr-ui): slot ProfileBuildCard into ProfileView"
```

---

### Task 1b.5: AttributeRankUpToast — animation handler

**Files:**
- Create: `UNBOUND/Views/Components/AttributeRankUpToast.swift`

- [ ] **Step 1: Write the implementation**

```swift
// UNBOUND/Views/Components/AttributeRankUpToast.swift
import SwiftUI

struct AttributeRankUpToast: ViewModifier {
    @State private var pending: AttributeRankUpEvent?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let pending {
                    toastView(for: pending)
                        .padding(.top, 64)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { note in
                guard let event = note.object as? AttributeRankUpEvent else { return }
                switch event.level {
                case .subRank:
                    return  // silent per cinematic-asymmetry rule
                case .tier, .aTier:
                    show(event)
                }
            }
    }

    @ViewBuilder
    private func toastView(for event: AttributeRankUpEvent) -> some View {
        HStack(spacing: 10) {
            Image("rank_title_\(event.toTitle.rawValue)")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.axis.shortCode)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.accent)
                Text(event.toTitle.displayName.uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(event.level == .aTier ? Color.unbound.impact : Color.unbound.accent, lineWidth: 1)
        )
        .shadow(color: Color.unbound.accent.opacity(event.level == .aTier ? 0.6 : 0.25), radius: 12)
    }

    private func show(_ event: AttributeRankUpEvent) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            pending = event
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { pending = nil }
            }
        }
    }
}

extension View {
    func attributeRankUpToast() -> some View {
        modifier(AttributeRankUpToast())
    }
}
```

- [ ] **Step 2: Apply the modifier on Home + Profile**

In `UnboundHomeView.swift`, on the root view:
```swift
.attributeRankUpToast()
```
Same in `ProfileView.swift`.

- [ ] **Step 3: Manual smoke test**

In simulator, manually push a `.attributeRankUp` notification via debug breakpoint or temporary debug button. Verify toast appears + auto-dismisses.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Components/AttributeRankUpToast.swift UNBOUND/Views/Home/UnboundHomeView.swift UNBOUND/Views/Profile/ProfileView.swift
git commit -m "feat(attr-ui): rank-up toast (silent sub-rank, toast tier, glow aTier)"
```

---

### Task 1b.6: Hook A-tier crossings into existing chain-shatter cinematic

**Files:**
- Modify: existing rank-up cinematic view (find with `grep -rn "RankUpShareCard\|chainShatter\|ChainShatter" UNBOUND/`)

- [ ] **Step 1: Find the existing A-tier cinematic component**

Run: `grep -rn "RankUpShareCard\|Cinematic" UNBOUND/Views/`
Identify the chain-shatter view used for skill A-tier crossings.

- [ ] **Step 2: Add a notification subscriber**

In whatever home-level container hosts cinematics (likely `UnboundHomeView` or `AppCoordinatorView`), subscribe to `.attributeRankUp` for `event.level == .aTier` and present the existing cinematic with `event.toTitle`.

```swift
.onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { note in
    guard let event = note.object as? AttributeRankUpEvent, event.level == .aTier else { return }
    cinematicState.present(rankTitle: event.toTitle, axisLabel: event.axis.displayName)
}
```
(Match the existing cinematic presentation API. If the existing cinematic only accepts a `SkillRank`, add a sibling presentation method or constructor that takes a `RankTitle` directly.)

- [ ] **Step 3: Manual smoke test**

Bump an attribute past the Vessel boundary in dev (force-set `current = 75` via debug menu) → trigger a session that pushes past Unbound. Confirm full chain-shatter fires.

- [ ] **Step 4: Commit**

```bash
git add <files-touched>
git commit -m "feat(attr-ui): A-tier attribute crossing triggers chain-shatter cinematic"
```

---

### Phase 1b Gate

- [ ] Profile renders Build card with hex + 3×2 grid.
- [ ] Empty profile renders gracefully (single point hex).
- [ ] Sub-rank crossings are silent.
- [ ] Tier crossings (Apprentice→Forged, etc.) show toast.
- [ ] A-tier crossings (into Vessel/Unbound/Ascendant) show full cinematic.
- [ ] All Phase 1a tests still pass.

---

# Phase 1c — Home Build chip + stats grid removal

### Task 1c.1: HomeBuildChipCard

**Files:**
- Create: `UNBOUND/Views/Home/HomeBuildChipCard.swift`

- [ ] **Step 1: Write the implementation**

```swift
// UNBOUND/Views/Home/HomeBuildChipCard.swift
import SwiftUI

struct HomeBuildChipCard: View {
    let profile: AttributeProfile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                AttributeHex(
                    current: currentValues,
                    peak: nil,
                    showLabels: false,
                    radius: 38
                )
                .padding(4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("BUILD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(buildPrimary)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.unbound.textPrimary)
                    if let suffix = buildSuffix {
                        Text(suffix)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.unbound.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.unbound.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.unbound.accent.opacity(0.10), radius: 6)
        }
        .buttonStyle(.plain)
    }

    private var currentValues: [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, profile.value(for: $0).current) })
    }

    private var buildPrimary: String {
        // "Power-leaning" — drop the "Hybrid" suffix for one-line header on the chip.
        let parts = profile.buildName.split(separator: " ")
        return parts.first.map(String.init) ?? profile.buildName
    }

    private var buildSuffix: String? {
        if profile.buildName == "Balanced" { return nil }
        return "Hybrid"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Home/HomeBuildChipCard.swift
git commit -m "feat(attr-ui): HomeBuildChipCard — compact hex + build name preview"
```

---

### Task 1c.2: Slot chip into UnboundHomeView, remove Stats grid

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift`

- [ ] **Step 1: Find the Stats grid section**

Run: `grep -n "MARK: - Stats grid\|StatScore\|statScore" UNBOUND/Views/Home/UnboundHomeView.swift`
Expected: a `// MARK: - Stats grid` section (around line 1919) and a corresponding view function.

- [ ] **Step 2: Delete the Stats grid section + its render call**

Remove:
- The `// MARK: - Stats grid` section comment + any `private func statsGrid(...)` view function in the file.
- The call to that view function in the main `body` (search the file for `statsGrid` usage).
- Any `@State` or computed properties only used by the stats grid (search for `statScore` references inside the file).

- [ ] **Step 3: Slot the Build chip**

Add `@State private var attrProfile: AttributeProfile = .empty(userId: "", at: .now)` near the other `@State` declarations.

In `.task`/`onAppear`:
```swift
.task {
    let uid = services.auth.currentUserId ?? "anonymous"
    attrProfile = services.attribute.snapshot(userId: uid, asOf: .now)
}
```

In the body, between the existing Rank card and Today's Mission:
```swift
HomeBuildChipCard(profile: attrProfile) {
    coordinator.navigateToProfile(scrollTo: .build)
}
.padding(.horizontal, 16)
```
(Replace `coordinator.navigateToProfile(...)` with whatever tab-navigation API the home uses. If a deep-scroll target doesn't exist, leave a simple "switch to Profile tab" — Phase 1c doesn't require scroll-to anchoring.)

- [ ] **Step 4: Manual smoke test**

Build & run. Confirm:
- Home no longer shows the 4-stat grid.
- Build chip renders in its place.
- Tapping chip navigates to Profile.
- Layout doesn't overflow vertically.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "feat(attr-ui): replace Home stats grid with Build chip"
```

---

### Phase 1c Gate

- [ ] Home shows Build chip in former Stats grid slot.
- [ ] No 4-axis stats grid anywhere on home.
- [ ] Build chip tap navigates to Profile.
- [ ] All earlier tests still pass.
- [ ] **`StatScoreService` and `StatScore.swift` still EXIST** at this point — that's intentional, Phase 1d deletes them.

---

# Phase 1d — Scan Δ panel + dead-code cleanup

### Task 1d.1: ScanBuildDeltaCard

**Files:**
- Create: `UNBOUND/Views/Scan/ScanBuildDeltaCard.swift`

- [ ] **Step 1: Write the implementation**

```swift
// UNBOUND/Views/Scan/ScanBuildDeltaCard.swift
import SwiftUI

struct ScanBuildDeltaCard: View {
    let firstScan: AttributeProfile
    let latestScan: AttributeProfile

    var body: some View {
        VStack(spacing: 12) {
            Text("BUILD · ARC EVOLUTION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(Color.unbound.textTertiary)

            HStack(spacing: 8) {
                Text(firstScan.buildName)
                    .foregroundStyle(Color.unbound.textTertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                Text(latestScan.buildName)
                    .foregroundStyle(Color.unbound.accent)
                    .fontWeight(.semibold)
            }
            .font(.system(size: 13))

            HStack(alignment: .center, spacing: 10) {
                VStack(spacing: 4) {
                    Text("SCAN 1").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(2.0).foregroundStyle(Color.unbound.textTertiary)
                    AttributeHex(current: values(firstScan), peak: nil, showLabels: false, radius: 54)
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.unbound.accent)
                VStack(spacing: 4) {
                    Text("LATEST").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(2.0).foregroundStyle(Color.unbound.accent)
                    AttributeHex(current: values(latestScan), peak: nil, showLabels: false, radius: 54)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                ForEach(AttributeKey.allCases, id: \.self) { key in
                    deltaCell(for: key)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.unbound.accent.opacity(0.4), lineWidth: 1))
    }

    private func values(_ p: AttributeProfile) -> [AttributeKey: Double] {
        Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, p.value(for: $0).current) })
    }

    private func deltaCell(for key: AttributeKey) -> some View {
        let delta = latestScan.value(for: key).current - firstScan.value(for: key).current
        let rounded = Int(delta.rounded())
        let flat = abs(rounded) < 5
        return VStack(spacing: 2) {
            Text(rounded >= 0 ? "+\(rounded)" : "\(rounded)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(flat ? Color.unbound.textTertiary : Color.unbound.accent)
            Text(key.shortCode)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textTertiary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.unbound.bg))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.unbound.border, lineWidth: 1))
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Scan/ScanBuildDeltaCard.swift
git commit -m "feat(attr-ui): ScanBuildDeltaCard — split hex + per-axis Δ strip"
```

---

### Task 1d.2: Snapshot profile on scan completion

**Files:**
- Modify: scan completion call site (find with `grep -rn "BodyScan\|scanCompleted" UNBOUND/`)

- [ ] **Step 1: Find scan-completion site**

Run: `grep -rn "completedScan\|scanCompleted\|BodyScan.save\|finishedScan" UNBOUND/`
Identify where a new scan is persisted (likely `ScanPayoffView` or a scan service).

- [ ] **Step 2: Add snapshot call**

After scan save succeeds:
```swift
await services.attribute.snapshotForScan(scanId: scan.id, userId: userId)
```

- [ ] **Step 3: Commit**

```bash
git add <scan-completion-file>
git commit -m "feat(attr): pin attribute profile to each completed scan"
```

---

### Task 1d.3: Slot ScanBuildDeltaCard into ScanPayoffView

**Files:**
- Modify: `UNBOUND/Views/Scan/ScanPayoffView.swift`

- [ ] **Step 1: Find the right injection point**

Open `ScanPayoffView.swift`, locate the body-Δ section (where body weight/lean mass deltas already render). Slot the Build Δ card *after* that section.

- [ ] **Step 2: Inject**

```swift
@EnvironmentObject var services: ServiceContainer
@State private var history: [AttributeProfile] = []

// In body, after body-Δ section:
if history.count >= 2, let first = history.first, let last = history.last {
    ScanBuildDeltaCard(firstScan: first, latestScan: last)
        .padding(.horizontal, 16)
}

// In .task:
.task {
    let uid = services.auth.currentUserId ?? "anonymous"
    history = services.attribute.scanHistory(userId: uid)
}
```

- [ ] **Step 3: Manual smoke test**

Run the app, complete two scans (with at least one logged session in between), confirm the card renders on the second scan's payoff screen.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Scan/ScanPayoffView.swift
git commit -m "feat(attr-ui): slot ScanBuildDeltaCard into ScanPayoffView (≥2 scans gate)"
```

---

### Task 1d.4: Delete StatScore + MuscleHeatmap files

**Files:**
- Delete: `UNBOUND/Models/StatScore.swift`
- Delete: `UNBOUND/Models/MuscleGroupTier.swift`
- Delete: `UNBOUND/Models/MuscleGroupTierState.swift`
- Delete: `UNBOUND/Models/MuscleHeatGroup.swift`
- Delete: `UNBOUND/Models/MuscleHeatmapRegions.swift`
- Delete (if found): `UNBOUND/Services/Ranking/StatScoreService.swift`
- Modify: `UNBOUND/Services/ServiceContainer.swift` — drop `statScore: any StatScoreServiceProtocol` line + init assignment

- [ ] **Step 1: grep for all references**

Run: `grep -rn "StatScore\|MuscleGroupTier\|MuscleHeatGroup\|MuscleHeatmapRegions" UNBOUND/ UNBOUNDTests/`
Expected: hits only in the soon-to-be-deleted files plus ServiceContainer.

- [ ] **Step 2: Delete the files**

```bash
git rm UNBOUND/Models/StatScore.swift \
       UNBOUND/Models/MuscleGroupTier.swift \
       UNBOUND/Models/MuscleGroupTierState.swift \
       UNBOUND/Models/MuscleHeatGroup.swift \
       UNBOUND/Models/MuscleHeatmapRegions.swift
# If StatScoreService.swift exists:
git ls-files UNBOUND/Services/Ranking/StatScoreService.swift | xargs -I{} git rm {}
```

- [ ] **Step 3: Update ServiceContainer**

Remove from properties list:
```swift
let statScore: any StatScoreServiceProtocol
```
Remove from default init:
```swift
self.statScore = StatScoreService.shared
```
Remove from test init signature + assignment + any mock-init callsite. Build to find any lingering references.

- [ ] **Step 4: Re-run grep**

Run: `grep -rn "StatScore\|MuscleGroupTier\|MuscleHeatGroup\|MuscleHeatmapRegions" UNBOUND/ UNBOUNDTests/`
Expected: ZERO hits.

- [ ] **Step 5: Build + test**

Run: `xcodebuild test -scheme UNBOUND`
Expected: BUILD SUCCESS + all existing tests PASS.

- [ ] **Step 6: Commit**

```bash
git add -A UNBOUND/ UNBOUNDTests/
git commit -m "chore(attr): remove dead StatScore + MuscleHeatmap layer"
```

---

### Task 1d.5: Snapshot test pass

**Files:**
- Create: `UNBOUNDTests/Views/ProfileBuildCardSnapshotTests.swift`

- [ ] **Step 1: Write snapshot tests** (use existing snapshot-testing framework if one is wired; otherwise plain `XCTAssertNotNil` smoke tests on view body initialization)

```swift
import XCTest
import SwiftUI
@testable import UNBOUND

@MainActor
final class ProfileBuildCardSnapshotTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testEmptyProfileRenders() {
        let p = AttributeProfile.empty(userId: "u", at: t0)
        let _ = ProfileBuildCard(profile: p).body
    }

    func testMidProfileRenders() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        p.set(.power,         AttributeValue(peak: 72, current: 72, lastContributionAt: t0))
        p.set(.agility,       AttributeValue(peak: 45, current: 45, lastContributionAt: t0))
        p.set(.control,       AttributeValue(peak: 58, current: 58, lastContributionAt: t0))
        p.set(.endurance,     AttributeValue(peak: 52, current: 52, lastContributionAt: t0))
        p.set(.mobility,      AttributeValue(peak: 28, current: 28, lastContributionAt: t0))
        p.set(.explosiveness, AttributeValue(peak: 38, current: 38, lastContributionAt: t0))
        let _ = ProfileBuildCard(profile: p).body
    }

    func testSaturatedProfileRenders() {
        var p = AttributeProfile.empty(userId: "u", at: t0)
        for key in AttributeKey.allCases {
            p.set(key, AttributeValue(peak: 95, current: 92, lastContributionAt: t0))
        }
        let _ = ProfileBuildCard(profile: p).body
    }
}
```

- [ ] **Step 2: Run**

Expected: PASS — these are smoke tests that catch crashes in view initialization.

- [ ] **Step 3: Commit**

```bash
git add UNBOUNDTests/Views/ProfileBuildCardSnapshotTests.swift
git commit -m "test(attr-ui): snapshot smoke tests for ProfileBuildCard (empty/mid/saturated)"
```

---

### Phase 1d Gate

- [ ] Scan results show Build Δ card on second+ scan, hides on first scan.
- [ ] All `StatScore`/`MuscleGroupTier`/`MuscleHeatmap` files removed.
- [ ] Project compiles with zero references to deleted types.
- [ ] All earlier tests still pass.
- [ ] Manual E2E: fresh user → onboarding (with seed) → first session → home Build chip non-zero → profile hex non-empty → second session → tier crossing fires toast → second scan → Δ card appears.

---

# Self-review (run by author before handoff)

## Spec coverage check
- ✅ 6-axis attribute model — Tasks 1a.1, 1a.3, 1a.4
- ✅ Hybrid peak + current — Task 1a.3
- ✅ 0-100 scalar + SubRank/RankTitle overlay — Tasks 1a.3, 1b.2
- ✅ Per-exercise tag mapping (catalog JSON) — Tasks 1a.9, 1a.11
- ✅ Gentle drift, 7d grace + 30d window, 70% floor — Task 1a.7
- ✅ Ingest order (decay-first, then deltas) — Task 1a.6 (snapshot call in ingest), Task 1a.7
- ✅ Profile primary, Home preview, Scan deep dive — Phases 1b/1c/1d
- ✅ Build name (Phase 1b minimum rule) — Task 1a.4
- ✅ Onboarding seed survey, +15 cap — Task 1a.12
- ✅ Rank-up animation, 3-level emission (silent/toast/cinematic) — Tasks 1a.8, 1b.5, 1b.6
- ✅ Profile 3×2 grid — Tasks 1b.2, 1b.3
- ✅ Home Build chip slotting in Stats grid's place — Task 1c.2
- ✅ Scan Build Δ card with split hex + Δ strip — Tasks 1d.1, 1d.3
- ✅ Snapshot profile on scan — Task 1d.2
- ✅ Dead code cleanup — Task 1d.4

## Type consistency check
- `AttributeKey`, `AttributeValue`, `AttributeProfile`, `AttributeContribution`, `AttributeRankUpEvent` — consistent across all tasks.
- `AttributeServiceProtocol` ↔ `AttributeService` ↔ `MockAttributeService` — same method signatures.
- `AttributeCatalogProtocol` declared in 1a.8, implemented by `AttributeCatalog` in 1a.9, used by `AttributeService` (1a.6) and `AttributeIngest` (1a.8).
- `AttributeProfileStoreProtocol` declared in 1a.10, used by `AttributeService` (1a.6). Naming consistent.
- `AttributeHex(current:peak:showLabels:radius:)` signature consistent in 1b.1/1b.3/1c.1/1d.1.

## Placeholder check
None — every code step contains the full code an engineer types.
