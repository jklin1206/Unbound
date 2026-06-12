# SkillDetail

Single-node detail screen (`SkillDetailView`) and its content extensions, plus the `SkillGuideLibrary` catalogue of curated form guides and their data models.

| File | Contents |
|---|---|
| `SkillDetailView.swift` | Root detail view: animated hero silhouette crossfade, title block, XP bar, Next Beat card, form section, locked requirements, and sticky TRAIN action |
| `SkillDetailView+RankPath.swift` | `rankPathSection` — vertical rank-path ladder showing cleared / current / upcoming tiers with achievable count and cleared-count header |
| `SkillDetailView+RequirementsAndActions.swift` | `requirementsSection`, `shouldShowRequirements`, and `unlockRequirementGroups` — unlock prereq display driven by `SkillUnlockStandards` |
| `SkillDetailView+Guide.swift` | `skillGuideSection` — expandable form-guide accordion sourced from `SkillGuideLibrary` |
| `SkillDetailView+Form.swift` | `nextBeatCard` and form-cue views — "NEXT BEAT" target criterion card and top-rank badge treatment |
| `SkillDetailSheet.swift` | `SkillDetailSheet` enum (`session` / `quickLog` / `trainChooser`) used as the `Identifiable` sheet discriminator |
| `SkillGuideLibrary.swift` | `SkillGuideLibrary` enum: `guide(for skillId:)` entry point returning `SkillGuide` for pull-cluster nodes (dead-hang, scapular pull, etc.) |
| `SkillGuideLibrary+PullPush.swift` | `pullupGuide(title:grip:standardDetail:extraTip:)` factory and all pull / push node guide entries |
| `SkillGuideLibrary+CoreInversion.swift` | `handstandGuide(...)` factory and guide entries for core / inversion / handstand cluster nodes |
| `SkillGuideLibrary+Legs.swift` | `legGuide(skillId:)` dispatcher and guide entries for all leg-cluster nodes (squat path, hinge, pistol, shrimp, etc.) |
| `SkillGuideModels.swift` | Value types: `SkillGuide`, `SkillGuideAssistance`, `SkillGuideTip`, `SkillGuideMistake`, `SkillGuideLayerCue` |
| `ExerciseExplainerSheet.swift` | `ExplainerPayload` and `ExerciseExplainerSheet`: lightweight bottom sheet showing an AI-supplied one-liner, cues, and prescription notes for a named exercise |

## Where to find X

- **Full detail screen layout** → `SkillDetailView.swift`
- **Rank-path ladder** → `SkillDetailView+RankPath.swift`
- **Unlock prerequisites display** → `SkillDetailView+RequirementsAndActions.swift`
- **Form-guide accordion** → `SkillDetailView+Guide.swift` (view) + `SkillGuideLibrary*.swift` (data)
- **Guide data models** → `SkillGuideModels.swift`
- **Sheet type enum** → `SkillDetailSheet.swift`
