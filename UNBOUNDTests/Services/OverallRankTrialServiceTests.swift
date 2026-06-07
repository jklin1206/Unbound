import XCTest
@testable import UNBOUND

@MainActor
final class OverallRankTrialServiceTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!
    var store: OverallRankTrialStore!

    struct RankTrialCase {
        let sourceRank: RankTitle
        let definition: OverallRankTrialDefinition
    }

    var upperRankTrialCases: [RankTrialCase] {
        [
            RankTrialCase(sourceRank: .master, definition: OverallRankTrialDefinitions.crucible),
            RankTrialCase(sourceRank: .vessel, definition: OverallRankTrialDefinitions.threshold),
            RankTrialCase(sourceRank: .unbound, definition: OverallRankTrialDefinitions.ascension)
        ]
    }

    var allRankTrialCases: [RankTrialCase] {
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

}
@MainActor
extension OverallRankTrialServiceTests {


    func readyEquipment() -> Set<MovementEquipment> {
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

    func equipment(for loadout: TrialLoadout) -> Set<MovementEquipment> {
        switch loadout {
        case .noGymField:
            return [.bodyweight, .openSpace, .pullupBar]
        case .homeKit:
            return [.bodyweight, .openSpace, .dumbbell, .kettlebell, .band, .pullupBar]
        case .gymHybrid:
            return readyEquipment()
        }
    }

    func resolvedTrial(
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

    func assertDraft(
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

    func assertDraftPassesAndFails(
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

    func assertCatalogBacked(
        _ definition: OverallRankTrialDefinition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for standard in definition.performanceStandards {
            XCTAssertNotNil(
                MovementCatalog.definition(for: standard.movementId),
                "\(standard.movementId) should resolve through MovementCatalog",
                file: file,
                line: line
            )
        }
    }

    func makeServices(database: MockDatabaseService) -> ServiceContainer {
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
