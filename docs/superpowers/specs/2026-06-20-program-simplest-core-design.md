# Program — Simplest Core — Design

**Date:** 2026-06-20
**Status:** Approved design, pending implementation plan

## Goal

Collapse the UNBOUND program's generation engine and time-model down to a core a
user (and the developer) can hold in one breath: **goal in → a program; train a
4-week arc; one tap renews it.** Collapse the overlapping periodization vocabulary
(arc / wave / block / phase) down to a single **Arc**, strip the self-renewing
machinery (calibration week, scan-at-boundary, checkpoints, grace windows) and the
hidden biasers (weak-point / fatigue / load) — replacing them with one time unit, a
single renewal moment, and a few **visible** choices. The program should still feel
*coached*, not like a bare logger, but it must be explainable in three sentences.

## Scope

**In scope** — the generation engine and the time-model:
- How a brand-new program is born (onboarding inputs → split → first arc).
- How the program is structured over time (one unit: the 4-week **arc**).
- How loads progress (pure double progression) and how an arc renews.

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

One time-word: **Arc** — the term (and 28-day / 4-week duration) the code already
uses. Everything else collapses into it: same split throughout an arc.

> **Born:** `goal + days/week + equipment` → instant split + first arc. The
> body-scan stays as the ceremonial intro; it gates nothing.
> **Lived:** a 4-week arc, same split, with **progression you can see**.
> **Renewed:** at the arc's end, **one tap** — *too easy / about right / brutal* —
> tunes the next arc. Loads carry forward from what you actually logged.

Gone: `Wave`, `Phase` (the Accumulation/Intensification `BlockType`), the 2-week
`ProgramBlock` rollover, Calibration-Week, scan-at-boundary, checkpoints, grace
windows, and all hidden biasers. **`Arc` stays** — as the single time unit.

## Progression — pure double progression (engine already exists)

**Correction from discovery (2026-06-20):** the progression engine the original draft
proposed *building* **already exists and runs in production.** `ProgressionEngine`
(`Services/Progression/ProgressionEngine.swift`), wired into the save path at
`TrainingCompletionService.swift:572` (every completed workout), already does double
progression: add weight after hitting the **top of the rep range for 2 consecutive
sessions**, plate-aware jumps via `WeightPlatePolicy.progressedWeightKilograms`,
accessories reps-first, bodyweight via the skill tree, plus `AutoDeloadService` +
`PlateauDetector`. **We keep it — we do not rebuild it.**

**RPE is removed** (it was pulled from the logger UI, so it is no longer entered). The
engine's RPE gate (`isCleanRPEHit` / `isGrindyRPE`) currently *requires* RPE — with no
RPE logged it returns "not a clean hit" and the engine **would never bump** (a latent
bug). The fix is to make progression **pure rep-based**: drop the RPE gate so the
advance criterion is `hitTopOfRange` for 2 consecutive sessions, full stop.
- Each exercise has a **rep range** (e.g. 8–12) at a working weight.
- Hit the **top of the range for 2 sessions running** → **weight goes up** (plate-aware),
  reps reset to the bottom. Otherwise → **same weight, chase the reps.**
- Accessories add reps to a ceiling first, then load; bodyweight via the skill tree
  (all existing `ProgressionEngine` behavior, unchanged).

**Tradeoff (accepted):** without RPE the engine can't tell a grind from an easy set — it
advances on reps alone. `AutoDeloadService` + `PlateauDetector` still catch a too-heavy
weight, so it self-corrects. The arc check-in (one tap) is now a **pure manual signal**
(no RPE pre-fill).

**The legible part — the cue (new):** "progression you can see" is a **forward-looking
cue under the set row**, computed read-only from `ProgressionState`: `▲ +2.5kg` (one more
top-range session bumps), `chase reps` (hit the top to advance), `+2 reps` (accessory), or
nothing for bodyweight. The engine already publishes the *after-the-fact* bump toast
(`WeightBumpToast`); the cue adds the *before*.

## Visible inputs (replacing hidden knobs)

The only things shaping the program are things the user can see and set:

| Input | When | Replaces |
| --- | --- | --- |
| **Goal** (build muscle / get stronger / skills) | onboarding | scan-driven intent |
| **Days/week** | onboarding | — (basic fact) |
| **Equipment** | onboarding | — (basic fact) |
| **Emphasis** (e.g. arms / chest / weak point) — *v1* | onboarding (optional) | `WeakPointBiaser` |
| **Arc check-in** (too easy / right / brutal) | each arc boundary | checkpoints + `LoadBiasApplier` + scan-at-boundary |

Deleted as hidden machinery: `WeakPointBiaser`, `RegionFatigueBudget`,
`AccessoryBiasRefreshRule`, `LoadBiasApplier`.

## Set-row display — the Previous column

"Progression you can see" is only real if the set row *shows* it. The dim
last-performance text line is replaced by a **co-equal "Previous" column** rendered in
the **same boxed style** as Weight and Reps (not a cramped sidecar, not dim text). RPE
is **removed from the logger grid** entirely to make room — three equal columns breathe.

**Layout:** `Set# · PREV · Weight · Reps · ✓` — three equal-width value columns. The
`ExerciseLogCard` header becomes `SET / PREV / WEIGHT / REPS` (the RPE header is gone).

- **All three value fields are rounded boxes** (recessed `bg` fill against the card,
  `cornerRadius 10`). The **current set's Weight/Reps carry a quiet cyan border** as the
  active-input cue; **PREV is borderless** — same box, read-only, a slightly quieter
  shade (`textSecondary`) so it reads as history. (This intentionally swaps the prior
  `calmStyle` hairline for a boxed field on this screen.)
- **PREV shows one clean value** matched by metric: weight for loaded lifts (`135`),
  reps for bodyweight (`12`), seconds for holds (`30s`). No `×reps` — a single number
  per box keeps the columns consistent, and once the engine lands, `PREV → WEIGHT`
  reads as the actual progression jump.
- **No history** (first time): PREV shows `—`.
- **RPE:** removed from the row (no column, no per-set field). `SetLog.rpe` is retained
  in the model but has no logger UI; `confirmAsPlanned` still seeds a default.
- **Progression cue** (future, with the engine): a short tinted line under the row —
  `▲ +2.5kg` / `chase reps` / `▲ +1 rep` — carrying the *why / what's next*.

**Ship split:** the **Previous column + boxed fields + RPE removal** need only
`LastPerformanceLookup` (already built) → shipped now on the last-performance branch.
The **progression cue** depends on the new double-progression engine and lands with it.
Every visual lands a pixel-council color check before "done" (tokens only:
`Color.unbound.*`, AA contrast on the recessed `bg` fill).

## Data flow

```
Onboarding (goal + days + equipment + emphasis)
  → SplitLookup → DeterministicProgramGenerator (split + movement selection + prescription)
  → Arc 1 (4 weeks, same split)

Within an arc:
  each session → log sets (weight/reps)  [unchanged logging layer]
  ProgressionEngine (on save) bumps loads rep-only — top of range × 2 sessions → +plate
  the row shows the forward-looking cue (Plan 2)   [progression you can see]

Arc boundary (end of 4 weeks):
  user taps too-easy / about-right / brutal  (pure manual signal, no RPE)
  → next arc = same split, loads carried forward, intensity nudged by the tap
```

## Code blast radius (honest)

**Delete / absorb** (periodization + renewal + biasing machinery):
`WaveAdjuster`, `ProgramPhaseEngine`, `RolloverCoordinator` (scan-at-boundary / grace
windows), `WeakPointBiaser`, `RegionFatigueBudget`, `AccessoryBiasRefreshRule`,
`LoadBiasApplier`, the Calibration-Week path, the `Wave` / `Phase` (`BlockType`) types,
and the 2-week `ProgramBlock` rollover. **`Arc` stays** as the single time unit
(`ArcGenerator` / `ArcState` simplified, not deleted). `ProgressionState` keeps its
rep-based fields; the RPE/phase fields (`targetRPE`, `blockType`) retire with the phase
collapse (Plan 3).

**Keep & simplify:**
- `ProgressionEngine` — already implements rep-based double progression; keep it
  (Plan 1 just drops its now-dead RPE gate).
- `DeterministicProgramGenerator` core + `ArcGenerator` (split + movement selection +
  prescription — already rank-free) — re-pointed at the new visible inputs.
- `SplitLookup` — this *is* "goal in, program out."
- `BlockRolloverService` → becomes a small "start next arc + apply check-in" function
  (no scan, no grace window, no hidden bias).

**Keep as-is (seams preserved):** `DailyWorkoutResolver` + all modifiers (incl.
`trialPrep`), `ProgramScheduler` (incl. Skills day), `MacroCalculator` / nutrition,
the whole logging + achievement layer.

Roughly **15–20 of the 36 `ProgramGeneration` files** collapse or vanish.

## Migration

Existing users have programs persisted in Supabase (`program_blocks`,
`current_program_id`). Cleanest path: on next open, **regenerate into the simplified arc
model** from the user's saved goal / split / equipment rather than migrating old
periodization state forward. Old `program_blocks` rows are ignored, not transformed. The
plan will specify the one-time regeneration trigger and how in-flight progress (last
logged loads) seeds the first new arc so users don't lose their working weights.

## Out of scope (YAGNI)

- **Simplifying the achievement layer** (ranks / trials / proof / skill trees) — its
  own future brainstorm; cleanly separable via the one-way dependency.
- **Nutrition / macros** simplification — `MacroCalculator` stays as-is.
- **RPE autoregulation beyond jump-sizing** (no per-set live target adjustment, no
  fatigue-driven volume autoregulation) — RPE only sizes the increment and pre-fills
  the check-in.
- Trend/PR analytics, multi-arc history visualizations.

## Testing

**Unit (pure functions, no DB):**
- Rep-only advance (Plan 1): top of range × 2 sessions → bump; no RPE involved.
- Bodyweight / hold movements progress on reps / hold-seconds (existing engine).
- Forward-looking cue (Plan 2): correct string per state (▲+plate / chase reps / +reps).
- Arc renewal: same split preserved; loads carried forward; check-in nudge applied.
- Generation from `goal + days + equipment + emphasis` produces a coherent split
  (emphasis biases the chosen movements visibly).

**Manual / sim:** QA Lab seeded program → log an arc → advance to boundary (dev SIM
date controls) → confirm the one-tap check-in and the carried-forward loads in the
next arc.

## Files touched (anticipated)

- **Delete:** `ArcGenerator`, `WaveAdjuster`, `ProgramPhaseEngine`,
  `RolloverCoordinator`, `WeakPointBiaser`, `RegionFatigueBudget`,
  `AccessoryBiasRefreshRule`, `LoadBiasApplier`, Calibration-Week generation.
- **New:** a small `ArcRenewal` (check-in → next arc) and the forward-looking progression
  cue (Plan 2). No new progression engine — `ProgressionEngine` already exists.
- **Modify:** `DeterministicProgramGenerator` (+ extensions), `SplitLookup`,
  `BlockRolloverService`, `ProgressionState` (shrink), onboarding inputs,
  `Program.swift` model types (drop `Arc`/`Wave`/`Phase`), the program-tab surface
  copy that names arcs/waves.
- **Modify (set-row display):** `SetLogGridRow.swift` (co-equal boxed PREV column
  replaces `lastReferenceLine`; all value fields → rounded boxes; RPE UI removed;
  progression cue under the row lands later with the engine), `ExerciseLogCard.swift`
  (header `SET / PREV / WEIGHT / REPS`, RPE header removed). Shippable now on the
  last-performance branch.
