# Program/RankLibrary

The rank library (exercise ranks) surface inside the Program tab: browsable sections of ranked exercises, a unified tabbed detail screen, and the proof-history / ruler / target-body visualizations. The top-level entry screen `ProgramRankLibraryView` lives one level up in `UNBOUND/Views/Program/ProgramRankLibraryView.swift`.

## Files

| File | What it is |
|---|---|
| `ProgramRankLibraryModels.swift` | Value models: `ProgramRankLibrarySection/Row/Source/Filter`. |
| `ProgramRankLibraryBrowse.swift` | Browse mode: tier ledger, trophy shelf, category progress tiles, and the per-category drill-in list (`RankLibraryCategoryDetailView`). |
| `ProgramRankAttemptRevealOverlay.swift` | Attempt-reveal overlay: `ProgramRankAttemptReveal` + the full-screen rank-result reveal. |
| `ProgramRankProofHistoryLineGraph.swift` | Proof history line graph (+ `ProgramRankRepGraphRange` / `ProgramRankProofGraphPoint` models). |
| `ProgramRankMetricRuler.swift` | Metric ruler (`RulerPicker` wrapper) + `ProgramRankWeightRulerConfig`. |
| `ProgramRankExerciseHistoryEntry.swift` | Proof-history data: `ProgramRankExerciseLogMode`, history entries from `PerformanceLog`s, `ProgramRankExerciseFormatter`. |
| `ProgramRankTargetBodyFigure.swift` | Target-muscle body figure: SVG region parser/mapper, region specs, `ProgramRankTargetBodyFigure` + region strip. |
| `Detail/` | The unified, tabbed `RankDetailView` — one detail screen for both exercises and skills — plus its view model. See `Detail/README.md`. |

## Where to find X

- **List rows / sections / filters of the library** → `ProgramRankLibraryModels.swift` (data) + `Components/Unbound/RankRow.swift` (row UI).
- **Unified detail screen (exercises + skills)** → `Detail/` (`RankDetailView` + `RankDetailViewModel`).
- **Rep/weight history graph** → `ProgramRankProofHistoryLineGraph.swift` (data: `ProgramRankExerciseHistoryEntry.swift`); **ruler picker** → `ProgramRankMetricRuler.swift`.
- **Muscle-highlight body diagram** → `ProgramRankTargetBodyFigure.swift` (uses `Utilities/SVGPathParser.swift`).
