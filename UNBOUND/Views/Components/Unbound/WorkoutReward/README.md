# WorkoutReward

The workout-end payout sequence: the full-screen `WorkoutRewardSequenceView` that plays staged reward "beats" (session complete → XP → proof → attributes → collection → progression) after a finished workout, plus every supporting card, row, bar, and HUD piece it composes. Color rules are deliberate: XP is blue, lift families own their hues, attributes use axis colors, violet is reserved for major tier/system impact.

## Files

| File | What's inside |
|---|---|
| `WorkoutRewardSequenceView.swift` | The root view: `WorkoutRewardSequenceView` (driven by `WorkoutRewardSequenceSummary`), its `RewardBeatKind` beat enum, beat state (`beat`, `animatedXP`), and dismiss flow. |
| `WorkoutRewardSequenceView+BeatPages.swift` | Extension with the per-beat page bodies (`cosmeticBeat`, `streakBeat`, etc.) — the actual content of each staged reward page. |
| `WorkoutRewardSequenceView+Readouts.swift` | Extension with derived readouts: `weightUnit`/`volumeText` formatting, `dominantLiftTint`/`proofTint` color selection, the radar before/after maps + level-bracket zoom, and the shared header/row/token builders. |
| `WorkoutRewardComponents.swift` | Shared chrome: `CinematicRewardHUD` (notched-line frame overlay), `HUDNotchedLine`, `TriangleCorner`, `RewardPanel` (the tinted beat container), `StreakFlame`, `CountUpNumberText` (odometer count-up number), and the free `formatWhole(_:)` helper. |
| `WorkoutRewardHeroComponents.swift` | Hero/spotlight cards: `ExerciseRankCard`, `ProofRewardRow`, `AnimatedRewardAttributeHex`, `RankBadgeRevealView`, `RankStandardHero` (+ private badge/copy nodes), `LevelProgressHero`, `MovementXPSpotlight`, `AttributeRankSpotlight`. |
| `RankRevealBloom.swift` | `RankRevealBloom` — tier-tinted breathing bloom + landing shockwave rendered behind rank badge reveals (reward heroes + the library's attempt reveal). |
| `WorkoutRewardProgressRows.swift` | Progress rows + accents: `RankPulseRings` (hexagon pulse), `LevelUpChip`, `AttributeLevelProgressRow`, `MovementXPProgressRow`, `ReceiptTotalRow`. |
| `WorkoutRewardRows.swift` | List rows for unlocks/deltas: `RewardBadgeAsset` (badge medallion lookup), `AttributeDeltaRow`, `PRRewardRow`, `SegmentedArcProgress`, `CosmeticUnlockRow`. |
| `WorkoutRewardStatBars.swift` | The RPG-style bar kit: `RPGStatBar`, `EnergyFill` (gradient fill + one-shot shimmer sweep), `OriginCap`/`EndCap`/`BarTick`, and the `DiamondShard`/`CutCornerBar` shapes. |

## Where to find X

- **Beat ordering / which beats exist** → `RewardBeatKind` in `WorkoutRewardSequenceView.swift`.
- **What a specific beat page looks like** → `WorkoutRewardSequenceView+BeatPages.swift`.
- **Tint or formatted-text logic (volume, units, proof color)** → `WorkoutRewardSequenceView+Readouts.swift`.
- **The tinted panel every beat sits in** → `RewardPanel` in `WorkoutRewardComponents.swift`.
- **Per-exercise rank card / rank-up badge reveal** → `WorkoutRewardHeroComponents.swift`.
- **XP/attribute progress bars** → `WorkoutRewardStatBars.swift` (bar primitives) and `WorkoutRewardProgressRows.swift` (composed rows).
- **Badge / PR / cosmetic unlock rows** → `WorkoutRewardRows.swift`.
