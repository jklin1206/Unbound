# Agent C — Skill Blocks + Proof / Reward Phase Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`. Read the canonical spec first: [`2026-05-24-program-canvas-monthly-arc.md`](2026-05-24-program-canvas-monthly-arc.md). All 12 locked decisions there are binding.

**Goal:** Make skill blocks first-class members of every workout. Run the proof engine on every logged session forever. Support retroactive prerequisite clearing via explicit per-prereq metadata. Ship the sequential-beat reward UX for multi-rank-up moments.

**Architecture:** Skills become a `ProgramBlock` variant (no more disconnected "fantasy layer"). Proof engine runs on every `WorkoutLog` regardless of source (generated, edited, Saved, custom, skill practice, vow, retest). Prereqs gain explicit family metadata so "higher proof" only clears compatibly-typed lower prereqs. The reward screen renders a sequential-beat animation that collapses into a tally.

**Tech stack:** SwiftUI animation, XCTest. No new dependencies.

---

## Scope

In:
- Skill block as first-class `ProgramBlock` variant
- Skill block routing — primer / main / accessory / mobility
- Region-load tagging on every skill block (feeds Agent A's `RegionFatigueBudget`)
- Proof engine on every logged workout
- Retroactive prereq clearing with family metadata
- Reward payload generation (multi-rank tally)
- End-of-workout reward screen — sequential beat → summary card
- Reward screen actions: Add next standard / Keep program / View Skill Tree

Out:
- Wave 2 / region budget rules (Agent A — Agent C tags loads; Agent A enforces budget)
- Editor UX (Agent B)
- Checkpoint scan plumbing (Agent D)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Models/ProgramBlock.swift` | Modify | Add `.skill(SkillBlockKind, SkillID, RegionLoad)` case |
| `UNBOUND/Models/SkillBlockKind.swift` | Create | enum: `primer`, `main`, `accessory`, `mobility` |
| `UNBOUND/Models/SkillUnlockStandards.swift` | Modify | Add `directProofFamily`, `proofFamilyCovered`, `autoClearFromHigherProof`, `safetyRequired` to each prereq |
| `UNBOUND/Models/ProofFamily.swift` | Create | enum: `reps`, `hold`, `mobility`, `form`, `eccentric`, `loaded`, `unilateral`, `tempo` |
| `UNBOUND/Models/WorkoutRewardSequence.swift` | Modify | Add sequential-beat metadata: `beats: [RewardBeat]`, `tally: RewardTally`, `emblemIgnition: Bool` |
| `UNBOUND/Models/RewardBeat.swift` | Create | One per cleared standard or unlock |
| `UNBOUND/Services/SkillProgress/SkillBlockRouter.swift` | Create | Inserts skill blocks into workouts at the correct slot (primer→main→accessory→mobility) |
| `UNBOUND/Services/SkillProgress/SkillBlockRegionTagger.swift` | Create | Maps each skill block to a `RegionLoad` for Agent A |
| `UNBOUND/Services/Ranking/ProofEngine.swift` | Create or extend | Runs on every `WorkoutLog`; emits cleared standards, unlocks, multi-rank events |
| `UNBOUND/Services/Ranking/PrereqClearer.swift` | Create | Family-aware retroactive clearing |
| `UNBOUND/Services/Rewards/RewardPayloadBuilder.swift` | Create or extend | Bundles cleared standards into a sequential-beat sequence + tally |
| `UNBOUND/Views/Program/WorkoutLogSummaryView.swift` | Modify | Render `WorkoutRewardSequence` with sequential-beat animation + summary card |
| `UNBOUND/UNBOUNDTests/SkillBlockRouterTests.swift` | Create | Block lands in the right slot regardless of base session structure |
| `UNBOUND/UNBOUNDTests/SkillBlockRegionTaggerTests.swift` | Create | Pull skill → pull region load only; multi-region skills tagged correctly |
| `UNBOUND/UNBOUNDTests/ProofEngineTests.swift` | Create | Every input source triggers proof; multi-rank emitted correctly |
| `UNBOUND/UNBOUNDTests/PrereqClearerTests.swift` | Create | Family-aware clearing — strict pull-ups don't clear dead hang |
| `UNBOUND/UNBOUNDTests/RewardPayloadBuilderTests.swift` | Create | Single, double, six-standard payloads produce correct beat lists + tally |
| `UNBOUND/UNBOUNDUITests/RewardScreenTests.swift` | Create | Visual smoke: sequential beats render, collapse to summary, no per-standard popups |

---

## Tasks

### Task C1 — `ProofFamily` + prereq metadata

**Files:** Create `ProofFamily.swift`. Modify `SkillUnlockStandards.swift` (and any companion data files / JSON seed for the skill tree).

**Acceptance**
- `ProofFamily` is exhaustive enough for the existing tree: `reps`, `hold`, `mobility`, `form`, `eccentric`, `loaded`, `unilateral`, `tempo`. Extensible with `case other(String)`.
- Every existing prereq gains:
  - `directProofFamily: ProofFamily`
  - `proofFamilyCovered: Set<ProofFamily>` — defaults to `[directProofFamily]`
  - `autoClearFromHigherProof: Bool` — `true` only for rep / loaded / eccentric prereqs in the same exercise line; `false` for `hold`, `mobility`, `form`, `tempo`
  - `safetyRequired: Bool` — defaults `false`; locks auto-clear when `true`
- Seed data backfill: a one-pass migration tags every prereq with sensible defaults; flag any prereq where the default is uncertain in a separate review list.

**Test (`PrereqMetadataMigrationTests.swift`):** every prereq in the seed has all four fields; no prereq has `autoClearFromHigherProof == true` AND `safetyRequired == true`.

**Commit:** `feat(skills): ProofFamily + per-prereq clearing metadata`

### Task C2 — `PrereqClearer`

**File:** Create `PrereqClearer.swift`.

**Acceptance**
- Given a `WorkoutLog` containing achieved proof (e.g., 12 strict pull-ups, rep-family), `PrereqClearer` returns the set of prereqs that should auto-clear.
- A prereq auto-clears only if all are true:
  1. `autoClearFromHigherProof == true`
  2. `safetyRequired == false`
  3. The achieved proof's `directProofFamily` ∈ `prereq.proofFamilyCovered`
  4. The achieved proof's magnitude ≥ the prereq's threshold
- Cross-family attempts never clear (12 strict pull-ups do not clear `Dead Hang 30s`).

**Test (`PrereqClearerTests.swift`):**
- 12 strict pull-ups → clears `Pull-Up x3, x5, x8, x10`; does NOT clear `Dead Hang 30s`; does NOT clear `Pull-Up Mobility Drill`.
- A `safetyRequired: true` prereq is never cleared retroactively.
- A `loaded` proof clears lower `loaded` prereqs but not `tempo` prereqs.

**Commit:** `feat(skills): family-aware retroactive prereq clearing`

### Task C3 — `ProofEngine`

**File:** Create or extend `ProofEngine.swift`.

**Acceptance**
- Runs on every `WorkoutLog` regardless of source: generated, edited, Saved Workout, custom workout, skill practice, vow, retest, imported.
- Emits:
  - `standardsCleared: [SkillStandard]` (direct proof)
  - `prereqsCleared: [SkillPrereq]` (via `PrereqClearer`)
  - `unlocks: [SkillUnlock]` (newly unlocked skills)
  - `multiRankEvent: RankAdvancement?` (multiple ranks advanced in a single log)
  - `newBests: [PersonalBest]`
- Idempotent: re-running on the same log yields the same outputs; no double-grant of unlocks.

**Test (`ProofEngineTests.swift`):**
- Each input source triggers proof.
- Multi-rank emitted when a single log clears standards across multiple ranks.
- Re-running on the same log yields zero new unlocks.
- A log that clears 6 standards emits one `RewardPayload` with 6 beats (verified by Task C5).

**Commit:** `feat(skills): ProofEngine — runs on every logged workout`

### Task C4 — `SkillBlockRouter` + `SkillBlockRegionTagger`

**Files:** Modify `ProgramBlock.swift` (add `.skill` case). Create `SkillBlockKind.swift`. Create `SkillBlockRouter.swift`. Create `SkillBlockRegionTagger.swift`.

**Acceptance**
- A `.skill` block carries `kind: SkillBlockKind`, `skillID`, `regionLoad: RegionLoad`.
- `SkillBlockRouter.insert(_:into:)` places the block in the right slot:
  - `primer` → before main lifts (warmup-adjacent)
  - `main` → first block after warmup
  - `accessory` → after main lifts
  - `mobility` → after working sets or as a standalone light day
- `SkillBlockRegionTagger.regionLoad(for:)` maps each skill to its primary + secondary regions (e.g., Strict Pull-Up → `{pull: 1.0, core: 0.3}`).
- Region loads are surfaced to Agent A's `RegionFatigueBudget` via a published feed.

**Test (`SkillBlockRouterTests.swift`):**
- Primer always lands before main work.
- Multiple skills of different kinds in the same workout land in the correct relative order.
- Inserting into an empty session creates a minimal scaffold.

**Test (`SkillBlockRegionTaggerTests.swift`):**
- Known skill → expected region map.
- Multi-region skill (e.g., Muscle-Up → pull + shoulders + core) tagged correctly.

**Commit:** `feat(skills): skill blocks as first-class ProgramBlock + region tagging`

### Task C5 — `RewardPayloadBuilder` + sequential-beat metadata

**Files:** Create `RewardPayloadBuilder.swift`. Modify `WorkoutRewardSequence.swift`. Create `RewardBeat.swift`.

**Acceptance**
- Input: `ProofEngine` output for a single log.
- Output: `WorkoutRewardSequence` with:
  - `beats: [RewardBeat]` — one per cleared standard, ordered (lowest rank first → highest rank last so the final beat is the biggest)
  - `tally: RewardTally { standardsCleared: Int, unlocksGained: Int, ranksAdvanced: Int, attributesGained: [Attribute: Int], newBests: Int }`
  - `emblemIgnition: Bool` — `true` when rank advanced or first-time unlock
- Bundles ALL cleared standards into ONE sequence (never a stack of popups).
- For zero-reward logs, `beats == []` and the summary card is suppressed entirely.

**Test (`RewardPayloadBuilderTests.swift`):**
- 1 standard cleared → 1 beat, tally count 1, no emblem ignition (unless rank crosses).
- 6 standards cleared in one log → 6 beats ordered ascending by rank; one tally; one emblem ignition at the end.
- Multi-rank event → emblem ignition `true`.

**Commit:** `feat(rewards): sequential-beat reward payload + tally`

### Task C6 — Reward screen UI (sequential beat → summary)

**File:** Modify `WorkoutLogSummaryView.swift`.

**Acceptance**
- Renders `WorkoutRewardSequence` as:
  - each `beat` flashes ~0.9s (configurable constant), with a subtle scale-in / scale-out
  - after the last beat, the summary card animates in showing the tally
  - one cinematic emblem ignition (only if `emblemIgnition == true`) plays as the summary card lands
  - the full list of cleared standards is visible as a tap-to-expand row inside the summary card
- A "Skip animation" affordance lets the user jump straight to the summary card.
- Action buttons in the summary card:
  - **Add next standard to Program** → calls back into editor (Agent B)
  - **Keep current Program** → dismiss
  - **View Skill Tree** → push the Skill Tree

**Test (`RewardScreenTests.swift`) — UITests:**
- A 6-beat sequence renders the animation in order and collapses to a summary card.
- No per-standard popup is ever instantiated (test against modal-presentation count).
- Skip jumps directly to the summary card without playing beats.

**Commit:** `feat(rewards): sequential-beat reward screen with tally summary`

### Task C7 — Wire `WorkoutLog` completion → `ProofEngine` → reward UI

**Files:** Touch wherever the existing `WorkoutLog` finalization happens (likely `WorkoutLoggingViewModel.swift` + a service in `UNBOUND/Services/WorkoutLog/`).

**Acceptance**
- On every workout finalization (regardless of source), the engine runs and the reward screen is presented.
- Custom workouts (no engine-provided targets) still trigger proof and a reward screen if any standards cleared.
- Vow completions trigger reward beats too (Vows are inputs per the spec).

**Test:** simulator slice — log a workout containing a Strict Pull-Up set of 12 → confirm reward screen shows multi-rank beat sequence + tally + ignition.

**Commit:** `feat(rewards): every logged workout routes through ProofEngine + reward UI`

### Task C8 — Edge cases

**Acceptance**
- Logging an empty workout (zero sets) → no reward screen, no engine work, no errors.
- Logging two-a-day on the same date — each workout triggers its own engine pass; the higher-quality session (Agent A's flag) is the day's "primary" but both contribute proof.
- Rest-day bonus workout — engine still runs; the day stays a rest-day in the schedule.

**Test:** add cases to `ProofEngineTests` for each scenario.

**Commit:** `test(rewards): edge cases — empty / two-a-day / rest-day bonus`

---

## Verification (end of phase)

```
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/PrereqMetadataMigrationTests \
  -only-testing:UNBOUNDTests/PrereqClearerTests \
  -only-testing:UNBOUNDTests/ProofEngineTests \
  -only-testing:UNBOUNDTests/SkillBlockRouterTests \
  -only-testing:UNBOUNDTests/SkillBlockRegionTaggerTests \
  -only-testing:UNBOUNDTests/RewardPayloadBuilderTests \
  -only-testing:UNBOUNDUITests/RewardScreenTests
```

All green = phase done. Hand off to Agent A for full-engine sim suite.
