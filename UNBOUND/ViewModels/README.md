# ViewModels

`@MainActor` view models that own data-loading, persistence, and business logic for each major screen. The `Onboarding/` subfolder holds the new 30-step flow VM and its navigation/persistence extensions.

| File | Purpose |
|------|---------|
| `AuthViewModel.swift` | `AuthViewModel` — email/password sign-in/up state; delegates to `AuthServiceProtocol` + `UserServiceProtocol` |
| `HomeViewModel.swift` | `HomeViewModel` — Home screen data: profile, program, XP/level, recent training signals, scan cadence, bodyweight logs, vows |
| `ProfileViewModel.swift` | `ProfileViewModel` — Profile screen data: identity, aggregate tier, badges, showcase picks, equipped cosmetics, photo counts, trials |
| `ProgramViewModel.swift` | `ProgramViewModel` (`@Observable`) — program, selected day, workout logs, wave adjustments, progression states |
| `CalibrationViewModel.swift` | `CalibrationViewModel` (`@Observable`) — calibration step enum, baseline inputs, preference state |
| `SettingsViewModel.swift` | `SettingsViewModel` — user profile, subscription status, account deletion confirmation flow |
| `SkillTreeViewModel.swift` | `SkillTreeViewModel` (`@Observable`) — skill-tree tab; loads build-identity aggregate rank |
| `ExerciseLibraryViewModel.swift` | Sort/filter state and ranked exercise list for the exercise library |
| `ProgressViewModel.swift` | `ProgressViewModel` — progress entries, loading state, scan sessions |
| `OnboardingViewModel.swift` | `OnboardingViewModel` — legacy 3-step auth/flow VM (kept while legacy flow gating exists) |
| `PreviewUserService.swift` | `PreviewUserService` — no-op `UserServiceProtocol` for SwiftUI `#Preview` use only (DEBUG) |
| `Onboarding/OnboardingFlowViewModel.swift` | `OnboardingFlowViewModel` (`@Observable`) — full 30-step flow: answer model, step enum, `finish()` writing to `UserService` |
| `Onboarding/OnboardingFlowViewModel+Navigation.swift` | `advance()`, `back()`, and step analytics tracking extensions |
| `Onboarding/OnboardingFlowViewModel+Persistence.swift` | `canAdvance(from:)` per-step validation and save-draft logic |
| `Onboarding/OnboardingStep.swift` | `OnboardingStep` enum with `flowOrder` array defining the 30-step sequence |

## Where to find X

| Task | File |
|------|------|
| Change Home screen data loading or refresh | `HomeViewModel.swift` |
| Modify Profile data loading or badge refresh | `ProfileViewModel.swift` |
| Add a new onboarding step to the flow | `Onboarding/OnboardingStep.swift` + `Onboarding/OnboardingFlowViewModel.swift` |
| Change onboarding step validation | `Onboarding/OnboardingFlowViewModel+Persistence.swift` |
| Modify program state or day selection | `ProgramViewModel.swift` |
| Adjust calibration step sequence | `CalibrationViewModel.swift` + `Views/Calibration/` steps |
