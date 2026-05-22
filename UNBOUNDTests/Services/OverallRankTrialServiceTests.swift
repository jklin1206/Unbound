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
