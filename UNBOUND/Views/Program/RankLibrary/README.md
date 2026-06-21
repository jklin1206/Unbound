# Program/RankLibrary

The rank library (exercise ranks) surface inside the Program tab: browsable sections of ranked exercises, an expanded ladder detail screen, a per-exercise detail view with logging controls, and the proof-history / ruler / target-body visualizations. The top-level entry screen `ProgramRankLibraryView` lives one level up in `UNBOUND/Views/Program/ProgramRankLibraryView.swift`.

## Files

| File | What it is |
|---|---|
| `ProgramRankExerciseDetailView.swift` | `ProgramRankExerciseDetailView` — per-exercise rank detail screen. |
| `ProgramRankExerciseDetailView+LogControls.swift` | Extension: log/attempt input controls on the detail screen. |
| `ProgramRankExerciseDetailView+Sections.swift` | Extension: detail screen section composition. |
| `ProgramRankLibraryDetailViews.swift` | `ProgramRankLibraryDetailScreen`, expanded row, and the expanded ladder row model/status. |
| `ProgramRankLibraryModels.swift` | Value models: `ProgramRankLibrarySection/Row/Source/Filter`. |
| `ProgramRankLibraryRowView.swift` | `ProgramRankLibraryRowView` — one library list row. |
| `ProgramRankProofAndRulerViews.swift` | Attempt-reveal overlay, proof history line graph (+ range/point models), metric ruler + weight-ruler config, `ProgramRankExerciseLogMode`. |
| `ProgramRankTargetBodyFigure.swift` | Target-muscle body figure: SVG region parser/mapper, region specs, `ProgramRankTargetBodyFigure` + region strip. |

## Where to find X

- **List rows / sections / filters of the library** → `ProgramRankLibraryModels.swift` (data) + `ProgramRankLibraryRowView.swift` (row UI).
- **Expanded rank-ladder view** → `ProgramRankLibraryDetailViews.swift`.
- **Logging an attempt from the detail screen** → `ProgramRankExerciseDetailView+LogControls.swift`.
- **Rep/weight history graph or the ruler picker** → `ProgramRankProofAndRulerViews.swift`.
- **Muscle-highlight body diagram** → `ProgramRankTargetBodyFigure.swift` (uses `Utilities/SVGPathParser.swift`).
