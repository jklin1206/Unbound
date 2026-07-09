# Program/RankLibrary/Detail

The unified, tabbed rank-detail screen used for BOTH ranked exercises and skills.
One container (`RankDetailView`) backed by one view model (`RankDetailViewModel`),
with three panes (Overview / Rank / Stats).
This replaces the two divergent legacy detail screens (`ProgramRankExerciseDetailView` for exercises and `Home/SkillDetail/SkillDetailView` for skills), which have been removed.

## Files

| File | What it is |
|---|---|
| `RankDetailTab.swift` | `RankDetailTab` (the three tab cases) plus the shared display models `RankLadderRow` and `RankStatItem` the tabs render. |
| `RankDetailViewModel.swift` | `RankDetailViewModel` — the single `@Observable` model: resolves a `ProgramRankLibraryRow` (or `SkillNode`) into identity + per-tab derived data (`ladderRows`, `nextGateText`, `statItems`, `formCues`), and loads progress/history/profile. |
| `RankDetailView.swift` | `RankDetailView` — the container: custom top bar, tier-tinted hero, `UnderlineTabBar`, and the three tab panes. |
| `RankDetailOverviewTab.swift` | Overview tab: "about this movement" reference only — target-body figure, equipment list, and the technique/form guide. No logging or rank glance (those live in the Rank tab). |
| `RankDetailRankTab.swift` | Rank tab (the centerpiece): compact current-rank header, the theatrical mystery-ladder CLIMB (earned tiers reveal as lit shields; unreached tiers are sealed "???" tokens — no criteria shown), the "Log a Set" action (ruler for exercises / session sheet for pure skills), and the inline rank-up reveal (ignited rung + banner). |
| `RankDetailStatsTab.swift` | Stats tab: the rich data pane (History folded in) — a progression trend graph (`ProgramRankProofHistoryLineGraph`, with range selector), the bests/PRs + derived numbers (attempts, first logged, accumulated, last logged) as a tile grid, and the chronological past-attempts log. Shows a structured first-time state (placeholder "-" tiles + prompt) before the first log. |

## Where to find X

- **The tab contract other tabs depend on** → `RankDetailViewModel.swift` (public properties + `load(services:)`).
- **The 9-tier ladder rows** → `RankDetailViewModel.ladderRows` (built from skill `tierCriteria` or the strength-ratio ladder).
- **Tab order / titles** → `RankDetailTab.swift`.
- **Custom top bar, hero, tab switch** → `RankDetailView.swift`.
