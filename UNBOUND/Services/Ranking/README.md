# Ranking

Per-lift RankTier and skill-tier state, the overall rank-trial system (the gym exams that advance `RankTitle`), proof/prereq evaluation from workout logs, session XP/streaks, and the velocity (LV) weighting layer. Tier standards themselves are objective and pure — this directory evaluates and persists them.

## Files

| File | Purpose |
| --- | --- |
| `GateKeys.swift` | Gate-key definitions: the consumable keys that unlock rank-trial attempts (`GateKey`, `GateKeyType`, inventory helpers). |
| `LiftTierService.swift` | UserDefaults persistence of the current `SkillTier` per (lift, userId). |
| `OverallRankTrialDefinitions.swift` | Static catalog of the rank-trial definitions: stations, movement options, equipment requirements, performance standards per `RankTitle`. |
| `OverallRankTrialProgress.swift` | Codable progress model: `highestPassedRank` + attempt history (`OverallRankTrialAttempt`). |
| `OverallRankTrialRunner.swift` | `@MainActor` runner: drafts a trial as a `TrainingSessionDraft`, evaluates the completed attempt, and produces `OverallRankTrialRunResult` (rank advance, dedup, callouts). |
| `OverallRankTrialService.swift` | The trial model layer: statuses, formats, loadouts, `TrialStation`/`TrialLoadoutVariant`/`ResolvedRankTrial`, evaluation + definition types (no class — all value types). |
| `PrereqClearer.swift` | Auto-clears skill prereqs from achieved proofs: `AchievedSkillProof`/`ClearedSkillPrereq` models + threshold mapping for unlock requirements and tier criteria. |
| `ProgramAwareStreakPolicy.swift` | Liftoff-style day-based streak rule: gaps auto-credit rest days; streak breaks only after a 3-day gap. Program-agnostic despite the name. |
| `ProofEngine.swift` | Pure `evaluate(log:source:...)` — turns a `WorkoutLog` into proof outcomes: cleared standards/prereqs, skill unlocks, rank advancements, new bests (`ProofEngineResult`). |
| `RankDecayService.swift` | On app foreground: 7-13 days idle → recalibrating banner; 14+ days → decay 1 sub-rank per extra week. Capability unlocks + peak rank never decay. |
| `RankProgressCloudBackup.swift` | Mirrors the trial-confirmed rank + per-lift tiers onto the synced `users` doc (`overall_rank_trials` / `lift_tiers` jsonb) through the outbox choke point, and seeds the local stores back on launch — so a reinstall restores the rank instead of resetting to Initiate (`RankProgressBackuping`). |
| `RankService.swift` | Owns per-lift `RankTier` state, triggered from ProgressionEngine on every ingested log; emits `.rankAdvanced`. Ratio/added-load/rep/hold anchors per lift family. |
| `RankServiceProtocol.swift` | Protocol: pure `computeTier(skill:history:bodyweightKg:)` + `evaluateTierCrossings(log:userId:)`. |
| `RankTrialLoadoutResolver.swift` | Resolves a trial definition + the user's available equipment into a concrete `RankTrialResolution` (preferred loadout variant, blockers). |
| `SessionXPCloudBackup.swift` | Mirrors the session-XP streak record + bonus ledger onto the synced `users` doc (`streakBackup` jsonb) through the outbox choke point, and seeds the local store back on launch via the never-regressing `SessionXPRecord.merging` — so a reinstall restores the streak instead of zeroing it (`SessionXPBackuping`). |
| `SessionXPService.swift` | Session record + streak/weekly counters with a source-idempotent `recordSession` variant; posts `.sessionXPUpdated`. |
| `SkillTierMigration.swift` | One-time idempotent migration that walks full log history to seed `UserSkillTierState` (called from `UnboundApp` RootView task). |
| `TierCriterionEvaluator.swift` | Pure single source of truth for `TierCriterion` semantics against log history (case-insensitive names, warmups excluded, `.seconds` reads `SetLog.durationSeconds`). |
| `TrialReadinessService.swift` | Evaluates whether the user is ready for the next rank trial: requirement lines, blocker summary, resolved trial preview. |
| `UserSkillTierStore.swift` | UserDefaults-backed persistence for `UserSkillTierState`, one entry per userId. |
| `VelocityService.swift` | The LV weighting layer: skill/compound multipliers, comeback bonus, rank-up bolus — makes ability visible in LV without touching objective rank standards. |

## Where to find X

- **How a lift's rank/tier is computed** → `RankService.swift` (orchestration) + `TierCriterionEvaluator.swift` (criterion semantics).
- **Rank trials (definitions, readiness, running one)** → `OverallRankTrialDefinitions.swift` → `TrialReadinessService.swift` → `RankTrialLoadoutResolver.swift` → `OverallRankTrialRunner.swift`; model types in `OverallRankTrialService.swift`.
- **What a finished workout "proves" (unlocks, bests, prereqs)** → `ProofEngine.swift` + `PrereqClearer.swift`.
- **Streak rules** → `ProgramAwareStreakPolicy.swift`; counters persist via `SessionXPService.swift` and mirror to the cloud via `SessionXPCloudBackup.swift`.
- **Rank decay / recalibration banner** → `RankDecayService.swift`.
- **LV/XP multipliers** → `VelocityService.swift` (session XP recording is `SessionXPService.swift`).
