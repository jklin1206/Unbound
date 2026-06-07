import XCTest
@testable import UNBOUND

extension OverallRankTrialServiceTests {
    func testResolverChoosesCleanOfficialLoadoutsForNoGymHomeAndGymUsers() throws {
        let definition = OverallRankTrialDefinitions.forge

        let noGym = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: "u1",
            equipment: [.bodyweight, .openSpace, .pullupBar]
        )
        let home = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: "u1",
            equipment: [.bodyweight, .openSpace, .dumbbell, .band]
        )
        let gym = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: "u1",
            equipment: readyEquipment()
        )

        XCTAssertEqual(try XCTUnwrap(noGym.resolvedTrial).selectedLoadout, .noGymField)
        XCTAssertEqual(try XCTUnwrap(home.resolvedTrial).selectedLoadout, .homeKit)
        XCTAssertEqual(try XCTUnwrap(gym.resolvedTrial).selectedLoadout, .gymHybrid)
        XCTAssertTrue(noGym.blockers.isEmpty)
        XCTAssertTrue(home.blockers.isEmpty)
        XCTAssertTrue(gym.blockers.isEmpty)
    }

    func testMissingPullSolutionBlocksApprenticePlus() {
        let definition = OverallRankTrialDefinitions.calibration
        let resolution = RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: "u1",
            equipment: [.bodyweight, .openSpace]
        )

        XCTAssertEqual(resolution.resolvedTrial?.selectedLoadout, .noGymField)
        XCTAssertFalse(resolution.isReady)
        XCTAssertTrue(resolution.blockers.contains { $0.id == "pull-solution" })
    }

    func testGymHybridDefinitionsAvoidMandatorySledBoxJumpAndNicheGates() {
        let bannedMovementFragments = ["5k", "planche", "one-arm", "one_arm", "muscle-up", "muscleup", "sled", "box-jump"]

        for definition in OverallRankTrialDefinitions.all {
            let gym = definition.loadoutVariants.first { $0.loadout == .gymHybrid }
            let stations = gym?.stations ?? []
            let allOptions = stations.flatMap(\.movementOptions)
            let requiredEquipment = allOptions.reduce(into: Set<MovementEquipment>()) { result, option in
                result.formUnion(option.requiredEquipment)
            }
            let movementIds = allOptions.map(\.movementId)

            XCTAssertFalse(requiredEquipment.contains(.sled), definition.displayName)
            XCTAssertFalse(requiredEquipment.contains(.box), definition.displayName)
            for fragment in bannedMovementFragments {
                XCTAssertFalse(
                    movementIds.contains { $0.localizedCaseInsensitiveContains(fragment) },
                    "\(definition.displayName) should not include \(fragment)"
                )
            }
        }
    }

    func testDetailedEvaluationFailsSkippedStationDespiteOtherOverperformance() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        var log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )

        log.blocks.removeFirst()
        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(log, against: definition)

        XCTAssertFalse(evaluation.passed)
        XCTAssertEqual(evaluation.failedStation?.status, .missing)
        XCTAssertEqual(evaluation.failedStation?.id, resolved.stations.first?.id)
    }

    func testDetailedEvaluationFailsPainAndFormBreakFlags() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        let cleanLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )
        var painLog = cleanLog
        var formBreakLog = cleanLog
        painLog.blocks[0].exercises[0].sets[0].qualityFlags = [.pain]
        formBreakLog.blocks[1].exercises[0].sets[0].qualityFlags = [.formBreak]

        let painEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(painLog, against: definition)
        let formBreakEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(formBreakLog, against: definition)

        XCTAssertFalse(painEvaluation.passed)
        XCTAssertEqual(painEvaluation.failedStation?.failedQualityFlags, Set([.pain]))
        XCTAssertFalse(formBreakEvaluation.passed)
        XCTAssertEqual(formBreakEvaluation.failedStation?.failedQualityFlags, Set([.formBreak]))
    }

    func testDetailedEvaluationReportsLoadPercentBodyweightBlockerWhenEnforced() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        var log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )

        let missingBodyweightEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log,
            against: definition,
            enforceLoadPercent: true
        )
        XCTAssertFalse(missingBodyweightEvaluation.passed)
        XCTAssertEqual(
            missingBodyweightEvaluation.failedStation?.failureReason,
            "Bodyweight is required for the load standard."
        )

        var lowLoadLog = log
        for blockIndex in lowLoadLog.blocks.indices where lowLoadLog.blocks[blockIndex].kind == .carry {
            for exerciseIndex in lowLoadLog.blocks[blockIndex].exercises.indices {
                for setIndex in lowLoadLog.blocks[blockIndex].exercises[exerciseIndex].sets.indices {
                    lowLoadLog.blocks[blockIndex].exercises[exerciseIndex].sets[setIndex].weightKg = 5
                }
            }
        }
        let lowLoadEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            lowLoadLog,
            against: definition,
            bodyweightKg: 100,
            enforceLoadPercent: true
        )
        XCTAssertFalse(lowLoadEvaluation.passed)
        XCTAssertEqual(
            lowLoadEvaluation.failedStation?.failureReason,
            "Logged load missed the bodyweight percentage standard."
        )

        for blockIndex in log.blocks.indices where log.blocks[blockIndex].kind == .carry {
            for exerciseIndex in log.blocks[blockIndex].exercises.indices {
                for setIndex in log.blocks[blockIndex].exercises[exerciseIndex].sets.indices {
                    log.blocks[blockIndex].exercises[exerciseIndex].sets[setIndex].weightKg = 25
                }
            }
        }
        XCTAssertTrue(
            OverallRankTrialRunner.shared.evaluateDetailed(
                log,
                against: definition,
                bodyweightKg: 100,
                enforceLoadPercent: true
            ).passed
        )
    }

    func testDetailedEvaluationFailsTrialTimeCap() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 100 + Double(definition.estimatedMinutes * 60 + 1)),
            passing: true
        )

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(log, against: definition)

        XCTAssertFalse(evaluation.passed)
        XCTAssertEqual(evaluation.failedStation?.id, "trial-time-cap")
        XCTAssertEqual(evaluation.failedStation?.failureReason, "Trial exceeded the official time cap.")
    }

    func testDetailedEvaluationFailsStationTimeCapFromPerformanceBlockDuration() throws {
        let definition = OverallRankTrialDefinitions.gauntlet
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        var log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )
        let cappedBlockIndex = try XCTUnwrap(log.blocks.firstIndex { $0.title == "Floor 10 Boss Hold" })
        log.blocks[cappedBlockIndex].durationSeconds = (5 * 60) + 1

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(log, against: definition)

        XCTAssertFalse(evaluation.passed)
        XCTAssertEqual(evaluation.failedStation?.id, "tower-floor-10")
        XCTAssertEqual(evaluation.failedStation?.failureReason, "Station exceeded the official time cap.")
    }

    func testRecordCompletedAttemptStoresOfficialLoadoutAndEvaluation() throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .novice, attempts: []),
            userId: "u1"
        )
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )

        let completed = OverallRankTrialRunner.shared.recordCompletedAttempt(
            performanceLog: log,
            completionResult: TrainingCompletionResult(),
            store: store,
            bodyweightKg: 100
        )
        let result = try XCTUnwrap(completed)

        XCTAssertTrue(result.attempt.passed)
        XCTAssertEqual(result.attempt.loadout, .homeKit)
        XCTAssertEqual(result.attempt.resolvedTrialId, "\(definition.id).homeKit")
        XCTAssertTrue(result.evaluation.passed)
        XCTAssertEqual(result.attempt.evaluation?.stationResults.count, resolved.stations.count)
        XCTAssertEqual(store.load(userId: "u1").attempts.first?.loadout, .homeKit)
    }

    func testRecordCompletedAttemptEnforcesLoadPercentInProductionPath() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )

        let completed = OverallRankTrialRunner.shared.recordCompletedAttempt(
            performanceLog: log,
            completionResult: TrainingCompletionResult(),
            store: store
        )
        let result = try XCTUnwrap(completed)

        XCTAssertFalse(result.attempt.passed)
        XCTAssertEqual(result.evaluation.failedStation?.failureReason, "Bodyweight is required for the load standard.")
    }

    func testActiveWorkoutSessionCarriesRankTrialLoadoutNotesAndQualityFlagsIntoPerformanceLog() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        let session = ActiveWorkoutSession(trainingDraft: draft)

        session.confirmAsPlanned(exerciseIndex: 0, setIndex: 0)
        session.toggleQualityFlag(.pain, exerciseIndex: 0, setIndex: 0)
        let log = session.assemblePerformanceLog(userId: "u1")

        XCTAssertEqual(log.blocks.first?.exercises.first?.notes, "Home Kit rank trial station: Engine")
        XCTAssertEqual(log.blocks.first?.exercises.first?.sets.first?.qualityFlags, Set([.pain]))
    }

    func testActiveWorkoutSessionCarriesRankTrialStationDurationIntoPerformanceLog() throws {
        let definition = OverallRankTrialDefinitions.gauntlet
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )
        let session = ActiveWorkoutSession(trainingDraft: draft)
        let started = Date(timeIntervalSince1970: 200)

        for setIndex in session.exercises[0].sets.indices {
            session.confirmAsPlanned(exerciseIndex: 0, setIndex: setIndex)
        }
        session.exercises[0].startedAt = started
        session.exercises[0].completedAt = started.addingTimeInterval(301)
        let log = session.assemblePerformanceLog(userId: "u1")

        XCTAssertEqual(log.blocks.first?.title, "Floor 1 Engine")
        XCTAssertEqual(log.blocks.first?.durationSeconds, 301)
    }

    func testRankTrialDraftDisplaysAndPrefillsBodyweightLoadStandards() throws {
        let definition = OverallRankTrialDefinitions.gauntlet
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved,
            bodyweightKg: 100
        )

        let carryPrescription = try XCTUnwrap(
            draft.blocks.flatMap(\.prescriptions).first { $0.loadPercentOfBodyweight != nil }
        )
        XCTAssertEqual(carryPrescription.displayTargetText, "100m @ 25 kg (25% BW)")
        XCTAssertEqual(carryPrescription.suggestedWeightKg, 25)
        XCTAssertTrue(draft.blocks.contains { $0.subtitle?.contains("100m @ 25 kg (25% BW)") == true })

        let session = ActiveWorkoutSession(trainingDraft: draft)
        let carryExercise = try XCTUnwrap(session.exercises.first { $0.id == carryPrescription.id })
        XCTAssertEqual(carryExercise.plannedReps, "100m @ 25 kg (25% BW)")
        XCTAssertEqual(carryExercise.sets.first?.suggestedWeightKg, 25)
    }

    func testRestoredRankTrialSessionKeepsOfficialSourceForAttemptRecording() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved,
            bodyweightKg: 100
        )
        let session = ActiveWorkoutSession(trainingDraft: draft)

        let data = try JSONEncoder().encode(session.snapshot())
        let snapshot = try JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        let restored = ActiveWorkoutSession(snapshot: snapshot)
        let log = restored.assemblePerformanceLog(userId: "u1")
        let result = OverallRankTrialRunner.shared.recordCompletedAttempt(
            performanceLog: log,
            completionResult: TrainingCompletionResult(),
            store: store,
            bodyweightKg: 100
        )

        XCTAssertEqual(restored.source, .overallRankTrial)
        XCTAssertEqual(log.source, .overallRankTrial)
        XCTAssertNotNil(result)
    }

    func testAllOverallRankTrialDefinitionsAreCatalogBackedAndReachable() {
        XCTAssertEqual(OverallRankTrialDefinitions.all.map(\.id), allRankTrialCases.map(\.definition.id))

        for trialCase in allRankTrialCases {
            assertCatalogBacked(trialCase.definition)
            XCTAssertEqual(
                OverallRankTrialDefinitions.nextTrial(after: trialCase.sourceRank)?.id,
                trialCase.definition.id,
                trialCase.definition.displayName
            )
        }

        XCTAssertNil(OverallRankTrialDefinitions.nextTrial(after: .ascendant))
    }

}
