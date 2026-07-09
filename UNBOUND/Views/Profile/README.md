# Views/Profile

The PROFILE tab — the ARCHIVE counterpart to Home: identity, lifetime state, collection, and settings entry (Home owns today's live mission/rank/streak). `ProfileView` holds the tab's state; its concerns are split across the `ProfileView+*.swift` extension files.

## Files

| File | What it is |
|---|---|
| `ProfileView.swift` | The tab root screen: `ProfileView` state + body (sheets, dialogs, notification wiring). |
| `ProfileView+Header.swift` | `ProfileView` trophy header: banner art + scrims, top bar, hero avatar, metric rail, showcase row, and responsive header-layout metrics. |
| `ProfileView+Identity.swift` | `ProfileView` identity stack (handle/title button, rank + level plates) and the handle-derived display strings. |
| `ProfileView+Archive.swift` | `ProfileView` archive bands (build card, badges section, photo journey/calendar) plus the band container and page wash. |
| `ProfileView+Showcase.swift` | `ProfileView` showcase resolution — builds skill/lift showcase options from proven skills + logged lifts and applies the persisted pick. |
| `ProfileView+Data.swift` | `ProfileView` data: initial load, reward/cosmetic refreshes, squad-flair publish, identity save. |
| `ProfileVisualComponents.swift` | Hero avatar, progress-journey section, rank-title + level plates, trophy showcase row, dossier linework. |
| `ProfileSheets.swift` | `ProfileIdentityForm` (+ its editor context, hosted in the Profile Kit hub), `RankInfoSheet`, `RankTrialFlowStrip`. |
| `ProfileBuildCard.swift` | `ProfileBuildCard` — the build (attribute hex) card. |
| `BuildAttributeCell.swift` | One attribute cell within the build card. |
| `PhotoCalendarView.swift` | Identity log calendar of captured photos; owns the capture action and promotes it into a scan when the milestone window is open. |
| `ProfileScanRow.swift` | Scan entry row (last-scan date / first-scan CTA) opening `PhotoCaptureFlow` via parent state. |
| `CameraPicker.swift` | Minimal `UIImagePickerController` camera sheet returning a `UIImage`. |
| `ProfileShowcaseModels.swift` | Showcase selection/option models + `ProfileShowcaseStore` persistence. |

## Where to find X

- **Profile data loading / badges / cosmetics state** → `ProfileView+Data.swift` (state vars declared on `ProfileView` in `ProfileView.swift`).
- **Header avatar, rank plate, level bar** → `ProfileVisualComponents.swift` (composed in `ProfileView+Header.swift` / `ProfileView+Identity.swift`).
- **Identity editing form (handle/title/showcase) or rank-info sheet** → `ProfileSheets.swift` (form is hosted by `Settings/ProfileCosmeticsView.swift`).
- **Progress-photo capture from Profile** → `PhotoCalendarView.swift` + `ProfileScanRow.swift` (flow itself in `UNBOUND/Views/Scan/PhotoCaptureFlow.swift`).
- **Trophy/showcase picks** → `ProfileShowcaseModels.swift` + `ProfileVisualComponents.swift` (`TrophyShowcaseRow`).
