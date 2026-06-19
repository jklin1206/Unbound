# Dashboard

The Home tab itself: `HomeTabView` is the app's root tab container, and `UnboundHomeView` (plus its extensions) is the quiet home dashboard it hosts — top bar, briefing, training console, week path, and the contextual cards that surface below them.

| File | Purpose |
| --- | --- |
| `HomeTabView.swift` | Root tab container — hosts `UnboundHomeView`, the skill tree tab, rest-timer overlay, and DEBUG launch-arg routing. |
| `UnboundHomeView.swift` | Main home dashboard view: stored state, model wiring, and the top-level `body` scroll scaffold. |
| `UnboundHomeView+Briefing.swift` | Hero stack extension: top bar + briefing block layout. |
| `UnboundHomeView+Controls.swift` | Control surface extension: week path, icon dock, active-vow inline status. |
| `UnboundHomeView+DailyQuest.swift` | Daily quest card extension; swaps PHOTO/SCAN label off the monthly scan cadence rule. |
| `UnboundHomeView+Loading.swift` | View-side load pieces only (data load lives in `HomeViewModel`): cosmetic store binding, session launch, bodyweight formatting. |
| `HomeDashboardSections.swift` | Reusable home sections: `HomeTopBarSection`, `HomeBriefingSection`, `HomeTrainingConsoleSection`, `HomeWeekPathSection`, shimmer bar. |
| `HomeSystemVoice.swift` | The `[ SYSTEM ]` directive voice: state machine (cleared/rest/quest/awaiting) + per-day deterministic line pools, plus the completed-console anime quote. |
| `HomeChromeViews.swift` | Home chrome: background contrast scrim, command artwork kinds, `HomeIconCommand` dock button. |
| `HomeLoadingSkeleton.swift` | Shimmer placeholder skeleton shown while the home dashboard loads. |
| `HomeLoadDerivations.swift` | Pure, dependency-free derivations from one recent-logs fetch (dedupes three `workout_logs` fetches; unit-testable). |
| `HomeRanksCard.swift` | `HomeRanksRow` — compact row surfacing aggregate rank tier, opens the rank library. |
| `HomeBuildChipCard.swift` | Tappable card showing the user's `AttributeProfile` as an attribute hex chart. |
| `HomeBodyWeightViews.swift` | Bodyweight chart, history screen, and log sheet. |
| `StaminaCardView.swift` | Stamina stat card with logger/history sheets; empty state when no sessions exist. |
| `ScanDueCard.swift` | Contextual card shown when the monthly scan is due/overdue or never done; opens PhotoCaptureFlow. |
| `DayOneCalibrationCard.swift` | Calibration prompt with `.hero` (onboarding) and `.slim` (home default) modes. |
| `CoachModesStrip.swift` | Three contextual AI coach mode buttons (travel, deload, plateau-fix) with their sheets. |
| `BodyLoadHeatmapView.swift` | Body-region load heatmap: SVG-region figure, heat colors, selection strip, band pills. |

Where to find X:
- Home tab routing / which tab shows what → `HomeTabView.swift`
- The home screen's section layout order → `UnboundHomeView.swift` (scaffold) + `UnboundHomeView+Briefing.swift` / `+Controls.swift`
- Top bar avatar/level/ARC balance UI → `HomeDashboardSections.swift` (`HomeTopBarSection`)
- Home data loading logic → NOT here; it's in `HomeViewModel` (this folder keeps only view-side pieces, see `UnboundHomeView+Loading.swift`)
- Skill tree tab content → `../SkillTree/`
- Muscle/body-region heat rendering → `BodyLoadHeatmapView.swift`
