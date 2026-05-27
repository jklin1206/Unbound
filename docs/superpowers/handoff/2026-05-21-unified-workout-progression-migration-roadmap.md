# UNBOUND Unified Workout + Progression Migration Roadmap

**Date:** 2026-05-21  
**Status:** Operating roadmap  
**Source docs:** `docs/PROGRESSION.md`, `2026-05-19-workout-flow-map.html`, `2026-05-20-movement-library-v1-review.html`, `2026-05-20-program-modifiers-and-movement-library-plan.md`

## North Star

Every way a user trains in UNBOUND should collapse into the same spine:

```text
Intent
  -> TrainingSessionDraft
  -> Workout Ready
  -> block-specific logger
  -> PerformanceLog
  -> TrainingCompletionService
  -> unified receipt + history + side effects
```

The app is "functionally migrated" when a user can:

1. Start today's generated program workout from Home.
2. Open Program, review Workout Ready, edit blocks, start, complete, and return cleanly.
3. Add a skill goal to the program and see it appear as scheduled workout blocks.
4. Start a skill-only session from Skill Detail and receive the same progression receipt shape.
5. Build a custom mixed workout with exercise, skill, cardio/carry/routine blocks.
6. Complete every block type with the correct logger UI and one completion pipeline.
7. See AP, attribute XP, Overall LV XP, skill XP, rank-ups, PRs, and badge unlocks in one coherent reward receipt.
8. Unlock and attempt overall-rank trials only after requirements are met.
9. Opt into a Weekly Vow (Ember / Overdrive / Apex) without confusing it with an Overall Rank Trial.

Screens can be redesigned after this is true. Until then, functionality wins.

## Current State

| Area | State | Notes |
|---|---:|---|
| Training draft models | Mostly implemented | `TrainingSessionDraft`, `TrainingBlock`, prescriptions, adapters exist. |
| Performance log model | Mostly implemented | `PerformanceLog` supports mixed blocks and block metrics. |
| Completion service | Stable for migrated routes | `TrainingCompletionService` writes `PerformanceLog`, movement/body/attribute/Overall LV progression, idempotency records, and compatible history. Production compatible `WorkoutLog` writes now avoid awaiting the old side-effect bridge. Receipts now carry exact Overall LV progress fractions from the service. |
| Home program completion | Stable | Simulator-proven: Home -> Begin Session -> Complete -> Reward Sequence -> Finish -> Home. |
| Workout Ready | Stable for V1 program + scheduled skill path | Program tab -> Workout Ready -> Active workout -> reward sequence -> Program is simulator-proven. Scheduled skill blocks now appear in the same ready state as program work. Edit/remove/add/reorder/save-draft/start depth is simulator-proven for the V1 surface. |
| Active workout logger | Stable for reps + skill + carry path | Sticky completion footer, empty-completion guard, one-set completion, reward sequence, and return are proven. A mixed program session with strength + scheduled skill + carry now reaches one unified receipt. |
| Skill-only logging | Stable reward path | Skill Detail -> Start Session -> log set -> Finish -> reward sequence -> Continue is simulator-proven with skill XP through the unified service. Skill Detail -> Train -> Log a Set -> Quick Log -> reward sequence -> Continue is also simulator-proven. |
| Custom workouts | Early | Simple recent draft builder exists; not yet a trusted main workflow. |
| Movement catalog | Core flows migrated / shim cleanup remains | Rich `MovementCatalog` exists. Program generation, substitutions, draft/log metadata, AP/rank progression, attributes/body-map, scan volume, Weekly Vow prescriptions, and Overall Rank trials now resolve through catalog IDs and standards. `ExerciseCatalog` remains as a compatibility/raw-source shim. |
| Progression math | Solid foundation | Whole AP/XP, attribute levels, Overall LV curve, novelty floor are implemented and tested. |
| Reward callouts | Early | PRs/badges counted. Future callouts need standardization. Feats should not become a separate data-model layer. |
| Weekly Vows | Catalog-backed unified route implemented | Weekly `Trial*` code now presents as Weekly Vows with temporary compatibility adapters. Active Weekly Vows build catalog-backed `TrainingSessionDraft`s, launch through Workout Ready, complete through `PerformanceLog` -> `TrainingCompletionService`, and mark the Vow complete only after saved real work. |
| Trial readiness / runner | Full V1 ladder service-tested | Overall Rank gates now cover Initiate -> Ascendant through Trial Readiness, `TrainingSessionDraft` -> `PerformanceLog` -> `TrainingCompletionService`, reward receipt, duplicate protection, comeback callout data, and rank advance only on pass. |
| Cleanup | In progress / guardrailed | Migrated compatible history writes bypass old `saveLog` cascades. Legacy direct-save paths still exist temporarily for old callers and are marked/quarantined. |

## Active Goal — Finish The Progression Migration

**Goal set:** 2026-05-22  
**Owner lane:** Main coordinator lane, with simulator / worker lanes split only for bounded proof or implementation tasks.

Turn the current partially migrated spine into a complete, demo-proven progression loop:

```text
Program or skill intent
  -> Workout Ready
  -> mixed block logger
  -> TrainingCompletionService
  -> unified receipt
  -> updated progression surfaces
  -> trial readiness
  -> named Overall Rank trial
  -> Overall Rank advances only on trial pass
```

This goal is complete when the Definition of Done demo at the bottom of this roadmap passes with screenshots or video, and no old hidden pipeline can award AP, XP, skill XP, rank progress, badges, or trial progress differently from the unified pipeline.

### Goal Checklist

- [x] Prove/fix Workout Ready edit depth: reorder, remove, add scheduled skill, add mixed block, edit targets, save recent draft, and start.
- [x] Prove that removing today's scheduled skill block does not unpin the active skill goal.
- [x] Prove the manual skill path: Skill Detail -> Add to Program -> next eligible Program day -> Workout Ready.
- [x] Fix the known Program `BEGIN SESSION` CTA overlap on small simulator screens.
- [x] Continue MovementCatalog migration until program generation, substitutions, logging, AP, ranks, attributes, body map, and trials read from one source.
- [x] Rename/migrate the weekly `Trial*` system into Weekly Vows: Ember, Overdrive, Apex.
- [x] Build Trial Readiness as the Overall Rank gate, separate from Weekly Vows.
- [x] Build the Overall Rank trial runner through `TrainingSessionDraft` -> `PerformanceLog` -> `TrainingCompletionService`.
- [x] Advance Overall Rank only when the named trial is passed.
- [ ] Delete or quarantine legacy direct-save/logging/rank paths after each replacement is proven.

### Immediate Success Target

Completed 2026-05-22: **Workout Ready edit/save depth plus the manual skill Add-to-Program proof**, followed by two three-agent MovementCatalog / Weekly Vows / Overall Rank Trial integration slices. Completed 2026-05-23: core MovementCatalog caller migration for the progression spine, catalog-backed Weekly Vow prescriptions, full Overall Rank ladder coverage, Daily Resolver V1 modifiers, and Phase 9 compatibility-history guardrails. The next highest-return lane is final demo proof plus cancel/failure/retry routes, UI surfacing for new trial callout data, and eventual `ExerciseCatalog` shim cleanup.

## Phase 0 — Freeze The Contract

**Goal:** Stop vocabulary drift and make the migration contract explicit.

Done when:
- `PROGRESSION.md` defines AP, XP, LV, reward callouts, Weekly Vows, ranks, trials, body map, and failure modes.
- This roadmap is the migration scoreboard.
- "Marks" is removed from reward UI/spec.
- "Feats" is not introduced as a major data model; persistent named accomplishments are Badges.
- Product copy reserves "Trial" for Overall Rank gates only.
- The 9-tier ladder is the only tier model.
- Body map is documented as diagnostic only, never ranked.

Current status: **Mostly done.**

Cleanup checklist:
- Remove or rewrite any app copy using "Marks" for reward events.
- Document old 5-level skill language as retired wherever it still appears.

## Phase 1 — Completion Reliability

**Goal:** Every existing training completion route closes cleanly and does not double-save, double-dismiss, or re-present loggers.

Routes to prove:
- Home generated workout completion.
- Program tab Workout Ready -> Active workout completion.
- Skill Detail -> Start Session completion.
- Skill Detail -> Log a Set quick completion.
- Custom draft completion.
- Cancel/close from each route without awarding completion.
- Save failure path offers retry or safe exit without trapping the user.

Implementation work:
- Standardize completion ownership: parent view owns presentation; child view calls a single `onFinished`.
- Make all reward finish buttons single-use.
- Ensure progression side effects run once per completed `PerformanceLog`.
- Ensure local draft cleanup only happens after successful completion.

Tests:
- Unit: duplicate completion source id does not double-count AP/LV.
- Unit: adapter can build compatible `WorkoutLog` / `SessionLog`.
- Integration: completion service emits receipt for program, skill, custom, and mixed sessions.
- Simulator proof: screenshots or video for every route above.

Exit criteria:
- No route loops the logger or reward screen.
- Every route returns to the expected parent screen.
- Every route emits one receipt or intentionally emits no reward on cancellation.

Current status: **In progress. Home, Program Workout Ready, Skill Session save path, Quick Log, custom carry, cardio, and routine reward routes are proven; broader failure/cancel routes still need proof.**

2026-05-21 implementation notes:
- Added a `training_completion_records` idempotency guard keyed by `PerformanceLog.id`.
- Compatible `SessionLog` ids are now deterministic per performance skill block, so repeated completions do not create new legacy skill logs.
- `SkillProgressService.awardSessionXP` now reports the XP actually awarded; receipts no longer claim skill XP when a cap/lock/no-op prevented the award.
- Skill session and quick-log saves now surface retryable errors instead of silently continuing with a partial/no progression receipt.
- `WorkoutReadyView -> ActiveWorkoutContainerView` now closes the ready sheet after a successful workout completion, while cancel/leave still returns to the ready screen.
- Simulator proof completed for Home `BEGIN SESSION -> COMPLETE SESSION -> reward sequence -> Home`.
- Focused simulator test suite passed after the fixes: `TrainingSessionAdapterTests`, `MovementProgressServiceTests`, `DailyWorkoutResolverTests`, `ActiveWorkoutSessionTests`, and `ActiveWorkoutSessionV2Tests` passed 41/41.
- Added launch-route hooks for Program/Skills/Profile/Squad and direct skill detail, so simulator proof no longer depends on the custom tab bar exposing child accessibility elements.
- Program tab `BEGIN SESSION` now opens Workout Ready directly through `DailyWorkoutResolver.programDraft(...)`.
- Empty workout completion no longer awards fake XP and no longer runs expensive legacy progression side effects.
- Logged-set workout completion now writes the compatible `WorkoutLog` directly from the unified pipeline for production-like services, avoiding the old side-effect bridge spinner loop.
- Active workout completion now presents the full `WorkoutRewardSequenceView`, then returns to Program after the user finishes the sequence.
- Progression receipts now carry exact Overall LV progress fractions from `OverallLevelReward`, so reward bars do not approximate from level number plus earned XP.
- Added a quick-log shaped regression test proving one-set skill logs write `PerformanceLog`, compatible `WorkoutLog`, and compatible `SessionLog` through `TrainingCompletionService`.
- Added quick-log accessibility identifiers for the submit/cancel actions and explicit accessibility labels for train chooser rows.
- Hardened `FriendChallengeService.createChallenge` so backend/RLS failures map to the app-level `backendUnavailable` error instead of leaking raw Supabase errors.
- Full simulator test suite passed after the reliability fixes: 584/584, no warnings.
- Full suite result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-21T20-10-41-080Z_pid40816_f80e5669.xcresult`
- Reproduced Quick Log UI bug: Skill Detail -> Train -> Log a Set -> Quick Log -> Log Set stayed trapped on `Saving Set` because the reward was presented as a nested sheet from inside the Quick Log sheet.
- Fixed Quick Log reward presentation by swapping the sheet content inline to `RewardCelebrationView`, expanding the sheet to the large detent, and resetting `isSubmitting` before showing the reward.
- Simulator proof completed for Quick Log `Skill Detail -> Train -> Log a Set -> Quick Log -> Log Set -> Reward -> Continue -> Skill Detail` using `cal.incline-pushup`.
- Focused post-fix simulator suite passed: `TrainingSessionAdapterTests`, `MovementProgressServiceTests`, `DailyWorkoutResolverTests`, `ActiveWorkoutSessionTests`, and `ActiveWorkoutSessionV2Tests` passed 41/41.
- Full simulator test suite passed after the Quick Log UI fix: 584/584, no warnings.
- Full suite result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-21T20-32-58-047Z_pid40816_bc3867f3.xcresult`
- Simulator proof completed for Program `BEGIN SESSION -> Workout Ready -> Start Workout -> log Bench Press set -> Complete -> Reward Sequence -> Program`.
- Simulator proof completed for Skill Detail `Train -> Start Session -> log Wall Handstand set -> Finish -> Skill Detail`; reward did not present because the dev account was already inside the 24h skill XP cap.
- Fixed structured Skill Session reward presentation by swapping `SkillSessionView` inline to `RewardCelebrationView` instead of presenting the reward as a nested sheet from inside the session sheet.
- Added a DEBUG-only launch proof flag, `--unbound-reset-opened-skill-for-proof`, that resets only the opened skill to an uncapped trainable state after the maxed dev bootstrap. This keeps simulator reward proofs eligible for real skill XP without changing production behavior.
- Simulator proof completed for structured Skill Detail `Train -> Start Session -> log Incline Push-Up set -> Finish -> Reward -> Continue -> Skill Detail` using `cal.incline-pushup`.
- The structured session reward proof showed `FIRST REP`, `PROGRESSION RECEIPT`, and Skill XP (`+4 XP`) before returning to Skill Detail with the CTA changed to `Trained Today`.
- Focused post-fix tests passed before the proof run: `MovementProgressServiceTests/testQuickLogShapedSkillCompletionWritesUnifiedAndCompatibleHistory` and `TrainingSessionAdapterTests/testSkillSessionLoggedExercisesMapIntoPerformanceLog` passed 2/2.
- App build for the proof run succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-21T22-47-10-995Z_pid13774_fe9f239c.log`
- Follow-up build verification note: the original DerivedData path became locked after a timed-out test worker; a fresh DerivedData compile began but timed out during full dependency/asset rebuild. The simulator proof used the successful app build above.
- Reward-shell normalization pass completed: `WorkoutRewardSequenceView` is now data-driven so it only shows reward beats that have content, which lets it serve program workouts, skill sessions, quick logs, cardio logs, and routines without empty rank/attribute pages.
- Added `WorkoutRewardSequenceSummary.trainingReceipt(...)` and `simpleReceipt(...)` as the shared reward payload builders. Skill Session and Quick Log now adapt `RewardSummary` + `TrainingCompletionResult` into the full program reward sequence instead of presenting the compact reward sheet.
- Cardio logs now create a metric-only `PerformanceLog` block, run through `TrainingCompletionService`, and adapt the resulting progression receipt into `WorkoutRewardSequenceView`.
- Routine completions now create a `PerformanceLog` from the authored routine steps, infer real movement rows when possible (for example pushup challenge bursts), run through `TrainingCompletionService`, and adapt the resulting progression receipt into `WorkoutRewardSequenceView`.
- Routine player completions now carry `RoutinePerformanceEntry` rows for completed rep targets, timed work, interval work, and completed instruction steps. The adapter prefers those captured entries over authored-step inference, preserving multiple rep targets in routines like Zero Limit Protocol.
- Custom Workout Ready carry blocks now default to a 40m Farmer Carry target, preserve block identity into `PerformanceLog`, and show the active logger as `LOAD` + `DIST` instead of a rep row.
- Custom carry completion simulator proof completed: Program -> custom workout -> add carry block -> start workout -> log carry set -> reward sequence -> progression receipt -> Program.
- Focused custom/carry/routine tests passed 6/6: carry receipt, cardio receipt regression, routine authored fallback, custom carry draft metrics, exact routine entries, and legacy routine-record decoding.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T02-24-31-203Z_pid13774_689c437a.xcresult`
- App build/run for custom carry proof succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T02-25-39-425Z_pid13774_2e9d2c4b.log`
- Custom carry proof screenshots:
  - Carry block builder defaults to Farmer Carry + 40m: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_fa9fe386-1ca4-40df-95c4-defa698fee92.jpg`
  - Workout Ready with carry block: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_55cb4104-aba3-4285-9096-a1d478ad14d2.jpg`
  - Active carry logger shows LOAD + DIST: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_205a7203-2b9e-4263-a51a-97169edc56aa.jpg`
  - Custom carry completion beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_fd9b0c0f-fc82-40ad-a0b1-87a18e0a9967.jpg`
  - Custom carry progression receipt: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_d6f8c1b1-0d06-4ee6-b5d3-1d3b48bcfd83.jpg`
- Active workout reward builder now delegates to `WorkoutRewardSequenceSummary.trainingReceipt(...)` instead of maintaining a second hand-built reward payload.
- Attribute reward beats now use 0-100 attribute score coordinates for the hex, keep XP-derived integer levels/tier labels separately, and show `+N XP` for attribute gains instead of misleading `+0.0` level deltas.
- Focused active-reward regression tests passed 2/2 after the shared-builder pass: `UNBOUNDSmokeTest/testTrainingReceiptUsesAttributeScoresAndXPForAttributeBeat` and `UNBOUNDSmokeTest/testCarryPerformanceLogFeedsUnifiedReceiptShape` (`/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T02-38-47-964Z_pid13774_3bf28abe.xcresult`).
- Broader focused carry/routine/cardio/attribute test pass also succeeded 6/6 (`/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T02-35-36-399Z_pid13774_81156b3a.xcresult`).
- App build/run after the active reward shared-builder pass succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T02-39-22-578Z_pid13774_1d56bdca.log`
- Active reward UI proof screenshots:
  - Completion beat after one logged program set: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_407ec3fe-ae24-4189-8565-4b109b594c9a.jpg`
  - XP beat through shared receipt: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_daac45e5-36c8-48b3-8418-50a92be6eccc.jpg`
  - Attribute beat showing XP gain, not `+0.0`: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_4146c1ef-ae74-4c2f-a1ff-bfe4b20df461.jpg`
- `simpleReceipt(...)` remains only as a fallback/helper for non-migrated or failure-state routes, not the primary cardio/routine path.
- Removed the replaced routine-only reward sheet/payload from `ProgramOverviewView`.
- Focused reward payload tests passed 2/2: `UNBOUNDSmokeTest/testTrainingReceiptCarriesSkillRewardIntoProgramSequencePayload` and `UNBOUNDSmokeTest/testSimpleReceiptProvidesProgramSequencePayloadForNonUnifiedRoutes`.
- Focused unified cardio/routine adapter tests passed 2/2: `UNBOUNDSmokeTest/testCardioSessionAdapterFeedsUnifiedProgressionReceipt` and `UNBOUNDSmokeTest/testRoutineAdapterTurnsAuthoredChallengeStepsIntoMovementProgression` (`/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T01-26-53-612Z_pid13774_b12475b6.xcresult`).
- Follow-up reward payload regression tests passed 2/2: `UNBOUNDSmokeTest/testTrainingReceiptCarriesSkillRewardIntoProgramSequencePayload` and `UNBOUNDSmokeTest/testSimpleReceiptProvidesProgramSequencePayloadForNonUnifiedRoutes`.
- App build/run after the cardio/routine unification pass succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T01-27-43-142Z_pid13774_23c5cfe7.log`
- App build/run for the reward-shell proof succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-21T23-55-25-747Z_pid13774_3da3e755.log`
- Proof screenshots:
  - Workout Ready: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_f4e94b36-16ed-40f3-8b13-58363e4e05c6.jpg`
  - Active workout sticky completion: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_adce1d06-071f-4e97-a651-3c2dd3585356.jpg`
  - Empty completion returns cleanly: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_8007cf53-5fb4-4ab5-9ffe-543d6b5de520.jpg`
  - Program reward sequence: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_aec3a203-fc7b-4c7d-9d0d-f6fd9cc7dc23.jpg`
  - Program return after reward: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_df574ff5-f9bf-4abb-bc78-411ce6f8c0e9.jpg`
  - Skill session logger: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_79042429-007d-4367-b55c-4c512473b31a.jpg`
  - Skill set logger: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_a20665c6-2274-48e9-aa17-fd33cb4715fb.jpg`
  - Skill train chooser / quick-log entry point: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_32677e48-fa22-45b5-86af-4c915d9f9b32.jpg`
  - Quick Log train chooser after fix: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_4b241bba-e93c-4214-9356-c5e1283f905c.jpg`
  - Quick Log form after fix: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_f63c5c9c-d611-45e0-a0ba-209dacd6f416.jpg`
  - Quick Log reward proof: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_d30d55e2-e813-418d-90ea-e27a66f80478.jpg`
  - Quick Log return after Continue: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_d0d51bd5-675f-4910-b420-8aaf3e883720.jpg`
  - Structured skill detail proof start: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_da564c66-278b-4284-b3f7-48d573cc367f.jpg`
  - Structured skill train chooser: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_c9bac258-0efb-46a4-a086-b33b778c1991.jpg`
  - Structured skill session logger: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_58b738da-e612-4a56-98d2-23e6d9256a57.jpg`
  - Structured skill set logger: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_858d910a-5d83-4000-9b39-17928b5d7986.jpg`
  - Structured skill session ready to finish: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_261d8bf1-05c2-4599-a11d-d5120e535f72.jpg`
  - Structured skill reward proof: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_c53603ae-4dad-4f23-a476-7d568af03c2d.jpg`
  - Structured skill return after Continue: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_33534f3f-48ce-4344-a916-835670d4990f.jpg`
  - Quick Log program-style completed beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_8ad258b3-ea48-43a8-ae04-60537cacec73.jpg`
  - Quick Log program-style XP beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_b33db0f0-88d5-4bea-b172-47b648878efa.jpg`
- Quick Log program-style reward callouts beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_41ca05dd-a970-4fb3-a363-f5f66ce98e7d.jpg`
- Quick Log program-style progression receipt beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_93270f13-a93f-4df7-abd6-6367f138b07b.jpg`

2026-05-22 follow-up notes:
- Progression integration coordinator pass completed on branch `codex/progression-overall-rank-trials`.
- Committed the missing active-workout metric UI baseline so mixed loggers compile from committed source: `ExerciseLogCard` and `SetLogGridRow` now render block-aware `WEIGHT/LOAD`, `REPS/HOLD/TIME/DIST/CAL`, and suggestion values from `TrainingMetricKind`.
- MovementCatalog caller migration advanced: deterministic and local program generation now use MovementCatalog program definitions, structured equipment compatibility, canonical exercise preferences, movement-slot filtering, and catalog substitutions; ProgressionEngine now resolves saved movement/rank-standard IDs through MovementCatalog and applies `WeightPlatePolicy` bumps.
- Overall Rank Trial runner advanced beyond V1: added Forged -> Veteran gate `The Reckoning`, including readiness, draft mapping, pass/fail attempt logging, and duplicate completion protection.
- Weekly Vow polish integrated as a narrow slice: saved `PerformanceLog` gating now records a persistent completion ledger, prevents duplicate bonus consumption, adds Vow bonus metadata, and only exposes Apex share-card metadata after real saved work.
- Focused simulator proof on iPhone 17 passed after the integrated slices: 98/98 across `MovementResolverTests`, `ExerciseEquipmentClassifierTests`, `ProgressionEngineBehaviorTests`, `DeterministicProgramGeneratorTests`, `OverallRankTrialServiceTests`, `WeeklyVowsServiceTests`, and `WeeklyVowsStoreTests`.
- Combined result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T01-24-22-220Z_pid85954_8af81497.xcresult`
- Remaining integration caution: the broad Weekly Vow worker branch still contains additional attribute/reward/model changes that were not cherry-picked; Profile/Settings also contain unrelated local redesign/dev-bootstrap edits and should be reconciled separately rather than overwritten by older agent UI hunks.

2026-05-23 four-agent split pass:
- MovementCatalog cleanup added `progressionDefinitions(...)` as the canonical progression-family helper, moved local calisthenics picks and the progression ladder off direct `ExerciseCatalog` family reads, and made `ProgressionEngine` use exact logged MovementCatalog definitions for family unlocks even when AP/rank state rolls up to a rank-standard movement.
- Overall Rank Trial coverage expanded with `The Gauntlet`, the Forged -> Veteran gate, including MovementCatalog-backed readiness, draft, pass/fail, and duplicate-attempt coverage.
- Weekly Vow receipt polish now keeps share-card subtitles, badge progress, and cosmetic progress explicitly in Vow language.
- Phase 9 guardrails now mark the legacy Program logger as a quarantined compatibility route and document that new AP/XP/LV/body-map/skill/rank/reward writes must enter through `PerformanceLog -> TrainingCompletionService`.
- Combined XcodeBuildMCP focused simulator suite passed 114/114 on iPhone 17 across MovementCatalog, progression engine, deterministic generation, Overall Rank trials, Weekly Vows, and legacy Program logging guardrail tests.
- Combined result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T02-01-36-785Z_pid85954_95290b8e.xcresult`
- Replaced the brittle parent-level routine completion handoff with inline `RoutineCompletionFlow`: `RoutinePlayerView -> TrainingCompletionService -> WorkoutRewardSequenceView -> Program/Routines`.
- Added DEBUG bootstrap coverage for `--unbound-open-routine` and `--unbound-open-cardio-log`, so simulator proof routes start from the real app shell instead of presenting over onboarding.
- Removed the remaining old `WorkoutLoggingViewModel.makeRewardSequenceSummary()` helper; `WorkoutLoggingView` now asks the view model for a `trainingReceiptSummary(for:)` backed by `WorkoutRewardSequenceSummary.trainingReceipt(...)`.
- Cardio UI proof completed: `LogCardioView -> Log session -> WorkoutRewardSequenceView -> FINISH -> Home`.
- Cardio proof also fixed the small-screen CTA issue by pinning `Log session` to the bottom safe area instead of leaving it below the scroll viewport.
- Cardio proof screenshots:
  - Pinned cardio logger CTA: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_dea85139-6b02-4d48-91e1-93b1cfa1d46e.jpg`
  - Shared reward completion beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_e24396e4-c2b1-4924-a922-5518dc432282.jpg`
  - Rewards collected beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_5fa95e96-b8dd-47fe-8df3-590a285c059e.jpg`
  - Return to Home: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ace85432-776c-4132-869c-7c6a45384577.jpg`
- Routine UI proof completed using `100-pushup`: `Routine Ready -> START ROUTINE -> Routine player -> RETURN -> shared reward sequence -> FINISH -> Program/Routines`.
- Routine proof screenshots:
  - Routine ready gate: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ca3ab9f6-de70-4c9d-9c0f-8909e8bdb358.jpg`
  - Routine player after explicit start: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_05bdf863-37e3-4d25-862d-2898084e3249.jpg`
  - Routine completion face: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_dac1c1fc-b382-408e-8eeb-d1bff7574213.jpg`
  - Shared reward completion beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_c228bd2f-cf76-4690-bdd9-b1f98e9f5712.jpg`
  - XP beat with level bar: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ca621e7b-fc19-4794-93e3-a36c7f0da2d5.jpg`
  - Attribute XP beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_c0e33adc-a7af-48c5-9f51-776a61d419e5.jpg`
  - Progression receipt beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_4dae0258-e072-451b-a444-49b43baedfea.jpg`
  - Rewards collected beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ecf42e08-8749-4510-8417-eb466c61e087.jpg`
  - Return to Program/Routines: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_96cd0be4-185d-4554-ad19-0b9c984dc633.jpg`
- Focused post-fix tests passed 4/4: cardio receipt, routine receipt, movement catalog policy validation, and movement catalog final-state query surfaces.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T05-14-21-643Z_pid13774_721d27cf.xcresult`
- Focused routine adapter regression passed 1/1 after the ready-gate change: `UNBOUNDSmokeTest/testRoutineAdapterTurnsAuthoredChallengeStepsIntoMovementProgression` (`/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T05-38-37-548Z_pid13774_9ae5f5ab.xcresult`).
- App build/run for cardio UI proof succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T05-05-37-285Z_pid13774_1b34629d.log`
- App build/run for routine UI proof succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T05-30-49-096Z_pid13774_92d3e9bc.log`

2026-05-22 scheduled skill + mixed-session notes:
- `DailyWorkoutResolver` now resolves scheduled skill goals against the selected draft date instead of only today's date, so future/selected Program days can include the correct skill blocks.
- `WorkoutReadyView` now uses the draft date for adding scheduled skill blocks and exposes block-row accessibility identifiers for simulator proof.
- Added a DEBUG-only proof bootstrap flag, `--unbound-proof-scheduled-skill <skillId>`, that pins one skill goal, schedules today's category for it, and clears only that skill's recent training cap.
- Added a mixed-session adapter regression proving strength + skill + cardio + carry metrics survive draft -> active workout -> `PerformanceLog`.
- Simulator proof completed for Program active goal routing: Program opened with `Wall Handstand` routed into today's Program Workout Ready.
- Simulator proof completed for mixed active completion: Program strength block + scheduled `Wall Handstand` skill block + added `Farmer Carry` carry block -> active workout -> logged sets -> unified reward sequence -> Program return.
- Mixed proof screenshots:
  - Scheduled skill in Workout Ready: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_9653f427-b67e-420f-ba56-237de861c3bb.jpg`
  - Mixed Workout Ready with 3 blocks: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_9910d73d-425b-467c-8298-df2ade506e09.jpg`
  - Mixed progression receipt with Movement AP, Attribute XP, Level XP, and Skill XP: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_52afc87f-f4c6-4ba5-b9c1-3f62b6d04528.jpg`
  - Program return after rewards: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_da47eb3c-5b29-4371-9737-e2b6861454e2.jpg`
- Focused post-fix tests passed 5/5 for daily resolver + mixed session adapter coverage:
  `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T06-36-30-560Z_pid13774_74577f85.xcresult`
- App build/run for scheduled skill mixed proof succeeded:
  `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T06-37-04-762Z_pid13774_28ec2afc.log`
- Resolved later on 2026-05-22: the Program `BEGIN SESSION` CTA now stays above the floating tab bar on the iPhone 16e simulator.

2026-05-22 Workout Ready edit/save + manual Skill Detail Add-to-Program closure notes:
- `WorkoutReadyView` now recalculates the draft estimate after add/remove/edit operations, uses a dedicated block edit sheet for sets/targets/notes, disables `Add Scheduled Skill` once all eligible scheduled skills are already present, and preserves the active skill goal when a scheduled block is removed from today's draft.
- `ProgramScheduler` now exposes `nextEligibleDate(forSkillId:from:daysToSearch:)`, letting Skill Detail explain the next matching Program day before the user pins a skill.
- `SkillDetailView` now labels the manual pin action with `Next program day: ...` and its Add-to-Program path was proven in the same running app process from Skill Detail -> Program -> Workout Ready. Note: relaunching debug builds with `--unbound-open-program` re-runs the dev bootstrap and can overwrite manual active-goal proof state, so same-process navigation is the correct proof route.
- `ProgramOverviewView` now keeps the `BEGIN SESSION` CTA to one line with tightening/scale behavior and verified spacing above the tab bar on iPhone 16e.
- Added DEBUG-only `--unbound-reset-active-goals-for-proof` so manual Skill Detail proof can start below the active-goal cap without changing production behavior.
- Simulator proof completed for Workout Ready depth: removed a scheduled skill block, re-added it without unpinning the active skill goal, edited the skill block sets, added a mixed block, saved a recent custom draft, started the active workout, and reordered blocks.
- Simulator proof completed for manual skill routing: Skill Detail `Crow Pose` -> `Add to Program` -> Program showed `Crow Pose` routed to Friday Skills Day -> Workout Ready showed `Crow Pose` as a scheduled skill block.
- Closure proof screenshots:
  - Manual Add-to-Program chooser: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_59c142b3-139a-46ea-95cb-383c550912bb.jpg`
  - Add row changed to In Program: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_d07efeff-fbf2-4d79-ad2f-f323fe765415.jpg`
  - Program card with Crow Pose routed today and CTA above tab bar: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_d8fdbb30-d9b3-420e-b595-a84a80def322.jpg`
  - Workout Ready with Crow Pose scheduled block: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_7e281ca1-0a88-4f90-b980-a80d085a894a.jpg`
  - Workout Ready reorder proof, Crow Pose moved above Power Upper: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ea41472d-6ed2-4eae-ab5d-bc6c383f7420.jpg`
- Focused tests passed 5/5 for daily resolver + scheduled skill routing coverage:
  `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T16-54-37-628Z_pid85954_fd4fb3a7.xcresult`
- App build/run for final manual Skill Detail proof succeeded:
  `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T16-57-58-949Z_pid85954_8db873f6.log`

## Phase 2 — Workout Ready Becomes The Only Pre-Start Surface

**Goal:** Generated programs, scheduled skill work, and custom sessions all pass through `WorkoutReadyView` before starting.

Implementation work:
- Route Home `BEGIN SESSION` through `TrainingSessionDraft` and Workout Ready, or intentionally keep a shortcut that still uses the same draft internally.
- Program overview should create a daily draft with generated program blocks plus scheduled skill blocks.
- Workout Ready supports:
  - reorder blocks
  - remove today's block only
  - add skill block
  - add exercise block
  - edit sets/reps/holds/time/distance/load
  - save recent draft
  - start session
- Recent custom drafts remain V1 local reuse, not recurring templates.

Tests:
- Program `Workout` -> `TrainingSessionDraft` preserves exercises.
- Scheduled skill block appears in the same draft as program work.
- Removing a scheduled block from today does not delete the active skill goal.
- Custom draft round-trips locally.

Exit criteria:
- A user has one obvious "workout ready" moment before training.
- No visible path starts a hidden separate logger with incompatible data.

Current status: **Stable for V1. Program start, scheduled skill insertion, manual skill routing, edit/remove/add/reorder/save-draft, and start depth are simulator-proven. Future work is UI polish and richer template persistence, not blocking migration proof.**

## Phase 3 — Block-Specific Loggers On One Session Runtime

**Goal:** Different block types keep appropriate UI, but all completion data becomes `PerformanceLog`.

Logger modes:
- Strength/bodyweight reps: weight, reps, RPE, warmup.
- Skill: attempts, reps, hold seconds, assistance/load, RPE, quality.
- Cardio: time, distance, calories, heart rate/RPE.
- Carry/sled: load, duration, distance, side, posture/quality.
- Routine: timer, step completion, notes.
- Mobility/prehab: duration, side, quality, pain/safety notes if needed.

Implementation work:
- Expand `ActiveWorkoutSession` to represent non-strength block rows cleanly.
- Avoid forcing holds/cardio/carries through rep-only rows.
- Preserve `movementId`, `rankStandardMovementId`, and exact variant identity on every completed row.
- Make empty blocks impossible to complete accidentally unless the user confirms skip.

Tests:
- Mixed draft with strength + handstand hold + row + carry preserves all metrics.
- Hold seconds, side, distance, duration, load, RPE, quality are not dropped.
- Logger UI selected from `TrainingBlock.kind` / movement logger metadata.

Exit criteria:
- The logger never asks "how many reps?" for a pure hold/cardio/carry block.
- Completion service receives complete metrics without string guessing.

Current status: **Partial. Strength/bodyweight reps, skill hold session, custom carry, cardio quick log, and routine player routes are now simulator-proven through unified receipts. A mixed active workout with strength + scheduled skill + carry is also simulator-proven. Cardio/routine blocks inside one active workout still need proof only if they become normal mixed-session blocks.**

## Phase 4 — Skill-To-Program Integration

**Goal:** Skills are no longer a separate island. They can be trained on the spot or scheduled into the user's program.

Implementation work:
- "Add to Program" pins a skill as an active goal.
- Active skill goals become program modifiers read by the daily resolver.
- Skill blocks appear on matching days based on slot, fatigue, prerequisites, and program intent.
- Skill Detail "Start Session" creates a skill-only draft/performance log.
- Quick logs create a minimal `PerformanceLog`, not an isolated `SessionLog` island.
- Skill prerequisites are enforced in the UI: locked skills explain what skill/movement standards unlock them.

Tests:
- Add Handstand to program -> next eligible upper/control day includes handstand block.
- Remove handstand block from today -> active handstand goal remains pinned.
- Skill-only session awards skill XP and progression receipt.
- Quick log updates skill progress and completion history once.

Exit criteria:
- A skill can be trained now or inserted into the plan.
- Skill progress updates from both paths without duplicate side effects.

Current status: **Stable for V1. Skill-only session reward route, Quick Log UI reward route, scheduled skill block insertion, and the fully manual Skill Detail "Add to Program" -> next eligible Program day -> Workout Ready path are simulator-proven. Remaining work is deeper scheduling intelligence, not the core bridge.**

## Phase 5 — Movement Library Becomes The App Source Of Truth

**Goal:** `MovementCatalog` owns identity, ranking, logging, programming, rewards, and domain links.

Implementation work:
- Finish metadata for every ranked standard:
  - `id`
  - display name
  - aliases
  - movement slot
  - equipment
  - logger mode
  - default metric
  - rank template / standard ladder
  - variant roll-up target
  - attribute weights
  - body regions
  - skill associations
  - contraindication tags
- Convert `ExerciseCatalog` into a compatibility shim or delete it after callers migrate.
- Resolve all variant chains deterministically.
- Validate no unrelated exercise credits the wrong skill family.
- Add all gym staples needed for normal programming without overwhelming discovery UI.

Tests:
- Every `variantOfMovementId` and `rankStandardMovementId` points to an existing standard.
- Every ranked standard has a 9-tier ladder or declared non-ranked reason.
- Every movement has a logger mode.
- Every movement has attribute weights and body regions.
- Program generator never picks a push movement for a pull slot.
- Resolver handles variant -> variant -> standard chains predictably.

Exit criteria:
- Program generation, substitutions, logging, AP, ranks, attributes, body map, and trials all read movement metadata from one source.

Current status: **Core progression spine migrated; compatibility cleanup remains.** Validation tests pass for current policy and final-state query surfaces. Program generation, substitutions, draft/log metadata, default logger metrics, exercise preferences, library, swap, detail surfaces, AP/rank progression, attributes/body-map, scan volume, Weekly Vow prescriptions, and Overall Rank trials now use `MovementCatalog` metadata. Remaining work is removing or shrinking `ExerciseCatalog` once all compatibility users are gone.

2026-05-22 Agent A MovementCatalog caller migration goal/status:
- Goal for `codex/progression-movementcatalog-migration`: migrate callers from legacy `ExerciseCatalog` / ad hoc exercise metadata to `MovementCatalog` without touching Weekly Vows, Overall Rank trials, or UI redesign.
- Completed in this slice: `DeterministicProgramGenerator` now filters day templates by `MovementCatalog.movementSlot`, so pull days cannot leak push-slot movements through broad shared tags like arms; `LocalProgramGenerator` calisthenics progression picks now read progression family/tier/display/substitution metadata from `MovementCatalog` instead of calling `ExerciseCatalog` directly; `TrainingSessionAdapters` hydrates draft prescriptions with catalog movement id, rank-standard id, and catalog muscle groups; `ActiveWorkoutSession` uses `MovementCatalog.defaultMetric` for nonspecific AMRAP logger rows.
- Test coverage added: pull template slot safety, variant draft metadata hydration, AMRAP hold logger defaults, AP gain rank-standard preservation, attribute contribution, and body-region metadata survival.
- Agent A second pass: exercise preferences, exercise library, workout detail, exercise detail, and swap sheet surfaces now show MovementCatalog display names, slots, logger modes, rank templates, equipment, and muscle metadata. Saved display names, canonical names, and legacy underscore names resolve through shared preference lookup compatibility. Swap alternatives stay same-slot and program-compatible.
- Previously remaining caller groups are now covered for the progression spine: legacy progression/rank fallback resolution, Weekly Vow prescription selection, trial-readiness standards, and scan/body-volume aggregation all route through `MovementCatalog`. Still remaining: eventual quarantine/deletion of `ExerciseCatalog` after compatibility users and tests no longer need the raw legacy list.

2026-05-23 coordinator MovementCatalog bridge:
- Added catalog-backed conditioning skill target definitions for the carry/sled standards used by Overall Rank trials (`co.bw-farmer-carry`, `co.1.5x-farmer-carry`, `co.2x-farmer-carry`, and `co.sled-push`). `SkillGraph.shared` still hides conditioning nodes from the visible V1 skill tree, but trial readiness can now resolve those standards through `MovementCatalog` instead of raw strings.
- Focused proof included `OverallRankTrialServiceTests`, which now asserts every trial movement, performance standard, and skill standard resolves through MovementCatalog.

2026-05-23 MovementCatalog final caller pass:
- Added `MovementCatalog.resolvedTrainingMovement(...)` as the shared resolver for saved `movementId`, saved `rankStandardMovementId`, canonical names, and legacy underscore/display names. Variant IDs now canonicalize to their rank standard before AP/rank progression state is seeded.
- `MovementAPCalculator`, `ProgressionEngine`, and `ScanContextBuilder` now prefer saved catalog IDs and fallback to catalog name resolution, so AP gains, working-weight progression, body-map/scan muscle volume, and legacy history all agree on the same exact movement + rank-standard pair.
- Focused coverage proves saved variant IDs, bad variant standard IDs, and legacy names still resolve to the canonical standard; scan-volume aggregation uses `MovementCatalog` muscle metadata instead of `ExerciseCatalog`.

## Phase 6 — Unified Receipt + Reward Callouts

**Goal:** Every completed session gets one coherent receipt.

Receipt sections:
- Movement AP
- Attribute XP
- Overall LV XP
- Skill XP when relevant
- Rank-ups
- PRs
- Badge unlocks
- Body map updated
- Trial progress when relevant

V1 callouts:
- PRs
- Badge unlocks

Next callouts:
- First clean standard
- Trial completion
- Comeback trial re-run
- Program consistency milestone
- First time training a new movement family

Implementation work:
- Replace route-specific reward summaries with one receipt builder.
- Keep cinematic reward sequence for full workout completion.
- Use the same full-screen reward sequence for quick logs/skill sessions; content changes by source, not the shell.
- Rank-ups stay distinct from PRs/badges.
- Do not add a separate Feats model; persistent named accomplishments are Badges.
- AP/XP display is whole-number truth.

Tests:
- Program, skill, custom, cardio, carry, routine completions emit the same receipt shape.
- PR and badge counts match receipt callouts.
- No decimal AP/XP appears in reward UI.

Exit criteria:
- The user can understand "what I earned" without knowing which logger route they used.

Current status: **Mostly done for V1. Program workout completion, Quick Log, structured skill sessions, cardio logs, routine completions, custom carry completions, and a mixed strength + scheduled skill + carry workout now route to `WorkoutRewardSequenceView`. `WorkoutRewardSequenceSummary.trainingReceipt(...)` is the shared builder for unified completion results; cardio, routine, custom carry, and active workout completion now feed it through `PerformanceLog` + `TrainingCompletionService` instead of hand-built reward payloads. Remaining work is deleting old completion/save paths as each route is fully replaced.**

## Phase 6A — Weekly Vows Migration

**Goal:** The current weekly Trial/Challenge concept becomes optional Weekly Vows, leaving "Trial" reserved for Overall Rank gates.

Final product concepts:
- **Ember** — rest-day / low-day vow, recovery-safe, 8-12 minutes, RPE 3-5.
- **Overdrive** — after-workout finisher, 6-12 minutes, RPE 7-8.
- **Apex** — dedicated weekend event, 20-45 minutes, RPE 8-9.

Implementation work:
- Introduce `WeeklyVow` naming and keep old `Trial*` types as temporary adapters only while migrating.
- Rename weekly picker/cards/copy away from Trial/Challenge language.
- Scale vows from movement ranks, skill ranks, recent volume, equipment, path, and recovery state.
- Route vow completions through `TrainingSessionDraft` -> `PerformanceLog` -> `TrainingCompletionService` -> `WorkoutRewardSequenceView`.
- Award normal AP/attribute/body/skill/LV rewards from the actual work.
- Award Vow completion bonus as Overall LV XP, badge progress, cosmetic progress, and optional Apex share card.
- Do not award flat attribute XP for clearing a vow.

Tests:
- Weekly Vow completion emits the same receipt shape as any other workout.
- Ember prescriptions do not violate rest-day recovery limits.
- Overdrive attaches after a completed workout without double-saving that workout.
- Apex can run as its own session and generate a shareable completion beat.
- No user-facing weekly copy says "Trial."

Exit criteria:
- A user can opt into a weekly event without thinking it affects Overall Rank Trial eligibility.

Current status: **Catalog-backed unified Vow route implemented and simulator-tested.** Weekly Vow drafts now carry `MovementCatalog` movement IDs, rank-standard IDs, display names, and muscle metadata; saved-work gating, one-time bonus ledger behavior, badge/cosmetic progress, and Apex share-card metadata are service-tested. Remaining follow-up is richer user-state scaling and final share-card UI/artifact polish.

2026-05-22 Agent B / `codex/progression-weekly-vows` goal: migrate the weekly `Trial*` / challenge concept into **Weekly Vows** with Ember, Overdrive, and Apex as the user-facing choices. Preserve old saved weekly state through temporary adapters while reserving "Trial" for Overall Rank gates.

Temporary adapters to track during this branch:
- `Trial`, `TrialCard`, `TrialCardKind`, `TrialTheme`, `TrialCapstone`, `TrialsState`, `TrialsStore`, `TrialsService`, `TrialsServiceProtocol`, and `TrialsNotificationScheduler` remain as typealiases or protocol adapters while existing callers and tests move to `WeeklyVow*` naming.
- Legacy notification names such as `.trialCompleted`, `.trialPicked`, and `.trialWeekRolled` still post alongside `.weeklyVowCompleted`, `.weeklyVowPicked`, and `.weeklyVowWeekRolled` so older observers do not miss weekly completions.
- `SquadActivityEntry.Kind.trialCompleted` and `SquadActivityPayload.trialCompleted` remain persistence/backend adapters; squad UI copy should render Weekly Vow language.
- UserDefaults keys under `unbound.trialsState.*` are read once and migrated idempotently to `unbound.weeklyVowsState.*`; old keys are not deleted in this lane.

2026-05-22 Agent B completion notes:
- Added `WeeklyVow*` models/store/service/generator naming with `Trial*` typealiases and old method/notification adapters kept temporarily.
- Weekly Vow generation now presents Ember, Overdrive, and Apex prescriptions with duration/RPE placement metadata; legacy `aligned/growth/prestige` raw values decode to `ember/overdrive/apex`.
- Weekly Vows state saves under `unbound.weeklyVowsState.*`, reads legacy `unbound.trialsState.*`, migrates idempotently, and does not delete old keys in this lane.
- Home, picker, card, notification, title, honor, squad, and friend-challenge user-facing copy now says Weekly Vow / Vow Proof / Ember / Overdrive / Apex instead of weekly Trial/Challenge language.
- Vow completion does not award flat attribute XP; the later open item is routing actual vow work through the unified training completion pipeline for normal AP/attribute/body/skill/LV rewards.
- Focused simulator tests passed 47/47 after one warm rerun: `WeeklyVowGeneratorTests`, `WeeklyVowsServiceTests`, `WeeklyVowsStoreTests`, `WeeklyVowKindTests`, `WeeklyVowThemeTests`, `WeeklyHonorTests`, and `SquadActivityServiceTests`.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T18-44-55-731Z_pid13663_925b8179.xcresult`
- Isolated retry for the earlier restarted threshold test passed: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T18-44-08-431Z_pid13663_59d8a29c.xcresult`
- App build/run for Weekly Vows proof succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T18-47-49-205Z_pid13663_aff8e6b7.log`
- Weekly Vows proof screenshots:
  - Home prompt before pick: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_beecf72a-a45a-448b-93ed-c464ab4af7f3.jpg`
  - Picker with Weekly Vow / Ember vocabulary and Vow Proof copy: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_03069f1e-a375-4d05-8441-c84c592558f7.jpg`
  - Home active Weekly Vow card after commit: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_74ad10b8-e43e-4903-a208-4e747bc95518.jpg`

2026-05-22 Agent B second-pass completion routing notes:
- Active Weekly Vows now build real `TrainingSessionDraft`s with `programId = weekly-vow:<vow.id>` and concrete prescriptions.
- The active Weekly Vow card launches `WorkoutReadyView`; completed logs flow through `TrainingCompletionService` and the existing `WorkoutRewardSequenceView`.
- `recordCompletedVowWork(...)` marks a Vow completed only when the saved `PerformanceLog` matches the current Vow marker and contains actual completed work.
- Compatibility `Trial*` aliases and legacy notifications remain.
- Focused Weekly Vow simulator tests passed 38/38 on iPhone 17.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T20-14-10-542Z_pid81496_b6e7368f.xcresult`
- UI proof build/run succeeded: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/build_run_sim_2026-05-22T20-10-58-858Z_pid81496_e62979bc.log`

2026-05-23 Weekly Vow catalog-prescription pass:
- Weekly Vow training prescriptions now resolve through `MovementCatalog`, carrying `movementId`, `rankStandardMovementId`, catalog display name, and muscle groups into `TrainingSessionDraft` prescriptions.
- Added safe catalog fallbacks for legacy proof names such as `box jump` while preserving Vow intent, same-slot behavior, and Ember/Overdrive/Apex RPE/duration envelopes.
- Added focused tests for catalog metadata in Vow drafts, Vow-only copy, saved-work share-card gating, and one-time bonus ledger behavior.

## Phase 7 — Trial Readiness + Overall Rank Gate

**Goal:** Overall rank becomes earned through named trials, not an aggregate score.

2026-05-22 Agent C branch note: `codex/progression-overall-rank-trials` is implementing the V1 Trial Readiness evaluator, named Overall Rank trial gate, service runner, and minimal Profile start surface. Initial target is service-tested and simulator-proven for one meaningful Overall Rank trial; proof status will be updated after focused tests/builds.

Implementation work:
- Build `TrialReadinessService`:
  - movement standards at target tier
  - skill standards at target tier
  - top-N attribute floor
  - min Overall LV
  - path/variant suggestion
- Build Trial Readiness card on Profile.
- Implement trial unlock state: locked -> ready -> attempted -> passed/failed.
- Build trial runner using the same `TrainingSessionDraft` / `PerformanceLog` pipeline.
- Passing a trial advances overall rank.
- Trial re-runs create badge/callout events and can activate comeback velocity.

Tests:
- User cannot advance overall rank without passing trial.
- Meeting requirements unlocks the correct trial.
- Trial variants are path-aware and equipment-aware.
- Failed trial logs history but does not advance rank.
- Passed trial emits overall rank update, badge/callout event, and receipt.

Exit criteria:
- Overall rank is no longer a passive computed label. It is earned by passing the named workout.

Current status: **V1 ladder implemented and simulator-tested through Ascendant.** Overall Rank trials now cover every transition from Initiate -> Ascendant with MovementCatalog-backed readiness, draft mapping, pass/fail logging, duplicate protection, and rank advance only on pass. Comeback and duplicate attempt callout data are service-tested; richer UI surfacing, badge activation, path/equipment variants, and cleanup of any passive aggregate-rank surfaces remain.

2026-05-22 Agent C / `codex/progression-overall-rank-trials` completion notes:
- Added `OverallRankTrialService.swift` with the pure `TrialReadinessService`, V1 `The Awakening` definition, persisted attempt state, and `OverallRankTrialRunner`.
- V1 readiness checks Overall LV, top-N attribute floor, movement AP, skill tier, and equipment, and reports missing/met requirement rows for UI.
- Added `TrainingSessionSource.overallRankTrial` and routed pass/fail attempts through `TrainingSessionDraft` -> `PerformanceLog` -> `TrainingCompletionService`.
- Active workout completion now records overall-rank trial attempts after unified completion and injects the rank-up into the existing reward sequence only when the named trial is passed.
- Profile now shows the minimal Overall Rank Trial readiness card with locked/ready/failed/passed states and starts the rank-trial runner without redesigning Profile.
- Added DEBUG proof bootstrap flag `--unbound-proof-rank-trial-ready` to seed a ready dev-player state for simulator proof.
- Focused tests passed 5/5 on iPad mini (A17 Pro) simulator `FC56466C-9963-4EC4-9841-5267D758B8F7`: readiness locked, readiness ready, draft-to-performance-log mapping, failed attempt/no rank advance, passed attempt/idempotent rank advance.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T18-46-05-251Z_pid13737_5325b5c0.xcresult`
- Focused build/test log: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/test_sim_2026-05-22T18-46-05-251Z_pid13737_72d661ca.log`
- Simulator proof used the app built by the focused test run, installed it onto the assigned simulator after a transient `build_run_sim` DerivedData lock, and launched with `--unbound-proof-rank-trial-ready --unbound-open-profile`.
- Trial proof screenshots:
  - Profile ready-state card: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_e39cf837-c930-46e4-8cda-d1675335932b.jpg`
  - Workout Ready rank-trial runner: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ddcf0eaf-be8c-402f-9ebe-bac9f3990c52.jpg`
  - Active trial logger with planned pass metrics: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_a84c821a-ec69-4e29-bc75-cafaa3ad80c6.jpg`
  - Completion beat: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_f478ab6e-9bc5-4761-a60b-c7fcab0af45e.jpg`
  - Overall Rank rank-up to Novice: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ffd0143e-4614-4e8f-8d81-4bc5be4aba8b.jpg`
  - Progression receipt: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_59a50c70-0b60-4190-84b2-926fb1181bca.jpg`
  - Profile passed-state card after reward finish: `/var/folders/1p/5wt2_h6x6pd2lyqwmyf10_6c0000gn/T/screenshot_optimized_ccaaf711-e663-468f-a32b-95200caf0870.jpg`

2026-05-22 coordinator integration pass:
- Integrated Agent A/B/C work in the shared worktree and fixed two broad-suite regressions found after the individual lane proofs.
- `WorkoutRewardSequenceSummary.trainingReceipt(...)` now includes Skill XP in the XP beat only when a reward payload explicitly carries skill XP, while preserving the invariant that a bare skill-only progression receipt does not move the Overall LV/account XP bar.
- `SquadMissionService.generateThisWeek(...)` now clamps ephemeral squad member count to at least one so locally generated fallback missions never have a zero target.
- Full XcodeBuildMCP simulator suite passed 615/615 on iPhone 16e simulator `280AE372-B5CE-4700-8108-A0666B407CC8`.
- Full suite result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T19-12-20-282Z_pid85954_6c52f30f.xcresult`
- Full suite log: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/test_sim_2026-05-22T19-12-20-281Z_pid85954_2bda39ed.log`

2026-05-22 progression integration review:
- Focused XcodeBuildMCP simulator suite passed 77/77 on iPhone 16e, covering MovementCatalog validation/callers, movement progress, training adapters, Weekly Vows naming/state/squad compatibility, squad mission fallback generation, and Overall Rank Trial readiness/runner behavior.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T19-34-59-399Z_pid85954_4bd8f4b9.xcresult`
- Focused log: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/test_sim_2026-05-22T19-34-59-399Z_pid85954_54623cc3.log`

2026-05-22 three-agent second integration pass:
- Agent A migrated additional MovementCatalog callers in exercise preferences, exercise library, workout detail, exercise detail, and swap sheets. Saved display names, canonical names, and legacy underscore names resolve through shared preference lookup compatibility; swap alternatives stay same-slot and program-compatible.
- Agent B implemented the Weekly Vow training route described above.
- Agent C added the second Overall Rank trial, `The Calibration` for Novice -> Apprentice, with LV/equipment/movement/skill readiness gates and 14-round pull-up / push-up / squat performance standards.
- Coordinator focused XcodeBuildMCP simulator suite passed 110/110 on iPhone 16e, covering MovementCatalog, Weekly Vows, TrainingSession adapters, Squad compatibility, and Overall Rank Trial expansion.
- Focused result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T20-16-42-985Z_pid85954_6bc8c519.xcresult`
- Full XcodeBuildMCP simulator suite passed 625/625 on iPhone 16e.
- Full suite result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-22T20-18-25-617Z_pid85954_e1be58c9.xcresult`
- Full suite log: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/logs/test_sim_2026-05-22T20-18-25-616Z_pid85954_5383312d.log`

2026-05-23 upper-rank trial pass:
- Added the remaining upper Overall Rank gates: `The Ten Hundred` (Master -> Vessel), `The Threshold` (Vessel -> Unbound), and `The Ascension` (Unbound -> Ascendant).
- Each upper trial includes Overall LV, top-attribute floor, equipment, movement AP, skill tier, draft mapping, pass/fail, duplicate-attempt, and catalog-backed definition coverage.
- Focused XcodeBuildMCP simulator test pass on iPhone 17: `OverallRankTrialServiceTests` passed 31/31.
- Result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T04-05-27-328Z_pid85954_f8e597a7.xcresult`

2026-05-23 Overall Rank trial callout pass:
- Added `OverallRankTrialRunCallout` result data for duplicate attempts and comeback clears. Duplicate attempts now report that the attempt was already counted; passing after prior failed attempts reports a comeback clear.
- Rank semantics are unchanged: failed attempts record history without advancing, passed named trials advance the target rank once, and duplicate performance log IDs do not advance again.
- Focused coverage added for comeback-pass callouts and duplicate-callout assertions.

## Phase 8 — Program Modifiers + Daily Resolver

**Goal:** Monthly programs are stable plans, but the daily workout adapts through deterministic modifiers.

Modifiers:
- Active skill goal
- Travel/equipment limits
- Deload week
- Trial readiness / trial prep
- Fatigue / recent body-map saturation
- User dislikes/unavailable movements

Implementation work:
- Expand `DailyWorkoutResolver`.
- Resolve slots using `MovementCatalog` metadata.
- Prefer deterministic rules first; reserve AI for high-friction explanations or unusual plan rewrites.
- Keep generated monthly plan readable and stable.
- Apply modifiers mid-cycle without regenerating the whole month unless needed.

Tests:
- Add pull-up skill mid-month -> resolver inserts pull-up work without wrecking the plan.
- Travel mode with dumbbells only -> substitutes compatible movements.
- Deload -> lowers volume/intensity cleanly.
- Trial prep -> nudges sessions toward missing requirements.

Exit criteria:
- The app can adjust today's workout without calling AI for normal cases.

Current status: **Partial.** Scheduled-skill tapering is proven, and deterministic V1 daily modifiers now cover equipment/travel substitutions, deload volume reduction, trial-prep injections, and avoided-movement swaps.

2026-05-23 Daily Resolver modifier pass:
- Added `DailyWorkoutModifierContext` so `DailyWorkoutResolver.programDraft(...)` can adapt today's draft without regenerating the monthly plan.
- Implemented same-slot MovementCatalog substitutions for equipment limits and avoided movements, deload set/RPE reduction with notes, and missing trial-prep movement injection.
- Existing scheduled-skill tapering remains intact.
- Focused XcodeBuildMCP simulator test pass on iPhone 17: `DailyWorkoutResolverTests` passed 9/9.
- Result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T04-03-36-326Z_pid85954_81007de0.xcresult`
- Integrated focused XcodeBuildMCP simulator proof passed 74/74 on iPhone 17 across `DailyWorkoutResolverTests`, `OverallRankTrialServiceTests`, `MovementResolverTests`, `ProgramAwareLoggingTests`, and `TrainingSessionDraftStoreTests`.
- Integrated result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T04-07-38-901Z_pid85954_0241e8fd.xcresult`
- Completion adapter guardrail proof also passed 29/29 across `MovementProgressServiceTests` and `TrainingSessionAdapterTests`.
- Completion guardrail result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T04-08-26-121Z_pid85954_15f2f22d.xcresult`
- Four-agent integrated progression migration proof passed 131/131 on iPhone 17 across `MovementResolverTests`, `MovementProgressServiceTests`, `ProgressionEngineBehaviorTests`, `WeeklyVowGeneratorTests`, `WeeklyVowsServiceTests`, `OverallRankTrialServiceTests`, `ProgramAwareLoggingTests`, `TrainingCompletionIntegrationGuardrailTests`, and `DailyWorkoutResolverTests`.
- Integrated result bundle: `/Users/jlin/Library/Developer/XcodeBuildMCP/workspaces/toji-aa3a04fb00a4/result-bundles/test_sim_2026-05-23T04-55-56-360Z_pid85954_f3cddb3b.xcresult`

## Phase 9 — Data Migration + Dead-Code Cleanup

**Goal:** Remove replaced paths only after each replacement is proven.

Implementation work:
- Backfill or adapt legacy `WorkoutLog` / `SessionLog` into movement IDs where possible.
- Preserve legacy compatibility until services no longer need it.
- Remove old direct save paths after their UI routes use `TrainingCompletionService`.
- Retire duplicate catalog APIs after callers use `MovementCatalog`.
- Delete dead UI components only when no route references them.

Per-phase cleanup rule:
- Delete code replaced by that phase.
- Document unrelated old code instead of silently removing it.
- Never break existing user logs just to make the model prettier.

Tests:
- Old logs still render in history.
- New logs use `PerformanceLog` path.
- Existing progression history is not wiped or re-counted.
- Migration helpers are idempotent.

Exit criteria:
- No hidden old pipeline can award XP/AP differently from the new pipeline.

Current status: **Partial, with migrated-route guardrails in place.** Phase 9 audit/update landed 2026-05-23. Migrated routes and compatibility history writes no longer fall back to legacy `WorkoutLogServiceProtocol.saveLog(_)`; old direct cascades remain only for true legacy callers.

Audit table:

| Hit area | Classification | 2026-05-23 result |
| --- | --- | --- |
| `TrainingCompletionService.complete`, `previewProgression`, `recordProgressionForLegacyWorkout` | canonical unified route | `recordProgressionForLegacyWorkout` can now attach a compatible `WorkoutLog` through the quarantined writer and stores `workoutLogId` on the completion receipt. If no compatibility writer exists, `TrainingCompletionService` writes the history row directly through the database instead of calling legacy `saveLog`. |
| `WorkoutLoggingViewModel.saveLog` | legacy Program receipt-preview route | Preview remains side-effect-free; flush no longer calls `services.workoutLog.saveLog(log)`. |
| `WorkoutLoggingViewModel.flushPendingCompletionEffects` | old direct side-effect path | Redirected to `TrainingCompletionService.recordProgressionForLegacyWorkout(..., compatibleWorkoutLog:)` so AP, LV XP, body-map, attribute, rank/trial, and reward writes stay in the unified service. |
| `WorkoutLogService.saveLog`, `SupabaseWorkoutLogService.saveLog` | legacy direct cascade that must remain temporarily | Quarantined with `MIGRATION(Phase 9)` comments; not used by the legacy Program flush after this update. |
| `WorkoutLogCompatibilityHistoryWriting` and `saveCompatibleHistoryLog(_:)` | compatibility history write | Added as side-effect-free `WorkoutLog` persistence for old readers/history while replacement routes finish proving out. |
| `TrainingSessionAdapters.workoutLog/sessionLogs`, `RewardComputer`, skill RPE/AI history queries, scan/coach/PT context, rank decay, trials history providers | compatibility/read-only history/rendering | No deletion; these remain read/adapt paths and should not award progression directly. |
| `MockWorkoutLogService`, `ProgramAwareLoggingTests`, `TrainingSessionDraftStoreTests`, `MovementProgressServiceTests`, `TrainingSessionAdapterTests` | test/mock only | Mock now separates direct-save calls from compatibility-history calls; guardrail tests assert legacy flush/history does not invoke the direct cascade. |

Deletion/quarantine result:
- Redirected one old side-effect path: legacy Program logger flush now writes compatible history through `saveCompatibleHistoryLog(_:)` and awards only through `TrainingCompletionService`.
- Removed the last migrated-route fallback to `WorkoutLogServiceProtocol.saveLog(_)`; compatible history is now writer-backed or direct database-backed only.
- Quarantined remaining direct `WorkoutLogService.saveLog` cascades with explicit `MIGRATION(Phase 9)` markers instead of deleting them while other old callers may still exist.

## Phase 10 — UX Redesign After The Spine Is Stable

**Goal:** Redesign the visible workout/progression surfaces once the flow is no longer changing underneath.

Screens to redesign:
- Workout Ready
- Active logger
- Skill session logger
- Reward sequence / receipt
- Profile progression section
- Movement library discovery
- Trial readiness card
- Trial runner

Rules:
- Do not redesign before the route's functionality is proven.
- Preserve the same data contract.
- Use screenshots/video as acceptance evidence.

Exit criteria:
- The user can follow the product without asking what AP, PRs, badges, ranks, Weekly Vows, or trial readiness mean.

Current status: **Deferred intentionally.**

## Immediate Next Sprint

This is the highest-return order from the current code state:

1. **Prove/fix Program Workout Ready path**
   - Program tab -> Workout Ready -> ActiveWorkoutContainerView -> Complete -> reward -> dismiss.
   - Screenshot/video proof.
   - Code path patched so successful active completion can dismiss Workout Ready through an explicit `onFinished` callback.
   - Done for the strength/reps route on 2026-05-21.

2. **Prove/fix Skill Session path**
   - Skill Detail -> Start Session -> log attempt/set -> Finish -> reward -> dismiss.
   - Confirm skill XP + progression receipt.
   - Save/finish guards and retryable error handling are implemented.
   - Skill Detail session save path is simulator-proven.
   - Quick Log shaped completion path is unit-proven through `TrainingCompletionService`.
   - Quick Log UI reward proof is simulator-proven after replacing the nested reward sheet.
   - Structured skill-session reward proof is simulator-proven after replacing the nested reward sheet with inline reward content.

3. **Normalize receipt content**
   - One receipt builder for workout sequence.
   - PRs and badges are the reward callout labels; Feats is not a major system label.
   - Active workout uses the full workout reward sequence now.
   - Overall LV progress bars now receive exact before/after fractions from the completion receipt.
   - Quick Log and structured Skill Session now use the full workout reward sequence instead of the smaller reward sheet.
   - Cardio and routine use the same shell through `PerformanceLog` + `TrainingCompletionService` receipts.
   - Legacy `WorkoutLoggingViewModel.makeRewardSequenceSummary()` has been removed; the old route now adapts through the shared receipt builder.

4. **Close block logger gaps**
   - Holds, cardio, carries, routines must not be forced through rep-only rows.
   - Carry custom path is now proven through `LOAD` + `DIST` and a unified receipt.
   - Cardio quick log is now simulator-proven through the unified reward sequence.
   - Routine player now records exact performance entries and is simulator-proven through the unified reward sequence.
   - Mixed Program Ready session with strength + scheduled skill + carry is now simulator-proven through one unified receipt.

5. **Finish Workout Ready edit/save depth**
   - Prove reorder/remove/add/edit/save-recent-draft from Workout Ready.
   - Confirm removing today's scheduled skill block does not delete the global active skill goal.
   - Fix the Program `BEGIN SESSION` CTA overlap before broader UI polish.
   - Done on 2026-05-22 for the V1 surface, including manual Skill Detail Add-to-Program proof.

6. **Finish MovementCatalog caller migration**
   - Ranking metadata, logger modes, roll-ups, attribute/body metadata.
   - Current validation tests pass; Agent A moved program, adapter, logger-default, settings/preferences, library, swap, and detail callers. Next work is replacing remaining rank/progression fallback, Weekly Vow prescription selection, and trial-readiness callers while documenting compatibility shims left behind.

7. **Polish Weekly Vow bonus layer**
   - The chosen Vow now becomes a `TrainingSessionDraft` and completes through `PerformanceLog` -> `TrainingCompletionService` -> `WorkoutRewardSequenceView`.
   - Next work is awarding Vow-specific bonus/cosmetic/share-card progress only after the actual work receipt is saved.

8. **Expand Overall Rank trials beyond The Calibration**
   - Add the remaining named rank-transition trials, path/equipment variants, richer readiness guidance, and comeback/badge callouts.

9. **Curated staging + legacy cleanup**
   - Split or stage progression-related code separately from generated assets and unrelated UI/onboarding changes.
   - Quarantine old direct-save/logging/rank paths only after their replacement route has simulator proof.

## Definition Of Done For The Migration

The migration is complete only when this demo works in the app:

1. Create or load a program.
2. Add Handstand as a skill goal.
3. Open today and see program lifts plus handstand skill block in Workout Ready.
4. Edit the draft.
5. Complete a strength block, a skill block, and a cardio/carry block.
6. See one receipt with AP, attribute XP, Overall LV XP, skill XP, rank-ups, PRs, badges, and body-map update.
7. See movement history, skill progress, attribute hex, LV, and body map all update from the same completion.
8. Meet trial requirements and unlock the next trial.
9. Attempt and pass the trial.
10. Overall rank advances only because the trial was passed.
11. Old direct save paths are gone or compatibility-only.

Until that demo passes with screenshots or video, the migration is still in progress.
