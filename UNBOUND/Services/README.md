# Services

Service layer for UNBOUND. Each subdirectory is one service domain; `ServiceContainer.swift` at this root is the `@MainActor` DI container that holds the protocol-typed instances (`auth`, `database`, `analytics`, `subscription`, `user`, `storage`, `logging`, ...) injected into the view layer.

## Subdirectories

- **Analytics/** — PostHog-backed event tracking: `AnalyticsService` behind `AnalyticsServiceProtocol`, with the typed event catalog in `AnalyticsEvent`.
- **Attributes/** — user attribute profile system: catalog, ingest, drift projection, and persistence; `AttributeService.snapshot(userId:asOf:)` is the pure read surface every consumer uses.
- **Auth/** — Supabase-backed Sign in with Apple (`AuthService`), plus the one-time legacy local-UUID → Supabase account migration (`LocalToSupabaseMigration`).
- **Badges/** — badge catalog evaluation and unlock state (`BadgeService`); evaluating a trigger returns only NEW unlocks.
- **BodyAnalysis/** — `LocalBodyInsightsService`: on-device Vision-based body-shape inference.
- **Calibration/** — persists `CalibrationBaseline` records to the database and tracks the calibration-completed flag.
- **CardioLog/** — cardio session logging and range queries (`CardioLogService`).
- **Claude/** — Anthropic Messages API client (text + vision, forced tool use for structured JSON), proxied through the `anthropic_proxy` Edge Function; `JSONValue` helper.
- **Coach/** — AI-coach action layer: `CoachActionExecutor` applies actions with undo stack/history, `PTContextBuilder` assembles user context for the coach, plus `PlateauFixService` and `TravelPlanService`.
- **Cosmetics/** — `SkinService`: skill-tree skin unlock state and active-skin selection (UserDefaults-persisted).
- **Database/** — local-first file-backed JSON document store (an actor) replacing Firestore; `Documents/Database/<collection>/<documentId>.json` with in-memory query filtering.
- **Entitlement/** — `EntitlementService` is the single source of truth for app unlock: real subscription OR DEBUG-only dev override (`DevFlags`). Views gate on this, never on `SubscriptionService` directly.
- **ExercisePreference/** — per-user exercise preferences and custom exercises, persisted through `SyncedDatabase`.
- **Health/** — HealthKit integration: `HealthRecoverySnapshot` (steps, walking/running distance, sleep) via `HealthKitService`.
- **ImageCapture/** — AVFoundation camera session for scan photo capture (`ImageCaptureService`).
- **Logging/** — `os.Logger`-backed logging facade (`LoggingService`), the Crashlytics replacement; swap only this when a real crash reporter returns.
- **Notifications/** — local-notification stack: `NotificationCoordinator` owns scheduling, with preferences store, schedule descriptors/schedulers, content catalog, milestone notifier — and `NotificationService`, the compatibility facade older call sites still use.
- **Onboarding/** — `PendingOnboardingProfile`: stashes pre-auth onboarding answers in UserDefaults so they replay onto the real account the instant the user authenticates.
- **Photo/** — local-only profile photo store: one downscaled JPEG per userId, `revision` counter for live SwiftUI refresh.
- **Program/** — `ProgramStore` is the single on-device owner of the active `TrainingProgram` (local-first; cloud push via the sync outbox), plus schedule/arc/wave-adjustment/training-context stores.
- **ProgramGeneration/** — `DeterministicProgramGenerator`: pure-function program generation from a `ProgramGeneratorInput` bundle (no IO); plus `DailyWorkoutResolver`, arc generation, block rollover, refresh rules.
- **Progression/** — deterministic RPE-based progression engine (Hawks' rules; block-driven target RPE, plate-policy weight jumps), auto-deload, plateau detection, movement AP/progress, overall level, stamina.
- **Ranking/** — `RankService` owns per-lift `RankTier` state (bodyweight-ratio, rep, and hold-seconds anchors), `TierCriterionEvaluator`, overall rank trials, session XP, rank decay, streak policy, proof engine.
- **Rewards/** — `RewardComputer` diffs user state across a training event into a `RewardSummary` (PR / rank-up / etc.) so reward semantics stay consistent across callers; currency wallet + payload builder.
- **Routine/** — `RoutineHistoryStore`: local-first routine completion records with the legacy 24h cooldown preserved byte-for-byte.
- **SavedWorkouts/** — local JSON persistence for user-owned Saved Workouts (`SavedWorkoutStore`), A/B rotation guard, and scheduler.
- **Scan/** — scan checkpoint flow: `ScanCheckpointService` reads BuildIdentity from the attribute system (never grades the photo), persists photo + checkpoint, narrative/comparison/nutrition-target services.
- **SkillProgress/** — `SkillProgressService` computes skill-tree node states (locked → proven) from workout logs + manual overrides; AI session generator, RPE sessions, skill-block routing/tagging.
- **Squads/** — squads domain: `SquadBackend` wraps the Supabase client for all squad-table operations, plus activity feed, missions, messages, presence, honors, loop reconciliation, and friend challenges (with mocks).
- **Storage/** — FileManager-backed local scan-photo storage (Firebase Storage replacement); photos stay on-device under `Documents/ScanPhotos/<userId>/<scanId>/`.
- **Subscription/** — RevenueCat-backed subscription status (`SubscriptionService`) and `SubscriptionGate`.
- **Supabase/** — the module-level Supabase client singleton (`UnboundSupabase`) and `SupabaseDatabase` wrapper; every table query in the app goes through this single instance.
- **Sync/** — outbox-based sync: `SyncEngine` drains `OutboxStore` to the remote (single-flight, trigger-driven, no polling), `SyncedDatabase`, `DocumentMerger`, `SyncTriggers`.
- **TrainingCompletion/** — `TrainingCompletionService`: the canonical post-workout completion cascade — records squad-mission + friend-challenge progress exactly once per performance log; `TrainingCompletionModels` defines `TrainingCompletionResult` (XP, rank-ups, attribute rewards, arcs earned, ...).
- **Trials/** — Weekly Vows (files keep the legacy "Trials" naming): `WeeklyVowGenerator` deterministically builds the 3 weekly vow cards, with proof, rewards, training builder, notifications, and the title catalog/threshold evaluator.
- **User/** — user profile CRUD (`UserService` over the local database) plus `SupabaseUserService`.
- **Vitality/** — `VitalityRewardPolicy`: XP awards for vitality check-in signals (daily signal cap, weekly consistency bonus).
- **WorkingWeight/** — per-exercise working-weight persistence (`WorkingWeightService`).
- **WorkoutLog/** — workout/performance log persistence (`WorkoutLogService`, `SupabaseWorkoutLogService`), session/workout draft stores, rest notifier/prescription, set prefill.

## Where to find X

- **Program generation** → `ProgramGeneration/DeterministicProgramGenerator.swift` (pure generator); the active program lives in `Program/ProgramStore.swift`.
- **Squads backend** → `Squads/SquadBackend.swift` (Supabase table ops); activity/missions/challenges are sibling files in `Squads/`.
- **Rank computation** → `Ranking/RankService.swift` (per-lift RankTier) and `Ranking/TierCriterionEvaluator.swift`; RPE progression is `Progression/ProgressionEngine.swift`.
- **Sync** → `Sync/SyncEngine.swift` (outbox drain) + `Sync/OutboxStore.swift`; local store is `Database/DatabaseService.swift`, synced facade is `Sync/SyncedDatabase.swift`.
- **Supabase client** → `Supabase/SupabaseClient.swift` (the one shared instance; never instantiate another).
- **Entitlements / paywall** → `Entitlement/EntitlementService.swift` (gate on this), `Subscription/SubscriptionService.swift` (RevenueCat).
- **Training completion** → `TrainingCompletion/TrainingCompletionService.swift` — the once-per-log cascade into squad missions + friend challenges.
- **Notifications** → `Notifications/NotificationCoordinator.swift` (real scheduling); `Notifications/NotificationService.swift` is the legacy facade.
