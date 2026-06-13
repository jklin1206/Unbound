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
        UserDefaults.standard.set(TrainingWeightUnit.kilograms.rawValue, forKey: WeightPlatePolicy.unitDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: WeightPlatePolicy.unitDefaultsKey) }

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

        XCTAssertNil(OverallRankTrialDefinitions.nextTrial(after: .unbound))
    }
}

// MARK: - Task 3: Per-option floor overrides

extension OverallRankTrialServiceTests {

    // Lightweight factory: builds a TrialStation directly without going through
    // the full Definitions builder so tests stay isolated from catalog availability.
    private func makeTestStation(
        id: String = "t-pull",
        category: TrialMovementCategory = .pull,
        movementId: String = "exercise.pullup",
        metric: TrainingMetricKind = .reps,
        minimumValue: Int = 12,
        movementOptions: [TrialMovementOption] = []
    ) -> TrialStation {
        let standard = OverallRankTrialPerformanceStandard(
            movementId: movementId,
            displayName: movementId,
            metric: metric,
            minimumValue: minimumValue
        )
        return TrialStation(
            id: id,
            title: id,
            category: category,
            standard: standard,
            capSeconds: nil,
            loadPercentOfBodyweight: nil,
            movementOptions: movementOptions.isEmpty
                ? [TrialMovementOption(movementId: movementId)]
                : movementOptions,
            restRule: "Clean reps only.",
            qualityFlags: [.clean]
        )
    }

    func testPerOptionFloorOverridesStationMinimum() {
        let station = makeTestStation(
            id: "t-pull",
            category: .pull,
            movementId: "exercise.pullup",
            metric: .reps,
            minimumValue: 12,
            movementOptions: [
                TrialMovementOption(movementId: "exercise.pullup"),
                TrialMovementOption(movementId: "exercise.inverted-row", floorOverride: 18)
            ]
        )
        XCTAssertEqual(station.resolvedMinimum(forMovementId: "exercise.pullup"), 12,
            "Primary option should use station minimum when no floorOverride")
        XCTAssertEqual(station.resolvedMinimum(forMovementId: "exercise.inverted-row"), 18,
            "Override option should use floorOverride value")
        XCTAssertEqual(station.resolvedMinimum(forMovementId: "exercise.unknown"), 12,
            "Unknown movement falls back to station minimum")
    }

    func testFloorOverrideIsUsedDuringEvaluation() throws {
        // Station: pullup floor 3, inverted-row override 6.
        // Logging 5 inverted-rows must FAIL (5 < 6) and 6 inverted-rows must PASS.
        let station = makeTestStation(
            id: "t-eval-floor",
            category: .pull,
            movementId: "exercise.pullup",
            metric: .reps,
            minimumValue: 3,
            movementOptions: [
                TrialMovementOption(movementId: "exercise.pullup"),
                TrialMovementOption(movementId: "exercise.inverted-row", floorOverride: 6)
            ]
        )

        func makeLog(reps: Int, movementId: String) -> PerformanceLog {
            let exercise = PerformanceExercise(
                name: movementId,
                movementId: movementId,
                plannedSets: 1,
                plannedTarget: "\(reps) reps",
                sets: [PerformanceSet(setNumber: 1, reps: reps)]
            )
            // Block title must match station title for evaluateDetailed to route blocks correctly.
            let block = PerformanceBlock(
                kind: .bodyweight,
                title: "t-eval-floor",
                exercises: [exercise]
            )
            return PerformanceLog(
                userId: "u1",
                source: .overallRankTrial,
                title: "Test Gate",
                startedAt: Date(timeIntervalSince1970: 0),
                completedAt: Date(timeIntervalSince1970: 60),
                programId: "test-gate",
                blocks: [block]
            )
        }

        // Build a minimal definition that contains only our test station.
        let testDef = OverallRankTrialDefinition(
            id: "test-gate",
            targetRank: .novice,
            displayName: "Test Gate",
            subtitle: "test",
            estimatedMinutes: 5,
            format: .firstLight,
            minOverallLevel: 1,
            requiredEquipment: [.bodyweight],
            performanceStandards: [station.standard],
            loadoutVariants: [
                TrialLoadoutVariant(
                    loadout: .homeKit,
                    requiredEquipment: [.bodyweight],
                    promise: "test",
                    stations: [station]
                )
            ]
        )

        let failLog = makeLog(reps: 5, movementId: "exercise.inverted-row")
        let passLog = makeLog(reps: 6, movementId: "exercise.inverted-row")

        let failEval = OverallRankTrialRunner.shared.evaluateDetailed(failLog, against: testDef)
        let passEval = OverallRankTrialRunner.shared.evaluateDetailed(passLog, against: testDef)

        XCTAssertFalse(failEval.passed,
            "5 inverted-rows should fail when floorOverride is 6")
        XCTAssertTrue(passEval.passed,
            "6 inverted-rows should pass when floorOverride is 6")
    }
}
