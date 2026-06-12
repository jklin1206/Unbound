# Services

All app service implementations live here, grouped by domain. `ServiceContainer.swift` (root) is the single `@MainActor ObservableObject` that wires every service into the app at startup.

## Subdirectories

| Directory | What lives here |
|-----------|----------------|
| Analytics | `AnalyticsEvent` enum and analytics tracking service |
| Attributes | `AttributeCatalog` — maps attribute keys to computed profile values |
| Auth | Supabase-backed Sign in with Apple authentication service |
| Badges | `BadgeServiceProtocol` and badge award logic |
| BodyAnalysis | Thin glue layer that delegates to `ScanPayoffFlavorService` for body-analysis flavor copy |
| Calibration | `CalibrationService` — baseline calibration for working-weight seeding |
| CardioLog | `CardioLogServiceProtocol` and cardio session persistence |
| Claude | Anthropic Messages API transport (text + vision, forced tool use) |
| Coach | `AppliedCoachAction` and coach action resolution |
| Cosmetics | `SkinServiceProtocol` and cosmetic unlock/equip logic |
| Database | `DatabaseService` — local-first file-backed JSON document store |
| Entitlement | `EntitlementService` + `DevFlags` — premium gating and DEBUG-only feature flags |
| ExercisePreference | `CustomExerciseStoreProtocol` and user exercise preference persistence |
| Health | `HealthRecoverySnapshot` and HealthKit recovery data integration |
| ImageCapture | Live alignment state and auto-snap trigger for body scan captures |
| Logging | `LoggingService` — local-first `os.Logger`-backed crash/event logging |
| Network | `APIEndpoint` definitions and network request helpers |
| Notifications | `NotificationCoordinator`, schedulers, milestone notifier, content catalog, preferences store, and `NotificationService` compatibility facade |
| Onboarding | `PendingOnboardingProfile` — collects onboarding answers before sign-in |
| Paywall | `PaywallService` / `PaywallServiceProtocol` — RevenueCat paywall trigger and result handling |
| Photo | Local-only profile picture store (one downscaled JPEG per user, no cloud sync) |
| Program | `ArcContext` and program state models used by the training arc |
| ProgramGeneration | Accessory bias rules, block generation logic, and AI-driven program builder |
| Progression | `AutoDeloadService` and deload planning; workout progression rules |
| Ranking | `LiftTierService` — persists and computes lift tier rankings per exercise |
| Rewards | Shop purchase result handling and reward beat orchestration |
| Routine | Local-first routine completion store with 24h cooldown (UserDefaults-backed) |
| SavedWorkouts | `ABRotationGuard` and saved-workout management |
| Scan | `CheckpointFlow` and scan checkpoint step management |
| SkillProgress | Compatibility shell for retired `AISessionGeneratorService`; skill session logic now lives in the skill tree models |
| Squads | `FriendChallengeProgressPolicy`, squad missions, and friend-challenge backend services |
| Storage | `StorageService` — local-first FileManager-backed photo storage |
| Subscription | `SubscriptionService` / `SubscriptionGate` — StoreKit subscription state and view-level premium gate |
| Supabase | Module-level Supabase client singleton (project xwoemvkzrnnsvtupxctu) |
| Sync | `DocumentMerger` — field-level merge primitive for multi-device last-write-wins sync |
| TrainingCompletion | `TrainingCompletionService` + `TrainingCompletionResult` — squad/challenge progress cascade run at end of every workout |
| Trials | `TitleCatalog` — maps `TitleID` → display name; trial unlock and capstone logic |
| User | `SupabaseUserService` — Supabase-backed `UserServiceProtocol` implementation |
| Vitality | `VitalityRewardPolicy` — vitality award computation rules |
| WorkingWeight | `WorkingWeightService` — per-exercise working-weight tracking and adjustment |
| WorkoutLog | `WorkoutLogService` — workout log persistence and history reads |

## Where to find X

| What you need | Where to look |
|---------------|---------------|
| Program generation (AI block builder, accessory bias) | `ProgramGeneration/` |
| Squads backend (missions, friend challenges, leaderboard) | `Squads/` |
| Rank computation (lift tiers, attribute ranking) | `Ranking/` |
| Multi-device sync (field-level document merge) | `Sync/` |
| Supabase client singleton | `Supabase/` |
| Entitlements / paywall trigger | `Entitlement/` + `Paywall/` |
| Training completion (squad/challenge cascade on workout end) | `TrainingCompletion/` |
| Notification scheduling and milestone alerts | `Notifications/` |
