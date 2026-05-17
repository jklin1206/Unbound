# Perceived Load: Incremental Render + Profile Off The Critical Path — Design Spec

**Date:** 2026-05-17
**Branch:** `program-redesign` · UNBOUND iOS
**Type:** Perceived-performance (render gating) — no feature/data change
**Builds on:** load-perf parallelize (`25af5ab`/`8478f21`) + local program store (`abf7a56`…`9e78910`)

## Context

Parallelize+dedupe + the local program store made the *work* fast and the
program *durable*, but jlin reports "I don't feel the changes." Diagnosed to
two render gates that the chosen scope deliberately left:

1. **Home is all-or-nothing.** `UnboundHomeView.load()` flips `isLoading=false`
   only after **every** awaited call (`skillLoad`, `rankDecay`, `plateaus`,
   `profileProgram`, `recentLogs`, `ranks`, `travel`, `coach`). Parallelize
   made total ≈ the slowest call instead of the sum — but the screen is
   `HomeLoadingSkeleton()` until that slowest call (e.g. `CoachNotesService
   .todaysNote`, which was observed throwing a decode error / likely a slow
   Claude path) returns. The instant program is invisible because Home never
   gates on the program in a way the user perceives.
2. **Program screen waits on a cold profile fetch.** `ProgramOverviewView
   .task` does `try await services.user.fetchProfile` *before*
   `vm.loadProgram`, because it used `profile.currentProgramId`. The local
   program store can't help until `loadProgram` runs, so the user still eats
   one cold round-trip before the Program screen paints.

Fix both. `ProgramStore.loadLocal(userId:)` already returns the user's last
program **without** needing `currentProgramId`, so the profile fetch can be
demoted to background revalidation — no separate profile cache is needed.

## Locked decisions

### Fix A — Home incremental render (two-phase `load()`)

- **Phase 1 (essentials, paint ASAP):** the cached program
  (`ProgramStore.shared.loadLocal(userId:)` — instant, no network), `loadRanks`
  (fast), and the synchronous reads (`sessionXP.record`,
  `calibration.skipRatio`, `attribute.profile`, `trials.state`). Set a
  **placeholder `profile`** immediately (the existing fallback `UserProfile`
  init) so no card ever renders against a nil profile. Then `isLoading = false`
  and kick `startAmbientAnimations()` exactly as today.
- **Phase 2 (secondary, concurrent, streams into cards after paint):** the
  real `fetchProfile` (replaces the placeholder when it lands), program
  reconciliation / first-run generate (only when there is no cached program),
  `SkillProgressService.load`, `RankDecayService.evaluateOnForeground`,
  progression→plateau, the single `recentLogs(40)` → `applyRecentLogs`,
  travel override, coach note, scan cadence. Each assigns its `@State` when it
  resolves; the cards already bind `@State` with safe defaults
  (`[]`/`nil`/`.eMinus`/`.initiate`), so they render empty then fill within
  ~a second. No card may force-unwrap `profile`/`program` (Phase 1's
  placeholder profile + the existing nil-program state guarantee this).
- First run / cold cache: Phase 1 has no program → Home paints its shell with
  the existing no/empty-program state; Phase 2 generates and fills it in
  (instant shell + "program appears" beats a multi-second blank skeleton).

### Fix B — Program screen: profile off the critical path

`ProgramOverviewView.task`:
- **Instant:** `if let cached = ProgramStore.shared.loadLocal(userId: userId)`
  → `vm.program = cached; vm.state = .loaded(cached)` immediately (zero network
  before paint), then `await vm.loadTrackingData()` (network, but the screen
  is already up — completion ticks fill in).
- **Background revalidation:** then `fetchProfile` to learn the authoritative
  `currentProgramId`; `await ProgramStore.shared.revalidate(userId:
  expectedProgramId:)`; if a *new* program superseded (rollover), swap
  `vm.program`/`vm.state` and re-`loadTrackingData`. `refreshHistory` /
  `refreshTravelOverride` stay concurrent (unchanged).
- **No cache (first run):** fall back to the existing
  `fetchProfile → loadProgram` / generate path (necessarily a network/generate
  wait — unavoidable on first ever load; only this path shows the spinner).

## What does NOT change

State variable names/types, every card view, `HomeLoadingSkeleton`, the
`vm.state` machine, `ProgramStore`/`ProgramViewModel` internals, the
program-persistence + program-store behavior, the load-perf dedupe (single
`recentLogs(40)`), tokens, navigation, `onSessionComplete`/foreground
refreshers, the detached per-goal prefetch loop. This is purely *when* state
is published, not *what*.

## Architecture (changed units)

- `UnboundHomeView.load()` — split into Phase 1 (essentials → `isLoading=false`)
  and a Phase 2 concurrent block. New private helper
  `loadCachedProgram(_ userId:) -> TrainingProgram?` =
  `ProgramStore.shared.loadLocal(userId:)`. `loadProfileAndProgram` is reused
  in Phase 2 for the real profile + first-run/reconcile (it already does
  store-first internally). Placeholder `profile` set in Phase 1 via the
  existing fallback `UserProfile(...)` initializer.
- `ProgramOverviewView.task` — local-first paint + profile demoted to
  background revalidation as above.

## Design bar

Cards appearing unpopulated then filling must look intentional, not broken:
they already have empty/skeleton states (existing defaults) — verify the
above-the-fold ones (topBar, homeBriefing, trainingConsole) read fine with
placeholder profile + cached program before Phase 2 lands. No layout jump
beyond content fill. `prefers-reduced-motion` unaffected (no new motion).

## Testing / verification

- No new unit logic (pure render-ordering). Existing suites stay green:
  `xcodebuild … test` → only the known pre-existing `FriendChallengeServiceTests`/
  `SquadMissionServiceTests` RLS flap; zero NEW failures.
- Build: `** BUILD SUCCEEDED **`.
- Parity review: every `@State` the old `load()` set is still set with the
  same value for the same input; only the *timing* (phase) differs. Program
  screen renders the same program; rollover still swaps via `revalidate`.
- On-device (jlin): warm cold-open Home → shell + rank + today's training
  paint near-instantly; coach/plateau/last-session fill in within ~1 s
  (visible stream-in, not a 2–3 s blank). Open Program (warm) → today's
  workout paints with **no spinner**; rollover still replaces. First-ever run
  still works (shell → program appears).

## Out of scope

Server-composed endpoints, broader non-program read-through caching,
cross-device sync, sub-projects C/D, any change to what data the cards show.

## Execution

Subagent-driven (fresh subagent per task, spec-then-quality review at the
seam), Sonnet minimum, scoped `git add` (no `git add -A`), co-authored
trailer, on-device sign-off by jlin.
