# Views/Settings

Settings screens: account, notifications, equipment, exercise preferences, cosmetics/skins, account deletion — plus the DEBUG-only dev player tools and program sandbox used to seed app states.

## Files

| File | What it is |
|---|---|
| `SettingsView.swift` | `SettingsView` root + `NotificationSettingsView`; Support FAQ links out to unboundbtr.com/faq. |
| `AccountDeletionView.swift` | Account deletion confirmation screen. |
| `EquipmentSettingsView.swift` | Declares available equipment (informational — never hides Skill Map nodes); feeds the recommender + adaptive program gen; reads/writes `UserProfile.equipment` through `UserService.updateProfile`. |
| `ProfileCosmeticsView.swift` | The Profile Kit hub: IDENTITY surface (hosts `ProfileIdentityForm`) plus border/banner equipping. |
| `SkinPickerView.swift` | Lists every `SkillTreeSkin` with lock states + live tree-map swatch; switches `SkinService`. |
| `DevPlayerToolsView.swift` | DEBUG tools screen + `DevBuildBootstrapper` (@MainActor enum) for seeding dev builds. |
| `DevBuildBootstrapper+ArcRecapDemo.swift` | Bootstrapper extension: `--unbound-arc-recap-demo` seeds a block-complete surface with a full recap story (logs, hex snapshot, level receipt). |
| `DevBuildBootstrapper+ProgramScenarios.swift` | Bootstrapper extension: program scenario seeding. |
| `DevBuildBootstrapper+ProofState.swift` | Bootstrapper extension: proof/rank state seeding. |
| `DevBuildBootstrapper+Rewards.swift` | Bootstrapper extension: rewards/cosmetics seeding. |
| `DevProgramSandboxModels.swift` | Dev sandbox enums/models (`DevProgramSandboxState`, `DevDynamicProgramScenario`, scan snapshot + card). |

## Where to find X

- **Add a settings row** → `SettingsView.swift`.
- **Equipment availability logic/persistence** → `EquipmentSettingsView.swift` (writes `UserProfile.equipment` via `UserService.updateProfile`).
- **Seed a dev state (program / proof / rewards)** → `DevBuildBootstrapper` in `DevPlayerToolsView.swift` + its `+` extensions.
- **Skin or cosmetic equipping** → `SkinPickerView.swift` / `ProfileCosmeticsView.swift`.
