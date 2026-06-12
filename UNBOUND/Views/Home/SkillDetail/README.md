# SkillDetail

The single-skill detail screen (`SkillDetailView` + its section extensions) presented when a node is tapped from the skill tree or home, plus the hand-authored `SkillGuideLibrary` content it renders and the small explainer sheet shared with prescription rows.

| File | Purpose |
| --- | --- |
| `SkillDetailView.swift` | Form-lead detail screen: single scroll with animated hero, title block, progress strip; sheet routing via `presentedSheet`. |
| `SkillDetailView+RankPath.swift` | Rank path section — the rung ladder with cleared/current/skipped rows and counts. |
| `SkillDetailView+RequirementsAndActions.swift` | Locked-node unlock requirement groups and the action buttons. |
| `SkillDetailView+Guide.swift` | Skill Guide section — renders the node's `SkillGuideLibrary` guide when one exists. |
| `SkillDetailView+Form.swift` | "Next beat" card and related form-progress UI. |
| `SkillDetailSheet.swift` | Sheet route enum for the detail screen: `.session` / `.quickLog` / `.trainChooser`. |
| `SkillGuideLibrary.swift` | Root guide lookup: `guide(for: skillId)` switch returning hand-authored `SkillGuide` content. |
| `SkillGuideLibrary+PullPush.swift` | Pull/push family guide builders (pull-up variants, etc.). |
| `SkillGuideLibrary+CoreInversion.swift` | Core + inversion/handstand family guide builders. |
| `SkillGuideLibrary+Legs.swift` | Leg family guide builders (step-up, squat, glute bridge, ...). |
| `SkillGuideModels.swift` | Guide data types + small views: `SkillGuide`, assistance/tip/mistake structs, layer cue views, `SkillGuideTab`. |
| `ExerciseExplainerSheet.swift` | Lightweight `ExplainerPayload` sheet for a one-line exercise description / cues / rx note. |

Where to find X:
- Where this screen is presented from → `../SkillTree/UnboundSkillTreeTabView.swift`, `../SkillTree/ClusterStaircaseView.swift`, `../Dashboard/HomeTabView.swift`
- TRAIN button → full session flow → `.session` case in `SkillDetailView.swift` opens `../SkillSession/SkillSessionView.swift`
- Quick "I did some reps" logging → `.quickLog` opens `QuickLogSheet` in `../SkillSession/SkillQuickLogSheet.swift`
- Adding/editing a skill's written guide content → `SkillGuideLibrary*.swift` (root switch in `SkillGuideLibrary.swift`)
- Rank ladder display logic → `SkillDetailView+RankPath.swift`
- Unlock requirements shown on locked nodes → `SkillDetailView+RequirementsAndActions.swift`
