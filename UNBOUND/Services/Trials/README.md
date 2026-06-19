# Trials (Weekly Vows)

The Weekly Vows system — historically named "Trials", and most types here carry the newer `WeeklyVow*` names (`typealias TrialsService = WeeklyVowsService`). Covers generating the three weekly vow cards, self-report sealing, completion rewards and missed-vow penalties, the title thresholds they feed, and persistence.

## Files

| File | Purpose |
| --- | --- |
| `TitleCatalog.swift` | Maps `TitleID` → display name (axis/tier grid plus badge, shop, and squad-season-winner paths). |
| `TrialsNotifications.swift` | `Notification.Name` constants for vow lifecycle (+ legacy `trial*` adapter names) and the `TrialsService = WeeklyVowsService` typealias. |
| `TrialsNotificationScheduler.swift` | `WeeklyVowsNotificationScheduler` — vows are in-app by default; this now only clears legacy pending local notifications. |
| `TrialsService.swift` | `WeeklyVowsService` — the `@MainActor` orchestrator: week roll, card pick, completion, state over store + attribute service. |
| `TrialsServiceProtocol.swift` | Protocol + `WeeklyVowCompletionReceipt` (vow, log id, reward callout, completion bonus). |
| `TrialsStore.swift` | `WeeklyVowsStore` — UserDefaults persistence for `WeeklyVowsState` per userId (reads legacy `trialsState` key too). |
| `VowBadgeTrack.swift` | Vow badge milestone thresholds and crossing detection for badge unlocks tied to vow streaks. |
| `VowBankPool.swift` | Curated weekly vow card bank pool — the universe of cards the weekly draw selects from. |
| `VowWeeklyDraw.swift` | Deterministic weekly 3-card draw from the bank pool, keyed to the user + ISO week. |
| `WeeklyVowRewards.swift` | Reward + penalty policy: `WeeklyVowPenaltyCatalog` applies missed-vow XP penalties to a capped ledger. |

## Where to find X

- **How the 3 weekly cards are picked** → `VowWeeklyDraw.swift` (draw) + `VowBankPool.swift` (card universe).
- **Sealing a vow (self-report taps) + completion/penalty** → `TrialsService.swift`; reward/penalty policy in `WeeklyVowRewards.swift`.
- **Vow lifecycle orchestration + state** → `TrialsService.swift` + `TrialsStore.swift`.
- **Titles earned from vows** → `TitleCatalog.swift`.
- **Vow badge milestones** → `VowBadgeTrack.swift`.
