# Routine Player Redesign — Typed Steps, No Logging — Design Spec

**Date:** 2026-05-17
**Branch:** `program-redesign` · UNBOUND iOS
**Type:** Feature redesign — routine/challenge flow + data model
**Sub-project:** 1 of 2. Sub-project 2 (next) = the cross-cutting "insane"
cinematic reward screen, which consumes this sub-project's completion record
and also covers program-workout rewards. Out of scope here.

## Context

Routines (the "Routines" tab: Cardio / Mobility / Challenges / Alt Circuits)
are **pre-set workouts** — the user just goes through them. The current
implementation treats them as a logging workout, which is the flaw:

1. `RoutineDef.steps` is `[String]` of free-text prose
   (`"Set a timer"`, `"Standard form: chest to 1 inch from floor"`,
   `"Warning: most people DNF after Gate 5. That's the point."`).
2. `RoutineDef.sideQuest` runs `RoutineStepParser` — a brittle regex that
   mangles each prose line into a fake `SideQuestExercise` (guessing
   name/sets/reps/rest).
3. `SideQuestPlayerView` plays the result as a **set-logging workout**: rep
   stepper, "LOG SET" button, set dots, per-set `SideQuestSetLog`.

So instructional, cue, and warning lines each become a loggable "exercise"
with a rep counter. There is no genuine routine the user is being walked
through — just a parser hallucinating sets out of prose.

**No routine History exists today.** `refreshHistory()` fetches only
*program* workout logs (`services.workoutLog.fetchRecentLogs`). The
`SideQuestLog` the player builds is **discarded**: `completeRoutine` uses only
`log?.setLogs.count` for a reward number and calls `RoutineCompletionStore`
(UserDefaults: 24h cooldown + a `unbound.gains` SP bump). Per-set logging
feeds nothing durable. Retiring the logging path is therefore safe.

Classifying all 20 placeholder routines, every one collapses to a **guided
step sequence** where each step is exactly one of five kinds. None need set
logging. The fix is two-fold: (1) replace `[String]` + parser with a typed
step model; (2) replace the logging player with a step-sequence player whose
only jobs are *show the current step, give a time reference when the step is
timed, advance to the next* — and persist a lightweight, progression-capable
completion record.

## Locked decisions (from brainstorming dialogue)

1. **Typed steps, hand-authored.** `RoutineStep` enum (below). All 20
   routines re-authored into it. `RoutineStepParser`, `RoutineDef.sideQuest`,
   `SideQuest`, `SideQuestExercise`, `SideQuestLog`, `SideQuestSetLog`,
   `SideQuestPlayerView` are retired.
2. **No set logging.** No rep stepper, no "LOG SET", no set dots in the
   player. Completion = the user went through the routine.
3. **Five step kinds + nested circuit + note.** instruction / timed /
   interval / repTarget / circuit / note.
4. **Circuits are nested.** `.circuit(rounds, restBetweenSeconds, steps)`.
   The player shows "ROUND k/N" and auto-inserts a `.timed(.rest)` between
   rounds. Honest data; real progress.
5. **repTarget = log-after-effort, not tap-during.** The user does a burst
   off-screen, returns, dials the count they just did on a large
   stepper/number entry, taps **ADD** (one recorded burst), rests freely,
   repeats until the running total ≥ target, then **DONE** (or "I'M DONE" to
   stop early / when `target == nil` / AMRAP). Each ADD is one burst —
   yielding the "100 in 4 sets: 35/30/20/15" progression data naturally,
   with no silent set detection.
6. **Completion record is local-first, progression-capable.**
   `RoutineCompletionRecord` persisted to App Support JSON (mirrors
   `WorkoutDraftStore`/`ProgramStore`). Schema is backend-adoptable later
   (the existing "Real RoutineService will replace this" note).
7. **Existing completion API is preserved.** `RoutineHistoryStore` keeps
   `canComplete(routineId:)` / 24h cooldown / `unbound.gains` SP bump with
   the same signatures, so the three call sites
   (`RoutineChallengeCard` ~2174, the detail-sheet completion ~2763/2777)
   do not change. It only *adds* `record(...)` and `history(routineId:)`.
8. **Reward screen is NOT redesigned here.** `RoutineRewardPayload` /
   `RoutineCompletionRewardView` stay; they are fed real mode-appropriate
   values (time / count, never fabricated sets). The cinematic upgrade is
   sub-project 2.

## Per-routine classification (the investigation)

| Routine(s) | Step shape |
|---|---|
| 20-min Zone 2 walk, 30-min easy bike | guidance `.note`s + one `.timed(work)` headline duration |
| 15-min HR intervals | `.timed` warmup + `.interval(rounds:5, [work 60, easy 60])` + `.timed` cooldown |
| Plank ladder | `.interval`-style via explicit `.timed` ladder (30/45/60/75/90) with `.timed(.rest)` 30 between |
| Tabata core | `.interval(rounds: 8, [work 20, rest 10])` with the 4 rotating move labels as the segment/round label |
| Morning mobility, Evening stretch, Hip flow | sequence of `.instruction` (rep moves) and `.timed(work)` (timed holds) |
| 100 pushup challenge | one `.repTarget(name:"Push-ups", target:100)` + form `.note` |
| 8 Gates, Beach Forge, Underground Grind, 3D, Thunder, Gravity, Vessel, Daily Quest, Saitama | `.instruction` steps + `.timed(.rest)` for explicit rests + `.note` for warning/inspiration lines; the looped portions wrapped in `.circuit` |
| Bodyweight full-body, Dumbbell full-body | `.circuit(rounds:3, restBetween:60/90, [.instruction × moves])` |

The exact authored content for all 20 is produced in the implementation plan
(one task), not enumerated here — but every routine maps to the above.

## Architecture

### Model (new — `UNBOUND/Models/RoutineStep.swift`)

```swift
enum TimedStyle: String, Codable, Hashable { case work, rest }

struct IntervalSegment: Codable, Hashable {
    let label: String      // "WORK" / "REST" / "Mountain climbers"
    let seconds: Int
}

indirect enum RoutineStep: Codable, Hashable {
    case instruction(text: String, cue: String?)
    case timed(label: String, seconds: Int, style: TimedStyle)
    case interval(label: String, rounds: Int, segments: [IntervalSegment])
    case repTarget(name: String, target: Int?, cue: String?)   // nil target = AMRAP
    case circuit(rounds: Int, restBetweenSeconds: Int, steps: [RoutineStep])
    case note(text: String)                                    // context, never advanced through
}
```

`RoutineDef` (in `ProgramOverviewView.swift` — moved to its own file as part
of this work, see below) changes its `steps` from `[String]` to
`[RoutineStep]`. `note` cases are extracted from the main flow by the player
and shown as context (on the relevant step header / the complete screen),
never as an advanceable step.

`RoutineDef` + `RoutineCategory` + `RoutineLibrary` + `RoutineChallengeCard`
+ `RoutineCompletionStore` currently live inside the 3478-line
`ProgramOverviewView.swift`. Move `RoutineDef`/`RoutineCategory`/
`RoutineLibrary` into `UNBOUND/Models/Routine.swift` (which is being emptied
of `SideQuest*` anyway) so the model is one focused file. `RoutineChallengeCard`
(a private view) stays in `ProgramOverviewView.swift`.

### Runtime expansion (new — `UNBOUND/Models/RoutineRun.swift`)

Pure, unit-tested. Flattens an authored `[RoutineStep]` into an ordered list
of runtime steps the player walks:

```swift
struct RoutineRunStep: Identifiable, Hashable {
    let id: Int                 // stable index in the run
    let kind: RoutineStep       // never .circuit (expanded) or .note (filtered)
    let roundLabel: String?     // "ROUND 2 / 3" when inside a circuit, else nil
}

enum RoutineRun {
    /// Expands .circuit into round-tagged copies of its inner steps with a
    /// .timed(.rest, restBetweenSeconds) inserted between rounds (not after
    /// the last). Filters .note out of the walk list. Returns the flat run +
    /// the collected notes (for context display).
    static func build(_ steps: [RoutineStep]) -> (run: [RoutineRunStep], notes: [String])
}
```

### Player (rewrite `UNBOUND/Views/Routine/RoutinePlayerView.swift`)

`SideQuestPlayerView` is deleted. New `RoutinePlayerView`:

```swift
struct RoutinePlayerView: View {
    let routine: RoutineDef
    let onComplete: (RoutineCompletionRecord) -> Void
    // ...
}
```

Owns: `runIndex`, the `RoutineRun.build` output, a 1 Hz clock for
`elapsedSeconds`, per-step transient timer state, and `bursts: [Int]` for the
current `repTarget`. Renders the current `RoutineRunStep.kind` in its face.
No rep stepper, no LOG SET, no set dots, no `SideQuestSetLog`.

Faces:

- **instruction** — large readable instruction (display/body scale), the
  `cue` muted beneath, a thin progress rail ("STEP k OF N" + `roundLabel` if
  any). One full-width primary **DONE** → advance. `note` context (if any
  for this routine) accessible via a small ⓘ, not inline clutter.
- **timed** (`.work`/`.rest`) — reuse the **existing** draining ring from the
  current `restView` verbatim (it is already premium): big mono countdown,
  the `label`, auto-advance at 0 with a `success` haptic + spring to next,
  `+30s` and `SKIP` as low-emphasis controls. `.rest` styled recovery
  (textTertiary ring track, no category glow); `.work` uses category color.
- **interval** — the ring + "ROUND k / N" + current segment `label` and
  remaining seconds; auto-cycles segments, then rounds; `SKIP ROUND`. Last
  3s of a segment: ring pulse + soft ticks (reuse the existing tick pattern).
- **repTarget** — the headline number is the **running total vs target**
  (`55 / 100`, or just `55` when `target == nil`). A large stepper/number
  entry (`StepperControl`-style: −/＋, long-press repeat, tap-to-type, step 1,
  default seeded to a sensible burst like 10) for "reps you just did", and a
  full-width **ADD** that appends the dialed value to `bursts`, bumps the
  total with a spring + medium haptic, and resets the entry. A small inline
  ledger of logged bursts (`35 · 30 · 20`). When `total ≥ target` (or any
  time when `target == nil`): the primary becomes **DONE** with a target-hit
  violet bloom (the one allowed dramatic moment in this player). An always-
  available "I'M DONE" secondary lets the user stop early.
- **complete** — clean, functional (NOT the cinematic sub-project-2 screen):
  headline = mode-appropriate primary metric (time / `total reps in M sets`
  / steps done) + "Done N times · best <metric>" pulled from
  `RoutineHistoryStore.history(routineId:)` + `+SP` + **RETURN**. Builds the
  `RoutineCompletionRecord` and calls `onComplete`.

Exit/abandon: the ✕ keeps the existing behavior (dismiss); abandoning does
**not** record completion or award SP (consistent with today — only the
finish path awards).

### Completion record + history store

`UNBOUND/Models/RoutineCompletionRecord.swift`:

```swift
enum RoutineMetric: Codable, Hashable {
    case time(seconds: Int)                       // timer / interval / checklist headline
    case repCount(total: Int, bursts: [Int])      // repTarget
    case steps(done: Int, total: Int)             // instruction-heavy routine headline
}

struct RoutineCompletionRecord: Codable, Identifiable, Hashable {
    let id: String
    let routineId: String
    let completedAt: Date
    let elapsedSeconds: Int          // always captured (every routine yields time-on-task)
    let primaryMetric: RoutineMetric // what the complete screen leads with
    let spAwarded: Int
}
```

**`primaryMetric` selection rule (deterministic, pinned here so the plan is
unambiguous):** if the run contains any `repTarget` →
`.repCount(total, bursts)` from that step (if multiple repTargets, sum totals
and concatenate bursts). Else if the run is *timer-dominant* — its single
longest `.timed`/`.interval` block is ≥ 50% of total `elapsedSeconds` (e.g.
the 20-min walk, 30-min bike, HR intervals, Tabata, plank ladder) →
`.time(elapsedSeconds)`. Else (instruction-dominant: mobility flows, the
prose challenges/circuits) → `.steps(done: completedRunSteps,
total: runStepCount)`. `elapsedSeconds` is always stored regardless; the rule
only chooses the *headline*.

`UNBOUND/Services/Routine/RoutineHistoryStore.swift` — `@MainActor`, local
JSON in App Support (`routine-history.json`), pattern copied from
`WorkoutDraftStore` (not the file). API:

- **Preserved (signatures identical to today's `RoutineCompletionStore`):**
  `static func canComplete(routineId:) -> Bool`,
  `static func lastCompleted(routineId:) -> Date?`,
  `@discardableResult static func complete(_ routine: RoutineDef) -> Bool`
  (24h cooldown + `unbound.gains` bump — copied verbatim so call sites at
  `ProgramOverviewView` ~2174 / ~2763 / ~2777 are untouched).
- **Added:** `static func record(_ rec: RoutineCompletionRecord)` (append +
  persist), `static func history(routineId:) -> [RoutineCompletionRecord]`
  (sorted), and a derived `static func summary(routineId:) -> (count: Int,
  best: RoutineMetric?)?` for the complete screen / future reward screen.

`RoutineCompletionStore` is renamed to `RoutineHistoryStore`; the old name is
removed (it is only referenced in `ProgramOverviewView.swift` — verified —
so the three references are updated in the same edit).

`completeRoutine(_:log:)` in `ProgramOverviewView.swift` changes signature to
`completeRoutine(_ routine: RoutineDef, record: RoutineCompletionRecord)`:
calls `RoutineHistoryStore.complete(routine)` (unchanged award/cooldown),
`RoutineHistoryStore.record(record)`, builds `RoutineRewardPayload` from the
record's real values (`elapsedSeconds`, and for `.repCount` the
`bursts.count` as "sets" + `total`; for others `completedSets/totalSets`
become a `stepsDone` count or are 0), then `refreshHistory()` (unchanged —
still program logs only; routine history is read directly from the store
where shown).

### Retire / delete

- `SideQuest`, `SideQuestExercise`, `SideQuestLog`, `SideQuestSetLog` —
  `UNBOUND/Models/Routine.swift`. **Guard:** grep co-located types first;
  `SideQuestCategory` is referenced by the current `SideQuestPlayerView`
  styling — once that view is deleted, confirm no other referencer (Home,
  Program) before removing `SideQuestCategory`; if any remain, keep it.
- `RoutineStepParser`, `RoutineDef.sideQuest`, `RoutineCategory.sideQuestCategory`
  — `ProgramOverviewView.swift`.
- `SideQuestPlayerView` — replaced by the new `RoutinePlayerView` in the same
  file.
- The `.fullScreenCover(item: $activeRoutinePlayer)` body changes from
  `SideQuestPlayerView(routine: routine.sideQuest) { log in completeRoutine(routine, log: log) }`
  to `RoutinePlayerView(routine: routine) { rec in completeRoutine(routine, record: rec) }`.

### Reused (do not rebuild)

- The draining-ring countdown + tick/`success` haptic pattern from the
  current `restView` (lift it into the new player's timed/interval faces).
- `StepperControl` (existing component from sub-project A) for the repTarget
  entry — do not build a new stepper.
- `UnboundHaptics`, `Color.unbound.*`, `Font.unbound.*` tokens.
- `RoutineRewardPayload` / `RoutineCompletionRewardView` (fed real values).
- `WorkoutDraftStore` file-persistence pattern (copy approach, not file).

## Design bar (non-negotiable — per project memory)

Premium-native, not brutalist; quiet default, one dramatic moment. The
player is restrained: charcoal surfaces, the category/accent color used only
on the primary action and the active ring. The single "moment" in this
sub-project is the `repTarget` target-hit bloom — everything else is calm
(the cinematic celebration is sub-project 2). Reuse the existing ring exactly;
introduce no new palette. ≥56pt hit targets, ≥13pt text, 8pt grid,
thumb-reachable primary in the bottom third, `prefers-reduced-motion`
collapses motion to fades and keeps haptics. Every face is reviewed
on-device via screenshot (active instruction / timed / interval / repTarget
add+hit / complete) before its task is marked done. A face is not done if it
looks like a generic form.

## Testing / verification

- **TDD (pure units):**
  - `RoutineRun.build` — `.circuit` expands to `rounds × innerSteps` with a
    `.timed(.rest, restBetweenSeconds)` between rounds (not trailing) and
    correct `roundLabel`; `.note` filtered into `notes`; nested order
    preserved; empty/edge cases.
  - `RoutineCompletionRecord` / `RoutineMetric` Codable round-trip.
  - `RoutineHistoryStore` — `record` then `history` round-trips and survives
    a fresh store; `summary` computes count + best (max reps / min time);
    `canComplete`/24h/gains parity with the old `RoutineCompletionStore`
    (regression: same cooldown + same `unbound.gains` delta).
  - All 20 authored routines: a `RoutineLibraryTests` asserts each produces a
    non-empty run, every `.timed`/`.interval` has positive seconds, every
    `repTarget` target is nil or > 0, no `.note` leaks into the run.
- `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build`
  → `** BUILD SUCCEEDED **`; `… test` → green except the known pre-existing
  `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap; zero NEW
  failures. SourceKit cross-file noise ignored per project rule.
- On-device (jlin): open 4 representative routines — a duration timer
  (20-min walk → big countdown, no sets), an interval (Tabata → ROUND k/8
  auto-cycle), a checklist challenge (8 Gates → instruction → DONE → next,
  rests auto-run, warnings as context not steps), and 100-pushup
  (do reps → dial count → ADD → total climbs → DONE at 100). Confirm the
  complete screen shows the right metric + "Done N times".

## Out of scope

The cinematic "insane" reward screen (sub-project 2 — also covers
program-workout rewards), routine generation / `RoutineService` backend,
cross-device sync of routine history, editing routines, supersets beyond the
nested `.circuit`, Apple Watch.

## Execution

Subagent-driven (fresh subagent per task, spec-then-quality review at the
seam), Sonnet minimum, scoped `git add` (no `git add -A`), co-authored
trailer, on-device sign-off by jlin. Branch `program-redesign`.
