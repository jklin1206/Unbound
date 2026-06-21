# Rewards

The post-training reward surface: diffing user state across a training event into a `RewardSummary`, shaping proof-engine results into the reward sequence payload, and the cosmetic-shop currency wallet.

## Files

| File | Purpose |
| --- | --- |
| `CurrencyWalletStore.swift` | UserDefaults-backed Vows currency wallet (`ObservableObject`): balance, 1,500 starter grant, grant ledger, `ShopPurchaseResult` (purchased / alreadyOwned / insufficientFunds), DEBUG unlimited-balance mode. |
| `RewardComputer.swift` | Central before/after snapshot differ: every caller (QuickLog, session end, ...) takes a snapshot before writing the log, then `after(snapshot:...)` derives PRs / rank-ups / badge unlocks / first-set into a `RewardSummary` for `WorkoutRewardSequenceView`. |
| `RewardPayloadBuilder.swift` | Attaches `ProofEngineResult` outcomes (beats, tally, emblem ignition, exercise ranks) onto a `WorkoutRewardSequenceSummary`. |
| `SquadRewardPolicy.swift` | Balance constants and dedup-safe `sourceId` builders for squad rewards (Arc amounts per the plan balance checkpoint). |

## Where to find X

- **Why a reward beat did (or didn't) show after a workout** → `RewardComputer.swift` (the snapshot diff) and `RewardPayloadBuilder.swift` (proof-result shaping).
- **Currency balance / shop purchase outcomes** → `CurrencyWalletStore.swift`.
- **The reward UI itself** → not here; see `UNBOUND/Views/Components/Unbound/WorkoutRewardSequenceView*`.
