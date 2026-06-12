# Services/Ranking

Evaluates and persists a user's strength rank and skill tier across every logged workout. Handles skill-tier crossing detection, lift-rank computation, session XP with velocity weighting, rank decay for inactivity, streak policy, and the Overall Rank Trial system that gates progression to the next rank tier.

| File | Purpose |
|---|---|
| `RankServiceProtocol.swift` | Protocol: `computeTier`, `evaluateTierCrossings`, `computeLiftRank`, `evaluate(log:)`, `aggregateRank/aggregateTier`. |
| `TierCriterionEvaluator.swift` | Pure evaluator: tests a single `TierCriterion` (reps, seconds, kg, %BW) against log history. Single source of truth for criterion semantics. |
| `ProofEngine.swift` | Defines `SkillStandard` and `WorkoutProofSource`; evaluates proof against the skill-standard catalog. |
| `UserSkillTierStore.swift` | UserDefaults-backed persistence for `UserSkillTierState` (per-skill earned tiers) keyed by userId. |
| `LiftTierService.swift` | UserDefaults-backed store for per-lift `SkillTier` progress keyed by userId + lift name. |
| `SessionXPService.swift` | Records sessions, maintains streaks and weekly counters, posts `.sessionXPUpdated`; source-idempotent via `sourceId`. |
| `VelocityService.swift` | Velocity/LV weighting layer: multiplies per-movement AP by skill difficulty, compound bonus, comeback bonus, and rank-up boluses. |
| `RankDecayService.swift` | Applies inactivity-based rank decay after 14 days of no logging (1 sub-rank per additional 7-day gap); never decays capability unlocks or peak rank. |
| `ProgramAwareStreakPolicy.swift` | Day-gap streak policy (Liftoff-style): streak breaks after 3 days with no workout; rest days are auto-counted. |
| `SkillTierMigration.swift` | One-time migration: walks full log history to seed `UserSkillTierState`; idempotent via UserDefaults flag. |
| `OverallRankTrialService.swift` | Manages the Overall Rank Trial lifecycle: status transitions (locked→ready→attempted→passed/failed). |
| `OverallRankTrialRunner.swift` | Executes a trial attempt: evaluates the user against the trial definition and records the outcome. |
| `OverallRankTrialDefinitions.swift` | Static catalog of rank-trial definitions per `RankTier` target. |
| `OverallRankTrialProgress.swift` | Tracks a user's progress within an active trial (sets completed, criteria met). |
| `TrialReadinessService.swift` | Evaluates readiness for the next Overall Rank Trial given current rank, level, and equipment. |
| `RankTrialLoadoutResolver.swift` | Resolves the correct exercise loadout for a trial based on the user's available equipment. |
| `PrereqClearer.swift` | Defines `AchievedSkillProof` and `SkillProofUnit`; marks prerequisites cleared when proof criteria are met. |

## Where to find X

| Task | File(s) |
|---|---|
| Whether a criterion (reps/seconds/kg) is satisfied | `TierCriterionEvaluator.swift` |
| Session XP, streaks, and weekly counters | `SessionXPService.swift` |
| Velocity / LV weighting for ability | `VelocityService.swift` |
| Rank decay for inactivity | `RankDecayService.swift` |
| Overall Rank Trial unlock conditions and execution | `OverallRankTrialDefinitions.swift`, `TrialReadinessService.swift`, `OverallRankTrialRunner.swift` |
