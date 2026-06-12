# Views/Components

Root-level shared UI primitives: toast notifications, chart shapes, badge and rank visuals, progress indicators, and exercise visual helpers. Subdirectories `HUD/`, `Unbound/`, `Anime/`, `Cinematic/`, `Home/`, and `Scan/` hold domain-specific component groups.

| File | Purpose |
|------|---------|
| `ActionUndoToast.swift` | `ActionUndoToast` — 10-second timed toast with animated undo progress ring |
| `AttributeRankUpToast.swift` | `AttributeRankUpToastModifier` — top-of-screen toast for attribute-axis tier and A-tier crossings |
| `BadgeUnlockToast.swift` | `BadgeUnlockToastModifier` — serialized queue of badge-unlock pills; legendary badges jump to the front |
| `SkinUnlockToast.swift` | `SkinUnlockToastModifier` — top-of-screen pill for newly unlocked skill-tree skins |
| `TierUnlockToast.swift` | `TierUnlockToastModifier` — top-of-screen tier unlock pill |
| `WeightBumpToast.swift` | `WeightBumpToastModifier` — top-of-screen pill for `ProgressionAdvance` weight-bump events |
| `AnimatedProgressBar.swift` | `AnimatedProgressBar` — horizontal fill bar that animates to a given progress fraction |
| `ScoreRing.swift` | `ScoreRing` — circular arc ring animating from 0 to `score/maxScore` |
| `AttributeHex.swift` | `AttributeHex` — filled hexagonal radar chart for the 6 build attributes |
| `MuscleRadarChart.swift` | `MuscleRadarChart` — radar chart with current vs target overlays for muscle groups |
| `BadgeMedallion.swift` | `BadgeMedallion` — unified rendered badge (SF symbol glyph + rarity metal frame + locked state; no PNG assets) |
| `ExerciseVisualView.swift` | `ExerciseVisualAssetSet` enum and helper for resolving the active exercise visual art set |
| `Hexagon.swift` | `Hexagon` — reusable pointy-top hexagon `InsettableShape` shared across skill nodes and rank badges |
| `GradientButton.swift` | `GradientButton` — branded gradient CTA button with loading/disabled states |
| `LoadingStateView.swift` | `LoadingStateView<T>` — generic idle/loading/error/loaded state renderer |
| `PhotoCaptureOverlay.swift` | `PhotoCaptureOverlay` — framing overlay (silhouette rectangle) for camera capture |
| `RecalibratingBanner.swift` | `RecalibratingBanner` — dismissible HUD banner shown when `unbound.isRecalibrating` is set |
| `TriStateToggle.swift` | `TriStateToggle` — YES/SUB/NO three-button toggle bound to `ExercisePreferenceStatus?` |

## Where to find X

| Task | File |
|------|------|
| Show a toast after an action (undo, badge, rank-up) | `ActionUndoToast.swift`, `BadgeUnlockToast.swift`, `AttributeRankUpToast.swift` |
| Display the attribute build hex chart | `AttributeHex.swift` |
| Add a new progress indicator | `AnimatedProgressBar.swift` or `ScoreRing.swift` |
| Use the hexagon shape for a new node type | `Hexagon.swift` |
| Handle the exercise visual asset set toggle | `ExerciseVisualView.swift` |
| Show the recalibrating banner | `RecalibratingBanner.swift` (reads `@AppStorage("unbound.isRecalibrating")`) |
