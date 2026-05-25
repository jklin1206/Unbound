# Program Command Center Redesign

Date: 2026-05-23

## Goal

Make the Program tab the fastest, clearest place to understand and run the user's training.

The user should open Program and immediately know:

- What am I doing today?
- Why did the system adjust it?
- What can I add, remove, or swap?
- How do I start right now?
- What happens when the current block ends or I rescan?

The Program tab should feel like an on-demand training command center, not a stack of competing cards.

## Current Status

### Implemented

- `ProgramOverviewView` has three surfaces: Program, Routines, History.
- Program loads the cached program locally first, then revalidates in the background.
- The Program tab can show:
  - resume workout banner
  - active skill goals via `todaysTrainingSection`
  - selected-day card
  - coach actions
  - program header
  - week strip
  - paywall banner
- Today's program can launch a `TrainingSessionDraft` through `DailyWorkoutResolver.programDraft`.
- Program now opens today first, with the selected-day card above secondary program sections.
- The primary Program CTA starts today's active workout directly from the resolved program draft.
- The secondary Program EDIT CTA opens `SessionEditorView`, a focused today-only editor for:
  - remove exercise
  - reorder exercise
  - swap exercise
  - add exercise from the catalog picker
  - view a staged edit summary
  - choose an explicit persistence intent; Today Only, Repeat Swap, Preference, and Next Block are executable
  - start edited session into `ActiveWorkoutContainerView`
- Session Editor repeat swaps now save `.substitute` exercise preferences, and Preference mode marks replacement exercises `.available` through `ExercisePreferenceService`.
- Session Editor has been redesigned for fewer visible commands: the plan summary is compact, persistence choices are chips, START is sticky at the bottom, exercise rows are direct tap-to-swap targets, drag handles reorder exercises, and remove lives behind a small row menu.
- Program no longer shows the skill-focus schedule card on days where no skill work is routed; active goals stop taking over the Program surface when they are not modifying today's workout.
- Program no longer exposes exercise `SWAP` in the `PLAN ADJUSTMENTS` row; plan-level chips stay focused on deload, travel, and short-session changes while exercise swaps route through EDIT.
- Binding Vow prompting now belongs on Home. Program should only surface Binding Vow work when it is attached to the selected session as a visible modifier/add-on, not as a duplicate full picker/card.
- Binding Vows are now stronger than placeholder workouts:
  - weight proofs are exercise-specific (`exerciseWeightKg`) so unrelated heavy logs cannot clear the proof
  - Low Binding and Limit Binding use multi-movement axis templates
  - Apex Binding drafts follow the rotating proof instead of collapsing into one generic circuit
  - all generated vow prescriptions resolve through `MovementCatalog`
- `DailyWorkoutResolver` already supports deterministic modifiers:
  - scheduled skill blocks
  - equipment/avoidance substitutions
  - trial-prep movement additions
  - deload volume reductions
  - skill-overlap tapering
- `WorkoutReadyView` supports block review, block reorder, block edit, adding scheduled skill work, adding mixed/custom blocks, recent drafts, and starting the workout.
- `ActiveWorkoutContainerView` owns the modern logging path:
  - autosaved draft
  - resume support
  - set grid
  - confirm-as-planned
  - add set
  - swap exercise
  - custom exercise builder
  - sticky logged/remaining work-set progress
  - current exercise/current set emphasis
  - compact non-current exercise rows until opened
  - higher-contrast dark-mode current exercise/current set color treatment
  - cursor advancement after one-tap planned-set logging
  - unified completion/reward sequence
- `ProgramExerciseLibraryView` is now the reusable Program add/swap/browse surface, with `ExerciseSwapSheet` retained as a thin compatibility wrapper. It supports swap and add modes, search text, movement-slot chips, explicit Favorites/Recent context filters, match counts, no-results states, favorite/recent badges, preference-state badges, and visible compatibility/unavailable states for avoid-list and equipment mismatches.
- `ExerciseLibrarySearch` centralizes exercise-library search/filtering over name, aliases, muscles, equipment, slot, rank, logger metadata, recency, saved preference status, context filters, and reusable compatibility state.
- Session Editor can open the existing custom exercise builder from add/swap flows and insert the saved custom exercise into the today-only draft.
- Session Editor persistence choices are executable for Today Only, Repeat Swap, Preference, and Next Block. Next Block queues substitute intent into the next generation/proposal preference path while leaving the current block intact.
- Program's selected-day card now uses `TrainingSessionAdaptationSummary` to explain scheduled skill work, travel mode, substitutions, deloads, trial prep, and skill-overlap tapering from the resolved session draft.
- Program modifier rendering now uses a reusable, tested `ProgramModifierSummary` model with deterministic priority, icon/color roles, capped visible lines, and overflow count for compact Program surfaces.
- Program surface-state resolution now uses a tested `ProgramSurfaceState` model covering no program, loading, load error/retry, block complete, rest day, training day, calibration, and missing-day cases. Initial load failures without a cache now land on a retryable Program error state instead of accidentally looking like no program exists. DEBUG simulator proof can seed saved-program states with `--unbound-proof-program-state=calibration|training-day|rest-day|missing-day|block-complete` and non-program surfaces with `--unbound-proof-program-surface=no-program|loading|load-error` before opening Program.
- Block rollover exists:
  - duration-based boundary detection: normal 28-day Arcs and first-run 7-day Calibration Week
  - block complete state
  - optional rescan
  - generate next block
  - block progress reveal
- Program generation is deterministic-first now. A user without at least two usable standards gets a 7-day Calibration Week; a standard-ready user gets the normal 28-day Arc. Claude is retained only as an emergency fallback, not the paid happy path.
- Block rollover now creates a `ProgramBlockProposal` from the latest scan delta when available, shows proposal reasons in the block-complete UI, and passes scan-derived focus plus stored `ProgressionState` into rollover generation.
- Current simulator proof: Program/Checkpoint/Saved Workout/Proof integration is green at 105 passed on iPhone 17, and the full iPhone 17 simulator suite passed 790/790. Build/run on iPhone 17 succeeded after the Program Canvas integration.
- Monthly scan direction is defined elsewhere: scan is a checkpoint and storytelling input, not the source of truth for stats.

### Not Good Enough

- Program is visually crowded. Too many cards have equal weight.
- Home and Program now have a stronger boundary: Home summarizes today's launch state; Program executes the detailed plan.
- Active goals/focus work no longer renders the full schedule card on non-routed days; remaining work is to fold routed skill work even more tightly into the Today Command modifier language.
- The normal workout start path is now direct, and the active workout now has a clearer logged/remaining footer, less duplicated exercise-menu chrome, higher-contrast current-set focus, compact non-current exercise rows, and cursor advancement after one-tap planned-set logging.
- `WorkoutReadyView` exposes too much machinery up front. It reads like a block builder, not a ready screen.
- Editing is split across multiple concepts:
  - `WorkoutDetailView` edit mode
  - `WorkoutReadyView` block editing
  - `ActiveWorkoutContainerView` swap/custom builder
- The exercise picker has search, broad add mode, custom exercise creation, favorites and recency ranking/filtering, saved preference status/filtering, repeat-swap preference execution, and explicit unavailable-state handling for avoid-list and equipment mismatches now.
- Adaptation is explained on the selected-day card, mid-block scan proposal, and block-boundary proposal now.
- Rescan behavior now has a proposal rule: mid-block scans inform the next block without silently rewriting the current plan, while block-boundary scans can feed generation immediately.
- The visual style is still not fully final, but the edit and active workout surfaces now have stronger dark-mode contrast and a clearer cyan/green training-state language.

## What Was Still Missing From The Plan

The first pass had the right direction, but it was not yet large enough to guide implementation across multiple agents. Missing pieces:

- The app needs a clear Program domain model: base program, resolved day, edited session draft, active workout, completed receipt, and next-block proposal should not blur together.
- The Program tab needs a full user-state matrix, not only the happy path.
- Home and Program need an explicit boundary so they stop competing.
- Add-ons need conflict rules. Binding Vow, skill focus, trial prep, deload, travel, and rescan focus cannot all have equal authority.
- Edits need persistence rules: one-off session edit, recurring substitution, preference update, and next-block bias are different actions.
- The exercise library needs taxonomy, search behavior, sort order, empty states, and compatibility scoring.
- Rescan has a v1 safety policy: checkpoint saved, delta explained, no current-block mutation, and next block proposal generated at boundary. Accepted current-block patches stay out of v1 until there is a real safe-suggestion engine.
- The active workout needs a reduced action model so logging is obvious under fatigue.
- Program visual style needs specific density, layout, and asset rules so it does not become another decorative dashboard.
- Testing needs simulator scripts and scenario fixtures, not just "looks good."
- Agent split needs ownership boundaries by file/service area.

This document now treats Program as a full product surface and implementation track, not a single-view restyle.

## Product Principles

1. Program is for execution.
2. Home is for status.
3. The primary action is always obvious.
4. A default program day starts in one tap.
5. Editing is one explicit secondary mode.
6. Add-ons are modifiers, not competing workouts.
7. Adaptation is suggested, not silent.
8. Search is mandatory for the exercise library.
9. Rescan creates a proposal, not a surprise rewrite.
10. The UI should have more atmosphere, but the workout itself stays dense and practical.
11. A user should never wonder whether the plan changed. Every meaningful adjustment gets a visible reason.
12. The system may suggest, but the user owns intentional changes.
13. Program design must work for tired thumbs: one primary action, plain labels, no command pileups.
14. The exercise catalog is infrastructure, not a sheet. It needs to become a reusable system surface.
15. Completion must close the loop: log -> receipt -> rank/progression -> next recommended action.

## Program Domain Model

Program should use a small set of named concepts everywhere. This prevents the UI and services from treating every screen as its own type of workout.

### Concepts

- **Base Program**: the generated multi-week plan. It owns the split, planned days, broad progression, and block identity.
- **Resolved Day**: today's base program day after deterministic rules are applied. This is what `DailyWorkoutResolver` already approximates.
- **Modifier**: a visible change source layered on top of the base day. Examples: skill focus, Binding Vow, equipment limit, deload, trial prep, rescan focus.
- **Session Draft**: the actual workout the user is about to run. It may be unchanged, modified once, or saved as a recurring preference.
- **Active Workout**: the in-progress logging state with autosave/resume.
- **Completion Receipt**: the canonical reward/progression output after finishing.
- **Block Proposal**: the next block candidate generated at a boundary or after a monthly scan.

### Ownership Rules

- Base Program is stable unless the user regenerates, rolls over, or accepts a meaningful change.
- Resolved Day can change automatically from deterministic safe modifiers, but it must explain why.
- Session Draft can be edited freely, but those edits are local until the user chooses persistence.
- Active Workout owns live logging and recovery from interruption.
- Completion Receipt owns rewards and progression deltas. Program reads its result; it does not invent rewards.
- Block Proposal is not the next program until accepted or generated through the normal rollover path.

### Persistence Choices

When the user edits a session, the app should eventually offer clear persistence choices:

- `Today only`: applies to this session draft and disappears after completion.
- `Use this swap again`: creates a recurring substitution preference for matching slots.
- `Update my preferences`: changes avoid/equipment/preference settings.
- `Bias next block`: saves a signal for the next block proposal without mutating the current block.

Phase 1 implementation can default edits to `Today only`; later phases should expose the other choices where they make sense.

## Home vs Program Boundary

Home and Program currently overlap too much. The intended split:

- **Home** shows status: streak, today's readiness, next action, progression highlights, and light reminders.
- **Program** shows execution: today's session, edit/start, week plan, add-ons, adaptations, and block rollover.
- **Profile** shows identity: rank, attributes, body map, skill/movement progress, badges.
- **Routines** are optional repeatable sessions, not the core generated plan.
- **Scan** is measurement/checkpoint input, not the daily command center.

Home may deep-link into Program's primary action, but it should not duplicate the full Program surface.

Implementation note (2026-05-24): Home now keeps only the launch/status summary for today: status, focus, day, time, plan count, and one primary action. The movement list, weekly calendar selection, editing, saved workouts, checkpoint, and Wave/adaptation controls belong to Program.

## User-State Matrix

The Program first screen needs deterministic behavior for every major state.

| State | First Screen Priority | Primary CTA | Secondary CTA | Notes |
| --- | --- | --- | --- | --- |
| No program yet | Program creation prompt | Build Program | Browse Routines | Should be sparse and decisive. |
| Program exists, workout today | Today Command | Start | Edit | Default happy path. |
| Program exists, rest day | Recovery Command | View Tomorrow | Add Light Work | Do not fake urgency. |
| Workout in progress | Resume banner | Resume | Discard/Review | Resume beats all other CTAs. |
| Today completed | Completion recap | View Reward | Preview Tomorrow | Keep progress loop visible. |
| Missed yesterday | Today Command with rollover note | Start Today | Review Week | Avoid guilt language. |
| Active skill goal | Today Command plus modifier | Start | Manage Add-ons | Skill work appears as modifier, not a second workout. |
| Binding Vow active | Today Command plus vow chip | Start | Manage Vow | Vow should append or tag, not bury base plan. |
| Travel/equipment limit | Substituted Today Command | Start | Adjust Equipment | Show what changed. |
| Deload/recovery | Reduced Today Command | Start Reduced | Use Normal Volume | Safety/recovery can be default, but visible. |
| Trial prep available | Today Command plus prep chip | Start | View Trial | Trial prep modifies plan only when useful. |
| Mid-block rescan available | Normal Program plus scan prompt | Start | Scan | Scan should not hijack workout. |
| Block complete | Rollover surface | Build Next Block | Review Recap | This can temporarily replace Today Command. |
| Paywall-limited | Best available preview | Unlock Program | Browse Free | Avoid dead ends. |
| Service/loading error | Cached Program if present | Start Cached | Retry | Local cached execution should survive network trouble. |

## Program First Screen Detail

The first screen should be vertically ordered by user intent, not by implementation history.

### 1. Resume Strip

Shown only when an active workout draft exists.

- compact, topmost
- exercise count and last updated time
- primary action: `RESUME`
- secondary action: small overflow for review/discard

### 2. Today Command

This is the centerpiece of Program.

Must include:

- day label: `Day 12`, `Upper Pull`, `Recovery`, etc.
- workout title
- estimated duration
- exercise count
- 3 to 5 key exercises or block names
- modifier chips, capped visually
- readiness/status line when relevant
- primary `START`
- secondary `EDIT`

Should avoid:

- multiple large equal CTAs
- a separate "ready" page for unchanged sessions
- long explanations inside the main command card

### 3. Week Rail

The week rail is for orientation, not a second dashboard.

States:

- completed
- today
- planned
- rest
- missed
- modified
- future preview

Tapping a future day opens preview mode. Preview mode should not imply the user can accidentally start a future workout unless that action is explicit.

### 4. Modifier Summary

Only shown when at least one modifier is active.

Contents:

- one sentence summary
- 1 to 3 modifier chips
- `Details` opens a modifier detail sheet

Examples:

- `Pull-up focus added 2 skill blocks before today's upper session.`
- `Travel mode swapped barbell work for dumbbells.`
- `Deload reduced planned volume by 25%.`

### 5. Add-ons Drawer

Collapsed by default. It should feel like "add something to today's plan," not "choose a different app mode."

Add-on types:

- Binding Vow
- skill focus
- routine finisher
- mobility/recovery block
- custom exercise/block
- trial prep

Each add-on must show:

- time cost
- training cost or recovery warning when relevant
- whether it appends, replaces, or tags the base session

### 6. Block Overview

Low-priority, below today's execution.

Shows:

- block name and week/day
- days remaining
- split summary
- recent adherence
- next block/rescan status if relevant

This is where "why this program" belongs, not inside the primary start card.

## Target Information Architecture

### Program Tab, First Screen

Order:

1. **Today Command**
   - Day label and workout name
   - estimated duration
   - key exercises, capped to a compact list
   - applied modifiers summary
   - primary CTA: `START`
   - secondary CTA: `EDIT`

2. **Week Rail**
   - seven compact day chips
   - completed/rest/today/planned states
   - tap a future day to preview

3. **Adaptation Card**
   - hidden when nothing changed
   - one sentence only when shown
   - examples:
     - `Skill focus added: Pull-up practice before upper pull.`
     - `Deload applied: volume reduced 25% today.`
     - `Travel mode: dumbbell substitutions active.`

4. **Add-ons Drawer**
   - collapsed by default
   - contains Binding Vow, skill focus, side quest/routine, custom finisher
   - these append to the plan, but never overpower today's base program

5. **Program Overview**
   - block name
   - days remaining
   - training split
   - "Why this program" as a small info action

Routines and History should remain reachable, but they should not compete with the main Program first screen.

## Target Flow

### Normal Day

```text
Program tab
  -> START
  -> ActiveWorkoutContainerView
  -> Complete
  -> Reward sequence
  -> Program/Home updated
```

No mandatory `WorkoutReadyView` stop for a normal unchanged program day.

### Edit Today's Session

```text
Program tab
  -> EDIT
  -> Session Editor
  -> add / remove / swap / reorder
  -> START
  -> ActiveWorkoutContainerView
```

The editor replaces the current "everything everywhere" role of `WorkoutReadyView`.

### Add Exercise

```text
Session Editor
  -> Add Exercise
  -> Exercise Library
  -> search / filter / select
  -> exercise inserted into session
```

### Swap Exercise

```text
Session Editor or Active Workout
  -> Swap
  -> Exercise Library opened in compatible-swap mode
  -> choose replacement
```

### Binding Vow / Focus Work

```text
Program tab
  -> Add-ons Drawer
  -> choose Vow or focus block
  -> appended to today's session draft
  -> visible as a modifier
```

Binding Vows, skill goals, travel, deload, and trial prep should all use the same modifier language.

## Detailed Flow Contracts

### Program Creation / Rebuild

This is not the main scope of the UI cleanup, but Program cannot be redesigned without honoring creation and rebuild states.

Flow:

```text
No active program
  -> Build Program
  -> inputs already known from onboarding/profile/scan where possible
  -> confirm training days/equipment/focus
  -> if standards unknown: generated Calibration Week
  -> if standards known: generated Base Program
  -> Program tab shows today's command
  -> Calibration Week completion rolls into the first real 28-day Arc
```

Rules:

- Do not ask for known profile data again.
- Let the user change equipment, training days, and focus before building.
- Show a short "why this program" explanation after generation.
- First week is not treated as the real program when standards are unknown. It is a low-risk RPE 6-7 standard-finding week that seeds progression.
- If scan data is stale, ask whether to rescan, but do not block program creation.

### Normal Start

Flow:

```text
Program
  -> START
  -> resolve Session Draft
  -> Active Workout
```

Rules:

- `START` should not open a preview if the session is unchanged.
- Any resolver failure should fall back to cached base day when safe.
- If no exercise can be resolved, show an inline error with `Edit` and `Retry`.

### Edit Start

Flow:

```text
Program
  -> EDIT
  -> Session Editor
  -> START
  -> Active Workout
```

Rules:

- Session Editor starts from the resolved day, not from a blank builder.
- Edits are local by default.
- The editor should make destructive actions reversible before leaving the screen.
- Starting from the editor uses the edited draft, not a second resolver pass that discards edits.

### Add-On Start

Flow:

```text
Program
  -> Add-ons
  -> choose add-on
  -> modifier appears on Today Command
  -> START
```

Rules:

- Add-ons show time cost before acceptance.
- If an add-on conflicts with recovery/deload, show the conflict and safer alternative.
- If an add-on would duplicate work already present, collapse it into one combined modifier.

### Active Workout Editing

Flow:

```text
Active Workout
  -> current exercise row
  -> swap / add set / skip / add exercise
  -> continue logging
```

Rules:

- Mid-workout changes affect only the active workout unless the user explicitly saves a preference.
- Completion should include what was actually logged, not what was originally planned.
- The active workout should never bounce the user back to Program to make a simple swap.

### Completion Loop

Flow:

```text
Active Workout
  -> Complete
  -> Completion Receipt
  -> Reward / rank / PR / badge callouts
  -> Program state updates
```

Rules:

- Program marks the day complete only after the canonical completion route succeeds.
- If reward calculation fails after log save, preserve the log and retry rewards.
- The post-completion Program surface should show: completed state, earned XP/rank highlights, and next planned session.

### Block Rollover

Flow:

```text
Block complete
  -> recap
  -> optional rescan
  -> next block proposal
  -> accept/build
  -> Program shows new block Day 1
```

Rules:

- Rollover can own the first screen temporarily.
- The user can continue without a rescan.
- The generated block should state what changed from the previous block.

## Session Editor Requirements

This is the likely replacement for most of `WorkoutReadyView`.

Must show:

- workout title
- total time estimate
- ordered exercise/block list
- per-row set/rep target
- remove button
- swap button
- drag/reorder or move controls
- add exercise
- add block/finisher only as secondary
- save custom only when the session has non-program modifications
- primary `START` pinned at bottom

Should hide:

- recent drafts unless user opens custom mode
- scheduled skill CTA unless a skill is available and not already attached
- block type builder until user chooses Add Block
- excessive equal-weight buttons

### Session Editor Layout

Top area:

- title, day label, duration
- modifier chips
- primary status: `Edited`, `Program`, `Recovery`, or `Travel`

Main list:

- grouped by warmup, main work, accessory, conditioning, cooldown when available
- each exercise row shows target sets/reps/time, equipment, and slot
- row actions use icons where possible: swap, remove, more
- reorder is available through drag or explicit move controls

Bottom bar:

- `START` primary
- compact draft status: `Saved for today`
- overflow for reset, save as routine, or persistence choices

### Editor Actions

- Add exercise
- Add block
- Remove exercise/block
- Swap exercise
- Reorder
- Edit target sets/reps/time
- Reset to program
- Save as routine/custom session
- Start now

### Editor Validation

The editor should prevent or warn on:

- empty workout
- no measurable logging target
- duplicate same exercise in a way that looks accidental
- add-on pushing session far beyond target duration
- exercise unavailable under current equipment settings
- deload/recovery conflict when the user adds high-intensity work

### What Happens To WorkoutReadyView

Short term:

- keep `WorkoutReadyView` for custom/routine builder paths if needed
- route normal Program `START` directly to active workout
- route Program `EDIT` to either a simplified editor or a trimmed `WorkoutReadyView`

Long term:

- retire `WorkoutReadyView` as the primary Program preview
- reuse its block editing pieces inside Session Editor
- keep one code path into `ActiveWorkoutContainerView`

## Exercise Library Requirements

The app is going to have too many exercises for simple lists.

Library modes:

- **Add mode**: any compatible movement/exercise can be inserted.
- **Swap mode**: defaults to same movement slot/pattern, but can expand.
- **Browse mode**: inspect the catalog.

Required controls:

- search bar
- filters:
  - equipment
  - movement pattern/slot
  - muscle group
  - skill/lift/category
  - bodyweight / loaded / cardio / carry / mobility
- recent exercises
- favorites or available list
- custom exercise creation
- empty-state guidance

Rows should show:

- exercise name
- primary slot/pattern
- equipment
- target muscles
- logger type
- compatibility state if unavailable

### Exercise Metadata Contract

Every searchable exercise should expose enough metadata for filtering and resolver decisions:

- stable id
- display name
- aliases
- movement pattern
- movement slot
- primary muscles
- secondary muscles
- equipment
- setup complexity
- logger type: reps, weight/reps, duration, distance, rounds, hold, carry
- progression family when applicable
- skill link when applicable
- rank standard link when applicable
- contraindication/avoidance tags
- home/gym/bodyweight availability
- substitution families

### Search Behavior

Search should match:

- name
- alias
- muscle
- equipment
- movement pattern
- skill family

Default sort:

1. exact/prefix name matches
2. compatible movement slot
3. available equipment
4. recent/favorite
5. lower setup complexity
6. broader catalog matches

### Compatibility States

The library should communicate why an exercise is or is not a good fit.

- `Best match`: same slot, equipment available, similar target.
- `Good swap`: same pattern but altered loading or difficulty.
- `Available`: can be added but changes the intent.
- `Unavailable`: missing equipment or avoided movement.
- `Custom`: user-created exercise.

Unavailable rows can be visible in browse mode, but should be hidden or deemphasized in quick swap mode.

### Custom Exercise Creation

Minimum custom creation fields:

- name
- logging type
- equipment
- movement pattern or uncategorized
- target muscles optional

The system can let a custom exercise be logged immediately, but it should not award movement rank credit until it is mapped to a known movement standard.

## Active Workout Cleanup

The active logger is the correct core direction, but it needs a simplicity pass.

Target:

- one obvious current exercise
- sets are easy to confirm as planned
- editing weight/reps is secondary but discoverable
- add set and swap are present but not visually equal to complete
- complete button stays persistent
- rest timer is useful but quiet
- overflow menu should be reduced to the actions users actually need mid-session

### Active Workout Action Hierarchy

Primary:

- confirm planned set
- edit set values
- next exercise
- complete workout

Secondary:

- add set
- swap exercise
- skip exercise
- rest timer

Overflow only:

- add custom exercise
- discard workout
- save as routine
- report issue

The active screen should not present add, swap, complete, timers, rewards, notes, and settings as equal-weight buttons.

## Adaptation Model

Program changes should be visible as a small stack of modifiers.

Modifier sources:

- base program
- scheduled skill focus
- Binding Vow
- trial prep
- travel/equipment
- deload/recovery
- avoidance/preferences
- block rollover
- rescan focus

Each modifier should produce:

- user-facing label
- short reason
- list of affected exercises or blocks
- accept/keep decision if it changes the base day

No silent rewrites.

### Modifier Priority

When modifiers conflict, priority should be deterministic:

1. safety/recovery/deload
2. user avoid list and explicit preferences
3. equipment availability
4. base program intent
5. trial prep
6. skill focus
7. Binding Vow
8. optional routine/finisher
9. rescan next-block bias

The lower-priority modifier should adapt, defer, or become a suggestion.

### Auto-Apply vs Ask

Auto-apply:

- equipment substitutions when the original is unavailable
- avoidance substitutions
- deload volume reductions
- scheduled skill work already accepted by the user
- safe trial-prep additions within session time budget

Ask first:

- changing the main movement of the day
- adding high-intensity work on deload/recovery
- turning a one-time swap into a recurring preference
- mutating the base program split
- applying mid-block rescan recommendations to current workouts

### Modifier Detail Sheet

The detail sheet should answer:

- What changed?
- Why did it change?
- What exercises or blocks were affected?
- Can I undo it today?
- Can I make this a preference?

This should be short and practical, not a coaching essay.

## Rescan Behavior

Monthly scans should not overwrite the current plan unexpectedly.

### If the user rescans mid-block

- save the scan/checkpoint
- compute the delta/focus candidate
- show a light result: `Next block can bias chest/shoulders based on this checkpoint`
- do not mutate today's workout automatically
- no accepted current-block patch in v1 unless a future safe-suggestion engine can prove the change is low-risk

### If the user rescans at block boundary

- scan feeds the next block proposal
- block complete state shows:
  - current block recap
  - scan delta teaser
  - proposed focus for next block
  - `BUILD BLOCK N`
- generated block uses:
  - current BuildIdentity
  - recent training logs
  - current equipment/preferences
  - scan focus/delta
  - stale exercise rotation
  - active goals and trial prep

### If the user skips rescan

- generate next block from training data and current profile
- keep the existing scan focus if still relevant
- never block program continuation on a scan

### Monthly Rescan Product Contract

Monthly scan is a checkpoint, not a judge. It should create better programming context without making the user feel punished or surprised.

Mid-block result:

- save new scan
- compare against prior scan and training logs
- identify possible visual/body-map focus changes
- show one simple next-block suggestion
- do not rewrite current week automatically

Future safe mid-block patch examples:

- add 5 to 8 minutes of mobility after sessions
- add one light skill primer
- swap one accessory for a similar target

Unsafe mid-block patch examples:

- replace main lift pattern
- change weekly split
- increase total volume sharply
- remove trial prep the user accepted

Block-boundary result:

- scan can be a first-class input to next block generation
- proposal explains 2 to 4 changes from previous block
- user accepts generated block or adjusts focus/equipment/days

Rescan copy should avoid body-shaming language. It should speak in training terms:

- `Chest and shoulders are ready for more direct work next block.`
- `Back volume has lagged behind pressing. Next block can pull that forward.`
- `Mobility checkpoint suggests keeping recovery work in the warmup.`

## Program Data And Service Gaps

Likely missing or incomplete implementation pieces:

- `ProgramModifierSummary` or equivalent UI-ready modifier model.
- A resolver output that includes explanations, not only adjusted exercises.
- A reusable Program exercise library surface now exists as `ProgramExerciseLibraryView`; remaining work is to add any future browse-only entry points beyond add/swap.
- A focused `SessionEditorView` backed by `TrainingSessionDraft`.
- Persistence layer for one-off edits vs recurring substitutions.
- Next-block proposal model that can hold scan deltas before acceptance.
- Program state reducer or coordinator so `ProgramOverviewView` stops owning too many unrelated concerns.
- Fixture/debug launch arguments for Program states, similar to existing routine launch helpers.

Potential service boundary:

- `DailyWorkoutResolver`: resolve base day plus deterministic modifiers.
- `ProgramModifierExplainer`: convert resolver decisions into user-facing summaries.
- `SessionDraftEditingService`: apply add/remove/swap/reorder edits to a draft.
- `ExerciseLibraryIndex`: search/filter/rank catalog entries.
- `ProgramRolloverCoordinator`: block complete, rescan optionality, next block proposal.

The first implementation should avoid inventing all services at once. Add the smallest model/service boundaries needed to reduce view clutter and make testing possible.

## Visual Direction

The Program tab should be more styled, but still usable under fatigue.

Direction:

- darker command-center base
- one strong atmospheric training background or generated texture, used subtly
- less card stacking
- stronger primary CTA
- compact modifiers
- fewer big rounded panels
- more table/list density for exercises
- color used for status and adaptation, not decoration everywhere

The art layer should support the program, not become the program.

### Visual Rules

- Program should feel more like a training cockpit than a marketing page.
- Use compact rows and dividers for workout content instead of stacking many large cards.
- Keep the primary `START` button visually dominant and thumb-reachable.
- Use accent color for state: today, modified, complete, warning, recovery.
- Avoid giant hero copy inside Program. The session is the hero.
- Background art/texture should be subtle enough that exercise names and numbers remain high contrast.
- Generated imagery, if used, should suggest training atmosphere without hiding real controls.
- Cards should be reserved for major surfaces: Today Command, modifier details, editor sheets, and repeated exercise rows.
- Do not make focus/add-on chips visually louder than the base workout.

### Density Targets

On a standard iPhone viewport, the first screen should show at minimum:

- Today Command primary title and `START`
- estimated duration and exercise count
- at least 3 planned exercise/block names
- week rail or the top of it
- visible hint that add-ons/modifiers exist if active

If the first viewport only shows a large header plus one card, the design is too airy for this surface.

### Accessibility And Interaction

- Dynamic type should not make `START` disappear below excessive decoration.
- Buttons need clear hit targets.
- Exercise rows need accessibility labels that include target sets/reps/time.
- Modifier chips need readable text, not color-only meaning.
- Active workout controls need to work one-handed.
- Reduce motion should disable nonessential animation.

## Implementation Phases

### Phase 1: Program Goal + Audit

- Capture this goal in `docs/PROGRESSION.md`.
- Keep current code behavior intact.
- Identify old surfaces to replace, not just restyle.

### Phase 2: Program First Screen

- Reorder Program tab around Today Command first.
- Move program header/week strip into a cleaner hierarchy.
- Collapse active goals into an add-on/modifier summary.
- Keep Routines and History reachable.
- Test: open Program, identify today's work, start in one tap.

### Phase 3: Fast Start Path

- Add direct start from today's Program card to `ActiveWorkoutContainerView`.
- Bypass `WorkoutReadyView` for unchanged program days.
- Preserve draft/resume and unified rewards.
- Test: Program -> Start -> log set -> complete -> reward.

### Phase 4: Session Editor

- Create a focused editor for session modifications.
- Port the useful pieces from `WorkoutReadyView`.
- Remove equal-weight clutter.
- Test: add, remove, swap, reorder, start.

### Phase 5: Exercise Library

- Build searchable library surface.
- Replace current swap-only sheet with library modes.
- Add filters and compatibility states.
- Test: search large catalog, add exercise, swap compatible exercise, create custom.

### Phase 6: Adaptation Explanations

- Introduce a `ProgramModifierSummary` model.
- Surface modifiers as one compact card.
- Ensure resolver outputs reasons for applied adjustments.
- Test: skill focus, travel/equipment, deload, trial prep, Binding Vow.

### Phase 7: Rescan + Block Rollover Contract

- Make mid-block scan behavior explicit.
- Make block-boundary scan proposal explicit.
- Ensure next block generation consumes scan delta when available.
- Test: rescan mid-block, rescan at rollover, skip rescan.

### Phase 8: Visual Style Pass

- Add a restrained generated/program background asset or texture.
- Reduce visual clutter.
- Verify mobile screenshots with simulator.

## Parallel Work Lanes

These are designed so multiple agents can work with low file interference.

### Lane A: Program Command Surface

Goal:

- Make Program first screen today-first and fast-start capable.

Likely files:

- `UNBOUND/Views/Program/ProgramOverviewView.swift`
- small extracted subviews under `UNBOUND/Views/Program/`

Responsibilities:

- Today Command
- week rail hierarchy
- resume/completed/rest states
- direct start for unchanged day
- keep edit path available

Avoid:

- building the full exercise library
- changing progression math
- touching scan services unless required for display

Simulator:

- primary iPhone 17
- verify Program -> Start -> Active Workout opens

### Lane B: Session Editor

Goal:

- Create the focused edit surface that replaces the cluttered ready flow.

Likely files:

- new `UNBOUND/Views/Program/SessionEditorView.swift`
- helper subviews under `UNBOUND/Views/Program/`
- draft editing helpers if needed

Responsibilities:

- add/remove/swap/reorder UI shell
- reset to program
- start edited draft
- local validation states

Avoid:

- rewriting `ActiveWorkoutContainerView`
- owning the global exercise library search implementation beyond integration hooks

Simulator:

- iPhone 16e or iPhone 17
- verify Program -> Edit -> reorder/remove -> Start

### Lane C: Exercise Library

Goal:

- Build reusable add/swap/browse library surface.

Likely files:

- new `UNBOUND/Views/Program/ExerciseLibraryView.swift`
- replace or wrap `UNBOUND/Views/Program/ExerciseSwapSheet.swift`
- search/filter helpers near existing movement catalog code

Responsibilities:

- search bar
- filters
- compatibility states
- add mode
- swap mode
- custom exercise entry point

Avoid:

- changing Program first-screen layout
- changing reward/progression math

Simulator:

- iPhone 17
- verify search, filter, add, swap, empty states

### Lane D: Adaptation And Rescan Contract

Goal:

- Make modifiers and monthly scan behavior explainable and testable.

Likely files:

- `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift`
- `UNBOUND/Services/ProgramGeneration/BlockRolloverService.swift`
- small modifier summary model/service
- Program display integration only where necessary

Responsibilities:

- modifier summary output
- auto-apply vs ask rules
- next-block scan input contract
- block-boundary proposal copy/data

Avoid:

- visual restyle beyond exposing summary data
- session editor controls

Simulator:

- iPhone 17
- verify modifier explanations appear for skill focus, equipment, deload, and rollover/rescan states

### Lane E: Active Workout Simplification

Goal:

- Make the in-workout controls less confusing while preserving logging power.

Likely files:

- `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift`
- `UNBOUND/Views/Program/ActiveWorkout/ExerciseLogCard.swift`
- related active workout subviews

Responsibilities:

- action hierarchy
- persistent complete button
- quieter rest timer
- lower visual weight for add/swap controls
- preserve autosave/resume

Avoid:

- changing Program tab layout
- changing exercise search internals

Simulator:

- iPhone 17
- verify start -> log/edit set -> swap -> complete -> reward

## Suggested First Implementation Order

1. Program Command Surface with direct start.
2. Modifier summary data just enough to display why today's session changed.
3. Session Editor shell using existing draft/block structures.
4. Exercise Library search/add/swap.
5. Active workout simplification.
6. Full rescan and block proposal contract.
7. Visual polish after flows are real.

The first build should not wait for the perfect library or rescan model. The biggest immediate user pain is getting into today's workout quickly and understanding what is being done today.

## Testing Matrix

Simulator coverage should include:

- Fresh program user
- Existing program with today's workout
- Rest day
- Active skill goal attached
- Binding Vow available
- Travel/equipment modifier
- Deload modifier
- Trial prep modifier
- Resume draft
- Exercise add/search/swap
- Custom exercise
- Mid-block rescan
- Block complete with rescan
- Block complete without rescan
- Program completion -> reward sequence

Primary simulator: iPhone 17.

Secondary visual pass: iPhone 16e for smaller viewport density.

## Acceptance Criteria

The redesign is not done until these are true:

- Opening Program answers "what am I doing today?" without scrolling on iPhone 17.
- A normal unchanged day starts active logging in one tap from Program.
- Editing a day has one obvious entry point and one obvious start action.
- Add exercise and swap exercise use the same searchable library system.
- Active skill focus and Binding Vow appear as modifiers, not separate competing workouts.
- Travel/equipment/deload changes show a reason.
- Mid-block rescan does not silently change the current plan.
- Block-boundary rescan can influence the next block proposal.
- Completion updates Program state and shows reward/progression through the canonical receipt path.
- The UI remains readable and uncluttered on iPhone 16e.
- Xcode simulator testing covers at least one full Program -> Active Workout -> Complete loop before merge.

## Open Questions To Decide During Implementation

- Should Program support starting a future day, or only preview it until the user explicitly chooses "Start anyway"?
- Should recurring substitutions be asked immediately after a swap or after the workout completes?
- Should Binding Vow completion be displayed inside the workout, on the reward screen, or both?
- How much of `WorkoutReadyView` should survive as a custom session builder?
- Does the exercise library need favorites in the first release, or are recents enough?
- Decision: mid-block rescan patches are not allowed in v1. All scan effects wait until next-block proposal/generation unless a future safe-suggestion engine is explicitly added.
- What debug launch arguments do we need for reliable Program state simulator proof?
