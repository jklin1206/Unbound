# Models/Rewards

Reward-economy model types: what a user earns from training (XP, badges, rank-up beats, shop cosmetics) and how a finished session's earnings are assembled into the post-workout reward sequence.

| File | Contents |
| --- | --- |
| `Badge.swift` | `Badge` (id/rarity/art), `BadgeTrigger` unlock conditions, `BadgeUnlockEvent`, and the `badgeUnlocked` notification name. |
| `BadgeCatalog.swift` | `BadgeCatalog` — declarative list of all unlockable badges, ordered roughly by rarity / expected unlock order. |
| `RankCosmetics.swift` | `RankCosmetics` — maps each rank tier (Initiate → Ascendant) to the cosmetic assets it unlocks; also `CosmeticAvatar` / `CosmeticBackdrop` SwiftUI views and a cosmetics notification name. |
| `RewardBeat.swift` | `RewardBeatKind` + `RewardBeat` — a single celebratory beat (standard cleared, skill unlock, rank advance, new best…) and `RewardTally` aggregation. |
| `RewardSummary.swift` | `RewardSummary` — aggregates everything earned from one training event; carries `ProgressionReceipt`, movement/attribute/body-region lines, `PersonalRecord`, `RankUp`. |
| `SessionXP.swift` | `SessionXPRecord` per-user session counter (drives streaks + badges, NOT rank), `SessionXPSourceReceipt`, `SessionXPDelta`, XP notification name. |
| `ShopItem.swift` | Shop catalog: `ShopCategory`, `ShopItemReward`, backdrop/home-background/profile-border/profile-background ID enums, `ShopItem`, `ShopCatalog`. |
| `WorkoutRewardSequence.swift` | `WorkoutRewardSequenceSummary` — the full post-workout reward payload: `XPReward` + breakdown lines, lift/streak/exercise-rank/attribute reward structs. |
| `WorkoutRewardSequenceSummary+Preview.swift` | Preview/sample `WorkoutRewardSequenceSummary` fixtures (extension). |
| `WorkoutRewardSequenceSummary+Receipts.swift` | Receipt-building extension on `WorkoutRewardSequenceSummary`. |

## Where to find X

- Add or edit a badge → `BadgeCatalog.swift` (definition list), `Badge.swift` (trigger kinds).
- Add a shop cosmetic (border, backdrop, background) → `ShopItem.swift` (`ShopCatalog` + ID enums).
- What unlocks at a rank tier → `RankCosmetics.swift`.
- Session XP / streak counting → `SessionXP.swift`.
- The beats shown in the post-workout celebration → `RewardBeat.swift` (single beat), `WorkoutRewardSequence.swift` (whole sequence payload).
- Receipt lines for "what did this set/session earn" → `RewardSummary.swift`, `WorkoutRewardSequenceSummary+Receipts.swift`.
