# Streak logic

UNBOUND's day-streak, modeled on the Liftoff "Ranked Gym Workouts" rule
([FAQ](https://liftoffrank.com/en/faq)). Day-based, forgiving, and **completely
program-agnostic** — the program only *suggests* what to train; the streak only
asks "did you log a workout recently."

## The rule

- **Driven by logging a workout — not opening the app.** The streak only advances
  from `TrainingCompletionService.complete()`, which runs when you complete a
  workout of *any* type (program, custom/freestyle, skill session, cardio,
  routine, trial). Opening Home/Profile reads the streak (`record()`) but never
  changes it.
- **Counts days, not sessions.** Logging on non-consecutive days credits the gap:
  log Monday then Wednesday → **+2** (Tuesday, a rest day, is auto-counted).
- **Breaks only after 3 missed days.** You must log within a **3-day gap** of your
  last session (log Monday → must log by Thursday; Friday is too late). A 4+ day
  gap resets the streak to 1.
- **Rest days are free.** No scheduled days, no rest-day accounting, no program
  adherence — train and rest on whatever cadence you want.

### Implementation
`ProgramAwareStreakPolicy.shouldExtendStreak` (the `activeProgram` /
`resetWindowDays` params are kept only for call-site compatibility and are
ignored):

```
same day              → no change
gap 1…3 days          → streak += gap   (extended; rest days credited)
gap ≥ 4 days          → reset to 1       (broken)
```

`maxGapDays = 3` is the single knob.

## Countdown (why it stays relevant)

So the streak creates urgency, the UI shows **days left to log before it breaks**:

```
daysRemaining = maxGapDays − (days since last logged session)
```

- logged **today** → 3 days of headroom (shown as safe).
- 1 day ago → **2 days left**
- 2 days ago → **1 day left**
- 3 days ago → **LOG TODAY** (last valid day)
- 4+ days ago → lapsed (next session starts a new run)

Surfaced via `SessionXPRecord.streakDaysRemaining(...)` on the Home streak block
(a countdown chip) and in the post-workout streak reward beat ("log within 3
days to keep it"). See `ProgramAwareStreakPolicyTests` for the locked behavior.

## Deliberately not built (Liftoff has these; they're separate features)

- **Streak-restore shop items** (Super / Mega / Revive) — monetization.
- **4-month seasons** that reset the ladder.
