# Arc Collapse 3a — Phases Out, Goal In — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the generated program from cycling training phases by day-position (accumulation→intensification→realization→deload inside each 28-day Arc). Make rep ranges, sets, rest, and RPE a fixed function of the user's **training goal** instead — uniform across the Arc.

**Architecture:** This is sub-plan **3a** of the Arc collapse (the time-model spine). The live phase decision is a single pure day-number function — `DeterministicProgramGenerator.blockType(forDayNumber:input:)` (`+Prescription.swift:54-67`) — feeding the `prescription(for blockType:)` switch (`:69-124`) and its bodyweight twin `calisthenicsPrescription` (`:137-218`). We introduce a `TrainingGoal` (derived for now from the existing `BuildIdentity.programTemplateKey`; an explicit user-chosen goal arrives in Plan 5) and re-key those switches to it. The calibration/deload special-case is preserved (a separate concern, removed later with Calibration-Week in Plan 5). `ProgramPhaseEngine` and `PhaseChip` are dead code (never called in the live path per the periodization map) and get deleted.

**Tech Stack:** Swift 5.9 / iOS 17, XCTest, XcodeGen-generated project.

## Global Constraints

- **Build gate:** `set -o pipefail`; `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' build` must print `** BUILD SUCCEEDED **`. Never run two `xcodebuild`s concurrently.
- **New files** require `xcodegen generate` before building (pbxproj is generated/gitignored).
- **Stage explicit paths only** — never `git add -A` (shared worktree).
- **Keep `import` lines** in every edited Swift file.
- **Commit footer (verbatim):** `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Worktree/branch:** `/Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core`, `claude/program-simplest-core`.
- **⚑ Balance decisions need jlin's checkpoint:** the exact goal→rep-range / sets / RPE numbers in Tasks 2–3 are *proposed defaults*. Surface them for his sign-off before treating them as final (per the staged-checkpoint convention) — do not silently tune.
- **Preserve the `.deload` path** (`DeloadPlanner`, `AutoDeloadService`, `PlateauFixService`, `BlockRolloverService:420` depend on `BlockType.deload`). 3a removes phase *cycling*, not the deload concept.

---

### Task 1: `TrainingGoal` type + derivation

**Files:**
- Create: `UNBOUND/Models/Program/TrainingGoal.swift`
- Test: `UNBOUNDTests/Models/TrainingGoalTests.swift`

**Interfaces:**
- Produces: `enum TrainingGoal: String, Codable, Hashable, Sendable { case strength, hypertrophy, skill }` and `static func TrainingGoal.from(programTemplateKey: String) -> TrainingGoal`. Consumed by Tasks 2–3.

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Models/TrainingGoalTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class TrainingGoalTests: XCTestCase {
    func test_derivesFromProgramTemplateKey() {
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "power"), .strength)
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "control"), .skill)
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "endurance"), .hypertrophy)
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "balanced"), .hypertrophy)
    }
    func test_unknownKeyFallsBackToHypertrophy() {
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "anything-else"), .hypertrophy)
    }
}
```

- [ ] **Step 2: Generate + run to verify it fails**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
xcodegen generate
set -o pipefail
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' \
  -only-testing:UNBOUNDTests/TrainingGoalTests test 2>&1 | tail -15
```
Expected: FAIL — `cannot find 'TrainingGoal' in scope`.

- [ ] **Step 3: Create the type**

Create `UNBOUND/Models/Program/TrainingGoal.swift`:

```swift
import Foundation

/// The user's training objective — the single driver of rep ranges / sets / RPE,
/// replacing the per-day BlockType phase cycle. Derived from BuildIdentity's
/// programTemplateKey until Plan 5 makes it an explicit onboarding choice.
enum TrainingGoal: String, Codable, Hashable, Sendable {
    case strength      // get stronger — low reps, heavy
    case hypertrophy   // build muscle — moderate reps
    case skill         // bodyweight skills — rep/hold targets

    static func from(programTemplateKey key: String) -> TrainingGoal {
        switch key {
        case "power":   return .strength
        case "control": return .skill
        default:        return .hypertrophy   // endurance / balanced / unknown
        }
    }
}
```

- [ ] **Step 4: Run the test — expect PASS** (same `-only-testing:UNBOUNDTests/TrainingGoalTests test`). Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
git add UNBOUND/Models/Program/TrainingGoal.swift UNBOUNDTests/Models/TrainingGoalTests.swift UNBOUND.xcodeproj/project.pbxproj
git commit -m "$(printf 'feat(program): TrainingGoal type + derivation from programTemplateKey\n\nThe single driver of rep ranges/sets/RPE that replaces the BlockType phase\ncycle. Derived from BuildIdentity for now; explicit goal arrives in Plan 5.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 2: Goal-driven rep ranges

**Files:**
- Modify: `UNBOUND/Models/Program/ProgressionState.swift` (`ExerciseClassification`, add `defaultRepRange(for goal: TrainingGoal)`)
- Test: `UNBOUNDTests/Models/GoalRepRangeTests.swift` (create)

**Interfaces:**
- Consumes: `TrainingGoal` (Task 1).
- Produces: `func ExerciseClassification.defaultRepRange(for goal: TrainingGoal) -> ClosedRange<Int>`. The existing `defaultRepRange(for block: BlockType)` stays for now (Task 3 stops calling it from generation; later sub-plans remove it).

⚑ **Balance defaults below need jlin's checkpoint.**

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Models/GoalRepRangeTests.swift`:

```swift
import XCTest
@testable import UNBOUND

final class GoalRepRangeTests: XCTestCase {
    func test_strength_isLowRep_forCompounds() {
        XCTAssertEqual(ExerciseClassification.upperCompound.defaultRepRange(for: .strength), 4...6)
        XCTAssertEqual(ExerciseClassification.lowerCompound.defaultRepRange(for: .strength), 4...6)
    }
    func test_hypertrophy_isModerateRep() {
        XCTAssertEqual(ExerciseClassification.upperCompound.defaultRepRange(for: .hypertrophy), 8...12)
        XCTAssertEqual(ExerciseClassification.accessory.defaultRepRange(for: .hypertrophy), 10...15)
    }
    func test_bodyweightRepTrack_variesByGoal() {
        XCTAssertEqual(ExerciseClassification.bodyweightSkill.defaultRepRange(for: .strength), 3...6)
        XCTAssertEqual(ExerciseClassification.bodyweightSkill.defaultRepRange(for: .skill), 5...8)
        XCTAssertEqual(ExerciseClassification.bodyweightSkill.defaultRepRange(for: .hypertrophy), 8...12)
    }
}
```

- [ ] **Step 2: Run to verify it fails** (`-only-testing:UNBOUNDTests/GoalRepRangeTests test`). Expected: FAIL — no `defaultRepRange(for goal:)`.

- [ ] **Step 3: Add the goal-keyed rep range**

In `ProgressionState.swift`, inside `extension ExerciseClassification` (next to the existing `defaultRepRange(for block:)`), add:

```swift
    /// Goal-keyed rep range — the fixed range used across an Arc (replaces the
    /// per-phase `defaultRepRange(for block:)` in generation). ⚑ Balance defaults.
    ///
    /// `bodyweightSkill` here is the REP track only (clean reps before advancing the
    /// variation). The HOLD track (isometrics → seconds) lives in
    /// `calisthenicsPrescription`'s `defaultMetric == .holdSeconds` branch, not here.
    /// For skills, the *scaling* is the skill-tree variation ladder (harder variation
    /// resets the target), not these numbers — these are just the build target.
    func defaultRepRange(for goal: TrainingGoal) -> ClosedRange<Int> {
        switch (self, goal) {
        case (.upperCompound, .strength), (.lowerCompound, .strength): return 4...6
        case (.upperCompound, _),         (.lowerCompound, _):         return 8...12
        case (.accessory, .strength):                                  return 6...10
        case (.accessory, _):                                          return 10...15
        case (.bodyweightSkill, .strength):                            return 3...6
        case (.bodyweightSkill, .skill):                               return 5...8
        case (.bodyweightSkill, .hypertrophy):                         return 8...12
        }
    }
```

- [ ] **Step 4: Run the test — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add UNBOUND/Models/Program/ProgressionState.swift UNBOUNDTests/Models/GoalRepRangeTests.swift
git commit -m "$(printf 'feat(program): goal-keyed default rep ranges\n\ndefaultRepRange(for goal:) — fixed per-Arc ranges driven by TrainingGoal,\nreplacing per-phase ranges in generation (Task 3 re-points callers).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 3: Re-point generation to goal; remove the phase cycle

**Files:**
- Modify: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Prescription.swift` (`blockType(forDayNumber:)`, `prescription`, `calisthenicsPrescription`, `blockProgrammingNote`)
- Modify: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Schedule.swift:56` (stop passing per-day blockType)
- Modify: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift:116,118,146` (thread goal, not blockType)
- Modify: `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift:9-36` (`ProgramGeneratorInput` gains a `goal: TrainingGoal`; derive it from `buildIdentity.programTemplateKey` at the call site, `ProgramGenerationService.swift`)
- Test: `UNBOUNDTests/Services/ProgramGeneration/GoalDrivenPrescriptionTests.swift` (create)

**Interfaces:**
- Consumes: `TrainingGoal` (Task 1), `defaultRepRange(for goal:)` (Task 2).
- Produces: `prescription(for goal: TrainingGoal, isCalibrationWeek: Bool, state:isPrimary:fallbackRPE:definition:input:)` and the matching `calisthenicsPrescription(for goal:...)`. `ProgramGeneratorInput.goal: TrainingGoal`.

⚑ **The goal→sets/reps/rest/RPE table below needs jlin's checkpoint.**

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Services/ProgramGeneration/GoalDrivenPrescriptionTests.swift`. It asserts the *uniformity* the collapse guarantees — the prescription no longer depends on day-position, only on goal:

```swift
import XCTest
@testable import UNBOUND

final class GoalDrivenPrescriptionTests: XCTestCase {
    func test_strengthGoal_givesLowRepPrimary_regardlessOfDay() {
        let rx = DeterministicProgramGenerator.prescription(
            for: .strength, isCalibrationWeek: false, state: nil,
            isPrimary: true, fallbackRPE: 8,
            definition: MovementCatalog.canonicalExercise(named: "bench press")!,
            input: .stubbed(goal: .strength))
        XCTAssertEqual(rx.reps, "4-6")
        XCTAssertEqual(rx.rpe, 0, "prescriptions no longer carry an RPE target")
    }
    func test_hypertrophyGoal_givesModerateRepPrimary() {
        let rx = DeterministicProgramGenerator.prescription(
            for: .hypertrophy, isCalibrationWeek: false, state: nil,
            isPrimary: true, fallbackRPE: 7,
            definition: MovementCatalog.canonicalExercise(named: "bench press")!,
            input: .stubbed(goal: .hypertrophy))
        XCTAssertEqual(rx.reps, "8-12")
    }
    func test_calibrationWeek_stillDeloads() {
        let rx = DeterministicProgramGenerator.prescription(
            for: .hypertrophy, isCalibrationWeek: true, state: nil,
            isPrimary: true, fallbackRPE: 7,
            definition: MovementCatalog.canonicalExercise(named: "bench press")!,
            input: .stubbed(goal: .hypertrophy))
        XCTAssertEqual(rx.reps, "8 easy")
        XCTAssertEqual(rx.rpe, 0)
    }
}
```

> Note: `ProgramGeneratorInput.stubbed(goal:)` — if no test stub factory exists, add a minimal one in the test file's scope mirroring the existing generator tests' fixtures (see `DeterministicProgramGeneratorTests.swift` for the established way to build a `ProgramGeneratorInput`). Reuse that pattern; do not invent new required fields.

- [ ] **Step 2: Run to verify it fails** (`-only-testing:UNBOUNDTests/GoalDrivenPrescriptionTests test`). Expected: FAIL — `prescription(for:)` has no `goal:`/`isCalibrationWeek:` signature.

- [ ] **Step 3: Rewrite `prescription` to switch on goal**

Replace `prescription(for blockType:...)` (`+Prescription.swift:69-124`) with:

```swift
    static func prescription(
        for goal: TrainingGoal,
        isCalibrationWeek: Bool,
        state: ProgressionState?,
        isPrimary: Bool,
        fallbackRPE: Int,
        definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> GeneratedPrescription {
        if usesCalisthenicsPrescription(definition: definition, input: input) {
            return calisthenicsPrescription(
                for: goal, isCalibrationWeek: isCalibrationWeek,
                state: state, isPrimary: isPrimary, fallbackRPE: fallbackRPE, definition: definition)
        }

        if isCalibrationWeek {
            return (sets: 2, reps: "8 easy", restSeconds: 60, rpe: 0,
                    note: "Calibration. Move well and keep reps easy.")
        }

        let classification = ExerciseClassification.classify(exerciseKey: definition.displayName)
        let range = state.map { $0.targetRepMin...$0.targetRepMax }
            ?? classification.defaultRepRange(for: goal)
        let reps = "\(range.lowerBound)-\(range.upperBound)"

        // rpe: 0 → `toExercise` nils it → no RPE shown anywhere. Fully RPE-free:
        // effort lives in the rep range + the note. (`targetRPE` retires in 3d.)
        switch goal {
        case .strength:
            return (sets: isPrimary ? 4 : 3, reps: reps,
                    restSeconds: isPrimary ? 180 : 90, rpe: 0,
                    note: "Strength. Heavy, clean reps — leave ~1 in reserve; add weight when the top of the range feels solid.")
        case .hypertrophy:
            return (sets: isPrimary ? 4 : 3, reps: reps,
                    restSeconds: isPrimary ? 120 : 75, rpe: 0,
                    note: "Build. Push near the top of the rep range (~1–2 in reserve), then add weight.")
        case .skill:
            return (sets: isPrimary ? 4 : 3, reps: reps,
                    restSeconds: isPrimary ? 120 : 75, rpe: 0,
                    note: "Quality reps. Stop before form breaks; progress the variation before load.")
        }
    }
```

- [ ] **Step 4: Rewrite `calisthenicsPrescription` to switch on goal — keep BOTH tracks**

Bodyweight has two tracks and BOTH must survive (this is the correction from the skill-range review):

1. **Hold track** — `definition.defaultMetric == .holdSeconds || .durationSeconds` (`+Prescription.swift:144`). Keep it as a *seconds* prescription. Phases scaled the hold down (15-25s → 8-15s); with phases gone, use a single build target — `"15-25s"` (⚑ balance) — and let the **skill tree** make the *variation* harder. A hold target does not vary by goal.
2. **Rep track** — the `else` branch (`:181`). Keep it as *clean reps*; source the range from `state.targetRepMin/Max` else `ExerciseClassification.bodyweightSkill.defaultRepRange(for: goal)` (Task 2: strength 3-6 / skill 5-8 / build 8-12 "clean").

Change the signature to `(for goal: TrainingGoal, isCalibrationWeek: Bool, state:isPrimary:fallbackRPE:definition:)`, add the `if isCalibrationWeek { … easy }` guard at the top of *each* track, and replace both `switch blockType` blocks with the single goal-driven target above. The **scaling for skills is the skill-tree variation ladder** (`bodyweightSkill` → tier unlock, already in `ProgressionEngine`), NOT a phase cycle — so the per-Arc target is fixed and correct. Preserve all existing `RankTemplate` / `defaultMetric` handling verbatim — only the phase switch is removed. Both tracks return `rpe: 0` (RPE-free) — intensity is the rep/hold target + the note, nothing more.

- [ ] **Step 5: Collapse `blockType(forDayNumber:)` and re-thread callers**

- Delete `blockType(forDayNumber:input:)` (`+Prescription.swift:54-67`).
- In `+Schedule.swift:56`, stop computing/ passing a per-day `blockType`; instead pass `input.goal` and `isCalibrationWeek: input.calibration.requiresLearningWeek` into `buildWorkout`.
- In `+WorkoutBuilder.swift` (`:4-9` signature, `:116` `cooldownExercises`, `:118` `toExercise`, `:146` `Workout(...)`), replace the `blockType:` parameter with `goal: TrainingGoal` (+ `isCalibrationWeek: Bool`). `Workout.blockType` (`Workout.swift:11`): set it to `isCalibrationWeek ? .deload : .accumulation` for now (its only real consumer is `ProgramDayPreviewResolver.swift:23`, which just copies it; full removal is sub-plan 3d).
- Update `blockProgrammingNote(for blockType:)` (`+Prescription.swift:220-233`) → `blockProgrammingNote(for goal:)` returning the goal's note, or fold it into the prescription notes above and delete it if it has no other caller (grep first).

- [ ] **Step 6: Add `goal` to `ProgramGeneratorInput` + derive at the call site**

- `DeterministicProgramGenerator.swift:9-36`: add `let goal: TrainingGoal` to `ProgramGeneratorInput`.
- `ProgramGenerationService.swift` (where `ProgramGeneratorInput(...)` is constructed, ~`:22/:105`): set `goal: TrainingGoal.from(programTemplateKey: buildIdentity.programTemplateKey)`.
- Fix every other `ProgramGeneratorInput(...)` constructor the compiler flags (tests, mocks, `DevBuildBootstrapper`) — pass an explicit `goal:` (default `.hypertrophy` in fixtures).

- [ ] **Step 7: Build + run the new tests + the existing generator suite**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
set -o pipefail
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' build 2>&1 | tail -3
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' \
  -only-testing:UNBOUNDTests/GoalDrivenPrescriptionTests \
  -only-testing:UNBOUNDTests/DeterministicProgramGeneratorTests test 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **` then `** TEST SUCCEEDED **`. Any existing generator test that asserted phase-specific reps-by-day must be updated to the goal-uniform expectation (note the change in the commit body).

- [ ] **Step 8: Commit**

```bash
git add UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Prescription.swift \
        UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+Schedule.swift \
        UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator+WorkoutBuilder.swift \
        UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift \
        UNBOUND/Services/ProgramGeneration/ProgramGenerationService.swift \
        UNBOUNDTests/Services/ProgramGeneration/GoalDrivenPrescriptionTests.swift
# plus any fixture/mock files the compiler required
git commit -m "$(printf 'feat(program): prescriptions driven by TrainingGoal, not the day-phase cycle\n\nGenerated programs no longer cycle accumulation/intensification/realization by\nday-position. Rep ranges/sets/rest/RPE come from the user goal (derived from\nbuildIdentity for now), uniform across the Arc. Calibration-week deload preserved.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 4: Delete the dead phase engine

**Files:**
- Delete: `UNBOUND/Services/ProgramGeneration/ProgramPhaseEngine.swift`, `UNBOUND/Views/.../PhaseChip.swift`
- Modify: `UNBOUND/App/ServiceContainer.swift` (remove `programPhase` wiring at `:29,68,107,134,174`)

**Interfaces:** none — pure dead-code removal (the map confirmed `currentPhase(` has zero call sites and `PhaseChip` is only used in its own `#Preview`).

- [ ] **Step 1: Confirm dead before deleting**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
grep -rn "currentPhase(\|ProgramPhaseEngine\|PhaseChip\|programPhase\|ProgramPhase\b" UNBOUND --include='*.swift' | grep -v "ProgramPhaseEngine.swift\|PhaseChip.swift"
```
Expected: only `ServiceContainer.swift` references remain (the wiring to remove). If anything else appears, STOP — it's not dead; surface it.

- [ ] **Step 2: Delete the files + wiring**

Remove the two files; delete the `programPhase` property + its assignments/protocol references in `ServiceContainer.swift` (lines ~29, 68, 107, 134, 174). Remove `MockProgramPhaseEngine`/`ProgramPhaseEngineProtocol`/`ProgramPhase` if they lived in those files.

- [ ] **Step 3: Regenerate + build**

```bash
xcodegen generate
set -o pipefail
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -u UNBOUND/Services/ProgramGeneration UNBOUND/App/ServiceContainer.swift UNBOUND.xcodeproj/project.pbxproj
git add UNBOUND   # picks up the PhaseChip deletion path
git commit -m "$(printf 'refactor(program): delete dead ProgramPhaseEngine + PhaseChip\n\nNever called in the live path (phase was decided by blockType(forDayNumber:),\nnow removed in 3a). Removes the legacy evergreen phase picker + its dead chip UI.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

> `git add -u` here is scoped to explicit dirs/files (not repo-wide) so it only stages the deletions under those paths — safe on the shared tree.

---

## After 3a — the rest of the Arc collapse

- **3b — Drop Wave:** delete `WaveAdjuster` + `Wave` enum + `Arc.wave*Range`/`currentWave` + `ProgramViewModel` wave methods (~10 sites) + `ProgramWaveAdjustment*` views + `WaveAdjustmentStore`. Self-contained view-time overlay; no generation/load impact.
- **3c — One renewal:** simplify `RolloverCoordinator` to a single 28-day boundary (drop scan-at-boundary + grace window); pick ONE next-Arc generator (`BlockRolloverService.performRollover` vs `ArcGenerator.generateNextArc`) and retire the other.
- **3d — Slim the model:** collapse `BlockType` to a deload flag, drop `weekInBlock` (only `DeloadPlanner` reads it), drop `ArcState.checkpointDue` if Checkpoint goes, remove the now-unused `defaultRepRange(for block:)`, remove the now-always-`0` `rpe` from `GeneratedPrescription` + the `toExercise` rpe line, and delete the dead `ProgressionState.targetRPE` / `BlockType.targetRPE`.

## Self-Review

- **Spec coverage:** implements the corrected spec — Arc is the single unit; rep ranges come from the goal, not the phase; loads stay with `ProgressionEngine`; calibration/deload preserved for now.
- **No placeholders:** new pure code (Tasks 1–2) is shown in full; the integration (Task 3) shows the rewritten `prescription` and names every caller + line to re-thread; Task 4 is gated on a dead-code grep.
- **Type consistency:** `TrainingGoal` (Task 1) → `defaultRepRange(for goal:)` (Task 2) → `prescription(for goal:isCalibrationWeek:)` + `ProgramGeneratorInput.goal` (Task 3). `GeneratedPrescription` tuple shape (`sets/reps/restSeconds/rpe/note`) preserved verbatim.
- **Risk:** Task 3 touches the core generator; Step 7's build + existing-suite run is the gate. The goal→numbers tables (Tasks 2–3) are flagged ⚑ for jlin's balance checkpoint before they're final.
