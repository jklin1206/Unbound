# Views/Profile

Identity and lifetime-achievement screen: avatar/banner, rank journey, badge grid, attribute build card, photo calendar, scan entry point, and cosmetic-selection sheets. Data state lives in `ProfileViewModel`; this directory holds only presentation and layout.

| File | Purpose |
|------|---------|
| `ProfileView.swift` | Root profile screen: avatar hero, rank, badges, build card, photo calendar, settings link |
| `ProfileVisualComponents.swift` | `ProfileHeroAvatar` — layered avatar: cosmetic tier glow, shop border, photo or letter fallback |
| `ProfileSheets.swift` | `EditProfileSheet` — handle, title, showcase-skill, and showcase-lift pickers |
| `ProfileShowcaseModels.swift` | `ProfileShowcaseSelection` and `ProfileShowcaseOption` for the pinned showcase slots |
| `ProfileBuildCard.swift` | 2-column attribute grid with selected-axis detail drawer |
| `BuildAttributeCell.swift` | Single attribute cell: key label, value, selected-state fill |
| `ProfileScanRow.swift` | Scan entry-point row: shows last-scan date or first-scan CTA; routes to `PhotoCaptureFlow` |
| `OverallRankTrialReadinessCard.swift` | Rank trial readiness card: shows the next available trial definition and "Start" CTA |
| `PhotoCalendarView.swift` | Identity photo log: calendar of captured progress photos with capture action |
| `CameraPicker.swift` | Minimal `UIImagePickerController` wrapper for camera capture |

## Where to find X

| Task | File |
|------|------|
| Change the avatar / hero section layout | `ProfileVisualComponents.swift` + `ProfileView.swift` |
| Edit the attribute build card or axis detail | `ProfileBuildCard.swift` + `BuildAttributeCell.swift` |
| Modify the scan entry-point row | `ProfileScanRow.swift` |
| Adjust the rank trial readiness card | `OverallRankTrialReadinessCard.swift` |
| Edit the edit-profile sheet fields | `ProfileSheets.swift` + `ProfileShowcaseModels.swift` |
| Change photo calendar behavior | `PhotoCalendarView.swift` |
