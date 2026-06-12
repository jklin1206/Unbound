# Services/Rewards

Computes and assembles the post-workout reward sequence: personal records, rank advances, badge unlocks, and XP tally. Also manages the in-app Arc Currency wallet (UserDefaults-backed) used for cosmetic shop purchases.

| File | Purpose |
|---|---|
| `RewardComputer.swift` | `@MainActor` service: diffs a pre-log snapshot against post-log state to derive PRs, rank-ups, and badge unlocks; returns a `WorkoutRewardSequenceSummary`. |
| `RewardPayloadBuilder.swift` | Pure builder: attaches proof engine results (tier crossings, lift ranks, emblem ignition) to an existing `WorkoutRewardSequenceSummary`. |
| `CurrencyWalletStore.swift` | `ObservableObject` UserDefaults store for the user's Arc Currency balance; handles starter grant, purchases (`ShopPurchaseResult`), and a DEBUG unlimited-balance mode. |

## Where to find X

| Task | File(s) |
|---|---|
| Compute PRs / rank-ups / badges after a log | `RewardComputer.swift` |
| Attach tier-crossing and proof results to the reward summary | `RewardPayloadBuilder.swift` |
| Check or deduct the user's Arc Currency balance | `CurrencyWalletStore.swift` |
