import XCTest
@testable import UNBOUND

extension OverallRankTrialServiceTests {
    func testFailedTrialLogsAttemptAndReceiptButDoesNotAdvanceOverallRank() async throws {
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.firstLight
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
        let definition = OverallRankTrialDefinitions.firstLight
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

    func testFailedTheCountLogsAttemptAndReceiptButDoesNotAdvancePastNovice() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .novice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.theCount
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

    func testPassedTheCountAdvancesToApprenticeExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .novice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.theCount
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

    func testFailedTheForgingLogsAttemptAndReceiptButDoesNotAdvancePastApprentice() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.theForging
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            bodyweightKg: 100
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

    func testPassedTheForgingAdvancesToForged() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.theForging
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            bodyweightKg: 100
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

    func testPassedTheForgingAfterFailedAttemptIncludesComebackCallout() throws {
        let definition = OverallRankTrialDefinitions.theForging
        let failedAttempt = OverallRankTrialAttempt(
            id: "forging-failed-1",
            userId: "u1",
            definitionId: definition.id,
            targetRank: definition.targetRank,
            startedAt: Date(timeIntervalSince1970: 100),
            completedAt: Date(timeIntervalSince1970: 2_000),
            performanceLogId: "forging-failed-1",
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
            date: Date(timeIntervalSince1970: 3_000),
            bodyweightKg: 100
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
            store: store,
            bodyweightKg: 100
        )
        let result = try XCTUnwrap(completed)

        XCTAssertTrue(result.attempt.passed)
        XCTAssertTrue(result.didAdvanceRank)
        XCTAssertEqual(result.progress.currentRank, .forged)
        XCTAssertEqual(result.callouts.map(\.kind), [.comebackPass])
        XCTAssertEqual(result.callouts.first?.title, "Comeback clear")
        XCTAssertTrue(result.callouts.first?.message.contains("The Forging") == true)
        XCTAssertTrue(result.callouts.first?.message.contains("1 failed attempt") == true)
        XCTAssertEqual(store.load(userId: "u1").attempts.count, 2)
    }

    func testDuplicateTheForgingPerformanceLogDoesNotCreateSecondAttemptOrAdvanceAgain() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .apprentice, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.theForging
        let draft = OverallRankTrialRunner.shared.draft(
            for: definition,
            userId: "u1",
            date: Date(timeIntervalSince1970: 100),
            bodyweightKg: 100
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
        XCTAssertTrue(second.callouts.first?.message.contains("The Forging") == true)
        XCTAssertEqual(progress.currentRank, .forged)
        XCTAssertEqual(progress.attempts.count, 1)
    }

    func testFailedDeckOfProofLogsAttemptAndReceiptButDoesNotAdvancePastForged() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.deckOfProof
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

    func testPassedDeckOfProofAdvancesToVeteranExactlyOnceForDuplicatePerformanceLogId() async throws {
        store.save(
            OverallRankTrialProgress(highestPassedRank: .forged, attempts: []),
            userId: "u1"
        )
        let database = MockDatabaseService()
        let services = makeServices(database: database)
        let definition = OverallRankTrialDefinitions.deckOfProof
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
}
