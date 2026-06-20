# Program — Simplest Core — Design

**Date:** 2026-06-20
**Status:** Approved design, pending implementation plan

## Goal

Collapse the UNBOUND program's generation engine and time-model down to a core a
user (and the developer) can hold in one breath: **goal in → a program; train a
4-week block; one tap renews it.** Strip the overlapping periodization vocabulary
(arc / wave / block / phase), the self-renewing machinery (calibration week,
scan-at-boundary, checkpoints, grace windows), and the hidden biasers
(weak-point / fatigue / load) — replacing them with a single time unit, a single
renewal moment, and a few **visible** choices. The program should still feel
*coached*, not like a bare logger, but it must be explainable in three sentences.

## Scope

**In scope** — the generation engine and the time-model:
- How a brand-new program is born (onboarding inputs → split → first block).
- How the program is structured over time (one unit: the 4-week **block**).
- How loads progress (double progression, RPE-modulated) and how a block renews.

**Out of scope — left running untouched:**
- **Logging** (`ActiveWorkoutSession`, `WorkoutLog`, `SetLog`).
- The **daily-modifier layer** — `DailyWorkoutResolver` + substitution / deload /
  travel / short-session / **trial-prep**. (User confirmed this layer feels fine.)
- The **Skills-day** slot in the weekly schedule (`ProgramScheduler`).
- The entire **achievement layer** — ranks, rank trials, proof engine, skill trees.
  It is a *one-way consumer* of logged `SetLog` data; it does not read arcs/waves/
  blocks, so simplifying the engine leaves it working. (Its own concept pile is a
  separate, cleanly-separable future brainstorm — see "Out of scope (YAGNI)".)

## The core model (the whole thing)

One time-word: **block**. A block is **4 weeks**, same split throughout.

> **Born:** `goal + days/week + equipment` → instant split + first block. The
> body-scan stays as the ceremonial intro; it gates nothing.
> **Lived:** a 4-week block, same split, with **progression you can see**.
> **Renewed:** at the block's end, **one tap** — *too easy / about right / brutal* —
> tunes the next block. Loads carry forward from what you actually logged.

Gone: `Arc`, `Wave`, `Phase`, Calibration-Week, scan-at-boundary, checkpoints,
grace windows, and all hidden biasers.

## Progression — double progression, RPE-modulated

The rule must be legible: a user can always see *why* today's number is today's
number. The reference line under a set reads e.g. `+2.5kg · hit 12 @ RPE 7`.

**Trigger (pure double progression):**
- Each exercise has a **rep range** (e.g. 8–12) at a fixed working weight.
- Hit the **top of the range on all working sets** → next session the **weight goes
  up** and reps reset to the bottom of the range.
- Otherwise → **same weight, chase the reps.**

**RPE sizes the step (the influence, not a replacement):** when the range is
cleared, the average working-set RPE picks the increment:
- avg RPE ≤ 7 (easy) → **confident / larger** bump.
- avg RPE 8–9 (hard) → **smaller** bump.
- avg RPE ≥ 9.5 (barely) → **tiny** bump, or hold the same weight one more session.

Increments are per-movement (small for isolation/upper, larger for compound/lower)
and rounded by the existing `WeightPlatePolicy`. Bodyweight / hold movements use the
same trigger on reps / hold-seconds; "weight up" becomes "rep-range or hold-target up."

**RPE also informs renewal:** the block's average RPE **pre-fills** the boundary
check-in — low avg → suggests *too easy*, high avg → suggests *brutal* — so the one
tap is informed, not blind. The user can always override the suggestion.

This replaces the `ProgressionState` / `TrainingPrescriptionResolver` /
`LoadBiasApplier` stack with one comprehensible function over the user's logged sets.

## Visible inputs (replacing hidden knobs)

The only things shaping the program are things the user can see and set:

| Input | When | Replaces |
| --- | --- | --- |
| **Goal** (build muscle / get stronger / skills) | onboarding | scan-driven intent |
| **Days/week** | onboarding | — (basic fact) |
| **Equipment** | onboarding | — (basic fact) |
| **Emphasis** (e.g. arms / chest / weak point) — *v1* | onboarding (optional) | `WeakPointBiaser` |
| **Block check-in** (too easy / right / brutal) | each block boundary | checkpoints + `LoadBiasApplier` + scan-at-boundary |

Deleted as hidden machinery: `WeakPointBiaser`, `RegionFatigueBudget`,
`AccessoryBiasRefreshRule`, `LoadBiasApplier`.

## Set-row display — the Previous column

"Progression you can see" is only real if the set row *shows* it. Today the
last-performance feature renders it as a dim text line under the row
(`SetLogGridRow.lastReferenceLine`); that is replaced by a **dedicated "Previous"
column** (the Strong/Hevy pattern the user chose).

**Layout:** `Set# · PREVIOUS · Weight · Reps · RPE · ✓` — a new column slots between
the set number and the weight cell (header label added at `ExerciseLogCard`'s column
header, `SET / WEIGHT / REPS / RPE` → `SET / PREVIOUS / WEIGHT / REPS / RPE`).

- **Previous cell** (dim, mono, `textTertiary`): last time's matching set, formatted by
  metric — `135×8` (weight×reps), `12` (bodyweight reps), `30s` (hold), `5:00`
  (duration), `400m`, `15` (calories). A subtle `→` shows it carrying into today's
  editable weight — consistent with the locked "last drives prefill" decision.
- **No history** (first time doing the exercise): Previous shows `—`, no arrow.
- **Progression cue** (under the row, only when meaningful): the double-progression +
  RPE outcome, short and tinted (`success`/`coachCyan`) — `▲ +2.5kg` (earned a jump),
  `chase reps` (hold weight, climb reps), `▲ +1 rep` / `▲ +5s` (bodyweight / holds).
  Because "last" now lives in the column, this line carries only the *why / what's next*.
- **Style:** fill-only, **no hard border, no left accent bar** — honors the established
  calm language; works in both `calmStyle` (hairline) and legacy (filled-cell) rows.
  Previous stays compact/dim so it doesn't crowd the editable cells on a phone.

**Ship split:** the **Previous column** needs only `LastPerformanceLookup` (already
built) → it can land independently, including on the current last-performance branch.
The **progression cue** depends on the new double-progression engine → it lands with
that engine. Every visual lands a pixel-council color check before "done" (tokens
only: `Color.unbound.*`, AA contrast on true-black).

## Data flow

```
Onboarding (goal + days + equipment + emphasis)
  → SplitLookup → DeterministicProgramGenerator (split + movement selection + prescription)
  → Block 1 (4 weeks, same split)

Within a block:
  each session → log sets (weight/reps/RPE)  [unchanged logging layer]
  next session's numbers = double-progression(logged sets, RPE)   [visible on the row]

Block boundary (end of 4 weeks):
  avg-RPE pre-fills the check-in → user taps too-easy / right / brutal
  → next block = same split, loads carried forward, intensity nudged by the tap
```

## Code blast radius (honest)

**Delete / absorb** (periodization + renewal + biasing engine):
`ArcGenerator`, `WaveAdjuster`, `ProgramPhaseEngine`, `RolloverCoordinator`
(scan-at-boundary / grace windows), `WeakPointBiaser`, `RegionFatigueBudget`,
`AccessoryBiasRefreshRule`, `LoadBiasApplier`, the Calibration-Week path, and the
`Arc` / `Wave` / `Phase` / `ArcState` model types. `ProgressionState` shrinks to a
per-exercise *(weight, rep-range, last-hit, last-avg-RPE)*.

**Keep & simplify:**
- `DeterministicProgramGenerator` core (split + movement selection + prescription —
  already rank-free) — re-pointed at the new visible inputs.
- `SplitLookup` — this *is* "goal in, program out."
- `BlockRolloverService` → becomes a small "start next block + apply check-in" function
  (no scan, no grace window, no hidden bias).

**Keep as-is (seams preserved):** `DailyWorkoutResolver` + all modifiers (incl.
`trialPrep`), `ProgramScheduler` (incl. Skills day), `MacroCalculator` / nutrition,
the whole logging + achievement layer.

Roughly **15–20 of the 36 `ProgramGeneration` files** collapse or vanish.

## Migration

Existing users have arc-based programs persisted in Supabase (`program_blocks`,
`current_program_id`). Cleanest path: on next open, **regenerate into the new block
model** from the user's saved goal / split / equipment rather than migrating old arc
state forward. Old `program_blocks` rows are ignored, not transformed. The plan will
specify the one-time regeneration trigger and how in-flight progress (last logged
loads) seeds the first new block so users don't lose their working weights.

## Out of scope (YAGNI)

- **Simplifying the achievement layer** (ranks / trials / proof / skill trees) — its
  own future brainstorm; cleanly separable via the one-way dependency.
- **Nutrition / macros** simplification — `MacroCalculator` stays as-is.
- **RPE autoregulation beyond jump-sizing** (no per-set live target adjustment, no
  fatigue-driven volume autoregulation) — RPE only sizes the increment and pre-fills
  the check-in.
- Trend/PR analytics, multi-block history visualizations.

## Testing

**Unit (pure functions, no DB):**
- Double-progression trigger: cleared top-of-range on all sets → weight up + reps
  reset; missed → same weight, reps chased.
- RPE step-sizing: same "cleared range" outcome produces larger/smaller/tiny bump
  for avg RPE ≤7 / 8–9 / ≥9.5; plate rounding applied.
- Bodyweight / hold movements progress on reps / hold-seconds with the same trigger.
- Check-in pre-fill: low avg RPE → *too easy*; high → *brutal*.
- Block renewal: same split preserved; loads carried forward; check-in nudge applied.
- Generation from `goal + days + equipment + emphasis` produces a coherent split
  (emphasis biases the chosen movements visibly).

**Manual / sim:** QA Lab seeded program → log a block → advance to boundary (dev SIM
date controls) → confirm the one-tap check-in and the carried-forward loads in the
next block.

## Files touched (anticipated)

- **Delete:** `ArcGenerator`, `WaveAdjuster`, `ProgramPhaseEngine`,
  `RolloverCoordinator`, `WeakPointBiaser`, `RegionFatigueBudget`,
  `AccessoryBiasRefreshRule`, `LoadBiasApplier`, Calibration-Week generation.
- **New:** a single `BlockProgression` (double-progression + RPE sizing, pure) and a
  small `BlockRenewal` (check-in → next block).
- **Modify:** `DeterministicProgramGenerator` (+ extensions), `SplitLookup`,
  `BlockRolloverService`, `ProgressionState` (shrink), onboarding inputs,
  `Program.swift` model types (drop `Arc`/`Wave`/`Phase`), the program-tab surface
  copy that names arcs/waves.
- **Modify (set-row display):** `SetLogGridRow.swift` (Previous column replaces
  `lastReferenceLine`; progression cue under the row), `ExerciseLogCard.swift`
  (add `PREVIOUS` column header at the `SET / WEIGHT / REPS / RPE` row, ~line 184).
  The Previous column is shippable now on the last-performance branch; the
  progression cue lands with the engine.
