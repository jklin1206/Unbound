# WorkoutReward

Post-workout payout sequence and all supporting components. Presents a staged
beat-by-beat reveal of XP, lift-rank advances, attribute deltas, badge unlocks,
and cosmetic drops after a session ends. The sequence is cinematic but
skippable — the user can dismiss as soon as the final yield is visible.

## File table

| File | Purpose |
|------|---------|
| `WorkoutRewardSequenceView.swift` | Root view (`WorkoutRewardSequenceView`). Owns the beat state machine, animated XP counter, attribute hex progress maps, and the outer `RewardPanel` scroll stack. Entry point from the post-workout dismissal flow. |
| `WorkoutRewardSequenceView+BeatPages.swift` | Extension on `WorkoutRewardSequenceView` — individual beat page bodies (cosmetic, badge, rank, XP, attribute) rendered as `some View` computed vars wired into the beat state machine. |
| `WorkoutRewardSequenceView+Readouts.swift` | Extension on `WorkoutRewardSequenceView` — computed readout helpers: `weightUnit`, `volumeText`, `dominantLiftTint`, `proofTint`, and other derived display values consumed by the beat pages. |
| `WorkoutRewardComponents.swift` | Shared layout primitives: `CinematicRewardHUD`, `HUDNotchedLine`, `RewardPanel`, `CosmeticUnlockRow`, and `formatWhole(_:)`. Used across multiple beat pages. |
| `WorkoutRewardHeroComponents.swift` | `ExerciseRankCard` — the animated rank-advance hero card with fill bar, badge pop, and tint driven by `ExerciseRankReward`. |
| `WorkoutRewardProgressRows.swift` | `RankPulseRings` — pulsing concentric hexagon rings rendered behind the rank badge during a rank-advance beat. |
| `WorkoutRewardRows.swift` | Row-level components: `RewardBadgeAsset` (badge medallion resolved from `BadgeCatalog`), `AttributeDeltaRow`, and other per-reward list rows. |
| `WorkoutRewardStatBars.swift` | `EnergyFill`, `CutCornerBar` — the animated stat bar fill used by progress rows. Handles shimmer sweep on completion. |
| `XPReceiptStrip.swift` | `XPReceiptStrip` — compact three-cell strip showing GAINED / TOTAL / TO NEXT XP with dividers. Embedded in the XP beat page. |

## Where to find X

- **The beat state machine / entry point** → `WorkoutRewardSequenceView.swift`
- **What each beat page looks like** → `WorkoutRewardSequenceView+BeatPages.swift`
- **Display value derivations (tints, unit formatting)** → `WorkoutRewardSequenceView+Readouts.swift`
- **Shared panel / row chrome** → `WorkoutRewardComponents.swift`
- **Rank-advance card** → `WorkoutRewardHeroComponents.swift`
- **Hexagon pulse rings behind the badge** → `WorkoutRewardProgressRows.swift`
- **Badge / attribute delta rows** → `WorkoutRewardRows.swift`
- **Animated fill bars** → `WorkoutRewardStatBars.swift`
- **XP gained / total / remaining strip** → `XPReceiptStrip.swift`
