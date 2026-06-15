import XCTest
@testable import UNBOUND

extension OverallRankTrialServiceTests {
    func testReadinessLockedWhenAccumulationAndLevelRequirementsAreMissing() {
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .initiate,
                overallLevel: 0,
                aggregateRank: .initiate,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .rank })
    }

    func testReadinessBecomesReadyWhenBothGatesAreMet() {
        let definition = OverallRankTrialDefinitions.firstLight
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .initiate,
                overallLevel: definition.minOverallLevel,
                aggregateRank: definition.targetRank,
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
                aggregateRank: .initiate,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .novice)
        XCTAssertEqual(readiness.targetRank, .apprentice)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .rank })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testNoviceReadinessBecomesReadyForTheCountWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.theCount
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .novice,
                overallLevel: definition.minOverallLevel,
                aggregateRank: definition.targetRank,
                equipment: readyEquipment(),
                clearedGateKeys: []
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
                aggregateRank: .initiate,
                equipment: [.bodyweight],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .apprentice)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .rank })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testApprenticeReadinessBecomesReadyForTheForgingWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.theForging
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                aggregateRank: definition.targetRank,
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
                aggregateRank: definition.targetRank,
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
                aggregateRank: .initiate,
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
                aggregateRank: definition.targetRank,
                equipment: [.bodyweight, .openSpace],
                clearedGateKeys: []
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
                aggregateRank: definition.targetRank,
                equipment: readyEquipment(),
                clearedGateKeys: []
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
                aggregateRank: .initiate,
                equipment: [.bodyweight, .openSpace],
                clearedGateKeys: []
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .veteran)
        XCTAssertEqual(readiness.targetRank, .master)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .rank })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testVeteranReadinessBecomesReadyForTheAscentWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.theAscent
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .veteran,
                overallLevel: definition.minOverallLevel,
                aggregateRank: definition.targetRank,
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
                    aggregateRank: .initiate,
                    equipment: [.bodyweight],
                    clearedGateKeys: []
                )
            )

            XCTAssertEqual(locked.status, .locked, definition.displayName)
            XCTAssertEqual(locked.currentRank, trialCase.sourceRank, definition.displayName)
            XCTAssertEqual(locked.targetRank, definition.targetRank, definition.displayName)
            XCTAssertEqual(locked.definition?.id, definition.id, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .overallLevel }, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .rank }, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .equipment }, definition.displayName)

            let ready = TrialReadinessService.shared.evaluate(
                OverallRankTrialReadinessInput(
                    userId: "u1",
                    currentRank: trialCase.sourceRank,
                    overallLevel: definition.minOverallLevel,
                    aggregateRank: definition.targetRank,
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

}
