# Binding Vows v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the toothless Ember/Overdrive/Apex weekly-vow model with a weekly self-directed *bet*: a curated-bank-pool card you bind for the week, a real XP stake that is **withheld from your next earned training XP** (never de-levels you), a token win, and a lean theme-true reward (Vows badge track + Vow Sigil + lane seals).

**Architecture:** The work is staged into five independently-green phases. Phase 1 lands the one true mechanical change (garnish debt) without touching the card model. Phase 2 swaps the card model from `WeeklyVowKind`/`WeeklyVowTheme` to `VowLane`/`VowBet`/`VowTarget`. Phase 3 replaces per-profile generation with a curated bank-pool draw. Phase 4 replaces routed-training completion with log-based auto-detection (Recovery/Engine) plus a vow-scoped Fuel self-report. Phase 5 swaps the reward economics, adds the Vows badge track + Vow Sigil + lane seals, and tears down the title ladder / cosmetic-every-5 / coin drip.

**Tech Stack:** Swift 5.9 / SwiftUI, XCTest, UserDefaults-backed stores, `@MainActor` services. Build/test via `xcodebuild` on an iPhone 17-class simulator (see Verification below).

**Source of truth:** `docs/superpowers/specs/2026-06-15-binding-vows-v2-design.md`. Section references (`§5`, `§7`, …) point there.

**Scope boundary — do NOT touch the Rank Trials system.** Two unrelated systems share the word "trial". This plan only touches **Weekly / Binding Vows**: `UNBOUND/Services/Trials/`, `UNBOUND/Models/Trial{Card,CardKind,Theme,sState}.swift`, `UNBOUND/Views/Trials/`, the `WeeklyVow*` types in `UNBOUND/Models/WorkoutRewardSequence.swift`, and the garnish hook in `OverallLevelService`. Leave `UNBOUND/Views/Program/RankTrials/`, `UNBOUND/Services/Ranking/OverallRankTrial*`, `UNBOUND/Models/Trial.swift`, `UNBOUND/Models/Standards/Gates/TrialStandards.swift`, and `RankTrialRewardCallout` alone.

**Seed-vs-final (per spec §13).** This plan implements the *engine and mechanics* in full. Genuinely deferred items get a concrete, functional interim so every task is testable, with final work flagged inline:
- **Bank-pool content** — a concrete *starter* pool (3 lanes × 3 bets = 9 authored cards) ships in Phase 3. It is "trivially expandable" (spec §6); the larger content pass is out of plan.
- **Vow Sigil + lane seal art** — Phase 5 builds the data model, segment-sealing, fracture/self-heal, and a *functional vector rendering* using existing tokens/SF Symbols. Final illustrated art is a separate content task (respect [[banner-art-is-anime-jrpg]] and [[every-design-color-checked]] — do NOT generate final art in this plan).
- **Badge milestone numbers** — use spec §8's examples (5 / 15 / 30 / 52); they are tunable constants.

---

## Conventions for every task

- **TDD.** Write the failing test first, watch it fail, implement minimally, watch it pass, commit.
- **Build/test command (single source — never two `xcodebuild` at once, never pipe to `tail`):**
  ```bash
  set -o pipefail
  xcodebuild test \
    -scheme UNBOUND \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath /private/tmp/unbound-dd-vows \
    CODE_SIGNING_ALLOWED=NO \
    -only-testing:UNBOUNDTests/<Suite> 2>&1 | grep -E "Test Suite .* (passed|failed)|error:|BUILD (SUCCEEDED|FAILED)"
  ```
  SourceKit "Cannot find type"/"No such module" diagnostics are stale-index noise — trust `xcodebuild`.
- **Device gate at each phase end:**
  ```bash
  set -o pipefail
  xcodebuild build -scheme UNBOUND -destination 'generic/platform=iOS' \
    -derivedDataPath /private/tmp/unbound-dd-vows CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
  ```
- **Git hygiene (shared tree — concurrent Codex/jlin edits):** stage explicit paths only, never `git add -A`. Each task commits exactly the files it touched.
- **xcodegen:** This project's `project.xcodeproj` is generated and gitignored. After **adding or deleting a `.swift` file**, run `xcodegen generate` before building. (`project.yml` pins `DEVELOPMENT_TEAM=6K5R25Y398` and HotReloading `weak: true` — do not let xcodegen wipe these.)

---

# Phase 1 — Garnish debt engine (the one true mechanical change)

**Phase goal (spec §5):** Breaking a vow stores XP debt that is **withheld from the user's next *earned training* XP** — `applied = max(0, earned − debt)` — and **never decreases total XP or de-levels**. Vow *wins* still pay out in full (debt is cleared only by earned training XP, not by completing vows). This phase keeps the existing Ember/Overdrive/Apex card model and its current amounts; only the *mechanism* changes.

## Task 1.1: Add `pendingVowDebtXP` to state, migrate the legacy penalty field

**Files:**
- Modify: `UNBOUND/Models/TrialsState.swift`
- Test: `UNBOUNDTests/Services/TrialsStoreTests.swift` (suite `WeeklyVowsStoreTests`)

- [ ] **Step 1: Write the failing test**

Add to `UNBOUNDTests/Services/TrialsStoreTests.swift`:

```swift
func testDecodesLegacyPendingPenaltyAsDebt() throws {
    // A v1 state blob carried `pendingVowPenaltyXP`. v2 must surface that owed
    // amount as collectible debt under `pendingVowDebtXP`.
    let legacyJSON = """
    {"currentWeekCards":[],"completionsByAxis":{},"completionsByCardKind":{},
     "unlockedTitles":[],"skippedCurrentWeek":false,"weeklyVowCompletionLedger":[],
     "weeklyVowPenaltyLedger":[],"pendingVowPenaltyXP":120}
    """.data(using: .utf8)!
    let state = try JSONDecoder().decode(WeeklyVowsState.self, from: legacyJSON)
    XCTAssertEqual(state.pendingVowDebtXP, 120)
}

func testDebtSurvivesEncodeRoundTrip() throws {
    var state = WeeklyVowsState.empty
    state.pendingVowDebtXP = 250
    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(WeeklyVowsState.self, from: data)
    XCTAssertEqual(decoded.pendingVowDebtXP, 250)
}
```

- [ ] **Step 2: Run the tests, verify they fail**

Run the test command with `-only-testing:UNBOUNDTests/WeeklyVowsStoreTests`.
Expected: FAIL — `pendingVowDebtXP` is not a member of `WeeklyVowsState`.

- [ ] **Step 3: Implement — add the field and migration in `TrialsState.swift`**

In the `WeeklyVowsState` struct, **replace** the stored property `var pendingVowPenaltyXP: Int` (line ~45) with:

```swift
    /// Outstanding XP debt from broken vows. Withheld from the user's next
    /// earned training XP (never subtracts existing total, never de-levels).
    var pendingVowDebtXP: Int
```

In `static let empty`, replace `pendingVowPenaltyXP: 0` with `pendingVowDebtXP: 0`.

In `init(...)`, replace the `pendingVowPenaltyXP` parameter and assignment:
- parameter: `pendingVowDebtXP: Int = 0`
- assignment: `self.pendingVowDebtXP = max(0, pendingVowDebtXP)`

In `CodingKeys`, replace `case pendingVowPenaltyXP` with:
```swift
        case pendingVowDebtXP
        case pendingVowPenaltyXP   // legacy v1 key, decode-only for migration
```

In `init(from:)`, replace the `pendingVowPenaltyXP` decode line with:
```swift
        pendingVowDebtXP = try container.decodeIfPresent(Int.self, forKey: .pendingVowDebtXP)
            ?? container.decodeIfPresent(Int.self, forKey: .pendingVowPenaltyXP)
            ?? 0
```

(The synthesized `encode(to:)` is not overridden here, so encoding now writes `pendingVowDebtXP` and never re-emits the legacy key — confirm there is no custom `encode(to:)` in this file; there is not.)

- [ ] **Step 4: Run the tests, verify they pass**

Expected: PASS. The compiler will now flag every reader of `pendingVowPenaltyXP` — those are fixed in Tasks 1.3–1.4; leave them for now if the suite under test still builds. If `WeeklyVowsStoreTests` won't build because another file references the removed field, temporarily keep a computed shim at the bottom of `TrialsState.swift`:
```swift
extension WeeklyVowsState {
    /// Temporary Phase-1 shim. Removed at end of Task 1.4.
    var pendingVowPenaltyXP: Int {
        get { pendingVowDebtXP }
        set { pendingVowDebtXP = max(0, newValue) }
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/TrialsState.swift UNBOUNDTests/Services/TrialsStoreTests.swift
git commit -m "feat(vows): add pendingVowDebtXP with legacy penalty migration"
```

## Task 1.2: `VowDebtLedger` — the consume-debt abstraction

**Files:**
- Create: `UNBOUND/Services/Trials/VowDebtLedger.swift`
- Test: `UNBOUNDTests/Services/VowDebtLedgerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Services/VowDebtLedgerTests.swift`:

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class VowDebtLedgerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: WeeklyVowsStore!
    private var ledger: LiveVowDebtLedger!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "vow-debt-\(UUID().uuidString)")
        store = WeeklyVowsStore(defaults: defaults)
        ledger = LiveVowDebtLedger(store: store)
    }

    func testOutstandingDebtReadsState() {
        var state = store.load(userId: "u")
        state.pendingVowDebtXP = 300
        store.save(state, userId: "u")
        XCTAssertEqual(ledger.outstandingDebtXP(userId: "u"), 300)
    }

    func testConsumePartialLeavesRemainder() {
        var state = store.load(userId: "u")
        state.pendingVowDebtXP = 300
        store.save(state, userId: "u")
        let consumed = ledger.consumeDebt(upTo: 120, userId: "u")
        XCTAssertEqual(consumed, 120)
        XCTAssertEqual(store.load(userId: "u").pendingVowDebtXP, 180)
    }

    func testConsumeNeverExceedsOutstanding() {
        var state = store.load(userId: "u")
        state.pendingVowDebtXP = 80
        store.save(state, userId: "u")
        let consumed = ledger.consumeDebt(upTo: 500, userId: "u")
        XCTAssertEqual(consumed, 80)
        XCTAssertEqual(store.load(userId: "u").pendingVowDebtXP, 0)
    }

    func testConsumeZeroWhenNoDebt() {
        XCTAssertEqual(ledger.consumeDebt(upTo: 200, userId: "u"), 0)
    }
}
```

- [ ] **Step 2: Run, verify it fails**

`-only-testing:UNBOUNDTests/VowDebtLedgerTests` → FAIL: `LiveVowDebtLedger` undefined.

- [ ] **Step 3: Implement `VowDebtLedger.swift`**

```swift
// UNBOUND/Services/Trials/VowDebtLedger.swift
import Foundation

/// Reads and pays down a user's broken-vow XP debt. Consulted by
/// OverallLevelService when crediting earned training XP (spec §5).
@MainActor
protocol VowDebtLedger: AnyObject {
    func outstandingDebtXP(userId: String) -> Int
    /// Consume up to `amount` of outstanding debt; returns the amount actually
    /// consumed (clamped to outstanding) and persists the reduced debt.
    @discardableResult
    func consumeDebt(upTo amount: Int, userId: String) -> Int
}

@MainActor
final class LiveVowDebtLedger: VowDebtLedger {
    private let store: WeeklyVowsStore

    init(store: WeeklyVowsStore = .shared) {
        self.store = store
    }

    func outstandingDebtXP(userId: String) -> Int {
        max(0, store.load(userId: userId).pendingVowDebtXP)
    }

    @discardableResult
    func consumeDebt(upTo amount: Int, userId: String) -> Int {
        guard amount > 0 else { return 0 }
        var state = store.load(userId: userId)
        let consumed = min(max(0, state.pendingVowDebtXP), amount)
        guard consumed > 0 else { return 0 }
        state.pendingVowDebtXP = max(0, state.pendingVowDebtXP - consumed)
        store.save(state, userId: userId)
        return consumed
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass**

```bash
xcodegen generate
```
Then run `-only-testing:UNBOUNDTests/VowDebtLedgerTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/Trials/VowDebtLedger.swift UNBOUNDTests/Services/VowDebtLedgerTests.swift
git commit -m "feat(vows): add VowDebtLedger consume-debt abstraction"
```

## Task 1.3: Wire garnish into `OverallLevelService.ingest`

**Files:**
- Modify: `UNBOUND/Models/OverallLevelProgress.swift` (`OverallLevelReward` — add field)
- Modify: `UNBOUND/Services/Progression/OverallLevelService.swift`
- Test: `UNBOUNDTests/Services/OverallLevelServiceTests.swift` (create if absent)

Garnish applies to the **`ingest` (earned training XP) path only** — not `grantFlatXP` (vow wins still pay out, spec §5/§10).

- [ ] **Step 1: Write the failing test**

Create/append `UNBOUNDTests/Services/OverallLevelServiceTests.swift`:

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class OverallLevelServiceGarnishTests: XCTestCase {
    /// Stub ledger so the test doesn't depend on real vow state.
    final class StubLedger: VowDebtLedger {
        var outstanding: Int
        private(set) var consumedCalls: [Int] = []
        init(outstanding: Int) { self.outstanding = outstanding }
        func outstandingDebtXP(userId: String) -> Int { outstanding }
        func consumeDebt(upTo amount: Int, userId: String) -> Int {
            let c = min(outstanding, max(0, amount))
            outstanding -= c
            consumedCalls.append(c)
            return c
        }
    }

    func testEarnedTrainingXPIsWithheldAgainstDebt() async {
        let service = OverallLevelService.makeForTesting()
        let ledger = StubLedger(outstanding: 1_000_000) // swallow everything
        service.vowDebtLedger = ledger

        let reward = await service.ingest(
            rawAP: 500,
            noveltyMultiplier: 1.0,
            sourceLogId: "log-garnish-1",
            userId: "u-garnish",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            database: InMemoryDatabaseService()
        )

        XCTAssertEqual(reward.xpGained, 0, "bar must not move while debt swallows the earnings")
        XCTAssertEqual(reward.currentXP, reward.previousXP, "total XP never decreases")
        XCTAssertGreaterThan(reward.xpWithheldToVowDebt, 0)
        XCTAssertEqual(ledger.consumedCalls.count, 1)
    }

    func testNoDebtMeansFullCredit() async {
        let service = OverallLevelService.makeForTesting()
        service.vowDebtLedger = StubLedger(outstanding: 0)
        let reward = await service.ingest(
            rawAP: 500, noveltyMultiplier: 1.0, sourceLogId: "log-garnish-2",
            userId: "u-garnish-2", at: Date(timeIntervalSince1970: 1_700_000_000),
            database: InMemoryDatabaseService()
        )
        XCTAssertGreaterThan(reward.xpGained, 0)
        XCTAssertEqual(reward.xpWithheldToVowDebt, 0)
    }
}
```

> **Executor note:** Confirm the in-memory database test double's exact type name (`InMemoryDatabaseService` or similar) by reading an existing progression test (e.g. `grep -rln "DatabaseServiceProtocol" UNBOUNDTests`). Use whatever double the existing `OverallLevelService` tests use. If `OverallLevelService` has no `makeForTesting()` or settable `vowDebtLedger` yet, that is added in Step 3.

- [ ] **Step 2: Run, verify it fails**

`-only-testing:UNBOUNDTests/OverallLevelServiceGarnishTests` → FAIL: `xpWithheldToVowDebt` / `vowDebtLedger` / `makeForTesting` undefined.

- [ ] **Step 3: Implement**

(a) In `UNBOUND/Models/OverallLevelProgress.swift`, add a defaulted field to `OverallLevelReward` (keeps the synthesized memberwise init backward-compatible):

```swift
struct OverallLevelReward: Codable, Hashable, Sendable {
    var xpGained: Double
    var noveltyMultiplier: Double
    var previousXP: Double
    var currentXP: Double
    var previousLevel: Int
    var currentLevel: Int
    var previousProgressToNextLevel: Double
    var currentProgressToNextLevel: Double
    /// Earned XP siphoned to pay down broken-vow debt this event (spec §5).
    var xpWithheldToVowDebt: Double = 0
    ...
}
```

(b) In `UNBOUND/Services/Progression/OverallLevelService.swift`:

Add a settable ledger + a test factory near the top of the class:
```swift
    /// Consulted to garnish earned training XP against broken-vow debt (spec §5).
    var vowDebtLedger: VowDebtLedger = LiveVowDebtLedger()

    #if DEBUG
    static func makeForTesting() -> OverallLevelService { OverallLevelService() }
    #endif
```
(`init()` is `private`; `makeForTesting` lives inside the class so it can call it.)

In the private `ingest(...)` method, locate:
```swift
        let xpGained = RewardLedgerQuantizer.wholePoints(
            from: effectiveAP * max(1.0, noveltyMultiplier) * comeback
        ) + bolus
        progress.apply(xpGained: xpGained, sourceLogId: sourceLogId, at: date)
```
Replace with:
```swift
        let earnedXP = RewardLedgerQuantizer.wholePoints(
            from: effectiveAP * max(1.0, noveltyMultiplier) * comeback
        ) + bolus
        // Spec §5: broken-vow debt is paid out of earned training XP before it
        // reaches the bar. Total XP never decreases; the bar simply pauses.
        let withheld = vowDebtLedger.consumeDebt(upTo: earnedXP, userId: userId)
        let xpGained = max(0, earnedXP - withheld)
        progress.apply(xpGained: xpGained, sourceLogId: sourceLogId, at: date)
```

In the `OverallLevelReward(...)` constructed right after, add the field:
```swift
            previousProgressToNextLevel: previousProgress,
            currentProgressToNextLevel: progress.progressToNextLevel,
            xpWithheldToVowDebt: Double(withheld)
```

> Leave `grantFlatXP` untouched — vow wins are not garnished.

- [ ] **Step 4: Run tests, verify pass**

`-only-testing:UNBOUNDTests/OverallLevelServiceGarnishTests` → PASS. Also re-run the existing progression suite to confirm the new defaulted field broke nothing.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/OverallLevelProgress.swift UNBOUND/Services/Progression/OverallLevelService.swift UNBOUNDTests/Services/OverallLevelServiceTests.swift
git commit -m "feat(vows): garnish earned training XP against vow debt"
```

## Task 1.4: Broken vow writes debt; completion stops paying debt

**Files:**
- Modify: `UNBOUND/Services/Trials/WeeklyVowRewards.swift`
- Modify: `UNBOUND/Services/Trials/TrialsService.swift`
- Modify: `UNBOUND/Models/TrialsState.swift` (remove the Task 1.1 shim)
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift` (suite `WeeklyVowsServiceTests`)

- [ ] **Step 1: Write the failing test**

Add to `UNBOUNDTests/Services/TrialsServiceTests.swift`:

```swift
func testBrokenVowAddsDebtNotNextVowPenalty() {
    // Pick a vow, then roll the week without completing → debt accrues.
    let card = makeAxisCard(kind: .apex, axis: .power)
    var state = service.state(userId: "u-1")
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    state.currentWeekCards = [card]
    store.save(state, userId: "u-1")
    service.pickVowCard(card, userId: "u-1")

    // Force a stale week so ensureCurrentWeek rolls + marks missed.
    var picked = service.state(userId: "u-1")
    picked.currentWeekStart = Date(timeIntervalSince1970: 1) // ancient
    store.save(picked, userId: "u-1")

    let exp = expectation(description: "rolled")
    Task { await service.ensureCurrentWeek(userId: "u-1"); exp.fulfill() }
    wait(for: [exp], timeout: 5)

    XCTAssertEqual(
        service.state(userId: "u-1").pendingVowDebtXP,
        card.kind.missedPenaltyOverallLevelXP
    )
}
```

- [ ] **Step 2: Run, verify it fails**

`-only-testing:UNBOUNDTests/WeeklyVowsServiceTests/testBrokenVowAddsDebtNotNextVowPenalty` → FAIL (or won't build, because `pendingVowPenaltyXP` references still exist).

- [ ] **Step 3: Implement — point the miss path at debt, stop deducting on win**

In `UNBOUND/Services/Trials/WeeklyVowRewards.swift`, rewrite `WeeklyVowPenaltyCatalog` to write debt:
```swift
enum WeeklyVowPenaltyCatalog {
    private static let maxLedgerEntries = 100

    static func applyMissedPenaltyIfNeeded(
        for vow: WeeklyVow,
        missedAt: Date,
        state: inout WeeklyVowsState
    ) {
        guard vow.capstoneState != .completed, vow.capstoneState != .missed else { return }
        guard !state.weeklyVowPenaltyLedger.contains(where: { $0.vowId == vow.id && $0.weekStart == vow.weekStart }) else { return }

        let owedXP = vow.chosenCard.kind.missedPenaltyOverallLevelXP
        guard owedXP > 0 else { return }

        state.weeklyVowPenaltyLedger.append(
            WeeklyVowPenaltyLedgerEntry(
                vowId: vow.id,
                cardKind: vow.chosenCard.kind,
                weekStart: vow.weekStart,
                missedAt: missedAt,
                penaltyXP: owedXP
            )
        )
        if state.weeklyVowPenaltyLedger.count > maxLedgerEntries {
            state.weeklyVowPenaltyLedger.removeFirst(state.weeklyVowPenaltyLedger.count - maxLedgerEntries)
        }
        // Spec §5: a broken vow becomes collectible debt, withheld from future
        // earned training XP — not a deduction from the next vow win.
        state.pendingVowDebtXP = max(0, state.pendingVowDebtXP + owedXP)
    }
}
```
Delete the `remainingPenaltyXP(afterApplying:to:)` function (no longer used).

In `WeeklyVowCompletionBonusCatalog.bonus(...)`, the win no longer deducts pending debt. Replace the penalty-applied computation:
```swift
        let kind = vow.chosenCard.kind
        let awardedOverallLevelXP = kind.completionBonusOverallLevelXP
```
…and in the returned `WeeklyVowCompletionBonus`, set:
```swift
            baseOverallLevelXP: nil,
            penaltyAppliedXP: nil
```
Remove the now-unused `pendingPenaltyXP` parameter from `bonus(...)` and the local `penaltyAppliedXP`/`baseOverallLevelXP` logic.

In `UNBOUND/Services/Trials/TrialsService.swift`:
- In `recordCompletedVowWork`, update the `bonus` call to drop the `pendingPenaltyXP:` argument:
  ```swift
        let bonus = WeeklyVowCompletionBonusCatalog.bonus(
            for: vow,
            performanceLog: performanceLog,
            completionCountAfter: completionCountAfter
        )
  ```
- In `sealCompletedVow`, delete the block that recomputes pending penalty:
  ```swift
        state.pendingVowPenaltyXP = WeeklyVowPenaltyCatalog.remainingPenaltyXP(
            afterApplying: ledgerEntry.bonus.penaltyAppliedXP ?? 0,
            to: state.pendingVowPenaltyXP
        )
  ```
  (Remove entirely — debt is cleared only by earned training XP.)

In `UNBOUND/Models/TrialsState.swift`, delete the temporary `pendingVowPenaltyXP` computed shim from Task 1.1.

- [ ] **Step 4: Run, verify pass**

Run `-only-testing:UNBOUNDTests/WeeklyVowsServiceTests` and `-only-testing:UNBOUNDTests/WeeklyVowsStoreTests` → PASS. Grep to confirm zero remaining references:
```bash
grep -rn "pendingVowPenaltyXP\|remainingPenaltyXP" UNBOUND UNBOUNDTests --include="*.swift"
```
Expected: only the legacy decode-only `CodingKeys` case in `TrialsState.swift`.

- [ ] **Step 5: Phase-1 device gate + commit**

Run the device build gate (see Conventions). Then:
```bash
git add UNBOUND/Services/Trials/WeeklyVowRewards.swift UNBOUND/Services/Trials/TrialsService.swift UNBOUND/Models/TrialsState.swift UNBOUNDTests/Services/TrialsServiceTests.swift
git commit -m "feat(vows): broken vow accrues garnish debt; win no longer pays debt"
```

---

# Phase 2 — Lane + bet card model

**Phase goal (spec §5/§7):** Replace `WeeklyVowKind` (ember/overdrive/apex) and `WeeklyVowTheme` (axis/wildcard) with `VowLane` (recovery/fuel/engine) + `VowBet` (small/medium/large, carrying owe/win XP) + `VowTarget` (count-based commitment). Migrate old persisted card/vow state to skipped/closed. Wins/debt now read `VowBet`.

## Task 2.1: `VowLane`, `VowBet`, `VowTarget` value types

**Files:**
- Create: `UNBOUND/Models/VowLane.swift`
- Create: `UNBOUND/Models/VowBet.swift`
- Create: `UNBOUND/Models/VowTarget.swift`
- Test: `UNBOUNDTests/Models/VowLaneBetTests.swift`

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Models/VowLaneBetTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class VowLaneBetTests: XCTestCase {
    func testBetEconomicsMatchSpec() {
        XCTAssertEqual(VowBet.small.oweXP, 150)
        XCTAssertEqual(VowBet.small.winXP, 50)
        XCTAssertEqual(VowBet.medium.oweXP, 250)
        XCTAssertEqual(VowBet.medium.winXP, 100)
        XCTAssertEqual(VowBet.large.oweXP, 300)
        XCTAssertEqual(VowBet.large.winXP, 150)
    }

    func testLaneVerificationKind() {
        XCTAssertEqual(VowLane.recovery.verification, .autoFromLog)
        XCTAssertEqual(VowLane.engine.verification, .autoFromLog)
        XCTAssertEqual(VowLane.fuel.verification, .selfReport)
    }

    func testCodableRoundTrips() throws {
        for lane in VowLane.allCases {
            let data = try JSONEncoder().encode(lane)
            XCTAssertEqual(try JSONDecoder().decode(VowLane.self, from: data), lane)
        }
        for bet in VowBet.allCases {
            let data = try JSONEncoder().encode(bet)
            XCTAssertEqual(try JSONDecoder().decode(VowBet.self, from: data), bet)
        }
    }

    func testTargetDisplayText() {
        XCTAssertEqual(VowTarget(count: 1, noun: "recovery reset").displayText, "1 recovery reset")
        XCTAssertEqual(VowTarget(count: 3, noun: "fuel anchor").displayText, "3 fuel anchors")
    }
}
```

- [ ] **Step 2: Run, verify it fails** — undefined types.

- [ ] **Step 3: Implement the three files**

`UNBOUND/Models/VowLane.swift`:
```swift
import Foundation
import SwiftUI

/// A Binding Vow lane. Determines how a vow is verified and its accent.
enum VowLane: String, CaseIterable, Codable, Sendable {
    case recovery
    case fuel
    case engine

    enum Verification: Sendable { case autoFromLog, selfReport }

    var verification: Verification {
        switch self {
        case .recovery, .engine: return .autoFromLog
        case .fuel: return .selfReport
        }
    }

    var displayLabel: String {
        switch self {
        case .recovery: return "RECOVERY"
        case .fuel: return "FUEL"
        case .engine: return "ENGINE"
        }
    }

    /// Accent tint, tokens only (per [[every-design-color-checked]]).
    var tintColor: Color {
        switch self {
        case .recovery: return Color.unbound.success
        case .fuel: return Color.unbound.rankGold
        case .engine: return Color.unbound.coachCyan
        }
    }

    /// Interim seal asset (final art deferred, spec §13). See Phase 5.
    var sealAssetName: String { "vow_seal_\(rawValue)" }

    var sealSymbolName: String {
        switch self {
        case .recovery: return "leaf.fill"
        case .fuel: return "fork.knife"
        case .engine: return "wind"
        }
    }
}
```

`UNBOUND/Models/VowBet.swift`:
```swift
import Foundation

/// The size of a Binding Vow bet (spec §5). `oweXP` is withheld from future
/// earned training XP on a break; `winXP` is the token paid on a clear.
enum VowBet: String, CaseIterable, Codable, Sendable {
    case small
    case medium
    case large

    var oweXP: Int {
        switch self {
        case .small: return 150
        case .medium: return 250
        case .large: return 300
        }
    }

    var winXP: Int {
        switch self {
        case .small: return 50
        case .medium: return 100
        case .large: return 150
        }
    }

    var displayLabel: String {
        switch self {
        case .small: return "SMALL"
        case .medium: return "MEDIUM"
        case .large: return "LARGE"
        }
    }
}
```

`UNBOUND/Models/VowTarget.swift`:
```swift
import Foundation

/// A count-based weekly commitment, e.g. "3 fuel anchors" or "1 recovery reset".
struct VowTarget: Codable, Equatable, Sendable {
    let count: Int
    /// Singular noun; pluralized by appending "s" when count != 1.
    let noun: String

    var displayText: String {
        count == 1 ? "\(count) \(noun)" : "\(count) \(noun)s"
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Models/VowLane.swift UNBOUND/Models/VowBet.swift UNBOUND/Models/VowTarget.swift UNBOUNDTests/Models/VowLaneBetTests.swift
git commit -m "feat(vows): add VowLane/VowBet/VowTarget value types"
```

## Task 2.2: Re-shape `WeeklyVowCard` onto lane/bet/target

**Files:**
- Modify: `UNBOUND/Models/TrialCard.swift`
- Modify: `UNBOUND/Models/WorkoutRewardSequence.swift` (`WeeklyVowRewardCallout`)
- Test: `UNBOUNDTests/Models/TrialCardKindTests.swift` (repurpose) + new assertions

The new `WeeklyVowCard` carries `lane`, `bet`, `target`. It drops `kind`, `theme`, `capstone`, `prescription`.

- [ ] **Step 1: Write the failing test**

Append to `UNBOUNDTests/Models/TrialCardKindTests.swift`:
```swift
func testCardCarriesLaneBetTarget() throws {
    let card = WeeklyVowCard(
        id: "vow-test",
        lane: .recovery,
        bet: .small,
        displayName: "Still Water Vow",
        blurb: "Protect recovery this week.",
        target: VowTarget(count: 1, noun: "recovery reset")
    )
    XCTAssertEqual(card.lane, .recovery)
    XCTAssertEqual(card.bet.oweXP, 150)
    XCTAssertEqual(card.target.displayText, "1 recovery reset")
    let data = try JSONEncoder().encode(card)
    XCTAssertEqual(try JSONDecoder().decode(WeeklyVowCard.self, from: data), card)
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement — rewrite `TrialCard.swift`**

```swift
import Foundation

/// One of the weekly vow cards offered to the user (spec §6). Static once drawn.
struct WeeklyVowCard: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let lane: VowLane
    let bet: VowBet
    let displayName: String
    let blurb: String
    let target: VowTarget

    init(
        id: String,
        lane: VowLane,
        bet: VowBet,
        displayName: String,
        blurb: String,
        target: VowTarget
    ) {
        self.id = id
        self.lane = lane
        self.bet = bet
        self.displayName = displayName
        self.blurb = blurb
        self.target = target
    }
}

typealias TrialCard = WeeklyVowCard
```
Delete `WeeklyVowPrescription` from this file (it moves nowhere — the routed-training model is removed in Phase 4; nothing in the new card needs it). If a Phase-2 compile error shows `WeeklyVowPrescription` still referenced by not-yet-deleted Phase-4 code, temporarily keep the `WeeklyVowPrescription` struct at the bottom of `TrialCard.swift` and delete it in Task 4.4.

In `UNBOUND/Models/WorkoutRewardSequence.swift`, update `WeeklyVowRewardCallout` to drop `cardKind`/`theme`/`proofName` and carry lane/bet:
```swift
struct WeeklyVowRewardCallout: Identifiable, Equatable, Sendable {
    let id: String
    var vowId: String
    var performanceLogId: String
    var lane: VowLane
    var bet: VowBet
    var title: String
    var subtitle: String
    var receiptLine: String
    var shareTitle: String
    var shareSubtitle: String
    var completedAt: Date
    var completionBonus: WeeklyVowCompletionBonus? = nil
}
```

- [ ] **Step 4: Run tests.** The build will break in the service/reward/generator/view layers — those are fixed in Task 2.4. For this task, confirm `UNBOUNDTests/WeeklyVowKindTests` (the card test) compiles and passes once Task 2.4's edits land. If you are doing strict per-task green builds, do Steps 3 of 2.2 and 2.4 together, then run both suites. (Subagent-driven execution: implement 2.2 + 2.4 in one task turn.)

- [ ] **Step 5: Commit (with 2.4) — see Task 2.4 commit.**

## Task 2.3: Migrate old persisted state to skipped/closed

**Files:**
- Modify: `UNBOUND/Models/TrialsState.swift` (`init(from:)`)
- Test: `UNBOUNDTests/Services/TrialsStoreTests.swift`

Old blobs contain `currentWeekCards`/`currentTrial` in the v1 shape (kind/theme/capstone). Under the new `WeeklyVowCard` they fail to decode. Per spec §9, in-flight vow state migrates to skipped/closed; unlocked titles/counters survive.

- [ ] **Step 1: Write the failing test**

```swift
func testLegacyCardBlobMigratesToSkippedClosed() throws {
    // v1 card shape (kind/theme/capstone) is unreadable under v2; the decoder
    // must drop in-flight vow state to empty + skipped, keeping titles.
    let legacyJSON = """
    {"currentWeekStart":1700000000,
     "currentWeekCards":[{"id":"x","kind":"ember","theme":{"axis":"power"},
       "displayName":"Old","blurb":"b","capstone":{"displayName":"p","description":"d","evaluation":{"manualClaim":{}}}}],
     "currentTrial":{"id":"x","userId":"u","weekStart":1700000000,
       "chosenCard":{"id":"x","kind":"ember","theme":{"axis":"power"},"displayName":"Old","blurb":"b",
         "capstone":{"displayName":"p","description":"d","evaluation":{"manualClaim":{}}}},
       "capstoneState":"pending","completedAt":null},
     "completionsByAxis":{},"completionsByCardKind":{},
     "unlockedTitles":["badge:keeper"],"skippedCurrentWeek":false,
     "weeklyVowCompletionLedger":[],"weeklyVowPenaltyLedger":[],"pendingVowDebtXP":0}
    """.data(using: .utf8)!
    let state = try JSONDecoder().decode(WeeklyVowsState.self, from: legacyJSON)
    XCTAssertTrue(state.currentWeekCards.isEmpty)
    XCTAssertNil(state.currentTrial)
    XCTAssertTrue(state.skippedCurrentWeek)
    XCTAssertEqual(state.unlockedTitles.count, 1)
}
```

- [ ] **Step 2: Run, verify it fails** — the decode throws on the unknown card shape.

- [ ] **Step 3: Implement — tolerant decode in `init(from:)`**

Replace the `currentWeekCards` / `currentTrial` decode lines with tolerant versions that null-out unreadable v1 data and flag a skip:
```swift
        if let cards = try? container.decodeIfPresent([WeeklyVowCard].self, forKey: .currentWeekCards), let cards {
            currentWeekCards = cards
        } else {
            currentWeekCards = []
        }
        let decodedVow = try? container.decodeIfPresent(WeeklyVow.self, forKey: .currentTrial)
        currentTrial = decodedVow ?? nil
        // If a vow was in-flight under an unreadable v1 shape, close it out (spec §9).
        let rawHadVow = container.contains(.currentTrial)
        let migratedAwayVow = rawHadVow && currentTrial == nil
```
Then, where `skippedCurrentWeek` is decoded, OR-in the migration flag:
```swift
        skippedCurrentWeek = (try container.decodeIfPresent(Bool.self, forKey: .skippedCurrentWeek) ?? false) || migratedAwayVow
```

> `WeeklyVow` itself decodes `chosenCard: WeeklyVowCard`; the v1 card inside it fails the same way, so `try?` yields nil → handled above.

- [ ] **Step 4: Run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Models/TrialsState.swift UNBOUNDTests/Services/TrialsStoreTests.swift
git commit -m "feat(vows): migrate legacy card state to skipped/closed"
```

## Task 2.4: Read economics from `VowBet`; delete `WeeklyVowKind`/`WeeklyVowTheme`

**Files:**
- Modify: `UNBOUND/Services/Trials/WeeklyVowRewards.swift`
- Modify: `UNBOUND/Services/Trials/TrialsService.swift`
- Modify: `UNBOUND/Services/Trials/TrialsServiceProtocol.swift` (`WeeklyVowCompletionReceipt`)
- Delete: `UNBOUND/Models/TrialCardKind.swift`, `UNBOUND/Models/TrialTheme.swift`
- Delete: `UNBOUNDTests/Models/TrialThemeTests.swift`; gut `TrialCardKindTests.swift` of kind/theme assertions
- Modify: `UNBOUND/Models/TrialsState.swift` (drop `completionsByCardKind`/`completionsByAxis` keyed by removed types → re-key by `VowLane`)
- Modify all view/test references (enumerated below)
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `UNBOUNDTests/Services/TrialsServiceTests.swift`:
```swift
func testBrokenVowDebtUsesBetOweXP() {
    let card = WeeklyVowCard(id: "vow-large", lane: .engine, bet: .large,
        displayName: "Blood Pace Vow", blurb: "Two easy sessions.",
        target: VowTarget(count: 2, noun: "easy cardio session"))
    var state = service.state(userId: "u-1")
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    state.currentWeekCards = [card]
    store.save(state, userId: "u-1")
    service.pickVowCard(card, userId: "u-1")
    var picked = service.state(userId: "u-1")
    picked.currentWeekStart = Date(timeIntervalSince1970: 1)
    store.save(picked, userId: "u-1")
    let exp = expectation(description: "rolled")
    Task { await service.ensureCurrentWeek(userId: "u-1"); exp.fulfill() }
    wait(for: [exp], timeout: 5)
    XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.large.oweXP) // 300
}
```

- [ ] **Step 2: Run, verify it fails / won't build** (kind references everywhere).

- [ ] **Step 3: Implement — the mechanical swap**

1. **`WeeklyVowsState`** (`TrialsState.swift`): replace the kind/axis completion counters with a single lane counter (spec §8 badge track is lane-tagged, and the title ladder is removed in Phase 5):
   - Replace `var completionsByCardKind: [WeeklyVowKind: Int]` with `var completionsByLane: [VowLane: Int]`.
   - Remove `var completionsByAxis: [AttributeKey: Int]` (axis themes are gone). Keep the computed `completionsByVowKind` only if still referenced — otherwise delete it and `currentVow`'s sibling helpers that touch removed types. Update `static empty`, `init`, `CodingKeys`, and `init(from:)` accordingly (decode the legacy keys with `try?` and discard).
   - Keep `WeeklyVowPenaltyLedgerEntry` but change `let cardKind: WeeklyVowKind` → `let lane: VowLane`.

2. **`WeeklyVowRewards.swift`**: `applyMissedPenaltyIfNeeded` now reads the bet:
   ```swift
        let owedXP = vow.chosenCard.bet.oweXP
   ```
   and `WeeklyVowPenaltyLedgerEntry(... lane: vow.chosenCard.lane ...)`.
   `WeeklyVowCompletionBonusCatalog.bonus(...)`:
   ```swift
        let lane = vow.chosenCard.lane
        let awardedOverallLevelXP = vow.chosenCard.bet.winXP
        let badgeTarget = 3 // kept tunable; lane badge milestones land in Phase 5
        let badgeProgress = min(badgeTarget, ((completionCountAfter - 1) % badgeTarget) + 1)
   ```
   Drop the `kind == .apex` share-card branch (no apex). Drop `cosmeticProgress` (cosmetic-every-5 removed Phase 5 — for now set it to the badge descriptor or remove the field; defer the field removal to Phase 5, populate it with the same badge values to keep the type stable).

3. **`TrialsService.swift`**: `sealCompletedVow` increments `state.completionsByLane[vow.chosenCard.lane, default: 0] += 1`; remove the `completionsByAxis`/`completionsByCardKind` increments and the `TitleThresholdEvaluator.crossings` call (title ladder removed in Phase 5 — for Phase 2, comment the crossings loop out and leave a `// TODO(Phase 5): badge-track titles`); `recordCompletedVowWork` reads `state.completionsByLane[vow.chosenCard.lane]` for `completionCountAfter`.

4. **`TrialsServiceProtocol.swift`** (`WeeklyVowCompletionReceipt.init`): build the callout with `lane`/`bet` instead of `cardKind`/`theme`/`proofName`:
   ```swift
        self.callout = WeeklyVowRewardCallout(
            id: "weekly-vow-\(vow.id)-\(performanceLog.id)",
            vowId: vow.id,
            performanceLogId: performanceLog.id,
            lane: vow.chosenCard.lane,
            bet: vow.chosenCard.bet,
            title: "\(vow.chosenCard.displayName) Sealed",
            subtitle: vow.chosenCard.displayName,
            receiptLine: "Receipt \(Self.shortReceiptId(performanceLog.id))",
            shareTitle: "Binding Vow Sealed",
            shareSubtitle: vow.chosenCard.displayName,
            completedAt: performanceLog.completedAt,
            completionBonus: completionBonus
        )
   ```
   Remove the `pickCard`/`completeCapstone`/`evaluateCapstoneFromLog`/`checkCapstoneWindow` Trial* adapters only if no caller uses them (grep first).

5. **Delete files:** `UNBOUND/Models/TrialCardKind.swift`, `UNBOUND/Models/TrialTheme.swift`, `UNBOUNDTests/Models/TrialThemeTests.swift`.

6. **Update remaining references.** Grep and fix each:
   ```bash
   grep -rn "WeeklyVowKind\|WeeklyVowTheme\|TrialCardKind\|TrialTheme\|\.chosenCard\.kind\|\.chosenCard\.theme\|completionsByCardKind\|completionsByAxis\|\.capstone\b\|\.prescription\b" UNBOUND UNBOUNDTests --include="*.swift"
   ```
   Expected hit sites and the fix:
   - `UNBOUND/Views/Trials/TrialCardView.swift`, `ActiveTrialCard.swift`, `TrialPickerSheet.swift`, `TrialPickerPromptCard.swift`, `ProfileTrialHistorySection.swift`, `TrialCapstoneToast.swift` — swap `card.kind.displayName`/`card.theme.tintColor`/`card.capstone.*` for `card.lane.displayLabel`/`card.lane.tintColor`/`card.target.displayText` and `card.bet`. (These views get their full Phase-4/Phase-5 treatment later; here, make them compile against the new model with minimal edits.)
   - `UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView+Readouts.swift:137` (`weeklyVowShareChip`) — read `callout.lane`/`callout.bet` instead of `cardKind`/`theme`.
   - `UNBOUNDTests/Services/TrialsServiceTests+Helpers.swift` `makeAxisCard(kind:axis:)` → replace with `makeVowCard(lane:bet:)` returning the new shape; update all call sites in `TrialsServiceTests.swift`.
   - `UNBOUNDTests/Models/TrialCardKindTests.swift` — delete kind/theme assertions, keep the Task-2.2 card test.

- [ ] **Step 4: `xcodegen generate`, run the full vow test surface, verify pass**

```bash
# after deletions/additions
xcodegen generate
```
Run `-only-testing:UNBOUNDTests/WeeklyVowsServiceTests`, `WeeklyVowsStoreTests`, `WeeklyVowKindTests`, `VowLaneBetTests`. Then the broad grep must be clean:
```bash
grep -rn "WeeklyVowKind\|WeeklyVowTheme\|completionsByCardKind\|completionsByAxis" UNBOUND UNBOUNDTests --include="*.swift"
```
Expected: no matches (legacy `CodingKeys` decode-only cases excepted).

- [ ] **Step 5: Phase-2 device gate + commit**

```bash
git add UNBOUND/Models/TrialCard.swift UNBOUND/Models/TrialsState.swift UNBOUND/Models/WorkoutRewardSequence.swift \
        UNBOUND/Services/Trials/WeeklyVowRewards.swift UNBOUND/Services/Trials/TrialsService.swift \
        UNBOUND/Services/Trials/TrialsServiceProtocol.swift \
        UNBOUND/Views/Trials UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView+Readouts.swift \
        UNBOUNDTests/Models/TrialCardKindTests.swift UNBOUNDTests/Services/TrialsServiceTests.swift \
        UNBOUNDTests/Services/TrialsServiceTests+Helpers.swift
git rm UNBOUND/Models/TrialCardKind.swift UNBOUND/Models/TrialTheme.swift UNBOUNDTests/Models/TrialThemeTests.swift
git commit -m "feat(vows): swap card model to lane/bet/target; delete kind/theme"
```

## Task 2.5: Switching grace — free to change pick while no progress is made

**Files:**
- Modify: `UNBOUND/Services/Trials/TrialsService.swift` (`pickVowCard`)
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift`

Spec §10: a short grace window lets the user change their pick with no penalty (guards mis-taps); after that, abandoning a bound vow owes the stake. We define grace as **"the outgoing vow has made zero progress"** (no Fuel anchors, still `.pending`) — simpler and clock-free (avoids unavailable `Date.now` semantics). Switching away from a vow that *has* progress counts as a break and owes `bet.oweXP`.

- [ ] **Step 1: Write the failing test**

```swift
func testSwitchingBeforeProgressIsFree() {
    let a = WeeklyVowCard(id: "vow-a", lane: .recovery, bet: .small, displayName: "Still Water Vow",
        blurb: "One reset.", target: VowTarget(count: 1, noun: "recovery reset"))
    let b = WeeklyVowCard(id: "vow-b", lane: .engine, bet: .large, displayName: "Iron Lungs Vow",
        blurb: "Three sessions.", target: VowTarget(count: 3, noun: "easy cardio session"))
    var state = service.state(userId: "u-1")
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    state.currentWeekCards = [a, b]
    store.save(state, userId: "u-1")

    service.pickVowCard(a, userId: "u-1")
    service.pickVowCard(b, userId: "u-1") // switch with no progress → free
    XCTAssertEqual(service.state(userId: "u-1").currentVow?.id, "vow-b")
    XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, 0)
}

func testSwitchingAfterProgressOwesStake() {
    let a = WeeklyVowCard(id: "vow-a", lane: .fuel, bet: .medium, displayName: "Steady Forge Vow",
        blurb: "Five anchors.", target: VowTarget(count: 5, noun: "fuel anchor"))
    let b = WeeklyVowCard(id: "vow-b", lane: .recovery, bet: .small, displayName: "Still Water Vow",
        blurb: "One reset.", target: VowTarget(count: 1, noun: "recovery reset"))
    var state = service.state(userId: "u-1")
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    state.currentWeekCards = [a, b]
    store.save(state, userId: "u-1")

    service.pickVowCard(a, userId: "u-1")
    service.logFuelAnchor(userId: "u-1") // progress made on vow-a
    service.pickVowCard(b, userId: "u-1") // abandon a bound, in-progress vow → owes a's stake
    XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.medium.oweXP) // 250
}
```
> `testSwitchingAfterProgressOwesStake` depends on `logFuelAnchor` (Task 4.2). If executing 2.5 before Phase 4, write only `testSwitchingBeforeProgressIsFree` now and add the second test when Task 4.2 lands.

- [ ] **Step 2: Run, verify it fails** (current `pickVowCard` always penalizes a switch).

- [ ] **Step 3: Implement — grace check in `pickVowCard`**

Add a progress probe and gate the debt on it:
```swift
    private func hasProgress(_ vow: WeeklyVow, in state: WeeklyVowsState) -> Bool {
        if vow.capstoneState == .completed { return true }
        if (state.fuelAnchorsByVowId[vow.id] ?? 0) > 0 { return true }
        return false
    }

    func pickVowCard(_ card: WeeklyVowCard, userId: String) {
        var state = store.load(userId: userId)
        if let existingVow = state.currentVow {
            guard existingVow.id != card.id else { return }
            // Grace: switching away from an untouched vow is free (spec §10).
            if hasProgress(existingVow, in: state) {
                WeeklyVowPenaltyCatalog.applyMissedPenaltyIfNeeded(
                    for: existingVow, missedAt: Date(), state: &state
                )
            }
        }
        let vow = WeeklyVow(
            id: card.id, userId: userId,
            weekStart: state.currentWeekStart ?? Date(),
            chosenCard: card, capstoneState: .pending, completedAt: nil
        )
        state.currentVow = vow
        state.skippedCurrentWeek = false
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowPicked, object: vow)
    }
```
> Auto-verified lanes (recovery/engine) have no in-app progress counter, so `hasProgress` returns false for them — switching a recovery/engine pick is always free, which matches "mis-tap protection" intent (a qualifying session logged elsewhere still counts toward whichever vow is bound at week close). This is acceptable; tighten only if abuse appears.

Remove the now-removed `.trialPicked` legacy notification post if it is gone; otherwise leave the existing notification posts intact.

- [ ] **Step 4: Run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Services/Trials/TrialsService.swift UNBOUNDTests/Services/TrialsServiceTests.swift
git commit -m "feat(vows): free pick-switch before progress; owe stake after"
```

---

# Phase 3 — Curated bank pool + weekly draw

**Phase goal (spec §6):** Replace per-profile `WeeklyVowGenerator` with a hand-authored `VowBankPool` and a `VowWeeklyDraw` that returns 3 cards spanning lanes and bets, with a light bias toward a neglected lane.

## Task 3.1: `VowBankPool` — concrete starter content

**Files:**
- Create: `UNBOUND/Services/Trials/VowBankPool.swift`
- Test: `UNBOUNDTests/Services/VowBankPoolTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class VowBankPoolTests: XCTestCase {
    func testEveryLaneHasCardsAtEveryBet() {
        for lane in VowLane.allCases {
            for bet in VowBet.allCases {
                let matches = VowBankPool.all.filter { $0.lane == lane && $0.bet == bet }
                XCTAssertFalse(matches.isEmpty, "No card for \(lane)/\(bet)")
            }
        }
    }

    func testTemplateIdsAreUnique() {
        let ids = VowBankPool.all.map(\.templateId)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testCopyIsBrandSafe() {
        // Brand guardrail: no "limiter/weak link/restriction" negging language.
        let banned = ["limiter", "weak link", "restriction", "holding you back", "trial", "challenge"]
        for template in VowBankPool.all {
            let blob = (template.displayName + " " + template.blurb).lowercased()
            for word in banned {
                XCTAssertFalse(blob.contains(word), "Banned copy '\(word)' in \(template.templateId)")
            }
        }
    }

    func testFuelTargetsAreCountBased() {
        for template in VowBankPool.all where template.lane == .fuel {
            XCTAssertGreaterThanOrEqual(template.target.count, 1)
        }
    }
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement `VowBankPool.swift`**

`templateId` is the stable pool identity; the per-week card `id` is stamped at draw time (Task 3.2). This is the concrete **starter** pool (spec §13: expandable).

```swift
// UNBOUND/Services/Trials/VowBankPool.swift
import Foundation

/// A hand-authored bank-pool entry (spec §6). Stable `templateId`; the weekly
/// draw stamps a per-week card id.
struct VowCardTemplate: Equatable, Sendable {
    let templateId: String
    let lane: VowLane
    let bet: VowBet
    let displayName: String
    let blurb: String
    let target: VowTarget
}

/// The curated Binding Vow bank pool. Expandable over time.
enum VowBankPool {
    static let all: [VowCardTemplate] = recovery + fuel + engine

    // MARK: Recovery (auto-verified from a logged recovery session)
    private static let recovery: [VowCardTemplate] = [
        VowCardTemplate(templateId: "rec-still-water", lane: .recovery, bet: .small,
            displayName: "Still Water Vow",
            blurb: "Bind one recovery reset this week. Protect the arc; let the body catch up.",
            target: VowTarget(count: 1, noun: "recovery reset")),
        VowCardTemplate(templateId: "rec-open-gate", lane: .recovery, bet: .medium,
            displayName: "Open Gate Vow",
            blurb: "Bind two recovery resets. Keep the joints honest while the load builds.",
            target: VowTarget(count: 2, noun: "recovery reset")),
        VowCardTemplate(templateId: "rec-deep-current", lane: .recovery, bet: .large,
            displayName: "Deep Current Vow",
            blurb: "Bind three recovery resets. A full week of tending the engine.",
            target: VowTarget(count: 3, noun: "recovery reset")),
    ]

    // MARK: Fuel (self-report anchors, vow-scoped only)
    private static let fuel: [VowCardTemplate] = [
        VowCardTemplate(templateId: "fuel-first-spark", lane: .fuel, bet: .small,
            displayName: "First Spark Vow",
            blurb: "Bind three fuel anchors this week — protein, water, or a real meal. Tap each as you hit it.",
            target: VowTarget(count: 3, noun: "fuel anchor")),
        VowCardTemplate(templateId: "fuel-steady-forge", lane: .fuel, bet: .medium,
            displayName: "Steady Forge Vow",
            blurb: "Bind five fuel anchors. Fuel the work without counting a single calorie.",
            target: VowTarget(count: 5, noun: "fuel anchor")),
        VowCardTemplate(templateId: "fuel-full-furnace", lane: .fuel, bet: .large,
            displayName: "Full Furnace Vow",
            blurb: "Bind seven fuel anchors. A week of feeding the arc on purpose.",
            target: VowTarget(count: 7, noun: "fuel anchor")),
    ]

    // MARK: Engine (auto-verified from a logged cardio session)
    private static let engine: [VowCardTemplate] = [
        VowCardTemplate(templateId: "eng-blood-pace", lane: .engine, bet: .small,
            displayName: "Blood Pace Vow",
            blurb: "Bind one easy cardio session this week. Keep the engine turning over.",
            target: VowTarget(count: 1, noun: "easy cardio session")),
        VowCardTemplate(templateId: "eng-long-road", lane: .engine, bet: .medium,
            displayName: "Long Road Vow",
            blurb: "Bind two easy cardio sessions. Build the base under everything else.",
            target: VowTarget(count: 2, noun: "easy cardio session")),
        VowCardTemplate(templateId: "eng-iron-lungs", lane: .engine, bet: .large,
            displayName: "Iron Lungs Vow",
            blurb: "Bind three easy cardio sessions. A full week of engine work.",
            target: VowTarget(count: 3, noun: "easy cardio session")),
    ]
}
```

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Services/Trials/VowBankPool.swift UNBOUNDTests/Services/VowBankPoolTests.swift
git commit -m "feat(vows): add curated bank-pool starter content"
```

## Task 3.2: `VowWeeklyDraw` — deterministic 3-card draw with light targeting

**Files:**
- Create: `UNBOUND/Services/Trials/VowWeeklyDraw.swift`
- Test: `UNBOUNDTests/Services/VowWeeklyDrawTests.swift`

Determinism: seed from `weekNumber` (no `Math.random` — and `Date.now`/RNG are unavailable in some contexts). Light targeting: bias the draw to include a card from the lane with the **lowest** `completionsByLane` count.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class VowWeeklyDrawTests: XCTestCase {
    func testDrawsThreeCards() {
        let cards = VowWeeklyDraw.cards(weekNumber: 5, completionsByLane: [:])
        XCTAssertEqual(cards.count, 3)
    }

    func testDeterministicForSameInputs() {
        let a = VowWeeklyDraw.cards(weekNumber: 5, completionsByLane: [.recovery: 2])
        let b = VowWeeklyDraw.cards(weekNumber: 5, completionsByLane: [.recovery: 2])
        XCTAssertEqual(a, b)
    }

    func testCardIdsCarryWeekStamp() {
        let cards = VowWeeklyDraw.cards(weekNumber: 7, completionsByLane: [:])
        XCTAssertTrue(cards.allSatisfy { $0.id.contains("W7") })
    }

    func testNeglectedLaneIsRepresented() {
        // Recovery and engine are well-trodden; fuel neglected → fuel must appear.
        let cards = VowWeeklyDraw.cards(
            weekNumber: 3,
            completionsByLane: [.recovery: 10, .engine: 10, .fuel: 0]
        )
        XCTAssertTrue(cards.contains { $0.lane == .fuel })
    }

    func testSpansMultipleLanes() {
        let cards = VowWeeklyDraw.cards(weekNumber: 1, completionsByLane: [:])
        XCTAssertGreaterThanOrEqual(Set(cards.map(\.lane)).count, 2)
    }
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement `VowWeeklyDraw.swift`**

```swift
// UNBOUND/Services/Trials/VowWeeklyDraw.swift
import Foundation

/// Draws the 3 weekly Binding Vow cards from the bank pool (spec §6).
/// Deterministic in (weekNumber, completionsByLane). Guarantees the most
/// neglected lane appears, then fills to 3 spanning lanes/bets.
enum VowWeeklyDraw {
    static func cards(weekNumber: Int, completionsByLane: [VowLane: Int]) -> [WeeklyVowCard] {
        let pool = VowBankPool.all
        guard !pool.isEmpty else { return [] }

        // Seeded, non-cryptographic rotation. weekNumber advances the offset so
        // the trio rotates week to week without RNG.
        func pick(_ candidates: [VowCardTemplate], salt: Int) -> VowCardTemplate? {
            guard !candidates.isEmpty else { return nil }
            let idx = ((weekNumber &* 31) &+ salt) % candidates.count
            return candidates[(idx % candidates.count + candidates.count) % candidates.count]
        }

        var chosen: [VowCardTemplate] = []

        // 1) Most neglected lane (lowest completion count; ties broken by lane order).
        let neglected = VowLane.allCases.min { a, b in
            (completionsByLane[a] ?? 0, a.rawValue) < (completionsByLane[b] ?? 0, b.rawValue)
        }
        if let neglected, let t = pick(pool.filter { $0.lane == neglected }, salt: 1) {
            chosen.append(t)
        }

        // 2) Fill remaining slots, preferring unused lanes then unused bets.
        var salt = 2
        while chosen.count < 3 {
            let usedLanes = Set(chosen.map(\.lane))
            let usedBets = Set(chosen.map(\.bet))
            let preferred = pool.filter { !usedLanes.contains($0.lane) }
            let pickFrom = preferred.isEmpty ? pool.filter { !chosen.contains($0) } : preferred
            guard var t = pick(pickFrom, salt: salt) else { break }
            // nudge toward an unused bet size if the picked one is taken
            if usedBets.contains(t.bet),
               let alt = pickFrom.first(where: { !usedBets.contains($0.bet) }) {
                t = alt
            }
            if !chosen.contains(t) { chosen.append(t) }
            salt += 1
            if salt > 64 { break } // safety
        }

        return chosen.prefix(3).map { template in
            WeeklyVowCard(
                id: "weekly-vow-W\(weekNumber)-\(template.templateId)",
                lane: template.lane,
                bet: template.bet,
                displayName: template.displayName,
                blurb: template.blurb,
                target: template.target
            )
        }
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Services/Trials/VowWeeklyDraw.swift UNBOUNDTests/Services/VowWeeklyDrawTests.swift
git commit -m "feat(vows): add deterministic weekly bank-pool draw"
```

## Task 3.3: Wire the service to the draw; delete `WeeklyVowGenerator`

**Files:**
- Modify: `UNBOUND/Services/Trials/TrialsService.swift` (`ensureCurrentWeek`)
- Delete: `UNBOUND/Services/Trials/TrialGenerator.swift`
- Delete: `UNBOUNDTests/Services/TrialGeneratorTests.swift`
- Inspect/clean: `CapstoneCatalog`, `PrestigeCapstoneCatalog` (only if now orphaned)
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testEnsureCurrentWeekDrawsThreeBankPoolCards() {
    let exp = expectation(description: "rolled")
    Task { await service.ensureCurrentWeek(userId: "u-draw"); exp.fulfill() }
    wait(for: [exp], timeout: 5)
    let cards = service.state(userId: "u-draw").currentWeekCards
    XCTAssertEqual(cards.count, 3)
    let poolNames = Set(VowBankPool.all.map(\.displayName))
    XCTAssertTrue(cards.allSatisfy { poolNames.contains($0.displayName) })
}
```

- [ ] **Step 2: Run, verify it fails** (still calling `WeeklyVowGenerator`).

- [ ] **Step 3: Implement**

In `TrialsService.ensureCurrentWeek`, replace the snapshot+generator block:
```swift
        // Snapshot the user's profile + history for card generation.
        let profile = attribute.snapshot(userId: userId, asOf: now)
        let history = await recentLogsProvider(userId)
        let weekNumber = isoWeekNumber(for: newWeekStart)

        let cards = WeeklyVowGenerator.cards(
            profile: profile,
            history: history,
            weekStart: newWeekStart,
            weekNumber: weekNumber
        )
```
with:
```swift
        let weekNumber = isoWeekNumber(for: newWeekStart)
        let cards = VowWeeklyDraw.cards(
            weekNumber: weekNumber,
            completionsByLane: state.completionsByLane
        )
```
Remove the now-unused `attribute` snapshot and `recentLogsProvider` history *only if no other method uses them*. Grep within `TrialsService.swift`: if `attribute`/`recentLogsProvider` are unused after this, delete the stored properties, the `init` params, and the convenience `init` wiring. (Phase 4 may re-add a logs provider for auto-detection — if so, keep `recentLogsProvider`. Check Task 4.1 before deleting; safest is to keep `recentLogsProvider`, delete `attribute` if unused.)

Delete `UNBOUND/Services/Trials/TrialGenerator.swift` and `UNBOUNDTests/Services/TrialGeneratorTests.swift`.

Check whether `CapstoneCatalog` / `PrestigeCapstoneCatalog` (referenced only by the old generator) are now orphaned:
```bash
grep -rn "CapstoneCatalog\|PrestigeCapstoneCatalog" UNBOUND UNBOUNDTests --include="*.swift"
```
`CapstoneStandards.swift` defines `TrialGenerator`-adjacent capstones; if `PrestigeCapstoneCatalog` is referenced only by the deleted generator, delete it too. **Do not** delete anything still referenced by the Rank Trials system or `CapstoneStandards` consumers — grep first, per [[verify-audit-dead-claims-before-delete]].

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass.** Confirm `WeeklyVowGenerator` is gone:
```bash
grep -rn "WeeklyVowGenerator\|TrialGenerator" UNBOUND UNBOUNDTests --include="*.swift"
```
Expected: no matches.

- [ ] **Step 5: Phase-3 device gate + commit**
```bash
git add UNBOUND/Services/Trials/TrialsService.swift UNBOUNDTests/Services/TrialsServiceTests.swift
git rm UNBOUND/Services/Trials/TrialGenerator.swift UNBOUNDTests/Services/TrialGeneratorTests.swift
git commit -m "feat(vows): draw weekly cards from bank pool; delete generator"
```

---

# Phase 4 — Verification (auto-detect + Fuel self-report)

**Phase goal (spec §7):** Recovery/Engine vows auto-complete when a qualifying logged session appears during the bound week. Fuel vows complete via vow-scoped self-report taps. This replaces the routed-training-draft completion model.

## Task 4.1: Auto-detect Recovery/Engine completion from logged sessions

**Files:**
- Create: `UNBOUND/Services/Trials/VowLogMatcher.swift`
- Modify: `UNBOUND/Services/Trials/TrialsService.swift`
- Test: `UNBOUNDTests/Services/VowLogMatcherTests.swift`

A vow's `target.count` qualifying sessions must be logged at/after `vow.weekStart` and before week close. "Qualifying" = the log's nature matches the lane (recovery vs cardio/engine).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class VowLogMatcherTests: XCTestCase {
    private func recoveryLog(at t: TimeInterval) -> WorkoutLog {
        WorkoutLog(id: UUID().uuidString, userId: "u", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Recovery Reset",
            startedAt: Date(timeIntervalSince1970: t),
            completedAt: Date(timeIntervalSince1970: t + 600),
            exerciseEntries: [], overallNotes: nil, overallRPE: 3, durationMinutes: 10,
            source: .recovery)
    }

    func testCountsRecoverySessionsInWindow() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [recoveryLog(at: 1_700_000_500), recoveryLog(at: 1_700_100_000)]
        let count = VowLogMatcher.qualifyingCount(
            lane: .recovery, weekStart: weekStart, logs: logs
        )
        XCTAssertEqual(count, 2)
    }

    func testIgnoresLogsBeforeWeekStart() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [recoveryLog(at: 1_600_000_000)]
        XCTAssertEqual(VowLogMatcher.qualifyingCount(lane: .recovery, weekStart: weekStart, logs: logs), 0)
    }

    func testRecoveryLaneIgnoresStrengthLogs() {
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        var strength = recoveryLog(at: 1_700_000_500)
        strength.source = .program
        XCTAssertEqual(VowLogMatcher.qualifyingCount(lane: .recovery, weekStart: weekStart, logs: [strength]), 0)
    }
}
```

> **Executor note:** Confirm `WorkoutLog` has a `source` property and the case names (`.recovery`, `.program`, cardio source). `grep -rn "enum .*Source\|var source" UNBOUND/Models/WorkoutLog.swift`. Adapt the lane→source mapping in Step 3 to the real source enum. If `WorkoutLog` lacks a `source`, derive the qualifier from `plannedWorkoutName`/block kind as the existing recovery/cardio logging does.

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement `VowLogMatcher.swift`**

```swift
// UNBOUND/Services/Trials/VowLogMatcher.swift
import Foundation

/// Counts logged sessions that qualify for an auto-verified vow lane within the
/// bound week (spec §7). Recovery/Engine only; Fuel is self-report.
enum VowLogMatcher {
    static func qualifyingCount(lane: VowLane, weekStart: Date, logs: [WorkoutLog]) -> Int {
        let weekEnd = weekStart.addingTimeInterval(7 * 86_400)
        return logs.filter { log in
            log.completedAt >= weekStart
                && log.completedAt < weekEnd
                && qualifies(lane: lane, log: log)
        }.count
    }

    private static func qualifies(lane: VowLane, log: WorkoutLog) -> Bool {
        switch lane {
        case .recovery: return log.source == .recovery
        case .engine:   return log.source == .cardio   // adapt to the real source case
        case .fuel:     return false                   // self-report, never log-matched
        }
    }
}
```

In `TrialsService.swift`, add a method to evaluate auto-verified completion against logs (called from the existing foreground/`checkVowWindow` path or a new `refreshVowProgress`):
```swift
    /// Auto-complete an auto-verified vow when enough qualifying sessions are
    /// logged in-week. No-op for Fuel (self-report) vows.
    func refreshAutoVerifiedVow(userId: String) async {
        var state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen,
              vow.chosenCard.lane.verification == .autoFromLog,
              let weekStart = state.currentWeekStart
        else { return }
        let logs = await recentLogsProvider(userId)
        let count = VowLogMatcher.qualifyingCount(lane: vow.chosenCard.lane, weekStart: weekStart, logs: logs)
        guard count >= vow.chosenCard.target.count else { return }
        sealVow(userId: userId, vow: vow, at: Date())
    }
```
> `sealVow` is the simplified completion introduced in Task 4.4 (replaces `recordCompletedVowWork`/`sealCompletedVow`). If implementing 4.1 before 4.4, temporarily route through a minimal inline seal that sets `.completed`, increments `completionsByLane`, pays `bet.winXP` via `OverallLevelService.grantFlatXPStrict`, and posts `.weeklyVowCompleted`; replace with `sealVow` in 4.4.

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Services/Trials/VowLogMatcher.swift UNBOUND/Services/Trials/TrialsService.swift UNBOUNDTests/Services/VowLogMatcherTests.swift
git commit -m "feat(vows): auto-detect recovery/engine vow completion from logs"
```

## Task 4.2: Fuel self-report state + service ops

**Files:**
- Modify: `UNBOUND/Models/TrialsState.swift` (add `fuelAnchorsByVowId`)
- Modify: `UNBOUND/Services/Trials/TrialsService.swift`
- Modify: `UNBOUND/Services/Trials/TrialsServiceProtocol.swift`
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift`

**Guardrail (spec §7):** Fuel anchors are vow-scoped check-offs only. They feed the vow's completion and nothing else — no XP/rank/attribute path.

- [ ] **Step 1: Write the failing test**

```swift
func testFuelTapIncrementsAndSealsAtTarget() {
    let card = WeeklyVowCard(id: "vow-fuel", lane: .fuel, bet: .small,
        displayName: "First Spark Vow", blurb: "Three anchors.",
        target: VowTarget(count: 3, noun: "fuel anchor"))
    var state = service.state(userId: "u-1")
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    state.currentWeekCards = [card]
    store.save(state, userId: "u-1")
    service.pickVowCard(card, userId: "u-1")

    service.logFuelAnchor(userId: "u-1")
    service.logFuelAnchor(userId: "u-1")
    XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 2)
    XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

    service.logFuelAnchor(userId: "u-1") // hits target → seals
    XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
}

func testFuelTapDoesNothingForNonFuelVow() {
    let card = WeeklyVowCard(id: "vow-rec", lane: .recovery, bet: .small,
        displayName: "Still Water Vow", blurb: "One reset.",
        target: VowTarget(count: 1, noun: "recovery reset"))
    var state = service.state(userId: "u-1")
    state.currentWeekCards = [card]
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    store.save(state, userId: "u-1")
    service.pickVowCard(card, userId: "u-1")
    service.logFuelAnchor(userId: "u-1")
    XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 0)
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement**

In `WeeklyVowsState`, add:
```swift
    /// Vow-scoped Fuel self-report tallies, keyed by vow id. Feeds only the
    /// vow's completion — never XP/rank/attributes (spec §7 guardrail).
    var fuelAnchorsByVowId: [String: Int]
```
Wire it through `empty`, `init`, `CodingKeys`, `init(from:)` (`decodeIfPresent ?? [:]`).

In `TrialsServiceProtocol.swift`, add to the protocol:
```swift
    /// Record one Fuel anchor for the current Fuel vow. No-op otherwise.
    func logFuelAnchor(userId: String)
    /// Current Fuel anchor tally for the active vow (0 if none / non-Fuel).
    func fuelAnchorCount(userId: String) -> Int
```

In `TrialsService.swift`:
```swift
    func logFuelAnchor(userId: String) {
        var state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.chosenCard.lane == .fuel,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen
        else { return }
        let next = (state.fuelAnchorsByVowId[vow.id] ?? 0) + 1
        state.fuelAnchorsByVowId[vow.id] = next
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowProgressUpdated, object: vow)
        if next >= vow.chosenCard.target.count {
            sealVow(userId: userId, vow: vow, at: Date())
        }
    }

    func fuelAnchorCount(userId: String) -> Int {
        let state = store.load(userId: userId)
        guard let vow = state.currentVow, vow.chosenCard.lane == .fuel else { return 0 }
        return state.fuelAnchorsByVowId[vow.id] ?? 0
    }
```
> Add `.weeklyVowProgressUpdated` to the existing vow `Notification.Name` extension (alongside `.weeklyVowPicked` etc.). `sealVow` is from Task 4.4 (or the inline interim seal from Task 4.1's note).

- [ ] **Step 4: Run tests, verify pass.**

- [ ] **Step 5: Commit**
```bash
git add UNBOUND/Models/TrialsState.swift UNBOUND/Services/Trials/TrialsService.swift UNBOUND/Services/Trials/TrialsServiceProtocol.swift UNBOUNDTests/Services/TrialsServiceTests.swift
git commit -m "feat(vows): vow-scoped Fuel self-report tally + seal-at-target"
```

## Task 4.3: Fuel self-report UI surface

**Files:**
- Modify: `UNBOUND/Views/Trials/ActiveTrialCard.swift` (add a Fuel tap row for fuel-lane vows)
- Test: manual screenshot verification (UI)

Per [[ui-claims-need-onsim-screenshot]], verify on-sim before claiming done.

- [ ] **Step 1: Implement the Fuel row**

In `ActiveTrialCard.swift`, when the active vow's `lane == .fuel`, render a tap-to-log control bound to `fuelAnchorCount` / `logFuelAnchor`, showing `count / target.count`. Match the calm-list language ([[calm-list-frontend-language]]): a single fill-only lifted surface, MetaLine not pills, no left accent bar ([[no-left-accent-bar]]). Example:

```swift
if vow.chosenCard.lane == .fuel {
    Button {
        services.trials.logFuelAnchor(userId: userId)
    } label: {
        HStack {
            Image(systemName: "plus.circle.fill")
            Text("Log fuel anchor")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
            Spacer()
            Text("\(services.trials.fuelAnchorCount(userId: userId))/\(vow.chosenCard.target.count)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.unbound.surfaceElevated.opacity(0.22)))
    }
    .buttonStyle(.plain)
    .foregroundStyle(VowLane.fuel.tintColor)
}
```
> Wire `services`/`userId` exactly as the surrounding view already accesses them (read the file's existing environment/observed objects first).

- [ ] **Step 2: Build for sim + screenshot-verify**

Launch with the Train tab harness (`--unbound-open-program`) or the existing vow-surface launch arg, drive a Fuel vow into the active state, screenshot, and `Read` the PNG to confirm the row renders, the count increments, and copy isn't clipped on iPhone SE width.

- [ ] **Step 3: Commit**
```bash
git add UNBOUND/Views/Trials/ActiveTrialCard.swift
git commit -m "feat(vows): Fuel self-report tap row on the active vow card"
```

## Task 4.4: Delete the routed-training completion path; introduce `sealVow`

**Files:**
- Delete: `UNBOUND/Services/Trials/WeeklyVowTrainingBuilder.swift`, `UNBOUND/Services/Trials/WeeklyVowProof.swift`
- Modify: `UNBOUND/Services/Trials/TrialsService.swift`, `TrialsServiceProtocol.swift`
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` (remove routed-vow completion)
- Modify: `UNBOUND/Models/TrialCard.swift` (delete leftover `WeeklyVowPrescription` if still present)
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
func testSealVowPaysBetWinAndMarksCompleted() {
    let card = WeeklyVowCard(id: "vow-seal", lane: .recovery, bet: .medium,
        displayName: "Open Gate Vow", blurb: "Two resets.",
        target: VowTarget(count: 2, noun: "recovery reset"))
    var state = service.state(userId: "u-1")
    state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
    state.currentWeekCards = [card]
    store.save(state, userId: "u-1")
    service.pickVowCard(card, userId: "u-1")

    service.sealVow(userId: "u-1", vow: service.state(userId: "u-1").currentVow!, at: Date())

    let after = service.state(userId: "u-1")
    XCTAssertEqual(after.currentVow?.capstoneState, .completed)
    XCTAssertEqual(after.completionsByLane[.recovery], 1)
}
```

- [ ] **Step 2: Run, verify it fails** (`sealVow` not yet a real method / still private).

- [ ] **Step 3: Implement — replace routed completion with `sealVow`**

Add `sealVow` to `TrialsService.swift` (consolidating Task 4.1's interim seal):
```swift
    func sealVow(userId: String, vow: WeeklyVow, at date: Date) {
        var state = store.load(userId: userId)
        guard var current = state.currentVow, current.id == vow.id,
              current.capstoneState != .completed, current.capstoneState != .missed
        else { return }
        current.capstoneState = .completed
        current.completedAt = date
        state.currentVow = current
        state.completionsByLane[current.chosenCard.lane, default: 0] += 1
        store.save(state, userId: userId)

        // Token win — paid in full, never garnished (spec §5).
        Task {
            try? await OverallLevelService.shared.grantFlatXPStrict(
                amount: current.chosenCard.bet.winXP,
                sourceId: "weeklyVowWin:\(current.id)",
                userId: userId,
                at: date
            )
        }
        NotificationCenter.default.post(name: .weeklyVowCompleted, object: current)
        AnalyticsService.shared.track(.bindingVowCleared(vowId: current.id))
    }
```
Add `func sealVow(userId:vow:at:)` to the protocol.

Delete the old completion machinery from `TrialsService.swift`: `recordCompletedVowWork`, `sealCompletedVow`, `completeVow`, `trainingDraft`, `trainingDraftForCurrentVow`, `evaluateVowProofFromLog`, and the `CurrencyWalletStore.shared.grant(...)` coin drip. Remove their protocol declarations and the `WeeklyVowCompletionReceipt` type if no longer referenced (the reward sequence integration moves to a callout built in `sealVow` — see Phase 5 Task 5.4; for now, post `.weeklyVowCompleted` and let Phase 5 wire the reward sequence).

In `ActiveWorkoutContainerView.swift`, remove the `recordCompletedVowWork` call (~line 851), `applyWeeklyVowBonus`, and the `weeklyVowReceipt` plumbing through `makeRewardSequenceSummary`. The reward-sequence vow callout is re-added in Phase 5 from the `sealVow` path / `.weeklyVowCompleted` observer.

Delete `WeeklyVowTrainingBuilder.swift` and `WeeklyVowProof.swift`. Delete leftover `WeeklyVowPrescription` from `TrialCard.swift`. Grep for orphans:
```bash
grep -rn "WeeklyVowTrainingBuilder\|WeeklyVowProof\|WeeklyVowPrescription\|recordCompletedVowWork\|trainingDraft\|WeeklyVowTrainingRoute\|TierCriterionEvaluator.*weeklyVow" UNBOUND UNBOUNDTests --include="*.swift"
```
Fix each remaining caller (Workout Ready / launch coordinators that built vow drafts — those entry points simply no longer route vow work; a vow is cleared by ordinary logging or Fuel taps now).

> **Caution** ([[verify-audit-dead-claims-before-delete]]): `TierCriterionEvaluator` is shared with the skill-rank system — do NOT delete it; only delete the vow-specific `weeklyVowExerciseHistory` extension in `WeeklyVowProof.swift`.

- [ ] **Step 4: `xcodegen generate`, run the vow suites + a broad build, verify pass.** Confirm the routed path is gone (grep above → clean except shared `TierCriterionEvaluator`).

- [ ] **Step 5: Phase-4 device gate + commit**
```bash
git add UNBOUND/Services/Trials/TrialsService.swift UNBOUND/Services/Trials/TrialsServiceProtocol.swift \
        UNBOUND/Models/TrialCard.swift UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift \
        UNBOUNDTests/Services/TrialsServiceTests.swift
git rm UNBOUND/Services/Trials/WeeklyVowTrainingBuilder.swift UNBOUND/Services/Trials/WeeklyVowProof.swift
git commit -m "feat(vows): replace routed-training completion with log/self-report sealVow"
```

---

# Phase 5 — Rewards (badge track + Vow Sigil + lane seals) + teardown

**Phase goal (spec §8/§9):** Replace vow rewards with one Vows badge track, an evolving Vow Sigil, and lane seal emblems. Tear down the vow title ladder, cosmetic-every-5, and the reward-callout's stale fields. Reward-sequence callout reflects the new token win + sigil seal.

## Task 5.1: Vows badge track

**Files:**
- Create: `UNBOUND/Services/Trials/VowBadgeTrack.swift`
- Test: `UNBOUNDTests/Services/VowBadgeTrackTests.swift`

Milestones (spec §8, tunable): 5 / 15 / 30 / 52 vows kept. "Vows kept" = total across `completionsByLane`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class VowBadgeTrackTests: XCTestCase {
    func testMilestoneCrossings() {
        XCTAssertEqual(VowBadgeTrack.crossings(priorKept: 4, currentKept: 5), [.init(threshold: 5)])
        XCTAssertEqual(VowBadgeTrack.crossings(priorKept: 5, currentKept: 5), [])
        XCTAssertEqual(VowBadgeTrack.crossings(priorKept: 14, currentKept: 15), [.init(threshold: 15)])
    }

    func testTotalKept() {
        XCTAssertEqual(VowBadgeTrack.totalKept([.recovery: 2, .fuel: 1, .engine: 3]), 6)
    }

    func testProgressToNext() {
        let p = VowBadgeTrack.progress(totalKept: 7)
        XCTAssertEqual(p.current, 7)
        XCTAssertEqual(p.nextThreshold, 15)
    }
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement `VowBadgeTrack.swift`**

```swift
// UNBOUND/Services/Trials/VowBadgeTrack.swift
import Foundation

enum VowBadgeTrack {
    struct Milestone: Equatable, Sendable { let threshold: Int }
    struct Progress: Equatable, Sendable {
        let current: Int
        let nextThreshold: Int?
    }

    /// Tunable milestone thresholds (spec §8).
    static let thresholds = [5, 15, 30, 52]

    static func totalKept(_ byLane: [VowLane: Int]) -> Int {
        byLane.values.reduce(0, +)
    }

    static func crossings(priorKept: Int, currentKept: Int) -> [Milestone] {
        thresholds
            .filter { priorKept < $0 && currentKept >= $0 }
            .map { Milestone(threshold: $0) }
    }

    static func progress(totalKept: Int) -> Progress {
        Progress(current: totalKept, nextThreshold: thresholds.first { $0 > totalKept })
    }
}
```

- [ ] **Step 4: `xcodegen generate`, run tests, verify pass.**

- [ ] **Step 5: Wire crossings into `sealVow` + commit**

In `TrialsService.sealVow`, compute kept-counts before/after and fire badge unlocks:
```swift
        let priorKept = VowBadgeTrack.totalKept(state.completionsByLane)
        state.completionsByLane[current.chosenCard.lane, default: 0] += 1
        let currentKept = VowBadgeTrack.totalKept(state.completionsByLane)
        ...
        for milestone in VowBadgeTrack.crossings(priorKept: priorKept, currentKept: currentKept) {
            NotificationCenter.default.post(name: .vowBadgeUnlocked, object: milestone)
        }
```
Add `.vowBadgeUnlocked` to the vow `Notification.Name` extension.
```bash
git add UNBOUND/Services/Trials/VowBadgeTrack.swift UNBOUND/Services/Trials/TrialsService.swift UNBOUNDTests/Services/VowBadgeTrackTests.swift
git commit -m "feat(vows): Vows badge track with milestone crossings"
```

## Task 5.2: Vow Sigil (data + segment seal + fracture self-heal + functional render)

**Files:**
- Create: `UNBOUND/Models/VowSigil.swift`
- Create: `UNBOUND/Views/Trials/VowSigilView.swift`
- Test: `UNBOUNDTests/Models/VowSigilTests.swift`

The sigil seals one segment per kept vow; a broken vow adds a fracture that self-heals after N kept vows (spec §8). Final illustrated art is deferred — this is a functional vector render.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import UNBOUND

final class VowSigilTests: XCTestCase {
    func testSealedSegmentsEqualKeptVows() {
        let sigil = VowSigil(keptVows: 4, brokenVows: 1)
        XCTAssertEqual(sigil.sealedSegments, 4)
    }

    func testFractureSelfHeals() {
        // A fracture from a break heals after `healAfterKept` subsequent keeps.
        let fresh = VowSigil(keptVows: 0, brokenVows: 1)
        XCTAssertEqual(fresh.activeFractures, 1)
        let healed = VowSigil(keptVows: VowSigil.healAfterKept, brokenVows: 1)
        XCTAssertEqual(healed.activeFractures, 0)
    }

    func testNeverNegativeFractures() {
        let sigil = VowSigil(keptVows: 100, brokenVows: 0)
        XCTAssertEqual(sigil.activeFractures, 0)
    }
}
```

- [ ] **Step 2: Run, verify it fails.**

- [ ] **Step 3: Implement `VowSigil.swift`**

```swift
// UNBOUND/Models/VowSigil.swift
import Foundation

/// The evolving profile oath-mark (spec §8). One sealed segment per kept vow;
/// each broken vow leaves a fracture that self-heals after `healAfterKept`
/// subsequent keeps so it never tips into negging.
struct VowSigil: Equatable, Sendable {
    let keptVows: Int
    let brokenVows: Int

    /// Keeps needed to heal one fracture (tunable).
    static let healAfterKept = 3

    var sealedSegments: Int { max(0, keptVows) }

    /// Fractures still visible: broken vows not yet healed by later keeps.
    var activeFractures: Int {
        let healed = keptVows / Self.healAfterKept
        return max(0, brokenVows - healed)
    }
}
```

- [ ] **Step 4: Implement `VowSigilView.swift` (functional vector render)**

A token-only, reduced-motion-safe radial render: `sealedSegments` lit wedges on a ring, `activeFractures` faint cracks. Use `Color.unbound` tokens, AA contrast on true black, no photoreal art (interim — final art deferred per [[banner-art-is-anime-jrpg]]). Keep it under ~60 lines; a `Canvas` or stacked `Capsule` wedges is fine. Drive color from the dominant lane via `VowLane.tintColor`.

```swift
// UNBOUND/Views/Trials/VowSigilView.swift
import SwiftUI

struct VowSigilView: View {
    let sigil: VowSigil
    var accent: Color = Color.unbound.rankGold
    var segmentCount: Int = 12

    var body: some View {
        ZStack {
            ForEach(0..<segmentCount, id: \.self) { i in
                Capsule()
                    .fill(i < sigil.sealedSegments % (segmentCount + 1) ? accent : Color.unbound.surfaceElevated.opacity(0.25))
                    .frame(width: 4, height: 14)
                    .offset(y: -26)
                    .rotationEffect(.degrees(Double(i) / Double(segmentCount) * 360))
            }
            Image(systemName: "seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent.opacity(sigil.activeFractures > 0 ? 0.55 : 1.0))
        }
        .frame(width: 64, height: 64)
        .accessibilityLabel("Vow sigil, \(sigil.sealedSegments) vows sealed")
    }
}
```

- [ ] **Step 5: `xcodegen generate`, run tests, screenshot-verify the render, commit**
```bash
git add UNBOUND/Models/VowSigil.swift UNBOUND/Views/Trials/VowSigilView.swift UNBOUNDTests/Models/VowSigilTests.swift
git commit -m "feat(vows): Vow Sigil model + functional render (final art deferred)"
```

## Task 5.3: Lane seal emblems + profile surface

**Files:**
- Modify: `UNBOUND/Assets.xcassets/BindingVows/` — add interim `vow_seal_recovery`, `vow_seal_fuel`, `vow_seal_engine` imagesets (or render from `VowLane.sealSymbolName` with no asset)
- Modify: `UNBOUND/Views/Trials/ProfileTrialHistorySection.swift` — show Vows badge progress + sigil + lane seals
- Test: screenshot verification

- [ ] **Step 1: Implement**

Render lane seals from `VowLane.sealSymbolName` + `tintColor` (no new art assets needed for the functional pass — `sealAssetName` stays a hook for final art). In `ProfileTrialHistorySection.swift`, replace any kind/theme/title-ladder UI with: `VowSigilView`, the `VowBadgeTrack.progress` line ("Vows kept 7 · next 15"), and a row of three lane seals dimmed/lit by `completionsByLane`. Keep calm-list language, no left accent bar.

Construct the sigil from state — kept count from the badge track, fractures from the penalty ledger:
```swift
let state = services.trials.state(userId: userId)
let sigil = VowSigil(
    keptVows: VowBadgeTrack.totalKept(state.completionsByLane),
    brokenVows: state.weeklyVowPenaltyLedger.count
)
let progress = VowBadgeTrack.progress(totalKept: sigil.sealedSegments)
```

- [ ] **Step 2: Build for sim + screenshot-verify** the profile vow section on iPhone 17 + a small device width; `Read` the PNGs (pixel-council color check per [[every-design-color-checked]]).

- [ ] **Step 3: Commit**
```bash
git add UNBOUND/Views/Trials/ProfileTrialHistorySection.swift UNBOUND/Assets.xcassets/BindingVows
git commit -m "feat(vows): profile vow section — sigil, badge track, lane seals"
```

## Task 5.4: Tear down title ladder / cosmetic-every-5 / stale callout; wire reward sequence

**Files:**
- Delete: `UNBOUND/Services/Trials/TitleThresholdEvaluator.swift` *(vow usage only — see caution)*
- Modify: `UNBOUND/Services/Trials/WeeklyVowRewards.swift` (drop `cosmeticProgress`)
- Modify: `UNBOUND/Models/WorkoutRewardSequence.swift` (`WeeklyVowCompletionBonus` — drop cosmetic/penalty fields)
- Modify: `UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView*` — vow callout shows token win + sigil seal
- Test: `UNBOUNDTests/Services/TrialsServiceTests.swift`, reward-sequence tests

- [ ] **Step 1: Caution check before deleting `TitleThresholdEvaluator`**

`TitleThresholdEvaluator` is also referenced by the Squads system (`SquadTitleThresholdEvaluator`, `SquadTitleService`, `SquadLoopReconciler`). Grep:
```bash
grep -rn "TitleThresholdEvaluator" UNBOUND --include="*.swift"
```
If the **vow** `TitleThresholdEvaluator` (`UNBOUND/Services/Trials/TitleThresholdEvaluator.swift`) is distinct from the Squad one, and the vow seal path no longer calls it (removed in Task 2.4), delete only the Trials file. **Do not** touch `SquadTitleThresholdEvaluator`. If a single shared evaluator is used by both, do NOT delete it — only remove the vow-path call (already done in 2.4) and leave the type.

- [ ] **Step 2: Write the failing test** (callout reflects token win, no cosmetic/penalty)

```swift
func testCompletionBonusIsTokenWinNoCosmeticNoPenalty() {
    let card = WeeklyVowCard(id: "vow-x", lane: .engine, bet: .medium,
        displayName: "Long Road Vow", blurb: "Two sessions.",
        target: VowTarget(count: 2, noun: "easy cardio session"))
    let bonus = WeeklyVowCompletionBonusCatalog.bonus(
        for: WeeklyVow(id: card.id, userId: "u", weekStart: Date(timeIntervalSince1970: 1_700_000_000),
                       chosenCard: card, capstoneState: .windowOpen, completedAt: nil),
        performanceLog: nil, // adapt: see executor note
        completionCountAfter: 1
    )
    XCTAssertEqual(bonus.overallLevelXP, VowBet.medium.winXP) // 100
    XCTAssertNil(bonus.penaltyAppliedXP)
}
```
> **Executor note:** Task 4.4 removed `PerformanceLog` from the seal path. Refactor `WeeklyVowCompletionBonusCatalog.bonus(...)` to take `(vow:completionCountAfter:)` only — drop the `performanceLog` param entirely — and update this test accordingly. The bonus no longer needs a log.

- [ ] **Step 3: Implement teardown**

- `WeeklyVowCompletionBonus` (in `WorkoutRewardSequence.swift`): remove `cosmeticProgress`, `baseOverallLevelXP`, `penaltyAppliedXP`, `shareCard`. Keep `overallLevelXP` + `badgeProgress`. Update its initializer and every reader.
- `WeeklyVowRewards.swift`: `bonus(...)` returns only `overallLevelXP: vow.chosenCard.bet.winXP` + `badgeProgress`. Delete `WeeklyVowShareCardDescriptor` if now unused (grep).
- Reward sequence views (`WorkoutRewardSequenceView+BeatPages.swift`, `+Readouts.swift`): the vow callout beat shows "{displayName} Sealed · +{winXP} XP" and a `VowSigilView` seal flourish; remove cosmetic/title-ladder readouts. Keep the recent "don't restate total XP" trim intact.
- Re-add the reward-sequence trigger from the seal path: when `.weeklyVowCompleted` carries a sealed vow, build a `WeeklyVowRewardCallout` (token win + lane + bet) and attach to the next `WorkoutRewardSequenceSummary` (or present a standalone vow-sealed beat). Wire through the observer that replaced `ActiveWorkoutContainerView`'s old `applyWeeklyVowBonus`.

- [ ] **Step 4: `xcodegen generate`, run the vow + reward suites, verify pass.** Final teardown grep:
```bash
grep -rn "cosmeticProgress\|cosmetic-every\|CurrencyWalletStore.*weeklyVow\|titleUnlocked.*vow\|completionBonusOverallLevelXP\|missedPenaltyOverallLevelXP" UNBOUND UNBOUNDTests --include="*.swift"
```
Expected: no vow matches (the `WeeklyVowKind` XP getters were already deleted in Phase 2).

- [ ] **Step 5: Phase-5 device gate + final commit**
```bash
git add UNBOUND/Services/Trials/WeeklyVowRewards.swift UNBOUND/Models/WorkoutRewardSequence.swift \
        UNBOUND/Views/Components/Unbound \
        UNBOUNDTests/Services/TrialsServiceTests.swift
git rm UNBOUND/Services/Trials/TitleThresholdEvaluator.swift   # ONLY if vow-distinct per Step 1
git commit -m "feat(vows): token-win reward callout; tear down title ladder + cosmetic drip"
```

---

# Final verification (whole-feature)

- [ ] **Full test suite green:**
  ```bash
  set -o pipefail
  xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' \
    -derivedDataPath /private/tmp/unbound-dd-vows CODE_SIGNING_ALLOWED=NO 2>&1 \
    | grep -E "Test Suite 'All tests' (passed|failed)|error:|BUILD (SUCCEEDED|FAILED)"
  ```
- [ ] **Device-arch build green** (Conventions command).
- [ ] **Spec success-criteria walk (spec §12):**
  - Breaking a vow withholds the next session's XP and never de-levels — covered by Tasks 1.3/1.4 tests.
  - Skipping costs nothing — `skipThisWeek` adds no debt (existing behavior, preserved).
  - Vows mint no cosmetics/titles/currency — Task 5.4 teardown + grep.
  - Recovery/Engine auto-complete from logs (Task 4.1); Fuel via self-report feeding only the vow (Tasks 4.2 guardrail test).
  - Cards from the curated pool, 3 spanning lanes/bets (Task 3.2).
  - Subjective "real weekly bet" — screenshot-verify the picker + active card + sealed reward beat on-sim.
- [ ] **No legacy symbols remain:**
  ```bash
  grep -rn "WeeklyVowKind\|WeeklyVowTheme\|WeeklyVowGenerator\|WeeklyVowTrainingBuilder\|pendingVowPenaltyXP\|recordCompletedVowWork\|ember\|overdrive\|apex" UNBOUND/Services/Trials UNBOUND/Models/Trial*.swift --include="*.swift"
  ```
  Expected: only legacy decode-only `CodingKeys` cases.

---

## Deferred (explicitly out of this plan, per spec §13)

- Larger bank-pool content expansion (beyond the 9-card starter).
- Final illustrated Vow Sigil + lane seal art (this plan ships functional vector interims; respect [[banner-art-is-anime-jrpg]] + pixel-council color check).
- Targeting-algorithm tuning beyond the simple neglected-lane bias.
- Exact Fuel anchor taxonomy (specific foods/habits) — the UI logs generic anchors today.
- Heavier proof for self-report lanes (only if gaming appears).
