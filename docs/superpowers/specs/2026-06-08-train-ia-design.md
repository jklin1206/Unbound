# Train Tab + My Workouts — IA Design

**Branch:** `frontend-redesign`
**Date:** 2026-06-08
**Related spec:** `docs/superpowers/specs/2026-06-08-program-frontend-redesign-design.md` (calm-list visual language)
**Goal:** Make the app program-flexible, not program-forced. Logging your *own*
workout should be a first-class, ~3-tap path — without exploding the app with
features. This is an information-architecture (IA) restructure that **absorbs and
extends** the in-flight calm-list redesign (Phase 3) rather than replacing it.

## Problem

Today the app is program-first. The generated program owns the "Program" tab;
everything a user might do on their own — saved workouts, building a workout,
the exercise library — is buried 3–4 taps deep inside the Program tab's
`ProgramCommandDock`. There is no fast "just let me log what I'm doing right now"
path. The result: a user who wants to train off-program is a second-class
citizen.

## Decisions (locked with user)

1. **Two→three equal modes, not one forced program.** The user explicitly wants
   the program and free workouts to coexist as peers (chosen: "two equal modes,"
   then expanded to keep Routines as a third).
2. **Rename the `Program` tab → `Train`.**
3. **`Train` has 3 sub-tabs:** `Today's Plan` (default) · `My Workouts` (new) ·
   `Routines` (kept). The old `Ranks` sub-tab is removed from Train.
4. **`My Workouts` contains exactly three things:** ⚡ Quick Log · ＋ Build ·
   📁 Saved. (Single-exercise logging and a separate "exercise library" entry
   were considered and cut — Quick Log covers "log one thing.")
5. **`Ranks` moves to Home** as a *compact card* (aggregate tier + "near
   rank-up" hint) that opens the full rank library. The full library is **not**
   embedded inline on Home.
6. **Calm-list everywhere.** Every screen in this structure follows the existing
   calm-list visual language (no cards/pills/shadows; `MetaLine`;
   `activeSurface` for emphasis; dark palette).
7. **3-tap rule.** Any primary destination is reachable in ≤3 taps.

### Approaches considered & rejected
- **Ranks → Skills tab** (it's progress/reference, and a Skills tab exists).
  Rejected by user: "feels wrong." → Ranks goes to Home instead.
- **Drop Routines.** Rejected: Routines are "super important."
- **Keep program as the single spine with one escape hatch** (Approach A in
  discussion). Rejected in favor of co-equal modes.
- **Full rank library inline on Home.** Rejected: Home is already busy; would
  feel feature-exploded.

## Navigation structure

```
Bottom tabs (5, unchanged count):  Home · Train · Skills · Squad · Profile
                                          └── was "Program"

Train tab — 3 sub-tabs (top selector):
  ▸ Today's Plan   (DEFAULT)  the program: week strip · day card · BEGIN
  ▸ My Workouts    (NEW)      ⚡ Quick Log · ＋ Build · 📁 Saved
  ▸ Routines                  curated cardio / mobility / challenges (unchanged)

Home tab:
  … existing briefing / training console / body-load heatmap / recap …
  + Ranks card  → opens the full rank library (ProgramRankLibraryView)
```

Tap-cost check (all ≤3):
- Quick Log: Train → My Workouts → ⚡ Quick Log = **3**
- Saved workout: Train → My Workouts → tap workout = **3**
- Routine: Train → Routines → tap routine = **3**
- Today's program: Train → BEGIN = **2**
- Ranks: Home → Ranks card → library = **3**

## Components

### What is reused as-is (no new feature work, just re-surfaced)
| Capability | Existing component |
|---|---|
| Today's Plan view | `ProgramOverviewView` program sub-tab + `Overview/*` |
| Saved workouts | `SavedWorkoutsListView` |
| Build a workout | `SessionEditorView` (+ rows already calm, Phase 2) |
| Routines | current Routines sub-tab (`Routines/ProgramRoutineViews.swift`) |
| Rank library | `ProgramRankLibraryView` + `RankLibrary/*` |
| Active logging + add-exercise-on-the-fly | `ActiveWorkoutContainerView` / `ActiveWorkoutSession.appendCustomExercise(_:)`, `addSet(toExerciseIndex:)` |

### What is net-new (small)
1. **Tab rename + sub-tab swap.** `HomeTabView` tab label `Program`→`Train`;
   `ProgramOverviewView.Tab` enum: drop `.ranks`, add `.myWorkouts`; relabel
   `.program`→"Today's Plan". Update `ProgramOverviewChrome`'s tab selector.
2. **`My Workouts` landing screen.** A new calm-list view that composes:
   - a hero **⚡ Quick Log** action (the one emphasized element),
   - a **＋ Build a new workout** row (→ `SessionEditorView`),
   - a **Saved** section (the `SavedWorkoutsListView` content, inlined or pushed).
   This screen mostly *arranges* existing pieces; it adds no new data model.
3. **Quick Log entry.** Create an empty `TrainingSessionDraft` (source `.custom`,
   no blocks) → launch `ActiveWorkoutContainerView`. The user adds exercises and
   sets mid-session via the existing `appendCustomExercise` / `addSet` paths. The
   only new code is the empty-draft factory + the launch wiring.
4. **Home Ranks card.** A compact card in `UnboundHomeView` (Home already holds
   `aggregateTier` state) that presents `ProgramRankLibraryView`.

### Side effect (a simplification, not extra work)
The Saved / Build / Library entries currently living in `ProgramCommandDock`
(1,148 lines) **move out** to `My Workouts`. The dock on the Today's Plan side
therefore *shrinks*, which makes the Phase-3 calm pass on it easier, not harder.

## Data flow

- **Quick Log:** `My Workouts` → empty-draft factory → `@State activeWorkoutDraft`
  → `ActiveWorkoutContainerView(session:)`. Exercises/sets added live; on finish,
  the same completion/reward path as any logged session runs. No schema change.
- **Saved/Build/Routines:** unchanged data flow; only their entry point moves.
- **Ranks:** Home card reads existing `aggregateTier`; "View →" presents
  `ProgramRankLibraryView` (same view, new launch site). The `.ranks` sub-tab and
  its launch in `ProgramOverviewView` are deleted in the same change.

## Relationship to the calm-list redesign

"Today's Plan" *is* the Phase-3 surface (`ProgramSelectedDayCard`,
`ProgramWeekStrip`, `ProgramDayActionRow`, `ProgramCommandDock`). The calm-list
pass on those screens happens *inside* this restructure. `My Workouts` is built
calm from day one. This spec therefore **supersedes the standalone Phase 3** in
the redesign handoff; Phases 1–2 (active logging, editor rows) are already
shipped and unaffected. The blocked session-editor *header* and the deferred
`WorkoutDetailView` remain parked exactly as the handoff describes.

## Scope & staging

Build incrementally; never go dark. Each phase ends with a build + simulator
screenshot + checkpoint. Concurrency note: a Codex session is live in the
program-generation / weight-policy / ActiveWorkout *model* files — commit with
explicit paths (never `git add -A`).

| Phase | Work |
|---|---|
| **A — shell** | Rename Program→Train; `.ranks`→removed, add `.myWorkouts` sub-tab; relabel Today's Plan. Stub `My Workouts` landing. Build + shot. |
| **B — My Workouts** | Build the calm `My Workouts` landing (Quick Log hero + Build row + Saved section); wire Quick Log empty-draft → ActiveWorkout. Build + shot. |
| **C — Ranks to Home** | Add compact Ranks card to Home → present rank library; delete the old `.ranks` sub-tab launch. Build + shot. |
| **D — calm Today's Plan** | The Phase-3 calm pass on the now-simpler Today's Plan surface (week strip, day card, action row, slimmed dock). Build + shot. |

A demo harness (`-trainTabDemo` / extend the existing proof launch args) is built
in Phase A so each surface is screenshot-verifiable on-sim (no populated-program
harness exists today — this is the current verification gap).

## Success criteria

- Quick Log: Train → My Workouts → ⚡ Quick Log opens an empty session you can
  add exercises/sets to and finish — **3 taps, no new data model.**
- Saved / Build / Routines reachable in ≤3 taps from the Train tab.
- Ranks reachable from Home (card → library) in 3 taps; gone from Train.
- No net increase in tab count or sub-tab count beyond the locked structure;
  no new top-level concepts.
- Every redesigned screen is calm-list compliant (no cards/pills/shadows; only
  the active element lifted; no left-edge accent bar).
- `xcodebuild` green on iOS Simulator **and** `generic/platform=iOS`.

## Out of scope

- Reward-sequence visuals, onboarding, program-generation / data-model logic.
- Single-exercise "log one move" library entry (cut — Quick Log covers it).
- Re-adding a standalone Routines-into-My-Workouts entry (Routines stays its own
  sub-tab).
- The session-editor header de-box (still blocked) and `WorkoutDetailView`
  palette migration (still deferred).

## Open questions

- **Quick Log default unit/metric:** empty session needs a sensible default
  weight unit + metric kind per added exercise — confirm it inherits the user's
  unit preference (likely already handled by `ActiveWorkoutSession`).
- **Saved section in My Workouts:** inline the list vs. a "Saved" row that pushes
  `SavedWorkoutsListView`. Lean inline for fewer taps; settle during Phase B.
