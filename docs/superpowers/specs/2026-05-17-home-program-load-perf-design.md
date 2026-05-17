# Home / Program Load Performance — Design Spec

**Date:** 2026-05-17
**Branch:** `program-redesign` · UNBOUND iOS
**Type:** Performance fix (load orchestration) — no feature/UI change

## Context

Home and Program take 2–5 s to show because `UnboundHomeView.load()`
(`UnboundHomeView.swift:1825-1890`) and `ProgramOverviewView.task`
(`ProgramOverviewView.swift:102-142`) run ~15 / ~4 **independent** network
round-trips strictly serially, and the screen stays in `isLoading` until the
last one returns. Perceived load = the *sum* of every call's latency, not the
slowest. Plus the `workout_logs` table is fetched 3× on Home (limit 1, 1, 14)
and again on Program (limit 40) per load. Scope chosen: **parallelize + dedupe**
(no UI/render-gating restructure — that is explicitly out).

## Locked decisions

1. **Parallelize independent loads** with structured `async let`. Only true
   dependencies stay sequential:
   - `ProgressionStateStore.fetchAll` → `PlateauDetector.detect` (detect needs
     the states)
   - `user.fetchProfile` → program read-or-generate (needs the profile)
   Everything else (`SkillProgressService.load`,
   `RankDecayService.evaluateOnForeground`, recent-logs fetch, ranks, travel
   override, coach note) starts concurrently and is awaited together.
2. **One `workout_logs` fetch per load.** Replace Home's three calls
   (`refreshLastLog` limit 1, `refreshWeeklyRhythm` limit 14,
   `refreshCalibrationState`'s limit-1 probe) with a single
   `fetchRecentLogs(userId:, limit: 40)`; derive `lastLog`,
   `hasLoggedAnyWorkout`, and `weekSessionDays` from that one array. Program's
   `refreshHistory` keeps its single `limit: 40` (already deduped) but runs
   concurrently with the profile→program chain.
3. **`aggregateRank` ∥ `aggregateTier`.** `refreshRanksAndStats`
   (`UnboundHomeView.swift:1893-1897`) currently serializes two independent
   calls — run them with `async let`.
4. **Claude generation never gates the rest of the screen.** The program
   read-or-generate branch runs as one concurrent `async let` alongside all
   other independent loads, so even a first-run/transient generate overlaps
   everything else instead of being a serial prefix. Add a guard:
   `generateFromOnboarding` runs **only** when `currentProgramId == nil`
   (genuine first run) — a *thrown* program `read` failure must NOT silently
   trigger a multi-second Claude generate; on read failure keep the existing
   graceful fallback profile path (Home) / `catch {}` (Program) without
   generating.
5. **Incremental helpers stay intact.** `refreshSessionXP`,
   `refreshRanksAndStats`, `refreshLastLog`, `refreshWeeklyRhythm`,
   `refreshCalibrationState`, `refreshTravelOverride`, `refreshCoachNote`
   remain callable as-is (the session-complete hook
   `onSessionComplete` `:1986-1991` and the `.task(id:)` foreground refreshes
   depend on them). Only the initial `load()` / `.task` paths are restructured;
   shared derivation is factored so there is no logic divergence.

## Architecture (new/changed units)

### `HomeLoadDerivations` (new, pure, unit-tested)

A dependency-free enum with static funcs over `[WorkoutLog]` so the
single-fetch dedupe is testable and DRY:

- `static func lastLog(_ logs: [WorkoutLog]) -> WorkoutLog?` → `logs.first`
- `static func hasLogged(_ logs: [WorkoutLog]) -> Bool` → `!logs.isEmpty`
- `static func weekSessionDays(_ logs: [WorkoutLog], now: Date = .now,
  calendar: Calendar = .current) -> Set<Int>` → the Monday-indexed
  current-week set currently computed inline in `refreshWeeklyRhythm`
  (`:1915-1928`), extracted verbatim (Monday firstWeekday,
  `((weekday + 5) % 7) + 1`).

`refreshWeeklyRhythm` is rewritten to call
`HomeLoadDerivations.weekSessionDays(logs)` (same behavior, now shared).

### `UnboundHomeView.load()` — restructured

Compute `userId` once; `services.badges.bind(userId:)` first (sync). Then:

```
async let skill:   Void   = SkillProgressService.shared.load(userId: userId)
async let decay:   Void   = RankDecayService.shared.evaluateOnForeground(userId: userId)
async let plateau         = loadProgressionAndPlateaus(userId)      // fetchAll → detect
async let profileProgram  = loadProfileAndProgram(userId)           // fetchProfile → read-or-generate(guarded)
async let recentLogs      = fetchRecentLogsSafe(userId, limit: 40)  // ONE fetch
async let rankPair        = loadRanks(userId)                       // aggregateRank ∥ aggregateTier
async let travel          = TravelOverrideStore.shared.activeOverride(for: userId)
async let coach           = CoachNotesService.shared.todaysNote(userId: userId)
```

Await them, assign `@State` on the main actor, then the cheap **synchronous**
tail (`sessionXP.record`, `calibration.skipRatio`, `attribute.profile`,
`ScanCheckpointStore.history`, `trials.state`) and `isLoading = false`
exactly as today. New private helpers: `loadProgressionAndPlateaus`,
`loadProfileAndProgram`, `loadRanks`, `fetchRecentLogsSafe`, `applyRecentLogs`
(sets `lastLog`/`hasLoggedAnyWorkout`/`weekSessionDays` via
`HomeLoadDerivations`). The post-load `DispatchQueue…startAmbientAnimations()`
and all state variable names are unchanged.

### `ProgramOverviewView.task` — restructured

`async let history = refreshHistorySafe(userId)` and
`async let travel = TravelOverrideStore.shared.activeOverride(for: userId)`
start concurrently with the `fetchProfile → loadProgram`/guarded-generate
chain; await all; the existing detached per-goal `RPESessionService.prefetch`
loop is unchanged.

## What does NOT change

State variable names/types, view bodies, render gating, `isLoading` semantics
(still flips false once after the load completes — no incremental paint),
`onSessionComplete`, `.task(id:)` foreground refreshers, `ProgramViewModel`,
service signatures, the program-persistence detached-write fix
(`ProgramGenerationService` `41ff444`), tokens, navigation.

## Testing / verification

- New unit tests `UNBOUNDTests/Views/HomeLoadDerivationsTests.swift`:
  `lastLog` (empty → nil; returns `.first`), `hasLogged`, `weekSessionDays`
  (logs in current week mapped to Monday-indexed set; logs before week start
  excluded; empty → empty) — using a fixed `now`/`calendar`.
- `xcodebuild -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 17' build`
  → `** BUILD SUCCEEDED **`.
- `xcodebuild … test` → all green except the known pre-existing
  `FriendChallengeServiceTests`/`SquadMissionServiceTests` RLS flap; zero NEW
  failures. SourceKit cross-file noise ignored.
- Parity guard: every `@State` set by the old `load()` is still set by the new
  one with identical values for the same inputs (reviewer diffs the assignment
  set). The single 40-log fetch yields the same `lastLog`/`hasLoggedAnyWorkout`/
  `weekSessionDays` the three smaller fetches did.
- On-device (jlin): cold-open Home and Program — screen appears in well under
  1 s (was 2–5 s); all cards populate correctly; logging a workout then
  returning still refreshes (onSessionComplete path intact).

## Out of scope

Incremental/skeleton render, the logging redesign (already shipped this
session), sub-projects B–E, any service-layer/caching change, prefetch-loop
changes.

## Execution

Subagent-driven (fresh subagent per task, spec-then-quality review at the
cluster seam), Sonnet minimum, frequent commits, co-authored trailer,
on-device sign-off by jlin.
