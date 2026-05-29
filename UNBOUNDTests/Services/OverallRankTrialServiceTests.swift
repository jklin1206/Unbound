import XCTest
@testable import UNBOUND

@MainActor
final class OverallRankTrialServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: OverallRankTrialStore!

    private struct RankTrialCase {
        let sourceRank: RankTitle
        let definition: OverallRankTrialDefinition
    }

    private var upperRankTrialCases: [RankTrialCase] {
        [
            RankTrialCase(sourceRank: .master, definition: OverallRankTrialDefinitions.crucible),
            RankTrialCase(sourceRank: .vessel, definition: OverallRankTrialDefinitions.threshold),
            RankTrialCase(sourceRank: .unbound, definition: OverallRankTrialDefinitions.ascension)
        ]
    }

    private var allRankTrialCases: [RankTrialCase] {
        [
            RankTrialCase(sourceRank: .initiate, definition: OverallRankTrialDefinitions.foundationProof),
            RankTrialCase(sourceRank: .novice, definition: OverallRankTrialDefinitions.calibration),
            RankTrialCase(sourceRank: .apprentice, definition: OverallRankTrialDefinitions.forge),
            RankTrialCase(sourceRank: .forged, definition: OverallRankTrialDefinitions.reckoning),
            RankTrialCase(sourceRank: .veteran, definition: OverallRankTrialDefinitions.gauntlet),
            RankTrialCase(sourceRank: .master, definition: OverallRankTrialDefinitions.crucible),
            RankTrialCase(sourceRank: .vessel, definition: OverallRankTrialDefinitions.threshold),
            RankTrialCase(sourceRank: .unbound, definition: OverallRankTrialDefinitions.ascension)
        ]
    }

    override func setUp() {
        super.setUp()
        suiteName = "OverallRankTrialServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = OverallRankTrialStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testReadinessLockedWhenMovementAttributeAndLevelRequirementsAreMissing() {
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .initiate,
                overallLevel: 0,
                movementProgress: [:],
                skillTiers: [:],
                attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                equipment: [.bodyweight]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .movement })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .attributes })
    }

    func testReadinessBecomesReadyWhenAllV1RequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.foundationProof
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .initiate,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: ["cal.pushup": .novice],
                attributeProfile: attributeProfile(score: 25),
                equipment: [.bodyweight]
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.id, definition.id)
    }

    func testNoviceReadinessTargetsApprenticeAndLocksWhenCalibrationRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.calibration
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .novice,
                overallLevel: definition.minOverallLevel - 1,
                movementProgress: [:],
                skillTiers: [:],
                attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                equipment: [.bodyweight]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .novice)
        XCTAssertEqual(readiness.targetRank, .apprentice)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .movement })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
        XCTAssertFalse(readiness.requirements.contains { $0.kind == .attributes })
    }

    func testNoviceReadinessBecomesReadyForCalibrationWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.calibration
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .novice,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: ["pp.pullup": .apprentice],
                attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                equipment: readyEquipment()
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .novice)
        XCTAssertEqual(readiness.targetRank, .apprentice)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "Operator Screen")
        XCTAssertEqual(readiness.resolvedTrial?.selectedLoadout, .gymHybrid)
    }

    func testApprenticeReadinessTargetsForgedAndLocksWhenForgeRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.forge
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel - 1,
                movementProgress: [:],
                skillTiers: [:],
                attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                equipment: [.bodyweight]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .apprentice)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .movement })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .attributes })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testApprenticeReadinessBecomesReadyForForgeWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.forge
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: readyEquipment()
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .apprentice)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Finisher")
    }

    func testForgeReadinessReportsFailedAfterMissedAttemptWhenRequirementsRemainMet() {
        let definition = OverallRankTrialDefinitions.forge
        let attempt = OverallRankTrialAttempt(
            id: "forge-log-1",
            userId: "u1",
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            performanceLogId: "forge-log-1",
            passed: false,
            movementAPGained: 0,
            overallLevelXPGained: 0
        )

        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .apprentice,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: readyEquipment(),
                attempts: [attempt]
            )
        )

        XCTAssertEqual(readiness.status, .failed)
        XCTAssertEqual(readiness.latestAttempt?.id, attempt.id)
        XCTAssertTrue(readiness.isReady)
    }

    func testForgedReadinessTargetsVeteranAndLocksWhenReckoningEquipmentIsMissing() {
        let definition = OverallRankTrialDefinitions.reckoning
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .forged,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: [.bodyweight, .openSpace]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .forged)
        XCTAssertEqual(readiness.targetRank, .veteran)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertEqual(readiness.missingRequirements.map(\.kind), [.equipment])
    }

    func testForgedReadinessBecomesReadyForReckoningWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.reckoning
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .forged,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: readyEquipment()
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .forged)
        XCTAssertEqual(readiness.targetRank, .veteran)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "Deck of Proof")
    }

    func testVeteranReadinessTargetsMasterAndLocksWhenGauntletRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.gauntlet
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .veteran,
                overallLevel: definition.minOverallLevel - 1,
                movementProgress: [:],
                skillTiers: [:],
                attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                equipment: [.bodyweight, .openSpace]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .veteran)
        XCTAssertEqual(readiness.targetRank, .master)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .movement })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .attributes })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testVeteranReadinessBecomesReadyForGauntletWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.gauntlet
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .veteran,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: readyEquipment()
            )
        )

        assertCatalogBacked(definition)
        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .veteran)
        XCTAssertEqual(readiness.targetRank, .master)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Tower")
    }

    func testUpperRankReadinessLocksAndReadiesForEveryNewDefinition() {
        for trialCase in upperRankTrialCases {
            let definition = trialCase.definition
            let locked = TrialReadinessService.shared.evaluate(
                OverallRankTrialReadinessInput(
                    userId: "u1",
                    currentRank: trialCase.sourceRank,
                    overallLevel: definition.minOverallLevel - 1,
                    movementProgress: [:],
                    skillTiers: [:],
                    attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                    equipment: [.bodyweight]
                )
            )

            XCTAssertEqual(locked.status, .locked, definition.displayName)
            XCTAssertEqual(locked.currentRank, trialCase.sourceRank, definition.displayName)
            XCTAssertEqual(locked.targetRank, definition.targetRank, definition.displayName)
            XCTAssertEqual(locked.definition?.id, definition.id, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .overallLevel }, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .movement }, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .attributes }, definition.displayName)
            XCTAssertTrue(locked.missingRequirements.contains { $0.kind == .equipment }, definition.displayName)

            let ready = TrialReadinessService.shared.evaluate(
                OverallRankTrialReadinessInput(
                    userId: "u1",
                    currentRank: trialCase.sourceRank,
                    overallLevel: definition.minOverallLevel,
                    movementProgress: movementProgress(for: definition),
                    skillTiers: skillTiers(for: definition),
                    attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                    equipment: readyEquipment()
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

    func testTrialRunnerDraftMapsToValidPerformanceLogBlocks() {
        let definition = OverallRankTrialDefinitions.foundationProof
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 800),
            passing: true
        )

        XCTAssertEqual(draft.source, .overallRankTrial)
        XCTAssertEqual(draft.programId, definition.id)
        XCTAssertEqual(log.source, .overallRankTrial)
        XCTAssertEqual(log.programId, definition.id)
        XCTAssertEqual(log.blocks.count, draft.blocks.count)
        XCTAssertTrue(log.blocks.flatMap(\.exercises).allSatisfy { !$0.sets.isEmpty })
        XCTAssertTrue(OverallRankTrialRunner.shared.evaluatePerformance(log, against: definition))
    }

    func testOperatorScreenDraftMapsToResolvedStationFloors() throws {
        let definition = OverallRankTrialDefinitions.calibration
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        XCTAssertEqual(definition.format, .operatorScreen)
        XCTAssertEqual(draft.title, "Operator Screen")
        XCTAssertEqual(draft.estimatedMinutes, 20)
        XCTAssertEqual(resolved.stations.map(\.category), [.engine, .lower, .push, .pull, .carryCore])
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testFinisherDraftMapsToDescendingRoundStations() throws {
        let definition = OverallRankTrialDefinitions.forge
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        XCTAssertEqual(definition.format, .finisher)
        XCTAssertEqual(draft.title, "The Finisher")
        XCTAssertEqual(draft.estimatedMinutes, 30)
        XCTAssertEqual(resolved.stations.count, 15)
        XCTAssertEqual(Array(resolved.stations.map(\.category).prefix(5)), [.engine, .hingePower, .push, .pull, .carryCore])
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testDeckOfProofDraftMapsToDeterministicFixedDeck() throws {
        let definition = OverallRankTrialDefinitions.reckoning
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        XCTAssertEqual(definition.format, .fixedDeck)
        XCTAssertEqual(draft.title, "Deck of Proof")
        XCTAssertEqual(draft.estimatedMinutes, 42)
        XCTAssertEqual(resolved.stations.count, 24)
        XCTAssertEqual(resolved.stations.filter { $0.category == .push }.count, 6)
        XCTAssertEqual(resolved.stations.filter { $0.category == .lower }.count, 6)
        XCTAssertEqual(resolved.stations.filter { $0.category == .pull }.count, 6)
        XCTAssertEqual(resolved.stations.filter { $0.category == .engine }.count, 4)
        XCTAssertEqual(resolved.stations.filter { $0.category == .carryCore }.count, 2)
        XCTAssertEqual(Array(resolved.stations.map(\.id).prefix(3)), ["deck-card-01", "deck-card-02", "deck-card-03"])
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testTowerDraftMapsToTenFloorProtocol() throws {
        let definition = OverallRankTrialDefinitions.gauntlet
        let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit))
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            resolvedTrial: resolved
        )

        assertCatalogBacked(definition)
        XCTAssertEqual(definition.format, .tower)
        XCTAssertEqual(draft.title, "The Tower")
        XCTAssertEqual(draft.estimatedMinutes, 50)
        XCTAssertEqual(resolved.stations.count, 11)
        XCTAssertEqual(resolved.stations.map(\.id).first, "tower-floor-01")
        XCTAssertEqual(resolved.stations.map(\.id).last, "tower-floor-10")
        XCTAssertTrue(resolved.stations.map(\.id).contains("tower-floor-09-push"))
        XCTAssertTrue(resolved.stations.map(\.id).contains("tower-floor-09-pull"))
        assertDraft(draft, matches: definition, resolvedTrial: resolved)
        assertDraftPassesAndFails(draft, against: definition)
    }

    func testEliteProtocolsScoreCompoundPushAndPullStationsSeparately() throws {
        let tower = try XCTUnwrap(resolvedTrial(for: OverallRankTrialDefinitions.gauntlet, loadout: .homeKit))
        let bossRush = try XCTUnwrap(resolvedTrial(for: OverallRankTrialDefinitions.crucible, loadout: .homeKit))

        XCTAssertEqual(tower.stations.first { $0.id == "tower-floor-09-push" }?.category, .push)
        XCTAssertEqual(tower.stations.first { $0.id == "tower-floor-09-pull" }?.category, .pull)
        XCTAssertFalse(tower.stations.map(\.id).contains("tower-floor-09"))
        XCTAssertEqual(bossRush.stations.first { $0.id == "boss-upper-push" }?.category, .push)
        XCTAssertEqual(bossRush.stations.first { $0.id == "boss-upper-pull" }?.category, .pull)
        XCTAssertFalse(bossRush.stations.map(\.id).contains("boss-upper"))
    }

    func testUpperRankDraftsMapToResolvedProtocolsForEveryNewDefinition() throws {
        for trialCase in upperRankTrialCases {
            let definition = trialCase.definition
            let resolved = try XCTUnwrap(resolvedTrial(for: definition, loadout: .homeKit), definition.displayName)
            let draft = OverallRankTrialRunner.shared.draft(
                for: definition,
                userId: "u1",
                date: Date(timeIntervalSince1970: 100),
                resolvedTrial: resolved
            )

            assertCatalogBacked(definition)
            assertDraft(draft, matches: definition, resolvedTrial: resolved)
            assertDraftPassesAndFails(draft, against: definition)
        }
    }

    func testFailedTrialLogsAttemptAndReceiptButDoesNotAdvanceOverallRank() async throws {
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.foundationProof
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 800),
            passing: false
        )

        let completed = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let result = try XCTUnwrap(completed)
        let savedLog: PerformanceLog = try await database.read(collection: "performanceLogs", documentId: log.id)
        let completionRecord: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertEqual(savedLog.id, log.id)
        XCTAssertEqual(completionRecord.performanceLogId, log.id)
        XCTAssertFalse(result.attempt.passed)
        XCTAssertFalse(result.didAdvanceRank)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .initiate)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedTrialAdvancesOverallRankExactlyOnceForDuplicateAttemptId() async throws {
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.foundationProof
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 800),
            passing: true
        )

        let firstCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let secondCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let first = try XCTUnwrap(firstCompleted)
        let second = try XCTUnwrap(secondCompleted)
        let progress = store.load(userId: "u1")

        XCTAssertTrue(first.attempt.passed)
        XCTAssertTrue(first.didAdvanceRank)
        XCTAssertEqual(first.progress.currentRank, .novice)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertEqual(progress.currentRank, .novice)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedCalibrationLogsAttemptAndReceiptButDoesNotAdvancePastNovice() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .novice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.calibration
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: false
        )

        let completed = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let result = try XCTUnwrap(completed)
        let savedLog: PerformanceLog = try await database.read(collection: "performanceLogs", documentId: log.id)
        let completionRecord: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertEqual(savedLog.id, log.id)
        XCTAssertEqual(completionRecord.performanceLogId, log.id)
        XCTAssertEqual(result.definition.id, definition.id)
        XCTAssertFalse(result.attempt.passed)
        XCTAssertFalse(result.didAdvanceRank)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .novice)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedCalibrationAdvancesToApprenticeExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .novice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.calibration
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )

        let firstCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let secondCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let first = try XCTUnwrap(firstCompleted)
        let second = try XCTUnwrap(secondCompleted)
        let progress = store.load(userId: "u1")

        XCTAssertEqual(first.definition.id, definition.id)
        XCTAssertTrue(first.attempt.passed)
        XCTAssertTrue(first.didAdvanceRank)
        XCTAssertEqual(first.progress.currentRank, .apprentice)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertEqual(progress.currentRank, .apprentice)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedForgeLogsAttemptAndReceiptButDoesNotAdvancePastApprentice() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.forge
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_800),
            passing: false
        )

        let completed = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let result = try XCTUnwrap(completed)
        let savedLog: PerformanceLog = try await database.read(collection: "performanceLogs", documentId: log.id)
        let completionRecord: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertEqual(savedLog.id, log.id)
        XCTAssertEqual(completionRecord.performanceLogId, log.id)
        XCTAssertEqual(result.definition.id, definition.id)
        XCTAssertFalse(result.attempt.passed)
        XCTAssertFalse(result.didAdvanceRank)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .apprentice)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedForgeAdvancesToForged() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.forge
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_800),
            passing: true
        )

        let completed = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let result = try XCTUnwrap(completed)

        XCTAssertEqual(result.definition.id, definition.id)
        XCTAssertTrue(result.attempt.passed)
        XCTAssertTrue(result.didAdvanceRank)
        XCTAssertEqual(result.progress.currentRank, .forged)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .forged)
    }

    func testPassedForgeAfterFailedAttemptIncludesComebackCallout() throws {
        let definition = OverallRankTrialDefinitions.forge
        let failedAttempt = OverallRankTrialAttempt(
            id: "forge-failed-1",
            userId: "u1",
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_000),
            performanceLogId: "forge-failed-1",
            passed: false,
            movementAPGained: 0,
            overallLevelXPGained: 0
        )
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: [failedAttempt]),
            userId: "u1"
        )
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 3_000)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 3_000),
            completedAt: Date(timeIntervalSince1970: 4_600),
            passing: true
        )

        let completed = OverallRankTrialRunner.shared.recordCompletedAttempt(
            performanceLog: log,
            completionResult: TrainingCompletionResult(),
            store: store
        )
        let result = try XCTUnwrap(completed)

        XCTAssertTrue(result.attempt.passed)
        XCTAssertTrue(result.didAdvanceRank)
        XCTAssertEqual(result.progress.currentRank, .forged)
        XCTAssertEqual(result.callouts.map(\.kind), [.comebackPass])
        XCTAssertEqual(result.callouts.first?.title, "Comeback clear")
        XCTAssertTrue(result.callouts.first?.message.contains("The Finisher") == true)
        XCTAssertTrue(result.callouts.first?.message.contains("1 failed attempt") == true)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 2)
    }

    func testDuplicateForgePerformanceLogDoesNotCreateSecondAttemptOrAdvanceAgain() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.forge
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_800),
            passing: true
        )

        let firstCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let secondCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let first = try XCTUnwrap(firstCompleted)
        let second = try XCTUnwrap(secondCompleted)
        let progress = store.load(userId: "u1")

        XCTAssertTrue(first.didAdvanceRank)
        XCTAssertTrue(first.callouts.isEmpty)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertNil(second.completionResult)
        XCTAssertEqual(second.callouts.map(\.kind), [.duplicateAttempt])
        XCTAssertEqual(second.callouts.first?.title, "Attempt already counted")
        XCTAssertTrue(second.callouts.first?.message.contains("The Finisher") == true)
        XCTAssertEqual(progress.currentRank, .forged)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedReckoningLogsAttemptAndReceiptButDoesNotAdvancePastForged() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.reckoning
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_600),
            passing: false
        )

        let completed = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let result = try XCTUnwrap(completed)
        let savedLog: PerformanceLog = try await database.read(collection: "performanceLogs", documentId: log.id)
        let completionRecord: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertEqual(savedLog.id, log.id)
        XCTAssertEqual(completionRecord.performanceLogId, log.id)
        XCTAssertEqual(result.definition.id, definition.id)
        XCTAssertFalse(result.attempt.passed)
        XCTAssertFalse(result.didAdvanceRank)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .forged)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedReckoningAdvancesToVeteranExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.reckoning
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_600),
            passing: true
        )

        let firstCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let secondCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let first = try XCTUnwrap(firstCompleted)
        let second = try XCTUnwrap(secondCompleted)
        let progress = store.load(userId: "u1")

        XCTAssertEqual(first.definition.id, definition.id)
        XCTAssertTrue(first.attempt.passed)
        XCTAssertTrue(first.didAdvanceRank)
        XCTAssertEqual(first.progress.currentRank, .veteran)
        XCTAssertEqual(first.rankUp?.toTier, .veteran)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertNil(second.completionResult)
        XCTAssertEqual(progress.currentRank, .veteran)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedGauntletLogsAttemptAndReceiptButDoesNotAdvancePastVeteran() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .veteran, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.gauntlet
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 3_000),
            passing: false
        )

        let completed = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let result = try XCTUnwrap(completed)
        let savedLog: PerformanceLog = try await database.read(collection: "performanceLogs", documentId: log.id)
        let completionRecord: TrainingCompletionRecord = try await database.read(
            collection: "training_completion_records",
            documentId: log.id
        )

        XCTAssertEqual(savedLog.id, log.id)
        XCTAssertEqual(completionRecord.performanceLogId, log.id)
        XCTAssertEqual(result.definition.id, definition.id)
        XCTAssertFalse(result.attempt.passed)
        XCTAssertFalse(result.didAdvanceRank)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .veteran)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedGauntletAdvancesToMasterExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .veteran, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.gauntlet
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let log = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 3_000),
            passing: true
        )

        let firstCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let secondCompleted = try await OverallRankTrialRunner.shared.complete(
            performanceLog: log,
            services: services,
            store: store
        )
        let first = try XCTUnwrap(firstCompleted)
        let second = try XCTUnwrap(secondCompleted)
        let progress = store.load(userId: "u1")

        XCTAssertEqual(first.definition.id, definition.id)
        XCTAssertTrue(first.attempt.passed)
        XCTAssertTrue(first.didAdvanceRank)
        XCTAssertEqual(first.progress.currentRank, .master)
        XCTAssertEqual(first.rankUp?.toTier, .master)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertNil(second.completionResult)
        XCTAssertEqual(progress.currentRank, .master)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testUpperRankCompletionPassFailAndDuplicateBehaviorForEveryNewDefinition() async throws {
        for trialCase in upperRankTrialCases {
            let definition = trialCase.definition
            let trialCompletedAt = Date(timeIntervalSince1970: 100 + Double(definition.estimatedMinutes * 60 - 30))
            let failingUserId = "upper-fail-\(definition.targetRank.rawValue)"
            store.save(
                OverallRankTrialProgress(highestPassedRank: trialCase.sourceRank, attempts: []),
                userId: failingUserId
            )
            let failingDatabase = MockDatabaseService()
            let failingServices = makeServices(database: failingDatabase)
            let failingDraft = OverallRankTrialRunner.shared.draft(
                for: definition,
                userId: failingUserId,
                date: Date(timeIntervalSince1970: 100)
            )
            let failingLog = OverallRankTrialRunner.shared.performanceLog(
                from: failingDraft,
                userId: failingUserId,
                startedAt: Date(timeIntervalSince1970: 100),
                completedAt: trialCompletedAt,
                passing: false
            )

            let failedCompleted = try await OverallRankTrialRunner.shared.complete(
                performanceLog: failingLog,
                services: failingServices,
                store: store
            )
            let failed = try XCTUnwrap(failedCompleted)
            let savedLog: PerformanceLog = try await failingDatabase.read(
                collection: "performanceLogs",
                documentId: failingLog.id
            )
            let completionRecord: TrainingCompletionRecord = try await failingDatabase.read(
                collection: "training_completion_records",
                documentId: failingLog.id
            )

            XCTAssertEqual(savedLog.id, failingLog.id, definition.displayName)
            XCTAssertEqual(completionRecord.performanceLogId, failingLog.id, definition.displayName)
            XCTAssertEqual(failed.definition.id, definition.id, definition.displayName)
            XCTAssertFalse(failed.attempt.passed, definition.displayName)
            XCTAssertFalse(failed.didAdvanceRank, definition.displayName)
            XCTAssertEqual(store.load(userId: failingUserId).currentRank, trialCase.sourceRank, definition.displayName)
            XCTAssertEqual(store.load(userId: failingUserId).attempts.count, 1, definition.displayName)

            let passingUserId = "upper-pass-\(definition.targetRank.rawValue)"
            store.save(
                OverallRankTrialProgress(highestPassedRank: trialCase.sourceRank, attempts: []),
                userId: passingUserId
            )
            let passingDatabase = MockDatabaseService()
            let passingServices = makeServices(database: passingDatabase)
            let passingDraft = OverallRankTrialRunner.shared.draft(
                for: definition,
                userId: passingUserId,
                date: Date(timeIntervalSince1970: 100)
            )
            let passingLog = OverallRankTrialRunner.shared.performanceLog(
                from: passingDraft,
                userId: passingUserId,
                startedAt: Date(timeIntervalSince1970: 100),
                completedAt: trialCompletedAt,
                passing: true
            )

            let firstCompleted = try await OverallRankTrialRunner.shared.complete(
                performanceLog: passingLog,
                services: passingServices,
                store: store
            )
            let secondCompleted = try await OverallRankTrialRunner.shared.complete(
                performanceLog: passingLog,
                services: passingServices,
                store: store
            )
            let first = try XCTUnwrap(firstCompleted)
            let second = try XCTUnwrap(secondCompleted)
            let progress = store.load(userId: passingUserId)

            XCTAssertEqual(first.definition.id, definition.id, definition.displayName)
            XCTAssertEqual(first.attempt.targetRank, definition.targetRank, definition.displayName)
            XCTAssertTrue(first.attempt.passed, definition.displayName)
            XCTAssertTrue(first.didAdvanceRank, definition.displayName)
            XCTAssertEqual(first.progress.currentRank, definition.targetRank, definition.displayName)
            XCTAssertEqual(first.rankUp?.toTier, definition.targetRank, definition.displayName)
            XCTAssertTrue(second.wasDuplicate, definition.displayName)
            XCTAssertFalse(second.didAdvanceRank, definition.displayName)
            XCTAssertNil(second.completionResult, definition.displayName)
            XCTAssertEqual(progress.currentRank, definition.targetRank, definition.displayName)
            XCTAssertEqual(progress.attempts.count, 1, definition.displayName)
        }
    }

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

        XCTAssertEqual(log.blocks.first?.exercises.first?.notes, "Home Kit official station: Engine")
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

    private func movementProgress(
        for definition: OverallRankTrialDefinition
    ) -> [String: MovementProgressState] {
        Dictionary(uniqueKeysWithValues: definition.movementStandards.map { standard in
            (
                standard.rankStandardMovementId,
                MovementProgressState(
                    userId: "u1",
                    rankStandardMovementId: standard.rankStandardMovementId,
                    displayName: standard.displayName,
                    rankTemplate: MovementCatalog.definition(for: standard.rankStandardMovementId)?.rankTemplate ?? .bodyweightReps,
                    totalAP: standard.minimumAP,
                    updatedAt: Date(timeIntervalSince1970: 0)
                )
            )
        })
    }

    private func skillTiers(
        for definition: OverallRankTrialDefinition
    ) -> [String: SkillTier] {
        var tiers = Dictionary(uniqueKeysWithValues: definition.skillStandards.map { standard in
            (standard.skillId, standard.minimumTier)
        })
        // Satisfy each path-aware group by meeting its first `minimumCount` options.
        for group in definition.skillPathGroups {
            for option in group.options.prefix(group.minimumCount) {
                tiers[option.skillId] = option.minimumTier
            }
        }
        return tiers
    }

    private func readyEquipment() -> Set<MovementEquipment> {
        [
            .bodyweight,
            .openSpace,
            .dumbbell,
            .kettlebell,
            .band,
            .pullupBar,
            .cable,
            .machine,
            .cardioMachine
        ]
    }

    private func equipment(for loadout: TrialLoadout) -> Set<MovementEquipment> {
        switch loadout {
        case .noGymField:
            return [.bodyweight, .openSpace, .pullupBar]
        case .homeKit:
            return [.bodyweight, .openSpace, .dumbbell, .kettlebell, .band, .pullupBar]
        case .gymHybrid:
            return readyEquipment()
        }
    }

    private func resolvedTrial(
        for definition: OverallRankTrialDefinition,
        loadout: TrialLoadout
    ) -> ResolvedRankTrial? {
        RankTrialLoadoutResolver.shared.resolve(
            definition: definition,
            userId: "u1",
            equipment: equipment(for: loadout),
            generatedAt: Date(timeIntervalSince1970: 100)
        ).resolvedTrial
    }

    private func assertDraft(
        _ draft: TrainingSessionDraft,
        matches definition: OverallRankTrialDefinition,
        resolvedTrial: ResolvedRankTrial,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(draft.source, .overallRankTrial, file: file, line: line)
        XCTAssertEqual(draft.programId, definition.id, file: file, line: line)
        XCTAssertEqual(draft.title, definition.displayName, file: file, line: line)
        XCTAssertEqual(draft.estimatedMinutes, definition.estimatedMinutes, file: file, line: line)
        XCTAssertEqual(draft.blocks.count, resolvedTrial.stations.count, file: file, line: line)
        XCTAssertEqual(
            draft.blocks.map(\.title),
            resolvedTrial.stations.map { $0.station.title },
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.blocks.flatMap(\.prescriptions).map(\.movementId),
            resolvedTrial.stations.map { Optional($0.selectedMovement.movementId) },
            file: file,
            line: line
        )
        XCTAssertEqual(
            draft.blocks.flatMap(\.prescriptions).map(\.sets),
            resolvedTrial.stations.map { $0.standard.plannedSets },
            file: file,
            line: line
        )
    }

    private func assertDraftPassesAndFails(
        _ draft: TrainingSessionDraft,
        against definition: OverallRankTrialDefinition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let passingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: true
        )
        let failingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 1_000),
            passing: false
        )
        let passingEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(passingLog, against: definition)
        let failingEvaluation = OverallRankTrialRunner.shared.evaluateDetailed(failingLog, against: definition)

        XCTAssertTrue(passingEvaluation.passed, definition.displayName, file: file, line: line)
        XCTAssertFalse(failingEvaluation.passed, definition.displayName, file: file, line: line)
        XCTAssertNil(passingEvaluation.failedStation, definition.displayName, file: file, line: line)
        XCTAssertNotNil(failingEvaluation.failedStation, definition.displayName, file: file, line: line)
    }

    private func attributeProfile(score: Double) -> AttributeProfile {
        var profile = AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0))
        for key in AttributeKey.allCases {
            profile.set(
                key,
                AttributeValue(
                    peak: score,
                    current: score,
                    lastContributionAt: Date(timeIntervalSince1970: 0)
                )
            )
        }
        return profile
    }

    private func assertCatalogBacked(
        _ definition: OverallRankTrialDefinition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for standard in definition.movementStandards {
            XCTAssertNotNil(
                MovementCatalog.definition(for: standard.rankStandardMovementId),
                "\(standard.rankStandardMovementId) should resolve through MovementCatalog",
                file: file,
                line: line
            )
        }
        for standard in definition.performanceStandards {
            XCTAssertNotNil(
                MovementCatalog.definition(for: standard.movementId),
                "\(standard.movementId) should resolve through MovementCatalog",
                file: file,
                line: line
            )
        }
        for standard in definition.skillStandards {
            XCTAssertNotNil(
                MovementCatalog.definition(for: "skill.\(standard.skillId)"),
                "\(standard.skillId) should resolve through MovementCatalog skill definitions",
                file: file,
                line: line
            )
        }
    }

    private func makeServices(database: MockDatabaseService) -> ServiceContainer {
        ServiceContainer(
            auth: MockAuthService(),
            database: database,
            analytics: AnalyticsService.shared,
            subscription: MockSubscriptionService(),
            paywall: MockPaywallService(),
            user: RankTrialUserServiceStub(),
            storage: StorageService.shared,
            network: NetworkService.shared,
            bodyAnalysis: MockBodyAnalysisService(),
            programGeneration: MockProgramGenerationService(),
            imageCapture: MockImageCaptureService(),
            exercisePreference: MockExercisePreferenceService(),
            customExercise: MockCustomExerciseStore(),
            workoutLog: MockWorkoutLogService(),
            workingWeight: MockWorkingWeightService(),
            cardioLog: MockCardioLogService(),
            calibration: MockCalibrationService(),
            entitlement: EntitlementService.shared,
            rank: MockRankService(),
            skin: MockSkinService(),
            sessionXP: MockSessionXPService(),
            badges: MockBadgeService(),
            programPhase: MockProgramPhaseEngine(),
            attribute: MockAttributeService()
        )
    }
}

private final class RankTrialUserServiceStub: UserServiceProtocol, @unchecked Sendable {
    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        profile(userId: userId, email: email)
    }

    func fetchProfile(userId: String) async throws -> UserProfile {
        profile(userId: userId)
    }

    func updateProfile(userId: String, fields: [String: Any]) async throws {}
    func deleteUserData(userId: String) async throws {}

    private func profile(userId: String, email: String? = nil) -> UserProfile {
        var profile = UserProfile(
            id: userId,
            email: email,
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0,
            weightKg: 100
        )
        profile.equipment = [.fullGym, .pullupBar, .homeWeights, .bands]
        return profile
    }
}
