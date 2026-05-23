# RPE Scale Revision — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the traffic-light effort dot with a real numeric **RPE 6–10** scale: the set row becomes `SET · WEIGHT · REPS · RPE · ✓` (✓ logs, RPE is an optional tap-to-pick cell explained in-picker), `ActiveSet` stores `rpe: Int?` directly, and the `Effort`/`EffortRPEMap` path retires.

**Architecture:** Surgical swap of the effort-capture mechanic across the model + the set row + a new picker + the onboarding sandbox. The grid/card/pill/container/exercise-detail redesign and the whole `complete()`→`saveLog`→reward path stay byte-unchanged. `SetLog.rpe` is already `Int?` so the persistence + ProgressionEngine path is unaffected — we just stop mapping through `Effort`.

**Tech Stack:** Swift 5.9, SwiftUI, XCTest, xcodegen. Branch `program-redesign`. Sim iPhone 17.

**Spec:** `docs/superpowers/specs/2026-05-17-workout-logging-redesign-v2-design.md` (revised decisions #2, #3, #7). Read its "Design bar" before any UI task.

---

## Verified current state (this session)

```swift
// UNBOUND/Models/ActiveWorkoutSession.swift  — @MainActor final class ObservableObject
struct ActiveSet: Identifiable, Codable, Sendable {
  let id: String; var weightKg: Double?; var reps: Int?
  var effort: Effort?            // ← BECOMES: var rpe: Int?
  var isWarmup: Bool; var logged: Bool }
struct ActiveExercise: Identifiable, Codable, Sendable { let id; var name; var plannedSets; var plannedReps; var restSeconds; var muscleGroups:[MuscleGroup]; var sets:[ActiveSet]; var skipped; var notes }
struct Snapshot: Codable { … exercises:[ActiveExercise] … }
// existing methods touching effort:
//   logCurrentSet(weightKg:reps:)            — current-index; does NOT touch effort
//   setEffort(_ effort: Effort)              — current-index  ← REMOVE
//   logSet(exerciseIndex:setIndex:weightKg:reps:)   — defaults effort=.solid when nil  ← drop the default
//   setEffort(exerciseIndex:setIndex:_ : Effort)    — index    ← REPLACE with setRPE
//   cycleEffort(exerciseIndex:setIndex:)            — index    ← REMOVE
//   addSet(toExerciseIndex:) / removeLastSet(fromExerciseIndex:)  — keep as-is
//   assembleWorkoutLog(userId:): SetLog(... rpe: set.effort?.rpe ...)  ← becomes set.rpe
//   private static let effortCycle: [Effort]        ← REMOVE
// UNBOUND/Models/EffortRPEMap.swift  (enum Effort + var rpe)            ← RETIRE (git rm)
// UNBOUNDTests/Models/EffortRPEMapTests.swift                          ← RETIRE (git rm)
// UNBOUNDTests/Models/ActiveWorkoutSessionTests.swift (v1)  — uses .effort/.setEffort  ← UPDATE
// UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift     — uses .effort/setEffort/cycleEffort  ← REWRITE for rpe
// UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift   — traffic-light dot (effort, onLog, onCycleEffort)  ← REWRITE
// UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift — passes effort/onLog/onCycleEffort                 ← UPDATE
// UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift — onCycleEffort:(Int,Int)                        ← rename onPickRPE
// UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift — onLog defaults effort; onCycleEffort→cycleEffort
//   ← onLog stops defaulting effort; onCycleEffort → onPickRPE presenting RPEPickerSheet → session.setRPE.
//     complete()/loadContext()/reward sheet/draft-autosave MUST stay byte-unchanged.
// UNBOUND/Views/Onboarding/RPEOnboardingStep.swift — uses cycleEffort  ← REWRITE to teach 6–10 via picker
// Tokens: Color.unbound.{bg,surface,surfaceElevated,textPrimary,textSecondary,textTertiary,border,borderSubtle,accent,warnOrange,success,alert}
//         Font.unbound.{titleM,bodyM,bodyMStrong,bodyLStrong,captionS,monoS,monoM,monoL}; UnboundHaptics.{tick(),success()}
```

**Commit trailer:** every commit ends with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`. Branch `program-redesign`. `project.pbxproj` gitignored → `xcodegen generate` after add/rm before build/test. **Test cmd:** `cd /Users/jlin/Documents/toji/UNBOUND && xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | tail -25` — only the pre-existing backend flap (`FriendChallengeServiceTests`/`SquadMissionServiceTests`) may fail; zero NEW failures. SourceKit "Cannot find" outside xcodebuild = noise.

**RPE meanings (use this exact copy everywhere RPE is explained):**
`10 = nothing left` · `9 = 1 rep left` · `8 = 2 reps left` · `7 = 3 reps left` · `6 = 4+ reps left`

---

## Task 1: Model — ActiveSet.rpe + setRPE; retire Effort/EffortRPEMap (TDD)

**Files:** Modify `UNBOUND/Models/ActiveWorkoutSession.swift`; Rewrite `UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift`; Modify `UNBOUNDTests/Models/ActiveWorkoutSessionTests.swift`; `git rm` `UNBOUND/Models/EffortRPEMap.swift` + `UNBOUNDTests/Models/EffortRPEMapTests.swift`.

- [ ] **Step 1: Rewrite `UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift` to the RPE model**

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class ActiveWorkoutSessionV2Tests: XCTestCase {
    private func workout() -> Workout {
        Workout(name: "Push", targetMuscleGroups: [], warmup: [],
            mainExercises: [
                Exercise(id: "e1", name: "Bench", muscleGroups: [.chest], sets: 3, reps: "8",
                         restSeconds: 90, rpe: nil, notes: nil, substitution: nil),
                Exercise(id: "e2", name: "Fly", muscleGroups: [.chest], sets: 2, reps: "12",
                         restSeconds: 60, rpe: nil, notes: nil, substitution: nil),
            ], cooldown: [], estimatedMinutes: 30, notes: nil, blockType: nil)
    }
    func test_logSet_anyOrder_recordsNoRPEByDefault() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 1, setIndex: 0, weightKg: 30, reps: 12)
        XCTAssertTrue(s.exercises[1].sets[0].logged)
        XCTAssertEqual(s.exercises[1].sets[0].weightKg, 30)
        XCTAssertEqual(s.exercises[1].sets[0].reps, 12)
        XCTAssertNil(s.exercises[1].sets[0].rpe)          // RPE is optional, NOT defaulted on log
        XCTAssertFalse(s.exercises[0].sets[0].logged)
    }
    func test_setRPE_indexAddressed_setAndClear() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 2, weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 2, 8)
        XCTAssertEqual(s.exercises[0].sets[2].rpe, 8)
        s.setRPE(exerciseIndex: 0, setIndex: 2, 10)
        XCTAssertEqual(s.exercises[0].sets[2].rpe, 10)
        s.setRPE(exerciseIndex: 0, setIndex: 2, nil)      // Clear
        XCTAssertNil(s.exercises[0].sets[2].rpe)
    }
    func test_setRPE_outOfRange_isNoOp() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.setRPE(exerciseIndex: 9, setIndex: 9, 8)         // no crash
        XCTAssertNil(s.exercises[0].sets[0].rpe)
    }
    func test_addAndRemoveSet_indexAddressed() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.addSet(toExerciseIndex: 1)
        XCTAssertEqual(s.exercises[1].sets.count, 3)
        s.removeLastSet(fromExerciseIndex: 1)
        XCTAssertEqual(s.exercises[1].sets.count, 2)
        s.removeLastSet(fromExerciseIndex: 9)
    }
    func test_assembleWorkoutLog_passesRPEStraight() {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 9)
        s.logSet(exerciseIndex: 1, setIndex: 1, weightKg: 30, reps: 11)   // no RPE set
        let log = s.assembleWorkoutLog(userId: "u")
        XCTAssertEqual(log.exerciseEntries[0].sets.count, 1)
        XCTAssertEqual(log.exerciseEntries[0].sets[0].rpe, 9)
        XCTAssertEqual(log.exerciseEntries[1].sets.count, 1)
        XCTAssertNil(log.exerciseEntries[1].sets[0].rpe)
    }
    func test_snapshotRoundTrip_preservesRPE() throws {
        let s = ActiveWorkoutSession(workout: workout(), programId: "p", dayNumber: 1)
        s.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 80, reps: 8)
        s.setRPE(exerciseIndex: 0, setIndex: 0, 7)
        let data = try JSONEncoder().encode(s.snapshot())
        let snap = try JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        let r = ActiveWorkoutSession(snapshot: snap)
        XCTAssertEqual(r.exercises[0].sets[0].rpe, 7)
        XCTAssertTrue(r.exercises[0].sets[0].logged)
    }
}
```

- [ ] **Step 2: Update `UNBOUNDTests/Models/ActiveWorkoutSessionTests.swift` (v1)** — open it; anywhere it references `.effort`, `Effort`, `setEffort`, or asserts `rpe` derived from effort in `assembleWorkoutLog`, replace with the `rpe: Int?` model: use `s.setRPE(exerciseIndex:setIndex:_:)` (or current-index logging then `setRPE`) and assert `sets[i].rpe` / `log...sets[i].rpe` directly. Any test that asserted "effort defaults to .solid on log" must now assert `rpe == nil` after `logSet`. Do not delete coverage — translate each effort assertion to the equivalent rpe assertion. (If the v1 file has no effort references, leave it untouched.)

- [ ] **Step 3: Run tests, verify FAIL** (`xcodegen generate >/dev/null 2>&1; <test cmd>`): `Effort`/`setEffort`/`cycleEffort` symbols gone → compile failures expected.

- [ ] **Step 4: Modify `ActiveWorkoutSession.swift`:**
  - In `ActiveSet`: replace `var effort: Effort?` with `var rpe: Int?`. Update EVERY `ActiveSet(...)` construction in the file (the `init(workout:)` mapping, `addSet(toExerciseIndex:)`, any current-index add, snapshot decode path) to use `rpe: nil` in place of `effort: nil` (keep argument order matching the struct's memberwise init).
  - Delete `private static let effortCycle`, `func cycleEffort(exerciseIndex:setIndex:)`, `func setEffort(exerciseIndex:setIndex:_:)`, and the current-index `func setEffort(_ effort: Effort)`.
  - In `logSet(exerciseIndex:setIndex:weightKg:reps:)` remove the `if … effort == nil { … = .solid }` block entirely (logging never sets RPE).
  - Add:

```swift
    func setRPE(exerciseIndex ei: Int, setIndex si: Int, _ rpe: Int?) {
        guard exercises.indices.contains(ei),
              exercises[ei].sets.indices.contains(si) else { return }
        exercises[ei].sets[si].rpe = rpe
    }
```

  - In `assembleWorkoutLog(userId:)` change the `SetLog(...)` `rpe:` argument from `set.effort?.rpe` to `set.rpe`.

- [ ] **Step 5: Retire Effort/EffortRPEMap**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git rm UNBOUND/Models/EffortRPEMap.swift UNBOUNDTests/Models/EffortRPEMapTests.swift
```
Then grep for stragglers: `grep -rn "Effort\b\|EffortRPEMap" --include=*.swift UNBOUND/ UNBOUNDTests/ | grep -v "RPE"` — every remaining hit (e.g. in `SetLogGridRow`, `ExerciseLogCard`, `WorkoutLogGridView`, `ActiveWorkoutContainerView`, `RPEOnboardingStep`) is fixed by the LATER tasks; for THIS task only the model + its two test files + the retired files must compile. The UI files still referencing `Effort` will not compile yet — that's expected; Task 1's gate is **the model + test targets compile and the model tests pass once the UI is also migrated**. To keep Task 1 self-verifying without the UI, **temporarily** the build will break on the UI files. THEREFORE: Task 1 commits the model+tests+retirement together with Tasks 3–6's UI migration is too coupled — instead Task 1 ends at: model changed, Effort files removed, `xcodegen generate` run, and `xcodebuild build` will fail ONLY on the not-yet-migrated UI files (SetLogGridRow/ExerciseLogCard/WorkoutLogGridView/ActiveWorkoutContainerView/RPEOnboardingStep). Capture that the ONLY build errors are "Cannot find 'Effort'/'cycleEffort'/'setEffort'/'effort'" in those 5 UI files and nothing else. Do NOT run the full test suite yet (it can't link). Commit the model+tests+retirement now; Tasks 2–6 restore a green build/suite.

- [ ] **Step 6: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Models/ActiveWorkoutSession.swift UNBOUNDTests/Models/ActiveWorkoutSessionV2Tests.swift UNBOUNDTests/Models/ActiveWorkoutSessionTests.swift
git commit -m "$(printf 'refactor(logging): ActiveSet stores rpe:Int?; setRPE; retire Effort/EffortRPEMap\n\nUI files migrate in the following tasks; build intentionally red on the 5 UI files until then.\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 2: RPEPickerSheet (UI — design bar)

**Files:** Create `UNBOUND/Views/Program/ActiveWorkout/RPEPickerSheet.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// Optional per-set RPE picker. Real strength scale (6–10) with the
/// reps-in-reserve meaning beside each number — this is where RPE is explained
/// in context. Returns Int? (nil = Clear).
struct RPEPickerSheet: View {
    let current: Int?
    let onPick: (Int?) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let rows: [(Int, String)] = [
        (10, "Nothing left"),
        (9,  "1 rep left"),
        (8,  "2 reps left"),
        (7,  "3 reps left"),
        (6,  "4+ reps left"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HOW HARD? — RPE")
                .font(Font.unbound.captionS).tracking(2)
                .foregroundStyle(Color.unbound.textTertiary)
                .padding(.bottom, 16)

            ForEach(Self.rows, id: \.0) { value, meaning in
                Button {
                    onPick(value)
                    UnboundHaptics.tick()
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Text("\(value)")
                            .font(Font.unbound.monoL)
                            .foregroundStyle(Color.unbound.textPrimary)
                            .frame(width: 40, alignment: .leading)
                        Text(meaning)
                            .font(Font.unbound.bodyM)
                            .foregroundStyle(Color.unbound.textSecondary)
                        Spacer()
                        if current == value {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.unbound.accent)
                        }
                    }
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if value != Self.rows.last?.0 {
                    Divider().overlay(Color.unbound.borderSubtle)
                }
            }

            Button {
                onPick(nil)
                dismiss()
            } label: {
                Text("Clear")
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
```

- [ ] **Step 2:** `xcodegen generate >/dev/null 2>&1; xcodebuild … build 2>&1 | tail -6`. Build still fails ONLY on the 5 not-yet-migrated UI files from Task 1 — `RPEPickerSheet.swift` itself must contribute NO new errors (token substitution rule: if a token is wrong read `Color+Unbound.swift`/`Font+Unbound.swift`, use the closest real token, report it).

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/RPEPickerSheet.swift
git commit -m "$(printf 'feat(logging): RPEPickerSheet — 6–10 scale with reps-in-reserve meanings\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 3: Rewrite SetLogGridRow — RPE cell + ✓ log (no dot)

**Files:** Rewrite `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift`

- [ ] **Step 1: Overwrite with:**

```swift
import SwiftUI

struct SetLogGridRow: View {
    let setNumber: Int
    let weightKg: Double?
    let reps: Int?
    let rpe: Int?
    let logged: Bool
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onPickRPE: () -> Void
    let onLog: () -> Void

    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(Font.unbound.monoS)
                .foregroundStyle(Color.unbound.textTertiary)
                .frame(width: 20, alignment: .leading)

            cell(text: weightKg.map(Self.fmt) ?? "—", action: onEditWeight)
            cell(text: reps.map(String.init) ?? "—", action: onEditReps)

            // RPE — optional value cell
            Button(action: onPickRPE) {
                Text(rpe.map(String.init) ?? "—")
                    .font(Font.unbound.monoM)
                    .foregroundStyle(rpe == nil ? Color.unbound.textTertiary : Color.unbound.accent)
                    .frame(width: 44)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.unbound.surfaceElevated))
            }
            .buttonStyle(.plain)

            // ✓ — the log control
            Button {
                onLog()
                UnboundHaptics.success()
                if !reduceMotion {
                    pop = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { pop = false }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(logged ? Color.unbound.accent : Color.clear)
                        .overlay(Circle().strokeBorder(
                            logged ? Color.clear : Color.unbound.textTertiary, lineWidth: 1.5))
                        .frame(width: 30, height: 30)
                    if logged {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.unbound.bg)
                    }
                }
                .scaleEffect(pop && !reduceMotion ? 1.18 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pop)
            }
            .buttonStyle(.plain)
            .frame(width: 40)
            .accessibilityLabel(logged ? "Set \(setNumber) logged" : "Log set \(setNumber)")
        }
        .padding(.vertical, 8)
    }

    private func cell(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Font.unbound.monoM)
                .foregroundStyle(text == "—" ? Color.unbound.textTertiary : Color.unbound.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.unbound.surfaceElevated))
        }
        .buttonStyle(.plain)
    }

    private static func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
    }
}
```

- [ ] **Step 2:** build → fewer errors (this file no longer references `Effort`/`onCycleEffort`). Token-substitution rule applies (report any).

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift
git commit -m "$(printf 'feat(logging): SetLogGridRow — RPE value cell + checkmark log (dot removed)\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 4: Update ExerciseLogCard

**Files:** Modify `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift`

- [ ] **Step 1:** Change the closure surface from `onLog`/`onCycleEffort` to `onLog`/`onPickRPE`, pass `rpe: set.rpe` instead of `effort: set.effort`, and update the column header so the columns line up with the new row (`SET`, `WEIGHT`, `REPS`, `RPE`, and a trailing blank/`✓` slot). Read the current file; apply exactly:
  - Property block: add `let onPickRPE: (Int) -> Void`; remove `let onCycleEffort: (Int) -> Void`.
  - Column header `HStack`: `Text("SET").frame(width:20,alignment:.leading)`, `Text("WEIGHT").frame(maxWidth:.infinity)`, `Text("REPS").frame(maxWidth:.infinity)`, `Text("RPE").frame(width:44)`, `Spacer().frame(width:40)` (the ✓ column, unlabeled). Same font/tracking/color as before (`captionS`, `tracking(1.2)`, `textTertiary`).
  - The `ForEach` `SetLogGridRow(...)` call: `setNumber: idx+1, weightKg: set.weightKg, reps: set.reps, rpe: set.rpe, logged: set.logged, onEditWeight:{onEditWeight(idx)}, onEditReps:{onEditReps(idx)}, onPickRPE:{onPickRPE(idx)}, onLog:{onLog(idx)}`.
  - Everything else (name header, ExerciseOverflowMenu, dividers, Add set, card chrome) unchanged.

- [ ] **Step 2:** build → fewer errors. Token rule applies.

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift
git commit -m "$(printf 'feat(logging): ExerciseLogCard — rpe + onPickRPE; RPE column header\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 5: Update WorkoutLogGridView + ActiveWorkoutContainerView (preserve save/reward verbatim)

**Before starting:** READ both files fully. In `ActiveWorkoutContainerView.swift` the `complete()` function, `loadContext()`, the `RewardSummary`/`WorkoutRewardPresentation`/`RewardCelebrationView(...).presentationDetents([.medium,.large]).presentationDragIndicator(.visible)` block, the draft-autosave call sites, and the notes/swap sheet wiring **must remain byte-unchanged**. Only the effort→RPE closure swap changes.

**Files:** Modify `UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift`, `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift`

- [ ] **Step 1: `WorkoutLogGridView.swift`** — rename the closure `let onCycleEffort: (Int, Int) -> Void` to `let onPickRPE: (Int, Int) -> Void`; in the `ExerciseLogCard(...)` call replace `onCycleEffort: { onCycleEffort(ei, $0) }` with `onPickRPE: { onPickRPE(ei, $0) }`. Nothing else changes.

- [ ] **Step 2: `ActiveWorkoutContainerView.swift`:**
  - In the `WorkoutLogGridView(...)` call: the `onLog` closure currently logs via `session.logSet(...)`; keep it logging weight/reps + `draftStore.save` + `startRest(ei:)` but DO NOT set RPE/effort (logging never sets RPE). Replace the `onCycleEffort:` argument with:
    `onPickRPE: { ei, si in rpeTarget = RPETarget(ei: ei, si: si) }`
  - Add state + the sheet (place the `.sheet` alongside the existing editor `.sheet`, do not disturb the notes/swap/reward sheets):

```swift
@State private var rpeTarget: RPETarget?
private struct RPETarget: Identifiable { let id = UUID(); let ei: Int; let si: Int }
```
```swift
.sheet(item: $rpeTarget) { t in
    RPEPickerSheet(
        current: session.exercises.indices.contains(t.ei)
            && session.exercises[t.ei].sets.indices.contains(t.si)
            ? session.exercises[t.ei].sets[t.si].rpe : nil,
        onPick: { v in
            session.setRPE(exerciseIndex: t.ei, setIndex: t.si, v)
            try? draftStore.save(session)
        }
    )
    .presentationDetents([.height(420)])
}
```
  - Remove any remaining reference to `cycleEffort`/`Effort`/`setEffort` in this file (e.g. in `handleIntent` there is none; the only one was the old `onCycleEffort` closure).
  - Verify (read) `complete()`, `loadContext()`, the reward sheet block, draft-autosave, notes/swap sheets are untouched.

- [ ] **Step 3:** `xcodegen generate >/dev/null 2>&1; xcodebuild … build 2>&1 | tail -8` → should now be **`** BUILD SUCCEEDED **`** if Task 6 (RPEOnboardingStep) has not yet migrated this is still red on that one file; otherwise green. Run after Task 6 for a fully green build (Task 5 commits even if the only remaining error is `RPEOnboardingStep.swift`'s `cycleEffort`).

- [ ] **Step 4: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Program/ActiveWorkout/WorkoutLogGridView.swift UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift
git commit -m "$(printf 'feat(logging): wire RPEPickerSheet; onLog no longer sets RPE; save/reward preserved\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 6: Rewrite RPEOnboardingStep — teach the 6–10 scale

**Files:** Rewrite `UNBOUND/Views/Onboarding/RPEOnboardingStep.swift` (do NOT touch `OnboardingContainerView.swift`/`OnboardingFlowViewModel.swift` — the `case rpeTeach` wiring stays).

- [ ] **Step 1: Overwrite with:**

```swift
import SwiftUI

/// Onboarding "try the app" RPE sandbox: a real 3-set Bench Press logged with
/// the production ExerciseLogCard, teaching the real 6–10 RPE scale via the
/// production RPEPickerSheet.
struct RPEOnboardingStep: View {
    let onContinue: () -> Void

    @StateObject private var demo = RPEOnboardingStep.makeDemo()
    @State private var editing: EditCell?
    @State private var rpeTarget: RPETarget?
    @State private var hasLogged = false

    private struct EditCell: Identifiable { let id = UUID(); let si: Int; let isWeight: Bool }
    private struct RPETarget: Identifiable { let id = UUID(); let si: Int }

    private static func makeDemo() -> ActiveWorkoutSession {
        let ex = Exercise(id: "demo-bench", name: "Bench Press",
                          muscleGroups: [], sets: 3, reps: "8",
                          restSeconds: 90, rpe: nil, notes: nil, substitution: nil)
        let w = Workout(name: "Try it", targetMuscleGroups: [], warmup: [],
                        mainExercises: [ex], cooldown: [],
                        estimatedMinutes: 0, notes: nil, blockType: nil)
        let s = ActiveWorkoutSession(workout: w, programId: "onboarding-demo", dayNumber: 0)
        for i in s.exercises[0].sets.indices {
            s.exercises[0].sets[i].weightKg = 60
            s.exercises[0].sets[i].reps = 8
        }
        return s
    }

    private var allLogged: Bool { demo.exercises.first?.sets.allSatisfy(\.logged) ?? false }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("TRY IT — RPE")
                    .font(Font.unbound.captionS).tracking(2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(allLogged
                     ? "That's RPE — how many reps you had left. 10 = none, 8 = ~2, 6 = 4+. We use it to adjust your weights."
                     : "Log these 3 sets (tap the ✓). Then tap RPE and pick how hard it felt — it's how many reps you had left in the tank.")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .animation(.easeInOut(duration: 0.25), value: allLogged)
            }
            .padding(.top, 24)

            if let ex = demo.exercises.first {
                ExerciseLogCard(
                    name: ex.name,
                    isWarmupCurrent: false,
                    sets: ex.sets,
                    onIntent: { _ in },
                    onEditWeight: { si in editing = EditCell(si: si, isWeight: true) },
                    onEditReps:   { si in editing = EditCell(si: si, isWeight: false) },
                    onPickRPE:    { si in rpeTarget = RPETarget(si: si) },
                    onLog: { si in
                        demo.logSet(exerciseIndex: 0, setIndex: si,
                                    weightKg: demo.exercises[0].sets[si].weightKg,
                                    reps: demo.exercises[0].sets[si].reps)
                        hasLogged = true
                    },
                    onAddSet: {}
                )
                .padding(.horizontal, 16)
            }

            Spacer()

            Button(action: onContinue) {
                Text("GOT IT")
                    .font(Font.unbound.bodyLStrong).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
            .opacity(hasLogged ? 1.0 : 0.85)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .sheet(item: $editing) { cell in
            OnboardingSetEditor(
                isWeight: cell.isWeight,
                initial: cell.isWeight
                    ? (demo.exercises[0].sets[cell.si].weightKg ?? 0)
                    : Double(demo.exercises[0].sets[cell.si].reps ?? 0),
                onSave: { v in
                    if cell.isWeight { demo.exercises[0].sets[cell.si].weightKg = v > 0 ? v : nil }
                    else { demo.exercises[0].sets[cell.si].reps = v > 0 ? Int(v) : nil }
                }
            )
            .presentationDetents([.height(260)])
        }
        .sheet(item: $rpeTarget) { t in
            RPEPickerSheet(
                current: demo.exercises[0].sets[t.si].rpe,
                onPick: { v in demo.setRPE(exerciseIndex: 0, setIndex: t.si, v) }
            )
            .presentationDetents([.height(420)])
        }
    }
}

private struct OnboardingSetEditor: View {
    let isWeight: Bool
    let initial: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(isWeight: Bool, initial: Double, onSave: @escaping (Double) -> Void) {
        self.isWeight = isWeight; self.initial = initial; self.onSave = onSave
        _value = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 28) {
            StepperControl(label: isWeight ? "Weight" : "Reps", value: $value,
                           step: isWeight ? 2.5 : 1, unit: isWeight ? "kg" : nil,
                           allowsDecimal: isWeight)
            Button { onSave(value); dismiss() } label: {
                Text("DONE")
                    .font(Font.unbound.bodyLStrong).tracking(2)
                    .foregroundStyle(Color.unbound.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.unbound.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.unbound.bg.ignoresSafeArea())
    }
}
```

- [ ] **Step 2:** `xcodegen generate >/dev/null 2>&1; xcodebuild … build 2>&1 | tail -6` → **`** BUILD SUCCEEDED **`** (all 5 UI files migrated; `Effort` fully gone). Then full suite: `… test … | tail -25` → all green except the known pre-existing backend flap; zero NEW failures (the rewritten `ActiveWorkoutSessionV2Tests` + updated `ActiveWorkoutSessionTests` pass; `EffortRPEMapTests` is gone).

- [ ] **Step 3: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND
git add UNBOUND/Views/Onboarding/RPEOnboardingStep.swift
git commit -m "$(printf 'feat(onboarding): RPE sandbox teaches the real 6–10 scale via RPEPickerSheet\n\nCo-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>')"
```

---

## Task 7: Cluster review + on-device (jlin-driven)

- [ ] **Step 1:** One combined reviewer subagent: verify (a) `ActiveWorkoutSession` `complete()`/`loadContext()`/reward block in `ActiveWorkoutContainerView` byte-unchanged vs pre-Task-5 (diff it); (b) no `Effort`/`EffortRPEMap`/`cycleEffort`/`setEffort` references remain anywhere (`grep -rn`); (c) `RPEPickerSheet` shows 6–10 with the exact reps-in-reserve meanings + Clear; (d) row is `SET·WEIGHT·REPS·RPE·✓`, ✓ logs, RPE optional/clears; (e) onboarding sandbox teaches the scale; (f) full suite green except the pre-existing backend flap, zero new failures. Report APPROVED or concrete fixes; implementer fixes; re-review.
- [ ] **Step 2:** Controller builds + installs to iPhone 17 sim. jlin drives: detail screen → Log Workout → grid; ✓ logs a set; tap RPE → picker shows 6–10 + meanings, pick one / Clear; rest pill; COMPLETE → reward sheet still fires; onboarding RPE sandbox teaches 6–10. jlin signs off the design bar. Fix anything that misses; then sub-project A is done.

---

## Self-Review

**Spec coverage:** revised #2 (row `SET·WEIGHT·REPS·RPE·✓`, ✓ logs, RPE optional tap-to-pick 6–10, `ActiveSet.rpe:Int?`, Effort/EffortRPEMap retired) → Tasks 1,2,3,4,5; revised #3 (reps-vs-target primary, numeric RPE refines via `SetLog.rpe`) → Task 1 (`assembleWorkoutLog` passes `set.rpe` straight to the unchanged ProgressionEngine path); revised #7 (onboarding teaches 6–10 with reps-left) → Task 6; complete()/reward/loadContext byte-unchanged → Task 5 constraint + Task 7 diff-verify; grid/pill/exercise-detail unchanged → not touched. No gaps.

**Placeholder scan:** Task 1 Step 5 deliberately documents an intentionally-red interim build (model migrated before UI) with the exact expected errors enumerated and resolved by Tasks 3–6 — this is a sequenced-migration note, not a vague placeholder; every code step has complete code. Task 4 specifies exact property/header/call changes (the file is small and just-built; full re-paste would duplicate the unchanged chrome — the changes are enumerated precisely with exact arguments). Task 5/6 "READ then apply with these exact changes/code" — concrete, the engineer has the just-built files. No "TBD"/"handle edge cases"/bare "similar to".

**Type consistency:** `ActiveSet.rpe: Int?` and `setRPE(exerciseIndex:setIndex:_:Int?)` used identically Tasks 1/5/6; `SetLogGridRow(setNumber:weightKg:reps:rpe:logged:onEditWeight:onEditReps:onPickRPE:onLog:)` matches its callers in Task 4; `ExerciseLogCard` exposes `onPickRPE:(Int)->Void` consumed by `WorkoutLogGridView`'s `onPickRPE:(Int,Int)->Void` consumed by the container's `RPETarget` sheet → `session.setRPE`; `RPEPickerSheet(current:Int?, onPick:(Int?)->Void)` identical Tasks 2/5/6; `assembleWorkoutLog` emits `SetLog.rpe` (already `Int?`). Tokens are the verified `Color.unbound.*`/`Font.unbound.*`/`UnboundHaptics.*` (warnOrange no longer needed — dot removed).
