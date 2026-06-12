# Program/RankLibrary

Browsable rank library: sectioned list of ranked exercises/skills showing tier, metric, and history, plus a full-screen detail view with proof logging and a body-target figure.

| File | Purpose |
|------|---------|
| `ProgramRankLibraryModels.swift` | Display models: `ProgramRankLibrarySection`, `ProgramRankLibraryRow`, `ProgramRankLibrarySource` |
| `ProgramRankLibraryRowView.swift` | Single library row: tier tint, visual asset, metric, disclosure chevron |
| `ProgramRankLibraryDetailViews.swift` | `ProgramRankLibraryDetailScreen` — routes to exercise detail or skill detail based on `ProgramRankLibrarySource` |
| `ProgramRankExerciseDetailView.swift` | Full exercise detail: loads `MovementProgressState`, history, submission; owns logging flow |
| `ProgramRankExerciseDetailView+DataLogic.swift` | Data-loading and submission logic extensions for `ProgramRankExerciseDetailView` |
| `ProgramRankExerciseDetailView+HeroViews.swift` | Hero section: exercise visual, tier badge, target metrics |
| `ProgramRankExerciseDetailView+LogViews.swift` | History log section and attempt-entry input |
| `ProgramRankProofAndRulerViews.swift` | `ProgramRankAttemptRevealOverlay` — rank-up/down reveal animation after a logged attempt |
| `ProgramRankTargetBodyFigure.swift` | SVG body-map figure tinted to target `BodyRegion` set for the exercise |

## Where to find X

| Task | File |
|------|------|
| Change how a rank-library row looks | `ProgramRankLibraryRowView.swift` |
| Edit the exercise detail hero or tier badge | `ProgramRankExerciseDetailView+HeroViews.swift` |
| Modify log-submission or history loading | `ProgramRankExerciseDetailView+DataLogic.swift` |
| Adjust the rank-up reveal animation | `ProgramRankProofAndRulerViews.swift` |
| Change body regions highlighted per exercise | `ProgramRankTargetBodyFigure.swift` |
