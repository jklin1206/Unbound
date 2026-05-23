import XCTest
@testable import UNBOUND

@MainActor
final class OverallRankTrialServiceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: OverallRankTrialStore!

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

    func testReadinessLockedWhenMovementSkillAttributeAndLevelRequirementsAreMissing() {
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
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .skill })
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
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .skill })
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
                equipment: [.bodyweight, .pullupBar]
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .novice)
        XCTAssertEqual(readiness.targetRank, .apprentice)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Calibration")
    }

    func testApprenticeReadinessTargetsHonedAndLocksWhenForgeRequirementsAreMissing() {
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
        XCTAssertEqual(readiness.targetRank, .honed)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .movement })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .skill })
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
                equipment: [.bodyweight, .kettlebell, .openSpace, .pullupBar]
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .apprentice)
        XCTAssertEqual(readiness.targetRank, .honed)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Forge")
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
                equipment: [.bodyweight, .kettlebell, .openSpace, .pullupBar],
                attempts: [attempt]
            )
        )

        XCTAssertEqual(readiness.status, .failed)
        XCTAssertEqual(readiness.latestAttempt?.id, attempt.id)
        XCTAssertTrue(readiness.isReady)
    }

    func testHonedReadinessTargetsForgedAndLocksWhenReckoningEquipmentIsMissing() {
        let definition = OverallRankTrialDefinitions.reckoning
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .honed,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: [.bodyweight, .openSpace, .pullupBar]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .honed)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertEqual(readiness.missingRequirements.map(\.kind), [.equipment])
    }

    func testHonedReadinessBecomesReadyForReckoningWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.reckoning
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .honed,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: [.bodyweight, .kettlebell, .openSpace, .pullupBar]
            )
        )

        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .honed)
        XCTAssertEqual(readiness.targetRank, .forged)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Reckoning")
    }

    func testForgedReadinessTargetsVeteranAndLocksWhenGauntletRequirementsAreMissing() {
        let definition = OverallRankTrialDefinitions.gauntlet
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .forged,
                overallLevel: definition.minOverallLevel - 1,
                movementProgress: [:],
                skillTiers: [:],
                attributeProfile: AttributeProfile.empty(userId: "u1", at: Date(timeIntervalSince1970: 0)),
                equipment: [.bodyweight, .openSpace]
            )
        )

        XCTAssertEqual(readiness.status, .locked)
        XCTAssertEqual(readiness.currentRank, .forged)
        XCTAssertEqual(readiness.targetRank, .veteran)
        XCTAssertEqual(readiness.definition?.id, definition.id)
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .overallLevel })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .movement })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .skill })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .attributes })
        XCTAssertTrue(readiness.missingRequirements.contains { $0.kind == .equipment })
    }

    func testForgedReadinessBecomesReadyForGauntletWhenRequirementsAreMet() {
        let definition = OverallRankTrialDefinitions.gauntlet
        let readiness = TrialReadinessService.shared.evaluate(
            OverallRankTrialReadinessInput(
                userId: "u1",
                currentRank: .forged,
                overallLevel: definition.minOverallLevel,
                movementProgress: movementProgress(for: definition),
                skillTiers: skillTiers(for: definition),
                attributeProfile: attributeProfile(score: definition.topAttributeFloor),
                equipment: definition.requiredEquipment
            )
        )

        assertCatalogBacked(definition)
        XCTAssertEqual(readiness.status, .ready)
        XCTAssertEqual(readiness.currentRank, .forged)
        XCTAssertEqual(readiness.targetRank, .veteran)
        XCTAssertTrue(readiness.missingRequirements.isEmpty)
        XCTAssertEqual(readiness.definition?.displayName, "The Gauntlet")
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
            completedAt: Date(timeIntervalSince1970: 1_000),
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

    func testCalibrationDraftMapsToFourteenRoundPerformanceStandards() {
        let definition = OverallRankTrialDefinitions.calibration
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
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

        XCTAssertEqual(draft.title, "The Calibration")
        XCTAssertEqual(draft.estimatedMinutes, 20)
        XCTAssertEqual(draft.blocks.flatMap(\.prescriptions).map(\.sets), [14, 14, 14])
        XCTAssertEqual(passingLog.blocks.flatMap(\.exercises).map { $0.sets.count }, [14, 14, 14])
        XCTAssertTrue(OverallRankTrialRunner.shared.evaluatePerformance(passingLog, against: definition))
        XCTAssertFalse(OverallRankTrialRunner.shared.evaluatePerformance(failingLog, against: definition))
    }

    func testForgeDraftMapsToThreeRoundChipperPerformanceStandards() {
        let definition = OverallRankTrialDefinitions.forge
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let passingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_000),
            passing: true
        )
        let failingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_000),
            passing: false
        )

        XCTAssertEqual(draft.title, "The Forge")
        XCTAssertEqual(draft.estimatedMinutes, 35)
        XCTAssertEqual(draft.blocks.map(\.kind), [.cardio, .strength, .bodyweight])
        XCTAssertEqual(draft.blocks.first?.cardioType, .run)
        XCTAssertEqual(draft.blocks.flatMap(\.prescriptions).map(\.sets), [3, 3, 3, 3])
        XCTAssertEqual(passingLog.blocks.flatMap(\.exercises).map { $0.sets.count }, [3, 3, 3, 3])
        XCTAssertTrue(OverallRankTrialRunner.shared.evaluatePerformance(passingLog, against: definition))
        XCTAssertFalse(OverallRankTrialRunner.shared.evaluatePerformance(failingLog, against: definition))
    }

    func testReckoningDraftMapsToHybridLifterPerformanceStandards() {
        let definition = OverallRankTrialDefinitions.reckoning
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let passingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_600),
            passing: true
        )
        let failingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_600),
            passing: false
        )

        XCTAssertEqual(draft.title, "The Reckoning")
        XCTAssertEqual(draft.estimatedMinutes, 42)
        XCTAssertEqual(draft.blocks.map(\.kind), [.cardio, .strength, .bodyweight, .carry])
        XCTAssertEqual(draft.blocks.first?.cardioType, .run)
        XCTAssertEqual(draft.blocks.flatMap(\.prescriptions).map(\.sets), [1, 2, 2, 2, 2])
        XCTAssertEqual(passingLog.blocks.flatMap(\.exercises).map { $0.sets.count }, [1, 2, 2, 2, 2])
        XCTAssertTrue(OverallRankTrialRunner.shared.evaluatePerformance(passingLog, against: definition))
        XCTAssertFalse(OverallRankTrialRunner.shared.evaluatePerformance(failingLog, against: definition))
    }

    func testGauntletDraftMapsToEightStationPerformanceStandards() {
        let definition = OverallRankTrialDefinitions.gauntlet
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100)
        )
        let passingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 3_000),
            passing: true
        )
        let failingLog = OverallRankTrialRunner.shared.performanceLog(
            from: draft,
            userId: "u1",
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 3_000),
            passing: false
        )

        assertCatalogBacked(definition)
        XCTAssertEqual(draft.title, "The Gauntlet")
        XCTAssertEqual(draft.estimatedMinutes, 50)
        XCTAssertEqual(draft.blocks.map(\.kind), [.cardio, .carry, .strength, .bodyweight, .skill])
        XCTAssertEqual(draft.blocks.first?.cardioType, .run)
        XCTAssertEqual(draft.blocks.flatMap(\.prescriptions).count, 8)
        XCTAssertEqual(draft.blocks.flatMap(\.prescriptions).map(\.sets), Array(repeating: 1, count: 8))
        XCTAssertEqual(
            Set(draft.blocks.flatMap(\.prescriptions).compactMap(\.movementId)),
            Set(definition.performanceStandards.map(\.movementId))
        )
        XCTAssertEqual(passingLog.blocks.flatMap(\.exercises).map { $0.sets.count }, Array(repeating: 1, count: 8))
        XCTAssertTrue(OverallRankTrialRunner.shared.evaluatePerformance(passingLog, against: definition))
        XCTAssertFalse(OverallRankTrialRunner.shared.evaluatePerformance(failingLog, against: definition))
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
            completedAt: Date(timeIntervalSince1970: 2_000),
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

    func testPassedForgeAdvancesToHoned() async throws {
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
            completedAt: Date(timeIntervalSince1970: 2_000),
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
        XCTAssertEqual(result.progress.currentRank, .honed)
        XCTAssertEqual(store.load(userId: "u1").currentRank, .honed)
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
            completedAt: Date(timeIntervalSince1970: 2_000),
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
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertNil(second.completionResult)
        XCTAssertEqual(progress.currentRank, .honed)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedReckoningLogsAttemptAndReceiptButDoesNotAdvancePastHoned() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .honed, attempts: []),
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
        XCTAssertEqual(store.load(userId: "u1").currentRank, .honed)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedReckoningAdvancesToForgedExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .honed, attempts: []),
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
        XCTAssertEqual(first.progress.currentRank, .forged)
        XCTAssertEqual(first.rankUp?.toTier, .forged)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertNil(second.completionResult)
        XCTAssertEqual(progress.currentRank, .forged)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedGauntletLogsAttemptAndReceiptButDoesNotAdvancePastForged() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: []),
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
        XCTAssertEqual(store.load(userId: "u1").currentRank, .forged)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 1)
    }

    func testPassedGauntletAdvancesToVeteranExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: []),
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
        XCTAssertEqual(first.progress.currentRank, .veteran)
        XCTAssertEqual(first.rankUp?.toTier, .veteran)
        XCTAssertTrue(second.wasDuplicate)
        XCTAssertFalse(second.didAdvanceRank)
        XCTAssertNil(second.completionResult)
        XCTAssertEqual(progress.currentRank, .veteran)
        XCTAssertEqual(progress.attempts.count, 1)
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
        Dictionary(uniqueKeysWithValues: definition.skillStandards.map { standard in
            (standard.skillId, standard.minimumTier)
        })
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
    }

    private func makeServices(database: MockDatabaseService) -> ServiceContainer {
        ServiceContainer(
            auth: MockAuthService(),
            database: database,
            analytics: AnalyticsService.shared,
            subscription: MockSubscriptionService(),
            paywall: MockPaywallService(),
            user: UserService.shared,
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
            attribute: MockAttributeService(),
            photoXP: MockPhotoXPService()
        )
    }
}
