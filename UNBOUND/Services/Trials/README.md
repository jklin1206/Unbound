# Services/Trials

Manages the Weekly Vow system (formerly Trials): weekly card generation, user pick/skip, proof evaluation, completion receipts, title unlocks, and missed-vow penalties. Also owns the `TitleCatalog` (display names for all earned titles) and the `TitleThresholdEvaluator` for progressive title unlocks.

| File | Purpose |
|---|---|
| `TrialsServiceProtocol.swift` | Protocol `WeeklyVowsServiceProtocol`: roll week, pick/skip card, build training draft, record completion, evaluate proof, check window, equip title. `TrialsServiceProtocol` is a typealias. |
| `TrialsService.swift` | Production service `WeeklyVowsService`: state machine for the weekly vow lifecycle (pending → picked → windowOpen → completed/missed). |
| `TrialsStore.swift` | UserDefaults-backed persistence for `WeeklyVowsState` per userId; includes legacy `unbound.trialsState.*` key migration. |
| `TrialGenerator.swift` | Pure card generator `WeeklyVowGenerator`: produces 3 `WeeklyVowCard` values (Recovery, Finisher, Limit) from profile + history + week number. |
| `WeeklyVowTrainingBuilder.swift` | Builds a routable `TrainingSessionDraft` for a committed vow's capstone work. |
| `WeeklyVowProof.swift` | Routing helpers: encodes/decodes the vow's `programId` prefix so the completion flow can identify a vow session. |
| `WeeklyVowRewards.swift` | Applies missed-vow XP penalty from `WeeklyVowPenaltyCatalog`; tracks penalty ledger to prevent double-penalizing. |
| `TitleCatalog.swift` | Pure display-name lookup for `TitleID` → human-readable title string. Covers badge, shop, and axis/tier-grid paths. |
| `TitleThresholdEvaluator.swift` | Pure evaluator: computes which progressive title thresholds are newly crossed given updated counters. |
| `TrialsNotifications.swift` | `Notification.Name` constants for vow lifecycle events (weekRolled, picked, windowOpen, completed, titleUnlocked) plus legacy trial-named adapters. |
| `TrialsNotificationScheduler.swift` | Clears legacy pending vow notifications from the system notification center; weekly vows are now in-app only. |

## Where to find X

| Task | File(s) |
|---|---|
| Weekly card generation logic | `TrialGenerator.swift` |
| Completing or missing a vow | `TrialsService.swift`, `WeeklyVowRewards.swift` |
| Building the capstone workout draft | `WeeklyVowTrainingBuilder.swift` |
| Title display names or unlock thresholds | `TitleCatalog.swift`, `TitleThresholdEvaluator.swift` |
| Notification names for vow events | `TrialsNotifications.swift` |
