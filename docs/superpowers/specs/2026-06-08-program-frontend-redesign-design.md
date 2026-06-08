# Program Frontend Redesign — "Calm List" Design

**Branch:** `frontend-redesign`
**Date:** 2026-06-08
**Goal:** Replace the box-soup style across the Program / logging screens with a
calm, scannable visual language that makes logging fast. Logging-first.

## Problem

The current program screens (worst offender: in-workout `ExerciseLogCard`) nest
boxes inside boxes: a shadowed/bordered card → bordered metadata "pills" →
bordered number cells. And logging an actual weight/reps opens a separate
656-line `SetLoggerSheet` modal — the fast path is only "confirm as planned."
The result is visually heavy and slow to log into.

## Visual language ("Calm List")

The rules every redesigned screen follows:

1. **No per-item cards.** Items flow as one continuous list separated by hairline
   rules (`Color.unbound.borderSubtle`). No card fills, no drop shadows.
2. **No pills.** Metadata is plain `·`-joined text (`3×8 · RPE 8 · rest 1:30`) in
   `textSecondary`. Never capsules.
3. **Emphasis is earned.** Only the *active / current / selected* item is lifted:
   a 3pt left accent bar + a faint `surface` wash + (in logging) its set grid
   expanded. Everything else sits flat on `bg`.
4. **Numbers are the hero.** Monospaced, large, high-contrast when logged/edited;
   dim (`textTertiary`) when they're only the program suggestion.
5. **Status = one glyph** (`✓` logged / `○` pending), never a boxed button.
6. **Breathing room.** Generous vertical rhythm; small tracked tertiary section
   headers (`PUSH · DAY 12`) for context, not chrome.
7. **Keep the exercise thumbnail** (58pt) as the leading anchor of each exercise.

## Shared primitives (build once, reuse on every screen)

- `MetaLine` — builds the `·`-joined plain-text metadata string; replaces every
  pill row in the app.
- `CalmSectionHeader` — small tracked caption + optional trailing meta.
- `ActiveAccent` (ViewModifier) — the "this is current/selected" treatment (left
  bar + wash); identical on every screen.
- `InlineNumberPad` — bottom-docked numeric keypad accessory (see below).
- RPE quick-pick — compact 1–10 picker rendered in the same bottom zone.

## Logging interaction

- Tapping a weight / reps / metric value highlights that cell and **auto-pops a
  numeric keypad docked at the bottom of the screen** (accessory bar, not a
  modal, not anchored under the exercise). Digits + decimal (weight only) + `⌫`
  + `done`. Live-updates the cell as you type; `done` or tapping the next cell
  commits and auto-advances.
- The `○ → ✓` glyph still logs the set in **one tap**, auto-filling suggested
  values if untouched — the fast "log as planned" path survives.
- Tapping **RPE** opens its **own** compact 1–10 quick-pick in the bottom zone
  (not the numeric keypad).
- Keypad/labels adapt to metric kind (reps / hold-secs / distance / cal) + unit.
- This replaces the in-row use of `SetLoggerSheet` for set editing.

## Scope & staged order

All program screens move to the new language, but staged so we never go dark —
each phase ends with a build + simulator screenshot + checkpoint.

| Phase | Screens |
|---|---|
| **0** | Build the shared primitives; mark old pill/card/shadow patterns for removal |
| **1 — flagship** | Active workout logging: `ExerciseLogCard`, `SetLogGridRow` → inline keypad, `WorkoutLogGridView`, bottom keypad + RPE quick-pick |
| **2** | `WorkoutDetailView` + Session builder/editor (`SessionEditorView` + rows) |
| **3** | Program overview + `ProgramCommandDock` + day cards |
| **4** | Supporting sheets: `SkillQuickLogSheet`, `SkillSessionView`, ready/summary |

**Hard checkpoint after Phase 1** — that's where the language lives or dies.

## Success criteria

- Logging a custom weight/reps set: tap cell → keypad auto-up → type → next,
  with **no full-screen modal**. "Log as planned" stays **1 tap**.
- Redesigned logging list has **zero** pills/cards/shadows; only the active
  exercise is visually lifted; thumbnail retained.
- RPE entry is its own quick-pick, not the numeric keypad.
- `xcodebuild` green on iOS Simulator **and** `generic/platform=iOS` (device-arch
  is the real gate).

## Out of scope

- Reward sequence visuals, onboarding flow (except program previews if Phase 3
  touches them), data model / program-generation logic. Style only.
