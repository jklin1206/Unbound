# CardioLog Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Goal:** Wire the existing `CardioLogService` (working CRUD, no consumers) into the coaching pipeline so cardio sessions actually inform weekly volume metrics, plateau detection, and recovery state. Stop treating cardio as a write-only side store.

**Architecture:** `CardioLogService` is the source of truth — no migration needed. Three new lightweight read-paths plug into existing services: `WeeklyVolumeService` adds cardio to its weekly totals, `PlateauFixService` factors recent cardio load into its detection (high cardio + stagnant strength → "you're probably under-recovered" recommendation), and `RecoveryStateService` (or equivalent in checkpoint flow) considers cardio minutes as a recovery-load signal.

**Tech stack:** Swift, existing service architecture.

---

## Scope

In:
- `WeeklyVolumeService` reads from `CardioLogService` and includes cardio in volume tallies
- `PlateauFixService` reads recent cardio when deciding if a plateau is fatigue-driven
- `RecoveryStateService` (if exists; else, integrate into the Checkpoint signal pipeline from program redesign Phase D) considers cardio load
- Logged cardio sessions auto-post to squad chat as a `.workout` `SquadMessage` (via `SquadMessageAutoPoster` — see Squads v1 P2)
- New `CardioLogQueryHelpers.swift` extension with rolled-up queries (`minutesInWeek(of:)`, `sessionsInLastNDays(_:)`)

Out:
- New cardio logging UI (existing UI assumed sufficient — verify via grep, flag if missing)
- Auto-import from Apple Health (defer)
- Cardio-specific PRs (defer)
- Heart rate zones, GPS routes, splits (defer — they belong in a future cardio-deep release)

---

## File-Touch Matrix

| File | Action | Notes |
|---|---|---|
| `UNBOUND/Services/CardioLog/CardioLogQueryHelpers.swift` | **Create** | Extensions on `CardioLogService` for time-windowed queries |
| `UNBOUND/Services/WeeklyVolume/WeeklyVolumeService.swift` | **Modify** | Find via grep; add cardio dimension to volume rollup |
| `UNBOUND/Services/Coach/PlateauFixService.swift` | **Modify** | Inject `CardioLogService`; include recent cardio in plateau analysis |
| `UNBOUND/Services/Scan/CheckpointValidator.swift` (from program redesign P-D) | **Modify** | Include `cardio.minutesInLastWeek` in the recovery-state computation |
| `UNBOUND/Services/Squads/SquadMessageAutoPoster.swift` | **Modify** | Observe `.cardioLogged` notification → post `.workout` SquadMessage with payload tagged as cardio |
| `UNBOUND/Services/CardioLog/CardioLogService.swift` | **Modify** | Post `Notification.Name.cardioLogged` on `log()` success |
| `UNBOUND/Models/SquadMessagePayload.swift` | **Modify** | Add an optional `discipline: String?` field to `.workout` payload to distinguish cardio from strength (or add a new `.cardio` case if the team prefers) |
| `UNBOUND/UNBOUNDTests/Services/CardioLogQueryHelpersTests.swift` | **Create** | minutesInWeek, sessionsInLastNDays |
| `UNBOUND/UNBOUNDTests/Services/WeeklyVolumeWithCardioTests.swift` | **Create** | Logging cardio increases weekly volume |
| `UNBOUND/UNBOUNDTests/Services/PlateauFixWithCardioTests.swift` | **Create** | High cardio + stagnant strength → fatigue suggestion, not load increase |

## Plan Notes

- TODO(cardiolog-integration): `WeeklyVolumeService.swift` and `SquadMessageAutoPoster.swift` are not present in the current `UNBOUND/UNBOUND/Services` tree; defer those consumers until the real services land rather than creating placeholder architecture.

---

## Tasks

### Task 1 — Query helpers

**File:** Create `UNBOUND/Services/CardioLog/CardioLogQueryHelpers.swift`.

```swift
extension CardioLogService {
    func minutesInLastNDays(_ n: Int, asOf date: Date = .now) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -n, to: date)!
        return recent(since: cutoff).map(\.durationMinutes).reduce(0, +)
    }

    func sessionsInLastNDays(_ n: Int, asOf date: Date = .now) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -n, to: date)!
        return recent(since: cutoff).count
    }

    func minutesInWeek(of date: Date) -> Int {
        let cal = Calendar(identifier: .iso8601)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: date)!.start
        let weekEnd = cal.dateInterval(of: .weekOfYear, for: date)!.end
        return all().filter { $0.performedAt >= weekStart && $0.performedAt < weekEnd }
            .map(\.durationMinutes).reduce(0, +)
    }
}
```

(`recent(since:)` may already exist; if not, add it.)

**Acceptance:** `CardioLogQueryHelpersTests` covers each helper with mixed-date fixtures.

**Commit:** `feat(cardio): query helpers`

### Task 2 — Weekly volume includes cardio

**File:** Modify `WeeklyVolumeService.swift` (locate via grep).

Add a `cardioMinutes` dimension to the weekly volume struct it returns. Pull via `cardioLog.minutesInWeek(of:)`. Update consumers (likely Program tab summary, Profile stats) to display the new dimension.

**Acceptance:** `WeeklyVolumeWithCardioTests` — log a 45-min cardio session this week → weekly volume.cardioMinutes == 45.

**Commit:** `feat(volume): include cardio in weekly volume`

### Task 3 — PlateauFix considers cardio

**File:** Modify `PlateauFixService.swift`.

Inject `cardioLog: CardioLogService` as a dependency. In the plateau-detection routine, when strength progression has stagnated for 2+ weeks, check `cardioLog.minutesInLastNDays(14)`:

- If `minutes > 300` (i.e., 5+ hrs cardio in 2 weeks): suggest "Try a deload or cut cardio for a week — your recovery may be the limiter."
- If `minutes <= 300`: existing logic (suggest load/volume adjustments).

**Acceptance:** `PlateauFixWithCardioTests` — stagnant strength + 400 min cardio → fatigue suggestion; same strength + 100 min cardio → load adjustment.

**Commit:** `feat(coach): plateau fix factors in cardio load`

### Task 4 — Checkpoint recovery factors in cardio

**File:** Modify `UNBOUND/Services/Scan/CheckpointValidator.swift` (created in program redesign Phase D — confirm it exists before editing).

Add `cardioMinutesLastWeek` to the input signals. In the recovery state computation, treat cardio minutes as a tier modifier:
- < 60 min/wk: no effect
- 60-180 min/wk: slight fatigue bias
- > 180 min/wk: substantial fatigue bias (push recovery hint toward `.accumulated` or `.flagged`)

**Acceptance:** Add to existing `CheckpointValidatorTests` — high cardio shifts the bias output as expected.

**Commit:** `feat(checkpoint): cardio minutes factor into recovery state`

### Task 5 — Auto-post cardio sessions to squad chat

**Files:** Modify `CardioLogService.swift`, `SquadMessageAutoPoster.swift`, `SquadMessagePayload.swift`.

In `CardioLogService.log()`, after a successful write, post:
```swift
NotificationCenter.default.post(name: .cardioLogged, object: cardioLog)
```

In `SquadMessageAutoPoster.start()`, observe `.cardioLogged` → if user is in a squad, insert a `SquadMessage(.workout)` with payload `.workout(workoutId: cardioLog.id, title: "\(cardioLog.discipline) · \(cardioLog.durationMinutes) min", durationMin: cardioLog.durationMinutes, rpe: cardioLog.rpe)`.

Update `SquadMessagePayload.workout` to include optional `discipline: String?` so the chat bubble can label it correctly ("Run · 45 min" vs "Push Day · 48 min"). Update `WorkoutBubble` rendering to show the discipline if present.

**Acceptance:** Log a run → card appears in squad chat with "Run · 45 min" header.

**Commit:** `feat(cardio): auto-post cardio sessions to squad chat`

---

## Verification

```bash
xcodebuild test -scheme UNBOUND -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:UNBOUNDTests/Services/CardioLogQueryHelpersTests \
  -only-testing:UNBOUNDTests/Services/WeeklyVolumeWithCardioTests \
  -only-testing:UNBOUNDTests/Services/PlateauFixWithCardioTests
```

Manual sanity:
1. Log a 45-min run via existing cardio UI.
2. Open Program tab → weekly volume shows cardio minutes.
3. Open squad chat → run card visible.
4. Log 5 more runs in a week → next plateau check biases toward fatigue suggestion.
