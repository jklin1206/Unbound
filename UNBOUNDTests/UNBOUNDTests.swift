// UNBOUNDTests/UNBOUNDTests.swift
import XCTest
@testable import UNBOUND

final class UNBOUNDSmokeTest: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }

    func testTrainingReceiptCarriesSkillRewardIntoProgramSequencePayload() {
        let now = Date()
        let performanceLog = PerformanceLog(
            id: "skill-log-1",
            userId: "user-1",
            source: .skill,
            title: "Incline Push-Up",
            startedAt: now.addingTimeInterval(-90),
            completedAt: now,
            blocks: [
                PerformanceBlock(
                    kind: .skill,
                    title: "Incline Push-Up",
                    skillId: "cal.incline-pushup",
                    exercises: [
                        PerformanceExercise(
                            name: "Incline Push-Up",
                            plannedSets: 1,
                            plannedTarget: "Skill work",
                            sets: [
                                PerformanceSet(setNumber: 1, reps: 8, rpe: 7)
                            ]
                        )
                    ],
                    durationSeconds: 90
                )
            ]
        )

        var completion = TrainingCompletionResult()
        completion.skillXPGained = 10
        completion.overallLevelXPGained = 6
        completion.overallLevelReward = OverallLevelReward(
            xpGained: 6,
            noveltyMultiplier: 1,
            previousXP: 20,
            currentXP: 26,
            previousLevel: 1,
            currentLevel: 1,
            previousProgressToNextLevel: 0.2,
            currentProgressToNextLevel: 0.26
        )

        var reward = RewardSummary()
        reward.xpGained = 10
        reward.firstSet = FirstSet(skillId: "cal.incline-pushup", skillTitle: "Incline Push-Up")
        reward.progression = completion.progressionReceipt

        let sequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: performanceLog,
            completionResult: completion,
            rewardSummary: reward,
            fallbackXP: 10,
            sourceName: "Quick Log"
        )

        XCTAssertEqual(sequence.workoutName, "Incline Push-Up")
        XCTAssertEqual(sequence.workSets, 1)
        XCTAssertEqual(sequence.rpe, 7)
        XCTAssertEqual(sequence.xp.total, 16)
        XCTAssertEqual(sequence.xp.breakdown.map(\.label), ["Skill XP", "Level XP"])
        XCTAssertEqual(sequence.badges.first?.title, "First Rep")
        XCTAssertEqual(sequence.progression?.skillXPGained, 10)
    }

    func testSimpleReceiptProvidesProgramSequencePayloadForNonUnifiedRoutes() {
        let sequence = WorkoutRewardSequenceSummary.simpleReceipt(
            workoutName: "Run Session",
            durationMinutes: 30,
            workSets: 1,
            rpe: 6,
            xpTotal: 36,
            xpLabel: "Cardio logged",
            sourceName: "Cardio"
        )

        XCTAssertEqual(sequence.workoutName, "Run Session")
        XCTAssertEqual(sequence.durationMinutes, 30)
        XCTAssertEqual(sequence.workSets, 1)
        XCTAssertEqual(sequence.rpe, 6)
        XCTAssertEqual(sequence.xp.total, 36)
        XCTAssertEqual(sequence.xp.breakdown.first?.label, "Cardio logged")
        XCTAssertNil(sequence.progression)
    }

    func testCardioSessionAdapterFeedsUnifiedProgressionReceipt() {
        let session = CardioSession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            userId: "u-cardio",
            type: .run,
            durationMinutes: 30,
            distanceKm: 5,
            avgHR: 142,
            perceivedEffort: 7,
            notes: "steady",
            date: Date(timeIntervalSince1970: 1_000)
        )

        let log = TrainingSessionAdapters.performanceLogForCardioSession(session)
        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertEqual(log.id, "cardio-11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(log.source, .cardio)
        XCTAssertEqual(log.blocks.first?.kind, .cardio)
        XCTAssertEqual(log.blocks.first?.durationSeconds, 1_800)
        XCTAssertEqual(log.blocks.first?.distanceMeters, 5_000)
        XCTAssertEqual(gains.first?.movementId, "cardio.run")
        XCTAssertGreaterThan(gains.reduce(0) { $0 + $1.rawAP }, 0)

        var completion = TrainingCompletionResult()
        completion.movementAPGains = gains
        completion.overallLevelXPGained = 12
        completion.overallLevelReward = OverallLevelReward(
            xpGained: 12,
            noveltyMultiplier: 1,
            previousXP: 100,
            currentXP: 112,
            previousLevel: 2,
            currentLevel: 2,
            previousProgressToNextLevel: 0.2,
            currentProgressToNextLevel: 0.28
        )

        let sequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: completion,
            fallbackXP: 30,
            sourceName: "Cardio"
        )

        XCTAssertEqual(sequence.workoutName, "Run Session")
        XCTAssertEqual(sequence.workSets, 1)
        XCTAssertEqual(sequence.rpe, 7)
        XCTAssertEqual(sequence.progression?.movementLines.first?.name, "Run")
    }

    func testRoutineAdapterTurnsAuthoredChallengeStepsIntoMovementProgression() {
        let routine = RoutineLibrary.placeholderRoutines.first { $0.id == "100-pushup" }!
        let record = RoutineCompletionRecord(
            id: "routine-record-1",
            routineId: routine.id,
            completedAt: Date(timeIntervalSince1970: 2_000),
            elapsedSeconds: 900,
            primaryMetric: .repCount(total: 100, bursts: [40, 30, 30]),
            spAwarded: routine.spReward
        )

        let log = TrainingSessionAdapters.performanceLogForRoutine(
            routine,
            record: record,
            userId: "u-routine"
        )
        let pushup = log.blocks.first?.exercises.first
        let gains = MovementAPCalculator.gains(from: log)

        XCTAssertEqual(log.id, "routine-routine-record-1")
        XCTAssertEqual(log.source, .routine)
        XCTAssertEqual(log.blocks.first?.routineId, "100-pushup")
        XCTAssertEqual(pushup?.name, "Push-ups")
        XCTAssertEqual(pushup?.sets.map(\.reps), [40, 30, 30])
        XCTAssertTrue(gains.contains { $0.rankStandardMovementId == "exercise.pushup" })
        XCTAssertGreaterThan(gains.reduce(0) { $0 + $1.rawAP }, 0)
    }

    func testCarryPerformanceLogFeedsUnifiedReceiptShape() {
        let now = Date()
        let log = PerformanceLog(
            id: "carry-log-1",
            userId: "u-carry",
            source: .custom,
            title: "Carry Proof",
            startedAt: now.addingTimeInterval(-600),
            completedAt: now,
            blocks: [
                PerformanceBlock(
                    kind: .carry,
                    title: "Loaded Carry",
                    exercises: [
                        PerformanceExercise(
                            name: "Farmer Carry",
                            plannedSets: 1,
                            plannedTarget: "40m",
                            sets: [
                                PerformanceSet(setNumber: 1, weightKg: 48, distanceMeters: 40, rpe: 8)
                            ]
                        )
                    ]
                )
            ]
        )
        let gains = MovementAPCalculator.gains(from: log)
        var completion = TrainingCompletionResult()
        completion.movementAPGains = gains
        completion.overallLevelXPGained = 8
        completion.overallLevelReward = OverallLevelReward(
            xpGained: 8,
            noveltyMultiplier: 1,
            previousXP: 200,
            currentXP: 208,
            previousLevel: 2,
            currentLevel: 2,
            previousProgressToNextLevel: 0.40,
            currentProgressToNextLevel: 0.45
        )

        let sequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: completion,
            fallbackXP: 12,
            sourceName: "Custom"
        )

        XCTAssertEqual(sequence.workoutName, "Carry Proof")
        XCTAssertEqual(sequence.workSets, 1)
        XCTAssertEqual(sequence.rpe, 8)
        XCTAssertEqual(sequence.progression?.movementLines.first?.name, "Farmer Carry")
        XCTAssertGreaterThan(sequence.progression?.totalMovementAP ?? 0, 0)
    }

    func testTrainingReceiptUsesAttributeScoresAndXPForAttributeBeat() {
        let now = Date()
        let log = PerformanceLog(
            id: "attribute-log-1",
            userId: "u-attributes",
            source: .custom,
            title: "Attribute Proof",
            startedAt: now.addingTimeInterval(-300),
            completedAt: now,
            blocks: [
                PerformanceBlock(
                    kind: .strength,
                    title: "Strength",
                    exercises: [
                        PerformanceExercise(
                            name: "Bench Press",
                            plannedSets: 1,
                            plannedTarget: "5",
                            sets: [
                                PerformanceSet(setNumber: 1, reps: 5, weightKg: 100, rpe: 8)
                            ]
                        )
                    ]
                )
            ]
        )
        var completion = TrainingCompletionResult()
        var profileBefore = AttributeProfile.empty(userId: "u-attributes", at: now)
        profileBefore.set(
            .power,
            AttributeValue(peak: 21.4, current: 21.4, xp: 400, lastContributionAt: now)
        )
        profileBefore.set(
            .mobility,
            AttributeValue(peak: 14, current: 14, xp: 225, lastContributionAt: now)
        )
        var profileAfter = profileBefore
        profileAfter.set(
            .power,
            AttributeValue(peak: 21.5, current: 21.5, xp: 405, lastContributionAt: now)
        )
        completion.attributeProfileBefore = profileBefore
        completion.attributeProfileAfter = profileAfter
        completion.attributeRewards = [
            AttributeProgressionReward(
                key: .power,
                xpGained: 5,
                previousXP: 400,
                currentXP: 405,
                previousLevel: 2,
                currentLevel: 2,
                previousTier: .novice,
                currentTier: .novice,
                previousScore: 21.4,
                currentScore: 21.5
            )
        ]

        let sequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: completion,
            fallbackXP: 12,
            sourceName: "Custom"
        )

        let power = sequence.attributeDeltas.first
        XCTAssertEqual(power?.key, .power)
        XCTAssertEqual(power?.xpGained ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(power?.previous ?? 0, 21.4, accuracy: 0.001)
        XCTAssertEqual(power?.current ?? 0, 21.5, accuracy: 0.001)
        XCTAssertEqual(sequence.attributePreviousLevels[.power], 2)
        XCTAssertEqual(sequence.attributeLevels[.power], 2)
        XCTAssertEqual(sequence.attributePreviousLevels.count, AttributeKey.allCases.count)
        XCTAssertEqual(sequence.attributeLevels.count, AttributeKey.allCases.count)
        XCTAssertEqual(sequence.attributeTiers[.power], profileAfter.rankTitles[.power])
        XCTAssertEqual(sequence.attributePreviousHexValues.count, AttributeKey.allCases.count)
        XCTAssertEqual(sequence.attributeCurrentHexValues.count, AttributeKey.allCases.count)
        XCTAssertEqual(
            sequence.attributePreviousHexValues[.mobility] ?? -1,
            sequence.attributeCurrentHexValues[.mobility] ?? -2,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            sequence.attributeCurrentHexValues[.power] ?? 0,
            sequence.attributePreviousHexValues[.power] ?? 0
        )
        XCTAssertEqual(power?.previousProgress ?? 0, AttributeLevelCurve.progressFraction(forXP: 400), accuracy: 0.001)
        XCTAssertEqual(power?.currentProgress ?? 0, AttributeLevelCurve.progressFraction(forXP: 405), accuracy: 0.001)
        XCTAssertEqual(
            power?.previousHexChartValue ?? 0,
            AttributeLevelCurve.hexDisplayValue(level: 2, progress: AttributeLevelCurve.progressFraction(forXP: 400)),
            accuracy: 0.001
        )
        XCTAssertEqual(
            power?.currentHexChartValue ?? 0,
            AttributeLevelCurve.hexDisplayValue(level: 2, progress: AttributeLevelCurve.progressFraction(forXP: 405)),
            accuracy: 0.001
        )
        XCTAssertEqual(power?.currentPrestigeGlow ?? 1, 0, accuracy: 0.001)
        XCTAssertLessThan(power?.currentHexChartValue ?? 100, power?.current ?? 0)
    }

    func testAttributeHexDisplayCompressesUncappedLevelsAndAddsPrestigeGlow() {
        let low = AttributeLevelCurve.hexDisplayValue(level: 12, progress: 0.5)
        let mid = AttributeLevelCurve.hexDisplayValue(level: 50, progress: 0)
        let softCap = AttributeLevelCurve.hexDisplayValue(level: 100, progress: 0)
        let prestige = AttributeLevelCurve.hexDisplayValue(level: 150, progress: 0)

        XCTAssertLessThan(low, 20)
        XCTAssertGreaterThan(mid, low)
        XCTAssertGreaterThan(softCap, 90)
        XCTAssertGreaterThan(prestige, softCap)
        XCTAssertLessThan(prestige, 100)
        XCTAssertEqual(AttributeLevelCurve.hexPrestigeGlow(level: 100, progress: 0), 0, accuracy: 0.001)
        XCTAssertGreaterThan(AttributeLevelCurve.hexPrestigeGlow(level: 150, progress: 0), 0)
    }

    func testRewardBarsExposeCurrentLevelDenominators() {
        let xp = XPReward(
            total: 25,
            previousLevel: 4,
            newLevel: 4,
            previousProgress: 0.2,
            newProgress: 0.4,
            previousXP: 820,
            currentXP: 845,
            levelFloorXP: 800,
            nextLevelXP: 900,
            breakdown: []
        )

        XCTAssertEqual(xp.xpIntoCurrentLevel, 45, accuracy: 0.001)
        XCTAssertEqual(xp.xpNeededForCurrentLevel, 100, accuracy: 0.001)
        XCTAssertEqual(xp.xpRemainingInLevel, 55, accuracy: 0.001)

        let attribute = AttributeDeltaReward(
            key: .power,
            xpGained: 20,
            previousXP: AttributeLevelCurve.xpRequired(forLevel: 4) + 15,
            currentXP: AttributeLevelCurve.xpRequired(forLevel: 4) + 35,
            previousLevel: 4,
            currentLevel: 4,
            previousProgress: 0.15,
            currentProgress: 0.35,
            previous: 24,
            current: 25,
            previousTier: .novice,
            currentTier: .novice
        )

        XCTAssertEqual(attribute.xpIntoCurrentLevel, 35, accuracy: 0.001)
        XCTAssertEqual(attribute.levelProgressStart, attribute.previousProgress, accuracy: 0.001)
        XCTAssertFalse(attribute.didIncreaseLevel)
    }

    func testSkillXPDoesNotPretendAccountLevelBarMoved() {
        let now = Date()
        let log = PerformanceLog(
            id: "skill-xp-only",
            userId: "u-skill-xp",
            source: .skill,
            title: "Skill Proof",
            startedAt: now.addingTimeInterval(-60),
            completedAt: now,
            blocks: []
        )
        let reward = RewardSummary(
            progression: ProgressionReceipt(skillXPGained: 25)
        )

        let sequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            rewardSummary: reward,
            fallbackXP: 0,
            sourceName: "Skill"
        )

        XCTAssertEqual(sequence.xp.total, 0)
        XCTAssertEqual(sequence.progression?.skillXPGained, 25)
    }

    func testProgressionReceiptGroupsMovementAPWithBeforeAfterBankProgress() {
        var completion = TrainingCompletionResult()
        completion.movementAPGains = [
            MovementAPGain(
                userId: "u-move",
                sourceLogId: "log-1",
                sourceExerciseId: "set-1",
                movementId: "exercise.bench-press",
                rankStandardMovementId: "exercise.bench-press",
                movementDisplayName: "Bench Press",
                standardDisplayName: "Bench Press",
                rankTemplate: .barbellStrength,
                rawAP: 9,
                reps: 5,
                loadKg: 100,
                occurredAt: Date(timeIntervalSince1970: 10)
            ),
            MovementAPGain(
                userId: "u-move",
                sourceLogId: "log-1",
                sourceExerciseId: "set-2",
                movementId: "exercise.bench-press",
                rankStandardMovementId: "exercise.bench-press",
                movementDisplayName: "Bench Press",
                standardDisplayName: "Bench Press",
                rankTemplate: .barbellStrength,
                rawAP: 6,
                reps: 4,
                loadKg: 100,
                occurredAt: Date(timeIntervalSince1970: 20)
            )
        ]
        completion.movementProgressStates = [
            MovementProgressState(
                userId: "u-move",
                rankStandardMovementId: "exercise.bench-press",
                displayName: "Bench Press",
                rankTemplate: .barbellStrength,
                totalAP: 40,
                lastGainedAP: 15,
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ]

        let line = completion.progressionReceipt.movementLines.first

        XCTAssertEqual(line?.id, "exercise.bench-press")
        XCTAssertEqual(line?.apGained ?? 0, 15, accuracy: 0.001)
        XCTAssertEqual(line?.totalAPBefore ?? 0, 25, accuracy: 0.001)
        XCTAssertEqual(line?.totalAPAfter ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(line?.progressBefore ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(line?.progressAfter ?? 0, 0.40, accuracy: 0.001)
        XCTAssertEqual(line?.apIntoCurrentCheckpoint ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(line?.apNeededForCurrentCheckpoint ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(line?.apRemainingToCheckpoint ?? 0, 60, accuracy: 0.001)
        XCTAssertFalse(line?.didAdvanceCheckpoint ?? true)
    }

    func testOverallLevelRewardStartsAtDisplayedLevelOneWithRealFirstBarScale() {
        let now = Date()
        let log = PerformanceLog(
            id: "overall-log-1",
            userId: "u-overall",
            source: .custom,
            title: "Overall Proof",
            startedAt: now.addingTimeInterval(-60),
            completedAt: now,
            blocks: []
        )
        var completion = TrainingCompletionResult()
        completion.overallLevelXPGained = 27
        completion.overallLevelReward = OverallLevelReward(
            xpGained: 27,
            noveltyMultiplier: 1,
            previousXP: 0,
            currentXP: 27,
            previousLevel: 0,
            currentLevel: 0,
            previousProgressToNextLevel: 0,
            currentProgressToNextLevel: OverallLevelCurve.progressFraction(forXP: 27)
        )

        let sequence = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: completion,
            fallbackXP: 27,
            sourceName: "Custom"
        )

        XCTAssertEqual(sequence.xp.newLevel, 1)
        XCTAssertEqual(sequence.xp.currentXP, 27, accuracy: 0.001)
        XCTAssertEqual(sequence.xp.levelFloorXP, 0, accuracy: 0.001)
        XCTAssertEqual(sequence.xp.nextLevelXP, OverallLevelCurve.xpRequired(forLevel: 1), accuracy: 0.001)
    }

    func testEveryLiveSkillNodeHasAllSkillTiers() {
        var failures: [String] = []

        for node in SkillGraph.shared.nodes.sorted(by: { $0.id < $1.id }) {
            let tiers = node.tierCriteria
            if tiers.count != SkillTier.allCases.count {
                failures.append("\(node.id): \(tiers.count)/\(SkillTier.allCases.count)")
                continue
            }

            let missing = SkillTier.allCases.filter { tiers[$0] == nil }
            if !missing.isEmpty {
                failures.append("\(node.id): missing \(missing.map(\.displayName).joined(separator: ", "))")
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Live skill nodes missing rank criteria:\n" + failures.joined(separator: "\n")
        )
    }

    func testEnduranceIsNotAVisibleSkillTreeBranch() {
        XCTAssertEqual(SkillDisplayTree.allCases.count, 6)
        XCTAssertNil(SkillDisplayTree.containing(.conditioning))
        XCTAssertFalse(SkillGraph.shared.nodes.contains { $0.cluster == .conditioning })
    }

    func testEveryLivePrerequisiteHasAnUnlockStandard() {
        let graph = SkillGraph.shared
        var failures: [String] = []

        for node in graph.nodes {
            let groups = SkillUnlockStandards.groups(for: node, in: graph)
            if groups.count != node.prereqs.count {
                failures.append("\(node.id): \(groups.count) standards for \(node.prereqs.count) prerequisite groups")
            }

            for group in groups {
                if group.requirements.isEmpty {
                    failures.append("\(node.id): empty unlock requirement group")
                }

                for requirement in group.requirements {
                    if graph.node(id: requirement.sourceSkillId) == nil {
                        failures.append("\(node.id): unresolved unlock source \(requirement.sourceSkillId)")
                    }
                    if requirement.requiredTier < .forged {
                        failures.append("\(node.id): \(requirement.sourceSkillId) unlocks before ownership at \(requirement.requiredTier.displayName)")
                    }
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Live prerequisite edges without usable unlock standards:\n" + failures.joined(separator: "\n")
        )
    }

    func testHardSkillUnlockStandardsRequireRepeatableOwnership() {
        let graph = SkillGraph.shared

        let strictMuscleUp = try! XCTUnwrap(graph.node(id: "pp.strict-muscle-up"))
        let strictRequirements = SkillUnlockStandards.groups(for: strictMuscleUp, in: graph).flatMap(\.requirements)
        XCTAssertTrue(strictRequirements.contains {
            $0.sourceSkillId == "pp.ring-muscle-up" && $0.requiredTier >= .master
        })

        let oneArmHandstand = try! XCTUnwrap(graph.node(id: "oah.full-one-arm-handstand"))
        let oahRequirements = SkillUnlockStandards.groups(for: oneArmHandstand, in: graph).flatMap(\.requirements)
        XCTAssertTrue(oahRequirements.contains {
            $0.sourceSkillId == "oah.one-arm-handstand-5s" && $0.requiredTier >= .master
        })
    }

    func testOutgoingUnlocksExposeSkillToSkillPath() {
        let graph = SkillGraph.shared

        let wallPlankUnlocks = SkillUnlockStandards.outgoingUnlocks(from: "hs.wall-plank", in: graph)
        XCTAssertTrue(wallPlankUnlocks.contains {
            $0.child.id == "hs.wall-handstand-30" && $0.requirement.requiredTier == .forged
        })

        let ringMuscleUpUnlocks = SkillUnlockStandards.outgoingUnlocks(from: "pp.ring-muscle-up", in: graph)
        XCTAssertTrue(ringMuscleUpUnlocks.contains {
            $0.child.id == "pp.strict-muscle-up" && $0.requirement.requiredTier >= .master
        })
    }

    func testExerciseBodyweightRatioOnlyUsesMatchingExerciseLoad() {
        let history = [
            exercise("weighted pullup", weightKg: 10, reps: 1),
            exercise("back squat", weightKg: 120, reps: 5),
        ]

        XCTAssertFalse(
            TierCriterionEvaluator.satisfied(
                criterion: .exerciseBodyweightRatio(0.5, exerciseName: "weighted pullup"),
                history: history,
                bodyweightKg: 80
            ),
            "A heavy unrelated lift must not satisfy a weighted-pullup ratio."
        )

        XCTAssertTrue(
            TierCriterionEvaluator.satisfied(
                criterion: .exerciseBodyweightRatio(0.1, exerciseName: "weighted pullup"),
                history: history,
                bodyweightKg: 80
            )
        )
    }

    @MainActor
    func testWeightedPullupTierDoesNotUnlockFromUnrelatedHeavyLift() {
        let skill = SkillGraph.shared.nodes.first { $0.id == "pp.weighted-pullup" }
        let history = [
            exercise("weighted pullup", weightKg: 10, reps: 1),
            exercise("back squat", weightKg: 120, reps: 5),
        ]

        XCTAssertEqual(
            RankService.shared.computeTier(skill: try XCTUnwrap(skill), history: history, bodyweightKg: 80),
            .novice
        )
    }

    private func exercise(_ name: String, weightKg: Double?, reps: Int) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: name,
            plannedSets: 1,
            plannedReps: "\(reps)",
            sets: [
                SetLog(
                    id: UUID().uuidString,
                    setNumber: 1,
                    weightKg: weightKg,
                    reps: reps,
                    rpe: nil,
                    isWarmup: false
                )
            ],
            skipped: false,
            notes: nil
        )
    }
}

final class AnalyticsServiceTests: XCTestCase {
    func testTrackCallsBackendWithEventNameAndMergedSuperProperties() {
        let backend = InMemoryAnalyticsBackend()
        let service = AnalyticsService(backend: backend)

        service.registerSuper(["isSubscribed": true, "source": "super"])
        service.track(.workoutStarted(programId: "program-1", dayNumber: 2))

        XCTAssertEqual(backend.events.count, 1)
        XCTAssertEqual(backend.events.first?.name, "workout_started")
        XCTAssertEqual(backend.events.first?.properties["program_id"] as? String, "program-1")
        XCTAssertEqual(backend.events.first?.properties["day_number"] as? Int, 2)
        XCTAssertEqual(backend.events.first?.properties["isSubscribed"] as? Bool, true)
        XCTAssertEqual(backend.events.first?.properties["source"] as? String, "super")
    }

    func testConfigureDefaultsAreIncludedInTrackedEvents() {
        let backend = InMemoryAnalyticsBackend()
        let service = AnalyticsService(backend: backend)

        service.configure(defaultProperties: ["appVersion": "1.0", "build": "42"])
        service.track(.appOpened)

        XCTAssertEqual(backend.configuredProperties["appVersion"] as? String, "1.0")
        XCTAssertEqual(backend.events.first?.properties["appVersion"] as? String, "1.0")
        XCTAssertEqual(backend.events.first?.properties["build"] as? String, "42")
    }

    func testIdentifyAndResetForwardToBackend() {
        let backend = InMemoryAnalyticsBackend()
        let service = AnalyticsService(backend: backend)

        service.identify(userId: "user-1", traits: ["email": "test@example.com"])
        XCTAssertEqual(backend.identifiedUserId, "user-1")
        XCTAssertEqual(backend.identifyTraits["email"] as? String, "test@example.com")

        service.reset()
        XCTAssertNil(backend.identifiedUserId)
        XCTAssertEqual(backend.resetCount, 1)
    }

    func testOptOutHaltsSubsequentTrackCalls() {
        let backend = InMemoryAnalyticsBackend()
        let service = AnalyticsService(backend: backend)

        service.track(.appOpened)
        service.optOut()
        service.track(.tabSelected(tab: "home"))

        XCTAssertEqual(backend.events.map(\.name), ["app_opened"])
        XCTAssertTrue(backend.isOptedOut)
        XCTAssertEqual(backend.optOutCount, 1)
    }

    func testOptInResumesTrackCallsAfterOptOut() {
        let backend = InMemoryAnalyticsBackend()
        let service = AnalyticsService(backend: backend)

        service.optOut()
        service.track(.tabSelected(tab: "home"))
        service.optIn()
        service.track(.tabSelected(tab: "profile"))

        XCTAssertEqual(backend.events.map(\.name), ["tab_selected"])
        XCTAssertEqual(backend.events.first?.properties["tab"] as? String, "profile")
        XCTAssertEqual(backend.optInCount, 1)
    }
}

@MainActor
final class AuthViewModelDevEntitlementTests: XCTestCase {
    private final class UserServiceStub: UserServiceProtocol, @unchecked Sendable {
        var createdUserIds: [String] = []

        func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
            createdUserIds.append(userId)
            return UserProfile(
                id: userId,
                email: email,
                createdAt: Date(),
                onboardingCompleted: true,
                totalScans: 0
            )
        }

        func fetchProfile(userId: String) async throws -> UserProfile {
            UserProfile(id: userId, createdAt: Date(), onboardingCompleted: true, totalScans: 0)
        }

        func updateProfile(userId: String, fields: [String: Any]) async throws {}
        func deleteUserData(userId: String) async throws {}
    }

    func testEmailSignInUnlocksDevEntitlementInDebug() async {
        DevFlags.shared.unlockAllFeatures = false
        defer { DevFlags.shared.unlockAllFeatures = false }

        let viewModel = AuthViewModel(
            auth: MockAuthService(),
            user: UserServiceStub(),
            analytics: AnalyticsService(backend: InMemoryAnalyticsBackend())
        )
        viewModel.email = "dev@example.com"
        viewModel.password = "password"

        await viewModel.signInWithEmail()

        #if DEBUG
        XCTAssertTrue(DevFlags.shared.unlockAllFeatures)
        #else
        XCTAssertFalse(DevFlags.shared.unlockAllFeatures)
        #endif
    }

    func testAppleSignInUnlocksDevEntitlementInDebug() async {
        DevFlags.shared.unlockAllFeatures = false
        defer { DevFlags.shared.unlockAllFeatures = false }

        let viewModel = AuthViewModel(
            auth: MockAuthService(),
            user: UserServiceStub(),
            analytics: AnalyticsService(backend: InMemoryAnalyticsBackend())
        )

        await viewModel.signInWithApple()

        #if DEBUG
        XCTAssertTrue(DevFlags.shared.unlockAllFeatures)
        #else
        XCTAssertFalse(DevFlags.shared.unlockAllFeatures)
        #endif
    }
}
