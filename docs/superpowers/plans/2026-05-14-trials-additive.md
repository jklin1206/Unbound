# Trials (Additive) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Weekly emphasis-lens trial system — pick 1 of 3 horizontal cards, get soft RPE bump suggestions on aligned exercises, earn Title + axis boost on capstone completion. Preserve session-flow Home.

**Architecture:** Reuse models/services from `trials-impl` reference branch (Trial, TrialCard, TrialTheme, TrialCapstone, TrialsService, TrialGenerator, CapstoneCatalog, TitleCatalog, TitleThresholdEvaluator). Add new UI: TrialCardView, TrialPickerSheet (3 horizontal cards via TabView.page), ActiveTrialCard for contextualStack, TrialCapstoneToast, ProfileTrialHistorySection. WorkoutLogService hooks TrialsService.evaluateCapstoneFromLog. SESSION PLAN exercises get TRIAL tag + +1 RPE chip on aligned axis matches.

**Tech Stack:** Swift 5.9+, SwiftUI iOS 17+, XCTest, UserDefaults persistence, NotificationCenter, existing Title/Attribute infrastructure from #1+#4.

**Spec:** [`docs/superpowers/specs/2026-05-14-trials-additive-design.md`](../specs/2026-05-14-trials-additive-design.md).

**Reference branch:** `/Users/jlin/Documents/toji/UNBOUND-trials/` — copy verbatim where indicated.

**Worktree:** Create `/Users/jlin/Documents/toji/UNBOUND-trials-v2` on new branch `trials-v2` off `program-redesign` HEAD.

---

## File Structure

### CREATE (copy from reference unless noted)

```
UNBOUND/Models/
├── TrialTheme.swift                      (copy)
├── TrialCardKind.swift                   (copy)
├── TrialCard.swift                       (copy)
├── Trial.swift                           (copy)
├── TrialCapstone.swift                   (copy)
└── TrialsState.swift                     (copy)

UNBOUND/Services/Trials/
├── CapstoneCatalog.swift                 (copy)
├── PrestigeCapstoneCatalog.swift         (copy)
├── TitleCatalog.swift                    (copy — Trial Titles only; doesn't conflict with existing Title system)
├── TitleThresholdEvaluator.swift         (copy)
├── TrialGenerator.swift                  (copy — deterministic 3-card pick)
├── TrialsService.swift                   (copy)
├── TrialsServiceProtocol.swift           (copy)
├── TrialsStore.swift                     (copy)
└── TrialsNotificationScheduler.swift     (copy — optional, decide in Phase 6)

UNBOUND/Views/Trials/
├── TrialCardView.swift                   (NEW — single card)
├── TrialPickerSheet.swift                (NEW — 3 horizontal cards)
├── ActiveTrialCard.swift                 (NEW — compact card for Home contextualStack)
├── TrialCapstoneToast.swift              (NEW — payoff overlay)
└── TrialPickerPromptCard.swift           (NEW — "Pick this week's trial" trigger)

UNBOUND/Views/Profile/
└── ProfileTrialHistorySection.swift      (NEW)

UNBOUNDTests/Models/
├── TrialCardKindTests.swift              (copy)
└── TrialThemeTests.swift                 (copy)

UNBOUNDTests/Services/
├── TrialsStoreTests.swift                (copy)
├── TrialsServiceTests.swift              (copy)
└── TrialGeneratorTests.swift             (copy)
```

### MODIFY

```
UNBOUND/Services/WorkoutLog/WorkoutLogService.swift             (hook TrialsService.evaluateCapstoneFromLog after AttributeService.ingest)
UNBOUND/Services/Attributes/AttributeService.swift              (add applyBoost(axis:amount:userId:) method)
UNBOUND/Services/ServiceContainer.swift                          (wire TrialsService)
UNBOUND/Models/AttributeRankUpEvent.swift                        (add .trialPicked / .trialCapstoneCompleted / .trialExpired notifications)
UNBOUND/Views/Home/UnboundHomeView.swift                         (insert TrialPickerPromptCard OR ActiveTrialCard in contextualStack; SESSION PLAN row TRIAL tags + RPE bumps)
UNBOUND/Views/Profile/ProfileView.swift                          (insert ProfileTrialHistorySection)
UNBOUND/App/AniBodyApp.swift                                     (Monday-rollover hook in .task)
```

### NOT TOUCHED

- Session-flow Home modules (Move/Foundation/TODAY STATUS/BEGIN SESSION/SESSION PLAN structure/COACH CUE/WEEK PATH/HomeBuildChipCard/ScanDueCard)
- ScanCheckpoint pipeline (#3)
- SkillTier pipeline (#4)
- Squads (#6 separate)

---

## Standing rules

1. All subagent dispatches `model: "sonnet"` or higher.
2. SourceKit cross-file errors are NOISE. `xcodebuild` is authoritative.
3. `xcodegen` after any new Swift file.
4. Build: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build`
5. Reference branch: `/Users/jlin/Documents/toji/UNBOUND-trials/` — literal `cp` for salvageable files.
6. **AI never grades the body.** Trials' COACH CUE additions use sonnet for higher-stakes copy.
7. **Don't touch session-flow Home modules.**
8. **Soft emphasis only on SESSION PLAN.** TRIAL tag + RPE chip. Never restructure the program.

---

# Phase 1 — Pre-flight

## Task 1.1: Worktree + baseline

- [ ] **Step 1: Create worktree**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git worktree add /Users/jlin/Documents/toji/UNBOUND-trials-v2 -b trials-v2 program-redesign
```

- [ ] **Step 2: Copy Secrets**

```bash
cp /Users/jlin/Documents/toji/UNBOUND/UNBOUND/Services/Secrets/Secrets.swift /Users/jlin/Documents/toji/UNBOUND-trials-v2/UNBOUND/Services/Secrets/Secrets.swift
```

- [ ] **Step 3: Baseline build + test**

```bash
cd /Users/jlin/Documents/toji/UNBOUND-trials-v2
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: TEST SUCCEEDED with 5 pre-existing failures. Note baseline count.

---

# Phase 2 — Models

## Task 2.1: TrialTheme + TrialCardKind

```bash
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Models/TrialTheme.swift UNBOUND/Models/TrialTheme.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Models/TrialCardKind.swift UNBOUND/Models/TrialCardKind.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUNDTests/Models/TrialThemeTests.swift UNBOUNDTests/Models/TrialThemeTests.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUNDTests/Models/TrialCardKindTests.swift UNBOUNDTests/Models/TrialCardKindTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TrialThemeTests -only-testing:UNBOUNDTests/TrialCardKindTests 2>&1 | tail -8
git add UNBOUND/Models/TrialTheme.swift UNBOUND/Models/TrialCardKind.swift UNBOUNDTests/Models/TrialThemeTests.swift UNBOUNDTests/Models/TrialCardKindTests.swift
git commit -m "feat(trials): add TrialTheme + TrialCardKind models + tests"
```

If reference files reference types we deleted (LiftRank, RegionRank, etc.), strip those — replace with trunk equivalents (SkillTier, BuildIdentity, AttributeKey).

## Task 2.2: TrialCard + Trial + TrialCapstone + TrialsState

```bash
for f in TrialCard Trial TrialCapstone TrialsState; do
    cp "/Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Models/${f}.swift" "UNBOUND/Models/${f}.swift"
done
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Models/TrialCard.swift UNBOUND/Models/Trial.swift UNBOUND/Models/TrialCapstone.swift UNBOUND/Models/TrialsState.swift
git commit -m "feat(trials): add TrialCard + Trial + TrialCapstone + TrialsState models"
```

---

# Phase 3 — Catalogs + Title eval

## Task 3.1: CapstoneCatalog + PrestigeCapstoneCatalog

```bash
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/CapstoneCatalog.swift UNBOUND/Services/Trials/CapstoneCatalog.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/PrestigeCapstoneCatalog.swift UNBOUND/Services/Trials/PrestigeCapstoneCatalog.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/Trials/CapstoneCatalog.swift UNBOUND/Services/Trials/PrestigeCapstoneCatalog.swift
git commit -m "feat(trials): add Capstone catalogs (aligned + prestige variants)"
```

## Task 3.2: TitleCatalog + TitleThresholdEvaluator

These are Trial-specific titles (not the same as SkillTier titles from #4 — separate Title namespace).

```bash
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/TitleCatalog.swift UNBOUND/Services/Trials/TitleCatalog.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/TitleThresholdEvaluator.swift UNBOUND/Services/Trials/TitleThresholdEvaluator.swift
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/Trials/TitleCatalog.swift UNBOUND/Services/Trials/TitleThresholdEvaluator.swift
git commit -m "feat(trials): add Title catalog + threshold evaluator for trial rewards"
```

If `TitleCatalog` conflicts with an existing `Title` system (from #4 SkillTier), namespace it as `TrialTitleCatalog` and `TrialTitleID`. Verify by searching:
```bash
grep -rn "struct TitleID\|enum TitleID\|class TitleCatalog" UNBOUND/ --include="*.swift" | head
```

---

# Phase 4 — Generator + Service

## Task 4.1: TrialGenerator + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/TrialGenerator.swift UNBOUND/Services/Trials/TrialGenerator.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUNDTests/Services/TrialGeneratorTests.swift UNBOUNDTests/Services/TrialGeneratorTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TrialGeneratorTests 2>&1 | tail -8
git add UNBOUND/Services/Trials/TrialGenerator.swift UNBOUNDTests/Services/TrialGeneratorTests.swift
git commit -m "feat(trials): add TrialGenerator (deterministic 3-card weekly pick)"
```

## Task 4.2: TrialsStore + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/TrialsStore.swift UNBOUND/Services/Trials/TrialsStore.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUNDTests/Services/TrialsStoreTests.swift UNBOUNDTests/Services/TrialsStoreTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TrialsStoreTests 2>&1 | tail -8
git add UNBOUND/Services/Trials/TrialsStore.swift UNBOUNDTests/Services/TrialsStoreTests.swift
git commit -m "feat(trials): add TrialsStore (UserDefaults persistence)"
```

## Task 4.3: TrialsService + protocol + tests

```bash
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/TrialsServiceProtocol.swift UNBOUND/Services/Trials/TrialsServiceProtocol.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUND/Services/Trials/TrialsService.swift UNBOUND/Services/Trials/TrialsService.swift
cp /Users/jlin/Documents/toji/UNBOUND-trials/UNBOUNDTests/Services/TrialsServiceTests.swift UNBOUNDTests/Services/TrialsServiceTests.swift
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/TrialsServiceTests 2>&1 | tail -10
git add UNBOUND/Services/Trials/TrialsService.swift UNBOUND/Services/Trials/TrialsServiceProtocol.swift UNBOUNDTests/Services/TrialsServiceTests.swift
git commit -m "feat(trials): add TrialsService + protocol + tests"
```

If `TrialsService` uses APIs that no longer exist on trunk (e.g. references LiftRank evaluation), adapt to use trunk types (SkillTier, AttributeProfile, etc.).

---

# Phase 5 — Notification names + AttributeService.applyBoost

## Task 5.1: Add notification names

**Files:**
- Modify: `UNBOUND/Models/AttributeRankUpEvent.swift`

- [ ] **Step 1: Add to the existing Notification.Name extension**

Find the extension in `UNBOUND/Models/AttributeRankUpEvent.swift`:

```bash
grep -n "extension Notification.Name" UNBOUND/Models/AttributeRankUpEvent.swift
```

Inside it, append:

```swift
static let trialPicked = Notification.Name("unbound.trialPicked")
static let trialCapstoneCompleted = Notification.Name("unbound.trialCapstoneCompleted")
static let trialExpired = Notification.Name("unbound.trialExpired")
```

- [ ] **Step 2: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Models/AttributeRankUpEvent.swift
git commit -m "feat(trials): add trial notification names"
```

## Task 5.2: AttributeService.applyBoost method

**Files:**
- Modify: `UNBOUND/Services/Attributes/AttributeService.swift` + protocol + mock
- Test: `UNBOUNDTests/Services/AttributeServiceBoostTests.swift`

- [ ] **Step 1: Add to protocol**

In `UNBOUND/Services/Attributes/AttributeServiceProtocol.swift`, append:

```swift
/// Add a one-time boost to the given axis. Used by Trials capstone payoff.
/// Posts .attributeRankUpEvent if the boost crosses a tier threshold.
func applyBoost(axis: AttributeKey, amount: Double, userId: String) async
```

- [ ] **Step 2: Implement in production**

In `UNBOUND/Services/Attributes/AttributeService.swift`:

```swift
func applyBoost(axis: AttributeKey, amount: Double, userId: String) async {
    var profile = store.load(userId: userId) ?? AttributeProfile.empty(userId: userId, at: .now)
    var value = profile.value(for: axis)
    let priorTier = value.rankTitle
    value.current = min(100, value.current + amount)
    value.peak = max(value.peak, value.current)
    profile.set(value, for: axis)
    store.save(profile, userId: userId)

    if value.rankTitle != priorTier {
        let event = AttributeRankUpEvent(
            axis: axis,
            fromTitle: priorTier,
            toTitle: value.rankTitle,
            fromSubRank: priorTier == .initiate ? .eMinus : .e,
            toSubRank: .e,
            crossedAt: .now
        )
        NotificationCenter.default.post(name: .attributeRankUp, object: event)
    }
}
```

(Adapt fields to actual `AttributeProfile` / `AttributeValue` shape. If `.set(_:for:)` doesn't exist, modify the dict directly.)

- [ ] **Step 3: Mock impl**

In `AttributeService.swift` (where MockAttributeService lives):

```swift
func applyBoost(axis: AttributeKey, amount: Double, userId: String) async {
    // Mock: just record the call for test assertions
    boostCalls.append((axis: axis, amount: amount, userId: userId))
}

var boostCalls: [(axis: AttributeKey, amount: Double, userId: String)] = []
```

- [ ] **Step 4: Test**

```swift
// UNBOUNDTests/Services/AttributeServiceBoostTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class AttributeServiceBoostTests: XCTestCase {
    func testApplyBoostIncreasesAxisValue() async {
        let suiteName = "AttributeBoostTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AttributeProfileStore(defaults: defaults)
        let database = MockDatabaseService()
        let service = AttributeService(store: store, database: database, catalog: AttributeCatalog.shared)
        let userId = "boost-test"

        var profile = AttributeProfile.empty(userId: userId, at: .now)
        var power = profile.value(for: .power)
        power.current = 30
        profile.set(power, for: .power)
        store.save(profile, userId: userId)

        await service.applyBoost(axis: .power, amount: 5, userId: userId)

        let updated = store.load(userId: userId)
        XCTAssertEqual(updated?.value(for: .power).current ?? 0, 35, accuracy: 0.01)
    }

    func testBoostClampedTo100() async {
        let suiteName = "AttributeBoostClamp-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AttributeProfileStore(defaults: defaults)
        let database = MockDatabaseService()
        let service = AttributeService(store: store, database: database, catalog: AttributeCatalog.shared)
        let userId = "clamp-test"

        var profile = AttributeProfile.empty(userId: userId, at: .now)
        var power = profile.value(for: .power)
        power.current = 98
        profile.set(power, for: .power)
        store.save(profile, userId: userId)

        await service.applyBoost(axis: .power, amount: 10, userId: userId)

        let updated = store.load(userId: userId)
        XCTAssertEqual(updated?.value(for: .power).current ?? 0, 100, accuracy: 0.01)
    }
}
```

(Adapt `AttributeProfile.empty(userId:at:)` and `.set(_:for:)` to actual shape.)

- [ ] **Step 5: Commit**

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/AttributeServiceBoostTests 2>&1 | tail -8
git add UNBOUND/Services/Attributes/AttributeService.swift UNBOUND/Services/Attributes/AttributeServiceProtocol.swift UNBOUNDTests/Services/AttributeServiceBoostTests.swift
git commit -m "feat(attr): AttributeService.applyBoost for trial capstone payoff"
```

---

# Phase 6 — WorkoutLogService hook + ServiceContainer wiring

## Task 6.1: Hook TrialsService.evaluateCapstoneFromLog into saveLog

**Files:**
- Modify: `UNBOUND/Services/WorkoutLog/WorkoutLogService.swift`

- [ ] **Step 1: Find existing hooks**

```bash
grep -n "AttributeService.shared.ingest\|RankService.shared.evaluateTierCrossings\|logger.log" UNBOUND/Services/WorkoutLog/WorkoutLogService.swift
```

- [ ] **Step 2: Add Trials hook**

After the RankService tier crossings evaluation and before `logger.log(...)`, add:

```swift
// Trials: evaluate capstone progress from this log.
// Fires .trialCapstoneCompleted notification if capstone cleared.
await TrialsService.shared.evaluateCapstoneFromLog(log: log, userId: log.userId)
```

If `TrialsService.evaluateCapstoneFromLog` has a different signature (e.g. takes `[ExerciseLogEntry]` instead of `WorkoutLog`), adapt:

```bash
grep "func evaluateCapstone" UNBOUND/Services/Trials/TrialsService.swift
```

- [ ] **Step 3: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/WorkoutLog/WorkoutLogService.swift
git commit -m "feat(trials): hook TrialsService.evaluateCapstoneFromLog into WorkoutLogService.saveLog"
```

## Task 6.2: Wire TrialsService into ServiceContainer

**Files:**
- Modify: `UNBOUND/Services/ServiceContainer.swift`

- [ ] **Step 1: Add slot**

```swift
let trials: any TrialsServiceProtocol
```

In init params:
```swift
trials: any TrialsServiceProtocol = TrialsService.shared,
```

In init body:
```swift
self.trials = trials
```

In `.mock` if present, use `MockTrialsService()` or whatever the reference branch's mock is called.

- [ ] **Step 2: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Services/ServiceContainer.swift
git commit -m "feat(trials): wire TrialsService into ServiceContainer"
```

## Task 6.3: Monday-rollover hook in AniBodyApp

**Files:**
- Modify: `UNBOUND/App/AniBodyApp.swift`

- [ ] **Step 1: Find existing .task block**

```bash
grep -n "backfillFromExistingLogs\|migrateIfNeeded" UNBOUND/App/AniBodyApp.swift
```

- [ ] **Step 2: Add expireTrialIfNeeded call**

Inside the existing `.task` block, after attribute backfill and skill tier migration:

```swift
await TrialsService.shared.expireTrialIfNeeded(userId: userId)
```

(Adapt to actual method name.)

- [ ] **Step 3: Commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/App/AniBodyApp.swift
git commit -m "feat(trials): wire TrialsService.expireTrialIfNeeded into app launch task"
```

---

# Phase 7 — TrialCardView (single card)

## Task 7.1: TrialCardView

**Files:**
- Create: `UNBOUND/Views/Trials/TrialCardView.swift`

```swift
// UNBOUND/Views/Trials/TrialCardView.swift
import SwiftUI

/// Single trial card. Used inside TrialPickerSheet (horizontal swipe layout).
/// Theme color treatment is the primary visual signal.
struct TrialCardView: View {
    let card: TrialCard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // THEME tag at top
            Text(card.theme.displayName.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(card.theme.tintColor)
                .padding(.bottom, 14)

            // Title
            Text(card.title)
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 10)

            // Subtitle
            Text(card.subtitle)
                .font(Font.unbound.bodyM)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(3)
                .padding(.bottom, 20)

            Spacer()

            // Aligned axes
            VStack(alignment: .leading, spacing: 8) {
                Text("FOCUS")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                HStack(spacing: 6) {
                    ForEach(Array(card.alignedAxes), id: \.self) { axis in
                        Text(axis.shortCode)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(card.theme.tintColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(card.theme.tintColor.opacity(0.15)))
                    }
                }
            }
            .padding(.bottom, 16)

            // Capstone hint
            VStack(alignment: .leading, spacing: 6) {
                Text("CAPSTONE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(card.capstone.shortDescription)
                    .font(Font.unbound.captionM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 460)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(card.theme.tintColor.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: card.theme.tintColor.opacity(0.2), radius: 12)
    }
}
```

Adapt field names: `card.title`, `card.subtitle`, `card.alignedAxes`, `card.capstone.shortDescription`, `card.theme.tintColor`, `card.theme.displayName`. Verify against actual types:

```bash
grep -n "struct TrialCard\|var title\|var subtitle\|var alignedAxes\|var capstone" UNBOUND/Models/TrialCard.swift UNBOUND/Models/TrialTheme.swift UNBOUND/Models/TrialCapstone.swift
```

If `TrialTheme.tintColor` doesn't exist, add it as an extension in TrialTheme.swift or compute in the view.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Trials/TrialCardView.swift
git commit -m "feat(trials): add TrialCardView (single card)"
```

---

# Phase 8 — TrialPickerSheet (3 horizontal cards)

## Task 8.1: TrialPickerSheet

**Files:**
- Create: `UNBOUND/Views/Trials/TrialPickerSheet.swift`

```swift
// UNBOUND/Views/Trials/TrialPickerSheet.swift
import SwiftUI

/// Sheet presenting the 3 weekly trial cards horizontally.
/// User swipes left/right between cards. Tapping "Pick this trial"
/// activates the currently visible card.
struct TrialPickerSheet: View {
    let cards: [TrialCard]
    let onPick: (TrialCard) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 6) {
                    Text("THIS WEEK'S TRIAL")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(Color.unbound.textSecondary)
                    Text("Pick one. Carry it through the week.")
                        .font(Font.unbound.bodyM)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
                .padding(.top, 12)

                // 3 horizontal cards via TabView with PageStyle.
                // .always indicator shows the dots below.
                TabView(selection: $selectedIndex) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                        TrialCardView(card: card)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Pick button
                Button {
                    guard cards.indices.contains(selectedIndex) else { return }
                    onPick(cards[selectedIndex])
                    dismiss()
                } label: {
                    Text("Pick this trial")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.unbound.accent)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color.unbound.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Trials/TrialPickerSheet.swift
git commit -m "feat(trials): add TrialPickerSheet (3 horizontal swipeable cards)"
```

---

# Phase 9 — Active card + payoff toast + prompt card

## Task 9.1: TrialPickerPromptCard (Home contextualStack)

**Files:**
- Create: `UNBOUND/Views/Trials/TrialPickerPromptCard.swift`

```swift
// UNBOUND/Views/Trials/TrialPickerPromptCard.swift
import SwiftUI

/// Appears in Home's contextualStack when a new week starts and no trial is picked.
/// Tap opens TrialPickerSheet.
struct TrialPickerPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.unbound.accent)
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick this week's trial")
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text("3 cards · pick one · carry it through Sunday")
                        .font(Font.unbound.captionM)
                        .foregroundStyle(Color.unbound.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.unbound.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Trials/TrialPickerPromptCard.swift
git commit -m "feat(trials): add TrialPickerPromptCard for Home contextualStack"
```

## Task 9.2: ActiveTrialCard

**Files:**
- Create: `UNBOUND/Views/Trials/ActiveTrialCard.swift`

```swift
// UNBOUND/Views/Trials/ActiveTrialCard.swift
import SwiftUI

/// Appears in Home's contextualStack after user has picked a trial for the week.
/// Shows the selected trial + capstone progress hint.
struct ActiveTrialCard: View {
    let trial: Trial
    let capstoneProgress: Double  // 0...1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(trial.chosenCard.theme.displayName.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(trial.chosenCard.theme.tintColor)
                Spacer()
                if trial.isCapstoneCompleted {
                    Text("✓ CLEARED")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.accent)
                }
            }
            Text(trial.chosenCard.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(trial.chosenCard.capstone.shortDescription)
                .font(Font.unbound.captionM)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(2)
            ProgressView(value: capstoneProgress)
                .progressViewStyle(.linear)
                .tint(trial.chosenCard.theme.tintColor)
                .padding(.top, 4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(trial.chosenCard.theme.tintColor.opacity(0.4), lineWidth: 1)
        )
    }
}
```

If `Trial.isCapstoneCompleted` doesn't exist, use whatever the reference branch's completion field is.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Trials/ActiveTrialCard.swift
git commit -m "feat(trials): add ActiveTrialCard for Home contextualStack"
```

## Task 9.3: TrialCapstoneToast

**Files:**
- Create: `UNBOUND/Views/Trials/TrialCapstoneToast.swift`

```swift
// UNBOUND/Views/Trials/TrialCapstoneToast.swift
import SwiftUI

/// Toast overlay that appears when a trial capstone is completed.
/// TierBloomToast-style — restrained celebration, not a full cinematic.
struct TrialCapstoneToast: View {
    let trial: Trial

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(trial.chosenCard.theme.tintColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("CAPSTONE CLEARED")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(trial.chosenCard.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(trial.chosenCard.theme.tintColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.unbound.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(trial.chosenCard.theme.tintColor.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: trial.chosenCard.theme.tintColor.opacity(0.3), radius: 14)
    }
}

/// View modifier listening for .trialCapstoneCompleted.
/// Auto-dismisses after 3 seconds.
struct TrialCapstoneToastModifier: ViewModifier {
    @State private var visible: Trial?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let trial = visible {
                    TrialCapstoneToast(trial: trial)
                        .padding(.bottom, 80)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(trial.id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .trialCapstoneCompleted)) { note in
                guard let trial = note.object as? Trial else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    visible = trial
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeIn(duration: 0.25)) {
                        visible = nil
                    }
                }
            }
    }
}

extension View {
    func trialCapstoneToast() -> some View {
        modifier(TrialCapstoneToastModifier())
    }
}
```

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Trials/TrialCapstoneToast.swift
git commit -m "feat(trials): add TrialCapstoneToast (TierBloomToast-style payoff)"
```

---

# Phase 10 — Home integration

## Task 10.1: Wire Trial UI into UnboundHomeView contextualStack

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift`

- [ ] **Step 1: Add state**

Near other `@State` properties:

```swift
@State private var trialsState: TrialsState = TrialsState.empty
@State private var showTrialPicker = false
```

- [ ] **Step 2: Load in .task**

Inside the existing `.task` block:

```swift
if let userId = services.auth.currentUserId {
    trialsState = await services.trials.state(userId: userId)
}
```

(Adapt to actual API. Reference branch's TrialsService likely exposes `state(userId:)` or `currentTrial(userId:)` + `weeklyCards(userId:)`.)

- [ ] **Step 3: Insert in contextualStack**

Find the `contextualStack` computed property. Inside it, after the existing conditionals (Recalibrating, ScanDueCard, etc.), add:

```swift
if let activeTrial = trialsState.activeTrial {
    ActiveTrialCard(
        trial: activeTrial,
        capstoneProgress: trialsState.capstoneProgress ?? 0
    )
} else if trialsState.canPickThisWeek {
    TrialPickerPromptCard {
        showTrialPicker = true
    }
}
```

- [ ] **Step 4: Present TrialPickerSheet**

Near other `.sheet` / `.fullScreenCover` modifiers on the view root:

```swift
.sheet(isPresented: $showTrialPicker) {
    TrialPickerSheet(
        cards: trialsState.weeklyCards,
        onPick: { card in
            Task {
                guard let userId = services.auth.currentUserId else { return }
                await services.trials.pickCard(card, userId: userId)
                trialsState = await services.trials.state(userId: userId)
            }
        }
    )
}
```

- [ ] **Step 5: Apply toast modifier**

At view root, after other modifiers:

```swift
.trialCapstoneToast()
```

- [ ] **Step 6: Refresh on capstone completion**

```swift
.onReceive(NotificationCenter.default.publisher(for: .trialCapstoneCompleted)) { _ in
    Task {
        guard let userId = services.auth.currentUserId else { return }
        trialsState = await services.trials.state(userId: userId)
    }
}
```

- [ ] **Step 7: Build + verify session-flow snapshot**

```bash
xcodegen
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:UNBOUNDTests/UnboundHomeViewSessionFlowTests 2>&1 | tail -8
```

Session-flow modules MUST still render.

- [ ] **Step 8: Commit**

```bash
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "feat(trials): wire TrialPickerPromptCard + ActiveTrialCard + toast into Home"
```

## Task 10.2: SESSION PLAN row emphasis

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift` (specifically the function that renders SESSION PLAN exercise rows)

- [ ] **Step 1: Find the row function**

```bash
grep -n "consoleExercisePlan\|premiumExerciseRow\|SESSION PLAN" UNBOUND/Views/Home/UnboundHomeView.swift | head -5
```

The exercise row function likely takes an `Exercise` (or `WorkoutEntry`) and renders the row.

- [ ] **Step 2: Compute "is aligned" predicate**

Add a helper:

```swift
private func isAlignedExercise(_ exercise: Exercise) -> Bool {
    guard let activeTrial = trialsState.activeTrial else { return false }
    // The aligned axes are on the chosen card; the exercise's AttributeContribution
    // is looked up via AttributeCatalog. If any contributed axis matches the trial's
    // aligned axes, the exercise is aligned.
    let contributions = AttributeCatalog.shared.contributions(for: exercise.name)
    let exerciseAxes = Set(contributions.byAxis.filter { $0.value > 0.2 }.map { $0.key })
    return !exerciseAxes.isDisjoint(with: activeTrial.chosenCard.alignedAxes)
}
```

(Adapt `Exercise.name` and the `AttributeCatalog` API to actual signatures.)

- [ ] **Step 3: Add TRIAL tag + RPE bump chip to row**

Inside the row function, where the row's RPE/rest column renders, add a conditional:

```swift
if isAlignedExercise(exercise) {
    HStack(spacing: 4) {
        Text("TRIAL")
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(trialsState.activeTrial?.chosenCard.theme.tintColor ?? Color.unbound.accent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill((trialsState.activeTrial?.chosenCard.theme.tintColor ?? Color.unbound.accent).opacity(0.18)))
        Text("+1 RPE")
            .font(.system(size: 8, weight: .heavy, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(Color.unbound.textSecondary)
    }
}
```

Insert near the existing RPE chip rendering.

- [ ] **Step 4: Build**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "feat(trials): SESSION PLAN rows show TRIAL tag + +1 RPE chip on aligned exercises"
```

---

# Phase 11 — Profile integration

## Task 11.1: ProfileTrialHistorySection

**Files:**
- Create: `UNBOUND/Views/Profile/ProfileTrialHistorySection.swift`

```swift
// UNBOUND/Views/Profile/ProfileTrialHistorySection.swift
import SwiftUI

struct ProfileTrialHistorySection: View {
    let history: [Trial]  // most recent first

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRIAL HISTORY")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color.unbound.textSecondary)
            if history.isEmpty {
                Text("No trials completed yet.")
                    .font(Font.unbound.captionM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(history.prefix(12), id: \.id) { trial in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(trial.chosenCard.theme.tintColor)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trial.chosenCard.title)
                                .font(Font.unbound.bodyMStrong)
                                .foregroundStyle(Color.unbound.textPrimary)
                            Text(weekLabel(for: trial.startedAt))
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                        Spacer()
                        if trial.isCapstoneCompleted {
                            Text("✓")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(trial.chosenCard.theme.tintColor)
                        } else {
                            Text("—")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider().background(Color.unbound.border)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.unbound.surface))
    }

    private func weekLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "'WK' w · MMM d"
        return formatter.string(from: date).uppercased()
    }
}
```

Adapt `Trial.startedAt`, `Trial.isCapstoneCompleted` to actual field names.

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Profile/ProfileTrialHistorySection.swift
git commit -m "feat(trials): add ProfileTrialHistorySection"
```

## Task 11.2: Insert into ProfileView

**Files:**
- Modify: `UNBOUND/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Add state + load**

```swift
@State private var trialHistory: [Trial] = []
```

In `.task`:

```swift
if let userId = services.auth.currentUserId {
    trialHistory = await services.trials.history(userId: userId)
}
```

- [ ] **Step 2: Insert section in body**

After existing identity surfaces (ProfileBuildCard, ProfileScanRow), add:

```swift
ProfileTrialHistorySection(history: trialHistory)
    .padding(.horizontal)
```

- [ ] **Step 3: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Profile/ProfileView.swift
git commit -m "feat(trials): wire ProfileTrialHistorySection into ProfileView"
```

---

# Phase 12 — COACH CUE trial suggestion

## Task 12.1: Add trial-aware COACH CUE copy

**Files:**
- Modify: `UNBOUND/Views/Home/UnboundHomeView.swift` (the `coachCueAnnotation` view)

- [ ] **Step 1: Find COACH CUE rendering**

```bash
grep -n "coachCueAnnotation\|COACH CUE" UNBOUND/Views/Home/UnboundHomeView.swift | head -5
```

- [ ] **Step 2: Add trial-suggestion branch**

In the COACH CUE body, if `trialsState.activeTrial` exists AND today's workout has an aligned exercise:

```swift
private var coachCueContent: String {
    if let activeTrial = trialsState.activeTrial,
       let alignedExercise = todaysFirstAlignedExercise(for: activeTrial) {
        return "Trial: push +1 RPE on \(alignedExercise). Stop one rep before form breaks."
    }
    return coachNote?.text ?? defaultCoachCue
}

private func todaysFirstAlignedExercise(for trial: Trial) -> String? {
    guard let workout = todayProgramDay?.workout else { return nil }
    for entry in workout.mainExercises {
        if isAlignedExercise(entry) {
            return entry.name
        }
    }
    return nil
}
```

Adapt to actual workout/exercise field names.

- [ ] **Step 3: Build + commit**

```bash
xcodegen
xcodebuild build -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD" | tail -3
git add UNBOUND/Views/Home/UnboundHomeView.swift
git commit -m "feat(trials): COACH CUE suggests +1 RPE on aligned exercise when trial active"
```

---

# Phase 13 — Final regression + smoke

## Task 13.1: Full test suite

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "Executed |TEST SUCCEEDED|TEST FAILED" | tail -3
```

Expected: TEST SUCCEEDED with 5 pre-existing failures only. Test count higher than baseline (trial tests added).

## Task 13.2: Grep verification

```bash
echo "=== Trial models referenced ==="
grep -rn "TrialCard\|TrialsService\|TrialPickerSheet\|ActiveTrialCard" UNBOUND/ --include="*.swift" | head -10

echo "=== Session-flow Home preserved ==="
grep -rn "BEGIN SESSION\|SESSION PLAN\|COACH CUE\|Move\b\|Foundation" UNBOUND/Views/Home/UnboundHomeView.swift | head -10
```

## Task 13.3: Sim smoke

```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/trials-v2-final build 2>&1 | tail -3
xcrun simctl install booted /tmp/trials-v2-final/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl terminate booted com.unboundapp.ios 2>&1 | tail -1
xcrun simctl launch booted com.unboundapp.ios
sleep 5
xcrun simctl io booted screenshot /tmp/trials-v2-home.png
```

Verify Home shows session-flow + (if Monday or first launch) the TrialPickerPromptCard.

Tap the prompt card → confirm TrialPickerSheet opens with 3 swipeable cards.

## Task 13.4: Handoff doc

```bash
cat > docs/superpowers/handoff/2026-05-14-trials-v2-smoke.md <<'EOF'
# Trials (Additive) — Final Smoke

Sub-project #5 shipped on `trials-v2`. Ready for merge into `program-redesign`.

## What ships
- 3 horizontal cards picker (TabView.page, swipeable)
- Aligned/Growth/Prestige theme system
- Soft SESSION PLAN emphasis: TRIAL tag + +1 RPE chip on aligned exercises
- COACH CUE suggests +1 RPE on aligned exercise when trial active
- Capstone completion = Title unlock + +5 attribute boost on aligned axis
- TrialCapstoneToast (TierBloomToast-style payoff)
- Profile Trial History section
- Weekly rollover on Monday via AniBodyApp .task

## Session-flow Home preserved
- Move/Foundation/TODAY STATUS/BEGIN SESSION/SESSION PLAN/COACH CUE/WEEK PATH/HomeBuildChipCard/ScanDueCard all render

## Known follow-ups
- Trial card art is typographic only (no hero images per card). Could generate art per kind in future PR.
EOF
git add docs/superpowers/handoff/2026-05-14-trials-v2-smoke.md
git commit -m "chore(trials): final smoke + handoff doc — sub-project #5 ready for merge"
```

---

## Self-Review Notes

**Spec coverage:**
- ✅ TrialTheme/TrialCardKind/TrialCard/Trial/TrialCapstone/TrialsState → Phase 2
- ✅ Catalogs (Capstone, PrestigeCapstone, Title, evaluator) → Phase 3
- ✅ TrialGenerator + TrialsStore + TrialsService → Phase 4
- ✅ Notification names + AttributeService.applyBoost → Phase 5
- ✅ WorkoutLogService hook + ServiceContainer + AniBodyApp rollover → Phase 6
- ✅ TrialCardView → Phase 7
- ✅ TrialPickerSheet (3 horizontal swipeable cards) → Phase 8
- ✅ TrialPickerPromptCard + ActiveTrialCard + TrialCapstoneToast → Phase 9
- ✅ UnboundHomeView contextualStack integration → Phase 10.1
- ✅ SESSION PLAN row emphasis (TRIAL tag + RPE chip) → Phase 10.2
- ✅ ProfileTrialHistorySection → Phase 11
- ✅ COACH CUE trial suggestion → Phase 12
- ✅ Final regression + smoke → Phase 13

**Placeholder scan:** No TBD/TODO. Heavy reuse from reference branch is intentional and explicit.

**Type consistency:**
- `Trial.chosenCard` is the canonical card accessor — used in TrialCardView, ActiveTrialCard, TrialCapstoneToast, ProfileTrialHistorySection.
- `TrialCard.alignedAxes` is `Set<AttributeKey>` — used in emphasis predicate.
- `TrialTheme.tintColor` and `TrialTheme.displayName` — referenced in 3+ files; verify present on the enum during Task 2.1.

**Known soft spots:**
1. Reference branch's `TrialsService` API surface may differ from spec (e.g. `state(userId:)` vs `currentTrial(userId:)`). Implementer adapts on Phase 4.3 and propagates through subsequent integration tasks.
2. `AttributeProfile.set(_:for:)` may not be the actual method name — verify in Phase 5.2.
3. `Exercise.name` vs `Exercise.id` for catalog lookup — verify with actual codebase model.
4. SESSION PLAN row may not have a clean insert point for the TRIAL tag — adapt to actual layout in Phase 10.2.
5. `TitleCatalog` namespacing: if it conflicts with #4's title system, rename to `TrialTitleCatalog` and `TrialTitleID`.
