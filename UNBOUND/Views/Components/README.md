# Views/Components (root level)

Shared, screen-agnostic UI components: toasts, badges, charts, shapes, and small widgets reused across tabs. Subfolders: `Anime/` (backdrop/glow/particle effects), `Cinematic/` (rank-up cinematics), `Home/` (`PhaseChip`), `HUD/` (HUD-styled form controls — see its README), `Scan/` (`ScanCameraPreview`), and `Unbound/` (the Premium Hollow component set — has its own README).

## Files (root level)

| File | What it is |
|---|---|
| `ActionUndoToast.swift` | `ActionUndoToast` — undoable-action toast. |
| `AnimatedProgressBar.swift` | `AnimatedProgressBar` — animated horizontal progress bar. |
| `AttributeHex.swift` | `AttributeHex` radar hex + `AttributeRankBadge`. |
| `AttributeRankUpToast.swift` | Attribute rank-up toast modifier; `.tier` accent vs `.aTier` impact styling (aTier also fires the chain-shatter cinematic). |
| `BadgeMedallion.swift` | One cohesive rendered badge (SF-symbol glyph + rarity metal frame, locked state) — replaced the 46 PNG medallions. |
| `BadgeUnlockToast.swift` | Serialized-queue badge unlock pill (quiet second-order reward; rank-ups own takeovers) + `BadgeEmblemView`. |
| `ExerciseVisualView.swift` | Exercise demo visual: asset-set enums + `ExerciseVisualView`. |
| `GradientButton.swift` | `GradientButton` — gradient CTA button. |
| `Hexagon.swift` | Pointy-top `Hexagon` InsettableShape shared by skill-tree nodes and rank badges. |
| `LoadingStateView.swift` | `LoadingStateView<T>` — generic loading-state wrapper view. |
| `MuscleRadarChart.swift` | `MuscleRadarChart` + radar grid/data shapes. |
| `PhotoCaptureOverlay.swift` | Camera capture framing overlay. |
| `RecalibratingBanner.swift` | Thin banner shown when `unbound.isRecalibrating` (7+ days idle); cleared by `RankDecayService`. |
| `ScoreRing.swift` | `ScoreRing` — circular score ring. |
| `SkinUnlockToast.swift` | Skin unlock pill; listens on `.skinUnlocked`. |
| `TierUnlockToast.swift` | Tier unlock toast + modifier. |
| `TriStateToggle.swift` | `TriStateToggle` — three-state toggle control. |
| `WeightBumpToast.swift` | Weight-bump suggestion toast + modifier. |

## Where to find X

- **A reward/unlock toast** → `BadgeUnlockToast.swift`, `SkinUnlockToast.swift`, `TierUnlockToast.swift`, `AttributeRankUpToast.swift`, `WeightBumpToast.swift` (full-screen cinematics in `Cinematic/`).
- **Hex/radar attribute visuals** → `AttributeHex.swift`, `Hexagon.swift`, `MuscleRadarChart.swift`.
- **Badge rendering** → `BadgeMedallion.swift`.
- **HUD-styled buttons/pickers/inputs** → `HUD/` (own README).
- **Premium Hollow design-language components** → `Unbound/` (own README).
