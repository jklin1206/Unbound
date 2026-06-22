# SkillDetail

Hand-authored skill guide content and the lightweight explainer sheet shared with prescription rows. The full per-node detail screen is now the unified `RankDetailView` in `../Program/RankLibrary/Detail/`.

| File | Purpose |
| --- | --- |
| `SkillGuideLibrary.swift` | Root guide lookup: `guide(for: skillId)` switch returning hand-authored `SkillGuide` content. |
| `SkillGuideLibrary+PullPush.swift` | Pull/push family guide builders (pull-up variants, etc.). |
| `SkillGuideLibrary+CoreInversion.swift` | Core + inversion/handstand family guide builders. |
| `SkillGuideLibrary+Legs.swift` | Leg family guide builders (step-up, squat, glute bridge, ...). |
| `SkillGuideModels.swift` | Guide data types + small views: `SkillGuide`, assistance/tip/mistake structs, layer cue views, `SkillGuideTab`. |
| `ExerciseExplainerSheet.swift` | Lightweight `ExplainerPayload` sheet for a one-line exercise description / cues / rx note. |

Where to find X:
- Where the unified detail screen is presented from → `../SkillTree/UnboundSkillTreeTabView.swift`, `../SkillTree/ClusterStaircaseView.swift`, `../Dashboard/HomeTabView.swift`
- Unified detail screen (exercises + skills) → `../Program/RankLibrary/Detail/` (`RankDetailView` + `RankDetailViewModel`)
- Quick "I did some reps" logging → `QuickLogSheet` in `../SkillSession/SkillQuickLogSheet.swift`
- Adding/editing a skill's written guide content → `SkillGuideLibrary*.swift` (root switch in `SkillGuideLibrary.swift`)
