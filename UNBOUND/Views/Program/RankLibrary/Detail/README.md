# Program/RankLibrary/Detail

The unified, tabbed rank-detail screen used for BOTH ranked exercises and skills.
One container (`RankDetailView`) backed by one view model (`RankDetailViewModel`),
with four panes (Overview / Rank / Stats / History).
This replaces the two divergent legacy detail screens (`ProgramRankExerciseDetailView` for exercises and `Home/SkillDetail/SkillDetailView` for skills), which have been removed.

## Files

| File | What it is |
|---|---|
| `RankDetailTab.swift` | `RankDetailTab` (the four tab cases) plus the shared display models `RankLadderRow` and `RankStatItem` the tabs render. |
| `RankDetailViewModel.swift` | `RankDetailViewModel` — the single `@Observable` model: resolves a `ProgramRankLibraryRow` (or `SkillNode`) into identity + per-tab derived data (`ladderRows`, `nextGateText`, `statItems`, `formCues`), and loads progress/history/profile. |
| `RankDetailView.swift` | `RankDetailView` — the container: custom top bar, tier-tinted hero, `UnderlineTabBar`, and the four tab panes. |
| `RankDetailOverviewTab.swift` | Overview tab: "about this movement" reference only — target-body figure, equipment list, and the technique/form guide. No logging or rank glance (those live in the Rank tab). |
| `RankDetailRankTab.swift` | Rank tab (the centerpiece): compact current-rank + next-gate header, the all-ranks CLIMB visual (vertical ladder with a connecting progress spine), the "Log a Set" action (ruler for exercises / session sheet for pure skills), and the inline rank-up reveal (ignited rung + banner). |
| `RankDetailStatsTab.swift` | Stats tab: the user's numbers — PRs, total AP, last logged — filtered to movement-relevant fields only; shows a structured first-time state (placeholder "—" tiles + prompt) before the first log. |
| `RankDetailHistoryTab.swift` | History tab: trend chart (`ProgramRankProofHistoryLineGraph`) with range selector above a chronological attempt log. |

## Where to find X

- **The tab contract other tabs depend on** → `RankDetailViewModel.swift` (public properties + `load(services:)`).
- **The 9-tier ladder rows** → `RankDetailViewModel.ladderRows` (built from skill `tierCriteria` or the strength-ratio ladder).
- **Tab order / titles** → `RankDetailTab.swift`.
- **Custom top bar, hero, tab switch** → `RankDetailView.swift`.
