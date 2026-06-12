Models that represent rank tiers, attribute axes, and the events/progress data that drive the UNBOUND ranking system. These are pure data shapes — computation lives in `RankService` and `AttributeService`.

| File | Purpose |
|---|---|
| `RankTitle+Helpers.swift` | SwiftUI color, ornament, and derivation metadata for the nine `RankTier` cases; the tier enum itself lives in `SkillTier.swift` |
| `RankState.swift` | Tombstone — `LiftRank` was removed in rank-cleanup-v1; file retained as a deletion record |
| `RankAdvance.swift` | `RankAdvance` struct — notification payload emitted on `.rankAdvanced` and consumed by `RankUpCinematic` / `BadgeService` |
| `AttributeKey.swift` | `AttributeKey` enum (power, vitality, control, endurance, mobility, explosiveness) and `AttributeLevelCurve` constants |
| `AttributeValue.swift` | `AttributeLevelCurve` level-cap and XP-curve constants; also defines the concave leveling math used by attribute axes |
| `AttributeProfile.swift` | `AttributeProfile` — per-user map of `AttributeKey` → current attribute state, with processed-source receipts |
| `AttributeContribution.swift` | `AttributeContribution` — weighted key→Double map that describes how a movement contributes to each attribute axis |
| `AttributeRankUpEvent.swift` | `AttributeRankUpEvent` — tier or aTier crossing event for an attribute axis, used by `AttributeRankUpToast` |
| `OverallLevelProgress.swift` | `OverallLevelCurve` constants and `OverallLevelProgress` — aggregate XP → overall LVL state |
| `TitleID.swift` | `TitleID` — typed identifier for an earned title, keyed by axis, weekly-vow kind, or badge ID |
| `ProofFamily.swift` | `ProofFamily` enum — categories of movement proof (reps, hold, mobility, form, eccentric, loaded, unilateral, tempo) |

## Where to find X

| Task | File |
|---|---|
| Look up a tier's display color or ornament | `RankTitle+Helpers.swift` |
| Read or emit a rank-up notification payload | `RankAdvance.swift` |
| Add or rename an attribute axis | `AttributeKey.swift` |
| Tune XP-curve constants or level caps | `AttributeValue.swift` (attribute axes), `OverallLevelProgress.swift` (overall LVL) |
| Understand how a movement scores against attribute axes | `AttributeContribution.swift` |
| Resolve a title by its unlock path | `TitleID.swift` |
