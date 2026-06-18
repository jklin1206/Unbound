# Agent Handoff — Rank Gates Experience Spine (Plan 2 of 4)

Branch: `claude/rank-gates-engine` (continues the engine branch; Plan-2 commits `6bcef5e2..HEAD`)
Worktree: `/Users/jlin/Documents/toji/UNBOUND-agent-a`
Lane: A (sim iPhone 17, DerivedData `/private/tmp/unbound-dd-a`)

## Summary
The shared experience-spine UI for the 8 destination-world rank gates, per spec §6/§10 and the Plan-2
doc (`docs/superpowers/plans/2026-06-13-rank-gates-experience-spine.md`). **Build-alongside** (jlin's call):
the spine is reachable only through a launch-arg demo harness; the live trial flow still runs the 8 old
mode views. Live cutover + legacy deletion + the Crossing + bespoke per-gate visualizers are Plans 3–4.

9 commits (`6bcef5e2..HEAD`):
- 1 plan doc.
- 3 foundation models (unit-tested): `GateWorld` + `GateWorldCatalog` (8 worlds), `NextGateCardModel`,
  `GateVerdictModel`.
- 3 view clusters: NextGateCard / GateHall / GateEntryCeremony · GateVisualizer + GateActiveHeaderView +
  GateActiveView + GateBeatOverlay · GateVerdictView + GateCardView + TrialRecordsShelf.
- 1 layout fix (banner width pin — see below).
- 1 demo harness + `--unbound-open-gate` launch arg.

## What shipped (all under `UNBOUND/Views/Gates/`)
- `GateWorlds/GateWorld.swift` + `GateWorldCatalog.swift` — declarative theme per `RankTrialFormat`
  (numeral I–VIII, one-line promise, beat verb, destination rank, world element). Tint/banner/transition
  derive from the destination rank, so engine renames/balance flow through automatically. Banner =
  existing `profile_banner_<token>` (spec §3); Plan 3 swaps bespoke threshold art behind the same accessor.
- `NextGateCard` (+model) — discovery card: sealed (darkened banner + lock + quest log + key fragments) /
  open (lit banner + BEGIN) / cleared. Key fragments read from `.gateKey` requirement lines.
- `GateHallView` + `GateEntryCeremony` — entry sheet: full-bleed banner, line-by-line type-on title stack
  (reduced-motion safe), loadout picker, world-language stations preview, past attempt, BEGIN.
- `GateActiveView` + `GateActiveHeaderView` + `GateVisualizer` — world-stage header (banner bleeding into
  true black, trial name, station N/M, progress visualizer) over an injected calm logging surface.
  `GateVisualizer` is a protocol with `DefaultGateVisualizer` (generic tinted progress); Plan 4 ships 8
  bespoke plugins. `GateActiveView` is generic over the logging surface — Plan 4 injects the real
  `ExerciseLogCard` grid; Plan 2 injects a lightweight stand-in.
- `GateBeatOverlay` — station-clear beat (world floods, one line, haptic, recedes; reduced-motion flash).
- `GateVerdictView` (+`GateVerdictModel`) — pass: hush → station accounting → minted card (tap = Plan-3
  Crossing hook). Fail: "The gate holds." → accounting → "What stands between you" → ENTER AGAIN. Unscored
  stations (e.g. Gate III Stoke the Fire) are correctly excluded from the verdict.
- `GateCardView` — minted/share card (stamped vs unstamped + attempt count).
- `TrialRecordsShelf` — every gate card at its best state from `OverallRankTrialProgress.attempts`.
- `GateExperienceDemoView` (`#if DEBUG`) + `-gateExperienceDemo` / `UNBOUND_OPEN_GATE=<1-8>` +
  `UNBOUND_GATE_STAGE=<stage>` in `UnboundApp.swift`. Self-contained fixtures built from the real engine
  definitions/keys (no dependency on the private RankTrialDemo* types).

## Verification done
- Unit: GateWorldCatalogTests (5), NextGateCardModelTests (5), GateVerdictModelTests (2) — 12/12 green.
- LocalizationTests green (5) — see L10n note below.
- Full suite: 1221 tests, **18 failures = the 3 pre-existing groups** the engine handoff documented
  (16 asset-PNG-dupe assertions in MovementResolverTests, 1 weight-rounding in ProgramAwareLoggingTests,
  1 band-swap in DailyWorkoutResolverTests) — all in files Plan 2 never touched. **Zero new regressions.**
- Sim build green (iPhone 17); **device-arch build green** (`generic/platform=iOS CODE_SIGNING_ALLOWED=NO`) —
  no type-check timeouts, no metadata cliff.
- On-sim screenshots, read + checked: all 9 spine stages (sealed/open/hall/active/beat/verdictPass/card/
  verdictFail/records) on Gate III, plus sealed/open/hall/card/active/records across Gates I (Novice),
  VI (Vessel), VIII (Unbound) — correct per-world banner, rank tint, numeral, difficulty pips (1→8),
  non-negging copy, no clipping.
- Scope: only `Views/Gates/*`, `App/UnboundApp.swift`, `UNBOUNDTests/Views/Gates/*`, plan doc. Engine
  untouched. Brand sweep clean (no EMOM/AMRAP/WOD/metcon/limiter/etc.). All files <225 lines.

## Layout bug found + fixed (commit `99847e37`)
GateHall + (latent) GateCard overflowed horizontally: a `scaledToFill` banner with only `.frame(height:)`
reports a width wider than the screen, and `.frame(maxWidth:.infinity)` does NOT clamp it down. Fixed with
the canonical pattern — `Color.clear.frame(height:H).overlay(Image…scaledToFill).clipped()` — which pins
the frame to the proposed width. (NextGateCard / ActiveHeader were already safe via a Spacer/maxWidth
sibling that pins width.)

## Deferred to Plans 3–4 (by design, not gaps)
- **L10n catalog migration.** Gate copy ships as literal `Text("…")` (auto-localizing) + verbatim
  `Text(stringVar)`, exactly like the existing trial UI; LocalizationTests is green. Wrapping the strings
  through `Localizable.xcstrings`/`String(localized:)` belongs with the **Plan 4 live cutover**, when the
  copy becomes user-facing. (Avoids a premature 14k-line catalog churn now.)
- The Crossing cinematic + asset manager + Higgsfield/Seedance art generation — Plan 3.
- 8 bespoke `GateVisualizer` plugins; live cutover (Profile → `NextGateCard`, `GateActiveView` replaces the
  `WorkoutLogGridView` dispatch, real `ExerciseLogCard` grid injected); deletion of the 8 old mode views +
  ready previews + `OverallRankTrialReadinessCard` + old `RankUpCinematic` beats — Plan 4.

## Risks / notes
- The demo harness's bottom controls overlay occludes `GateHallView`'s own BEGIN bar in screenshots
  (demo-only; the product flow has no such overlay).
- `GateActiveView`'s logging surface is a stand-in in Plan 2; the one-logging-spine guarantee is honored at
  Plan 4 cutover when the real `ActiveWorkoutSession` grid is injected.
- To run locally: `cd UNBOUND-agent-a && xcodegen generate`, then build to iPhone 17 and launch with
  `SIMCTL_CHILD_UNBOUND_OPEN_GATE=3 SIMCTL_CHILD_UNBOUND_GATE_STAGE=hall xcrun simctl launch booted com.unboundapp.ios`.
