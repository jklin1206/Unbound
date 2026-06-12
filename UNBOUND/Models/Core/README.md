## Models/Core

Foundation-level types shared across the entire app: the user profile, error taxonomy, generic loading state, build identity, onboarding configuration, and user-health context models.

| File | Purpose |
|------|---------|
| `User.swift` | `UserProfile` — the primary user record (id, email, display name, onboarding status, program id, biometrics) |
| `AppError.swift` | `AppError` — exhaustive typed error enum covering auth, network, data, and permission failures |
| `LoadingState.swift` | `LoadingState<T>` — generic enum (idle / loading / loaded / error) used across all ViewModels |
| `BuildIdentity.swift` | `BuildIdentity` — grounded athletic descriptor auto-derived from `AttributeProfile`; the canonical identity type |
| `BuildIdentityDelta.swift` | `BuildIdentityDelta` — per-axis change between two `BuildIdentity` snapshots; UI shows only positive deltas |
| `OnboardingAnswers.swift` | Enums for all onboarding survey selections (experience level, goals, equipment, schedule, etc.) |
| `NotificationPreferences.swift` | `NotificationPreferences` — user's opt-in state for workout reminders, retention nudges, and milestone alerts |
| `Nutrition.swift` | `NutritionPlan` and `MealTemplate` — daily calorie/macro targets and meal structure |
| `NutritionContext.swift` | `NutritionContext` — derived protein target ranges and display text surfaced to coaching views |
| `Recovery.swift` | `RecoveryPlan` and `RecoveryActivity` — sleep targets, rest days, and recovery modalities |
| `Progress.swift` | `ProgressEntry` — per-scan overall score and per-muscle scores; the raw progress ledger |
| `ProgressNotifications.swift` | `Notification.Name` extensions for cross-module progress update broadcasts |
| `VitalityCheckIn.swift` | `VitalityCheckInSignal` enum — daily check-in options (rest day, easy walk, sleep, hydration, deload) |

### Where to find X

- **Read or update the user's profile** → `User.swift`
- **Handle or display an app error** → `AppError.swift`
- **Drive a loading spinner in a ViewModel** → `LoadingState.swift`
- **Show the user's athletic identity label** → `BuildIdentity.swift`
- **Check or change notification opt-ins** → `NotificationPreferences.swift`
- **Record or read a vitality check-in** → `VitalityCheckIn.swift`
- **Listen for progress update events** → `ProgressNotifications.swift`
