# Views/Profile

The PROFILE tab — the ARCHIVE counterpart to Home: identity, lifetime state, collection, and settings entry (Home owns today's live mission/rank/streak). Data state lives in `UNBOUND/ViewModels/ProfileViewModel.swift`; presentation state stays on the views here.

## Files

| File | What it is |
|---|---|
| `ProfileView.swift` | The tab root screen. |
| `ProfileVisualComponents.swift` | Hero avatar, progress-journey section, rank-title + level plates, trophy showcase row, dossier linework. |
| `ProfileSheets.swift` | `EditProfileSheet`, `RankInfoSheet`, `RankTrialFlowStrip`. |
| `ProfileBuildCard.swift` | `ProfileBuildCard` — the build (attribute hex) card. |
| `BuildAttributeCell.swift` | One attribute cell within the build card. |
| `OverallRankTrialReadinessCard.swift` | Overall rank-trial readiness card. |
| `PhotoCalendarView.swift` | Identity log calendar of captured photos; owns the capture action and promotes it into a scan when the milestone window is open. |
| `ProfileScanRow.swift` | Scan entry row (last-scan date / first-scan CTA) opening `PhotoCaptureFlow` via parent state. |
| `CameraPicker.swift` | Minimal `UIImagePickerController` camera sheet returning a `UIImage`. |
| `ProfileShowcaseModels.swift` | Showcase selection/option models + `ProfileShowcaseStore` persistence. |

## Where to find X

- **Profile data loading / badges / cosmetics state** → `UNBOUND/ViewModels/ProfileViewModel.swift` (not this folder).
- **Header avatar, rank plate, level bar** → `ProfileVisualComponents.swift`.
- **Edit-profile or rank-info sheets** → `ProfileSheets.swift`.
- **Progress-photo capture from Profile** → `PhotoCalendarView.swift` + `ProfileScanRow.swift` (flow itself in `UNBOUND/Views/Scan/PhotoCaptureFlow.swift`).
- **Trophy/showcase picks** → `ProfileShowcaseModels.swift` + `ProfileVisualComponents.swift` (`TrophyShowcaseRow`).
