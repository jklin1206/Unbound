## Models

All Swift data models for the UNBOUND app, organized by domain. Each subfolder owns one cohesive feature area.

### Subfolders

| Folder | Domain |
|--------|--------|
| `Core/` | Foundation types shared app-wide: `UserProfile`, `AppError`, `LoadingState<T>`, `BuildIdentity`, onboarding enums, notification preferences, nutrition/recovery plans, and vitality check-ins |
| `Program/` | Training program lifecycle: the generated plan, blocks, progression state, coaching actions, travel override, cut mode, and configuration enums (training style, weight policy, feedback mode, weekday) |
| `Routines/` | Side-quest routines: library of cardio/mobility/challenge routines, step definitions, runtime execution model, and completion records |
| `Trials/` | Weekly Vow system: card selection, slot kinds (ember/overdrive/apex), theme/axis targeting, capstone proof verification, and completion ledger entries |
| `Rewards/` | Shop inventory, cosmetics by rank, badge catalog, reward beats, session XP, and the post-workout reward sequence pipeline |
| `Sessions/` | Active workout models: `Workout`, `WorkoutLog`, `WorkoutBlock`, `PerformanceLog`, `CardioSession`, `AISession`, `SavedWorkout`, rest timer, and quick-log draft factory |
| `Movements/` | Exercise catalog and resolution: `MovementCatalog`, `ExerciseCatalog`, `MovementResolver`, proof matching, movement progress, and library search |
| `Skills/` | Skill tree: nodes, clusters, tiers, tier generator, unlock standards, training plan library (all 6 families), tree skins, and user skill progress |
| `SkillTreeContent/` | Generated skill graph node definitions organized by family (V3 calisthenics, carry, core, handstand, planche, pull, push, legs, strength gaps) |
| `Ranking/` | Attribute-based ranking: `AttributeProfile`, `AttributeKey`, `AttributeValue`, `RankState`, `RankAdvance`, `OverallLevelProgress`, `TitleID`, and proof family definitions |
| `Standards/` | Performance standards: `SkillStandards` (single source for bodyweight tier criteria), `StrengthStandards`, `UnrankedMovements`, movement resolution tables, and gates |
| `Squads/` | Social layer: `Squad`, `SquadMember`, `SquadState`, `SquadMission`, leaderboard, activity feed, presence, logos, titles, and friend challenges |
| `Body/` | Body-scan domain: `BodyScan`, `BodyAnalysis`, `BodyRegion`, muscle heat groups, scan checkpoints, delta reports, progress photos, and calibration baselines |

### Files remaining at Models/ root

| File | Why not moved |
|------|--------------|
| `WorkingWeight.swift` | Cross-cutting: tracks per-user per-exercise working weight and `ProgressionSuggestion`; not listed for movement to any subfolder in this pass — flag for a future Standards or Sessions assignment |

### Where to find X

- **User account fields (name, email, program id)** → `Core/User.swift`
- **Today's training plan / rest day status** → `Program/ProgramSurfaceState.swift`, `Program/Program.swift`
- **Available exercises and movement aliases** → `Movements/MovementCatalog.swift`, `Movements/MovementResolver.swift`
- **Skill node definitions and tier ladders** → `Skills/SkillTree.swift`, `Skills/SkillTierGenerator.swift`, `SkillTreeContent/`
- **Post-workout XP, badges, and rank reveal** → `Rewards/RewardSummary.swift`, `Rewards/WorkoutRewardSequence.swift`
- **Squad members, missions, and leaderboard** → `Squads/Squad.swift`, `Squads/SquadMission.swift`, `Squads/SquadLeaderboard.swift`
- **Body scan results and muscle scores** → `Body/BodyScan.swift`, `Body/BodyAnalysis.swift`
- **Strength and skill performance thresholds** → `Standards/StrengthStandards.swift`, `Standards/SkillStandards.swift`
