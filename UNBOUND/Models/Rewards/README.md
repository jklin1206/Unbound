## Models/Rewards

Shop inventory, cosmetic unlocks, badges, and the reward-beat pipeline that animates post-workout celebrations.

| File | Purpose |
|------|---------|
| `ShopItem.swift` | `ShopCategory` enum and `ShopItem` struct representing purchasable cosmetics (backdrops, borders, banners, tree skins, titles) |
| `RankCosmetics.swift` | Maps each `RankTier` to the avatar frame, profile wallpaper, and skill-tree skin that unlock at that rank |
| `BadgeCatalog.swift` | Declarative static list of all unlockable `Badge` entries, ordered by rarity |
| `Badge.swift` | `Badge` model — id, display name, unlock criteria text, and visual metadata |
| `RewardSummary.swift` | Aggregates everything earned from one training event (XP, new bests, unlocks) for the reward beat sequence |
| `RewardBeat.swift` | `RewardBeatKind` enum — individual beat types (standard cleared, rank advance, skill unlock, new best, etc.) |
| `SessionXP.swift` | `SessionXPRecord` — per-user session counter driving streaks and badge unlocks; not rank |
| `WorkoutRewardBuilder.swift` | Private builder helpers extracted from `WorkoutRewardSequence.swift` to keep file size manageable |
| `WorkoutRewardSequence.swift` | `WorkoutRewardSequenceSummary` — rich post-workout beat payload shared by all completion routes |
| `WorkoutRewardTypes.swift` | `XPReward` and related supporting value types for the reward sequence |
| `WorkoutVowCallouts.swift` | `WeeklyVowCompletionBonus` and share-card descriptors presented when a weekly vow is fulfilled |

### Where to find X

- **Add a new badge** → `BadgeCatalog.swift` (add to `all` array) + `Badge.swift` (confirm fields)
- **Change what unlocks at a rank** → `RankCosmetics.swift`
- **Add a new shop category or item type** → `ShopItem.swift`
- **Adjust what appears in the post-workout screen** → `WorkoutRewardSequence.swift`, `WorkoutRewardBuilder.swift`
- **Change beat kinds (e.g. add a new milestone type)** → `RewardBeat.swift`
- **Track or reset session XP / streaks** → `SessionXP.swift`
