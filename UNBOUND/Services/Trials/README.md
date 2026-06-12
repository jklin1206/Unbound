# Trials (Weekly Vows)

The Weekly Vows system — historically named "Trials", and most types here carry the newer `WeeklyVow*` names (`typealias TrialsService = WeeklyVowsService`). Covers generating the three weekly vow cards, building/recognizing vow training sessions, completion rewards and missed-vow penalties, the title thresholds they feed, and persistence.

## Files

| File | Purpose |
| --- | --- |
| `TitleCatalog.swift` | Maps `TitleID` → display name (axis/tier grid plus badge, shop, and squad-season-winner paths). |
| `TitleThresholdEvaluator.swift` | Pure: compares two `WeeklyVowsState` snapshots and returns TitleIDs whose 3/7/15 (bronze/silver/gold) thresholds were crossed. |
| `TrialGenerator.swift` | `WeeklyVowGenerator` — pure, deterministic: profile + recent logs + week → 3 `WeeklyVowCard`s (Recovery / Finisher / Limit). |
| `TrialsNotifications.swift` | `Notification.Name` constants for vow lifecycle (+ legacy `trial*` adapter names) and the `TrialsService = WeeklyVowsService` typealias. |
| `TrialsNotificationScheduler.swift` | `WeeklyVowsNotificationScheduler` — vows are in-app by default; this now only clears legacy pending local notifications. |
| `TrialsService.swift` | `WeeklyVowsService` — the `@MainActor` orchestrator: week roll, card pick, completion, state over store + attribute service. |
| `TrialsServiceProtocol.swift` | Protocol + `WeeklyVowCompletionReceipt` (vow, log id, reward callout, completion bonus). |
| `TrialsStore.swift` | `WeeklyVowsStore` — UserDefaults persistence for `WeeklyVowsState` per userId (reads legacy `trialsState` key too). |
| `WeeklyVowProof.swift` | `WeeklyVowTrainingRoute` — encodes/decodes the vow id in the session's programId and decides whether a log counts as completed vow work. |
| `WeeklyVowRewards.swift` | Reward + penalty policy: `WeeklyVowPenaltyCatalog` applies missed-vow XP penalties to a capped ledger. |
| `WeeklyVowTrainingBuilder.swift` | Builds the `TrainingSessionDraft` for a chosen vow card (block kind/title/prescriptions from the capstone). |

## Where to find X

- **How the 3 weekly cards are picked** → `TrialGenerator.swift`.
- **Starting a vow workout / detecting a vow log** → `WeeklyVowTrainingBuilder.swift` (build) + `WeeklyVowProof.swift` (route/detect).
- **Completion bonus or missed penalty** → `WeeklyVowRewards.swift`; receipt shape in `TrialsServiceProtocol.swift`.
- **Vow lifecycle orchestration + state** → `TrialsService.swift` + `TrialsStore.swift`.
- **Titles earned from vows** → `TitleThresholdEvaluator.swift` + `TitleCatalog.swift`.
