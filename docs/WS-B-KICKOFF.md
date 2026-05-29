# Workstream B — "Close the open loops" · kickoff handoff

**Status:** not started. Workstream A is DONE (see `docs/WS-A-REMEDIATION-REPORT.md`), merged + pushed to `origin/main`, server pieces deployed live.
**Theme:** make systems do what the UI already claims — things that are computed but never applied, or wired but never triggered.

## How to run it (same playbook as WS-A)
Coordinator + isolated subagents. Each agent gets: own git worktree off `main`, own branch `fix/ws-b-<slug>`, own cloned simulator (`xcrun simctl create`), own `.derivedData-*` dir. TDD with a falsifiable proof per issue. Coordinator merges + integration-tests + writes report. **For any data/security change: council review + live `supabase db query --linked` rollback test** (see memory `data-layer-needs-council-and-live-test`). Project uses XcodeGen — `xcodegen generate` before each build; verify each `-only-testing` suite actually ran.

## ⚠️ Parallelization caution (different from WS-A)
WS-A subsystems were disjoint. **B1 is NOT** — most B1 items touch the shared progression/program-generation/ranking engine, so they will collide. Plan: do B1 mostly **sequential** (or carefully partitioned), and run **B2 in parallel** (squads / badges / missions / home-UI are separable). Do a real impact-radius pass before fanning out.

## B1 — computed but never applied (likely sequential; shared engine)
| Issue | Fix | ✓ Proof |
|---|---|---|
| Checkpoint load-bias inert | scale next Arc sets/reps/RPE by bias | recovery checkpoint → next Arc total volume numerically < prior; +2-Arc screenshot |
| Velocity layer unbuilt | boluses + skill/compound/comeback mult | sim re-run: vet & beginner at equal volume diverge in LV; updated cohort-matrix |
| Rank decay = no honest signal | stale flags + recent-vs-lifetime | 31d idle → stale flag + recent<lifetime, rank unchanged; stale-UI screenshot |
| Trials ignore skills | path-aware "any N of" gates, mid/high tiers | below skill req → readiness locked w/ skill line; meet → unlocked per path (lifter vs cali) |
| Skill auto-proof half-built | detect hold-time / carry-distance | log 60s L-sit hold → node auto-advances, no manual tap (NodeState assert) |
| Auto-deload never fires + no peaking | PlateauDetector in ingest; rank-gate phase | inject 2 plateaus → next resolved day is deload (no Coach tap); generator emits realization at rank≥threshold |

Note: peak-gating decision is already made — gate trials on attribute **PEAK**, not current (that landed as WS-C earlier; confirm).

## B2 — wired in, never triggered (parallelizable)
| Issue | Fix | ✓ Proof |
|---|---|---|
| Linked-session bonus dead | post event + apply +20% | 2 squadmates train in window → toast + +20% LV; screenshot |
| Squad titles never awarded | wire threshold evaluator | cross threshold → `unlockedSquadTitles` populated; badge renders |
| Missions/challenges never close | launch trigger: generate/evaluate/expire | new-week launch → mission created; past-deadline challenge → evaluated & closed |
| Badge catalog ↔ service mismatch | reconcile id sets | awarded-ids ⊆ catalog AND every catalog id reachable by a trigger (set equality) |
| Home bell + Daily-Quest inert | wire to real dest/service or remove | bell navigates to a real screen; quest reflects a real value (or is gone); screenshot |
| Frozen 5→5 grades + dual loggers | drop dead cols; one logger path | scan delta writes no 5→5 grades; legacy VM no longer writes progression |

## First move next session
1. Read `docs/unbound-issues-and-plan.html` slides 7–8 (WS-B source of truth) + this file.
2. Impact-radius pass on the B1 engine items to decide sequential vs partitioned.
3. Start with **B2 parallel batch** (separable, fast wins) while scoping B1.
4. Heaviest/most valuable B1 item is the **velocity layer** (the central finding from the teardown — rank is currently pure volume, ability is invisible). Treat it as its own focused effort.
