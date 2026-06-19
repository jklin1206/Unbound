# UNBOUND iOS — Architecture

How the app is layered, how the six core flows move through it, and the repo conventions that keep it navigable. For the product-level subsystem map (metric model, progression/ranking/logging ownership) see `docs/ARCHITECTURE.md`; for the top-level repo layout see `docs/FILE_STRUCTURE.md`.

## The 60-second mental model

All shipped app code lives under `UNBOUND/`, in five layers plus utilities:

| Layer | Path | Owns |
| --- | --- | --- |
| App entry | `UNBOUND/App/` | `UnboundApp.swift` creates the one `ServiceContainer` as a `@StateObject` and injects it via `.environmentObject`; `RootView.swift` routes auth → onboarding → `HomeTabView` (5 tabs: home / train / skills / squad / profile) and runs app-start migrations; `UnboundAppDemos.swift` is the DEBUG launch-arg demo harness. |
| Views | `UNBOUND/Views/` | SwiftUI screens grouped by feature (`Home/`, `Program/`, `Squads/`, `Onboarding/`, `Profile/`, `Settings/`, ...). Shared chrome lives in `Views/Components/`. Presentation state (sheets, animations) stays here. |
| ViewModels | `UNBOUND/ViewModels/` | Screen-level `@MainActor` data/loading state (`HomeViewModel`, `ProgramViewModel`, `ProfileViewModel`, `Onboarding/OnboardingFlowViewModel`, ...). One VM per screen, not per component. |
| Models | `UNBOUND/Models/` | Plain data types grouped by domain (`Sessions/`, `Program/`, `Skills/`, `Standards/`, `Rewards/`, ...). No services, almost no views. |
| Services | `UNBOUND/Services/` | All business logic and IO, one subdirectory per domain. `Services/ServiceContainer.swift` is the `@MainActor` dependency hub: it holds the protocol-typed instances (`auth`, `database`, `rank`, `subscription`, `entitlement`, `programGeneration`, `squadPresence`, ...) that views and view models reach through `@EnvironmentObject var services`. Most services are singletons (`X.shared`) wrapped by the container; the container also has a mock initializer for previews/tests. |
| Utilities | `UNBOUND/Utilities/` | Cross-cutting helpers: design tokens in `Extensions/` (colors/fonts/style modifiers), `Localization/L10n.swift`, haptics, constants. |

Persistence is local-first: `Services/Database/` is a file-backed JSON document store, `Services/Sync/SyncEngine.swift` drains an outbox to Supabase, and `Services/Supabase/` holds the single shared Supabase client (`UnboundSupabase`). Squad data is the exception — it lives directly in Supabase tables behind `Services/Squads/*Backend` wrappers.

**How a workout flows through the layers:** onboarding answers feed `ProgramViewModel`, which calls `ProgramGenerationService` → the pure `DeterministicProgramGenerator` → the program is saved in `ProgramStore`. On training day, `DailyWorkoutResolver` turns the program day into a draft that launches `ActiveWorkoutContainerView` (Views/Program/ActiveWorkout) directly. Set edits mutate the `ActiveWorkoutSession` model and autosave through `WorkoutDraftStore`. On COMPLETE, the container assembles a `PerformanceLog` and hands it to `TrainingCompletionService.complete(...)` — the canonical once-per-log cascade (progression, XP, attributes, proof, squad missions, friend challenges) — whose `TrainingCompletionResult` drives the full-screen `WorkoutRewardSequenceView`.

## Key flows (exact files, in order)

### 1. Log a set in an active workout

1. `UNBOUND/Views/Program/ActiveWorkout/SetLogGridRow.swift` — the set row (suggested vs logged states); tapping a cell opens the keypad.
2. `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView+Keypad.swift` — wires the session into the shared `NumberPadEditorModel` (per-cell config, live-write/commit/RPE closures).
3. `UNBOUND/Views/Components/Unbound/NumberPadEditor.swift` — the bottom keypad dock itself.
4. `UNBOUND/Models/Sessions/ActiveWorkoutSession+SetLogging.swift` — `logSet(exerciseIndex:setIndex:weightKg:reps:)` mutates the in-memory session.
5. `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` — owns the session, calls `saveDraft()` on changes.
6. `UNBOUND/Services/WorkoutLog/WorkoutDraftStore.swift` — draft autosave persistence (crash/kill recovery).

### 2. Deterministic program generation

1. `UNBOUND/ViewModels/ProgramViewModel.swift` (also `HomeViewModel.swift` for the home-triggered path) — calls `ProgramGenerationService.shared.generateFromOnboarding(...)`.
2. `UNBOUND/Services/ProgramGeneration/ProgramGenerationService.swift` — the live `ProgramGenerationServiceProtocol` impl: calibration week first, then 28-day Arcs.
3. `UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift` — pure function `ProgramGeneratorInput` → `TrainingProgram` (extensions: `+MovementSelection`, `+Prescription`, `+Schedule`, `+Progression`, `+WorkoutBuilder`, ...). No IO, no AI.
4. `UNBOUND/Services/Program/ProgramStore.swift` — the single on-device owner of the active program (local-first; cloud push via the sync outbox).
5. `UNBOUND/Services/ProgramGeneration/SupabaseProgramService.swift` — cloud persistence after every generate.
6. `UNBOUND/Services/ProgramGeneration/DailyWorkoutResolver.swift` — later resolves a program day + active modifiers into the concrete draft that launches straight into `ActiveWorkoutContainerView` (routing decided by `UNBOUND/Views/Program/Overview/ProgramWorkoutLaunchCoordinator.swift`).

### 3. Rank/tier computation for a skill

1. `UNBOUND/Models/SkillTreeContent/Tiers/*SkillTiers.swift` — per-family anchors (edit these, never hand-write tier tables).
2. `UNBOUND/Models/Skills/SkillTierGenerator.swift` — generates each node's 9-tier `tierCriteria` ladder from the anchors.
3. `UNBOUND/Models/SkillTreeContent/SkillGraph+V3*Nodes.swift` — the node definitions carrying those criteria.
4. `UNBOUND/Models/Standards/SkillStandards.swift` — the single-source bodyweight rep/hold ladders (`StrengthStandards.swift` is the barbell/accessory counterpart).
5. `UNBOUND/Services/Ranking/TierCriterionEvaluator.swift` — pure criterion semantics against log history (case-insensitive names, warmups excluded, holds read `SetLog.durationSeconds`).
6. `UNBOUND/Services/Ranking/RankService.swift` — `computeTier(skill:history:bodyweightKg:)` walks tiers highest-first; per-lift rank via `computeLiftRank`; persisted state in `UserSkillTierStore.swift`, seeded once from full history by `SkillTierMigration.swift` (called from `UNBOUND/App/RootView.swift`).
7. Read by `UNBOUND/ViewModels/SkillTreeViewModel.swift` and `UNBOUND/Views/Home/SkillTree/UnboundSkillTreeTabView.swift` (node state via `UNBOUND/Services/SkillProgress/SkillProgressService.swift`).

Note: `RankService.evaluateTierCrossings(log:userId:)` exists on the protocol but has no production trigger yet — live tier reads go through migration-seeded state + `computeTier`.

### 4. Workout completion → post-workout reward sequence

1. `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` — COMPLETE assembles the `PerformanceLog` (helpers in `UNBOUND/Models/Sessions/ActiveWorkoutSession+LogAssembly.swift`) and calls `TrainingCompletionService.shared.complete(...)`.
2. `UNBOUND/Services/TrainingCompletion/TrainingCompletionService.swift` — the canonical, idempotent (receipt-checkpointed, once-per-log-id) cascade: saves the log, `ProgressionEngine.shared.ingest`, `services.sessionXP.recordSession`, `services.attribute.ingest`, `ProofEngine.evaluate`, `services.skin.evaluateUnlocks`, squad-mission + friend-challenge progress. Result type in `TrainingCompletionModels.swift`.
3. `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView+RewardSummary.swift` — maps `TrainingCompletionResult` → `WorkoutRewardSequenceSummary`.
4. `UNBOUND/Views/Components/Unbound/WorkoutReward/WorkoutRewardSequenceView.swift` — plays the staged reward beats (`+BeatPages.swift`, `+Readouts.swift`, supporting cards/bars in sibling `WorkoutReward*` files).

### 5. Squad activity + presence

1. `UNBOUND/Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` — on workout start, `services.squadPresence.markInWorkout(userId:squadId:)`.
2. `UNBOUND/Services/Squads/SquadPresenceService.swift` — mark/refresh/read presence rows (Supabase via the squad backend).
3. `UNBOUND/Services/TrainingCompletion/TrainingCompletionService.swift` — `recordSquadProgress` advances `SquadMissionService.swift` + `FriendChallengeService.swift` exactly once per performance log.
4. `UNBOUND/Services/Squads/SquadActivityService.swift` — records feed events (NotificationCenter observers) through `SquadActivityBackend.swift` (`squad_activity` table).
5. `UNBOUND/Services/Squads/SquadService.swift` — squad state owner; hydrates `state.recentActivity` from the activity backend on load.
6. `UNBOUND/Views/Squads/SquadDetailView.swift` (+ `+Data.swift`, `+Sections.swift`) and `ActivityFeedRow.swift` — render the feed and the LIVE presence roster (`state.activeRosterPresence`, refreshed via the `.squadPresenceChanged` notification).

### 6. Onboarding → paywall

1. `UNBOUND/App/RootView.swift` — routes to onboarding while `onboardingCompleted` (AppStorage) is false.
2. `UNBOUND/Views/Onboarding/OnboardingContainerView.swift` — hosts the step views (`Views/Onboarding/Steps/`), driven by:
3. `UNBOUND/ViewModels/Onboarding/OnboardingFlowViewModel.swift` (+ `OnboardingStep.swift`) — flow state; stashes pre-auth answers via:
4. `UNBOUND/Services/Onboarding/PendingOnboardingProfile.swift` — UserDefaults stash replayed onto the real account after sign-in.
5. `UNBOUND/Views/Onboarding/Steps/Step_Paywall.swift` — the hard paywall step (no limited free tier behind it).
6. `UNBOUND/Views/Subscription/SubscriptionPackagePicker.swift` — purchase UI calling `services.subscription.purchase(packageId:)`.
7. `UNBOUND/Services/Subscription/SubscriptionService.swift` — RevenueCat-backed purchase/status; but app features gate on:
8. `UNBOUND/Services/Entitlement/EntitlementService.swift` — the single source of truth for unlock (real subscription OR DEBUG-only `DevFlags`). Views check entitlement, never `SubscriptionService` directly.

## Conventions

- **Generated Xcode project.** `UNBOUND.xcodeproj/project.pbxproj` is generated from `project.yml` and gitignored — never edit it. After adding, deleting, or moving files, run `xcodegen generate`. The directory globs in `project.yml` pick up new files automatically.
- **`project.yml` exclusion trap.** The target excludes `Views/Components/Unbound/TierBloomToast.swift` (an intentionally empty placeholder file — the real implementation is `Views/Components/Cinematic/TierBloomToast.swift`), plus `CloudFunctions/**`, `supabase/**`, and `**/README.md`. If a file mysteriously doesn't compile into the target, check the `excludes` list first.
- **`Type+Concern.swift` extension files.** Large types are split into extension files named after the concern: `ActiveWorkoutContainerView+Keypad.swift`, `DeterministicProgramGenerator+Prescription.swift`, `WorkoutRewardSequenceView+BeatPages.swift`. Find behavior by concern name, not by scrolling one giant file.
- **README-per-directory contract.** `Models/`, `Services/`, `ViewModels/`, `Utilities/`, and the feature `Views/` subdirectories each carry a `README.md` listing every file with a one-line purpose and a "Where to find X" section. Read the directory README before reading source. **Maintenance rule: when a change adds, renames, deletes, or repurposes files in a directory, update that directory's README in the same change.** A stale README is worse than none.
- **Module size guidance.** Keep modules around ~450 lines; past that, split along a `+Concern` seam (and update the README). The split exists so agents and humans can read one concern without paging a mega-file.
- **DEBUG-only tooling.** Demo/screenshot harnesses are launch-arg driven and `#if DEBUG`-gated: `App/UnboundAppDemos.swift` plus per-feature harnesses (`Views/Program/ActiveWorkout/ActiveWorkoutDemoHarness.swift`, `Views/Program/SessionEditor/SessionEditorDemoHarness.swift`, `Views/Program/MyWorkouts/MyWorkoutsDemoHarness.swift`). Dev player tooling (`DevBuildBootstrapper`, declared in `Views/Settings/DevPlayerToolsView.swift` with `DevBuildBootstrapper+*.swift` extensions alongside) lives in `Views/Settings/`; debug entitlement overrides in `Services/Entitlement/DevFlags.swift`.
- **Localization catalog rule.** Every new `L10n` key (`Utilities/Localization/L10n.swift`) needs a real entry in `UNBOUND/Resources/Localizable.xcstrings` — an inline `defaultValue` alone fails the localization tests. Edit the catalog as text (surgical insert); never round-trip it through a JSON serializer, which reformats the entire 14k-line file.
