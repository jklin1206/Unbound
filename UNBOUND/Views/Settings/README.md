# Views/Settings

Settings screen and sub-screens: account management, equipment declaration, exercise preferences, cosmetics picker, skin picker, and DEBUG-only developer tools and bootstrappers.

| File | Purpose |
|------|---------|
| `SettingsView.swift` | Root settings list: account, weight unit, microloading, analytics opt-out, link to sub-screens |
| `AccountDeletionView.swift` | Confirmation screen for permanent account deletion (requires typed confirmation) |
| `EquipmentSettingsView.swift` | Equipment-access declaration; feeds the program generator (never hides skill nodes) |
| `ExercisePreferencesView.swift` | Hawks-style YES/SUB/NO exercise library picker grouped by movement pattern |
| `ProfileCosmeticsView.swift` | Equip/preview profile borders and backdrop cosmetics from `ShopInventoryStore` |
| `SkinPickerView.swift` | Skill-tree skin picker with lock states and live tree-map swatches |
| `DevPlayerToolsView.swift` | DEBUG-only player state controls (level, rank, streak, trial target) |
| `DevProgramSandboxModels.swift` | DEBUG sandbox state enum (`DevProgramSandboxState`) and start-offset helpers |
| `DevBuildBootstrapper+ProgramScenarios.swift` | DEBUG extension: seeds a multi-day program with realistic workouts |
| `DevBuildBootstrapper+ProofState.swift` | DEBUG extension: seeds scan history for proof-state and photo calendar testing |
| `DevBuildBootstrapper+Rewards.swift` | DEBUG extension: activates dev user, seeds full profile and reward state |

## Where to find X

| Task | File |
|------|------|
| Add or change a settings row | `SettingsView.swift` |
| Modify the equipment picker | `EquipmentSettingsView.swift` |
| Change the exercise YES/SUB/NO flow | `ExercisePreferencesView.swift` |
| Edit cosmetic equip/preview logic | `ProfileCosmeticsView.swift` |
| Seed a specific dev scenario | `DevBuildBootstrapper+ProgramScenarios.swift` / `+ProofState.swift` / `+Rewards.swift` (DEBUG only) |
