# Views/Settings

Settings screens: account, notifications, equipment, exercise preferences, cosmetics/skins, account deletion — plus the DEBUG-only dev player tools and program sandbox used to seed app states.

## Files

| File | What it is |
|---|---|
| `SettingsView.swift` | `SettingsView` root + `NotificationSettingsView`. |
| `AccountDeletionView.swift` | Account deletion confirmation screen. |
| `EquipmentSettingsView.swift` | Declares available equipment (informational — never hides Skill Map nodes); feeds the recommender + adaptive program gen; persisted via `EquipmentProfileStore` (UserDefaults). |
| `ExercisePreferencesView.swift` | YES/SUB/NO exercise library picker — rows cycle unset → available → substitute → avoid, grouped by movement pattern. |
| `ProfileCosmeticsView.swift` | Equip profile cosmetics (borders/banners). |
| `SkinPickerView.swift` | Lists every `SkillTreeSkin` with lock states + live tree-map swatch; switches `SkinService`. |
| `DevPlayerToolsView.swift` | DEBUG tools screen + `DevBuildBootstrapper` (@MainActor enum) for seeding dev builds. |
| `DevBuildBootstrapper+ProgramScenarios.swift` | Bootstrapper extension: program scenario seeding. |
| `DevBuildBootstrapper+ProofState.swift` | Bootstrapper extension: proof/rank state seeding. |
| `DevBuildBootstrapper+Rewards.swift` | Bootstrapper extension: rewards/cosmetics seeding. |
| `DevProgramSandboxModels.swift` | Dev sandbox enums/models (`DevProgramSandboxState`, `DevDynamicProgramScenario`, scan snapshot + card). |

## Where to find X

- **Add a settings row** → `SettingsView.swift`.
- **Equipment availability logic/persistence** → `EquipmentSettingsView.swift` (`EquipmentProfileStore`).
- **Exercise avoid/substitute preferences** → `ExercisePreferencesView.swift`.
- **Seed a dev state (program / proof / rewards)** → `DevBuildBootstrapper` in `DevPlayerToolsView.swift` + its `+` extensions.
- **Skin or cosmetic equipping** → `SkinPickerView.swift` / `ProfileCosmeticsView.swift`.
