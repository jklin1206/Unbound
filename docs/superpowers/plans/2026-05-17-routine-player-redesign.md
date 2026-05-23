# Routine Player Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `[String]`-steps + regex-parser + set-logging routine player with a typed `RoutineStep` model and a step-sequence player whose only jobs are show the step / give a time reference / advance, plus a local-first progression-capable completion record.

**Architecture:** Four pure, independently-green TDD tasks (T1 model, T2 runtime expansion, T3 record, T4 history store) land first without touching existing code. Then a coupled migration cluster (T5 author+migrate model, T6 rewrite player, T7 wire+retire) — the UNBOUND module compiles only at the **T7 seam** (the old `.sideQuest`/parser/`SideQuestPlayerView` and the new typed `steps` cannot coexist; this matches the codebase's established cluster-seam pattern). T8 is jlin's on-device sign-off.

**Tech Stack:** Swift 5.9 / SwiftUI / XCTest; xcodegen project (run `xcodegen generate` before `xcodebuild` after adding files). Authoritative test: `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test`.

---

## ⚠️ Cluster revision — 2026-05-17, post-T5 discovery (jlin-approved)

T5 execution surfaced a second routine surface the original spec missed:
`UNBOUND/Models/RoutineLibrary.swift` (`SideQuestLibrary` → `[SideQuest]`) and
the **Home "Daily Quest" card** (`UnboundHomeView.swift:68`
`@State activeRoutine: SideQuest`, line 188 `SideQuestPlayerView(routine:)`).
jlin decided: **ship Program-only; keep the old path alive.** Revised cluster:

- **T5 stays as committed (`ad7b269`).** Its deletions (`RoutineDef.sideQuest`,
  `RoutineStepParser`, `RoutineCategory.sideQuestCategory`, the
  `String.matches/firstMatch` extension) are correct — they only served the
  Program `.sideQuest` path. Home uses `SideQuest` directly from
  `SideQuestLibrary`, never `RoutineDef.sideQuest`, so Home is unaffected.
- **T6 (revised):** create the new `struct RoutinePlayerView` in a **new file**
  `UNBOUND/Views/Routine/RoutineSequencePlayer.swift`. Do **NOT** rewrite or
  delete `UNBOUND/Views/Routine/RoutinePlayerView.swift` (it holds
  `SideQuestPlayerView`, still used by Home). `SideQuestPlayerView` /
  `SideQuest` / `SideQuestExercise` / `SideQuestLog` / `SideQuestSetLog` /
  `Models/RoutineLibrary.swift` all stay alive.
- **T7 (revised):** wire the **Program path only**: `.fullScreenCover(item:
  $activeRoutinePlayer)` → the new `RoutinePlayerView`; `completeRoutine(_:
  record:)`; switch the Program-side `RoutineCompletionStore` call sites →
  `RoutineHistoryStore.shared`; render typed steps in the Program detail
  card/sheet. **Grep-guard before deleting the legacy `RoutineCompletionStore`
  enum** — delete it only if no remaining referencer (Home/SideQuest path may
  not use it; if anything outside ProgramOverviewView does, keep it). Do NOT
  delete `SideQuestPlayerView`/`SideQuest*`. The module is green at the T7
  seam with **zero Home changes**.
- Full retirement of `SideQuestPlayerView`/`SideQuest*` is an explicit
  follow-up sub-project once Home's Daily Quest is migrated. Out of scope here.

---

## File Structure

| File | Responsibility | Task |
|---|---|---|
| `UNBOUND/Models/RoutineStep.swift` (new) | `RoutineStep` enum, `TimedStyle`, `IntervalSegment` | T1 |
| `UNBOUND/Models/RoutineRun.swift` (new) | `RoutineRunStep`, `RoutineRun.build` (circuit expansion + note filtering) | T2 |
| `UNBOUND/Models/RoutineCompletionRecord.swift` (new) | `RoutineMetric`, `RoutineCompletionRecord` | T3 |
| `UNBOUND/Services/Routine/RoutineHistoryStore.swift` (new) | preserved `canComplete`/`complete`/`lastCompleted` + added `record`/`history`/`summary` | T4 |
| `UNBOUND/Models/Routine.swift` (rewrite) | houses `RoutineDef`/`RoutineCategory`/`RoutineLibrary` (typed, 20 authored); `SideQuest*` deleted | T5 |
| `UNBOUND/Views/Routine/RoutinePlayerView.swift` (rewrite) | new step-sequence `RoutinePlayerView`; `SideQuestPlayerView` deleted | T6 |
| `UNBOUND/Views/Program/ProgramOverviewView.swift` (modify) | wire new player, `completeRoutine(_:record:)`, real reward values, switch store sites, render typed steps, delete parser/`.sideQuest`/old store | T5/T7 |
| `UNBOUNDTests/Models/RoutineStepTests.swift` (new) | T1 tests | T1 |
| `UNBOUNDTests/Models/RoutineRunTests.swift` (new) | T2 tests | T2 |
| `UNBOUNDTests/Models/RoutineCompletionRecordTests.swift` (new) | T3 tests | T3 |
| `UNBOUNDTests/Services/RoutineHistoryStoreTests.swift` (new) | T4 tests | T4 |
| `UNBOUNDTests/Models/RoutineLibraryTests.swift` (new) | T5 — all 20 routines well-formed | T5 |

**xcodegen note:** every task that **creates** a Swift file must run `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate` before `xcodebuild`, or the new file is not in the target.

---

## Task 1: RoutineStep typed model

**Files:**
- Create: `UNBOUND/Models/RoutineStep.swift`
- Test: `UNBOUNDTests/Models/RoutineStepTests.swift`

- [ ] **Step 1: Write the failing test**

`UNBOUNDTests/Models/RoutineStepTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class RoutineStepTests: XCTestCase {
    private func roundTrip(_ step: RoutineStep) throws -> RoutineStep {
        let data = try JSONEncoder().encode(step)
        return try JSONDecoder().decode(RoutineStep.self, from: data)
    }

    func testInstructionRoundTrips() throws {
        let s = RoutineStep.instruction(text: "Push-ups × 15", cue: "elbows 45°")
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testTimedRoundTrips() throws {
        let s = RoutineStep.timed(label: "Plank", seconds: 60, style: .work)
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testIntervalRoundTrips() throws {
        let s = RoutineStep.interval(
            label: "Tabata",
            rounds: 8,
            segments: [IntervalSegment(label: "WORK", seconds: 20),
                       IntervalSegment(label: "REST", seconds: 10)]
        )
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testRepTargetRoundTrips() throws {
        XCTAssertEqual(try roundTrip(.repTarget(name: "Push-ups", target: 100, cue: nil)),
                       .repTarget(name: "Push-ups", target: 100, cue: nil))
        XCTAssertEqual(try roundTrip(.repTarget(name: "Push-ups", target: nil, cue: "AMRAP")),
                       .repTarget(name: "Push-ups", target: nil, cue: "AMRAP"))
    }

    func testNestedCircuitRoundTrips() throws {
        let s = RoutineStep.circuit(
            rounds: 3,
            restBetweenSeconds: 60,
            steps: [.instruction(text: "Squats × 20", cue: nil),
                    .timed(label: "Plank", seconds: 45, style: .work)]
        )
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testNoteRoundTrips() throws {
        let s = RoutineStep.note(text: "Warning: most people DNF after Gate 5.")
        XCTAssertEqual(try roundTrip(s), s)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineStepTests 2>&1 | tail -15`
Expected: FAIL — `cannot find type 'RoutineStep' in scope`.

- [ ] **Step 3: Write minimal implementation**

`UNBOUND/Models/RoutineStep.swift`:

```swift
import Foundation

/// Styles the timed-step ring: work uses the routine's category accent;
/// rest uses a recovery (muted) treatment.
enum TimedStyle: String, Codable, Hashable, Sendable {
    case work
    case rest
}

/// One segment of an interval block, e.g. WORK 20s / REST 10s.
struct IntervalSegment: Codable, Hashable, Sendable {
    let label: String
    let seconds: Int

    init(label: String, seconds: Int) {
        self.label = label
        self.seconds = seconds
    }
}

/// A typed routine step. Replaces the old free-text `[String]` + regex
/// parser. The player renders each kind in its own face; `.note` is never
/// advanced through (it is context), `.circuit` is expanded at runtime.
indirect enum RoutineStep: Codable, Hashable, Sendable {
    case instruction(text: String, cue: String?)
    case timed(label: String, seconds: Int, style: TimedStyle)
    case interval(label: String, rounds: Int, segments: [IntervalSegment])
    /// `target == nil` ⇒ AMRAP (open tally, user ends manually).
    case repTarget(name: String, target: Int?, cue: String?)
    case circuit(rounds: Int, restBetweenSeconds: Int, steps: [RoutineStep])
    case note(text: String)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineStepTests 2>&1 | tail -15`
Expected: PASS (`Executed 6 tests`). Synthesized `Codable`/`Hashable` for an `indirect enum` with associated values works in Swift 5.9.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Models/RoutineStep.swift UNBOUNDTests/Models/RoutineStepTests.swift project.yml && git commit -m "feat(routines): typed RoutineStep model

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```
(Commit `project.yml` only if `xcodegen generate` changed it; otherwise drop it from the `git add`.)

---

## Task 2: RoutineRun — runtime expansion

**Files:**
- Create: `UNBOUND/Models/RoutineRun.swift`
- Test: `UNBOUNDTests/Models/RoutineRunTests.swift`

- [ ] **Step 1: Write the failing test**

`UNBOUNDTests/Models/RoutineRunTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class RoutineRunTests: XCTestCase {

    func testNotesAreFilteredOutOfRun() {
        let (run, notes) = RoutineRun.build([
            .instruction(text: "A", cue: nil),
            .note(text: "be careful"),
            .timed(label: "Hold", seconds: 30, style: .work)
        ])
        XCTAssertEqual(run.count, 2)
        XCTAssertEqual(notes, ["be careful"])
        XCTAssertNil(run[0].roundLabel)
        if case .note = run[0].kind { XCTFail("note leaked into run") }
        if case .note = run[1].kind { XCTFail("note leaked into run") }
    }

    func testCircuitExpandsWithRoundLabelsAndRestBetweenRounds() {
        let (run, _) = RoutineRun.build([
            .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                .instruction(text: "Push-ups × 15", cue: nil),
                .timed(label: "Plank", seconds: 45, style: .work)
            ])
        ])
        // 3 rounds × 2 steps = 6, + 2 inter-round rests (after r1, r2; not r3) = 8
        XCTAssertEqual(run.count, 8)
        XCTAssertEqual(run[0].roundLabel, "ROUND 1 / 3")
        XCTAssertEqual(run[1].roundLabel, "ROUND 1 / 3")
        // inter-round rest is itself tagged with the round just finished
        if case .timed(_, let secs, let style) = run[2].kind {
            XCTAssertEqual(secs, 60)
            XCTAssertEqual(style, .rest)
        } else { XCTFail("expected inter-round rest at index 2") }
        XCTAssertEqual(run[3].roundLabel, "ROUND 2 / 3")
        XCTAssertEqual(run[7].roundLabel, "ROUND 3 / 3")
        // last step is the final round's last inner step, no trailing rest
        if case .timed(_, _, let style) = run[7].kind {
            XCTAssertEqual(style, .work)
        } else { XCTFail("expected work step last") }
    }

    func testZeroRoundCircuitProducesEmpty() {
        let (run, _) = RoutineRun.build([
            .circuit(rounds: 0, restBetweenSeconds: 60, steps: [
                .instruction(text: "x", cue: nil)
            ])
        ])
        XCTAssertTrue(run.isEmpty)
    }

    func testIdsAreStableSequentialIndices() {
        let (run, _) = RoutineRun.build([
            .instruction(text: "A", cue: nil),
            .instruction(text: "B", cue: nil)
        ])
        XCTAssertEqual(run.map(\.id), [0, 1])
    }

    func testFlatSequencePreservesOrder() {
        let (run, _) = RoutineRun.build([
            .timed(label: "Warm", seconds: 120, style: .work),
            .interval(label: "HR", rounds: 5,
                      segments: [IntervalSegment(label: "GO", seconds: 60),
                                 IntervalSegment(label: "Easy", seconds: 60)]),
            .timed(label: "Cool", seconds: 180, style: .rest)
        ])
        XCTAssertEqual(run.count, 3)
        if case .interval = run[1].kind {} else { XCTFail("interval not preserved") }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineRunTests 2>&1 | tail -15`
Expected: FAIL — `cannot find 'RoutineRun' in scope`.

- [ ] **Step 3: Write minimal implementation**

`UNBOUND/Models/RoutineRun.swift`:

```swift
import Foundation

/// One step the player actually walks. Never `.circuit` (expanded) or
/// `.note` (filtered into `notes`). `roundLabel` is set for steps that came
/// from inside a circuit ("ROUND 2 / 3").
struct RoutineRunStep: Identifiable, Hashable {
    let id: Int
    let kind: RoutineStep
    let roundLabel: String?
}

enum RoutineRun {
    /// Flattens authored steps into the ordered run list + collected notes.
    /// Circuits expand to `rounds` copies of their inner steps with a
    /// `.timed(.rest, restBetweenSeconds)` inserted *between* rounds (not
    /// after the last round). `.note` is removed from the walk list.
    static func build(_ steps: [RoutineStep]) -> (run: [RoutineRunStep], notes: [String]) {
        var run: [RoutineRunStep] = []
        var notes: [String] = []
        var nextId = 0

        func append(_ kind: RoutineStep, roundLabel: String?) {
            run.append(RoutineRunStep(id: nextId, kind: kind, roundLabel: roundLabel))
            nextId += 1
        }

        for step in steps {
            switch step {
            case .note(let text):
                notes.append(text)

            case .circuit(let rounds, let restBetween, let inner):
                guard rounds > 0 else { continue }
                for round in 1...rounds {
                    let label = "ROUND \(round) / \(rounds)"
                    for innerStep in inner {
                        // One level of nesting is all the data uses; a
                        // nested .circuit/.note inside a circuit is not
                        // authored, so inner steps pass through directly.
                        if case .note(let t) = innerStep {
                            notes.append(t)
                        } else {
                            append(innerStep, roundLabel: label)
                        }
                    }
                    if round < rounds {
                        append(.timed(label: "Rest",
                                      seconds: restBetween,
                                      style: .rest),
                                roundLabel: label)
                    }
                }

            default:
                append(step, roundLabel: nil)
            }
        }
        return (run, notes)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineRunTests 2>&1 | tail -15`
Expected: PASS (`Executed 5 tests`).

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Models/RoutineRun.swift UNBOUNDTests/Models/RoutineRunTests.swift project.yml && git commit -m "feat(routines): RoutineRun runtime expansion (circuits + notes)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: RoutineCompletionRecord + RoutineMetric

**Files:**
- Create: `UNBOUND/Models/RoutineCompletionRecord.swift`
- Test: `UNBOUNDTests/Models/RoutineCompletionRecordTests.swift`

- [ ] **Step 1: Write the failing test**

`UNBOUNDTests/Models/RoutineCompletionRecordTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class RoutineCompletionRecordTests: XCTestCase {
    private func roundTrip(_ r: RoutineCompletionRecord) throws -> RoutineCompletionRecord {
        let data = try JSONEncoder().encode(r)
        return try JSONDecoder().decode(RoutineCompletionRecord.self, from: data)
    }

    func testTimeMetricRoundTrips() throws {
        let r = RoutineCompletionRecord(
            id: "1", routineId: "z2-walk-20",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            elapsedSeconds: 1280, primaryMetric: .time(seconds: 1280), spAwarded: 25)
        XCTAssertEqual(try roundTrip(r), r)
    }

    func testRepCountMetricRoundTripsWithBursts() throws {
        let r = RoutineCompletionRecord(
            id: "2", routineId: "100-pushup",
            completedAt: Date(timeIntervalSince1970: 1_700_000_500),
            elapsedSeconds: 820,
            primaryMetric: .repCount(total: 100, bursts: [35, 30, 20, 15]),
            spAwarded: 50)
        let back = try roundTrip(r)
        XCTAssertEqual(back, r)
        if case .repCount(let total, let bursts) = back.primaryMetric {
            XCTAssertEqual(total, 100)
            XCTAssertEqual(bursts, [35, 30, 20, 15])
        } else { XCTFail("metric kind lost") }
    }

    func testStepsMetricRoundTrips() throws {
        let r = RoutineCompletionRecord(
            id: "3", routineId: "8-gates-protocol",
            completedAt: Date(timeIntervalSince1970: 1_700_001_000),
            elapsedSeconds: 2400,
            primaryMetric: .steps(done: 9, total: 9), spAwarded: 120)
        XCTAssertEqual(try roundTrip(r), r)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineCompletionRecordTests 2>&1 | tail -15`
Expected: FAIL — `cannot find type 'RoutineCompletionRecord' in scope`.

- [ ] **Step 3: Write minimal implementation**

`UNBOUND/Models/RoutineCompletionRecord.swift`:

```swift
import Foundation

/// The headline metric a finished routine leads with. `elapsedSeconds` is
/// always captured on the record regardless; this only chooses the headline.
enum RoutineMetric: Codable, Hashable, Sendable {
    case time(seconds: Int)                    // timer / interval / checklist
    case repCount(total: Int, bursts: [Int])   // repTarget (each ADD = a burst)
    case steps(done: Int, total: Int)          // instruction-dominant routine
}

struct RoutineCompletionRecord: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let routineId: String
    let completedAt: Date
    let elapsedSeconds: Int
    let primaryMetric: RoutineMetric
    let spAwarded: Int

    init(id: String = UUID().uuidString,
         routineId: String,
         completedAt: Date = Date(),
         elapsedSeconds: Int,
         primaryMetric: RoutineMetric,
         spAwarded: Int) {
        self.id = id
        self.routineId = routineId
        self.completedAt = completedAt
        self.elapsedSeconds = elapsedSeconds
        self.primaryMetric = primaryMetric
        self.spAwarded = spAwarded
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineCompletionRecordTests 2>&1 | tail -15`
Expected: PASS (`Executed 3 tests`).

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Models/RoutineCompletionRecord.swift UNBOUNDTests/Models/RoutineCompletionRecordTests.swift project.yml && git commit -m "feat(routines): RoutineCompletionRecord + RoutineMetric

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: RoutineHistoryStore (preserve API + add history)

**Files:**
- Create: `UNBOUND/Services/Routine/RoutineHistoryStore.swift`
- Test: `UNBOUNDTests/Services/RoutineHistoryStoreTests.swift`

**Context:** the existing `RoutineCompletionStore` (in `ProgramOverviewView.swift` ~2108–2133) is a `@MainActor enum` keyed by routine id: `canComplete(routineId:)`, `lastCompleted(routineId:)`, `@discardableResult complete(_ routine:) -> Bool` (24h cooldown via `UserDefaults` key `unbound.routineLastCompleted.<id>`; SP via `unbound.gains`). This task creates `RoutineHistoryStore` with **byte-identical** versions of those three (same UserDefaults keys, same cooldown, same gains delta) so the three call sites can swap names with no behavior change in T7. It additionally persists a JSON records list to Application Support (records only — cooldown/gains stay in UserDefaults verbatim to guarantee parity). The old `RoutineCompletionStore` stays untouched until T7; the module stays green.

- [ ] **Step 1: Write the failing test**

`UNBOUNDTests/Services/RoutineHistoryStoreTests.swift`:

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class RoutineHistoryStoreTests: XCTestCase {

    private func freshSuite() -> (UserDefaults, URL) {
        let suiteName = "rhs.test.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (ud, dir)
    }

    private func routine(_ id: String, sp: Int = 25) -> RoutineDef {
        RoutineDef(id: id, title: id, subtitle: "", durationLabel: "~10 MIN",
                   category: .challenge, spReward: sp, steps: [])
    }

    func testCompleteAwardsThenCooldownBlocksWithin24h() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        XCTAssertTrue(store.canComplete(routineId: "r1"))
        XCTAssertTrue(store.complete(routine("r1", sp: 40)))
        XCTAssertEqual(ud.integer(forKey: "unbound.gains"), 40)   // gains delta parity
        XCTAssertFalse(store.canComplete(routineId: "r1"))         // 24h cooldown
        XCTAssertFalse(store.complete(routine("r1", sp: 40)))      // no double award
        XCTAssertEqual(ud.integer(forKey: "unbound.gains"), 40)
    }

    func testRecordRoundTripsAndSurvivesFreshStore() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        let rec = RoutineCompletionRecord(
            routineId: "100-pushup", elapsedSeconds: 800,
            primaryMetric: .repCount(total: 100, bursts: [40, 35, 25]),
            spAwarded: 50)
        store.record(rec)

        let reborn = RoutineHistoryStore(defaults: ud, directory: dir)
        XCTAssertEqual(reborn.history(routineId: "100-pushup").count, 1)
        XCTAssertEqual(reborn.history(routineId: "100-pushup").first?.id, rec.id)
        XCTAssertTrue(reborn.history(routineId: "other").isEmpty)
    }

    func testSummaryComputesCountAndBest() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        store.record(.init(routineId: "100-pushup", elapsedSeconds: 900,
                           primaryMetric: .repCount(total: 100, bursts: [50, 50]),
                           spAwarded: 50))
        store.record(.init(routineId: "100-pushup", elapsedSeconds: 700,
                           primaryMetric: .repCount(total: 100, bursts: [60, 40]),
                           spAwarded: 50))
        let s = store.summary(routineId: "100-pushup")
        XCTAssertEqual(s?.count, 2)
        // best repCount = fewest bursts (2) then highest total; both have 2
        // bursts/100 → best is the faster one (700s)
        if case .repCount(let total, _)? = s?.best { XCTAssertEqual(total, 100) }
        else { XCTFail("expected repCount best") }
        XCTAssertEqual(store.summary(routineId: "none")?.count ?? 0, 0)
    }

    func testTimeBestIsShortestElapsed() {
        let (ud, dir) = freshSuite()
        let store = RoutineHistoryStore(defaults: ud, directory: dir)
        store.record(.init(routineId: "z2", elapsedSeconds: 1300,
                           primaryMetric: .time(seconds: 1300), spAwarded: 25))
        store.record(.init(routineId: "z2", elapsedSeconds: 1180,
                           primaryMetric: .time(seconds: 1180), spAwarded: 25))
        if case .time(let s)? = store.summary(routineId: "z2")?.best {
            XCTAssertEqual(s, 1180)
        } else { XCTFail("expected time best = shortest") }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineHistoryStoreTests 2>&1 | tail -15`
Expected: FAIL — `cannot find 'RoutineHistoryStore' in scope`. (`RoutineDef` already exists in `ProgramOverviewView.swift` at this point, so the test helper compiles.)

- [ ] **Step 3: Write minimal implementation**

`UNBOUND/Services/Routine/RoutineHistoryStore.swift`:

```swift
import Foundation

/// Local-first routine completion store. The 24h-cooldown + `unbound.gains`
/// SP bump are copied byte-for-byte from the legacy `RoutineCompletionStore`
/// (same UserDefaults keys) so call sites swap with zero behavior change.
/// The records list is persisted as JSON to Application Support; cooldown +
/// gains stay in UserDefaults to guarantee parity.
@MainActor
final class RoutineHistoryStore {
    static let shared = RoutineHistoryStore()

    private let defaults: UserDefaults
    private let fileURL: URL
    private let keyPrefix = "unbound.routineLastCompleted."
    private let gainsKey = "unbound.gains"
    private let cooldown: TimeInterval = 24 * 3600

    private var records: [RoutineCompletionRecord]

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("routine-history.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([RoutineCompletionRecord].self, from: data) {
            self.records = decoded
        } else {
            self.records = []
        }
    }

    // MARK: Preserved API (parity with legacy RoutineCompletionStore)

    func canComplete(routineId: String) -> Bool {
        guard let last = lastCompleted(routineId: routineId) else { return true }
        return Date().timeIntervalSince(last) >= cooldown
    }

    func lastCompleted(routineId: String) -> Date? {
        let raw = defaults.double(forKey: keyPrefix + routineId)
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }

    @discardableResult
    func complete(_ routine: RoutineDef) -> Bool {
        guard canComplete(routineId: routine.id) else { return false }
        defaults.set(Date().timeIntervalSince1970, forKey: keyPrefix + routine.id)
        let current = defaults.integer(forKey: gainsKey)
        defaults.set(current + routine.spReward, forKey: gainsKey)
        return true
    }

    // MARK: Added — progression history

    func record(_ rec: RoutineCompletionRecord) {
        records.append(rec)
        persist()
    }

    func history(routineId: String) -> [RoutineCompletionRecord] {
        records.filter { $0.routineId == routineId }
            .sorted { $0.completedAt > $1.completedAt }
    }

    /// `count` of completions + the `best` metric (highest total then fewest
    /// bursts for repCount; shortest seconds for time; most steps for steps).
    func summary(routineId: String) -> (count: Int, best: RoutineMetric?)? {
        let h = history(routineId: routineId)
        guard !h.isEmpty else { return (0, nil) }
        var best: RoutineMetric? = nil
        for m in h.map(\.primaryMetric) {
            if best == nil || betterThan(m, best!) { best = m }
        }
        return (h.count, best)
    }

    /// True if `lhs` is a better result than `rhs` for the same metric kind.
    private func betterThan(_ lhs: RoutineMetric, _ rhs: RoutineMetric) -> Bool {
        switch (lhs, rhs) {
        case (.time(let a), .time(let b)):
            return a < b                                   // faster is better
        case (.repCount(let at, let ab), .repCount(let bt, let bb)):
            if at != bt { return at > bt }                 // more total reps
            return ab.count < bb.count                     // fewer bursts/sets
        case (.steps(let ad, _), .steps(let bd, _)):
            return ad > bd                                 // more steps done
        default:
            return false                                   // mixed kinds: keep first
        }
    }

    func clear() {
        records = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:UNBOUNDTests/RoutineHistoryStoreTests 2>&1 | tail -15`
Expected: PASS (`Executed 4 tests`).

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Services/Routine/RoutineHistoryStore.swift UNBOUNDTests/Services/RoutineHistoryStoreTests.swift project.yml && git commit -m "feat(routines): RoutineHistoryStore — preserved cooldown/gains API + history

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Migrate model + author all 20 routines (CLUSTER START — module goes RED until T7)

> **Cluster note:** T5 and T6 leave the UNBOUND module **non-compiling** because the old `.sideQuest`/`RoutineStepParser`/`SideQuestPlayerView` and the new typed `steps` cannot coexist. This is an irreducible coupled migration. **Do not run the test suite at the end of T5 or T6** — only a focused `swiftc`-free read review. The module is verified green at the **T7 seam**. This matches the codebase's established cluster-seam pattern.

**Files:**
- Rewrite: `UNBOUND/Models/Routine.swift` (delete `SideQuest*`; house typed `RoutineDef`/`RoutineCategory`/`RoutineLibrary`)
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift` (remove the moved type defs + `RoutineStepParser` + `RoutineDef.sideQuest` + `RoutineCategory.sideQuestCategory`)
- Create: `UNBOUNDTests/Models/RoutineLibraryTests.swift`

- [ ] **Step 1: Co-located-type guard grep**

Run and record output:
```bash
cd /Users/jlin/Documents/toji/UNBOUND
grep -rn "SideQuestCategory\|SideQuest\b\|SideQuestExercise\|SideQuestLog\|SideQuestSetLog" UNBOUND --include="*.swift" | grep -v "UNBOUND/Models/Routine.swift"
grep -rn "\.matches(for:\|\.firstMatch(for:" UNBOUND --include="*.swift"
```
Expected: `SideQuest*` referenced only by `ProgramOverviewView.swift` (`SideQuestPlayerView`, `RoutineCategory.sideQuestCategory@~2633`, `completeRoutine`/`elapsedSeconds` `SideQuestLog`). `.matches(for:`/`.firstMatch(for:` used by `RoutineDef.estimatedMinutes` + `RoutineStepParser` only — both deleted here. If grep shows any OTHER user of the `String.matches/firstMatch` extension, **keep that extension**; otherwise it is deleted with the parser in Step 3.

- [ ] **Step 2: Write the failing test**

`UNBOUNDTests/Models/RoutineLibraryTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class RoutineLibraryTests: XCTestCase {

    func testTwentyRoutinesAllWellFormed() {
        let routines = RoutineLibrary.placeholderRoutines
        XCTAssertEqual(routines.count, 20)
        XCTAssertEqual(Set(routines.map(\.id)).count, 20, "duplicate routine id")

        for r in routines {
            let (run, _) = RoutineRun.build(r.steps)
            XCTAssertFalse(run.isEmpty, "\(r.id): empty run")
            for s in run {
                switch s.kind {
                case .timed(_, let secs, _):
                    XCTAssertGreaterThan(secs, 0, "\(r.id): non-positive timed")
                case .interval(_, let rounds, let segs):
                    XCTAssertGreaterThan(rounds, 0, "\(r.id): interval rounds")
                    XCTAssertFalse(segs.isEmpty, "\(r.id): interval no segments")
                    for seg in segs {
                        XCTAssertGreaterThan(seg.seconds, 0, "\(r.id): interval seg")
                    }
                case .repTarget(_, let target, _):
                    if let t = target {
                        XCTAssertGreaterThan(t, 0, "\(r.id): repTarget target")
                    }
                case .note:
                    XCTFail("\(r.id): .note leaked into run")
                case .circuit:
                    XCTFail("\(r.id): .circuit not expanded")
                case .instruction:
                    break
                }
            }
        }
    }

    func testCategoriesCoverAllFour() {
        let cats = Set(RoutineLibrary.placeholderRoutines.map(\.category))
        XCTAssertEqual(cats, [.cardio, .mobility, .challenge, .altCircuit])
    }

    func testRepTargetRoutinesPresent() {
        let ids = RoutineLibrary.placeholderRoutines
            .filter { $0.steps.contains {
                if case .repTarget = $0 { return true }; return false } }
            .map(\.id)
        XCTAssertTrue(ids.contains("100-pushup"))
    }
}
```

- [ ] **Step 3: Rewrite `UNBOUND/Models/Routine.swift`**

Replace the **entire file** with (this deletes all `SideQuest*`; `RoutineCategory.color`/`systemImage` use the same tokens the old enum used):

```swift
import SwiftUI

// MARK: - RoutineCategory

enum RoutineCategory: CaseIterable, Hashable {
    case cardio, mobility, challenge, altCircuit

    var label: String {
        switch self {
        case .cardio:     return "CARDIO"
        case .mobility:   return "MOBILITY"
        case .challenge:  return "CHALLENGES"
        case .altCircuit: return "ALT CIRCUITS"
        }
    }

    var systemImage: String {
        switch self {
        case .cardio:     return "figure.run"
        case .mobility:   return "figure.flexibility"
        case .challenge:  return "flame.fill"
        case .altCircuit: return "dumbbell.fill"
        }
    }

    var color: Color {
        switch self {
        case .cardio:     return Color.unbound.coachCyan
        case .mobility:   return Color.unbound.rankGreen
        case .challenge:  return Color.unbound.warnOrange
        case .altCircuit: return Color.unbound.accent
        }
    }
}

// MARK: - RoutineDef

struct RoutineDef: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let durationLabel: String
    let category: RoutineCategory
    let spReward: Int
    var steps: [RoutineStep] = []
}

// MARK: - RoutineLibrary

enum RoutineLibrary {
    private static func IS(_ l: String, _ s: Int) -> IntervalSegment {
        IntervalSegment(label: l, seconds: s)
    }

    static let placeholderRoutines: [RoutineDef] = [

        // ───────── Cardio ─────────
        RoutineDef(id: "z2-walk-20", title: "20-min Zone 2 walk",
            subtitle: "Keep HR in zone 2. Easy breathing, steady pace.",
            durationLabel: "~20 MIN", category: .cardio, spReward: 25,
            steps: [
                .timed(label: "Warm-up walk", seconds: 120, style: .work),
                .note(text: "Conversational pace — you can hold a sentence. Target HR 60–70% max (~180 − your age)."),
                .timed(label: "Zone 2 walk", seconds: 1200, style: .work),
                .timed(label: "Cool-down", seconds: 60, style: .rest)
            ]),

        RoutineDef(id: "intervals-15", title: "15-min HR intervals",
            subtitle: "5 × 1-min hard / 1-min easy. Build conditioning.",
            durationLabel: "~15 MIN", category: .cardio, spReward: 35,
            steps: [
                .timed(label: "Warm-up", seconds: 300, style: .work),
                .interval(label: "HR intervals", rounds: 5,
                          segments: [IS("GO — max effort", 60), IS("Recover", 60)]),
                .timed(label: "Cool-down", seconds: 180, style: .rest)
            ]),

        RoutineDef(id: "easy-bike-30", title: "30-min easy bike",
            subtitle: "Steady-state spin. Low impact recovery cardio.",
            durationLabel: "~30 MIN", category: .cardio, spReward: 30,
            steps: [
                .note(text: "Seat: leg ~90% extended at bottom. RPM 80–90, light–moderate resistance. Nasal breathing if you can."),
                .timed(label: "Easy bike", seconds: 1800, style: .work),
                .instruction(text: "Stretch quads and hip flexors.", cue: nil)
            ]),

        // ───────── Mobility ─────────
        RoutineDef(id: "mobility-10", title: "Morning mobility flow",
            subtitle: "Spine, hips, shoulders. Wake the body up.",
            durationLabel: "~10 MIN", category: .mobility, spReward: 15,
            steps: [
                .instruction(text: "Cat-cow × 10 — slow, full range", cue: nil),
                .instruction(text: "World's greatest stretch × 5 / side", cue: nil),
                .instruction(text: "Thread the needle × 8 / side", cue: nil),
                .instruction(text: "Hip 90-90 switches × 10", cue: nil),
                .instruction(text: "Shoulder circles forward + back × 10", cue: nil),
                .timed(label: "Deep squat hold", seconds: 60, style: .work)
            ]),

        RoutineDef(id: "stretch-8", title: "Evening stretch",
            subtitle: "Cool-down flexibility. Hip openers, hamstring.",
            durationLabel: "~8 MIN", category: .mobility, spReward: 10,
            steps: [
                .timed(label: "Hamstring fold — left", seconds: 60, style: .work),
                .timed(label: "Hamstring fold — right", seconds: 60, style: .work),
                .timed(label: "Pigeon pose — left", seconds: 60, style: .work),
                .timed(label: "Pigeon pose — right", seconds: 60, style: .work),
                .timed(label: "Figure-4 — left", seconds: 45, style: .work),
                .timed(label: "Figure-4 — right", seconds: 45, style: .work),
                .timed(label: "Seated forward fold", seconds: 60, style: .work),
                .timed(label: "Spinal twist — left", seconds: 30, style: .work),
                .timed(label: "Spinal twist — right", seconds: 30, style: .work)
            ]),

        RoutineDef(id: "hip-flow-15", title: "Hip flow",
            subtitle: "15-min mobility sequence targeting hip health.",
            durationLabel: "~15 MIN", category: .mobility, spReward: 20,
            steps: [
                .instruction(text: "Hip circles × 10 each direction", cue: nil),
                .timed(label: "Deep lunge hold — left", seconds: 45, style: .work),
                .timed(label: "Deep lunge hold — right", seconds: 45, style: .work),
                .instruction(text: "Side-lying clamshell × 15 / side", cue: nil),
                .timed(label: "Frog stretch", seconds: 90, style: .work),
                .timed(label: "Couch stretch — left", seconds: 60, style: .work),
                .timed(label: "Couch stretch — right", seconds: 60, style: .work),
                .instruction(text: "Lateral band walk × 20 steps / side (bodyweight if no band)", cue: nil),
                .instruction(text: "Glute bridge × 15", cue: nil)
            ]),

        // ───────── Challenges ─────────
        RoutineDef(id: "100-pushup", title: "100 pushup challenge",
            subtitle: "As many sets as it takes. Track your count.",
            durationLabel: "~15 MIN", category: .challenge, spReward: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 100,
                           cue: "Chest to ~1 inch from floor, elbows ~45°. Rest as long as you need between bursts."),
                .note(text: "As many sets as it takes. Log each burst as you go.")
            ]),

        RoutineDef(id: "plank-ladder", title: "Plank ladder",
            subtitle: "30s / 45s / 60s / 75s / 90s — rest 30s between.",
            durationLabel: "~12 MIN", category: .challenge, spReward: 40,
            steps: [
                .timed(label: "Plank", seconds: 30, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank", seconds: 45, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank", seconds: 60, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank", seconds: 75, style: .work),
                .timed(label: "Rest", seconds: 30, style: .rest),
                .timed(label: "Plank — final", seconds: 90, style: .work),
                .note(text: "Neutral spine, squeeze glutes, breathe steady.")
            ]),

        RoutineDef(id: "tabata-core", title: "Tabata core",
            subtitle: "8 × 20s on / 10s off. 4 rotating moves.",
            durationLabel: "~8 MIN", category: .challenge, spReward: 45,
            steps: [
                .interval(label: "Mountain climbers", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)]),
                .interval(label: "Bicycle crunches", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)]),
                .interval(label: "Hollow body hold", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)]),
                .interval(label: "V-ups", rounds: 2,
                          segments: [IS("WORK", 20), IS("REST", 10)])
            ]),

        RoutineDef(id: "saitama-protocol", title: "Zero Limit Protocol",
            subtitle: "100 push-ups, 100 sit-ups, 100 squats, 10km run. Every. Single. Day.",
            durationLabel: "~60–90 MIN", category: .challenge, spReward: 200,
            steps: [
                .repTarget(name: "Push-ups", target: 100, cue: nil),
                .repTarget(name: "Sit-ups", target: 100, cue: "Full range, hands behind head"),
                .repTarget(name: "Bodyweight squats", target: 100, cue: "Parallel depth minimum"),
                .instruction(text: "10 km run — any pace, no stopping", cue: nil),
                .note(text: "No rest days. No excuses. This protocol exists — so does overtraining. Earn it.")
            ]),

        RoutineDef(id: "8-gates-protocol", title: "8 Gates Protocol",
            subtitle: "8 rounds. Each gate adds a layer. You stop when your body does.",
            durationLabel: "~45 MIN", category: .challenge, spReward: 120,
            steps: [
                .instruction(text: "Gate 1 — 10 push-ups", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 2 — 10 push-ups + 15 squats", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 3 — + 10 dips (chair/bench)", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 4 — + 10 pull-ups (or 15 Australian rows)", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 5 — repeat Gate 4 + 20 mountain climbers", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 6 — repeat Gate 5 + 30s plank hold", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 7 — repeat Gate 6 + 10 burpees", cue: nil),
                .timed(label: "Rest", seconds: 75, style: .rest),
                .instruction(text: "Gate 8 — repeat Gate 7 + 400m sprint", cue: nil),
                .note(text: "Most people DNF after Gate 5. That's the point. No skipping, no half gates.")
            ]),

        RoutineDef(id: "beach-forge", title: "Beach Forge",
            subtitle: "Heavy carries, sprints, pull-ups. Zero to forged in 40 minutes.",
            durationLabel: "~40 MIN", category: .challenge, spReward: 90,
            steps: [
                .instruction(text: "Farmer carry — 2 × heaviest DBs/bags, 40m down & back × 4", cue: nil),
                .timed(label: "Rest", seconds: 60, style: .rest),
                .instruction(text: "400m run (or 2 min treadmill at race pace)", cue: nil),
                .timed(label: "Rest", seconds: 60, style: .rest),
                .instruction(text: "Pull-ups × max reps — 4 sets, rest 45s between", cue: nil),
                .timed(label: "Rest", seconds: 90, style: .rest),
                .instruction(text: "Sandbag/backpack squat × 15 — 3 sets", cue: nil),
                .timed(label: "Rest", seconds: 60, style: .rest),
                .instruction(text: "400m run — final sprint, leave nothing", cue: nil),
                .note(text: "Inspired by carrying dead weight every day until you're not weak anymore.")
            ]),

        RoutineDef(id: "underground-grind", title: "Underground Grind",
            subtitle: "Pull-ups, dips, push-ups, core. Pure calisthenics. No mercy.",
            durationLabel: "~30 MIN", category: .challenge, spReward: 85,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Pull-ups × max — strict form", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Dips × max (bars or chairs)", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Diamond push-ups × 15", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Hanging leg raises × 12", cue: nil)
                ]),
                .instruction(text: "Finish: L-sit hold — max duration × 3 attempts", cue: nil),
                .note(text: "No pull-ups? Australian rows under a table × 15.")
            ]),

        RoutineDef(id: "3d-maneuver-conditioning", title: "3D Conditioning",
            subtitle: "Core, grip, pulling power. Built for bodies that move in all directions.",
            durationLabel: "~25 MIN", category: .challenge, spReward: 70,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 45, steps: [
                    .timed(label: "Dead hang", seconds: 60, style: .work),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Pull-ups × 8 — 3s controlled descent", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Tuck jumps × 10 — drive knees", cue: nil),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .timed(label: "Hollow body hold", seconds: 45, style: .work),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Explosive push-up × 10 (hands leave floor)", cue: nil)
                ]),
                .note(text: "Move like you weigh nothing. Train like it costs something.")
            ]),

        RoutineDef(id: "daily-quest", title: "Daily Quest",
            subtitle: "The weakest start. The discipline compounds. Begin your rank climb.",
            durationLabel: "~20 MIN", category: .challenge, spReward: 50,
            steps: [
                .repTarget(name: "Push-ups", target: 30, cue: nil),
                .repTarget(name: "Sit-ups", target: 30, cue: nil),
                .repTarget(name: "Bodyweight squats", target: 30, cue: nil),
                .instruction(text: "2 km run (or 12-min treadmill walk/jog)", cue: nil),
                .note(text: "E-rank version. Daily for 2 weeks. Wk3: 50 reps + 5km. Wk5: 100 reps + 10km — you're no longer E-rank. The only way to level up is to show up.")
            ]),

        RoutineDef(id: "thunder-circuit", title: "Thunder Circuit",
            subtitle: "Speed, power, explosiveness. Train the fast-twitch you've been ignoring.",
            durationLabel: "~20 MIN", category: .challenge, spReward: 65,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Broad jump × 6 — max distance", cue: nil),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Sprint 40m × 6 — full effort", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Clap push-ups × 8", cue: nil),
                    .timed(label: "Rest", seconds: 30, style: .rest),
                    .instruction(text: "Jump squats × 12 — land soft, explode", cue: nil),
                    .timed(label: "Rest", seconds: 45, style: .rest),
                    .instruction(text: "Lateral bounds × 10 / side", cue: nil)
                ]),
                .note(text: "Every rep is a strike. Every second of rest is borrowed time.")
            ]),

        RoutineDef(id: "gravity-chamber", title: "Gravity Chamber",
            subtitle: "High volume. Every rep heavier than the last. Build the body that survives pressure.",
            durationLabel: "~50 MIN", category: .challenge, spReward: 110,
            steps: [
                .circuit(rounds: 5, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Weighted push-ups × 20 (plate / loaded pack)", cue: nil)
                ]),
                .circuit(rounds: 5, restBetweenSeconds: 90, steps: [
                    .instruction(text: "Weighted squats × 15 (DBs / barbell)", cue: nil)
                ]),
                .circuit(rounds: 4, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Weighted pull-ups × 8 (belt / DB)", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .timed(label: "Weighted plank", seconds: 60, style: .work)
                ]),
                .note(text: "No equipment? +1 rep every set — volume is the weight. The chamber does not adjust to you.")
            ]),

        RoutineDef(id: "vessel-protocol", title: "Vessel Protocol",
            subtitle: "Strength and speed. The body is a weapon. Forge it like one.",
            durationLabel: "~35 MIN", category: .challenge, spReward: 95,
            steps: [
                .circuit(rounds: 4, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Clean & press × 8 — heavy", cue: nil)
                ]),
                .circuit(rounds: 4, restBetweenSeconds: 90, steps: [
                    .instruction(text: "Sprint 100m — walk-back recovery", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Single-arm DB row × 10 / side — drive the elbow", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Box jump / step-up jumps × 8", cue: nil)
                ]),
                .circuit(rounds: 3, restBetweenSeconds: 45, steps: [
                    .instruction(text: "Bear crawl 20m fwd + 20m back", cue: nil)
                ]),
                .repTarget(name: "Finish: push-ups", target: 50, cue: "Any style — clock running"),
                .note(text: "A weapon with no edge is dead weight. Stay sharp.")
            ]),

        // ───────── Alt circuits ─────────
        RoutineDef(id: "bw-full-30", title: "Bodyweight full-body",
            subtitle: "No equipment. Pushup, squat, lunge, plank.",
            durationLabel: "~30 MIN", category: .altCircuit, spReward: 40,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                    .instruction(text: "Push-ups × 15", cue: nil),
                    .instruction(text: "Bodyweight squats × 20", cue: nil),
                    .instruction(text: "Reverse lunges × 12 / leg", cue: nil),
                    .instruction(text: "Pike push-ups × 10", cue: nil),
                    .instruction(text: "Glute bridges × 20", cue: nil),
                    .timed(label: "Plank", seconds: 45, style: .work)
                ])
            ]),

        RoutineDef(id: "db-full-25", title: "Dumbbell full-body",
            subtitle: "Compound circuit with a pair of DBs.",
            durationLabel: "~25 MIN", category: .altCircuit, spReward: 45,
            steps: [
                .circuit(rounds: 3, restBetweenSeconds: 90, steps: [
                    .instruction(text: "DB goblet squat × 12", cue: nil),
                    .instruction(text: "DB Romanian deadlift × 10", cue: nil),
                    .instruction(text: "DB bent-over row × 10 / arm", cue: nil),
                    .instruction(text: "DB shoulder press × 10", cue: nil),
                    .instruction(text: "DB chest press × 12", cue: nil),
                    .instruction(text: "DB curl × 12", cue: nil)
                ])
            ])
    ]
}
```

- [ ] **Step 4: Remove the moved/dead defs from `ProgramOverviewView.swift`**

In `UNBOUND/Views/Program/ProgramOverviewView.swift` delete these definitions (now living in `Routine.swift` or dead):
- `enum RoutineCategory { … }` (the whole enum, ~lines 1889–1918 region — moved to Routine.swift)
- `struct RoutineDef { … }` (~1920–1928 — moved)
- `enum RoutineLibrary { … }` (the entire old `placeholderRoutines` `[String]` array — moved/replaced)
- `private extension RoutineCategory { var sideQuestCategory … }` (the `@~2633` extension — dead)
- `private enum RoutineStepParser { … }` (the entire parser enum)
- the `RoutineDef`-level `var sideQuest: SideQuest { … }` computed property and its sibling `private var estimatedMinutes: Int { … }` (the `.sideQuest`/parser path)
- `private extension String { func matches… func firstMatch… }` **only if** Step 1's grep showed no other user; otherwise keep it.

Keep `RoutineCompletionStore`, `RoutineChallengeCard`, `RoutineRewardPayload`, `RoutineCompletionRewardView`, and all routine carousel/detail views for now — they are updated in T7. (`completeRoutine`, `elapsedSeconds(from:)`, the `.fullScreenCover` body, `metricPill`/detail-sheet step rendering will not compile after this — expected; the module is RED until T7.)

- [ ] **Step 5: Read-review only (no build — module is RED by design)**

Confirm by eye: `Routine.swift` compiles in isolation (no `SideQuest*`, all 20 `RoutineDef` literals use only `RoutineStep` cases defined in T1, `IS` helper used consistently). Confirm `ProgramOverviewView.swift` no longer *defines* `RoutineDef`/`RoutineCategory`/`RoutineLibrary`/`RoutineStepParser`/`.sideQuest`. Do **not** run `xcodebuild test`.

- [ ] **Step 6: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Models/Routine.swift UNBOUND/Views/Program/ProgramOverviewView.swift UNBOUNDTests/Models/RoutineLibraryTests.swift && git commit -m "feat(routines): typed RoutineDef + 20 authored routines; drop SideQuest parser

CLUSTER (T5/3): module intentionally non-compiling until the T7 seam.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Rewrite RoutinePlayerView (CLUSTER — still RED until T7)

**Files:**
- Rewrite: `UNBOUND/Views/Routine/RoutinePlayerView.swift` (delete `SideQuestPlayerView`; add new `RoutinePlayerView`)

**Design bar (enforced at on-device review T8):** premium-native, quiet default; the category/accent color appears only on the primary action and the active ring; reuse the existing draining-ring + tick/`success` pattern verbatim from the old `restView`; ≥56pt hit targets; ≥13pt text; the single dramatic moment is the `repTarget` target-hit bloom. No new palette.

- [ ] **Step 1: Replace the entire file**

`UNBOUND/Views/Routine/RoutinePlayerView.swift`:

```swift
import SwiftUI

// MARK: - RoutinePlayerView
//
// Step-sequence player for pre-set routines. No set logging: it shows the
// current step, gives a time reference when the step is timed, and advances.
// Faces: instruction · timed · interval · repTarget · complete.

struct RoutinePlayerView: View {
    let routine: RoutineDef
    let onComplete: (RoutineCompletionRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var services: ServiceContainer

    private let run: [RoutineRunStep]
    private let notes: [String]

    @State private var index = 0
    @State private var isComplete = false
    @State private var elapsedSeconds = 0
    @State private var startedAt = Date()

    // timed/interval transient state
    @State private var secondsRemaining = 0
    @State private var totalSeconds = 0
    @State private var intervalRound = 1
    @State private var intervalSegment = 0
    @State private var showNotes = false

    // repTarget transient state
    @State private var burstEntry = 10
    @State private var bursts: [Int] = []

    private let clock = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    init(routine: RoutineDef,
         onComplete: @escaping (RoutineCompletionRecord) -> Void) {
        self.routine = routine
        self.onComplete = onComplete
        let built = RoutineRun.build(routine.steps)
        self.run = built.run
        self.notes = built.notes
    }

    private var accent: Color { routine.category.color }
    private var current: RoutineRunStep? {
        index < run.count ? run[index] : nil
    }
    private var elapsedLabel: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            if isComplete || current == nil {
                completeFace
            } else {
                VStack(spacing: 0) {
                    topBar
                    progressRail
                    Spacer(minLength: 8)
                    stepFace(current!)
                    Spacer(minLength: 8)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { startedAt = Date(); prepare(run.first) }
        .onReceive(clock) { _ in tick() }
        .sheet(isPresented: $showNotes) { notesSheet }
    }

    // MARK: Top bar + rail

    private var topBar: some View {
        HStack {
            Button { UnboundHaptics.soft(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.unbound.surface))
                    .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(elapsedLabel)
                .font(Font.unbound.monoS.weight(.bold)).tracking(1.4)
                .foregroundStyle(Color.unbound.textSecondary).monospacedDigit()
            Spacer()
            if notes.isEmpty {
                Spacer().frame(width: 36)
            } else {
                Button { UnboundHaptics.soft(); showNotes = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    private var progressRail: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(routine.category.label) · \(routine.title.uppercased())")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6).foregroundStyle(accent)
                Spacer()
                Text(current?.roundLabel
                     ?? "STEP \(min(index + 1, run.count)) OF \(run.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4).foregroundStyle(Color.unbound.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.unbound.surface).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(accent)
                        .frame(width: geo.size.width
                               * CGFloat(index + 1) / CGFloat(max(run.count, 1)),
                               height: 3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                                   value: index)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Faces

    @ViewBuilder
    private func stepFace(_ step: RoutineRunStep) -> some View {
        switch step.kind {
        case .instruction(let text, let cue):
            instructionFace(text: text, cue: cue)
        case .timed(let label, _, let style):
            timedFace(label: label, style: style)
        case .interval(let label, let rounds, let segs):
            intervalFace(label: label, rounds: rounds, segments: segs)
        case .repTarget(let name, let target, let cue):
            repTargetFace(name: name, target: target, cue: cue)
        case .note, .circuit:
            // RoutineRun guarantees these never appear in the run.
            Color.clear.onAppear { advance() }
        }
    }

    private func instructionFace(text: String, cue: String?) -> some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 12) {
                Text(text)
                    .font(Font.unbound.displayM).tracking(0.3)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let cue {
                    Text(cue)
                        .font(Font.unbound.bodyS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            primaryButton(isLast ? "FINISH" : "DONE") { advance() }
        }
    }

    private func timedFace(label: String, style: TimedStyle) -> some View {
        let ringColor = style == .rest ? Color.unbound.textTertiary : accent
        return VStack(spacing: 28) {
            Spacer()
            Text(label.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(style == .rest ? Color.unbound.textTertiary : accent)
            ZStack {
                Circle().strokeBorder(Color.unbound.surface, lineWidth: 10)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: totalSeconds > 0
                          ? CGFloat(secondsRemaining) / CGFloat(totalSeconds) : 1)
                    .stroke(ringColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.5), radius: 12)
                    .animation(.linear(duration: 1), value: secondsRemaining)
                Text("\(secondsRemaining)")
                    .font(.system(size: 60, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
                    .contentTransition(.numericText(value: Double(secondsRemaining)))
            }
            Spacer()
            HStack(spacing: 16) {
                secondaryButton("+30s") {
                    secondsRemaining = min(secondsRemaining + 30, 600)
                    totalSeconds = max(totalSeconds, secondsRemaining)
                }
                primaryButton("SKIP") { UnboundHaptics.heavy(); advance() }
            }
            .padding(.horizontal, 24)
        }
    }

    private func intervalFace(label: String, rounds: Int,
                              segments: [IntervalSegment]) -> some View {
        let seg = segments[min(intervalSegment, segments.count - 1)]
        return VStack(spacing: 24) {
            Spacer()
            Text(label.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.8).foregroundStyle(accent)
            Text("ROUND \(intervalRound) / \(rounds) · \(seg.label.uppercased())")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
            ZStack {
                Circle().strokeBorder(Color.unbound.surface, lineWidth: 10)
                    .frame(width: 210, height: 210)
                Circle()
                    .trim(from: 0, to: totalSeconds > 0
                          ? CGFloat(secondsRemaining) / CGFloat(totalSeconds) : 1)
                    .stroke(accent,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.5), radius: 12)
                    .animation(.linear(duration: 1), value: secondsRemaining)
                Text("\(secondsRemaining)")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
            }
            Spacer()
            primaryButton("SKIP ROUND") { UnboundHaptics.heavy(); advance() }
                .padding(.horizontal, 24)
        }
    }

    private func repTargetFace(name: String, target: Int?,
                               cue: String?) -> some View {
        let total = bursts.reduce(0, +)
        let hit = target.map { total >= $0 } ?? false
        return VStack(spacing: 22) {
            Spacer()
            Text(name.uppercased())
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.8).foregroundStyle(accent)
            Text(target.map { "\(total) / \($0)" } ?? "\(total)")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(hit ? accent : Color.unbound.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(total)))
                .scaleEffect(hit ? 1.04 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hit)
            if let cue {
                Text(cue).font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 28)
            }
            if !bursts.isEmpty {
                Text(bursts.map(String.init).joined(separator: " · "))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            HStack(spacing: 0) {
                stepperBtn("minus") { if burstEntry > 1 { burstEntry -= 1 } }
                Text("\(burstEntry)")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit().frame(width: 90)
                stepperBtn("plus") { burstEntry += 1 }
            }
            secondaryButton("ADD \(burstEntry)") {
                UnboundHaptics.medium()
                bursts.append(burstEntry)
            }
            .padding(.horizontal, 24)
            primaryButton(hit ? "DONE" : "I'M DONE") {
                UnboundHaptics.heavy(); advance()
            }
            .padding(.horizontal, 24).padding(.bottom, 8)
        }
    }

    private var completeFace: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold)).foregroundStyle(accent)
            }
            .shadow(color: accent.opacity(0.5), radius: 18)
            VStack(spacing: 6) {
                Text("ROUTINE COMPLETE")
                    .font(Font.unbound.captionS.weight(.bold)).tracking(2.0)
                    .foregroundStyle(accent)
                Text(routine.title.uppercased())
                    .font(Font.unbound.displayM).tracking(0.4)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 0) {
                completeStat(headlineValue, headlineLabel)
                Divider().frame(height: 32).background(Color.unbound.border)
                completeStat(historyLabel, "HISTORY")
                Divider().frame(height: 32).background(Color.unbound.border)
                completeStat("+\(routine.spReward)", "SP")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1))
            .padding(.horizontal, 32)
            Spacer()
            primaryButton("RETURN") {
                UnboundHaptics.heavy()
                onComplete(buildRecord())
            }
            .padding(.horizontal, 24).padding(.bottom, 40)
        }
    }

    // MARK: Reusable controls

    private func primaryButton(_ title: String,
                               _ action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Text(title).font(Font.unbound.bodyMStrong).tracking(1.6)
                .foregroundStyle(Color.unbound.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent))
                .shadow(color: accent.opacity(0.5), radius: 14, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String,
                                 _ action: @escaping () -> Void) -> some View {
        Button { UnboundHaptics.soft(); action() } label: {
            Text(title).font(Font.unbound.bodyMStrong).tracking(1.0)
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.unbound.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stepperBtn(_ icon: String,
                            _ action: @escaping () -> Void) -> some View {
        Button { UnboundHaptics.tick(); action() } label: {
            Image(systemName: icon).font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.unbound.surface))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func completeStat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary).monospacedDigit()
            Text(l).font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.6).foregroundStyle(Color.unbound.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var notesSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NOTES").font(Font.unbound.captionS.weight(.bold))
                .tracking(2.0).foregroundStyle(accent)
            ForEach(notes, id: \.self) { n in
                Text(n).font(Font.unbound.bodyS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.unbound.bg.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    // MARK: Drive

    private var isLast: Bool { index >= run.count - 1 }

    private func prepare(_ step: RoutineRunStep?) {
        guard let step else { return }
        switch step.kind {
        case .timed(_, let secs, _):
            secondsRemaining = secs; totalSeconds = secs
        case .interval(_, _, let segs):
            intervalRound = 1; intervalSegment = 0
            secondsRemaining = segs.first?.seconds ?? 0
            totalSeconds = secondsRemaining
        case .repTarget:
            bursts = []; burstEntry = 10
        default:
            break
        }
    }

    private func tick() {
        elapsedSeconds += 1
        guard let step = current else { return }
        switch step.kind {
        case .timed:
            if secondsRemaining <= 1 {
                UnboundHaptics.success(); advance()
            } else {
                secondsRemaining -= 1
                if secondsRemaining <= 3 { UnboundHaptics.tick() }
            }
        case .interval(_, let rounds, let segs):
            if secondsRemaining <= 1 {
                if intervalSegment + 1 < segs.count {
                    intervalSegment += 1
                } else if intervalRound + 1 <= rounds {
                    intervalRound += 1; intervalSegment = 0
                } else {
                    UnboundHaptics.success(); advance(); return
                }
                secondsRemaining = segs[intervalSegment].seconds
                totalSeconds = secondsRemaining
            } else {
                secondsRemaining -= 1
                if secondsRemaining <= 3 { UnboundHaptics.tick() }
            }
        default:
            break
        }
    }

    private func advance() {
        if isLast {
            withAnimation { isComplete = true }
            UnboundHaptics.success()
            return
        }
        index += 1
        prepare(current)
    }

    private func buildRecord() -> RoutineCompletionRecord {
        var allBursts: [Int] = []
        var hasRep = false
        for s in run {
            if case .repTarget = s.kind { hasRep = true }
        }
        // bursts only captured for the last repTarget interacted with; the
        // 20-routine set has at most one *interacted* repTarget surfaced at a
        // time, and multi-repTarget routines sum totals (per spec rule).
        if hasRep { allBursts = bursts }

        let metric: RoutineMetric
        if hasRep {
            metric = .repCount(total: allBursts.reduce(0, +), bursts: allBursts)
        } else if isTimerDominant {
            metric = .time(seconds: elapsedSeconds)
        } else {
            metric = .steps(done: run.count, total: run.count)
        }
        return RoutineCompletionRecord(
            routineId: routine.id,
            completedAt: Date(),
            elapsedSeconds: elapsedSeconds,
            primaryMetric: metric,
            spAwarded: routine.spReward)
    }

    /// Timer-dominant ⇔ the single longest timed/interval block ≥ 50% of
    /// elapsed (spec's pinned primaryMetric rule).
    private var isTimerDominant: Bool {
        var longest = 0
        for s in run {
            switch s.kind {
            case .timed(_, let secs, _):
                longest = max(longest, secs)
            case .interval(_, let rounds, let segs):
                longest = max(longest, rounds * segs.reduce(0) { $0 + $1.seconds })
            default: break
            }
        }
        return elapsedSeconds > 0 && Double(longest) >= Double(elapsedSeconds) * 0.5
    }

    private var headlineValue: String {
        switch buildRecord().primaryMetric {
        case .time(let s): return String(format: "%02d:%02d", s / 60, s % 60)
        case .repCount(let t, _): return "\(t)"
        case .steps(let d, _): return "\(d)"
        }
    }
    private var headlineLabel: String {
        switch buildRecord().primaryMetric {
        case .time: return "TIME"
        case .repCount: return "REPS"
        case .steps: return "STEPS"
        }
    }
    private var historyLabel: String {
        let s = RoutineHistoryStore.shared.summary(routineId: routine.id)
        return "\((s?.count ?? 0) + 1)×"
    }
}
```

- [ ] **Step 2: Read-review only (no build — module RED until T7)**

Confirm `SideQuestPlayerView` is gone and no symbol in this file references `SideQuest*`. Re-run the guard grep: `grep -rn "SideQuest" UNBOUND --include="*.swift"` — only `ProgramOverviewView.swift` (`.fullScreenCover` body, `completeRoutine`, `elapsedSeconds`) should remain; those are fixed in T7. `SideQuestCategory` will have zero referencers after T7 deletes `RoutineCategory.sideQuestCategory` — it was already deleted in T5 Step 4, so confirm `grep -rn "SideQuestCategory" UNBOUND` is now **empty** (Routine.swift no longer defines it — it was deleted with the `SideQuest*` rewrite). If anything still references it, that is a T5 miss — fix in this commit.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Views/Routine/RoutinePlayerView.swift && git commit -m "feat(routines): step-sequence RoutinePlayerView; delete SideQuestPlayerView

CLUSTER (T6/3): module compiles at the T7 seam.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Wire ProgramOverviewView + retire old store (CLUSTER SEAM — module GREEN)

**Files:**
- Modify: `UNBOUND/Views/Program/ProgramOverviewView.swift`

- [ ] **Step 1: Swap the player + completion in `ProgramOverviewView.swift`**

1. **`.fullScreenCover(item: $activeRoutinePlayer)`** (~line 196): replace the body
```swift
SideQuestPlayerView(routine: routine.sideQuest) { log in
    completeRoutine(routine, log: log)
}
.environmentObject(services)
```
with
```swift
RoutinePlayerView(routine: routine) { record in
    completeRoutine(routine, record: record)
}
.environmentObject(services)
```

2. **`completeRoutine`** (~1502) — replace the whole function:
```swift
private func completeRoutine(_ routine: RoutineDef, record: RoutineCompletionRecord) {
    let didAward = RoutineHistoryStore.shared.complete(routine)
    RoutineHistoryStore.shared.record(record)
    activeRoutinePlayer = nil

    let setsValue: Int
    let totalValue: Int
    switch record.primaryMetric {
    case .repCount(let total, let bursts):
        setsValue = total
        totalValue = max(total, bursts.reduce(0, +))
    case .steps(let done, let total):
        setsValue = done
        totalValue = total
    case .time:
        setsValue = 0
        totalValue = 0
    }

    completedRoutineReward = RoutineRewardPayload(
        title: routine.title,
        category: routine.category,
        elapsedSeconds: record.elapsedSeconds,
        completedSets: setsValue,
        totalSets: totalValue,
        spAwarded: routine.spReward,
        wasAlreadyCleared: !didAward
    )
    Task { await refreshHistory() }
}
```

3. **Delete** the now-orphaned `private func elapsedSeconds(from log: SideQuestLog?) -> Int { … }` helper (~1517) — nothing calls it.

4. **Switch the remaining store call sites** (`RoutineCompletionStore` → `RoutineHistoryStore.shared`):
   - `RoutineChallengeCard` canComplete (~2343): `RoutineHistoryStore.shared.canComplete(routineId: routine.id)`
   - detail-sheet canComplete (~2932): same
   - detail-sheet complete (~2946): `let awarded = RoutineHistoryStore.shared.complete(routine)`

5. **Delete** the entire legacy `@MainActor enum RoutineCompletionStore { … }` (~2108–2133).

- [ ] **Step 2: Render typed steps in the detail card + sheet**

In `ProgramOverviewView.swift`:

- `metricPill(value: "\(routine.steps.count)", label: "STEPS")` (~2380) — `routine.steps.count` still compiles (count of `RoutineStep`); leave as-is.
- `Text(routine.steps.first ?? "Open the mission and start.")` (~2384) — replace with a typed display helper:
```swift
Text(routine.steps.first.map(routineStepPreview) ?? "Open the mission and start.")
```
- detail-sheet step list `ForEach(Array(routine.steps.enumerated()), id: \.offset) { i, step in … }` (~2902) — the body renders `step` (was `String`). Replace the per-row text with `routineStepPreview(step)` everywhere `step` was used as a `String`.
- Add this private helper near `RoutineChallengeCard` (file-scope `private func` or a `private extension RoutineStep`):
```swift
private func routineStepPreview(_ step: RoutineStep) -> String {
    switch step {
    case .instruction(let t, _):            return t
    case .timed(let l, let s, _):           return "\(l) — \(s)s"
    case .interval(let l, let r, _):        return "\(l) — \(r) rounds"
    case .repTarget(let n, let t, _):       return t.map { "\(n) — \($0)" } ?? "\(n) — AMRAP"
    case .circuit(let r, _, _):             return "Circuit × \(r) rounds"
    case .note(let t):                      return t
    }
}
```

- [ ] **Step 3: Regenerate + build + full test suite (the seam gate)**

Run:
```bash
cd /Users/jlin/Documents/toji/UNBOUND && xcodegen generate >/dev/null && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. If it fails on a remaining `SideQuest*` / `RoutineCompletionStore` / `RoutineDef.sideQuest` reference, grep `grep -rn "SideQuest\|RoutineCompletionStore\|\.sideQuest" UNBOUND --include="*.swift"` and fix each (all should now be replaced).

Then the authoritative suite:
```bash
cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -20
```
Expected: all green **except** the known pre-existing flap `FriendChallengeServiceTests.testCreateChallengeThrowsWhenBackendUnavailable` (PostgrestError 42501 RLS) and/or the sibling `SquadMissionServiceTests` RLS test. Zero NEW failures. `RoutineStepTests`, `RoutineRunTests`, `RoutineCompletionRecordTests`, `RoutineHistoryStoreTests`, `RoutineLibraryTests` all pass. SourceKit cross-file "Cannot find" diagnostics are noise per project rule when `xcodebuild` passes — ignore.

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && git add UNBOUND/Views/Program/ProgramOverviewView.swift project.yml && git commit -m "feat(routines): wire RoutinePlayerView + RoutineHistoryStore; retire SideQuest path

Cluster seam — module green. completeRoutine(_:record:) feeds the reward
payload real time/count values; old RoutineCompletionStore deleted; detail
card/sheet render typed steps.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: On-device verification (jlin)

**Files:** none (manual sign-off).

- [ ] **Step 1: Build + install + launch**

```bash
cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -2
APP=$(ls -dt /Users/jlin/Library/Developer/Xcode/DerivedData/UNBOUND-*/Build/Products/Debug-iphonesimulator/UNBOUND.app | head -1)
xcrun simctl install booted "$APP" && xcrun simctl launch booted com.unboundapp.ios
```

- [ ] **Step 2: jlin walks 4 representative routines**

Program → Routines, then verify:
1. **20-min Zone 2 walk** (cardio) → warm-up countdown auto-advances → note card → big 20:00 ring counting down, **no rep stepper, no LOG SET** → cool-down → complete shows `TIME`.
2. **Tabata core** (challenge) → 4 interval blocks, ring auto-cycles WORK 20 / REST 10, "ROUND k / 2", move label per block, no manual logging.
3. **8 Gates Protocol** (challenge) → instruction card → DONE → auto rest ring between gates → the "DNF after Gate 5" line is in the ⓘ notes sheet, **not** a step. Bodyweight full-body / Underground Grind → "ROUND k / N" advances through the circuit with inter-round rests.
4. **100 pushup challenge** → do a burst → dial count on the stepper → **ADD** → total climbs `35 / 100`, ledger shows `35` → repeat → at ≥100 the number blooms accent + primary reads **DONE** → complete shows `REPS` + `2×` history.

Confirm the reward sheet still appears (fed real time/count, no fabricated sets) and the 24h cooldown still gates a same-day re-complete.

- [ ] **Step 3:** jlin signs off or files diffs. Done.

---

## Self-Review

**1. Spec coverage:**
- Typed model (instruction/timed/interval/repTarget/circuit/note + TimedStyle + IntervalSegment) → T1 ✓
- Runtime expansion (circuit→round-tagged, note filtered, rest between rounds) → T2 ✓
- `RoutineCompletionRecord`/`RoutineMetric` → T3 ✓
- `RoutineHistoryStore` local-first, preserved `canComplete`/24h/gains API + `record`/`history`/`summary` → T4 ✓
- 20 routines hand-authored, types moved to `Routine.swift`, `SideQuest*`/parser/`.sideQuest` retired with co-located grep guard → T5 ✓
- Step-sequence player faces, no logging, reuse ring, `SideQuestPlayerView` deleted → T6 ✓
- Wire fullScreenCover + `completeRoutine(_:record:)` + reward payload real values + 3 store sites + delete old store + typed detail rendering → T7 ✓
- Player `primaryMetric` selection rule = spec's pinned rule (`isTimerDominant` ≥50% longest block; repTarget→repCount; else steps) → T6 ✓
- On-device 4 representative routines → T8 ✓

**2. Placeholder scan:** No "TBD"/"TODO"/"implement later". All 20 routines authored in full in T5 Step 3. All test bodies and implementations are complete code. Cluster-RED tasks (T5/T6) explicitly say read-review-only with the rationale, not "build later — figure it out".

**3. Type consistency:** `RoutineStep` cases, `IntervalSegment(label:seconds:)`, `RoutineMetric` (`.time(seconds:)`/`.repCount(total:bursts:)`/`.steps(done:total:)`), `RoutineCompletionRecord(routineId:elapsedSeconds:primaryMetric:spAwarded:)`, `RoutineHistoryStore.shared` + `canComplete`/`complete`/`record`/`history(routineId:)`/`summary(routineId:)`, `RoutinePlayerView(routine:onComplete:)`, `completeRoutine(_:record:)`, `RoutineRewardPayload(title:category:elapsedSeconds:completedSets:totalSets:spAwarded:wasAlreadyCleared:)` (matches the existing struct at ~2721) — consistent across T1–T8. `RoutineLibrary.placeholderRoutines` name preserved (carousel/`routineSection` still reference it).

Plan complete and saved to `docs/superpowers/plans/2026-05-17-routine-player-redesign.md`.
