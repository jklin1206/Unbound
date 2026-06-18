import XCTest
@testable import UNBOUND

extension OverallRankTrialServiceTests {
    func testResolverChoosesCleanOfficialLoadoutsForNoGymHomeAndGymUsers() throws {
        let definition = OverallRankTrialDefinitions.theForging

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
        let definition = OverallRankTrialDefinitions.theCount
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

    func testUnscoredStationDoesNotBlockTheVerdict() throws {
        // Gate III's "Stoke the Fire" is an unscored warm-up. Even if it is failed
        // (or missing), the trial still passes when every scored station passes.
        let definition = OverallRankTrialDefinitions.theForging
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved,
            bodyweightKg: 80
        )
        var log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )

        // Zero out the engine (stoke) block's logged distance so the unscored
        // station fails, leaving every scored strike/carry intact.
        for blockIndex in log.blocks.indices where log.blocks[blockIndex].kind == .cardio {
            for exerciseIndex in log.blocks[blockIndex].exercises.indices {
                for setIndex in log.blocks[blockIndex].exercises[exerciseIndex].sets.indices {
                    log.blocks[blockIndex].exercises[exerciseIndex].sets[setIndex].distanceMeters = 0
                }
            }
        }

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log,
            against: definition,
            bodyweightKg: 80,
            enforceLoadPercent: true
        )

        XCTAssertTrue(evaluation.passed, "An unscored station failing must not fail the trial")
        XCTAssertNil(evaluation.failedStation, "Unscored stations are excluded from failedStation")
        let stoke = try XCTUnwrap(evaluation.stationResults.first { $0.id == "forging-stoke" })
        XCTAssertFalse(stoke.isScored)
        XCTAssertNotEqual(stoke.status, .passed, "The stoke was deliberately degraded")
    }

    func testDetailedEvaluationFailsSkippedStationDespiteOtherOverperformance() throws {
        let definition = OverallRankTrialDefinitions.theCount
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
        let definition = OverallRankTrialDefinitions.theCount
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
        let definition = OverallRankTrialDefinitions.theCount
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

    func testLoadPercentRequiresLoadAndMetricInTheSameSet() {
        let standard = OverallRankTrialPerformanceStandard(
            movementId: "carry.farmer-carry",
            displayName: "Farmer Carry",
            metric: .distanceMeters,
            minimumValue: 60,
            minimumQualifyingSets: 1,
            plannedSets: 1
        )
        let station = TrialStation(
            id: "test-load-carry",
            title: "Loaded Carry",
            category: .carryCore,
            standard: standard,
            capSeconds: nil,
            loadPercentOfBodyweight: 0.30,
            movementOptions: [TrialMovementOption(movementId: "carry.farmer-carry")],
            restRule: "test",
            qualityFlags: [.clean]
        )
        let definition = OverallRankTrialDefinition(
            id: "test-load-percent-gate",
            targetRank: .apprentice,
            displayName: "Load Percent Gate",
            subtitle: "test",
            estimatedMinutes: 10,
            format: .theCount,
            minOverallLevel: 1,
            requiredEquipment: [.dumbbell, .openSpace],
            performanceStandards: [standard],
            loadoutVariants: [
                TrialLoadoutVariant(
                    loadout: .homeKit,
                    requiredEquipment: [.dumbbell, .openSpace],
                    promise: "test",
                    stations: [station]
                )
            ]
        )

        func log(with sets: [PerformanceSet]) -> PerformanceLog {
            PerformanceLog(
                userId: "u1",
                source: .overallRankTrial,
                title: "Load Percent Gate",
                startedAt: Date(timeIntervalSince1970: 0),
                completedAt: Date(timeIntervalSince1970: 60),
                programId: definition.id,
                blocks: [
                    PerformanceBlock(
                        kind: .carry,
                        title: "Loaded Carry",
                        exercises: [
                            PerformanceExercise(
                                name: "Farmer Carry",
                                movementId: "carry.farmer-carry",
                                plannedSets: 1,
                                plannedTarget: "60m",
                                sets: sets
                            )
                        ]
                    )
                ]
            )
        }

        let splitSetEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log(with: [
                PerformanceSet(setNumber: 1, weightKg: 30, distanceMeters: 1),
                PerformanceSet(setNumber: 2, weightKg: 5, distanceMeters: 60)
            ]),
            against: definition,
            bodyweightKg: 100,
            enforceLoadPercent: true
        )
        XCTAssertFalse(splitSetEvaluation.passed)
        XCTAssertEqual(
            splitSetEvaluation.failedStation?.failureReason,
            "Logged load missed the bodyweight percentage standard."
        )

        let sameSetEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log(with: [PerformanceSet(setNumber: 1, weightKg: 30, distanceMeters: 60)]),
            against: definition,
            bodyweightKg: 100,
            enforceLoadPercent: true
        )
        XCTAssertTrue(sameSetEvaluation.passed)
    }

    func testTheForgingDoesNotEnforceOverallTimeCap() throws {
        let definition = OverallRankTrialDefinitions.theForging
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved,
            bodyweightKg: 80
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 100 + Double(definition.estimatedMinutes * 60 + 600)),
            passing: true
        )

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log,
            against: definition,
            bodyweightKg: 80
        )

        XCTAssertFalse(definition.enforcesTotalTimeCap)
        XCTAssertTrue(evaluation.passed)
        XCTAssertFalse(evaluation.stationResults.contains { $0.id == "trial-time-cap" })
    }

    func testDetailedEvaluationFailsTrialTimeCap() throws {
        let definition = OverallRankTrialDefinitions.theCount
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

        XCTAssertTrue(definition.enforcesTotalTimeCap)
        XCTAssertFalse(evaluation.passed)
        XCTAssertEqual(evaluation.failedStation?.id, "trial-time-cap")
        XCTAssertEqual(evaluation.failedStation?.failureReason, "Trial exceeded the official time cap.")
    }

    func testDetailedEvaluationFailsStationTimeCapFromPerformanceBlockDuration() throws {
        let definition = OverallRankTrialDefinitions.theAscent
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
        let cappedBlockIndex = try XCTUnwrap(log.blocks.firstIndex { $0.title == "Floor 10 — The Summit Gate" })
        log.blocks[cappedBlockIndex].durationSeconds = (5 * 60) + 1

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(log, against: definition)

        XCTAssertFalse(evaluation.passed)
        XCTAssertEqual(evaluation.failedStation?.id, "ascent-floor-10")
        XCTAssertEqual(evaluation.failedStation?.failureReason, "Station exceeded the official time cap.")
    }

    func testRecordCompletedAttemptStoresOfficialLoadoutAndEvaluation() throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .novice, attempts: []),
            userId: "u1"
        )
        let definition = OverallRankTrialDefinitions.theCount
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
        let definition = OverallRankTrialDefinitions.theCount
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
        let definition = OverallRankTrialDefinitions.theCount
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
        let definition = OverallRankTrialDefinitions.theAscent
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

        XCTAssertEqual(log.blocks.first?.title, "Floor 1 — The Path")
        XCTAssertEqual(log.blocks.first?.durationSeconds, 301)
    }

    func testRankTrialDraftDisplaysAndPrefillsBodyweightLoadStandards() throws {
        UserDefaults.standard.set(TrainingWeightUnit.kilograms.rawValue, forKey: WeightPlatePolicy.unitDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: WeightPlatePolicy.unitDefaultsKey) }

        let definition = OverallRankTrialDefinitions.theAscent
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
        let definition = OverallRankTrialDefinitions.theCount
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

// MARK: - Task 4: Strength-tier strike floors

extension OverallRankTrialServiceTests {

    private func makeStrikeStation(
        id: String = "t-strike",
        movementId: String = "exercise.barbell-romanian-deadlift",
        reps: Int = 3,
        strengthTier: RankTier
    ) -> TrialStation {
        let standard = OverallRankTrialPerformanceStandard(
            movementId: movementId,
            displayName: movementId,
            metric: .reps,
            minimumValue: reps,
            minimumQualifyingSets: 1,
            plannedSets: 3
        )
        return TrialStation(
            id: id,
            title: id,
            category: .hingePower,
            standard: standard,
            capSeconds: nil,
            loadPercentOfBodyweight: nil,
            strengthTier: strengthTier,
            movementOptions: [TrialMovementOption(movementId: movementId)],
            restRule: "Strike station.",
            qualityFlags: [.clean]
        )
    }

    func testStrikeStationResolvesLoadFloorFromStrengthStandards() {
        // Anchor to the engine — never hardcode the ratio (tests-anchor-to-curve-functions rule).
        let movementId = "exercise.barbell-romanian-deadlift"
        let expectedRatio = StrengthStandards.ratio(exerciseKey: movementId, tier: .forged, sex: nil)
        XCTAssertNotNil(expectedRatio,
            "StrengthStandards must resolve a ratio for barbell-romanian-deadlift at .forged tier")

        let station = makeStrikeStation(movementId: movementId, reps: 3, strengthTier: .forged)
        let bodyweightKg = 80.0
        let resolved = station.resolvedStrikeLoadKg(bodyweightKg: bodyweightKg)

        XCTAssertNotNil(resolved, "resolvedStrikeLoadKg must return a value for a strike station")
        if let ratio = expectedRatio, let resolved = resolved {
            XCTAssertEqual(resolved, ratio * bodyweightKg, accuracy: 0.5)
        }
    }

    func testStrikeStationFailsClosedWhenLoadFloorDoesNotResolve() {
        let movementId = "exercise.plank"
        let station = makeStrikeStation(movementId: movementId, reps: 3, strengthTier: .forged)
        let testDef = OverallRankTrialDefinition(
            id: "test-unresolved-strike-gate",
            targetRank: .forged,
            displayName: "Unresolved Strike Gate",
            subtitle: "test",
            estimatedMinutes: 10,
            format: .theForging,
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
        let log = PerformanceLog(
            userId: "u1",
            source: .overallRankTrial,
            title: "Unresolved Strike Gate",
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 60),
            programId: testDef.id,
            blocks: [
                PerformanceBlock(
                    kind: .bodyweight,
                    title: "t-strike",
                    exercises: [
                        PerformanceExercise(
                            name: "Plank",
                            movementId: movementId,
                            plannedSets: 1,
                            plannedTarget: "3 reps",
                            sets: [PerformanceSet(setNumber: 1, reps: 3, weightKg: 100)]
                        )
                    ]
                )
            ]
        )

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log,
            against: testDef,
            bodyweightKg: 80,
            enforceLoadPercent: false
        )

        XCTAssertFalse(evaluation.passed)
        XCTAssertEqual(
            evaluation.failedStation?.failureReason,
            "Could not resolve the strength-tier load standard."
        )
    }

    func testStrikeStationFailsWhenTopSetBelowLoadFloor() throws {
        let movementId = "exercise.barbell-romanian-deadlift"
        let bodyweightKg = 80.0
        let station = makeStrikeStation(movementId: movementId, reps: 3, strengthTier: .forged)
        let floorKg = try XCTUnwrap(station.resolvedStrikeLoadKg(bodyweightKg: bodyweightKg))

        let testDef = OverallRankTrialDefinition(
            id: "test-strike-gate",
            targetRank: .forged,
            displayName: "Strike Gate",
            subtitle: "test",
            estimatedMinutes: 10,
            format: .theForging,
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

        func makeStrikeLog(reps: Int, weightKg: Double) -> PerformanceLog {
            let exercise = PerformanceExercise(
                name: movementId,
                movementId: movementId,
                plannedSets: 3,
                plannedTarget: "\(reps) reps",
                sets: [PerformanceSet(setNumber: 1, reps: reps, weightKg: weightKg)]
            )
            let block = PerformanceBlock(
                kind: .bodyweight,
                title: "t-strike",
                exercises: [exercise]
            )
            return PerformanceLog(
                userId: "u1",
                source: .overallRankTrial,
                title: "Strike Gate",
                startedAt: Date(timeIntervalSince1970: 0),
                completedAt: Date(timeIntervalSince1970: 60),
                programId: "test-strike-gate",
                blocks: [block]
            )
        }

        // 5kg below floor → fail
        let belowFloorLog = makeStrikeLog(reps: 3, weightKg: floorKg - 5)
        let belowEval = OverallRankTrialRunner.shared.evaluateDetailed(
            belowFloorLog,
            against: testDef,
            bodyweightKg: bodyweightKg,
            enforceLoadPercent: false
        )
        XCTAssertFalse(belowEval.passed,
            "Strike station should fail when top set is below the strength-tier load floor")
        XCTAssertEqual(belowEval.failedStation?.failureReason,
            "Top set did not meet the strength-tier load floor.")

        // At or above floor → pass
        let atFloorLog = makeStrikeLog(reps: 3, weightKg: floorKg)
        let atEval = OverallRankTrialRunner.shared.evaluateDetailed(
            atFloorLog,
            against: testDef,
            bodyweightKg: bodyweightKg,
            enforceLoadPercent: false
        )
        XCTAssertTrue(atEval.passed,
            "Strike station should pass when top set meets the strength-tier load floor")
    }

    func testStrikeStationRequiresRepsAndLoadInTheSameSet() throws {
        let movementId = "exercise.barbell-romanian-deadlift"
        let bodyweightKg = 80.0
        let station = makeStrikeStation(movementId: movementId, reps: 3, strengthTier: .forged)
        let floorKg = try XCTUnwrap(station.resolvedStrikeLoadKg(bodyweightKg: bodyweightKg))

        let testDef = OverallRankTrialDefinition(
            id: "test-strike-gate-conjoined",
            targetRank: .forged,
            displayName: "Strike Gate",
            subtitle: "test",
            estimatedMinutes: 10,
            format: .theForging,
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

        // A heavy 1-rep set plus a light 3-rep set satisfies load and reps in
        // DIFFERENT sets — the strike demands both in ONE set, so this must fail.
        let exercise = PerformanceExercise(
            name: movementId,
            movementId: movementId,
            plannedSets: 3,
            plannedTarget: "3 reps",
            sets: [
                PerformanceSet(setNumber: 1, reps: 1, weightKg: floorKg + 10),
                PerformanceSet(setNumber: 2, reps: 3, weightKg: floorKg - 30)
            ]
        )
        let block = PerformanceBlock(
            kind: .bodyweight,
            title: "t-strike",
            exercises: [exercise]
        )
        let splitLog = PerformanceLog(
            userId: "u1",
            source: .overallRankTrial,
            title: "Strike Gate",
            startedAt: Date(timeIntervalSince1970: 0),
            completedAt: Date(timeIntervalSince1970: 60),
            programId: "test-strike-gate-conjoined",
            blocks: [block]
        )

        let splitEval = OverallRankTrialRunner.shared.evaluateDetailed(
            splitLog,
            against: testDef,
            bodyweightKg: bodyweightKg,
            enforceLoadPercent: false
        )
        XCTAssertFalse(splitEval.passed,
            "Strike must require the rep floor AND the load floor in the same set")
    }
}

// MARK: - Task 5: Dynamic weakest-attribute station resolution

extension OverallRankTrialServiceTests {

    /// Builds a synthetic definition that contains all 6 `lastgate-landing-6-<attribute>`
    /// station variants plus a fixed set of non-dynamic stations, for use in
    /// `resolveDynamicStations` tests before Gate VIII's real definition lands.
    private func syntheticLastGateDefinition() -> OverallRankTrialDefinition {
        var stations: [TrialStation] = []

        // Fixed stations (non-dynamic)
        stations.append(TrialStation(
            id: "lastgate-anchor",
            title: "Anchor Station",
            category: .engine,
            standard: OverallRankTrialPerformanceStandard(
                movementId: "exercise.pullup",
                displayName: "Pull-up",
                metric: .reps,
                minimumValue: 5
            ),
            capSeconds: nil,
            loadPercentOfBodyweight: nil,
            movementOptions: [TrialMovementOption(movementId: "exercise.pullup")],
            restRule: "test",
            qualityFlags: []
        ))

        // One landing-6 station per attribute key
        for key in AttributeKey.allCases {
            stations.append(TrialStation(
                id: "lastgate-landing-6-\(key.rawValue)",
                title: "Landing 6 — \(key.rawValue)",
                category: .mobilityControl,
                standard: OverallRankTrialPerformanceStandard(
                    movementId: "exercise.plank",
                    displayName: "Plank",
                    metric: .holdSeconds,
                    minimumValue: 60
                ),
                capSeconds: nil,
                loadPercentOfBodyweight: nil,
                dynamicGroupKey: "lastgate-landing-6",
                movementOptions: [TrialMovementOption(movementId: "exercise.plank")],
                restRule: "test",
                qualityFlags: []
            ))
        }

        return OverallRankTrialDefinition(
            id: "gate-08-the-last-gate",
            targetRank: .unbound,
            displayName: "The Last Gate",
            subtitle: "test",
            estimatedMinutes: 75,
            format: .theLastGate,
            minOverallLevel: 1,
            requiredEquipment: [.bodyweight],
            performanceStandards: stations.map(\.standard),
            loadoutVariants: [
                TrialLoadoutVariant(
                    loadout: .homeKit,
                    requiredEquipment: [.bodyweight],
                    promise: "test",
                    stations: stations
                )
            ]
        )
    }

    private func makeAttributeProfile(overriding key: AttributeKey, level: Int, baseLevel: Int = 70) -> AttributeProfile {
        let date = Date(timeIntervalSince1970: 0)
        var profile = AttributeProfile.empty(userId: "u1", at: date)
        // Set all axes to the base level's XP
        let baseXP = AttributeLevelCurve.xpRequired(forLevel: baseLevel)
        for axis in AttributeKey.allCases {
            profile.set(axis, AttributeValue(xp: baseXP, lastContributionAt: date))
        }
        // Override the target axis to the given level
        let overrideXP = AttributeLevelCurve.xpRequired(forLevel: level)
        profile.set(key, AttributeValue(xp: overrideXP, lastContributionAt: date))
        return profile
    }

    func testLastGateLanding6ResolvesToWeakestAttributeStation() {
        let definition = syntheticLastGateDefinition()

        // Make mobility the weakest (level 32 vs 70 for all others)
        let scores = makeAttributeProfile(overriding: .mobility, level: 32)

        let resolved = OverallRankTrialRunner.resolveDynamicStations(
            for: definition,
            loadout: .homeKit,
            attributeScores: scores
        )

        let landing6Ids = resolved.map(\.id).filter { $0.hasPrefix("lastgate-landing-6-") }
        XCTAssertEqual(landing6Ids.count, 1,
            "Exactly one landing-6 station should survive dynamic resolution")
        XCTAssertEqual(landing6Ids.first, "lastgate-landing-6-mobility",
            "The weakest attribute's station should be kept")

        let otherLanding6 = resolved.filter {
            $0.id.hasPrefix("lastgate-landing-6-") && $0.id != "lastgate-landing-6-mobility"
        }
        XCTAssertTrue(otherLanding6.isEmpty,
            "All non-weakest landing-6 stations must be removed")

        // Fixed station is preserved
        XCTAssertTrue(resolved.contains { $0.id == "lastgate-anchor" },
            "Non-dynamic anchor station must survive resolution")
    }

    func testRealLastGateDraftResolvesExactlyOneLanding6Station() {
        let definition = OverallRankTrialDefinitions.theLastGate
        let scores = makeAttributeProfile(overriding: .control, level: 31)

        let stations = OverallRankTrialRunner.resolveDynamicStations(
            for: definition,
            loadout: .homeKit,
            attributeScores: scores
        )
        let resolvedTrial = ResolvedRankTrial(
            id: "\(definition.id):homeKit:dynamic-test",
            definitionId: definition.id,
            userId: "u1",
            selectedLoadout: .homeKit,
            stations: stations.map { station in
                ResolvedTrialStation(
                    id: station.id,
                    station: station,
                    selectedMovement: station.primaryMovement
                )
            },
            generatedAt: Date(timeIntervalSince1970: 100),
            version: 1
        )
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolvedTrial,
            bodyweightKg: 80
        )

        let landing6Ids = resolvedTrial.stations.map(\.id).filter { $0.hasPrefix("lastgate-landing-6-") }
        XCTAssertEqual(landing6Ids, ["lastgate-landing-6-control"])
        XCTAssertEqual(draft.blocks.count, resolvedTrial.stations.count)
        XCTAssertEqual(draft.blocks.filter { $0.title.hasPrefix("Landing 6") }.count, 1)
    }

    func testRealLastGateNormalDraftPathContainsExactlyOneLanding6Station() {
        let definition = OverallRankTrialDefinitions.theLastGate
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "lastgate-normal-draft-\(UUID().uuidString)",
            date: Date(timeIntervalSince1970: 100),
            bodyweightKg: 80
        )

        let landing6Blocks = draft.blocks.filter { $0.title.hasPrefix("Landing 6") }
        XCTAssertEqual(landing6Blocks.count, 1)
        XCTAssertEqual(landing6Blocks.first?.title, "Landing 6 - Power Seal")
    }

    func testRealLastGateEvaluationCollapsesLanding6DynamicGroup() {
        let definition = OverallRankTrialDefinitions.theLastGate
        let userId = "lastgate-evaluation-dynamic-group-\(UUID().uuidString)"
        let startedAt = Date(timeIntervalSince1970: 100)
        let completedAt = Date(timeIntervalSince1970: 100 + 60 * 70)
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: userId,
            date: startedAt,
            bodyweightKg: 80
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: userId,
            startedAt: startedAt,
            completedAt: completedAt,
            passing: true
        )

        let evaluation = OverallRankTrialRunner.shared.evaluateDetailed(
            log,
            against: definition,
            bodyweightKg: 80
        )
        let landing6Results = evaluation.stationResults.filter { $0.id.hasPrefix("lastgate-landing-6-") }

        XCTAssertTrue(evaluation.passed, evaluation.failedStation?.failureReason ?? "The Last Gate failed")
        XCTAssertEqual(landing6Results.map(\.id), ["lastgate-landing-6-power"])
        XCTAssertFalse(landing6Results.contains { $0.status == .missing })
    }

    func testLastGateLanding6TieBreaksByAttributeKeyOrder() {
        // When all attributes are equal, the first in AttributeKey.allCases order wins.
        let definition = syntheticLastGateDefinition()
        let equalScores = makeAttributeProfile(overriding: .power, level: 70)  // all equal at 70

        let resolved = OverallRankTrialRunner.resolveDynamicStations(
            for: definition,
            loadout: .homeKit,
            attributeScores: equalScores
        )

        let landing6Ids = resolved.map(\.id).filter { $0.hasPrefix("lastgate-landing-6-") }
        XCTAssertEqual(landing6Ids.count, 1, "Exactly one landing-6 station in a tie")

        // First case in AttributeKey.allCases is .power
        let firstKey = AttributeKey.allCases.first!.rawValue
        XCTAssertEqual(landing6Ids.first, "lastgate-landing-6-\(firstKey)",
            "Tie should resolve to first AttributeKey.allCases entry")
    }

    func testResolveDynamicStationsIsNoOpForDefinitionWithoutLanding6() {
        // A definition with no lastgate-landing-6-* stations is returned unchanged.
        let definition = OverallRankTrialDefinitions.theCount
        let scores = makeAttributeProfile(overriding: .endurance, level: 10)

        let resolved = OverallRankTrialRunner.resolveDynamicStations(
            for: definition,
            loadout: .homeKit,
            attributeScores: scores
        )

        let variant = definition.loadoutVariants.first { $0.loadout == .homeKit }!
        XCTAssertEqual(resolved.map(\.id), variant.stations.map(\.id),
            "Definition without landing-6 stations should be returned unchanged")
    }
}
