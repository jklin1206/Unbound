# SkillSession

Full-screen modal session logger for a single skill, launched from SkillDetailView's TRAIN button. It loads (or regenerates) today's AI session, lets the user log sets inline per prescription slot, and finishes by emitting a PerformanceLog through TrainingCompletionService into the reward sequence.

| File | Purpose |
| --- | --- |
| `SkillSessionView.swift` | Core view: stored state, inits, computed slot/progress counts, `body` + `sessionBody` scaffold (alerts, sheets, rest-banner overlay, lifecycle). |
| `SkillSessionView+Sections.swift` | UI sections: header + AI badge, today's work list with slot chips, accessories disclosure, loading/summary/fallback cards, finish bar, shared card styling. |
| `SkillSessionView+Session.swift` | Session logic: `finish()` completion flow + XP, AI session load/regenerate, elapsed timer helpers. |
| `SetLoggerSheet.swift` | Per-slot set entry sheet presented from `SkillSessionView`; edits/creates a `LoggedSet` for a prescription. |
| `SkillQuickLogSheet.swift` | `QuickLogSheet` — lightweight single-set "I did some reps" capture (10 XP), opened from `SkillDetailView` without a structured session. |
| `SkillSessionRestCombatViews.swift` | Rest-period combat UI: `ActiveSlot`/`RestCombatState` models, `RestCombatBanner`, rest-guard health bar. |
