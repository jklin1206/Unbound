# ViewModels

Screen-level view models (mostly `@MainActor final class`, ObservableObject or `@Observable`) owning data/loading state for their screens; presentation state (sheets, animations) stays on the views. `Onboarding/` holds the onboarding flow's VM and step enum.

## Files

| File | What it is |
|---|---|
| `AuthViewModel.swift` | Auth screen state: email/password fields, sign-in/sign-up (incl. Apple), loading + error messaging. |
| `ExerciseLibraryViewModel.swift` | Exercise library browsing: sort/status filters, display rows, rank benchmark summaries. |
| `HomeViewModel.swift` | Home data state: profile + program, ranks/XP, recent training signals, bodyweight logs, travel override, scan cadence, weekly vows (moved from `../Views/Home/Dashboard/UnboundHomeView+Loading.swift`). |
| `PreviewUserService.swift` | No-op `UserServiceProtocol` for SwiftUI `#Preview` — never hits the backend. |
| `ProgramViewModel.swift` | Program tab state (`@Observable`): program + selected day, workout logs by day, wave adjustments, progression states, profile. |
| `ProgressViewModel.swift` | Progress entries + scan sessions loading. |
| `SettingsViewModel.swift` | Settings: user profile, subscription flag, delete-account confirmation state. |
| `SkillTreeViewModel.swift` | Skill-tree tab: loads the build-identity aggregate rank (per-lift sections removed in rank-cleanup-v1). |
| `Onboarding/OnboardingFlowViewModel.swift` | The live onboarding flow VM (`@Observable`) driving `OnboardingContainerView`. |
| `Onboarding/OnboardingFlowViewModel+Navigation.swift` | Extension: step navigation. |
| `Onboarding/OnboardingStep.swift` | `OnboardingStep` enum (step order, categories) for the 33-step flow. |

## Where to find X

- **Home screen data loading** → `HomeViewModel.swift`.
- **Onboarding step order / navigation / validation** → `Onboarding/OnboardingStep.swift` + `OnboardingFlowViewModel*.swift`.
- **Program day selection + logs** → `ProgramViewModel.swift`.
- **Stub services for previews** → `PreviewUserService.swift`.
