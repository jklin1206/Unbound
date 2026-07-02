# Models/Core

Cross-cutting user/account model types: the user profile, onboarding answers, app-wide error and loading primitives, notification preferences, and the lifestyle plans (nutrition, recovery, vitality) plus body-weight progress logs.

| File | Contents |
| --- | --- |
| `AppError.swift` | `AppError: LocalizedError` — the app-wide error enum. |
| `BuildClass.swift` | `BuildClass` — anime-RPG class epithet (Titan, Monk, Sword Saint…) derived from `BuildIdentity` shape/axes; pure naming layer, lean shapes read as "Path of the X". |
| `BuildIdentity.swift` | `BuildIdentity` — grounded athletic descriptor derived from `AttributeProfile` (canonical identity type; titles are a separate earned layer). |
| `BuildIdentityDelta.swift` | `BuildIdentityDelta` — per-axis change between two BuildIdentity snapshots; UI shows positive deltas only, regressions surface via `regressedAxes`. |
| `LoadingState.swift` | `LoadingState<T>` — idle / loading / loaded / error generic. |
| `NotificationPreferences.swift` | `NotificationPreferences` plus workout-reminder, retention-nudge, and milestone sub-preference structs. |
| `Nutrition.swift` | `NutritionPlan`, `NutritionDayTarget`, `DayNutrition`, `MealTemplate` — macro targets and meal templates. |
| `NutritionContext.swift` | `NutritionContext` — protein/hydration targets + training-fuel guidance attached to training context. |
| `OnboardingAnswers.swift` | Onboarding answer enums (`Gender`, `BodyType`, `Experience`, `Frequency`, `TargetFrequency`, `Equipment`, `ExerciseStyle`, …) — Codable, Firestore-friendly, one per onboarding screen. |
| `Progress.swift` | `ProgressEntry` and `BodyWeightLog` — body-weight / progress measurements over time. |
| `ProgressNotifications.swift` | `Notification.Name` constants for movement / overall-level / body-map progress updates. |
| `Recovery.swift` | `RecoveryPlan` + `RecoveryActivity` — sleep target, rest days, recovery activities. |
| `User.swift` | `UserProfile` (the account record) and `BiologicalSex`. |
| `VitalityCheckIn.swift` | `VitalityCheckInSignal` (rest day, sleep, hydration…) and `VitalityRewardRecord`. |

## Where to find X

- The user account record → `User.swift`; onboarding selections → `OnboardingAnswers.swift`.
- App-wide error type / generic async-load state → `AppError.swift`, `LoadingState.swift`.
- Macro / protein / hydration targets → `Nutrition.swift`, `NutritionContext.swift`.
- Push-notification settings model → `NotificationPreferences.swift`.
- Body-weight logging → `Progress.swift`.
- The derived "build" identity shown on profile → `BuildIdentity.swift` (+ `BuildIdentityDelta.swift` for scan-to-scan change).
- The class name shown above the hex (Titan, Monk, …) → `BuildClass.swift` (held-identity stability lives in `Services/Attributes/BuildClassStore.swift`).
