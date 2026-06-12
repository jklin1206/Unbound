# Dashboard

The main home tab: the quiet black-and-charcoal overview screen (`UnboundHomeView`) assembled by `HomeTabView`, plus every contextual card, chrome layer, and data derivation that populates it.

| File | Contents |
|---|---|
| `UnboundHomeView.swift` | Root view struct, stored properties, inits; assembles the top bar, rank card, CTA, contextual stack, stats grid, and last-session recap from sub-modules |
| `UnboundHomeView+Briefing.swift` | `homeHeroStack` — top bar + `homeBriefing` + training console layout; the "above the fold" hero section |
| `UnboundHomeView+Controls.swift` | `homeControlSurface` — weekly strip, icon dock, and active vow inline status bar rendered below the hero |
| `UnboundHomeView+DailyQuest.swift` | Daily-quest / scan-eligibility logic: `shouldShowScanEligibility`, `dayWord(for:)`, and quest card rendering helpers |
| `UnboundHomeView+Loading.swift` | Cosmetic store binding (`bindCosmeticStores`), session launch, and bodyweight display formatting (unit from `@AppStorage`) |
| `HomeTabView.swift` | Root `TabView` wiring all four tabs (Home / Skills / Squad / Profile), rest-timer clock, launch-argument tab selection, and debug skill/cardio overrides |
| `HomeDashboardSections.swift` | Stateless section views: `HomeTopBarSection`, `HomeAvatarBadge`, and other composable rows used inside `UnboundHomeView` |
| `HomeChromeViews.swift` | `HomeBackgroundContrastScrim` and other full-bleed chrome layers (gradient scrims, backdrop overlays) |
| `HomeLoadingSkeleton.swift` | Shimmer placeholder skeleton shown while `HomeViewModel` is fetching on first load |
| `HomeRanksCard.swift` | `HomeRanksRow` — compact row surfacing aggregate rank tier; tapping opens the rank library |
| `HomeBuildChipCard.swift` | `HomeBuildChipCard` — attribute hex-chart thumbnail + BUILD label; taps into the character-sheet attribute breakdown |
| `HomeBodyWeightViews.swift` | `BodyWeightOverTimeChart` and related body-weight log visualisations (30-log sparkline, unit-aware display) |
| `HomeLoadDerivations.swift` | Pure, dependency-free `HomeLoadDerivations` enum: dedupes `workout_logs` fetches into `lastLog`, `hasLogged`, `bodyRegionLoads`, and weekly-rhythm helpers |
| `StaminaCardView.swift` | `StaminaCardView` — navigates to `CardioHistoryView` when sessions exist, or shows an empty-state prompt to log cardio |
| `ScanDueCard.swift` | `ScanDueCard` — contextual banner that appears when the monthly scan cadence is unlocked or on first scan; taps into `PhotoCaptureFlow` |
| `DayOneCalibrationCard.swift` | `DayOneCalibrationCard` — two-mode calibration prompt (`.hero` pulsing onboarding card / `.slim` compact banner) |
| `CoachModesStrip.swift` | `CoachModesStrip` — three AI coach mode buttons (Travel / Deload / Plateau-fix); plateau button only visible when `ProgressionEngine` flags a stall |
| `BodyLoadHeatmapView.swift` | `BodyLoadHeatmapView` — body-region load chart built from 7-day `workout_logs`; tapping a bar highlights the selected region |

## Where to find X

- **Tab bar and tab routing** → `HomeTabView.swift`
- **Home hero layout (top bar, briefing, CTA)** → `UnboundHomeView+Briefing.swift`
- **Weekly strip / icon dock** → `UnboundHomeView+Controls.swift`
- **Shimmer loading state** → `HomeLoadingSkeleton.swift`
- **Weekly rhythm / body-region load math** → `HomeLoadDerivations.swift`
- **AI coach mode sheets** → `CoachModesStrip.swift`
