# Models/Ranking

Rank, attribute, and level progression models: the six-axis attribute system (XP curves, profiles, level curves), the overall LVL curve, rank-up event payloads, earned Titles, and proof-family classification. The `RankTier` enum itself (the nine-tier ladder) is declared in `../Skills/SkillTier.swift`; this folder holds the surfaces built on top of it.

| File | What it contains |
| --- | --- |
| `AttributeContribution.swift` | `AttributeContribution` — a single XP contribution to one attribute axis. |
| `AttributeKey.swift` | `AttributeKey` — the six attribute axes (power, vitality, control, endurance, mobility, explosiveness) with legacy-rawValue decoding and display metadata. |
| `AttributeProfile.swift` | `AttributeProfile` (per-axis values for a user), plus `AttributeProfileSnapshot` and `AttributeSourceReceipt`. |
| `AttributeRankUpEvent.swift` | `AttributeRankUpEvent` — attribute-axis tier-crossing event (`tier` vs crown-band `aTier`) + its `Notification.Name`. |
| `AttributeValue.swift` | `AttributeLevelCurve` (per-axis XP curve: base 16, exponent 2.0, L100 cap) and `AttributeValue` (one axis's XP/level state). |
| `OverallLevelProgress.swift` | `OverallLevelCurve` (overall LVL XP curve, soft cap L100), `OverallLevelProgress`, and `OverallLevelReward`. |
| `ProofFamily.swift` | `ProofFamily` — classification of how a movement proves capability (reps, hold, loaded, eccentric, …). |
| `RankAdvance.swift` | `RankAdvance` — rank-up notification payload emitted on `.rankAdvanced`, consumed by RankUpCinematic / BadgeService; plus a `Color` helper extension. |
| `RankState.swift` | Tombstone only — `LiftRank` was removed in rank-cleanup-v1; file documents the deletion. |
| `RankTitle+Helpers.swift` | `RankTier` extension: canonical tier tint colors, ornament/visual metadata, and derivation helpers (core ladder lives in `../Skills/SkillTier.swift`). |
| `TitleID.swift` | `TitleID` — identifier for an earned Title (axis / vow-kind / badge / shop paths) and `ShopTitleCatalog`. |

Where to find X:

- Tune the per-axis attribute XP curve → `AttributeValue.swift` (`AttributeLevelCurve`)
- Tune the overall LVL curve or level rewards → `OverallLevelProgress.swift`
- Change a rank tier's color or visual ornament → `RankTitle+Helpers.swift`
- Add/decode an attribute axis → `AttributeKey.swift`
- The payload fired when a lift ranks up → `RankAdvance.swift`; for attribute-axis crossings → `AttributeRankUpEvent.swift`
- How earned Titles are identified/cataloged → `TitleID.swift`
