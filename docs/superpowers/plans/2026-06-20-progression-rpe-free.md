# Progression RPE-Free (Pure Double Progression) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing `ProgressionEngine` advance on reps alone — drop the RPE gate that no longer has input now that RPE is removed from the logger — so double progression keeps working.

**Architecture:** This is Plan 1 of the simplest-core roadmap. It does **not** build a progression engine — one already exists (`Services/Progression/ProgressionEngine.swift`, live via `TrainingCompletionService.swift:572`). It surgically removes the RPE-based advance gate so the criterion is purely "hit the top of the rep range for 2 consecutive sessions." This fixes a latent bug: with RPE no longer logged, `isCleanRPEHit(nil, targetRPE>0)` returns `false`, so the engine would never bump. Pure rep-based progression is the spec's accepted model (RPE removed; auto-deload + plateau detection remain the safety net).

**Tech Stack:** Swift 5.9 / iOS 17, SwiftUI, XCTest, XcodeGen-generated project.

## Global Constraints

- **Build gate:** `set -o pipefail`; build with `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' build` and confirm `** BUILD SUCCEEDED **`. Never run two `xcodebuild`s concurrently (build-DB lock).
- **No new files in the Xcode target without `xcodegen generate`** (pbxproj is gitignored + generated). After creating the new test file, run `xcodegen generate` before building.
- **Shared worktree git hygiene:** stage explicit paths only — never `git add -A`.
- **Keep `import` lines** when editing Swift files (do not drop `import Foundation`).
- **Commit message footer (verbatim):**
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Worktree:** this plan executes in `/Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core` on branch `claude/program-simplest-core` (already created off `origin/main`).
- **Do not touch** `ProgressionState.targetRPE` the stored field, nor its other consumers (`DeterministicProgramGenerator+Progression`, `TrainingPrescriptionResolver`) — the field becomes inert in the engine here; its full removal belongs to the later phase-collapse plan.

---

### Task 1: Pure rep-based advance check

**Files:**
- Modify: `UNBOUND/Services/Progression/ProgressionEngine.swift` (add a `static func`)
- Test: `UNBOUNDTests/Services/Progression/ProgressionEngineRepProgressionTests.swift` (create)

**Interfaces:**
- Produces: `static func ProgressionEngine.sessionHitsTarget(bestSetReps: Int, targetRepMax: Int) -> Bool` — the rep-only advance predicate consumed by Task 2's `evaluate`.

- [ ] **Step 1: Write the failing test**

Create `UNBOUNDTests/Services/Progression/ProgressionEngineRepProgressionTests.swift`:

```swift
import XCTest
@testable import UNBOUND

@MainActor
final class ProgressionEngineRepProgressionTests: XCTestCase {

    func test_hitsTarget_atOrAboveTopOfRange_regardlessOfRPE() {
        // Top of range reached → hit, with no RPE involved at all.
        XCTAssertTrue(ProgressionEngine.sessionHitsTarget(bestSetReps: 12, targetRepMax: 12))
        XCTAssertTrue(ProgressionEngine.sessionHitsTarget(bestSetReps: 15, targetRepMax: 12))
    }

    func test_doesNotHitTarget_belowTopOfRange() {
        XCTAssertFalse(ProgressionEngine.sessionHitsTarget(bestSetReps: 11, targetRepMax: 12))
        XCTAssertFalse(ProgressionEngine.sessionHitsTarget(bestSetReps: 0, targetRepMax: 8))
    }
}
```

- [ ] **Step 2: Generate project + run test to verify it fails**

Run:
```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
xcodegen generate
set -o pipefail
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' \
  -only-testing:UNBOUNDTests/ProgressionEngineRepProgressionTests test 2>&1 | tail -20
```
Expected: FAIL — compile error, `type 'ProgressionEngine' has no member 'sessionHitsTarget'`.

- [ ] **Step 3: Add the pure predicate**

In `ProgressionEngine.swift`, add inside the `ProgressionEngine` class (e.g. just above `isCleanRPEHit`):

```swift
/// Pure, rep-based advance check. RPE is no longer logged, so a session
/// "hits target" when its best working set reaches the top of the rep range.
static func sessionHitsTarget(bestSetReps: Int, targetRepMax: Int) -> Bool {
    bestSetReps >= targetRepMax
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `-only-testing:UNBOUNDTests/ProgressionEngineRepProgressionTests test` command.
Expected: `** TEST SUCCEEDED **`, 2 tests passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
git add UNBOUND/Services/Progression/ProgressionEngine.swift \
        UNBOUNDTests/Services/Progression/ProgressionEngineRepProgressionTests.swift
git commit -m "$(printf 'test(progression): pure rep-based advance predicate\n\nsessionHitsTarget(bestSetReps:targetRepMax:) — the RPE-free advance check\nthat Task 2 wires into evaluate.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 2: Rewire `evaluate` to rep-only; delete the RPE gate

**Files:**
- Modify: `UNBOUND/Services/Progression/ProgressionEngine.swift` (`evaluate`, `bestSet` selection, top-of-file doc comment; delete `isCleanRPEHit` + `isGrindyRPE`)

**Interfaces:**
- Consumes: `ProgressionEngine.sessionHitsTarget(bestSetReps:targetRepMax:)` from Task 1.

- [ ] **Step 1: Replace the RPE-gated advance block**

In `evaluate(...)`, find:

```swift
        let hitTopOfRange = bestSet.reps >= state.targetRepMax
        let hitTargetRPE = isCleanRPEHit(bestSet.rpe, targetRPE: state.targetRPE)
        let wasGrindy = isGrindyRPE(bestSet.rpe, targetRPE: state.targetRPE)

        var next = state
        next.updatedAt = loggedAt
        next.lastSessionReps = bestSet.reps
        next.lastSessionRPE = bestSet.rpe
        next.lastSessionHitTarget = hitTopOfRange && hitTargetRPE
        next.lastSessionWasGrindy = wasGrindy

        if hitTopOfRange && hitTargetRPE {
            next.consecutiveSessionsAtTarget += 1
            next.underTargetSessionCount = 0
            next.prescriptionBias = .hold
        } else {
            next.consecutiveSessionsAtTarget = 0
            let misses = (state.underTargetSessionCount ?? 0) + 1
            next.underTargetSessionCount = misses
            next.prescriptionBias = wasGrindy || misses >= 2 ? .easier : .hold
        }
```

Replace with (rep-only; RPE removed):

```swift
        let hitTarget = Self.sessionHitsTarget(bestSetReps: bestSet.reps, targetRepMax: state.targetRepMax)

        var next = state
        next.updatedAt = loggedAt
        next.lastSessionReps = bestSet.reps
        next.lastSessionRPE = nil          // RPE is no longer logged
        next.lastSessionHitTarget = hitTarget
        next.lastSessionWasGrindy = false  // no RPE → no grind signal

        if hitTarget {
            next.consecutiveSessionsAtTarget += 1
            next.underTargetSessionCount = 0
            next.prescriptionBias = .hold
        } else {
            next.consecutiveSessionsAtTarget = 0
            let misses = (state.underTargetSessionCount ?? 0) + 1
            next.underTargetSessionCount = misses
            next.prescriptionBias = misses >= 2 ? .easier : .hold
        }
```

- [ ] **Step 2: Simplify `bestSet` selection (drop the inert RPE tiebreak)**

Find:

```swift
        let bestSet = workingSets.max { a, b in
            // Primary: reps; tiebreak: RPE; tiebreak: weight
            if a.reps != b.reps { return a.reps < b.reps }
            if (a.rpe ?? 0) != (b.rpe ?? 0) { return (a.rpe ?? 0) < (b.rpe ?? 0) }
            return (a.weightKg ?? 0) < (b.weightKg ?? 0)
        } ?? workingSets[0]
```

Replace with:

```swift
        let bestSet = workingSets.max { a, b in
            // Primary: reps; tiebreak: weight (RPE no longer logged)
            if a.reps != b.reps { return a.reps < b.reps }
            return (a.weightKg ?? 0) < (b.weightKg ?? 0)
        } ?? workingSets[0]
```

- [ ] **Step 3: Delete the now-unused RPE helpers**

Delete these two methods entirely from `ProgressionEngine`:

```swift
    private func isCleanRPEHit(_ rpe: Int?, targetRPE: Int) -> Bool {
        guard targetRPE > 0 else { return true }
        guard let rpe else { return false }
        return rpe <= targetRPE
    }

    private func isGrindyRPE(_ rpe: Int?, targetRPE: Int) -> Bool {
        guard let rpe else { return false }
        guard targetRPE > 0 else { return rpe >= 9 }
        return rpe >= targetRPE + 2 || (rpe >= 9 && rpe > targetRPE)
    }
```

- [ ] **Step 4: Correct the top-of-file doc comment**

In the `// MARK: - ProgressionEngine` comment block, replace the bullet:

```
//   • Target RPE is set by the current block
//     - Accumulation: 7
//     - Intensification: 8
//     - Realization: 9
//     - Deload: 6
//   • Add weight when the athlete hits the TOP of the rep range at target
//     RPE for 2 consecutive sessions of the same exercise.
```

with:

```
//   • Pure double progression: add weight when the athlete hits the TOP of
//     the rep range for 2 consecutive sessions of the same exercise. RPE is
//     no longer logged, so it plays no part in the advance decision —
//     AutoDeloadService + PlateauDetector are the safety net for too-heavy loads.
```

- [ ] **Step 5: Build + run the progression tests**

Run:
```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
set -o pipefail
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **` (confirms `isCleanRPEHit`/`isGrindyRPE` had no other callers).

Then run any existing progression tests plus the new one:
```bash
xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,id=810087B3-226D-4398-8ABD-9FF61E642E1D' \
  -only-testing:UNBOUNDTests/ProgressionEngineRepProgressionTests test 2>&1 | tail -10
```
Expected: `** TEST SUCCEEDED **`.

If any existing progression-engine integration test encodes the old RPE-gated behavior (asserts a grindy set does NOT advance, or that a clean RPE is required to bump), update that test's expectation to the rep-only rule and note the change in the commit body.

- [ ] **Step 6: Commit**

```bash
cd /Users/jlin/Documents/toji/UNBOUND/.claude/worktrees/program-simplest-core
git add UNBOUND/Services/Progression/ProgressionEngine.swift
git commit -m "$(printf 'feat(progression): advance on reps alone, drop the RPE gate\n\nRPE was removed from the logger UI, so the engine no longer receives it;\nthe RPE gate (isCleanRPEHit/isGrindyRPE) would have blocked every bump.\nAdvance criterion is now top-of-rep-range for 2 consecutive sessions.\nAuto-deload + plateau detection remain the too-heavy safety net.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Roadmap (later plans — not in this plan)

1. **(this plan)** Progression RPE-free.
2. **Forward-looking cue** on the set row (`▲ +2.5kg` / `chase reps` / `+2 reps`), read-only from `ProgressionState` — pairs with the shipped PREV column. (Depends on the column being merged to `main`.)
3. **Time-model collapse** — `Arc` absorbs `Wave`/`Phase`/the 2-week `ProgramBlock` rollover (Arc is the surviving on-theme unit); removes `ProgressionState.blockType`/`targetRPE` phase coupling and phase-driven rep ranges.
4. **One-tap arc check-in** renewal (pure manual signal; no RPE pre-fill).
5. **Goal-in/program-out onboarding** + delete the hidden biasers (`WeakPointBiaser`, `RegionFatigueBudget`, `AccessoryBiasRefreshRule`, `LoadBiasApplier`).
6. **Migration** — regenerate into the arc model on next open.

## Self-Review

- **Spec coverage:** Implements the corrected spec §3 (pure rep-based double progression, RPE removed, keep the existing engine). The cue (§ "the legible part") is deferred to Plan 2 by design.
- **No placeholders:** every step has exact code/commands.
- **Type consistency:** `sessionHitsTarget(bestSetReps:targetRepMax:)` is defined in Task 1 and consumed verbatim in Task 2. `lastSessionRPE`, `lastSessionWasGrindy`, `prescriptionBias`, `consecutiveSessionsAtTarget`, `underTargetSessionCount` all exist on `ProgressionState` (verified). No new types introduced.
- **Risk:** removing `isCleanRPEHit`/`isGrindyRPE` — Step 5's build confirms no other callers; if the build fails on a missing reference, that caller must also move to the rep-only signal (surface it, don't stub).
