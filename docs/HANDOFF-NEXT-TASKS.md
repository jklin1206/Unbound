# Handoff — Next Tasks (written 2026-06-10, post security-hardening session)

Context for the next session. `origin/main` = `681f47ed`. Prod Supabase is fully
caught up (all migrations applied + verified live; `delete_account` redeployed).
Full audit findings + what shipped are summarized at the bottom.

---

## P0 — Resolve the 2 red tests (Codex's in-flight iteration owns these)

The suite is 1166/1168. Both failures are **open behavior questions** inside the
backdrop/draft-factory iteration that landed as `681f47ed` — do NOT just rewrite
the expectations; decide the intended behavior first.

1. `ProgramAwareLoggingTests.test_trainingDraftSetPlansBecomeActiveSetSuggestions`
   (`UNBOUNDTests/Models/ProgramAwareLoggingTests.swift:98`)
   - Expects `suggestedWeightKg == [100, 80, 60]`; gets `[99.79, 79.38, 58.97]`.
   - Cause: draft→session ingest now lb-snaps suggestions via `WeightPlatePolicy`
     (locale-dependent — US sim = lbs). Decide: is snap-at-ingest intended, or
     should snapping stay display-time-only? If intended, anchor the test to
     `WeightPlatePolicy.snappedSuggestionKilograms` (never hardcode snapped values).
2. `DailyWorkoutResolverTests.testTravelEquipmentModifierSwapsGymPullDayToBandSafeMovements`
   (`UNBOUNDTests/Services/ProgramGeneration/DailyWorkoutResolverTests.swift:200`)
   - A gym pull-day no longer swaps to "Band Lat Pull" with `[.bodyweight, .bands]`.
   - Cause: `DeterministicProgramGenerator+MovementSelection` changes in the same
     iteration. Decide the intended band-swap target, then fix code or test.

## P1 — MVVM rollout (Home is the template)

`d63316ca` established the pattern: `UNBOUND/ViewModels/HomeViewModel.swift` +
slimmed `UnboundHomeView`. Apply the same split to, in order:

1. **ProfileView** (`UNBOUND/Views/Profile/ProfileView.swift`, ~1,036 lines,
   49 `@State`) — biggest offender. Same recipe: data state + load/refresh →
   `ProfileViewModel(services:)`; presentation state stays in the view;
   `init(services:)` from the tab view; verify with build + on-sim screenshot
   (`--unbound-open-profile`) + 3x launch gauntlet.
2. **ProgramOverviewView** (+Loading split exists already).
3. Then opportunistically as screens get touched — don't big-bang.

Watch-outs (cost cycles last time): the test target may instantiate views
directly (fix `init` call sites in UNBOUNDTests); SourceKit shows phantom
"Cannot find type" after xcodegen — trust xcodebuild only.

## P2 — Audit punch list, remaining Mediums/Lows

Backend (all are small migrations or function edits):
- [ ] Rate-limit / atomicity for `join_squad` invite-code attempts (Medium) —
      per-user throttle + `FOR UPDATE` on the squad row so the capacity check
      can't race.
- [ ] Commit a `supabase/config.toml` codifying per-function `verify_jwt`
      (webhook/cron fns gate on the shared secret; `anthropic_proxy`/`join_squad`/
      `delete_account` need JWT) so auth posture is reviewable from source.
- [ ] `sync_merge_row` whitelists `scan_checkpoints` — table doesn't exist;
      either create it or drop it from the whitelist (runtime sync error today).
- [ ] `squad_members` has no DELETE policy → no client "leave squad" path.
- [ ] `waitlist` duplicate-email returns a unique-violation → email-presence
      oracle for anon (return generic success instead).

Client cleanups (from the clean-code audit, in priority order):
- [ ] `CapstoneCatalog.perAxis[axis]!` (`Services/Trials/TrialGenerator.swift:59`)
      and `as! AVPlayerLayer` (`Step_Arc01_Opening.swift:331`) — guard both.
- [ ] Migrate the last 62 `Color.theme.*` uses (Settings/Auth/DevTools) to
      `Color.unbound.*`, then delete the legacy namespace.
- [ ] Split `View+UnboundStyle.swift` (1,369 lines) by family (cards/text/backdrops).
- [ ] FileManager `.first!` x5 → guarded unwraps.

## P3 — Bigger refactors (audit's highest-leverage, jlin to prioritize)

- ServiceContainer: 8 services still hardcoded `.shared` in the testable init;
  102 `.shared` declarations total; services reach across domains via `.shared`
  (e.g. ProgramGenerationService → AttributeService.shared). Inject instead.
- Split the 700+ line models (TrainingSessionDraft 983, ActiveWorkoutSession 944,
  SkillTrainingPlan 874) into record + domain services.
- Move `DevBuildBootstrapper` (~2,700 lines, Views/Settings) into a test-harness
  target — it's `#if DEBUG`-gated now but doesn't belong in Views.

## Standing constraints (read before touching anything)

- **Shared tree**: a Codex session edits this checkout concurrently. Stage
  explicit paths only; `git branch --show-current` in the same command as every
  commit (the branch switched mid-session once); failing tests in untouched
  files → check Codex's `git status`-modified files first.
- **Build gates**: `set -o pipefail` + grep `BUILD SUCCEEDED`; device-arch build
  (`-destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`) is the real
  gate; background builds must `cd` to the repo root first.
- **Archive strip**: the explicit `schemes:` block in `project.yml` carries the
  archive post-action that strips SwiftTrace/HotReloading — if it's removed,
  shipped archives carry injection code again. Verify with an unsigned
  `xcodebuild archive` → Frameworks/ must be empty.
- 518 churning Assets PNGs remain deliberately uncommitted (jlin's call);
  untracked `scripts/*.py` asset tooling is Codex's, leave it.

## What shipped this session (for reference)

| Commit | What |
|---|---|
| `8c72c342` | Draft autosave + restore failures surfaced (saveDraft funnel + warning row) |
| `04d411c1` | Backend hardening migration + `delete_account` confirm enforcement |
| `b0882498` | `#if DEBUG` gates on DevBuildBootstrapper extensions (Release compiles) |
| `d63316ca` | HomeViewModel — the MVVM template screen |
| `cd96286b` | Injection-framework strip via scheme archive post-action |
| `681f47ed` | Codex in-flight iteration carried (required for compilation) + new imagesets |

Prod verified live post-deploy: `is_pro` client-write revoked, `is_squad_member`
anon-execute revoked (authenticated kept for RLS), `handle_new_user` search_path
pinned, `body_weight_logs`/`squad_routine_drops`/`users.workout_minute_of_day`
exist. Audit verdict for the record: backend RLS 27/27 tables, zero permissive
policies, zero Critical/High findings anywhere; architecture C+ (View-layer
bypasses MVVM); clean code B-.
