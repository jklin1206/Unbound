# Last Performance in the Logger — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each set's last performance (weight×reps / reps / hold-seconds) in the workout logger, with last performance driving the weight prefill and the program suggestion shown as the target.

**Architecture:** A pure `LastPerformanceLookup` is built from the user's recent `WorkoutLog`s and attached per-set onto the live session in `loadContext()`. `SetLogGridRow` renders a dim reference line from it; the weight-prefill sites prefer it over the suggestion.

**Tech Stack:** Swift / SwiftUI, XCTest, XcodeGen (run `xcodegen generate` after adding files).

## Global Constraints

- Swift 5.9, iOS 17 deployment target.
- Build/test sim: iPhone 17 (`id=810087B3-226D-4398-8ABD-9FF61E642E1D`). Always `set -o pipefail` + gate on `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`.
- New `.swift` files require `xcodegen generate` before building (pbxproj is generated).
- Keep `import` lines. Match existing token usage (`Color.unbound.*`, `Font.unbound.*`). Never `git add -A` (shared tree) — stage explicit paths.
- `LastPerformanceLookup` must have **zero** app/DB/SwiftUI dependencies (Foundation + the model types only) so it unit-tests in isolation.

---

### Task 1: `LastPerformanceLookup` (pure core) + tests

**Files:**
- Create: `UNBOUND/Models/Sessions/LastPerformanceLookup.swift`
- Test: `UNBOUNDTests/Models/LastPerformanceLookupTests.swift`

**Interfaces:**
- Consumes: `WorkoutLog`, `ExerciseLogEntry`, `SetLog` (existing, `UNBOUND/Models/Sessions/WorkoutLog.swift`).
- Produces:
  - `struct LastSetPerformance: Equatable, Sendable { var weightKg: Double?; var reps: Int?; var durationSeconds: Int?; var performedAt: Date }`
  - `struct LastPerformanceLookup { init(logs: [WorkoutLog], excludingLogId: String?); func lastWorkingSet(movementId: String?, exerciseName: String, workingIndex: Int) -> LastSetPerformance? }`
  - Match: `movementId` first, normalized `exerciseName` fallback. `workingIndex` is 0-based over non-warmup sets of the most-recent prior non-skipped entry.

- [ ] **Step 1: Write the failing tests**

```swift
// UNBOUNDTests/Models/LastPerformanceLookupTests.swift
import XCTest
@testable import UNBOUND

final class LastPerformanceLookupTests: XCTestCase {
    private func set(_ n: Int, kg: Double? = nil, reps: Int = 0, hold: Int? = nil, warmup: Bool = false) -> SetLog {
        SetLog(id: "s\(n)", setNumber: n, weightKg: kg, reps: reps, rpe: nil,
               isWarmup: warmup, durationSeconds: hold, qualityFlags: nil, notes: nil)
    }
    private func entry(name: String, movementId: String? = nil, skipped: Bool = false, sets: [SetLog]) -> ExerciseLogEntry {
        ExerciseLogEntry(id: "e-\(name)", exerciseName: name, movementId: movementId,
                         rankStandardMovementId: nil, plannedSets: sets.count, plannedReps: "",
                         sets: sets, skipped: skipped, notes: nil)
    }
    private func log(id: String, at: Date, entries: [ExerciseLogEntry]) -> WorkoutLog {
        WorkoutLog(id: id, userId: "u", programId: "p", dayNumber: 1, plannedWorkoutName: "",
                   startedAt: at, completedAt: at, exerciseEntries: entries, overallNotes: nil,
                   overallRPE: nil, durationMinutes: nil)
    }
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func test_returnsMostRecentPriorWorkingSetByMovementId() {
        let older = log(id: "old", at: t0, entries: [entry(name: "Bench", movementId: "m1", sets: [set(1, kg: 100, reps: 8)])])
        let newer = log(id: "new", at: t0.addingTimeInterval(86_400),
                        entries: [entry(name: "Bench", movementId: "m1", sets: [set(1, kg: 110, reps: 8)])])
        let lookup = LastPerformanceLookup(logs: [older, newer], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: "m1", exerciseName: "Bench", workingIndex: 0)?.weightKg, 110)
    }

    func test_movementIdWinsOverName_andNameFallbackWhenNoId() {
        let l = log(id: "a", at: t0, entries: [entry(name: "Pull-Up", sets: [set(1, reps: 12)])])
        let lookup = LastPerformanceLookup(logs: [l], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: nil, exerciseName: "pull-up ", workingIndex: 0)?.reps, 12)  // normalized
        XCTAssertNil(lookup.lastWorkingSet(movementId: "missing", exerciseName: "Other", workingIndex: 0))
    }

    func test_workingIndexSkipsWarmups_andMissingLaterSetIsNil() {
        let l = log(id: "a", at: t0, entries: [entry(name: "Squat", movementId: "m", sets: [
            set(1, kg: 60, reps: 5, warmup: true), set(2, kg: 140, reps: 5), set(3, kg: 140, reps: 4)
        ])])
        let lookup = LastPerformanceLookup(logs: [l], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: "m", exerciseName: "Squat", workingIndex: 0)?.weightKg, 140)  // first WORKING
        XCTAssertNil(lookup.lastWorkingSet(movementId: "m", exerciseName: "Squat", workingIndex: 2))                   // only 2 working
    }

    func test_holdsAndSkippedAndExclusion() {
        let hold = log(id: "h", at: t0, entries: [entry(name: "Plank", movementId: "pl", sets: [set(1, hold: 45)])])
        let skip = log(id: "s", at: t0.addingTimeInterval(86_400),
                       entries: [entry(name: "Plank", movementId: "pl", skipped: true, sets: [set(1, hold: 9)])])
        let lookup = LastPerformanceLookup(logs: [skip, hold], excludingLogId: nil)
        XCTAssertEqual(lookup.lastWorkingSet(movementId: "pl", exerciseName: "Plank", workingIndex: 0)?.durationSeconds, 45)  // skipped ignored
        let selfExcluded = LastPerformanceLookup(logs: [hold], excludingLogId: "h")
        XCTAssertNil(selfExcluded.lastWorkingSet(movementId: "pl", exerciseName: "Plank", workingIndex: 0))
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run:
```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/codex-workflow-test && xcodegen generate >/dev/null && set -o pipefail && xcodebuild test -project UNBOUND.xcodeproj -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' -only-testing:UNBOUNDTests/LastPerformanceLookupTests 2>&1 | tail -25
```
Expected: FAIL — `cannot find 'LastPerformanceLookup' in scope`.

- [ ] **Step 3: Implement `LastPerformanceLookup`**

```swift
// UNBOUND/Models/Sessions/LastPerformanceLookup.swift
import Foundation

/// One set's last performance, read from prior WorkoutLog history.
struct LastSetPerformance: Equatable, Sendable {
    var weightKg: Double?
    var reps: Int?
    var durationSeconds: Int?   // holds/carries; nil for rep-based sets
    var performedAt: Date
}

/// Pure lookup of the most-recent prior performance per exercise, built from the
/// user's recent completed WorkoutLogs. `workingIndex` is 0-based over the entry's
/// non-warmup sets. No app/DB/UI dependencies — unit-testable in isolation.
struct LastPerformanceLookup {
    private struct Entry { let sets: [SetLog]; let performedAt: Date }
    private var byKey: [String: Entry] = [:]

    init(logs: [WorkoutLog], excludingLogId: String?) {
        let sorted = logs
            .filter { $0.id != excludingLogId }
            .sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
        for log in sorted {
            let when = log.completedAt ?? log.startedAt
            for entry in log.exerciseEntries where !entry.skipped {
                let working = entry.sets.filter { !$0.isWarmup }
                guard !working.isEmpty else { continue }
                for key in Self.keys(for: entry) where byKey[key] == nil {
                    byKey[key] = Entry(sets: working, performedAt: when)
                }
            }
        }
    }

    func lastWorkingSet(movementId: String?, exerciseName: String, workingIndex: Int) -> LastSetPerformance? {
        guard let entry = resolve(movementId: movementId, exerciseName: exerciseName),
              workingIndex >= 0, workingIndex < entry.sets.count else { return nil }
        let s = entry.sets[workingIndex]
        return LastSetPerformance(weightKg: s.weightKg, reps: s.reps,
                                  durationSeconds: s.durationSeconds, performedAt: entry.performedAt)
    }

    private func resolve(movementId: String?, exerciseName: String) -> Entry? {
        if let mid = movementId, let e = byKey["mid:" + mid] { return e }
        return byKey["name:" + Self.normalize(exerciseName)]
    }
    private static func keys(for entry: ExerciseLogEntry) -> [String] {
        var keys = ["name:" + normalize(entry.exerciseName)]
        if let mid = entry.movementId { keys.append("mid:" + mid) }
        return keys
    }
    private static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run the Step-2 command. Expected: `** TEST SUCCEEDED **`, all 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/Sessions/LastPerformanceLookup.swift UNBOUNDTests/Models/LastPerformanceLookupTests.swift
git commit -m "feat(logger): pure LastPerformanceLookup over WorkoutLog history"
```

---

### Task 2: Attach last performance to the session + populate on load

**Files:**
- Modify: `UNBOUND/Models/Sessions/ActiveWorkoutSession+Models.swift` (the `ActiveSet` struct, ~line 25-44)
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` (`loadContext()`, ~line 627)

**Interfaces:**
- Consumes: `LastPerformanceLookup`, `LastSetPerformance` (Task 1); `services.database.query(collection:field:isEqualTo:orderBy:descending:limit:)` returning `[WorkoutLog]`.
- Produces: `ActiveWorkoutSession.ActiveSet.lastPerformance: LastSetPerformance?`, populated for non-warmup sets after load.

- [ ] **Step 1: Add the field to `ActiveSet`**

In `ActiveWorkoutSession+Models.swift`, inside `struct ActiveSet`, after `var suggestedRestSeconds: Double?` / before `qualityFlags`, add:

```swift
        /// Most-recent prior performance for this working set, for display + weight prefill.
        var lastPerformance: LastSetPerformance? = nil
```
(Optional + default keeps the memberwise init + Codable source-compatible; `LastSetPerformance` must be `Codable` — add `Codable` to its conformances in Task 1's file: `struct LastSetPerformance: Codable, Equatable, Sendable`.)

- [ ] **Step 2: Populate it in `loadContext()`**

In `ActiveWorkoutContainerView.loadContext()` (after `guard let uid = services.auth.currentUserId else { return }`), add a fetch + population block:

```swift
        // Last-performance: most-recent prior WorkoutLogs → per-set reference + prefill source.
        let recentLogs: [WorkoutLog] = (try? await services.database.query(
            collection: "workoutLogs", field: "userId", isEqualTo: uid,
            orderBy: "startedAt", descending: true, limit: 40
        )) ?? []
        let lookup = LastPerformanceLookup(logs: recentLogs, excludingLogId: nil)  // live session has no persisted WorkoutLog yet
        for ei in session.exercises.indices {
            let mid = session.exercises[ei].movementId
            let name = session.exercises[ei].name
            var workingIndex = 0
            for si in session.exercises[ei].sets.indices {
                guard !session.exercises[ei].sets[si].isWarmup else { continue }
                session.exercises[ei].sets[si].lastPerformance =
                    lookup.lastWorkingSet(movementId: mid, exerciseName: name, workingIndex: workingIndex)
                workingIndex += 1
            }
        }
```

Verified fields: `ActiveExercise.movementId: String?` and `.name: String` exist (`ActiveWorkoutSession+Models.swift:111-112`). `movementId` is already optional — pass it straight through (`nil` falls back to name match inside the lookup).

- [ ] **Step 3: Build to verify it compiles**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/codex-workflow-test && xcodegen generate >/dev/null && set -o pipefail && xcodebuild build -project UNBOUND.xcodeproj -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -8
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Models/Sessions/ActiveWorkoutSession+Models.swift UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift
git commit -m "feat(logger): fetch + attach last performance per working set on load"
```

---

### Task 3: Display the reference line in `SetLogGridRow`

**Files:**
- Modify: `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift`
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift` (call site ~line 197)

**Interfaces:**
- Consumes: `LastSetPerformance` (Task 1), `set.lastPerformance` (Task 2).
- Produces: `SetLogGridRow` shows the dim reference line; weight cell dim value = last ?? suggested.

- [ ] **Step 1: Add inputs + reference line to `SetLogGridRow`**

Add a stored property near the other `let`s:
```swift
    let lastPerformance: LastSetPerformance?
```
Change the weight cell so its dim value prefers last:
```swift
                cell(actual: weightKg.map(formatLoggedWeight),
                     suggested: (lastPerformance?.weightKg ?? suggestedWeightKg).map(formatSuggestionWeight),
                     action: onEditWeight)
```
Inside `body`'s outer `VStack(alignment: .leading, spacing: 6)`, after the `HStack { … }`, add the reference line:
```swift
            if let line = lastReferenceLine {
                Text(line)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .padding(.leading, 34)
            }
```
Add the computed string (private), formatted by `metricKind` + matching the row's weight unit:
```swift
    private var lastReferenceLine: String? {
        guard let last = lastPerformance else { return nil }
        var parts: [String] = []
        switch metricKind {
        case .reps:
            if let kg = last.weightKg, let r = last.reps {
                if let s = suggestedWeightKg, s != kg { parts.append("target " + formatSuggestionWeight(s)) }
                parts.append("last " + formatLoggedWeight(kg) + " × \(r)")
            } else if let r = last.reps {
                parts.append("last \(r) reps")
            }
        case .holdSeconds:
            if let d = last.durationSeconds { parts.append("last \(d)s") }
        case .durationSeconds:
            if let d = last.durationSeconds { parts.append("last " + Self.time(d)) }
        case .distanceMeters, .calories:
            if let r = last.reps { parts.append("last \(r)") }
        }
        guard !parts.isEmpty else { return nil }
        parts.append(Self.relativeAge(last.performedAt))
        return parts.joined(separator: " · ")
    }

    private static func relativeAge(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "today" }
        if days == 1 { return "1d ago" }
        return "\(days)d ago"
    }
```

- [ ] **Step 2: Pass `lastPerformance` at the call site**

In `ExerciseLogCard.swift`, in the `SetLogGridRow(` call (~line 206, alongside `suggestedWeightKg:`), add:
```swift
                lastPerformance: set.lastPerformance,
```

- [ ] **Step 3: Build to verify**

Run the Task-2 Step-3 build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift
git commit -m "feat(logger): show last-performance reference line per set"
```

---

### Task 4: Last drives the weight prefill

**Files:**
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView+Intents.swift` (~line 19)
- Modify: `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView+Keypad.swift` (`editPlaceholder`, ~line 86)

**Interfaces:**
- Consumes: `set.lastPerformance` (Task 2).
- Produces: weight prefill = `lastPerformance?.weightKg ?? suggestedWeightKg ?? …`.

- [ ] **Step 1: `+Intents` — confirm/seed uses last weight first**

Change the `.reps` weight assignment:
```swift
                    set.weightKg = set.lastPerformance?.weightKg ?? set.suggestedWeightKg ?? debugWeightKg(exerciseIndex: exerciseIndex, setIndex: setIndex)
```

- [ ] **Step 2: `+Keypad` — `editPlaceholder` pre-seeds to last weight first**

In `editPlaceholder`, change the weight branch:
```swift
        if target.isWeight {
            guard let kg = set.lastPerformance?.weightKg ?? set.suggestedWeightKg ?? set.weightKg else { return "—" }
            return displayNumber(WeightPlatePolicy.editingValue(fromKilograms: kg, unit: editWeightUnit))
        }
```

- [ ] **Step 3: Build to verify**

Run the Task-2 Step-3 build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView+Intents.swift UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView+Keypad.swift
git commit -m "feat(logger): last performance drives the weight prefill"
```

---

### Task 5: Sim verification

- [ ] **Step 1:** Build + install the combined/feature build on the iPhone 17 sim; launch QA Lab (`--unbound-dev-dynamic-program program-qa-lab`).
- [ ] **Step 2:** Log a session (weights + a hold). Advance a day via the dev SIM panel (Train → Quest Board → `›`). Open the next session's logger.
- [ ] **Step 3:** Confirm: each previously-performed set shows `last …`, the weight cell is prefilled to the last weight, and the suggested shows as `target …` when it differs. Screenshot + Read to verify. No crash (3× launch).

---

## Notes for the implementer
- Verified: `ActiveExercise.movementId: String?`, `.name: String` (`ActiveWorkoutSession+Models.swift:111-112`); `TrainingMetricKind` cases are `reps / holdSeconds / durationSeconds / distanceMeters / calories` (`TrainingSessionDraft.swift:29`) — the Task-3 switch matches.
- `loadContext()` already loops exercises and fetches per-exercise working weight (~`ActiveWorkoutContainerView.swift:643`); add the workoutLogs fetch alongside it (single fetch, before the per-set loop).
