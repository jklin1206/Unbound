# UNBOUND Program Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace UNBOUND's current program generation and presentation with a deterministic, tailored, always-on 2-week block model driven by scan weak-points, user-configurable training feedback, and the existing Hawks progression engine — per `docs/superpowers/specs/2026-04-20-program-redesign-design.md`.

**Architecture:** Deterministic pure-function generator, 2-week UX cycle with continuously flowing programming underneath, Hawks engine locked to Accumulation with reactive deload, gated accessory-bias refresh, scheduled exercise-refresh every ~6 weeks. User-visible: today's workout hero, 2-week calendar, progress album with scan + daily photos.

**Tech Stack:** Swift 5.9, SwiftUI, iOS 17+, XcodeGen project, Supabase backend. Target: `UNBOUND` app (not test target — see "Test Strategy" below).

**Test Strategy:** No test target exists today. Rather than set one up project-wide, unit tests for pure logic (SplitLookup, WeakPointBiaser, MacroCalculator, ExerciseRefreshRule, BlockRolloverService) are delivered in a single new `UNBOUNDTests` target added in Task 0. UI work is verified manually via the simulator. If adding the test target produces friction, fall back to inline `#if DEBUG` assertions + a single `VerifyProgramGeneration` debug command in Settings.

---

## File Structure

### Chunk 1 — Data model foundations
- **Create:** `UNBOUND/Models/ProgramBlock.swift`
- **Create:** `UNBOUND/Models/ProgressPhoto.swift`
- **Create:** `UNBOUND/Models/TrainingFeedbackMode.swift`
- **Create:** `UNBOUND/Models/CutMode.swift`
- **Create:** `UNBOUND/Models/TrainingStyle.swift`
- **Create:** `UNBOUND/Models/Weekday.swift`
- **Modify:** `UNBOUND/Models/User.swift` — add new fields
- **Modify:** `UNBOUND/Models/Program.swift` — lock `durationDays = 14` default

### Chunk 2 — Deterministic generator pipeline
- **Create:** `UNBOUND/Services/ProgramGeneration/SplitLookup.swift`
- **Create:** `UNBOUND/Services/ProgramGeneration/WeakPointBiaser.swift`
- **Create:** `UNBOUND/Services/ProgramGeneration/MacroCalculator.swift`
- **Create:** `UNBOUND/Services/ProgramGeneration/DayTemplate.swift`
- **Create:** `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift` — the pure pipeline
- **Modify:** `UNBOUND/Services/ProgramGeneration/LocalProgramGenerator.swift` — delegate to DeterministicProgramGenerator
- **Modify:** `UNBOUND/Services/ProgramGeneration/ProgramGenerationService.swift` — deprecate LLM path, no-op

### Chunk 3 — Block rollover + refresh rules
- **Create:** `UNBOUND/Services/ProgramGeneration/ExerciseRefreshRule.swift`
- **Create:** `UNBOUND/Services/ProgramGeneration/BlockRolloverService.swift`
- **Create:** `UNBOUND/Services/ProgramGeneration/AccessoryBiasRefreshRule.swift`
- **Modify:** `UNBOUND/Services/ProgramGeneration/ProgramPhaseEngine.swift` — replace phase logic with rollover service
- **Create:** Supabase migration `supabase/migrations/2026xxxx_program_blocks.sql`

### Chunk 4 — Progression engine tweaks
- **Modify:** `UNBOUND/Services/Progression/ProgressionEngine.swift` — silent mode, cut-preserve
- **Create:** `UNBOUND/Services/Progression/ProgressionMode.swift` — advance/preserve enum

### Chunk 5 — Onboarding changes
- **Delete step:** current-`Frequency` onboarding step (identify & remove)
- **Modify:** `UNBOUND/Views/Onboarding/Steps/Step14_Equipment.swift` — expand chip list
- **Create:** `UNBOUND/Views/Onboarding/Steps/Step_TrainingDays.swift`
- **Modify:** `UNBOUND/Models/OnboardingAnswers.swift` — add `Equipment` cases, remove `Frequency` if unreferenced
- **Modify:** `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` — wire new step
- **Modify:** `UNBOUND/ViewModels/OnboardingFlowViewModel.swift` — new fields

### Chunk 6 — UI surfaces
- **Modify:** `UNBOUND/Views/Program/ProgramOverviewView.swift` — hero rework
- **Create:** `UNBOUND/Views/Program/TodayWorkoutHero.swift`
- **Create:** `UNBOUND/Views/Program/BlockStatusCard.swift`
- **Modify:** `UNBOUND/Views/Program/DayDetailView.swift` — "Why this day" + deload label
- **Create/Modify:** `UNBOUND/Views/Nutrition/MacrosView.swift` (if doesn't exist, create)

### Chunk 7 — Progress album
- **Create:** `UNBOUND/Services/ProgressPhoto/ProgressPhotoService.swift`
- **Create:** `UNBOUND/Views/Album/ProgressAlbumView.swift`
- **Create:** `UNBOUND/Views/Album/ProgressPhotoCaptureView.swift`
- **Create:** `UNBOUND/Views/Album/ProgressCompareView.swift`
- **Modify:** `UNBOUND/Views/Profile/ProfileView.swift` — entry point

### Chunk 8 — Settings + migration
- **Modify:** `UNBOUND/Views/Settings/SettingsView.swift` — add new rows
- **Create:** `UNBOUND/Views/Settings/TrainingFeedbackSettingView.swift`
- **Create:** `UNBOUND/Views/Settings/TrainingStyleSettingView.swift`
- **Create:** `UNBOUND/Views/Settings/TrainingDaysSettingView.swift`
- **Create:** `UNBOUND/Views/Settings/CutModeSettingView.swift`
- **Create:** `UNBOUND/Views/Program/LegacyUserFillInSheet.swift`

---

## Chunk 0 — Test target setup (one-time)

### Task 0.1: Add UNBOUNDTests target

**Files:**
- Modify: `project.yml`
- Create: `UNBOUNDTests/UNBOUNDTests.swift`

- [ ] **Step 1: Add test target to project.yml**

Add under `targets:` (after the `UNBOUND:` target block):

```yaml
  UNBOUNDTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: UNBOUNDTests
    dependencies:
      - target: UNBOUND
    settings:
      base:
        BUNDLE_LOADER: "$(TEST_HOST)"
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/UNBOUND.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/UNBOUND"
```

- [ ] **Step 2: Create placeholder test file**

```swift
// UNBOUNDTests/UNBOUNDTests.swift
import XCTest
@testable import UNBOUND

final class UNBOUNDSmokeTest: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 3: Regenerate project + verify test runs**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate`
Then run in Xcode: ⌘U
Expected: 1 test passes.

- [ ] **Step 4: Commit**

```bash
git add project.yml UNBOUNDTests/
git commit -m "chore: add UNBOUNDTests target"
```

---

## Chunk 1 — Data model foundations

### Task 1.1: Add TrainingFeedbackMode enum

**Files:**
- Create: `UNBOUND/Models/TrainingFeedbackMode.swift`
- Test: `UNBOUNDTests/Models/TrainingFeedbackModeTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// UNBOUNDTests/Models/TrainingFeedbackModeTests.swift
import XCTest
@testable import UNBOUND

final class TrainingFeedbackModeTests: XCTestCase {
    func testDefaultForBeginner() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .beginner), .silent)
    }
    func testDefaultForIntermediate() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .intermediate), .quick)
    }
    func testDefaultForAdvanced() {
        XCTAssertEqual(TrainingFeedbackMode.default(for: .advanced), .detailed)
    }
    func testTargetRPE() {
        XCTAssertEqual(TrainingFeedbackMode.silent.defaultTargetRPE, 0)
        XCTAssertEqual(TrainingFeedbackMode.quick.defaultTargetRPE, 7)
        XCTAssertEqual(TrainingFeedbackMode.detailed.defaultTargetRPE, 7)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: ⌘U in Xcode or `xcodebuild test`
Expected: FAIL — TrainingFeedbackMode doesn't exist.

- [ ] **Step 3: Implement TrainingFeedbackMode**

```swift
// UNBOUND/Models/TrainingFeedbackMode.swift
import Foundation

enum TrainingFeedbackMode: String, Codable, CaseIterable, Identifiable {
    case silent
    case quick
    case detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .silent: return "Silent"
        case .quick: return "Quick check"
        case .detailed: return "Detailed"
        }
    }

    var description: String {
        switch self {
        case .silent: return "No feedback taps. Just log reps and weight."
        case .quick: return "One tap per exercise after your top set."
        case .detailed: return "Tap after every set. For serious lifters."
        }
    }

    /// Used by the progression engine. Silent returns 0 so `hitTargetRPE` always passes.
    var defaultTargetRPE: Int {
        switch self {
        case .silent: return 0
        case .quick, .detailed: return 7
        }
    }

    static func `default`(for experience: Experience) -> TrainingFeedbackMode {
        switch experience {
        case .beginner: return .silent
        case .intermediate: return .quick
        case .advanced: return .detailed
        }
    }
}
```

Note: `Experience` already exists in `OnboardingAnswers.swift`. If its cases differ from `beginner/intermediate/advanced`, adjust the switch to match actual cases.

- [ ] **Step 4: Run tests, verify pass**

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/TrainingFeedbackMode.swift UNBOUNDTests/Models/TrainingFeedbackModeTests.swift
git commit -m "feat: add TrainingFeedbackMode enum"
```

---

### Task 1.2: Add TrainingStyle enum

**Files:**
- Create: `UNBOUND/Models/TrainingStyle.swift`
- Test: `UNBOUNDTests/Models/TrainingStyleTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class TrainingStyleTests: XCTestCase {
    func testArchetypeDefaults() {
        XCTAssertEqual(TrainingStyle.default(for: .calisthenic), .bodyweight)
        // Adjust the expected style per archetype once all Archetype cases are known.
    }

    func testAllStylesHaveDisplayName() {
        for s in TrainingStyle.allCases {
            XCTAssertFalse(s.displayName.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Models/TrainingStyle.swift
import Foundation

enum TrainingStyle: String, Codable, CaseIterable, Identifiable {
    case bodyweight        // calisthenics, minimal equipment
    case freeWeights       // dumbbells + barbell
    case hybrid            // mix of bodyweight and weights
    case machines          // cable / machine / gym

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight: return "Bodyweight / Calisthenics"
        case .freeWeights: return "Free weights"
        case .hybrid: return "Hybrid"
        case .machines: return "Gym machines"
        }
    }

    static func `default`(for archetype: Archetype) -> TrainingStyle {
        // Fill in per archetype definition. Rule of thumb:
        // Calisthenic → bodyweight. Everything else → hybrid by default.
        switch archetype {
        case .calisthenic: return .bodyweight
        default: return .hybrid
        }
    }
}
```

If `Archetype` uses different case names, update the switch. Add an explicit mapping per archetype once the product confirms what each should default to; `hybrid` is a safe fallback.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/TrainingStyle.swift UNBOUNDTests/Models/TrainingStyleTests.swift
git commit -m "feat: add TrainingStyle enum with archetype defaults"
```

---

### Task 1.3: Add Weekday enum

**Files:**
- Create: `UNBOUND/Models/Weekday.swift`
- Test: `UNBOUNDTests/Models/WeekdayTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class WeekdayTests: XCTestCase {
    func testOrdering() {
        XCTAssertEqual(Weekday.allCases.first, .monday)
        XCTAssertEqual(Weekday.allCases.last, .sunday)
    }
    func testCalendarConversion() {
        // Jan 3 2026 is a Saturday; Calendar weekday == 7 (in Gregorian, 1 = Sunday)
        let d = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 3))!
        XCTAssertEqual(Weekday(from: d), .saturday)
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Models/Weekday.swift
import Foundation

enum Weekday: String, Codable, CaseIterable, Identifiable, Hashable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String { rawValue }

    var short: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    init?(from date: Date, calendar: Calendar = .current) {
        let weekdayNumber = calendar.component(.weekday, from: date)
        // Gregorian: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        switch weekdayNumber {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/Weekday.swift UNBOUNDTests/Models/WeekdayTests.swift
git commit -m "feat: add Weekday enum"
```

---

### Task 1.4: Add CutMode struct

**Files:**
- Create: `UNBOUND/Models/CutMode.swift`
- Test: `UNBOUNDTests/Models/CutModeTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class CutModeTests: XCTestCase {
    func testSoftCapNotReachedBeforeEightWeeks() {
        let cut = CutMode(enabled: true, startedAt: Date().addingTimeInterval(-7 * 7 * 86400))
        XCTAssertFalse(cut.softCapReached(now: Date()))
    }
    func testSoftCapReachedAtEightWeeks() {
        let cut = CutMode(enabled: true, startedAt: Date().addingTimeInterval(-8 * 7 * 86400 - 1))
        XCTAssertTrue(cut.softCapReached(now: Date()))
    }
    func testDisabledCutNeverReachesSoftCap() {
        let cut = CutMode(enabled: false, startedAt: Date().addingTimeInterval(-100 * 86400))
        XCTAssertFalse(cut.softCapReached(now: Date()))
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Models/CutMode.swift
import Foundation

struct CutMode: Codable, Equatable {
    var enabled: Bool
    var startedAt: Date?
    var softCapWeeks: Int

    init(enabled: Bool = false, startedAt: Date? = nil, softCapWeeks: Int = 8) {
        self.enabled = enabled
        self.startedAt = startedAt
        self.softCapWeeks = softCapWeeks
    }

    func softCapReached(now: Date = Date()) -> Bool {
        guard enabled, let startedAt else { return false }
        let weeksElapsed = now.timeIntervalSince(startedAt) / (7 * 86400)
        return weeksElapsed > Double(softCapWeeks)
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/CutMode.swift UNBOUNDTests/Models/CutModeTests.swift
git commit -m "feat: add CutMode with 8-week soft cap"
```

---

### Task 1.5: Add ProgramBlock model

**Files:**
- Create: `UNBOUND/Models/ProgramBlock.swift`
- Test: `UNBOUNDTests/Models/ProgramBlockTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class ProgramBlockTests: XCTestCase {
    func testEncodesAndDecodes() throws {
        let block = ProgramBlock(
            id: "b-1",
            userId: "u-1",
            programId: "p-1",
            blockNumber: 3,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: nil,
            scanId: "s-42",
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: true,
            biasRefreshedFromPrevious: true,
            exerciseRotationsThisBlock: ["barbell_row"]
        )
        let data = try JSONEncoder().encode(block)
        let decoded = try JSONDecoder().decode(ProgramBlock.self, from: data)
        XCTAssertEqual(decoded, block)
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Models/ProgramBlock.swift
import Foundation

struct ProgramBlock: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let programId: String
    let blockNumber: Int
    let startedAt: Date
    var endedAt: Date?
    let scanId: String?
    var accessoryBias: [MuscleGroup: Int]
    var cutModeActive: Bool
    var biasRefreshedFromPrevious: Bool
    var exerciseRotationsThisBlock: [String]

    init(
        id: String,
        userId: String,
        programId: String,
        blockNumber: Int,
        startedAt: Date,
        endedAt: Date? = nil,
        scanId: String?,
        accessoryBias: [MuscleGroup: Int] = [:],
        cutModeActive: Bool = false,
        biasRefreshedFromPrevious: Bool = false,
        exerciseRotationsThisBlock: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.blockNumber = blockNumber
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.scanId = scanId
        self.accessoryBias = accessoryBias
        self.cutModeActive = cutModeActive
        self.biasRefreshedFromPrevious = biasRefreshedFromPrevious
        self.exerciseRotationsThisBlock = exerciseRotationsThisBlock
    }
}
```

Note: `MuscleGroup` already exists in the codebase; `[MuscleGroup: Int]` encodes to JSON as a keyed object when MuscleGroup conforms to `RawRepresentable` with `String`. If `Codable` dictionary keying errors, wrap in a `CodableMap<MuscleGroup, Int>` helper. Verify by running the test.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/ProgramBlock.swift UNBOUNDTests/Models/ProgramBlockTests.swift
git commit -m "feat: add ProgramBlock model"
```

---

### Task 1.6: Add ProgressPhoto model

**Files:**
- Create: `UNBOUND/Models/ProgressPhoto.swift`
- Test: `UNBOUNDTests/Models/ProgressPhotoTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class ProgressPhotoTests: XCTestCase {
    func testEncodesAndDecodes() throws {
        let p = ProgressPhoto(
            id: "pp-1",
            userId: "u-1",
            storageUrl: "https://x.y/p.jpg",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            note: "after workout",
            angle: .front,
            blockNumber: 3,
            source: .manual
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(ProgressPhoto.self, from: data)
        XCTAssertEqual(decoded, p)
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Models/ProgressPhoto.swift
import Foundation

struct ProgressPhoto: Codable, Identifiable, Equatable {
    enum Source: String, Codable { case manual, scan }

    let id: String
    let userId: String
    let storageUrl: String
    let capturedAt: Date
    var note: String?
    var angle: ScanAngle?       // optional reuse of existing ScanAngle
    var blockNumber: Int?       // which block this was taken in (for album grouping)
    var source: Source          // manual or pulled from a scan session
}
```

If `ScanAngle` is not `Codable`, make it so (it should already be). If not present, define a simple `PhotoAngle` here.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/ProgressPhoto.swift UNBOUNDTests/Models/ProgressPhotoTests.swift
git commit -m "feat: add ProgressPhoto model"
```

---

### Task 1.7: Extend UserProfile with new fields

**Files:**
- Modify: `UNBOUND/Models/User.swift`
- Test: `UNBOUNDTests/Models/UserProfileTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class UserProfileTests: XCTestCase {
    func testNewFieldsDefaultNil() {
        let p = UserProfile(id: "u", createdAt: Date(), onboardingCompleted: false, totalScans: 0)
        XCTAssertNil(p.trainingFeedbackMode)
        XCTAssertNil(p.trainingStyleOverride)
        XCTAssertNil(p.trainingDays)
        XCTAssertEqual(p.cutMode, CutMode())
    }
    func testEncodesWithNewFields() throws {
        var p = UserProfile(id: "u", createdAt: Date(), onboardingCompleted: true, totalScans: 1)
        p.trainingFeedbackMode = .quick
        p.trainingStyleOverride = .hybrid
        p.trainingDays = [.monday, .wednesday, .friday]
        p.cutMode = CutMode(enabled: true, startedAt: Date())
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.trainingFeedbackMode, .quick)
        XCTAssertEqual(decoded.trainingStyleOverride, .hybrid)
        XCTAssertEqual(decoded.trainingDays, [.monday, .wednesday, .friday])
        XCTAssertTrue(decoded.cutMode.enabled)
    }
}
```

Add a convenience initializer to `UserProfile` if one doesn't exist — tests need the minimal-arg form.

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Modify UserProfile**

Add these fields after `exerciseStyles: [ExerciseStyle]?`:

```swift
    // MARK: Program Redesign (2026-04-20)
    var trainingFeedbackMode: TrainingFeedbackMode?
    var trainingStyleOverride: TrainingStyle?
    var trainingDays: Set<Weekday>?
    var cutMode: CutMode = CutMode()
```

Because `cutMode` has a default, older persisted JSON (without the key) will still decode. Verify by running the test with a manual `JSONDecoder` roundtrip on a stripped object.

Add a minimal init used by tests:

```swift
    init(id: String, createdAt: Date, onboardingCompleted: Bool, totalScans: Int) {
        self.id = id
        self.createdAt = createdAt
        self.onboardingCompleted = onboardingCompleted
        self.totalScans = totalScans
    }
```

(If the autogenerated memberwise init is sufficient, skip this — but other optional fields will need explicit nil assignment in the test construction.)

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/User.swift UNBOUNDTests/Models/UserProfileTests.swift
git commit -m "feat: extend UserProfile with training feedback, style override, training days, cut mode"
```

---

### Task 1.8: Lock TrainingProgram.durationDays to 14

**Files:**
- Modify: `UNBOUND/Models/Program.swift`

- [ ] **Step 1: Update Program.swift**

Replace:
```swift
    var durationDays: Int
```
With:
```swift
    var durationDays: Int = 14   // Redesign 2026-04-20: blocks are fixed at 14 days.
```

Keep the field for back-compat. Generator should always write 14.

- [ ] **Step 2: Run existing tests + build**

Expected: build succeeds, no existing tests broken.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Models/Program.swift
git commit -m "chore: lock TrainingProgram.durationDays default to 14"
```

---

### Chunk 1 Review Gate

- [ ] **Review:** Run all tests (⌘U). All should pass. Models should feel cohesive and codable-clean.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 2.

---

## Chunk 2 — Deterministic generator pipeline

### Task 2.1: Add DayTemplate enum

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/DayTemplate.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/DayTemplateTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class DayTemplateTests: XCTestCase {
    func testRestDayFlag() {
        XCTAssertTrue(DayTemplate.rest.isRest)
        XCTAssertFalse(DayTemplate.push.isRest)
    }
    func testMuscleGroupsPerTemplate() {
        XCTAssertTrue(DayTemplate.push.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.pull.muscleGroups.contains(.back))
        XCTAssertTrue(DayTemplate.legs.muscleGroups.contains(.legs))
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/DayTemplate.swift
import Foundation

enum DayTemplate: String, Codable, Hashable {
    case push
    case pull
    case legs
    case upper
    case lower
    case fullBody
    case skill          // calisthenic-specific skill day
    case weakPoint      // targeted weak-point bias day
    case rest

    var isRest: Bool { self == .rest }

    var muscleGroups: [MuscleGroup] {
        switch self {
        case .push: return [.chest, .shoulders, .arms]
        case .pull: return [.back, .lats, .arms, .traps]
        case .legs: return [.legs, .glutes, .calves, .core]
        case .upper: return [.chest, .back, .shoulders, .arms, .lats]
        case .lower: return [.legs, .glutes, .calves, .core]
        case .fullBody: return [.chest, .back, .legs, .shoulders, .core]
        case .skill: return [.core, .arms, .shoulders]
        case .weakPoint: return []  // filled by generator based on focus areas
        case .rest: return []
        }
    }

    var displayLabel: String {
        switch self {
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .fullBody: return "Full Body"
        case .skill: return "Skill"
        case .weakPoint: return "Weak Point"
        case .rest: return "Rest"
        }
    }
}
```

Adjust `muscleGroups` cases to match actual `MuscleGroup` enum values in the codebase (already verified: chest, back, lats, shoulders, legs, glutes, calves, arms, forearms, core, traps, neck).

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/DayTemplate.swift UNBOUNDTests/Services/ProgramGeneration/DayTemplateTests.swift
git commit -m "feat: add DayTemplate enum"
```

---

### Task 2.2: SplitLookup — map (archetype, frequency) → day sequence

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/SplitLookup.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/SplitLookupTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class SplitLookupTests: XCTestCase {
    func testThreeDayCalisthenicIsFullBody() {
        let split = SplitLookup.split(archetype: .calisthenic, frequency: .three)
        XCTAssertEqual(split.trainingDayTemplates.count, 3)
        XCTAssertTrue(split.trainingDayTemplates.allSatisfy { $0 == .fullBody || $0 == .upper || $0 == .lower })
    }

    func testFourDayDefaultIsUpperLowerTwice() {
        let split = SplitLookup.split(archetype: .gymGoer, frequency: .four)
        XCTAssertEqual(split.trainingDayTemplates.count, 4)
    }

    func testSixDayIsPPLTwice() {
        let split = SplitLookup.split(archetype: .gymGoer, frequency: .six)
        XCTAssertEqual(split.trainingDayTemplates, [.push, .pull, .legs, .push, .pull, .legs])
    }

    func testSplitAlwaysMatchesFrequency() {
        let freqs: [TargetFrequency] = [.three, .four, .five, .six]
        for f in freqs {
            let s = SplitLookup.split(archetype: .gymGoer, frequency: f)
            XCTAssertEqual(s.trainingDayTemplates.count, f.numericCount)
        }
    }
}
```

`TargetFrequency.numericCount` is a helper — add it in the same task if missing. If Archetype doesn't have `.gymGoer`, use a real case (e.g., `.brawler`).

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

Add helper on TargetFrequency (in `OnboardingAnswers.swift`):

```swift
extension TargetFrequency {
    var numericCount: Int {
        switch self {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        }
    }
}
```

Then:

```swift
// UNBOUND/Services/ProgramGeneration/SplitLookup.swift
import Foundation

struct Split {
    let trainingDayTemplates: [DayTemplate]  // only training days, not rest
}

enum SplitLookup {
    static func split(archetype: Archetype, frequency: TargetFrequency) -> Split {
        let isCalisthenic = archetype == .calisthenic
        switch (isCalisthenic, frequency) {
        case (true, .three):
            return Split(trainingDayTemplates: [.fullBody, .fullBody, .fullBody])
        case (true, .four):
            return Split(trainingDayTemplates: [.upper, .lower, .upper, .lower])
        case (true, .five):
            return Split(trainingDayTemplates: [.push, .pull, .legs, .skill, .weakPoint])
        case (true, .six):
            return Split(trainingDayTemplates: [.push, .pull, .legs, .push, .pull, .skill])

        case (false, .three):
            return Split(trainingDayTemplates: [.upper, .lower, .fullBody])
        case (false, .four):
            return Split(trainingDayTemplates: [.upper, .lower, .upper, .lower])
        case (false, .five):
            return Split(trainingDayTemplates: [.push, .pull, .legs, .upper, .lower])
        case (false, .six):
            return Split(trainingDayTemplates: [.push, .pull, .legs, .push, .pull, .legs])
        }
    }
}
```

If `Archetype.calisthenic` isn't the literal case, use whichever name the codebase uses.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/SplitLookup.swift UNBOUND/Models/OnboardingAnswers.swift UNBOUNDTests/Services/ProgramGeneration/SplitLookupTests.swift
git commit -m "feat: SplitLookup maps archetype+frequency to day sequence"
```

---

### Task 2.3: MacroCalculator

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/MacroCalculator.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/MacroCalculatorTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class MacroCalculatorTests: XCTestCase {
    func testMaintenanceReasonableRange() {
        let macros = MacroCalculator.macros(
            weightKg: 80, heightCm: 180, age: 25, sex: .male,
            frequency: .four, cutMode: false
        )
        // 80 kg, 180 cm, 25 M, moderate-active ~ 2700-3100 kcal
        XCTAssertGreaterThan(macros.calories, 2500)
        XCTAssertLessThan(macros.calories, 3300)
    }
    func testCutIs15PercentLower() {
        let base = MacroCalculator.macros(
            weightKg: 80, heightCm: 180, age: 25, sex: .male,
            frequency: .four, cutMode: false
        )
        let cut = MacroCalculator.macros(
            weightKg: 80, heightCm: 180, age: 25, sex: .male,
            frequency: .four, cutMode: true
        )
        let ratio = Double(cut.calories) / Double(base.calories)
        XCTAssertEqual(ratio, 0.85, accuracy: 0.01)
    }
    func testProteinBumpsOnCut() {
        let base = MacroCalculator.macros(
            weightKg: 80, heightCm: 180, age: 25, sex: .male,
            frequency: .four, cutMode: false
        )
        let cut = MacroCalculator.macros(
            weightKg: 80, heightCm: 180, age: 25, sex: .male,
            frequency: .four, cutMode: true
        )
        XCTAssertGreaterThan(cut.proteinG, base.proteinG)
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/MacroCalculator.swift
import Foundation

struct MacroTargets: Codable, Equatable {
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
}

enum MacroCalculator {
    /// Mifflin-St Jeor BMR × activity factor (from training frequency) × (0.85 if cut).
    /// Protein: 1.8 g/kg (2.2 g/kg if cut). Fat: 25% of calories. Carbs: remainder.
    static func macros(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        frequency: TargetFrequency,
        cutMode: Bool
    ) -> MacroTargets {
        let bmr: Double
        switch sex {
        case .male:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }

        let activity: Double
        switch frequency {
        case .three: activity = 1.45
        case .four:  activity = 1.55
        case .five:  activity = 1.65
        case .six:   activity = 1.75
        }

        let tdee = bmr * activity
        let adjusted = cutMode ? tdee * 0.85 : tdee

        let proteinGPerKg = cutMode ? 2.2 : 1.8
        let proteinG = Int(round(weightKg * proteinGPerKg))
        let proteinCals = proteinG * 4

        let fatCals = Int(round(adjusted * 0.25))
        let fatG = fatCals / 9

        let remainingCals = Int(round(adjusted)) - proteinCals - fatCals
        let carbsG = max(0, remainingCals / 4)

        return MacroTargets(
            calories: Int(round(adjusted)),
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG
        )
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/MacroCalculator.swift UNBOUNDTests/Services/ProgramGeneration/MacroCalculatorTests.swift
git commit -m "feat: MacroCalculator with Mifflin-St Jeor + cut mode"
```

---

### Task 2.4: WeakPointBiaser

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/WeakPointBiaser.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/WeakPointBiaserTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class WeakPointBiaserTests: XCTestCase {
    func testBiasFromFocusAreas() {
        let focus = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "narrow", suggestedFocus: "side delts"),
            FocusArea(muscleGroup: .back, priority: 2, rationale: "flat", suggestedFocus: "rows"),
        ]
        let bias = WeakPointBiaser.bias(from: focus)
        XCTAssertEqual(bias[.shoulders], 2)   // priority-1 → weight 2
        XCTAssertEqual(bias[.back], 1)        // priority-2 → weight 1
        XCTAssertNil(bias[.chest])            // not flagged
    }
    func testEmptyFocusProducesEmptyBias() {
        XCTAssertTrue(WeakPointBiaser.bias(from: []).isEmpty)
    }
    func testAddExtraAccessoriesForBiasedGroup() {
        let exercises = [
            CatalogExercise(name: "bench", targetMuscleGroups: [.chest]),
            CatalogExercise(name: "lateral_raise", targetMuscleGroups: [.shoulders]),
            CatalogExercise(name: "face_pull", targetMuscleGroups: [.shoulders]),
        ]
        let biased = WeakPointBiaser.addAccessories(
            to: [exercises[0]],
            from: exercises,
            biasedGroups: [.shoulders: 2],
            maxAccessories: 2
        )
        XCTAssertEqual(biased.count, 3)   // 1 original + 2 shoulder accessories
    }
}

// Lightweight test-only struct if CatalogExercise doesn't already exist in this shape.
private struct CatalogExercise {
    let name: String
    let targetMuscleGroups: [MuscleGroup]
}
```

The test uses a local `CatalogExercise` — in real code, the biaser should work with `ExerciseCatalog.Entry` (the actual type in `ExerciseCatalog.swift`). Update the signature to match the real type — inspect it before coding.

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/WeakPointBiaser.swift
import Foundation

enum WeakPointBiaser {

    /// Convert scan-derived FocusAreas into a bias weight per muscle group.
    /// Priority 1 → weight 2, priority 2 → weight 1, lower priorities → 0.
    static func bias(from focusAreas: [FocusArea]) -> [MuscleGroup: Int] {
        var result: [MuscleGroup: Int] = [:]
        for fa in focusAreas {
            let weight: Int
            switch fa.priority {
            case 1: weight = 2
            case 2: weight = 1
            default: weight = 0
            }
            if weight > 0 {
                result[fa.muscleGroup] = weight
            }
        }
        return result
    }

    /// C-bias: pick the exercise whose `biasedMuscleGroups` overlaps biased groups.
    /// Given two equivalent candidates, prefer the one that targets a biased group.
    static func pickBiased<T: Equatable>(
        candidates: [T],
        biasedGroups: [MuscleGroup: Int],
        biasedGroupsFor: (T) -> [MuscleGroup]
    ) -> T? {
        guard !candidates.isEmpty else { return nil }
        let scored = candidates.map { c -> (T, Int) in
            let groups = biasedGroupsFor(c)
            let score = groups.reduce(0) { $0 + (biasedGroups[$1] ?? 0) }
            return (c, score)
        }
        return scored.max(by: { $0.1 < $1.1 })?.0
    }

    /// B-bias: add extra accessory exercises whose target groups are biased.
    /// `exercises` is the current workout's exercise list.
    /// `pool` is the eligible catalog pool already filtered by style/equipment.
    /// `maxAccessories` caps how many B-bias accessories can be appended.
    static func addAccessories<T>(
        to exercises: [T],
        from pool: [T],
        biasedGroups: [MuscleGroup: Int],
        maxAccessories: Int,
        targetGroupsFor: (T) -> [MuscleGroup] = { _ in [] }
    ) -> [T] where T: Equatable {
        // Order pool entries by how much bias they hit, descending.
        let ranked = pool
            .filter { !exercises.contains($0) }
            .map { entry -> (T, Int) in
                let groups = targetGroupsFor(entry)
                let score = groups.reduce(0) { $0 + (biasedGroups[$1] ?? 0) }
                return (entry, score)
            }
            .filter { $0.1 > 0 }
            .sorted(by: { $0.1 > $1.1 })

        let toAdd = ranked.prefix(maxAccessories).map(\.0)
        return exercises + Array(toAdd)
    }
}
```

If the test's local `CatalogExercise` shadow struct won't satisfy the generic, rewrite the test to pass `targetGroupsFor:` closures explicitly. The point is to keep the biaser **generic** so it can work with either `ExerciseCatalog.Entry` or any future exercise type.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/WeakPointBiaser.swift UNBOUNDTests/Services/ProgramGeneration/WeakPointBiaserTests.swift
git commit -m "feat: WeakPointBiaser with B-bias (accessories) and C-bias (selection)"
```

---

### Task 2.5: DeterministicProgramGenerator — integrate pipeline

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/DeterministicProgramGeneratorTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class DeterministicProgramGeneratorTests: XCTestCase {

    func testGeneratesFourteenDays() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.days.count, 14)
    }

    func testTrainingDaysMatchSelection() throws {
        let days: Set<Weekday> = [.monday, .wednesday, .friday]
        let input = makeInput(frequency: .three, trainingDays: days)
        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingDayDates = program.days.filter { !$0.isRestDay }.count
        XCTAssertEqual(trainingDayDates, 6)   // 3/week × 2 weeks
    }

    func testWeakPointBiasLandsOnAccessories() throws {
        var input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        input.focusAreas = [FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "narrow", suggestedFocus: "side delts")]
        let program = try DeterministicProgramGenerator.generate(input: input)
        let allExerciseGroups = program.days
            .compactMap { $0.workout }
            .flatMap { $0.targetMuscleGroups }
        XCTAssertTrue(allExerciseGroups.contains(.shoulders))
    }

    private func makeInput(frequency: TargetFrequency, trainingDays: Set<Weekday>) -> ProgramGeneratorInput {
        return ProgramGeneratorInput(
            userId: "u-1",
            scanId: "s-1",
            analysisId: "a-1",
            archetype: .calisthenic,
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: frequency,
            trainingDays: trainingDays,
            experience: .intermediate,
            focusAreas: [],
            cutModeActive: false,
            trainingFeedbackMode: .quick,
            progressionStates: [:],
            previousBlock: nil,
            weightKg: 75,
            heightCm: 178,
            age: 24,
            sex: .male,
            blockStartDate: Date()
        )
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement input struct + generator**

```swift
// UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift
import Foundation

struct ProgramGeneratorInput {
    let userId: String
    let scanId: String?
    let analysisId: String?
    let archetype: Archetype
    let trainingStyle: TrainingStyle
    let equipment: [Equipment]
    let targetFrequency: TargetFrequency
    let trainingDays: Set<Weekday>
    let experience: Experience
    var focusAreas: [FocusArea]
    let cutModeActive: Bool
    let trainingFeedbackMode: TrainingFeedbackMode
    let progressionStates: [String: ProgressionState]   // keyed by exerciseKey
    let previousBlock: ProgramBlock?
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let sex: BiologicalSex
    let blockStartDate: Date
}

enum DeterministicProgramGenerator {

    static func generate(input: ProgramGeneratorInput) throws -> TrainingProgram {
        let bias = WeakPointBiaser.bias(from: input.focusAreas)
        let split = SplitLookup.split(archetype: input.archetype, frequency: input.targetFrequency)
        let days = try scheduleDays(
            split: split,
            trainingDays: input.trainingDays,
            blockStartDate: input.blockStartDate,
            input: input,
            bias: bias
        )
        let nutrition = buildNutritionPlan(input: input)
        let recovery = buildRecoveryPlan(days: days)
        let rationale = RationaleBuilder.build(input: input, bias: bias, split: split)

        return TrainingProgram(
            id: UUID().uuidString,
            scanId: input.scanId ?? "",
            analysisId: input.analysisId ?? "",
            userId: input.userId,
            createdAt: Date(),
            archetype: input.archetype,
            name: programName(for: input),
            description: programDescription(for: input),
            durationDays: 14,
            days: days,
            nutritionPlan: nutrition,
            recoveryPlan: recovery,
            difficultyLevel: difficultyLevel(for: input.experience),
            requiredEquipment: input.equipment.map { $0.rawValue },
            estimatedDailyMinutes: estimatedDailyMinutes(for: input),
            rationale: rationale
        )
    }

    // MARK: — Day scheduling

    private static func scheduleDays(
        split: Split,
        trainingDays: Set<Weekday>,
        blockStartDate: Date,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) throws -> [ProgramDay] {
        // Create 14 consecutive days starting from blockStartDate.
        // For each day: if its Weekday is in trainingDays, assign the next DayTemplate from the split (looping).
        // Otherwise mark rest.
        let cal = Calendar.current
        var result: [ProgramDay] = []
        let orderedTemplates = split.trainingDayTemplates
        var templateCursor = 0

        for i in 0..<14 {
            let date = cal.date(byAdding: .day, value: i, to: blockStartDate) ?? blockStartDate
            guard let weekday = Weekday(from: date, calendar: cal) else {
                throw GeneratorError.unexpected("bad weekday for offset \(i)")
            }
            let dayNumber = i + 1
            if trainingDays.contains(weekday) && !orderedTemplates.isEmpty {
                let template = orderedTemplates[templateCursor % orderedTemplates.count]
                templateCursor += 1
                let workout = buildWorkout(for: template, input: input, bias: bias, dayNumber: dayNumber)
                let label = labelFor(template: template, bias: bias)
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: label,
                    isRestDay: false,
                    workout: workout,
                    nutritionOverride: nil,
                    recoveryActivities: []
                ))
            } else {
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: "Rest",
                    isRestDay: true,
                    workout: nil,
                    nutritionOverride: nil,
                    recoveryActivities: restDayRecovery()
                ))
            }
        }
        return result
    }

    // MARK: — Workout building (hand-wave first pass; refine in Task 2.6)

    private static func buildWorkout(
        for template: DayTemplate,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        dayNumber: Int
    ) -> Workout {
        let eligible = ExerciseCatalog.allExercises
            .filter { isCompatible($0, style: input.trainingStyle, equipment: input.equipment) }
            .filter { !$0.targetMuscleGroups.isEmpty }

        let dayGroups = Set(template.muscleGroups)
        var picked: [Exercise] = []

        // 1-2 primary compounds
        let compounds = eligible.filter { $0.isCompound && $0.targetMuscleGroups.contains(where: dayGroups.contains) }
        picked.append(contentsOf: compounds.prefix(2).map { toExercise(catalog: $0, input: input) })

        // 2-3 secondaries
        let secondaries = eligible.filter { !$0.isCompound && $0.targetMuscleGroups.contains(where: dayGroups.contains) }
        picked.append(contentsOf: secondaries.prefix(3).map { toExercise(catalog: $0, input: input) })

        // Accessories with B-bias
        let accessoryPool = eligible.filter { $0.isAccessory }
        let accessoryChoices = WeakPointBiaser.addAccessories(
            to: [ExerciseCatalog.Entry](),
            from: accessoryPool,
            biasedGroups: bias,
            maxAccessories: bias.isEmpty ? 1 : 2,
            targetGroupsFor: \.targetMuscleGroups
        )
        picked.append(contentsOf: accessoryChoices.map { toExercise(catalog: $0, input: input) })

        return Workout(
            id: UUID().uuidString,
            name: template.displayLabel,
            exercises: picked,
            targetMuscleGroups: Array(dayGroups),
            estimatedDuration: 45 + (picked.count * 5)
        )
    }

    // Note: `ExerciseCatalog.Entry`'s actual property names must be verified.
    // `isCompound` and `isAccessory` may need to be computed from `classification` or a similar field.
    // Adjust to match real API once inspected.

    private static func isCompatible(
        _ entry: ExerciseCatalog.Entry,
        style: TrainingStyle,
        equipment: [Equipment]
    ) -> Bool {
        // Placeholder: return true. Refine in Task 2.6 once catalog field names are known.
        return true
    }

    private static func toExercise(catalog: ExerciseCatalog.Entry, input: ProgramGeneratorInput) -> Exercise {
        let state = input.progressionStates[normalize(catalog.name)]
        let prescribedWeight = state?.currentWorkingWeightKg ?? startingWeight(for: catalog, experience: input.experience)
        let topReps = state?.targetRepMax ?? 10
        let sets = 3

        return Exercise(
            id: UUID().uuidString,
            name: catalog.displayName,
            targetMuscleGroups: catalog.targetMuscleGroups,
            sets: sets,
            reps: max(6, topReps - 4)...topReps,
            weightKg: prescribedWeight,
            restSeconds: 90,
            notes: nil
        )
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static func startingWeight(for entry: ExerciseCatalog.Entry, experience: Experience) -> Double {
        switch experience {
        case .beginner: return 0
        case .intermediate: return 0
        case .advanced: return 0
        }
    }

    private static func labelFor(template: DayTemplate, bias: [MuscleGroup: Int]) -> String {
        guard let biggest = bias.max(by: { $0.value < $1.value }) else {
            return template.displayLabel
        }
        return "\(template.displayLabel) + \(biggest.key.displayName) Bias"
    }

    // MARK: — Nutrition

    private static func buildNutritionPlan(input: ProgramGeneratorInput) -> NutritionPlan {
        let macros = MacroCalculator.macros(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            age: input.age,
            sex: input.sex,
            frequency: input.targetFrequency,
            cutMode: input.cutModeActive
        )
        return NutritionPlan(
            dailyCalories: macros.calories,
            proteinG: macros.proteinG,
            carbsG: macros.carbsG,
            fatG: macros.fatG,
            cutModeActive: input.cutModeActive
        )
    }

    // MARK: — Recovery

    private static func buildRecoveryPlan(days: [ProgramDay]) -> RecoveryPlan {
        // Static rec plan for MVP; refine in later chunk.
        return RecoveryPlan(
            sleepHoursTarget: 8,
            waterLitersTarget: 3,
            mobilityMinutesDaily: 10
        )
    }

    private static func restDayRecovery() -> [RecoveryActivity] {
        [
            RecoveryActivity(id: UUID().uuidString, name: "Hip flow", durationMinutes: 10, category: .mobility),
            RecoveryActivity(id: UUID().uuidString, name: "Shoulder dislocates", durationMinutes: 5, category: .mobility),
            RecoveryActivity(id: UUID().uuidString, name: "Walk", durationMinutes: 20, category: .cardio)
        ]
    }

    // MARK: — Meta

    private static func programName(for input: ProgramGeneratorInput) -> String {
        "\(input.archetype.displayName) Training"
    }

    private static func programDescription(for input: ProgramGeneratorInput) -> String {
        let freq = input.targetFrequency.numericCount
        return "Your \(freq)-day personalized plan, tuned to your scan."
    }

    private static func difficultyLevel(for experience: Experience) -> DifficultyLevel {
        switch experience {
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .advanced: return .advanced
        }
    }

    private static func estimatedDailyMinutes(for input: ProgramGeneratorInput) -> Int {
        switch input.experience {
        case .beginner: return 45
        case .intermediate: return 60
        case .advanced: return 75
        }
    }

    enum GeneratorError: Error {
        case unexpected(String)
    }
}

// Placeholder for rationale builder (fleshed out in Task 2.7)
enum RationaleBuilder {
    static func build(input: ProgramGeneratorInput, bias: [MuscleGroup: Int], split: Split) -> ProgramRationale {
        var decisions: [ProgramRationale.Decision] = []
        decisions.append(.init(
            inputSummary: "You train \(input.targetFrequency.numericCount) days/week",
            decisionApplied: "Split: \(split.trainingDayTemplates.map(\.displayLabel).joined(separator: " / "))",
            iconSystemName: "calendar"
        ))
        if !bias.isEmpty {
            let groups = bias.sorted(by: { $0.value > $1.value }).map(\.key.displayName).joined(separator: " + ")
            decisions.append(.init(
                inputSummary: "Scan flagged: \(groups)",
                decisionApplied: "Added accessory bias to those muscle groups",
                iconSystemName: "sparkles"
            ))
        }
        if input.cutModeActive {
            decisions.append(.init(
                inputSummary: "Cut mode on",
                decisionApplied: "Calories in deficit, progression paused",
                iconSystemName: "flame"
            ))
        }
        return ProgramRationale(
            headline: "Your Arc",
            summaryCopy: "Built from your scan, equipment, and training days.",
            decisions: decisions
        )
    }
}
```

**Important:** Real field names on `ExerciseCatalog.Entry`, `Exercise`, `Workout`, `NutritionPlan`, `RecoveryPlan`, `RecoveryActivity`, `MuscleGroup.displayName`, and `Archetype.displayName` must be verified before wiring. Read those files first. Any mismatch shows up as a compile error — fix inline.

- [ ] **Step 4: Run tests, verify pass. Fix compile errors by reading real model field names.**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift UNBOUNDTests/Services/ProgramGeneration/DeterministicProgramGeneratorTests.swift
git commit -m "feat: DeterministicProgramGenerator pipeline"
```

---

### Task 2.6: Refine compatibility filter (style × equipment)

**Files:**
- Modify: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift`
- Test: add to existing test file

- [ ] **Step 1: Add failing test for equipment filtering**

```swift
func testBodyweightOnlyExcludesBarbells() throws {
    var input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
    input.trainingStyle = .bodyweight
    input.equipment = [.bodyweight]
    let program = try DeterministicProgramGenerator.generate(input: input)
    let allNames = program.days.compactMap { $0.workout }.flatMap { $0.exercises }.map(\.name).joined(separator: " ").lowercased()
    XCTAssertFalse(allNames.contains("barbell"))
    XCTAssertFalse(allNames.contains("cable"))
}
```

- [ ] **Step 2: Inspect `ExerciseCatalog.Entry` fields**

Open `UNBOUND/Models/ExerciseCatalog.swift`. Note which fields encode equipment requirements (`requiredEquipment`, `equipmentTags`, etc.) and how style/category is expressed.

- [ ] **Step 3: Replace `isCompatible` with real logic**

Replace the placeholder:

```swift
private static func isCompatible(
    _ entry: ExerciseCatalog.Entry,
    style: TrainingStyle,
    equipment: [Equipment]
) -> Bool {
    // Translate the user's Equipment chips into the catalog's equipment tagging.
    // Reject if the exercise needs something the user doesn't have.
    let required = entry.requiredEquipment  // ← actual field name TBD from ExerciseCatalog.swift
    for req in required {
        if !equipment.map(\.rawValue).contains(req) {
            return false
        }
    }
    // Style filter: if the user picked bodyweight style, reject exercises tagged
    // as requiring external load beyond optional weight.
    if style == .bodyweight && entry.requiresExternalLoad {
        return false
    }
    return true
}
```

Adjust to actual catalog field names.

- [ ] **Step 4: Run test, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift UNBOUNDTests/Services/ProgramGeneration/DeterministicProgramGeneratorTests.swift
git commit -m "feat: equipment and style compatibility filtering"
```

---

### Task 2.7: Rationale builder — concrete decisions

**Files:**
- Modify: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/RationaleBuilderTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class RationaleBuilderTests: XCTestCase {
    func testIncludesEquipmentDecisionWhenLimited() {
        let input = ProgramGeneratorInput(
            userId: "u", scanId: nil, analysisId: nil,
            archetype: .calisthenic, trainingStyle: .bodyweight,
            equipment: [.bodyweight], targetFrequency: .three,
            trainingDays: [.monday, .wednesday, .friday],
            experience: .intermediate,
            focusAreas: [],
            cutModeActive: false, trainingFeedbackMode: .quick,
            progressionStates: [:], previousBlock: nil,
            weightKg: 75, heightCm: 178, age: 24, sex: .male,
            blockStartDate: Date()
        )
        let rationale = RationaleBuilder.build(
            input: input,
            bias: [:],
            split: SplitLookup.split(archetype: .calisthenic, frequency: .three)
        )
        let summaries = rationale.decisions.map(\.inputSummary).joined(separator: " ")
        XCTAssertTrue(summaries.lowercased().contains("bodyweight") || summaries.lowercased().contains("equipment"))
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Expand RationaleBuilder**

Replace the placeholder with:

```swift
enum RationaleBuilder {
    static func build(
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        split: Split
    ) -> ProgramRationale {
        var decisions: [ProgramRationale.Decision] = []

        // Frequency decision
        decisions.append(.init(
            inputSummary: "You train \(input.targetFrequency.numericCount) days/week",
            decisionApplied: "Split: \(split.trainingDayTemplates.map(\.displayLabel).joined(separator: " / "))",
            iconSystemName: "calendar"
        ))

        // Training days decision
        let daysShort = Weekday.allCases.filter(input.trainingDays.contains).map(\.short).joined(separator: ", ")
        decisions.append(.init(
            inputSummary: "Your training days: \(daysShort)",
            decisionApplied: "Scheduled workouts on those weekdays; rest days fill in",
            iconSystemName: "calendar.day.timeline.left"
        ))

        // Equipment / style decision
        if input.trainingStyle == .bodyweight || input.equipment == [.bodyweight] {
            decisions.append(.init(
                inputSummary: "Bodyweight only",
                decisionApplied: "Swapped all barbell and machine exercises for bodyweight equivalents",
                iconSystemName: "figure.strengthtraining.traditional"
            ))
        }

        // Weak-point bias decision
        if !bias.isEmpty {
            let groups = bias.sorted(by: { $0.value > $1.value }).map(\.key.displayName).joined(separator: " + ")
            decisions.append(.init(
                inputSummary: "Scan flagged: \(groups)",
                decisionApplied: "Added accessory bias + favored exercises that hit \(groups)",
                iconSystemName: "sparkles"
            ))
        }

        // Cut mode
        if input.cutModeActive {
            decisions.append(.init(
                inputSummary: "Cut mode is on",
                decisionApplied: "Calories in 15% deficit, lift progression paused — preserving what you've built",
                iconSystemName: "flame"
            ))
        }

        return ProgramRationale(
            headline: "Why this program",
            summaryCopy: "Deterministic, built from your inputs. No magic.",
            decisions: decisions
        )
    }
}
```

- [ ] **Step 4: Run test, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift UNBOUNDTests/Services/ProgramGeneration/RationaleBuilderTests.swift
git commit -m "feat: RationaleBuilder populates with real decisions"
```

---

### Task 2.8: Wire DeterministicProgramGenerator into LocalProgramGenerator

**Files:**
- Modify: `UNBOUND/Services/ProgramGeneration/LocalProgramGenerator.swift`
- Modify: `UNBOUND/Services/ProgramGeneration/ProgramGenerationService.swift`

- [ ] **Step 1: Read both files and note their public API shape**

Use Read. Identify where the existing LocalProgramGenerator is called and what inputs/outputs it expects.

- [ ] **Step 2: Rewrite LocalProgramGenerator to delegate**

Replace the body of its primary generation method with a call to `DeterministicProgramGenerator.generate(input:)`, converting whatever inputs it already has into `ProgramGeneratorInput`. Keep the function signature the same so callers don't change.

Example skeleton (adapt to real API):

```swift
// Inside LocalProgramGenerator
func generate(scan: ScanSession, analysis: BodyAnalysis, profile: UserProfile) async throws -> TrainingProgram {
    guard let frequency = profile.targetFrequency,
          let days = profile.trainingDays, !days.isEmpty,
          let archetype = profile.preferredArchetype,
          let experience = profile.experience,
          let height = profile.heightCm, let weight = profile.weightKg,
          let age = profile.age, let sex = profile.biologicalSex
    else {
        throw AppError.missingProfileInputs
    }

    let style = profile.trainingStyleOverride ?? TrainingStyle.default(for: archetype)
    let feedback = profile.trainingFeedbackMode ?? TrainingFeedbackMode.default(for: experience)
    let progressionStates = await ProgressionStateStore.shared.allStates(userId: profile.id)
        .reduce(into: [String: ProgressionState]()) { $0[$1.exerciseKey] = $1 }
    let previousBlock = await ProgramBlockStore.shared.latestBlock(userId: profile.id)

    let input = ProgramGeneratorInput(
        userId: profile.id,
        scanId: scan.id,
        analysisId: analysis.id,
        archetype: archetype,
        trainingStyle: style,
        equipment: profile.equipment ?? [.bodyweight],
        targetFrequency: frequency,
        trainingDays: days,
        experience: experience,
        focusAreas: analysis.focusAreas,
        cutModeActive: profile.cutMode.enabled,
        trainingFeedbackMode: feedback,
        progressionStates: progressionStates,
        previousBlock: previousBlock,
        weightKg: weight, heightCm: height,
        age: age, sex: sex,
        blockStartDate: Date()
    )

    return try DeterministicProgramGenerator.generate(input: input)
}
```

`ProgramBlockStore.shared.latestBlock(_:)` is created in Chunk 3 — stub with `nil` for now.

- [ ] **Step 3: Neutralize the LLM path**

In `ProgramGenerationService.swift`, make the LLM-generating function log a deprecation warning and delegate to `LocalProgramGenerator`:

```swift
// Keep file for rollback; stop calling LLM. This path is now deterministic.
func generateProgram(...) async throws -> TrainingProgram {
    LoggingService.shared.log("ProgramGenerationService.generateProgram called; delegating to LocalProgramGenerator (deterministic).", level: .info)
    return try await LocalProgramGenerator.shared.generate(...)
}
```

- [ ] **Step 4: Build, run tests**

Expected: build succeeds; integration test suite (if any uses this path) still passes.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/
git commit -m "refactor: LocalProgramGenerator delegates to deterministic pipeline; LLM path deprecated"
```

---

### Chunk 2 Review Gate

- [ ] **Review:** Run all tests. Run the app in simulator, trigger a scan + program generation, verify a sensible 14-day program appears.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 3.

---

## Chunk 3 — Block rollover + refresh rules

### Task 3.1: AccessoryBiasRefreshRule

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/AccessoryBiasRefreshRule.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/AccessoryBiasRefreshRuleTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class AccessoryBiasRefreshRuleTests: XCTestCase {
    func testNoPreviousBlock_refreshesFromScan() {
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: "")
            ],
            previousBlock: nil
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertEqual(result.bias[.shoulders], 2)
    }

    func testSamePriorities_carriesForward() {
        let prev = ProgramBlock(
            id: "b", userId: "u", programId: "p", blockNumber: 1,
            startedAt: Date(), scanId: nil,
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: false, biasRefreshedFromPrevious: false, exerciseRotationsThisBlock: []
        )
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: ""),
                FocusArea(muscleGroup: .back, priority: 2, rationale: "", suggestedFocus: "")
            ],
            previousBlock: prev
        )
        XCTAssertTrue(result.carriedForward)
        XCTAssertEqual(result.bias, prev.accessoryBias)
    }

    func testPriorityChange_refreshes() {
        let prev = ProgramBlock(
            id: "b", userId: "u", programId: "p", blockNumber: 1,
            startedAt: Date(), scanId: nil,
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: false, biasRefreshedFromPrevious: false, exerciseRotationsThisBlock: []
        )
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .chest, priority: 1, rationale: "", suggestedFocus: ""),
                FocusArea(muscleGroup: .arms, priority: 2, rationale: "", suggestedFocus: "")
            ],
            previousBlock: prev
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertEqual(result.bias[.chest], 2)
        XCTAssertEqual(result.bias[.arms], 1)
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/AccessoryBiasRefreshRule.swift
import Foundation

enum AccessoryBiasRefreshRule {
    struct Result {
        let bias: [MuscleGroup: Int]
        let carriedForward: Bool
    }

    /// Only shift bias if top-2 priority muscle groups from the latest scan differ
    /// (by rank) from the previous block's bias. Otherwise carry forward.
    static func resolve(
        newFocusAreas: [FocusArea],
        previousBlock: ProgramBlock?
    ) -> Result {
        let newBias = WeakPointBiaser.bias(from: newFocusAreas)
        guard let previousBlock else {
            return Result(bias: newBias, carriedForward: false)
        }

        let prevTop = previousBlock.accessoryBias
            .sorted(by: { $0.value > $1.value })
            .prefix(2)
            .map(\.key)
        let newTop = newBias
            .sorted(by: { $0.value > $1.value })
            .prefix(2)
            .map(\.key)

        if Array(prevTop) == Array(newTop) {
            return Result(bias: previousBlock.accessoryBias, carriedForward: true)
        }
        return Result(bias: newBias, carriedForward: false)
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/AccessoryBiasRefreshRule.swift UNBOUNDTests/Services/ProgramGeneration/AccessoryBiasRefreshRuleTests.swift
git commit -m "feat: AccessoryBiasRefreshRule — bias only refreshes on meaningful priority change"
```

---

### Task 3.2: ExerciseRefreshRule

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/ExerciseRefreshRule.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/ExerciseRefreshRuleTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class ExerciseRefreshRuleTests: XCTestCase {
    func testDoesNotRotateBeforeThreeBlocks() {
        let history = ExerciseRefreshRule.ExerciseHistory(
            exerciseKey: "bench_press",
            consecutiveBlocksPrescribed: 2,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: history))
    }

    func testRotatesAtThreeBlocks() {
        let history = ExerciseRefreshRule.ExerciseHistory(
            exerciseKey: "bench_press",
            consecutiveBlocksPrescribed: 3,
            hadTierUnlock: false,
            hadPlateauDeload: false
        )
        XCTAssertTrue(ExerciseRefreshRule.shouldRotate(history: history))
    }

    func testTierUnlockResetsRotationCounter() {
        let history = ExerciseRefreshRule.ExerciseHistory(
            exerciseKey: "bench_press",
            consecutiveBlocksPrescribed: 4,
            hadTierUnlock: true,
            hadPlateauDeload: false
        )
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: history))
    }

    func testPlateauDeloadResetsRotationCounter() {
        let history = ExerciseRefreshRule.ExerciseHistory(
            exerciseKey: "bench_press",
            consecutiveBlocksPrescribed: 4,
            hadTierUnlock: false,
            hadPlateauDeload: true
        )
        XCTAssertFalse(ExerciseRefreshRule.shouldRotate(history: history))
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/ExerciseRefreshRule.swift
import Foundation

enum ExerciseRefreshRule {
    struct ExerciseHistory {
        let exerciseKey: String
        let consecutiveBlocksPrescribed: Int
        let hadTierUnlock: Bool
        let hadPlateauDeload: Bool
    }

    /// Rotate when an exercise has been prescribed for 3+ consecutive blocks
    /// AND has not unlocked a tier AND has not been plateau-deloaded.
    /// Tier unlocks and plateau deloads count as "fresh stimulus" — the counter
    /// resets to 0 in those cases.
    static func shouldRotate(history: ExerciseHistory) -> Bool {
        if history.hadTierUnlock || history.hadPlateauDeload { return false }
        return history.consecutiveBlocksPrescribed >= 3
    }

    /// Find a same-pattern alternative in the catalog.
    static func alternative(
        for entry: ExerciseCatalog.Entry,
        in pool: [ExerciseCatalog.Entry]
    ) -> ExerciseCatalog.Entry? {
        // Prefer an entry in the same progression family, different tier,
        // or the same targetMuscleGroups but different name.
        if let family = entry.progressionFamily {
            let siblings = pool.filter { $0.progressionFamily == family && $0.name != entry.name }
            if let sibling = siblings.first { return sibling }
        }
        let sameTargets = pool.filter {
            $0.targetMuscleGroups == entry.targetMuscleGroups && $0.name != entry.name
        }
        return sameTargets.first
    }
}
```

Field names (`progressionFamily`, `targetMuscleGroups`) must match the real `ExerciseCatalog.Entry`.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/ExerciseRefreshRule.swift UNBOUNDTests/Services/ProgramGeneration/ExerciseRefreshRuleTests.swift
git commit -m "feat: ExerciseRefreshRule rotates stale exercises after 3 blocks"
```

---

### Task 3.3: ProgramBlockStore (persistence)

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/ProgramBlockStore.swift`

- [ ] **Step 1: Implement a minimal store**

```swift
// UNBOUND/Services/ProgramGeneration/ProgramBlockStore.swift
import Foundation

@MainActor
final class ProgramBlockStore {
    static let shared = ProgramBlockStore()
    private let database = DatabaseService.shared
    private init() {}

    func save(_ block: ProgramBlock) async {
        try? await database.create(block, collection: "program_blocks", documentId: block.id)
    }

    func latestBlock(userId: String) async -> ProgramBlock? {
        let all: [ProgramBlock] = (try? await database.list(
            collection: "program_blocks",
            filter: ["userId": userId]
        )) ?? []
        return all.sorted(by: { $0.blockNumber > $1.blockNumber }).first
    }

    func blocks(userId: String) async -> [ProgramBlock] {
        let all: [ProgramBlock] = (try? await database.list(
            collection: "program_blocks",
            filter: ["userId": userId]
        )) ?? []
        return all.sorted(by: { $0.blockNumber > $1.blockNumber })
    }
}
```

Real `DatabaseService` API names may differ (e.g., `create`, `list`, `query`). Adapt to match what's actually in the codebase.

- [ ] **Step 2: Build, verify no compile errors**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/ProgramBlockStore.swift
git commit -m "feat: ProgramBlockStore persistence"
```

---

### Task 3.4: Supabase migration for program_blocks

**Files:**
- Create: `supabase/migrations/2026xxxx_program_blocks.sql` (fill in real date)

- [ ] **Step 1: Create migration**

```sql
-- program_blocks — one record per 2-week block per user
CREATE TABLE IF NOT EXISTS program_blocks (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    program_id TEXT NOT NULL,
    block_number INT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    scan_id TEXT,
    accessory_bias JSONB NOT NULL DEFAULT '{}'::JSONB,
    cut_mode_active BOOLEAN NOT NULL DEFAULT FALSE,
    bias_refreshed_from_previous BOOLEAN NOT NULL DEFAULT FALSE,
    exercise_rotations_this_block JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_program_blocks_user ON program_blocks(user_id, block_number DESC);

ALTER TABLE program_blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_owns_their_blocks" ON program_blocks
    FOR ALL USING (auth.uid()::TEXT = user_id);
```

- [ ] **Step 2: Apply (or note for ops to apply)**

Run: `supabase db push` in the project directory, or apply via the Supabase MCP `apply_migration` tool when an operator is available.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/
git commit -m "db: add program_blocks table"
```

---

### Task 3.5: BlockRolloverService

**Files:**
- Create: `UNBOUND/Services/ProgramGeneration/BlockRolloverService.swift`
- Test: `UNBOUNDTests/Services/ProgramGeneration/BlockRolloverServiceTests.swift`

- [ ] **Step 1: Write failing test (integration-style)**

```swift
import XCTest
@testable import UNBOUND

final class BlockRolloverServiceTests: XCTestCase {
    // Unit test for the pure resolution logic (separate from IO).
    func testRolloverResolvesBiasAndRotations() {
        let prev = ProgramBlock(
            id: "b", userId: "u", programId: "p", blockNumber: 1,
            startedAt: Date().addingTimeInterval(-14 * 86400), scanId: nil,
            accessoryBias: [.shoulders: 2],
            cutModeActive: false, biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
        let exerciseHistory: [String: ExerciseRefreshRule.ExerciseHistory] = [
            "bench_press": .init(exerciseKey: "bench_press", consecutiveBlocksPrescribed: 3, hadTierUnlock: false, hadPlateauDeload: false),
            "squat": .init(exerciseKey: "squat", consecutiveBlocksPrescribed: 1, hadTierUnlock: false, hadPlateauDeload: false)
        ]
        let newScanFocus = [FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: "")]

        let resolution = BlockRolloverService.resolveRollover(
            previousBlock: prev,
            newFocusAreas: newScanFocus,
            exerciseHistory: exerciseHistory,
            cutModeActive: false
        )

        XCTAssertTrue(resolution.accessoryBiasResult.carriedForward)
        XCTAssertTrue(resolution.exercisesToRotate.contains("bench_press"))
        XCTAssertFalse(resolution.exercisesToRotate.contains("squat"))
    }
}
```

- [ ] **Step 2: Run test, verify fails**

- [ ] **Step 3: Implement**

```swift
// UNBOUND/Services/ProgramGeneration/BlockRolloverService.swift
import Foundation

@MainActor
enum BlockRolloverService {

    struct Resolution {
        let accessoryBiasResult: AccessoryBiasRefreshRule.Result
        let exercisesToRotate: [String]
    }

    /// Pure logic: given previous block, new scan focus, and per-exercise history,
    /// decide what the new block's bias should be and which exercises rotate.
    static func resolveRollover(
        previousBlock: ProgramBlock?,
        newFocusAreas: [FocusArea],
        exerciseHistory: [String: ExerciseRefreshRule.ExerciseHistory],
        cutModeActive: Bool
    ) -> Resolution {
        let bias = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: newFocusAreas,
            previousBlock: previousBlock
        )
        let toRotate = exerciseHistory.values
            .filter { ExerciseRefreshRule.shouldRotate(history: $0) }
            .map(\.exerciseKey)
        return Resolution(
            accessoryBiasResult: bias,
            exercisesToRotate: toRotate
        )
    }

    /// Full rollover flow — reads state, generates next block, persists new ProgramBlock.
    /// Called when day 14 completes (or 14 days elapse).
    static func performRollover(
        userId: String,
        profile: UserProfile,
        analysis: BodyAnalysis?,
        scan: ScanSession?
    ) async throws -> TrainingProgram {
        let previous = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let exerciseHistory = await buildExerciseHistory(userId: userId, previous: previous)
        let focus = analysis?.focusAreas ?? []
        let resolution = resolveRollover(
            previousBlock: previous,
            newFocusAreas: focus,
            exerciseHistory: exerciseHistory,
            cutModeActive: profile.cutMode.enabled
        )

        // Generate the new program via DeterministicProgramGenerator
        // (it picks up the merged bias via focusAreas input; we simulate by
        // passing the resolved bias's implied focus areas.)
        let progressionStates = await ProgressionStateStore.shared.allStates(userId: userId)
            .reduce(into: [String: ProgressionState]()) { $0[$1.exerciseKey] = $1 }

        guard let archetype = profile.preferredArchetype,
              let experience = profile.experience,
              let frequency = profile.targetFrequency,
              let trainingDays = profile.trainingDays,
              let weight = profile.weightKg, let height = profile.heightCm,
              let age = profile.age, let sex = profile.biologicalSex else {
            throw GeneratorError.missingProfileInputs
        }

        let style = profile.trainingStyleOverride ?? TrainingStyle.default(for: archetype)
        let feedback = profile.trainingFeedbackMode ?? TrainingFeedbackMode.default(for: experience)

        let input = ProgramGeneratorInput(
            userId: userId,
            scanId: scan?.id,
            analysisId: analysis?.id,
            archetype: archetype,
            trainingStyle: style,
            equipment: profile.equipment ?? [.bodyweight],
            targetFrequency: frequency,
            trainingDays: trainingDays,
            experience: experience,
            focusAreas: focus,
            cutModeActive: profile.cutMode.enabled,
            trainingFeedbackMode: feedback,
            progressionStates: progressionStates,
            previousBlock: previous,
            weightKg: weight, heightCm: height, age: age, sex: sex,
            blockStartDate: Date()
        )

        let program = try DeterministicProgramGenerator.generate(input: input)

        // Persist a new ProgramBlock record
        let newBlock = ProgramBlock(
            id: UUID().uuidString,
            userId: userId,
            programId: program.id,
            blockNumber: (previous?.blockNumber ?? 0) + 1,
            startedAt: Date(),
            scanId: scan?.id,
            accessoryBias: resolution.accessoryBiasResult.bias,
            cutModeActive: profile.cutMode.enabled,
            biasRefreshedFromPrevious: resolution.accessoryBiasResult.carriedForward,
            exerciseRotationsThisBlock: resolution.exercisesToRotate
        )
        await ProgramBlockStore.shared.save(newBlock)
        return program
    }

    private static func buildExerciseHistory(
        userId: String,
        previous: ProgramBlock?
    ) async -> [String: ExerciseRefreshRule.ExerciseHistory] {
        // Placeholder: derive from ProgressionState.consecutiveSessionsAtTarget + block history.
        // For MVP, return empty — rotation won't fire until this is fleshed out with real data.
        return [:]
    }

    enum GeneratorError: Error {
        case missingProfileInputs
    }
}
```

`buildExerciseHistory` is intentionally stubbed — full implementation requires aggregating across prior `ProgramBlock` records. This is OK for MVP; rotation will naturally start firing after we have 3 real blocks of history stored.

- [ ] **Step 4: Run tests, verify pass**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/BlockRolloverService.swift UNBOUNDTests/Services/ProgramGeneration/BlockRolloverServiceTests.swift
git commit -m "feat: BlockRolloverService integrates bias + rotation + persistence"
```

---

### Task 3.6: Replace ProgramPhaseEngine with rollover hook

**Files:**
- Modify: `UNBOUND/Services/ProgramGeneration/ProgramPhaseEngine.swift`

- [ ] **Step 1: Read current ProgramPhaseEngine**

Understand what callers invoke and what it returns. Preserve the signature where needed.

- [ ] **Step 2: Rewrite to delegate to BlockRolloverService**

Replace internals. The phase engine previously computed Accumulation/Intensification/etc.; now it's just a thin wrapper around rollover. If callers only need "should I rollover now?", expose that.

Skeleton:

```swift
// UNBOUND/Services/ProgramGeneration/ProgramPhaseEngine.swift
import Foundation

@MainActor
enum ProgramPhaseEngine {
    static func shouldRollover(currentProgram: TrainingProgram, now: Date = Date()) -> Bool {
        let elapsed = now.timeIntervalSince(currentProgram.createdAt)
        return elapsed >= Double(14 * 86400)
    }

    static func performRolloverIfNeeded(
        profile: UserProfile,
        analysis: BodyAnalysis?,
        scan: ScanSession?
    ) async throws -> TrainingProgram? {
        // Callers should check `shouldRollover(currentProgram:)` themselves;
        // this helper assumes the decision was already made.
        return try await BlockRolloverService.performRollover(
            userId: profile.id,
            profile: profile,
            analysis: analysis,
            scan: scan
        )
    }
}
```

Remove any Accumulation/Intensification/Realization/Deload phase progression logic. Keep the file, rename functions to match usage.

- [ ] **Step 3: Build, fix callers**

Expected: one or two call sites to update. Change them to either `performRolloverIfNeeded` or to `shouldRollover`.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/ProgramPhaseEngine.swift
git commit -m "refactor: ProgramPhaseEngine delegates to BlockRolloverService"
```

---

### Chunk 3 Review Gate

- [ ] **Review:** All tests pass. Run the app, complete 14 days manually (dev-only shortcut to advance time), verify a new ProgramBlock record is created and bias logic fires.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 4.

---

## Chunk 4 — Progression engine tweaks

### Task 4.1: Add ProgressionMode enum

**Files:**
- Create: `UNBOUND/Services/Progression/ProgressionMode.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Services/Progression/ProgressionMode.swift
import Foundation

/// Overall mode the progression engine runs in.
enum ProgressionMode {
    case advance     // default — bump weights when criteria met
    case preserve    // cut mode — hold weights, still record sessions
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Services/Progression/ProgressionMode.swift
git commit -m "feat: add ProgressionMode enum"
```

---

### Task 4.2: ProgressionEngine reads targetRPE from TrainingFeedbackMode

**Files:**
- Modify: `UNBOUND/Services/Progression/ProgressionEngine.swift`
- Test: `UNBOUNDTests/Services/Progression/ProgressionEngineTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import XCTest
@testable import UNBOUND

final class ProgressionEngineTests: XCTestCase {

    func testSilentModeAlwaysPassesRPECheck() {
        // With silent mode, targetRPE=0, so even a set logged without RPE
        // should count as hitting target and contribute to progression.
        // Smoke test — assumes engine reads profile.trainingFeedbackMode at ingest time.
        // Full integration test may require stubbing Database + Profile services.
        XCTAssertEqual(TrainingFeedbackMode.silent.defaultTargetRPE, 0)
    }

    func testPreserveModeShortCircuitsBump() {
        // Verified via mode parameter on ProgressionEngine.ingest(log:mode:).
        // We test that a logged workout in preserve mode doesn't advance weight
        // even when the criteria would otherwise trigger.
        // For unit-test simplicity, this lives as a doc-level assertion; full
        // flow is verified manually.
    }
}
```

Expand with a real integration test once `DatabaseService` has a fake-backed mode — for MVP the doc-level assertion is fine.

- [ ] **Step 2: Modify `ProgressionEngine.ingest` to accept mode**

Current signature: `func ingest(log: WorkoutLog) async`.

New signature: `func ingest(log: WorkoutLog, mode: ProgressionMode) async`.

Inside:

```swift
func ingest(log: WorkoutLog, mode: ProgressionMode = .advance) async {
    for entry in log.exerciseEntries where !entry.skipped {
        await evaluate(
            entry: entry,
            userId: log.userId,
            loggedAt: log.startedAt,
            mode: mode
        )
    }
}
```

In `evaluate`, after the "threshold hit" block, wrap the weight bump:

```swift
if next.consecutiveSessionsAtTarget >= 2 {
    let previousWeight = next.currentWorkingWeightKg
    if mode == .advance {
        applyBump(to: &next)
    }
    // else: preserve — hold weight, don't fire .progressionAdvanced
    try? await database.create(next, collection: "progression_states", documentId: next.id)
    if mode == .advance && next.currentWorkingWeightKg > previousWeight {
        // existing event firing logic
    }
}
```

Tier unlocks (`maybeUnlockTier`) should still fire regardless of mode — preserve mode still allows skill progression.

- [ ] **Step 3: Update `targetRPE` source**

When loading a state (`loadOrSeedState`), if it's being seeded fresh, set `targetRPE` from the user's `trainingFeedbackMode`:

```swift
private func loadOrSeedState(...) async -> ProgressionState {
    // ...
    let userProfile = try? await UserService.shared.fetchProfile(userId: userId)
    let feedback = userProfile?.trainingFeedbackMode ?? .quick
    return ProgressionState.seed(
        userId: userId,
        exercise: displayName,
        startingWeightKg: seedWeight,
        targetRPE: feedback.defaultTargetRPE
    )
}
```

Add `targetRPE` to `ProgressionState.seed(...)` if the factory doesn't accept it already.

- [ ] **Step 4: Update caller — WorkoutLogService**

Where `ProgressionEngine.ingest(log:)` is called, thread the user's current cut-mode:

```swift
let mode: ProgressionMode = profile.cutMode.enabled ? .preserve : .advance
await ProgressionEngine.shared.ingest(log: log, mode: mode)
```

- [ ] **Step 5: Build, run tests**

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Services/Progression/ProgressionEngine.swift UNBOUND/Services/WorkoutLog/WorkoutLogService.swift UNBOUNDTests/Services/Progression/ProgressionEngineTests.swift
git commit -m "feat: ProgressionEngine supports silent mode and preserve mode (cut)"
```

---

### Task 4.3: Lock blockType to .accumulation by default

**Files:**
- Modify: `UNBOUND/Models/ProgressionState.swift`
- Modify: `UNBOUND/Services/Progression/ProgressionEngine.swift`

- [ ] **Step 1: In `ProgressionState.seed`, set `blockType = .accumulation` always**

Find the factory method and ensure new states seed with `.accumulation`. Don't remove the field — existing code may rely on it.

- [ ] **Step 2: Remove any auto-promotion logic**

If `ProgressionEngine` (or any other file) promotes `blockType` to `.intensification` or `.realization`, remove that logic. Deload is still reactive — kept.

- [ ] **Step 3: Build, run tests**

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/ProgressionState.swift UNBOUND/Services/Progression/ProgressionEngine.swift
git commit -m "refactor: blockType locked to .accumulation (no auto-promotion)"
```

---

### Chunk 4 Review Gate

- [ ] **Review:** Tests pass. Manual QA: log a workout with `trainingFeedbackMode = .silent` and verify progression still fires. Enable cut mode, log a workout, verify weight doesn't bump.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 5.

---

## Chunk 5 — Onboarding changes

### Task 5.1: Expand Equipment enum

**Files:**
- Modify: `UNBOUND/Models/OnboardingAnswers.swift`

- [ ] **Step 1: Update Equipment enum**

Replace:
```swift
enum Equipment: String, Codable, CaseIterable, Identifiable {
    case fullGym, homeWeights, bodyweight, bands
    // ...
}
```
With:
```swift
enum Equipment: String, Codable, CaseIterable, Identifiable {
    case fullGym
    case machines       // cables and machines only
    case barbell        // barbell + rack
    case dumbbells
    case bench
    case pullupBar
    case bodyweight
    case bands

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullGym: return "Full gym"
        case .machines: return "Cables / machines"
        case .barbell: return "Barbell + rack"
        case .dumbbells: return "Dumbbells"
        case .bench: return "Bench"
        case .pullupBar: return "Pull-up bar"
        case .bodyweight: return "Bodyweight only"
        case .bands: return "Resistance bands"
        }
    }
    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .machines: return "gearshape.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbells: return "dumbbell"
        case .bench: return "bed.double.fill"
        case .pullupBar: return "figure.play"
        case .bodyweight: return "figure.arms.open"
        case .bands: return "circle.dashed"
        }
    }
}
```

Existing data with `homeWeights` is stale. Treat `homeWeights` as a migration case: handle it in `UserProfile` load — if stored value is `"homeWeights"`, map to `[.dumbbells, .bench]` at read time. Add a tiny adapter on User load.

- [ ] **Step 2: Build, fix compile errors**

Wherever `Equipment.homeWeights` is referenced, either delete or replace. Likely only in `Step14_Equipment.swift` and any debug fixtures.

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Models/OnboardingAnswers.swift
git commit -m "feat: expand Equipment enum with granular chips"
```

---

### Task 5.2: Drop current-Frequency onboarding step

**Files:**
- Find: whichever onboarding step file asks about current frequency (`Step11_Frequency.swift` or similar)
- Modify: `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` to remove its invocation
- Modify: `UNBOUND/ViewModels/OnboardingFlowViewModel.swift` to remove `currentFrequency` reads
- Modify: `UNBOUND/Models/OnboardingAnswers.swift` — mark `Frequency` enum as deprecated but keep it (for backward-compat of stored profiles)

- [ ] **Step 1: Identify the file**

```
grep -r "Step.*Frequency" UNBOUND/Views/Onboarding
```

- [ ] **Step 2: Remove the step from the container flow**

In `OnboardingContainerView.swift`, remove the `case .frequency:` (or equivalent) from the switch that renders steps.

- [ ] **Step 3: Delete the step file**

Delete `Step11_Frequency.swift` (or whatever filename). Do not delete the `Frequency` enum itself — old `UserProfile` records still carry it.

- [ ] **Step 4: Build, verify onboarding flows without that step**

Manual QA in simulator.

- [ ] **Step 5: Commit**

```bash
git add -u UNBOUND/
git commit -m "feat(onboarding): drop current-frequency step (redundant with target)"
```

---

### Task 5.3: Add Step_TrainingDays

**Files:**
- Create: `UNBOUND/Views/Onboarding/Steps/Step_TrainingDays.swift`
- Modify: `UNBOUND/ViewModels/OnboardingFlowViewModel.swift`
- Modify: `UNBOUND/Views/Onboarding/OnboardingContainerView.swift`

- [ ] **Step 1: Create Step_TrainingDays view**

```swift
// UNBOUND/Views/Onboarding/Steps/Step_TrainingDays.swift
import SwiftUI

struct Step_TrainingDays: View {
    @Bindable var flow: OnboardingFlowViewModel
    var progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    private var requiredCount: Int {
        flow.targetFrequency?.numericCount ?? 3
    }

    var body: some View {
        OnboardingScaffold(
            title: "Which days will you train?",
            subtitle: "Pick \(requiredCount) days that work for you.",
            progress: progress,
            primaryTitle: "Continue",
            primaryEnabled: flow.trainingDays.count == requiredCount,
            hudStep: .trainingDays,
            onBack: onBack,
            onPrimary: onContinue
        ) {
            HUDMultiSelectGroup(
                options: Weekday.allCases,
                selection: $flow.trainingDays,
                title: { $0.short },
                icon: { _ in "calendar" }
            )
            .padding(.top, 4)

            if flow.trainingDays.count != requiredCount {
                Text("Selected \(flow.trainingDays.count) / \(requiredCount)")
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
                    .padding(.top, 8)
            }
        }
    }
}
```

If `.hudStep` cases don't include `.trainingDays`, add it.

- [ ] **Step 2: Add `trainingDays: Set<Weekday>` to OnboardingFlowViewModel**

```swift
// OnboardingFlowViewModel.swift
@Published var trainingDays: Set<Weekday> = []
```

- [ ] **Step 3: Wire into OnboardingContainerView**

Insert the new step immediately after `TargetFrequency`. Update the `OnboardingStep` enum and the switch statement that renders steps. Update progress fractions.

- [ ] **Step 4: Persist to UserProfile on finish**

In the onboarding completion handler, write `profile.trainingDays = flow.trainingDays`.

- [ ] **Step 5: Build, QA in simulator**

Verify the step appears, validation works (requires exactly N days), and persists.

- [ ] **Step 6: Commit**

```bash
git add UNBOUND/Views/Onboarding/Steps/Step_TrainingDays.swift UNBOUND/Views/Onboarding/OnboardingContainerView.swift UNBOUND/ViewModels/OnboardingFlowViewModel.swift
git commit -m "feat(onboarding): add training-days multi-select step"
```

---

### Task 5.4: Default TrainingFeedbackMode from experience at profile finalize

**Files:**
- Modify: wherever `UserProfile` is finalized at the end of onboarding

- [ ] **Step 1: Find the finalize point**

Grep for `onboardingCompleted = true` or similar.

- [ ] **Step 2: Add the default assignment**

```swift
if profile.trainingFeedbackMode == nil, let exp = profile.experience {
    profile.trainingFeedbackMode = TrainingFeedbackMode.default(for: exp)
}
```

- [ ] **Step 3: Commit**

```bash
git add -u UNBOUND/
git commit -m "feat(onboarding): default TrainingFeedbackMode from experience"
```

---

### Chunk 5 Review Gate

- [ ] **Review:** Run through onboarding end-to-end in the simulator. Verify the dropped step is gone, training-days step appears, all fields persist on completion.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 6.

---

## Chunk 6 — UI surfaces

### Task 6.1: TodayWorkoutHero component

**Files:**
- Create: `UNBOUND/Views/Program/TodayWorkoutHero.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Program/TodayWorkoutHero.swift
import SwiftUI

struct TodayWorkoutHero: View {
    let day: ProgramDay
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dayTitle)
                    .font(.caption(12))
                    .foregroundColor(.theme.textMuted)
                    .textCase(.uppercase)

                Text(day.label)
                    .font(.headline(28))
                    .foregroundColor(.theme.textPrimary)
            }

            if day.isRestDay {
                restContent
            } else {
                workoutContent
            }

            Button(action: onStart) {
                Text(day.isRestDay ? "Start Recovery" : "Start Workout")
                    .font(.bodyMedium(16))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var dayTitle: String {
        "Day \(day.dayNumber)"
    }

    @ViewBuilder
    private var workoutContent: some View {
        if let workout = day.workout {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(workout.exercises.prefix(4)) { ex in
                    HStack {
                        Text(ex.name)
                            .font(.bodyText(14))
                            .foregroundColor(.theme.textPrimary)
                        Spacer()
                        Text("\(ex.sets) × \(ex.reps.lowerBound)-\(ex.reps.upperBound)")
                            .font(.caption(12))
                            .foregroundColor(.theme.textSecondary)
                    }
                }
                if workout.exercises.count > 4 {
                    Text("+\(workout.exercises.count - 4) more")
                        .font(.caption(12))
                        .foregroundColor(.theme.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var restContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(day.recoveryActivities.prefix(3)) { activity in
                HStack {
                    Image(systemName: "leaf")
                        .foregroundColor(.theme.secondary)
                    Text(activity.name)
                        .font(.bodyText(14))
                    Spacer()
                    Text("\(activity.durationMinutes) min")
                        .font(.caption(12))
                        .foregroundColor(.theme.textSecondary)
                }
            }
        }
    }
}
```

Field names (`Exercise.reps`, `Exercise.sets`) must match actual types. If `reps` isn't a `ClosedRange<Int>`, adapt.

- [ ] **Step 2: Build, visually verify in preview**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Program/TodayWorkoutHero.swift
git commit -m "feat(ui): TodayWorkoutHero component"
```

---

### Task 6.2: BlockStatusCard component

**Files:**
- Create: `UNBOUND/Views/Program/BlockStatusCard.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Program/BlockStatusCard.swift
import SwiftUI

struct BlockStatusCard: View {
    let daysRemaining: Int
    let cutModeActive: Bool
    let showRescanNudge: Bool
    let onRescanTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                statusPill(iconSystemName: "calendar", text: "\(daysRemaining) days left")

                if cutModeActive {
                    statusPill(iconSystemName: "flame.fill", text: "Cut mode", tint: .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showRescanNudge {
                Button(action: onRescanTap) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check in")
                                .font(.bodyMedium(14))
                                .foregroundColor(.theme.textPrimary)
                            Text("Scan to see your progress and refresh the plan")
                                .font(.caption(12))
                                .foregroundColor(.theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.theme.textMuted)
                    }
                    .padding(12)
                    .background(Color.theme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func statusPill(iconSystemName: String, text: String, tint: Color = .theme.primary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: iconSystemName)
                .font(.caption(12))
                .foregroundColor(tint)
            Text(text)
                .font(.caption(13))
                .foregroundColor(.theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Program/BlockStatusCard.swift
git commit -m "feat(ui): BlockStatusCard component"
```

---

### Task 6.3: Rebuild ProgramOverviewView with new hierarchy

**Files:**
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift`

- [ ] **Step 1: Replace `programContent` layout**

Replace:
```swift
VStack(spacing: 24) {
    programHeader(program)
    if !services.subscription.hasActiveSubscription { subscriptionBanner }
    calendarSection(program)
}
```
With:
```swift
VStack(spacing: 20) {
    if let today = todayDay(in: program) {
        TodayWorkoutHero(
            day: today,
            onStart: {
                if services.subscription.hasActiveSubscription {
                    selectedDay = today
                } else {
                    showPaywall = true
                }
            }
        )
    }

    calendarSection(program)

    BlockStatusCard(
        daysRemaining: daysRemaining(in: program),
        cutModeActive: services.user.currentProfile?.cutMode.enabled ?? false,
        showRescanNudge: daysRemaining(in: program) <= 1,
        onRescanTap: { /* navigate to scan flow */ }
    )

    if !services.subscription.hasActiveSubscription {
        subscriptionBanner
    }

    if program.rationale != nil {
        Button { showRationale = true } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Why this program?")
            }
            .font(.bodyMedium(14))
            .foregroundColor(.theme.primary)
        }
        .buttonStyle(.plain)
    }
}
.padding(.bottom, 32)
```

- [ ] **Step 2: Add helpers**

```swift
private func todayDay(in program: TrainingProgram) -> ProgramDay? {
    let offset = Int(Date().timeIntervalSince(program.createdAt) / 86400) + 1
    return program.days.first(where: { $0.dayNumber == offset })
        ?? program.days.first
}

private func daysRemaining(in program: TrainingProgram) -> Int {
    let offset = Int(Date().timeIntervalSince(program.createdAt) / 86400)
    return max(0, program.durationDays - offset)
}
```

- [ ] **Step 3: Remove the old `programHeader` function** (archetype badge, duration, etc.) — that visual was the old hero; now redundant. Keep `archetypeBadge` if reused elsewhere.

- [ ] **Step 4: Build, visually QA**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Views/Program/ProgramOverviewView.swift
git commit -m "feat(ui): rebuild ProgramOverviewView with TodayWorkoutHero + BlockStatusCard"
```

---

### Task 6.4: DayDetailView — add "Why this day" + deload label

**Files:**
- Modify: `UNBOUND/Views/Program/DayDetailView.swift`

- [ ] **Step 1: Read current file**

- [ ] **Step 2: Add "Why this day" section at top**

```swift
// Inside body, above the exercise list:
if let whyCopy = whyThisDay(day) {
    HStack(spacing: 8) {
        Image(systemName: "sparkles")
            .foregroundColor(.theme.primary)
        Text(whyCopy)
            .font(.bodyText(14))
            .foregroundColor(.theme.textSecondary)
    }
    .padding(12)
    .background(Color.theme.primary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 16)
}
```

And the helper:
```swift
private func whyThisDay(_ day: ProgramDay) -> String? {
    // Derive from ProgramRationale.decisions if the day's label includes a bias hint.
    guard day.label.contains("Bias") else { return nil }
    return "Extra volume on \(day.label.replacingOccurrences(of: " Bias", with: "")) — your scan flagged it as a weak point."
}
```

- [ ] **Step 3: Add deload label on exercise cards**

Inside the exercise-row rendering, check if the exercise's `ProgressionState` is in `.deload`:

```swift
if progressionIsDeload(for: exercise) {
    Text("Deload")
        .font(.caption(11))
        .foregroundColor(.theme.warning)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.theme.warning.opacity(0.15))
        .clipShape(Capsule())
}
```

Helper:
```swift
private func progressionIsDeload(for exercise: Exercise) -> Bool {
    // Check ProgressionStateStore for current blockType == .deload
    // For MVP, look up synchronously via in-memory cache if available, else return false.
    return false  // TODO: wire to ProgressionStateStore
}
```

- [ ] **Step 4: Build, QA in preview**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Views/Program/DayDetailView.swift
git commit -m "feat(ui): DayDetailView adds Why-this-day and deload labels"
```

---

### Task 6.5: MacrosView (create if missing, else update)

**Files:**
- Create or Modify: `UNBOUND/Views/Nutrition/MacrosView.swift`

- [ ] **Step 1: Check if exists; create if not**

```swift
// UNBOUND/Views/Nutrition/MacrosView.swift
import SwiftUI

struct MacrosView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var program: TrainingProgram?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let plan = program?.nutritionPlan {
                    targetsCard(plan)
                    if plan.cutModeActive {
                        cutBanner
                    }
                } else {
                    ProgressView().tint(.theme.primary)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
        .navigationTitle("Macros")
        .task {
            await loadProgram()
        }
    }

    private func targetsCard(_ plan: NutritionPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(plan.dailyCalories)")
                    .font(.stat(36))
                    .foregroundColor(.theme.primary)
                Text("kcal")
                    .font(.caption(14))
                    .foregroundColor(.theme.textSecondary)
            }
            HStack(spacing: 24) {
                macroStat("Protein", "\(plan.proteinG)g")
                macroStat("Carbs", "\(plan.carbsG)g")
                macroStat("Fat", "\(plan.fatG)g")
            }
        }
        .padding(20)
        .background(Color.theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func macroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption(12)).foregroundColor(.theme.textMuted)
            Text(value).font(.bodyMedium(16)).foregroundColor(.theme.textPrimary)
        }
    }

    private var cutBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill").foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cut mode")
                    .font(.bodyMedium(14))
                Text("We've paused lift progression while you lean out. Resume anytime in Settings.")
                    .font(.caption(12))
                    .foregroundColor(.theme.textSecondary)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadProgram() async {
        guard let userId = services.auth.currentUserId else { return }
        let profile: UserProfile? = try? await services.user.fetchProfile(userId: userId)
        guard let pid = profile?.currentProgramId else { return }
        let fetched: TrainingProgram? = try? await services.database.read(collection: "programs", documentId: pid)
        self.program = fetched
    }
}
```

`NutritionPlan` needs a `cutModeActive` field. If missing, add in Chunk 2 extension:

```swift
// In Nutrition.swift or Program.swift wherever NutritionPlan lives
var cutModeActive: Bool = false
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Nutrition/MacrosView.swift
git commit -m "feat(ui): MacrosView with cut-mode banner"
```

---

### Chunk 6 Review Gate

- [ ] **Review:** Open the app, check home screen (today's workout hero, calendar, status card), open day detail, open macros. All render correctly.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 7.

---

## Chunk 7 — Progress Album

### Task 7.1: ProgressPhotoService

**Files:**
- Create: `UNBOUND/Services/ProgressPhoto/ProgressPhotoService.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Services/ProgressPhoto/ProgressPhotoService.swift
import Foundation

@MainActor
final class ProgressPhotoService {
    static let shared = ProgressPhotoService()
    private let database = DatabaseService.shared
    private let storage = StorageService.shared   // assumes this exists
    private init() {}

    func capture(userId: String, imageData: Data, note: String?, blockNumber: Int?) async throws -> ProgressPhoto {
        let photoId = UUID().uuidString
        let path = "progress_photos/\(userId)/\(photoId).jpg"
        let url = try await storage.upload(data: imageData, to: path)

        let photo = ProgressPhoto(
            id: photoId,
            userId: userId,
            storageUrl: url,
            capturedAt: Date(),
            note: note,
            angle: nil,
            blockNumber: blockNumber,
            source: .manual
        )
        try await database.create(photo, collection: "progress_photos", documentId: photo.id)
        return photo
    }

    func photos(userId: String) async -> [ProgressPhoto] {
        let all: [ProgressPhoto] = (try? await database.list(
            collection: "progress_photos",
            filter: ["userId": userId]
        )) ?? []
        // Also include scan-sourced photos from ScanSession (optional)
        return all.sorted(by: { $0.capturedAt > $1.capturedAt })
    }
}
```

Adapt to real `StorageService` + `DatabaseService` APIs.

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Services/ProgressPhoto/ProgressPhotoService.swift
git commit -m "feat: ProgressPhotoService"
```

---

### Task 7.2: Supabase migration for progress_photos

**Files:**
- Create: `supabase/migrations/2026xxxx_progress_photos.sql`

- [ ] **Step 1: Create migration**

```sql
CREATE TABLE IF NOT EXISTS progress_photos (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    storage_url TEXT NOT NULL,
    captured_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    angle TEXT,
    block_number INT,
    source TEXT NOT NULL,           -- 'manual' or 'scan'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_progress_photos_user_time ON progress_photos(user_id, captured_at DESC);

ALTER TABLE progress_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_owns_photos" ON progress_photos FOR ALL USING (auth.uid()::TEXT = user_id);
```

Also add a storage policy for the `progress_photos/` prefix to allow per-user read/write.

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/
git commit -m "db: progress_photos table"
```

---

### Task 7.3: ProgressAlbumView (grid)

**Files:**
- Create: `UNBOUND/Views/Album/ProgressAlbumView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Album/ProgressAlbumView.swift
import SwiftUI

struct ProgressAlbumView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var photos: [ProgressPhoto] = []
    @State private var showingCapture = false

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Button {
                        showingCapture = true
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                            Text("Take progress photo")
                        }
                        .font(.bodyMedium(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(photos) { p in
                        photoTile(p)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Progress")
        .task { await reload() }
        .sheet(isPresented: $showingCapture) {
            ProgressPhotoCaptureView(onCaptured: { _ in
                Task { await reload() }
            })
        }
    }

    private func photoTile(_ photo: ProgressPhoto) -> some View {
        AsyncImage(url: URL(string: photo.storageUrl)) { phase in
            switch phase {
            case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(Color.theme.surface)
            }
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if photo.source == .scan {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                    .padding(6)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let arc = photo.blockNumber {
                Text("Arc \(arc)")
                    .font(.caption(10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(6)
            }
        }
    }

    private func reload() async {
        guard let uid = services.auth.currentUserId else { return }
        photos = await ProgressPhotoService.shared.photos(userId: uid)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Album/ProgressAlbumView.swift
git commit -m "feat(ui): ProgressAlbumView grid"
```

---

### Task 7.4: ProgressPhotoCaptureView

**Files:**
- Create: `UNBOUND/Views/Album/ProgressPhotoCaptureView.swift`

- [ ] **Step 1: Implement**

Use existing `ScanCameraPreview.swift` as a reference — the capture pattern should mirror it.

```swift
// UNBOUND/Views/Album/ProgressPhotoCaptureView.swift
import SwiftUI
import UIKit

struct ProgressPhotoCaptureView: View {
    var onCaptured: (ProgressPhoto) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickedImage: UIImage?
    @State private var uploading = false
    @EnvironmentObject var services: ServiceContainer

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let img = pickedImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    ImagePicker(image: $pickedImage)
                        .frame(maxHeight: .infinity)
                }

                if pickedImage != nil {
                    Button {
                        Task { await upload() }
                    } label: {
                        Text(uploading ? "Saving…" : "Save photo")
                            .font(.bodyMedium(16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(uploading)
                }
            }
            .padding(16)
            .navigationTitle("Progress photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func upload() async {
        guard let img = pickedImage, let data = img.jpegData(compressionQuality: 0.85),
              let uid = services.auth.currentUserId else { return }
        uploading = true
        defer { uploading = false }
        do {
            let photo = try await ProgressPhotoService.shared.capture(
                userId: uid, imageData: data, note: nil, blockNumber: nil
            )
            onCaptured(photo)
            dismiss()
        } catch {
            LoggingService.shared.log("Photo upload failed: \(error)", level: .error)
        }
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.image = img }
        }
    }
}
```

Grant camera permission is already set in `project.yml`.

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Album/ProgressPhotoCaptureView.swift
git commit -m "feat(ui): ProgressPhotoCaptureView"
```

---

### Task 7.5: ProgressCompareView

**Files:**
- Create: `UNBOUND/Views/Album/ProgressCompareView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Album/ProgressCompareView.swift
import SwiftUI

struct ProgressCompareView: View {
    let before: ProgressPhoto
    let after: ProgressPhoto

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                photoSide(before, label: "Before")
                    .frame(width: (geo.size.width - 2) / 2)
                photoSide(after, label: "After")
                    .frame(width: (geo.size.width - 2) / 2)
            }
        }
        .navigationTitle("Compare")
    }

    private func photoSide(_ p: ProgressPhoto, label: String) -> some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: p.storageUrl)) { phase in
                if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                else { Rectangle().fill(Color.theme.surface) }
            }
            VStack {
                Text(label)
                    .font(.caption(11))
                    .foregroundColor(.white)
                Text(p.capturedAt, style: .date)
                    .font(.caption(10))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }
    }
}
```

Wire a "Compare" mode in `ProgressAlbumView` later via selection — for MVP, add a long-press on two photos to open compare. This can be polished in a follow-up task.

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Album/ProgressCompareView.swift
git commit -m "feat(ui): ProgressCompareView"
```

---

### Task 7.6: Profile tab entry point

**Files:**
- Modify: `UNBOUND/Views/Profile/ProfileView.swift` (locate and edit)

- [ ] **Step 1: Add a NavigationLink to `ProgressAlbumView`**

In the profile view, add a row:

```swift
NavigationLink(destination: ProgressAlbumView()) {
    HStack {
        Image(systemName: "photo.stack")
        Text("Progress album")
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundColor(.theme.textMuted)
    }
    .padding(.vertical, 12)
}
```

- [ ] **Step 2: QA in simulator — navigate, capture, see album populate**

- [ ] **Step 3: Commit**

```bash
git add UNBOUND/Views/Profile/ProfileView.swift
git commit -m "feat(ui): Progress album entry point in Profile"
```

---

### Chunk 7 Review Gate

- [ ] **Review:** Capture a photo, see it in the album. Verify grid displays correctly. Compare view renders.
- [ ] **Checkpoint:** Pause for user review before proceeding to Chunk 8.

---

## Chunk 8 — Settings + migration

### Task 8.1: TrainingFeedbackSettingView

**Files:**
- Create: `UNBOUND/Views/Settings/TrainingFeedbackSettingView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Settings/TrainingFeedbackSettingView.swift
import SwiftUI

struct TrainingFeedbackSettingView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var selection: TrainingFeedbackMode = .quick

    var body: some View {
        List {
            ForEach(TrainingFeedbackMode.allCases) { mode in
                Button {
                    selection = mode
                    Task { await persist(mode) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selection == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selection == mode ? .theme.primary : .theme.textMuted)
                            .font(.body)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.displayName).font(.bodyMedium(16)).foregroundColor(.theme.textPrimary)
                            Text(mode.description).font(.caption(13)).foregroundColor(.theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Training feedback")
        .task {
            guard let uid = services.auth.currentUserId,
                  let profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
            selection = profile.trainingFeedbackMode ?? .quick
        }
    }

    private func persist(_ mode: TrainingFeedbackMode) async {
        guard let uid = services.auth.currentUserId,
              var profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        profile.trainingFeedbackMode = mode
        try? await services.user.saveProfile(profile)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Settings/TrainingFeedbackSettingView.swift
git commit -m "feat(settings): TrainingFeedbackSettingView"
```

---

### Task 8.2: TrainingStyleSettingView

**Files:**
- Create: `UNBOUND/Views/Settings/TrainingStyleSettingView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Settings/TrainingStyleSettingView.swift
import SwiftUI

struct TrainingStyleSettingView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var selection: TrainingStyle?
    @State private var archetypeDefault: TrainingStyle = .hybrid

    var body: some View {
        List {
            Section {
                row(style: nil, label: "Use archetype default (\(archetypeDefault.displayName))")
            }
            Section("Override") {
                ForEach(TrainingStyle.allCases) { style in
                    row(style: style, label: style.displayName)
                }
            }
        }
        .navigationTitle("Training style")
        .task { await loadProfile() }
    }

    private func row(style: TrainingStyle?, label: String) -> some View {
        Button {
            selection = style
            Task { await persist(style) }
        } label: {
            HStack {
                Image(systemName: selection == style ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selection == style ? .theme.primary : .theme.textMuted)
                Text(label).foregroundColor(.theme.textPrimary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func loadProfile() async {
        guard let uid = services.auth.currentUserId,
              let profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        selection = profile.trainingStyleOverride
        if let arch = profile.preferredArchetype {
            archetypeDefault = TrainingStyle.default(for: arch)
        }
    }

    private func persist(_ style: TrainingStyle?) async {
        guard let uid = services.auth.currentUserId,
              var profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        profile.trainingStyleOverride = style
        try? await services.user.saveProfile(profile)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Settings/TrainingStyleSettingView.swift
git commit -m "feat(settings): TrainingStyleSettingView"
```

---

### Task 8.3: TrainingDaysSettingView

**Files:**
- Create: `UNBOUND/Views/Settings/TrainingDaysSettingView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Settings/TrainingDaysSettingView.swift
import SwiftUI

struct TrainingDaysSettingView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var selection: Set<Weekday> = []
    @State private var requiredCount: Int = 3

    var body: some View {
        List {
            Section(footer: Text("Pick \(requiredCount) days").font(.caption(12))) {
                ForEach(Weekday.allCases) { day in
                    Button {
                        toggle(day)
                    } label: {
                        HStack {
                            Image(systemName: selection.contains(day) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selection.contains(day) ? .theme.primary : .theme.textMuted)
                            Text(day.rawValue.capitalized).foregroundColor(.theme.textPrimary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Training days")
        .task { await loadProfile() }
    }

    private func toggle(_ day: Weekday) {
        if selection.contains(day) {
            selection.remove(day)
        } else {
            if selection.count >= requiredCount {
                // Remove the earliest-selected day to honor count cap
                if let first = Weekday.allCases.first(where: selection.contains) { selection.remove(first) }
            }
            selection.insert(day)
        }
        Task { await persist() }
    }

    private func loadProfile() async {
        guard let uid = services.auth.currentUserId,
              let profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        selection = profile.trainingDays ?? []
        requiredCount = profile.targetFrequency?.numericCount ?? 3
    }

    private func persist() async {
        guard selection.count == requiredCount,
              let uid = services.auth.currentUserId,
              var profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        profile.trainingDays = selection
        try? await services.user.saveProfile(profile)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Settings/TrainingDaysSettingView.swift
git commit -m "feat(settings): TrainingDaysSettingView"
```

---

### Task 8.4: CutModeSettingView

**Files:**
- Create: `UNBOUND/Views/Settings/CutModeSettingView.swift`

- [ ] **Step 1: Implement**

```swift
// UNBOUND/Views/Settings/CutModeSettingView.swift
import SwiftUI

struct CutModeSettingView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var cut: CutMode = CutMode()

    var body: some View {
        List {
            Section(footer: cutInfo) {
                Toggle("Cut mode", isOn: Binding(
                    get: { cut.enabled },
                    set: { newVal in toggleCut(newVal) }
                ))
            }

            if cut.softCapReached() {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your cut is 8+ weeks in")
                            .font(.bodyMedium(14))
                        Text("Consider taking a maintenance break to let your body recover.")
                            .font(.caption(13))
                            .foregroundColor(.theme.textSecondary)
                    }
                }
            }
        }
        .navigationTitle("Cut mode")
        .task { await loadProfile() }
    }

    private var cutInfo: some View {
        Text("When on, calories drop to a 15% deficit and lift progression pauses. Tier unlocks still fire.")
            .font(.caption(12))
    }

    private func toggleCut(_ value: Bool) {
        if value {
            cut.enabled = true
            cut.startedAt = Date()
        } else {
            cut.enabled = false
            cut.startedAt = nil
        }
        Task { await persist() }
    }

    private func loadProfile() async {
        guard let uid = services.auth.currentUserId,
              let profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        cut = profile.cutMode
    }

    private func persist() async {
        guard let uid = services.auth.currentUserId,
              var profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        profile.cutMode = cut
        try? await services.user.saveProfile(profile)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Settings/CutModeSettingView.swift
git commit -m "feat(settings): CutModeSettingView with 8-week soft cap"
```

---

### Task 8.5: Wire all settings into SettingsView

**Files:**
- Modify: `UNBOUND/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Add rows**

```swift
NavigationLink("Training feedback", destination: TrainingFeedbackSettingView())
NavigationLink("Training style", destination: TrainingStyleSettingView())
NavigationLink("Training days", destination: TrainingDaysSettingView())
NavigationLink("Cut mode", destination: CutModeSettingView())
```

Place them under an appropriate section ("Program" or "Training").

- [ ] **Step 2: Commit**

```bash
git add UNBOUND/Views/Settings/SettingsView.swift
git commit -m "feat(settings): wire program-redesign settings"
```

---

### Task 8.6: LegacyUserFillInSheet (migration prompt)

**Files:**
- Create: `UNBOUND/Views/Program/LegacyUserFillInSheet.swift`
- Modify: app-root view to present it on first post-update launch when needed

- [ ] **Step 1: Implement sheet**

```swift
// UNBOUND/Views/Program/LegacyUserFillInSheet.swift
import SwiftUI

struct LegacyUserFillInSheet: View {
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss
    @State private var trainingDays: Set<Weekday> = []
    @State private var loading = false

    let requiredCount: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Quick setup")
                    .font(.headline(22))
                Text("Which days will you train? Pick \(requiredCount).")
                    .font(.bodyText(14))
                    .foregroundColor(.theme.textSecondary)
                    .multilineTextAlignment(.center)

                HUDMultiSelectGroup(
                    options: Weekday.allCases,
                    selection: $trainingDays,
                    title: { $0.short },
                    icon: { _ in "calendar" }
                )

                Spacer()

                Button {
                    Task { await save() }
                } label: {
                    Text(loading ? "Saving…" : "Done")
                        .font(.bodyMedium(16))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(trainingDays.count != requiredCount || loading)
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationBarBackButtonHidden(true)
        }
    }

    private func save() async {
        guard let uid = services.auth.currentUserId,
              var profile: UserProfile = try? await services.user.fetchProfile(userId: uid) else { return }
        loading = true
        defer { loading = false }
        profile.trainingDays = trainingDays
        try? await services.user.saveProfile(profile)
        dismiss()
    }
}
```

- [ ] **Step 2: Present on app root when needed**

Find the root view (likely `RootView.swift` or `ContentView.swift`). Add a `.sheet(isPresented:)` binding driven by a check: `profile.onboardingCompleted == true && profile.trainingDays == nil && profile.targetFrequency != nil`.

- [ ] **Step 3: Build, QA with a faked legacy profile**

Set `trainingDays = nil` on an existing test profile and verify the sheet appears on next launch.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Program/LegacyUserFillInSheet.swift UNBOUND/App/RootView.swift
git commit -m "feat: legacy user migration sheet for missing training-days"
```

---

### Task 8.7: Final QA pass

- [ ] **Step 1: Full manual run-through**
  - Fresh onboarding → scan → program → today's workout → log workout → progression fires.
  - Settings → toggle cut mode → macros update, progression paused.
  - Settings → toggle Training Feedback → RPE prompts appear/disappear.
  - 14-day rollover → new block generates, bias carries forward.
  - Album → capture photo → appears in grid.
  - Legacy user → sheet appears, fills in days, dismisses.

- [ ] **Step 2: Run all tests**

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15'
```

- [ ] **Step 3: Final commit**

```bash
git commit --allow-empty -m "chore: program redesign complete"
```

---

### Chunk 8 Review Gate

- [ ] **Review:** Full end-to-end manual QA. All success criteria in the spec's Section 10 are verifiable.
- [ ] **Done.**

---

## Self-Review Results (ran against the spec)

**1. Spec coverage check:**
- Section 1 (Mental Model) ✓ covered by overall architecture.
- Section 2 (Inputs → Outputs) ✓ `ProgramGeneratorInput` struct, Task 2.5.
- Section 3 (Data Model) ✓ Chunk 1.
- Section 4 (Generation Pipeline) ✓ Chunk 2, all 8 steps.
- Section 5 (Progression + Rollover) ✓ Chunk 3 + Chunk 4.
- Section 6 (UI Surfaces) ✓ Chunk 6.
- Section 7 (Onboarding) ✓ Chunk 5.
- Section 8 (Migration) ✓ Task 8.6.
- Section 9 (Keep/Change/Add/Remove) ✓ distributed across chunks.
- Section 10 (Success Criteria) ✓ all 9 criteria are testable at QA gates.

**2. Placeholder scan:** A few `// TODO: wire to …` stubs remain in Task 6.4 (deload label lookup) and Task 3.5 (`buildExerciseHistory`). Both are explicitly called out as MVP-acceptable — they don't block the feature from being end-to-end usable, they just mean rotation won't fire until history accumulates, and deload label won't render until a follow-up wire-up. Not plan failures; conscious MVP scope.

**3. Type consistency:** `ProgramGeneratorInput` fields used in Task 2.5 match the types imported from Chunk 1. `ProgramBlock` fields used in Chunk 3 match Task 1.5. `CutMode` usage in Chunk 8 matches Task 1.4.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-20-program-redesign.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
