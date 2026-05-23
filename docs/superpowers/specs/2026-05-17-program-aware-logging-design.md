# Program-Aware Logging Surface — Design Spec

**Date:** 2026-05-17
**Supersedes:** the grid-presentation portions of `2026-05-17-workout-logging-redesign-v2-design.md`
**Branch:** `program-redesign` · UNBOUND iOS

## Context

The block/grid logger ships, but on device jlin found a structural flaw: the
Claude-generated program produces a full prescription per exercise
(`plannedSets`, `plannedReps`, target `rpe`, `restSeconds`, `muscleGroups`,
form-cue `notes`, `substitution`) — and the logging UI **discards all of it**.
`WorkoutLogGridView` passes only `name` + blank `sets` into `ExerciseLogCard`,
so the user faces a blank spreadsheet of `—`, can't see today's plan, can't
reach form cues mid-workout, and the explicit per-set ✓ makes "when is it
logged" ambiguous. The end state to reach: **the user has everything the
program knows and logging is confirming or correcting reality, one gesture.**

## Locked decisions (from brainstorming dialogue)

1. **Two-state set rows: SUGGESTED → LOGGED.** Every set row is pre-populated
   with the program's full suggestion (weight from working-weight/last-session
   prefill, reps from the program's rep target, RPE from the program's target),
   rendered **dim** (a proposal, not a record). It becomes LOGGED — solid, with
   a filled ✓ status glyph, and included in the saved log — two ways, both
   implicit (no checkbox ritual):
   - **Confirm as planned:** one tap on the row's trailing confirm control →
     the suggestion commits as the actual. One tap *because it is prefilled* —
     this is the "easy" path for the user who did exactly the plan.
   - **Edit a value:** tapping the WEIGHT or REPS cell opens the stepper
     **pre-seeded to the program's suggested number**; committing an edit
     *is* the log. This is the "flexible" path — a user who deviated never
     touches the confirm control; changing a value logs the set.
2. **One haptic + solidify moment** on every SUGGESTED→LOGGED transition: a
   single `UnboundHaptics.success()`, the row "solidifies" (dim→solid spring +
   faint accent bloom), and the rest pill auto-starts **once** at the
   exercise's prescribed seconds.
3. **Adjust later if need be.** After a set is LOGGED, tapping any cell
   re-opens the stepper to edit; the set **stays LOGGED** (no un-log, no repeat
   haptic).
4. **Per-exercise only — no session header.** The planned-workout name is just
   the screen title. No day strip, no progress bar at the top.
5. **The expandable thing (inline, no modal).** Tapping the exercise
   name/chevron expands the card **in place** to reveal the premium detail
   sections — Target Muscles, Programming, Form Cues, Substitution — reusing
   the existing `ExerciseDetailView` section views. Collapses back. The user
   reads "what / why / how" without leaving the set. `⋯` stays for *actions*
   (warmup / notes / swap / skip / add-remove); name/chevron is *read*.
6. **A compact Target caption** under the exercise name always shows the
   prescription in one line: `Target · 4 × 8–10 · RPE 8 · rest 2:30`.

## What survives byte-identical (do NOT touch — verified by git diff in review)

`WorkoutLog`/`ExerciseLogEntry`/`SetLog` shapes; `ActiveWorkoutSession`
.assembleWorkoutLog filtering on `set.logged`; `WorkoutLogService.saveLog` +
its 11-step cascade; `ActiveWorkoutContainerView.complete()`; the post-save
reward trigger (`RewardSummary`); `loadContext()`; `WorkoutDraftStore` autosave
cadence; `RestTimerModel`/`RestTimerPill`/`RestNotifier`; `RPEPickerSheet`;
`StepperControl`; `ExerciseOverflowMenu`/`OverflowIntent`; the two entry-point
constructions (`ProgramOverviewView.swift:1065`, `WorkoutDetailView.swift:101`)
— init signature unchanged. Sub-project B (rewards) depends on this.

## Architecture (new/changed units)

### Model — `ActiveWorkoutSession.swift`

- `ActiveSet` gains three optional suggestion fields:
  `suggestedWeightKg: Double?`, `suggestedReps: Int?`, `suggestedRPE: Int?`.
  `logged: Bool` stays (save filter). A set is SUGGESTED while
  `logged == false`, LOGGED once `logged == true`.
- `ActiveExercise` gains `targetRPE: Int?`, `formCues: String?`,
  `substitution: String?` — currently `Exercise.rpe`/`.notes`/`.substitution`
  are dropped in `init(workout:)`. (`ActiveExercise.notes` remains the user's
  editable per-exercise note — distinct from program `formCues`.)
- `init(workout:)` maps the new fields and seeds each `ActiveSet`:
  `suggestedReps = RepRange.lowerBound(ex.reps)`, `suggestedRPE = ex.rpe`.
  `suggestedWeightKg` is left nil here (needs async prefill — backfilled by the
  container after `loadContext`).
- `enum RepRange { static func lowerBound(_ s: String) -> Int? }` — first
  integer in the string; `"8-10"→8`, `"8"→8`, `"12 each"→12`, `"AMRAP"→nil`,
  `"30s"→30`. Pure, unit-tested.
- `func confirmAsPlanned(exerciseIndex:setIndex:)` — copies
  `suggested* → weightKg/reps/rpe` and sets `logged = true`. No-op if indices
  invalid or already logged.
- `func logSet(exerciseIndex:setIndex:weightKg:reps:)` and the editor commit
  path set `logged = true` when **both** `weightKg != nil && reps != nil`
  (implicit done on fill). Editing a logged set does not clear `logged`.
- `Snapshot` Codable stays backward-compatible: explicit `init(from:)` /
  `ActiveSet`/`ActiveExercise` decoders use `decodeIfPresent` for the new
  fields so an old in-flight draft still resumes (missing keys → nil).

### UI — extracted detail sections

- New `ExerciseDetailSections(exercise:)` view holding the four sections
  currently inside `ExerciseDetailView` (Target Muscles / Programming / Form
  Cues / Substitution + the private `FlowLayout`). `ExerciseDetailView` becomes
  a thin wrapper: `ScrollView { ExerciseDetailSections(exercise:) }` +
  nav title — **no visual or behavioral change to the standalone screen**.
  The card's inline expansion embeds `ExerciseDetailSections` directly.

### UI — `SetLogGridRow.swift` (rewrite)

- Inputs gain `suggestedWeightKg/Reps/RPE`. Display rule per cell: if
  `logged` → actual value, `Color.unbound.textPrimary` (solid); else if a
  suggestion exists → suggested value, `Color.unbound.textTertiary` (dim);
  else `—`.
- Trailing control replaces the ✓ Button:
  - `logged == false`: a hollow ring (`◔`-style, ≥30pt hit target),
    `accessibilityLabel "Log set N as planned"` → calls `onConfirmAsPlanned`.
  - `logged == true`: a filled accent circle + `checkmark` glyph,
    non-interactive, `accessibilityLabel "Set N logged"`. The dim→solid +
    bloom spring plays on the `logged` transition (respects
    `accessibilityReduceMotion`: fades only, haptic kept).
- WEIGHT/REPS cells: tap → `onEditWeight`/`onEditReps` (stepper pre-seeds to
  actual-or-suggested). RPE cell: tap → `onPickRPE` (picker pre-seeds to
  actual-or-suggested). No prose in the row.

### UI — `ExerciseLogCard.swift`

- New inputs: `plannedSets`, `plannedReps`, `targetRPE`, `restSeconds`,
  `muscleGroups`, `formCues`, `substitution`, `exercise: Exercise?` (for the
  expansion), `isExpanded: Bool`, `onToggleExpand`, `onConfirmAsPlanned(Int)`.
- Header: name + chevron (rotates on expand) tappable → `onToggleExpand`;
  `ExerciseOverflowMenu` unchanged. A `Target · N × reps · RPE r · rest m:ss`
  caption (`captionS`, `textTertiary`) under the name; RPE/rest segments
  omitted when nil.
- When `isExpanded`: `ExerciseDetailSections(exercise:)` rendered between the
  caption and the column header, inside the card, with a divider; smooth
  height animation.
- Rows pass the new suggestion inputs + `onConfirmAsPlanned` through.

### UI — `WorkoutLogGridView.swift`

- Pass the new prescription inputs through to `ExerciseLogCard`. Own a
  per-exercise expanded set (`@State private var expanded: Set<String>` keyed
  by exercise id) toggled by `onToggleExpand`. **No session header added.**
  `COMPLETE SESSION` button unchanged.

### Wire — `ActiveWorkoutContainerView.swift`

- After `loadContext()` resolves `priorEntries`/`workingWeightKg`, **backfill**
  `session.exercises[*].sets[*].suggestedWeightKg` via the existing
  `SetPrefill.ghost(...)` (per exercise/set). Reps/RPE suggestions are already
  seeded at session build.
- `onConfirmAsPlanned(ei, si)`: `session.confirmAsPlanned(...)` →
  `draftStore.save` → `transition(ei)` (haptic + rest, once).
- Editor commit (`EditorSheet.commit`) and any weight/reps write: if the set
  crosses into `logged == true` on this write, run `transition(ei)`. A
  `transition` runs `UnboundHaptics.success()` + `startRest(ei:)` exactly once
  per set (guard on the nil→logged edge, not on subsequent edits).
- Remove the old per-tap `onLog` ✓ semantics from the grid wiring; the row no
  longer has a log Button. `complete()`, the reward sheet block, `loadContext`,
  draft cadence, swap/notes/custom sheets — **unchanged**.

## Design bar (non-negotiable — carries over)

Premium-native, materials/depth/springs, quiet-default (violet only on the
primary signal), tokens only (`Color.unbound.*`, `Font.unbound.*`),
`UnboundHaptics`. Specifics:
- SUGGESTED rows read clearly as a *proposal* — dim but legible (≥13pt,
  `textTertiary`), never look broken or like an error state.
- The SUGGESTED→LOGGED solidify is the one satisfying beat: spring + single
  `success` haptic + faint accent bloom; no confetti, no color carnival.
- Confirm control: a calm ≥30pt ring, obviously tappable, one accent.
- Target caption: one line, tertiary, never wraps to a giant mono block
  (the v2-T8 anti-pattern stays dead).
- Inline expansion: smooth height spring, the detail sections keep their
  existing premium treatment; collapses cleanly; does not shove the rest pill.
- `prefers-reduced-motion` → fades only, haptics kept.
- Definition of done per UI task: builds, on-device screenshot reviewed
  against this bar by jlin, reads premium not generic.

## Testing / verification

- New unit tests (`ActiveWorkoutSession`): `RepRange.lowerBound` cases;
  `confirmAsPlanned` copies suggested→actual + logged; edit fills →
  `logged` only when weight && reps both present; editing a logged set keeps
  `logged`; `targetRPE/formCues/substitution` carried from `Exercise`;
  `Snapshot` decodes both with and without the new keys (draft back-compat).
  Existing tests stay green.
- `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' test`
  — only the known pre-existing `FriendChallengeServiceTests`/
  `SquadMissionServiceTests` RLS flap may fail; zero new failures. SourceKit
  cross-file noise ignored per project rule.
- Parity guard: a logged session produces an equivalent `WorkoutLog` and the
  same `saveLog` cascade side-effects as before (reward sheet still fires).
- On-device (jlin-driven, signed-in account with a persisted program):
  open today's workout → each exercise shows the Target caption + dim
  suggested rows → tap name → card expands to muscles/cues/why → confirm a
  set (one tap) → it solidifies + haptic + rest pill → edit another set's
  weight → it logs on commit → adjust a logged value → stays logged →
  COMPLETE → existing reward sheet fires → a row lands in Supabase.

## Out of scope

Reward choreography (sub-project B — preserved, untouched), skill→program
(C/D), skill visuals (E), program *generation*, supersets/circuits, Apple
Watch, any change to the entry-point screens beyond what passes the same
`Workout` in.

## Execution

Subagent-driven (fresh subagent per task, spec-then-quality review at cluster
seams), Sonnet minimum, frequent commits, co-authored trailer, on-device
sign-off by jlin per the design bar.
