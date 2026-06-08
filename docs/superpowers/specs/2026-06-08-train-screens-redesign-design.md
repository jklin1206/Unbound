# Train Screens Redesign — My Workouts (list-first) + Today's Plan (de-blocked)

**Branch:** `frontend-redesign`
**Date:** 2026-06-08
**Builds on:** `docs/superpowers/specs/2026-06-08-train-ia-design.md` (Train IA, shipped Phases 1–3) and the calm-list language in `docs/superpowers/specs/2026-06-08-program-frontend-redesign-design.md`.
**Goal:** The Train tab's two main surfaces are not comfortable to read on mobile. Make **My Workouts** list-first (the saved workouts are the content; Quick Log/Build are small secondary actions) and make **Today's Plan** editorial (dissolve the one big container block and the fuel band so the day reads as flowing content).

## Problem

After the IA work, two screens still feel heavy:
1. **My Workouts** leads with a large accent **Quick Log** block and a **Build** row, while the actual saved workouts are *hidden* behind a "Your saved workouts" push. The user wants to see and read their workouts immediately; Quick Log/Build should be lightweight.
2. **Today's Plan** crams the entire day — summary, fuel band, modifier rail, wave panel, exercise list, *and* the BEGIN button — inside ONE `ProgramSelectedDayCard` fill block. It reads as a dense box, with a fuel "band" that still feels pill-like.

## Decisions (locked with user, via mockups)

- **My Workouts = Option A — list-first.** Small action pair on top; saved workouts inline as a readable flat list.
- **Today's Plan = Option A — editorial, no container.** Dissolve the day-card block; fold the fuel band into a plain meta line; exercises flow flat; BEGIN is the single accent.

---

## Part 1 — My Workouts (list-first)

### Layout
```
[ ⚡ Quick Log ]  [ ＋ Build ]      ← two compact bordered buttons, equal width, secondary
SAVED · N                           ← CalmSectionHeader with count
┌ (flat rows, hairline separators) ─────────────┐
[img]  My Push Day            ↻   ⋯
       6 exercises · 45m · PUSH
[img]  Sunday Legs            ↻   ⋯
       5 exercises · 50m · LEGS
…
```
- **Action pair:** two compact, equal-width bordered buttons (`border`, no fill) — `⚡ Quick Log` and `＋ Build`. Quiet; not accent blocks. Quick Log keeps haptic `.medium`, Build `.soft`.
- **Saved list inline:** rows rendered directly in the tab (no push). Each row: leading thumbnail (`WorkoutReferenceImageView`, ~44pt), title, a `·`-joined meta line (`N exercises · Mm · ROLE`), a trailing ↻ "use today" circular action (`coachCyan`), and a `⋯` overflow menu (Schedule / Drop to Squad / Delete). Tapping the row body opens the workout.
- **De-box the row:** today's `SavedWorkoutLibraryRow` is a bordered `surface` card — convert to a **flat row** on `bg` separated by hairline `border` rules (calm-list: no per-item card).
- **Empty state:** when there are no saved workouts, show a calm empty line under SAVED (e.g. "No saved workouts yet — build one or quick-log a session"). The action pair stays visible.
- **Role filter rail:** OUT for now (the per-row ROLE tag already conveys role; the filter rail is chrome). Can return later if the list grows long. (YAGNI.)

### Components & refactor
- **New `SavedWorkoutsInlineList`** (`UNBOUND/Views/Program/MyWorkouts/SavedWorkoutsInlineList.swift`): owns the saved-workout data (`SavedWorkoutStore.shared.all()`), renders the flat rows, and handles delete + the Squad-share sheet locally. Takes `onUseToday: (SavedWorkout) -> Void`, `onSchedule: (SavedWorkout) -> Void`, `onOpen: (SavedWorkout) -> Void` from the parent. This is the saved-list content lifted out of `SavedWorkoutsListView` so it can live inline.
- **`SavedWorkoutLibraryRow`** → moved/renamed into the inline component as a flat calm row (drop the `RoundedRectangle.fill(surface)` + `strokeBorder`; hairline separators between rows instead).
- **`MyWorkoutsView`** becomes: action pair (Quick Log / Build) + `CalmSectionHeader("SAVED", trailing: "\(count)")` + `SavedWorkoutsInlineList`. The old `onOpenSaved` push callback is removed.
- **Retire the `showSavedWorkouts` sheet** in `ProgramOverviewView` (its only entry was the now-deleted push) — confirm via repo grep that nothing else presents `SavedWorkoutsListView`; if another entry exists, keep `SavedWorkoutsListView` as a thin wrapper around `SavedWorkoutsInlineList`. The action callbacks (`onReplaceToday`/`onSchedule`) that ProgramOverviewView wired for the sheet now feed `SavedWorkoutsInlineList` instead.

### Data flow
- Data: `SavedWorkoutStore.shared.all()` (singleton, same source as today). Delete mutates the store + local `@State`.
- `onUseToday` → reuses the existing `onReplaceToday` handler (starts/uses the workout today). `onSchedule` → existing schedule handler. `onOpen` (row tap) → open the workout in the editor/preview (reuse the existing path the sheet used for tapping a saved workout, or `sessionEditorDraft = workout.asDraft(...)`). Share → existing `SquadRoutineDropShareSheet`.
- No data-model changes.

---

## Part 2 — Today's Plan (editorial, no container)

### Layout
```
PUSH · DAY 12   · ● READY            ← eyebrow: headerLabel + status glyph+word (no capsule)
Push Strength                         ← large title, flat on bg
3 moves · ~55 min · 2850 kcal · 180g protein   ← one MetaLine (fuel folded in, no band)
────────────────────────────────────  ← hairline
[img] Barbell Bench Press   4×4-6     ← exercises flow flat, hairline rules
[img] Incline DB Press      3×8-10
[img] Overhead Press        3×5-7
            BEGIN  →                   ← single accent button
```

### Components & refactor
- **`ProgramSelectedDayCard`** stops being a container. Remove the `activeSurface` wrapper (and any residual card padding-as-box). It becomes a flat `VStack` on `bg`: eyebrow (`headerLabel` + status as a small glyph+word, not a capsule) → title → the day `MetaLine` → hairline `Divider` (`Color.unbound.border`) → the `content` (which flows flat) . No fill, no border, no shadow.
- **Fuel band folds into the meta line.** `ProgramFuelTargetBand` is removed from the `dayCard()` content; its values (training-day kcal + protein from `program.nutritionPlan`/`day`) are appended to the day `MetaLine` as plain text (e.g. `… · 2850 kcal · 180g protein`). Compute the fuel summary where the meta is built (presenter or `dayCard()`), reusing `ProgramFuelTargetBand`'s existing calculation logic (extract it to a small helper if needed). Rest days show no fuel numbers (or "rest day").
- **Exercise list** (`ProgramWorkoutExerciseList`): rows already calm from Phase 3 — verify they're flat (thumbnail · name · muscles · reps) on `bg` with hairline separators; adjust if any residual fill remains.
- **Modifier rail / wave panel** (`ProgramModifierSummaryRail`, `ProgramWaveAdjustmentPanel`): already calmed in Phase 3 — keep as quiet text/rows in the flat flow.
- **BEGIN** (`ProgramDayActionRow`): unchanged from Phase 3 (accent fill, no shadow) — now the single emphasized element, sitting at the bottom of the flat flow.
- **`dayCard()` composition** (`ProgramOverviewView+WeekAndDay.swift`): drop `ProgramFuelTargetBand(...)` from the content closure; pass the fuel summary into the card's meta instead.

### Risk
- Dissolving the container changes the Today's-Plan view tree. Gate on the **device-arch build** (`generic/platform=iOS`) — the known metadata-cliff guard. Removing a container layer should reduce nesting (lower risk), but verify; if EXC_BAD_ACCESS/type-check timeout appears, `AnyView`-wrap the heavy children.

---

## Success criteria
- **My Workouts:** on entering the tab, the saved workouts are visible and readable inline (no extra tap). Quick Log + Build are small secondary buttons, not large blocks. Saved rows are flat (no per-item card box). Use-today / schedule / share / delete all work as before.
- **Today's Plan:** no wrapping fill block; the day reads as a flat editorial header + flowing exercise list; fuel is plain text in the meta line (no band/pill); BEGIN is the only accent element.
- Calm-list compliant: zero cards/pills/shadows/accent-bars except the BEGIN accent fill.
- `xcodebuild` green on iOS Simulator **and** `generic/platform=iOS`.

## Out of scope
- Routines tab, Home, Ranks, Skills/Squad/Profile.
- The saved-workout role-filter rail (deferred), search.
- Data-model / program-generation / nutrition-calculation logic (style + composition only; reuse existing fuel computation).
- Session-editor header (still blocked) and `WorkoutDetailView` (still deferred).

## Open questions
- **Row tap target vs ↻:** row-body tap = open the workout (editor/preview); ↻ = use today (start now). Confirmed reusing existing semantics; if "open" should instead immediately start, collapse the two — settle during implementation.
