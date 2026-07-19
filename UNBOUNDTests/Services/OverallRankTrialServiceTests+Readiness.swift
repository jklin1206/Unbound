import XCTest
@testable import UNBOUND

extension OverallRankTrialServiceTests {
    func testReadinessLockedWhenAccumulationAndLevelRequirementsAreMissing() {
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .initiate,
                overallLevel: 0,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        // Accumulated-rank requirement was folded out; level alone gates here.
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
    }

    func testReadinessBecomesReadyWhenBothGatesAreMet() {
        let definition = OverallRankTrialDefinitions.firstLight
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .initiate,
                overallLevel: definition.minOverallLevel,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.id, definition.id)
    }

    func testEarlyRankGatesUsePlayableBenchmarkTrials() {
        XCTAssertEqual(OverallRankTrialDefinitions.ceremonyTier(for: .novice), .benchmark)
        XCTAssertEqual(OverallRankTrialDefinitions.ceremonyTier(for: .apprentice), .benchmark)

        for definition in [OverallRankTrialDefinitions.firstLight, OverallRankTrialDefinitions.theCount] {
            let draft = OverallRankTrialRunner.shared.draft(
                for: definition,
                userId: "u1",
                date: Date(timeIntervalSince1970: 100)
            )

            XCTAssertEqual(draft.source, .overallRankTrial, definition.displayName)
            XCTAssertEqual(draft.programId, definition.id, definition.displayName)
            XCTAssertFalse(draft.blocks.isEmpty, definition.displayName)
        }
    }

    func testNoviceReadinessTargetsApprenticeAndLocksWhenTheCountRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.theCount
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .novice,
                overallLevel: definition.minOverallLevel - 1,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .novice)
        XCTAssertEqual(readiness.targetRank, .apprentice)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testNoviceReadinessBecomesReadyForTheCountWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.theCount
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .novice,
                overallLevel: definition.minOverallLevel,
                equipment: readyEquipment(),
                clearedGateKeys: clearedGateKeyIds(for: definition)
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .novice)
        XCTAssertEqual(readiness.targetRank, .apprentice)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Count")
        XCTAssertEqual(readiness.resolvedTrial?.selectedLoadout, .gymHybrid)
    }

    func testApprenticeReadinessTargetsForgedAndLocksWhenTheForgingRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.theForging
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel - 1,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .apprentice)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testApprenticeReadinessBecomesReadyForTheForgingWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.theForging
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                equipment: readyEquipment(),
                clearedGateKeys: clearedGateKeyIds(for: definition)
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .apprentice)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Forging")
    }

    func testTheForgingReadinessReportsFailedAfterMissedAttemptWhenRequirementsRemainMet() {
        let definition = OverallRankTrialDefinitions.theForging
        let attempt = OverallRankTrialAttempt(
            id: "forging-log-1",
            userId: "u1",
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            performanceLogId: "forging-log-1",
            passed: false,
            movementAPGained: 0,
            overallLevelXPGained: 0
        )

        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                equipment: readyEquipment(),
                clearedGateKeys: clearedGateKeyIds(for: definition),
                attempts: [attempt]
            )
        )

        XCTAssertEqual(readiness.status, .failed)
        XCTAssertEqual(readiness.latestAttempt?.id, attempt.id)
        XCTAssertTrue(readiness.isReady)
    }

    func testLegacyDefinitionAttemptsCountForProgressAndReadiness() throws {
        let definition = OverallRankTrialDefinitions.theForging
        let legacyId = try XCTUnwrap(definition.legacyIds.first)
        let legacyAttempt = OverallRankTrialAttempt(
            id: "legacy-forging-pass",
            userId: "u1",
            definitionId: legacyId,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            performanceLogId: "legacy-forging-log",
            passed: true,
            movementAPGained: 0,
            overallLevelXPGained: 0
        )
        let progress = OverallRankTrialProgress(
            highestPassedRank: .apprentice,
            attempts: [legacyAttempt]
        )

        XCTAssertEqual(progress.latestAttempt(for: definition)?.id, legacyAttempt.id)

        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: 0,
                equipment: [.bodyweight],
                clearedGateKeys: [],
                attempts: progress.attempts
            )
        )

        XCTAssertEqual(readiness.latestAttempt?.id, legacyAttempt.id)
        XCTAssertEqual(readiness.status, .passed)
    }

    func testForgedReadinessTargetsVeteranAndLocksWhenDeckOfProofEquipmentIsMissing() {
        let definition = OverallRankTrialDefinitions.deckOfProof
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .forged,
                overallLevel: definition.minOverallLevel,
                equipment: [.bodyweight, .openSpace],
                clearedGateKeys: clearedGateKeyIds(for: definition)
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .forged)
        XCTAssertEqual(readiness.targetRank, .veteran)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertEqual(readiness.missingRequirements.map(\.kind), [.equipment])
    }

    func testForgedReadinessBecomesReadyForDeckOfProofWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.deckOfProof
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .forged,
                overallLevel: definition.minOverallLevel,
                equipment: readyEquipment(),
                clearedGateKeys: clearedGateKeyIds(for: definition)
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .forged)
        XCTAssertEqual(readiness.targetRank, .veteran)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Reckoning")
    }

    func testVeteranReadinessTargetsMasterAndLocksWhenTheAscentRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.theAscent
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .veteran,
                overallLevel: definition.minOverallLevel - 1,
                equipment: [.bodyweight, .openSpace],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .veteran)
        XCTAssertEqual(readiness.targetRank, .master)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testVeteranReadinessBecomesReadyForTheAscentWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.theAscent
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .veteran,
                overallLevel: definition.minOverallLevel,
                equipment: readyEquipment(),
                clearedGateKeys: clearedGateKeyIds(for: definition)
            )
        )

        assertCatalogBacked(definition)
        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .veteran)
        XCTAssertEqual(readiness.targetRank, .master)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Ascent")
    }

    func testUpperRankReadinessLocksAndReadiesForEveryNewDefinition() {
        for trialCase in upperRankTrialCases {
            let definition = trialCase.definition
            let locked = TrialReadinessService.shared.evaluate(
                OverallRankTrialReadinessInput(
                    userId: "u1",
                    currentRank: trialCase.sourceRank,
                    overallLevel: definition.minOverallLevel - 1,
                    equipment: [.bodyweight],
                    clearedGateKeys: []
                )
            )

            XCTAssertEqual(locked.status, .locked, definition.displayName)
            XCTAssertEqual(locked.currentRank, trialCase.sourceRank, definition.displayName)
            XCTAssertEqual(locked.targetRank, definition.targetRank, definition.displayName)
            XCTAssertEqual(locked.definition?.id, definition.id, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .overallLevel }, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .equipment }, definition.displayName)

            let ready = TrialReadinessService.shared.evaluate(
                OverallRankTrialReadinessInput(
                    userId: "u1",
                    currentRank: trialCase.sourceRank,
                    overallLevel: definition.minOverallLevel,
                    equipment: readyEquipment(),
                    clearedGateKeys: clearedGateKeyIds(for: definition)
                )
            )

            assertCatalogBacked(definition)
            XCTAssertEqual(ready.status, .ready, definition.displayName)
            XCTAssertEqual(ready.currentRank, trialCase.sourceRank, definition.displayName)
            XCTAssertEqual(ready.targetRank, definition.targetRank, definition.displayName)
            XCTAssertTrue(ready.missingRequirements.isEmpty, definition.displayName)
            XCTAssertEqual(ready.definition?.id, definition.id, definition.displayName)
        }
    }

    // Regression for the permanent Last Gate lockout: a player with >50 lifetime
    // attempts loses their early gate-pass records to the store's 50-entry trim,
    // yet the final gate's `gatesAnswered(7)` key - computed from the trimmed log
    // via GateKeys.clearedKeys - must still clear because it now reads the
    // monotonic `highestPassedRank`. Prove the gate-count key is met and never a
    // blocker in the real readiness evaluation.
    func testLastGateReadinessGateCountKeyNotBlockedByTrimmedAttemptLog() {
        let definition = OverallRankTrialDefinitions.theLastGate
        let gatesKey = GateKeys.keys(for: .theLastGate).first { $0.metric == .gatesAnswered(7) }!

        let trimmedLog = (0..<50).map { i in
            OverallRankTrialAttempt(
                id: "lastgate-fail-\(i)",
                userId: "u1",
                definitionId: definition.id,
                targetRank: definition.targetRank,
                startedAt: Date(timeIntervalSince1970: 100),
                completedAt: Date(timeIntervalSince1970: 1_000 + Double(i)),
                performanceLogId: "lastgate-log-\(i)",
                passed: false,
                movementAPGained: 0,
                overallLevelXPGained: 0
            )
        }
        let progress = OverallRankTrialProgress(highestPassedRank: .ascendant, attempts: trimmedLog)
        let history = WorkoutLogGateKeyHistory(
            workoutLogs: [],
            attributeProfile: nil,
            trialProgress: progress,
            movementTiers: []
        )
        let clearedGateKeys = GateKeys.clearedKeys(for: .theLastGate, history: history, bodyweightKg: 100)

        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .ascendant,
                overallLevel: definition.minOverallLevel,
                equipment: readyEquipment(),
                clearedGateKeys: clearedGateKeys,
                attempts: progress.attempts
            )
        )

        let gatesLine = readiness.requirements.first { $0.id == gatesKey.id }
        XCTAssertEqual(gatesLine?.isMet, true, "gatesAnswered(7) must be met once Ascendant is confirmed")
        XCTAssertFalse(
            readiness.missingRequirements.contains { $0.id == gatesKey.id },
            "the gate-count key must never block the Last Gate after the trim"
        )
    }

    // CLAUDE.md contract lock: real readiness = overall level + equipment + gate
    // keys ONLY. The build-weighted aggregate rank gates NOTHING. Drive the real
    // readiness path twice, varying ONLY the aggregate, and require an identical
    // verdict. (The aggregate is no longer even fetched here; this guards against
    // anyone re-wiring it into the hot path.)
    func testReadinessIgnoresAggregateStrengthSignal() async throws {
        let database = MockDatabaseService()
        try await database.create(
            OverallLevelProgress(userId: "u1", totalXP: OverallLevelCurve.xpRequired(forLevel: 100)),
            collection: "overall_level_progress",
            documentId: "u1"
        )
        store.save(.empty, userId: "u1") // next trial = First Light (a level-only gate)
        let services = makeServices(database: database)
        let mockRank = try XCTUnwrap(services.rank as? MockRankService)

        mockRank.aggregateRankOverride = .initiate
        let low = await TrialReadinessService.shared.readiness(userId: "u1", services: services, store: store)

        mockRank.aggregateRankOverride = .unbound
        let high = await TrialReadinessService.shared.readiness(userId: "u1", services: services, store: store)

        XCTAssertEqual(low.status, high.status, "aggregate rank must not change readiness status")
        XCTAssertEqual(low.status, .ready, "level + equipment satisfied and First Light has no gate keys → ready")
        XCTAssertEqual(low.targetRank, .novice)
    }

}
