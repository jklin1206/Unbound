# Frontend Redesign — Handoff

**Branch:** `frontend-redesign` (base/fallback: `codex/program-per-set-control`)
**Spec:** `docs/superpowers/specs/2026-06-08-program-frontend-redesign-design.md`
**Goal:** Replace the "box-soup" style across the Program / logging screens with a
calm, scannable "calm-list" language; make logging fast. Dark-mode only app.

> ⚠️ A **Codex session edits this repo concurrently** (assets, models:
> ActiveWorkoutSession / TrainingSessionDraft / TrainingWeightPolicy, exercise
> art). Commit with **explicit paths**, never `git add -A`, or you'll sweep its
> in-flight work into your commit (this already happened once — see commit notes).

---

## State: what's done

All committed on `frontend-redesign`. Build is green (iOS Simulator, Debug) at
each commit.

| Commit | What |
|---|---|
| `453480a` | baseline snapshot of the working tree |
| `d50a8ee` | the design spec |
| `6f84fec` | **Phase 1a** — calm look for active-workout logging (`ExerciseLogCard`, `SetLogGridRow`, `WorkoutLogGridView`) |
| `1fc1231` | dropped the left accent bar; active = fill-only `surfaceElevated` panel; dividers `border` |
| `1d731d4` | removed left bar from rank-trial card too |
| `1af8a13` | `-activeWorkoutDemo` dev launch arg (verify the logging screen on-sim) |
| `6ee8a52` | **Phase 1b** — bottom-docked numeric keypad + RPE quick-pick; removed "NOW" label |
| `7af001e` | **Phase 2** — calm-list the session-editor *rows*; `-sessionEditorDemo` launch arg |

**Note on `6ee8a52`:** it accidentally bundled two Codex-authored files
(`ExerciseVisualView.swift` +64, `MovementResolverTests.swift` +19 — exercise-art
resolution) that landed in the tree concurrently. They build fine; just not mine.

### Calm-list primitives (reuse these on every screen)
- `MetaLine` (`Views/Components/Unbound/CalmList.swift`) — `·`-joined plain text; replaces pills.
- `activeSurface(_:)` (same file) — the ONLY active-item emphasis: fill-only `surfaceElevated` panel. **Never a left bar** (hard user rule).
- `InlineNumberPad` + `InlineRPEPicker` + `bottomDock()` (`Views/Components/Unbound/InlineNumberPad.swift`) — bottom-docked logging controls.

### Dark palette (fixed hex, no light mode)
`bg #050505`(~2%) → `surface #121212`(~7%) → `surfaceElevated #1A1A1A`(~10%) →
`borderSubtle #1F1F1F`(~12%) → `border #262626`(~15%). Steps are tiny — use
`border` (not `borderSubtle`) for dividers that need to read on `bg`.

### How to verify on-sim (DEBUG launch args)
```
xcodebuild build -project UNBOUND.xcodeproj -scheme UNBOUND \
  -destination 'platform=iOS Simulator,id=<booted-sim-udid>' \
  -configuration Debug -derivedDataPath /tmp/unbound-dd CODE_SIGNING_ALLOWED=NO
xcrun simctl install booted /tmp/unbound-dd/Build/Products/Debug-iphonesimulator/UNBOUND.app
xcrun simctl launch booted com.unboundapp.ios -activeWorkoutDemo   # logging screen
xcrun simctl launch booted com.unboundapp.ios -sessionEditorDemo   # workout builder
xcrun simctl io booted screenshot /tmp/shot.png
```
Harness sources: `ActiveWorkoutDemoHarness.swift`, `SessionEditorDemoHarness.swift`.

---

## State: what's NOT done (and why)

### 1. Session-editor HEADER — BLOCKED by a SwiftUI compiler crash
De-boxing `SessionEditorView+Header.swift` (Close pill, title field, ADD EXERCISE
button) **deterministically crashes** the editor on launch — EXC_BAD_ACCESS /
`swift_retain` on a garbage pointer inside `ViewBuilder.buildExpression` in
`SessionEditorView.body`. Confirmed mine, not Codex, via back-to-back rebuilds
(original header ALIVE 3/3, calm header CRASH 3/3).

Tried & failed: overlay-underline, sibling-underline, AnyView-wrap-all-children,
**and a real `EditorScrollContent` struct extraction**. The extraction *fixed*
the `builderHeader` crash but the corruption **relocated to `bottomStartBar`** —
it's whack-a-mole: the whole `SessionEditorView` file compiles as one fragile
unit. Full details + the diagnosis in the `session-editor-body-metadata-cliff`
memory.

**Next move (do when Codex is OFF these files):**
1. First try a **clean build** (fresh derivedData) with a minimal calm header —
   small chance it's a stale-incremental codegen artifact, not a true cliff.
2. If it still crashes: **decompose the whole editor view** — extract `header`,
   `builderHeader`, the ScrollView content, and `bottomStartBar` into separate
   `View` structs (each its own compilation/metadata unit), THEN apply the calm
   header. Editor *rows* are already calm and shipped, so this is header-only.

### 2. `WorkoutDetailView` — deferred (legacy palette)
The read-only "view workout" screen is on the **legacy `Color.theme`** palette
(16 refs), not `Color.unbound`. Making it calm = a palette migration too. Its own
focused pass.

### 3. Phase 3–4 (not started)
Program overview + command-dock + day cards (Phase 3); supporting sheets
(`SkillQuickLogSheet`, `SkillSessionView`, ready/summary) (Phase 4). Phase 3 is a
good "Codex-isn't-touching-it" next target.

### Open design question (unanswered by user)
Active-exercise panel "pop": the `surfaceElevated` lift is quiet by palette
design. Leave it, or nudge brighter? No decision yet.

---

## Hard user rules (locked)
- **Never** a left-edge accent bar/spine for active/selected — use a fill surface.
- **Don't restate what the UI already shows** (removed "NOW"; hunt for more like "TAP TO OPEN").
- Sweep all program screens eventually, but staged + checkpointed.

## Loose ends
- Local screenshots are in `/tmp/` (ephemeral): `p1b_resting.png`, `p1b_keypad.png`, `p2_editor.png`, `active_real.png`.
- 23 uncommitted files in the tree are **Codex's** (assets/models/tests) — leave them; don't `git add -A`.
