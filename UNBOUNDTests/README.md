# UNBOUND Test Map

Use this file as the first stop before adding or moving tests. The suite is broad, but the useful question is ownership: which subsystem is protected, and which command should a refactor run first?

| Subsystem | Primary tests | Run first when changing |
| --- | --- | --- |
| Logging and completion | `Services/TrainingCompletionSquadProgressTests.swift`, `Services/TrainingSessionDraftStoreTests.swift`, `Models/TrainingSessionAdapterTests.swift`, `Models/ProgramAwareLoggingTests.swift` | `-only-testing:UNBOUNDTests/TrainingCompletionSquadProgressTests -only-testing:UNBOUNDTests/TrainingCompletionIntegrationGuardrailTests -only-testing:UNBOUNDTests/TrainingSessionAdapterTests -only-testing:UNBOUNDTests/ProgramAwareLoggingTests` |
| Movement progression and rank proof | `Services/MovementProgressServiceTests.swift`, `Models/MovementResolverTests.swift`, `Services/SkillProgress/SkillAutoProofTests.swift` | `-only-testing:UNBOUNDTests/MovementProgressServiceTests -only-testing:UNBOUNDTests/SkillAutoProofTests` |
| Skill detail, guide, and standards | `Services/SkillStandardConsistencyTests.swift`, `Services/SkillProgress/SkillAutoProofTests.swift`, `Models/NodeStateLegacyDecodeTests.swift`, `Models/SkillTierGeneratorTests.swift` | `-only-testing:UNBOUNDTests/SkillStandardConsistencyTests -only-testing:UNBOUNDTests/SkillAutoProofTests -only-testing:UNBOUNDTests/NodeStateLegacyDecodeTests -only-testing:UNBOUNDTests/SkillTierGeneratorTests`; use simulator smoke for Skill Detail UI until focused view tests exist. |
| Program generation | `Services/ProgramGeneration/*Tests.swift`, `Services/ProgramStoreTests.swift` | `-only-testing:UNBOUNDTests/DeterministicProgramGeneratorTests -only-testing:UNBOUNDTests/ProgramStoreTests` |
| Sync and merge safety | `Services/Sync/*Tests.swift` | `-only-testing:UNBOUNDTests/SyncEngineTests -only-testing:UNBOUNDTests/SyncedDatabaseTests -only-testing:UNBOUNDTests/RemoteSyncMapTests` |
| Squads and challenges | `Services/Squad*Tests.swift`, `Models/Squad*Tests.swift`, `Services/FriendChallengeServiceTests.swift` | `-only-testing:UNBOUNDTests/SquadServiceTests -only-testing:UNBOUNDTests/FriendChallengeServiceTests` |
| Rewards | `Services/RewardPayloadBuilderTests.swift`, plus temporary cross-system coverage in `UNBOUNDTests.swift` | `-only-testing:UNBOUNDTests/RewardPayloadBuilderTests`; run completion tests when reward receipts are fed by logging. |

For large refactors, regenerate the project with `xcodegen generate`, then run the focused slice above before the full simulator suite. Keep new tests near the subsystem they protect; avoid adding another catch-all test file unless the behavior truly crosses systems.
