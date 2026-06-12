# UNBOUND — Architecture & Navigation

Entry point for finding your way around the iOS app. This is the **agent-navigation**
map: the layers, who owns what, and the exact files a real flow touches. For the
deep product-system map (rank/level/attribute/recovery semantics), see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). For per-directory detail, read the
`README.md` inside the directory you land in — almost every `Models/`, `Services/`,
and `Views/` subfolder has one.

---

## 60-second mental model

The app is a single SwiftUI target (`xcodegen`-generated project, no SPM modules of
our own). Code is grouped by layer, then by domain inside each layer:

| Layer | Path | Owns |
|---|---|---|
| **App entry** | `UNBOUND/App/` | `@main` app, scene wiring, root router, demo harnesses |
| **Views** | `UNBOUND/Views/` | SwiftUI screens & components, grouped by feature (one README per subfolder) |
| **ViewModels** | `UNBOUND/ViewModels/` | `@MainActor` per-screen state: data loading, persistence calls, screen logic |
| **Models** | `UNBOUND/Models/` | Pure data types & domain logic, grouped by domain (Sessions, Rewards, Skills, Squads, …) |
| **Services** | `UNBOUND/Services/` | One rule-family per folder: generation, ranking, sync, squads, completion cascade, … |
| **Utilities** | `UNBOUND/Utilities/` | Design tokens (`Color.unbound`, `Font.unbound`), L10n catalog, haptics, constants |

**Dependency hub:** `Services/ServiceContainer.swift` is the single
`@MainActor ObservableObject` that constructs every service at launch (each service is a
`.shared` singleton behind a protocol). `UnboundApp` builds one `ServiceContainer` as a
`@StateObject` and injects it via `.environmentObject(services)`. Views/ViewModels reach
services through `@EnvironmentObject var services: ServiceContainer`. A second init plus a
`static var mock` swaps in `Mock*` services for tests/previews.

**App startup** (`App/UnboundApp.swift` → `App/RootView.swift`): `RootView` gates into
loading → onboarding → auth → `HomeTabView()` (wrapped in `.subscriptionGate()`). On
sign-in it replays any stashed onboarding answers (`PendingOnboardingProfile`), restores
the program from the cloud if there's no local cache, runs the one-time skill-tier
migration, and rolls the weekly Vow. In `DEBUG`, `RootView` also routes launch-arg demo
harnesses (e.g. `-rewardDemo`, `-activeWorkoutDemo`) before `mainContent`.

**How a workout flows through the layers:** a Program screen presents
`ActiveWorkoutContainerView` (View) → the user logs sets into an `ActiveWorkoutSession`
(Model) → on completion the view assembles a `PerformanceLog` and calls
`TrainingCompletionService.complete(...)` (Service), the **single completion ingest
path** that fans out to XP/streak (`SessionXPService`), attributes (`AttributeService`),
rank (`RankService`), squad/challenge progress, and persists the `WorkoutLog` → the view
builds a `WorkoutRewardSequenceSummary` (Model) and presents
`WorkoutRewardSequenceView` (View) for the cinematic payout.

---

## Key flows (exact files, verified)

### 1. Log a set in an active workout
1. `Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` — owns the `ActiveWorkoutSession`, autosaves drafts, hosts the grid + keypad chrome
2. `Views/Program/ActiveWorkout/WorkoutLogGridView.swift` → `ExerciseLogCard.swift` → `SetLogGridRow.swift` — the per-exercise grid and suggested-vs-logged set rows
3. `Views/Program/ActiveWorkout/ActiveWorkoutContainerView+Keypad.swift` — bottom keypad that writes weight/reps into the active set
4. `Views/Program/ActiveWorkout/RPEPickerSheet.swift` / `RestTimerPill.swift` — per-set RPE pick and rest timer
5. `Models/Sessions/` — `ActiveWorkoutSession`, `SetLog`, `PerformanceLog` value types the grid mutates

### 2. Post-workout completion + reward sequence
1. `Views/Program/ActiveWorkout/ActiveWorkoutContainerView.swift` `complete()` — assembles `PerformanceLog`, on entry broadcasts squad presence (`markInWorkout`), clears it on finish
2. `Services/TrainingCompletion/TrainingCompletionService.swift` `complete(...)` — the one ingest cascade: persists `WorkoutLog`, records session XP/streak, ingests attributes, evaluates rank, records squad-mission + friend-challenge progress (idempotent via persisted records + in-process log-id guard)
3. `Services/Trials/` (`recordCompletedVowWork`) + `Services/Ranking/OverallRankTrialRunner.swift` — weekly-Vow receipt and rank-trial attempt recording, layered on top of the completion result
4. `Models/Rewards/WorkoutRewardSequence.swift` — `WorkoutRewardSequenceSummary` built by `makeRewardSequenceSummary(...)`
5. `Views/Components/Unbound/WorkoutReward/WorkoutRewardSequenceView.swift` (+ `+BeatPages` / `+Readouts` extensions) — the skippable beat-by-beat XP / rank / attribute / badge / cosmetic reveal

### 3. Deterministic program generation
1. `Services/ProgramGeneration/ProgramGenerationService.swift` — assembles `ProgramGeneratorInput` from live services (scan-triggered or onboarding-triggered)
2. `Services/ProgramGeneration/DeterministicProgramGenerator.swift` (+ `+Schedule`, `+MovementSelection`, `+Prescription`, `+Progression`, `+WorkoutBuilder`, `+SessionDetails`, `+Metadata`) — pure `input → TrainingProgram`, no AI/network
3. `Services/ProgramGeneration/SplitLookup.swift` + `ProgramScheduler.swift` — `(buildIdentity, frequency) → Split` and routing focuses onto weekday categories
4. `Services/ProgramGeneration/MacroCalculator.swift` / `NutritionTargetCalculator.swift` — nutrition + hydration defaults stamped into the plan
5. `Services/ProgramGeneration/SupabaseProgramService.swift` — persists the program and patches `current_program_id`
6. `Models/Program/` — `TrainingProgram`, `ProgramDay`, `Workout`, configuration enums

(For block rollover / Arc chaining: `ArcGenerator.swift`, `BlockRolloverService.swift`, `RolloverCoordinator.swift`.)

### 4. Rank / tier computation for a movement or skill
1. `Services/Ranking/RankServiceProtocol.swift` — `computeTier`, `evaluateTierCrossings`, `computeLiftRank`, `evaluate(log:)`, aggregate rank
2. `Services/Ranking/TierCriterionEvaluator.swift` — pure single-criterion evaluator (reps / seconds / kg / %BW); the one source of criterion semantics
3. `Models/Standards/SkillStandards.swift` — single source mapping a bodyweight movement to its skill-graph `tierCriteria` (so the rank and the "% to next" bar agree)
4. `Models/Standards/StrengthStandards.swift` — bodyweight-relative ratio tables for loaded movements
5. `Models/Standards/MovementResolution.swift` + `Models/Standards/UnrankedMovements.swift` — name normalization, regression-variant terms, explicit unranked set
6. `Services/Ranking/UserSkillTierStore.swift` / `LiftTierService.swift` — persisted earned tiers per skill / per lift

### 5. Squad activity + presence
1. `Views/Squads/SquadDetailView.swift` (+ `+Sections` / `+Actions` / `+Components`) — squad screen reading roster, missions, activity, presence
2. `Services/Squads/SquadService.swift` — core create/join/leave; wires `SquadStore` + `SquadBackend` + `SquadLoopReconciler`
3. `Services/Squads/SquadPresenceService.swift` — reads/writes the `squad_presence` Supabase table; written from `ActiveWorkoutContainerView` (`markInWorkout` on open, `clearPresence` on finish)
4. `Services/Squads/SquadActivityService.swift` (+ `SquadActivityBackend.swift`) — records/fetches activity rows; listens on `NotificationCenter` for upstream events
5. `Services/Squads/SquadMissionService.swift` + `Services/Squads/FriendChallengeService.swift` — weekly co-op mission and 1v1 Heaviest-Lift challenge progress (fed by `TrainingCompletionService.recordSquadProgress`)
6. `Models/Squads/` — `Squad`, `SquadMember`, `SquadState`, `SquadMission`, leaderboard, activity, presence

(Squad tables live in **Supabase**, isolated behind `*Backend` protocols, not the local `DatabaseService`.)

### 6. Onboarding → paywall
1. `App/RootView.swift` — routes to `OnboardingContainerView` while `onboardingCompleted` is false
2. `Views/Onboarding/OnboardingContainerView.swift` — initializes `OnboardingFlowViewModel`, dispatches each step
3. `ViewModels/Onboarding/OnboardingFlowViewModel.swift` (+ `+Navigation`, `+Persistence`) and `ViewModels/Onboarding/OnboardingStep.swift` — the 30-step answer model, `flowOrder`, per-step validation, and `finish()`
4. `Views/Onboarding/Steps/Step_Verdict.swift` → `Step24_26_Processing.swift` → `Step_Paywall.swift` — verdict, processing, then the in-flow paywall step
5. `Services/Paywall/PaywallService.swift` — RevenueCat paywall trigger/result; onboarding answers are stashed in `Services/Onboarding/PendingOnboardingProfile` and replayed onto the real profile in `RootView` after sign-in
6. `Services/Subscription/SubscriptionGate.swift` — `.subscriptionGate()` wraps `HomeTabView` for ongoing premium gating

---

## Multi-device sync (cross-cutting)

Local-first JSON document store (`Services/Database/DatabaseService`) with field-level
last-write-wins merge (`Services/Sync/DocumentMerger.swift`) over a Supabase outbox.
`UnboundApp` starts `SyncTriggers` on launch and flushes the `SyncEngine` on foreground.
Squad data bypasses this and talks to Supabase directly through `*Backend` protocols.

---

## Conventions

**xcodegen directory-glob project.** `project.yml` globs the whole `UNBOUND/` tree
(`sources: - path: UNBOUND`), so a new `.swift` file is picked up automatically — but the
`.pbxproj`/`.xcodeproj` are **generated, never hand-edited**. After adding, renaming, or
moving files, run `xcodegen generate`. `**/README.md` is globbed-out of the compile, so
READMEs ship as docs only.

**`Type+Concern.swift` extension-file naming.** Large types are split into a base file
plus `Base+Concern.swift` extension files on the *same* type (e.g.
`ActiveWorkoutContainerView.swift` + `…+Keypad.swift` + `…+CompletionFooter.swift`;
`DeterministicProgramGenerator.swift` + `…+Schedule.swift`). Keep `import` lines in each
extracted file.

**README-per-directory contract.** Most `Models/`, `Services/`, and `Views/`
subdirectories carry a `README.md` with a file table and a "Where to find X" table. They
are the cheap way to locate code without reading every file. **Update the README in the
same change that adds, renames, or removes a file in that directory** — a stale README is
worse than none.

**~450-line module guidance.** Files are kept single-responsibility and roughly under
~450 lines; when a file grows past that, split it (extension files for one type,
sibling files for distinct concerns) rather than letting it sprawl. A few intentional
exceptions exist where a state machine reads better whole — say so in a comment.

**DEBUG-only tooling.**
- Demo harnesses live in `App/UnboundAppDemoViews.swift` and per-feature `*DemoHarness.swift` files (e.g. `Views/Program/ActiveWorkout/ActiveWorkoutDemoHarness.swift`), routed by launch args in `App/RootView.swift` (`-rewardDemo`, `-activeWorkoutDemo`, `-sessionEditorDemo`, `-myWorkoutsDemo`, …). Use these for deterministic screenshots — never blind-tap simulator coordinates.
- `DevBuildBootstrapper` (DEBUG seed/scenario tooling) lives in `Views/Settings/` (`DevBuildBootstrapper+ProgramScenarios.swift`, `+Rewards.swift`, `+ProofState.swift`); `RootView` calls `DevBuildBootstrapper.ensureReady()` and flips `DevFlags.shared.unlockAllFeatures` only under `#if DEBUG`.

**`TierBloomToast.swift` exclusion trap.** Two files share the name:
`Views/Components/Cinematic/TierBloomToast.swift` is the **active** one;
`Views/Components/Unbound/TierBloomToast.swift` is explicitly listed under `excludes:` in
`project.yml` so it is *not* compiled. Edit the Cinematic copy. Do not remove that exclude
line, and do not assume the Unbound copy is live.

**Localization catalog rule.** Strings go through `L10n.Key` (a `String`-raw enum) in
`Utilities/Localization/L10n.swift`. A new key needs a matching entry in
`Resources/Localizable.xcstrings` or `LocalizationTests` fails. Edit the `.xcstrings`
catalog **as text** — do not round-trip it through a JSON dumper (it reformats the entire
~14k-line file).

**HotReloading guard.** The `import HotReloading` in `App/UnboundApp.swift` must stay
`#if DEBUG && targetEnvironment(simulator)`, and the SPM product must stay `weak: true` in
`project.yml`, or DEBUG device builds SIGABRT in dyld at launch.
