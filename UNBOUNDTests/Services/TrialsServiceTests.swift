// UNBOUNDTests/Services/TrialsServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class WeeklyVowsServiceTests: XCTestCase {

    var suiteName: String!
    var defaults: UserDefaults!
    var store: WeeklyVowsStore!
    var attribute: MockAttributeService!
    var service: WeeklyVowsService!

    override func setUp() {
        super.setUp()
        suiteName = "WeeklyVowsServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = WeeklyVowsStore(defaults: defaults)
        attribute = MockAttributeService()
        service = WeeklyVowsService(
            store: store,
            attribute: attribute,
            recentLogsProvider: { _ in [] }
        )
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func seedAttribute(power: Double = 70, control: Double = 30) {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        for axis in AttributeKey.allCases {
            let value: Double = {
                switch axis {
                case .power: return power
                case .control: return control
                default: return 50
                }
            }()
            profile.set(axis, AttributeValue(xp: AttributeLevelCurve.xpRequired(forLevel: Int(value)), lastContributionAt: .now))
        }
        attribute.profileByUser["u-1"] = profile
    }

    // MARK: - T6.2 ensureCurrentWeek

    func testEnsureCurrentWeekGenerates3Cards() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentWeekCards.count, 3)
        XCTAssertNotNil(state.currentWeekStart)
    }

    func testEnsureCurrentWeekIdempotentWithinWeek() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let stateA = service.state(userId: "u-1")
        await service.ensureCurrentWeek(userId: "u-1")
        let stateB = service.state(userId: "u-1")
        XCTAssertEqual(stateA, stateB)
    }

    // MARK: - T6.3 pickCard + skipThisWeek

    func testPickCardPersistsWeeklyVow() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)

        service.pickVowCard(overdrive, userId: "u-1")
        let state = service.state(userId: "u-1")

        XCTAssertNotNil(state.currentVow)
        XCTAssertEqual(state.currentVow?.chosenCard.id, overdrive.id)
        XCTAssertEqual(state.currentVow?.capstoneState, .pending)
    }

    func testPickCardFiresNotification() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)

        let exp = expectation(forNotification: .weeklyVowPicked, object: nil)
        service.pickVowCard(overdrive, userId: "u-1")
        await fulfillment(of: [exp], timeout: 1.0)
    }

    func testSkipThisWeekSetsFlag() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        service.skipThisWeek(userId: "u-1")
        let state = service.state(userId: "u-1")

        XCTAssertTrue(state.skippedCurrentWeek)
        XCTAssertNil(state.currentVow)
        XCTAssertTrue(state.weeklyVowPenaltyLedger.isEmpty)
        XCTAssertEqual(state.pendingVowDebtXP, 0)
    }

    // MARK: - completeVow

    func testCompleteVowDoesNotSealWithoutSavedWorkoutReceipt() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        service.completeVow(userId: "u-1", at: .now)

        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentVow?.capstoneState, .windowOpen)
        XCTAssertNil(state.completionsByAxis[.power])
        XCTAssertNil(state.completionsByCardKind[.overdrive])
        XCTAssertTrue(state.weeklyVowCompletionLedger.isEmpty)
    }

    func testCompleteVowDoesNotFireCompletionNotification() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let exp = expectation(forNotification: .weeklyVowCompleted, object: nil)
        exp.isInverted = true
        service.completeVow(userId: "u-1", at: .now)
        await fulfillment(of: [exp], timeout: 0.1)
    }

    func testSkippingPickedVowAddsPenalty() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")

        service.skipThisWeek(userId: "u-1")

        let state = service.state(userId: "u-1")
        XCTAssertTrue(state.skippedCurrentWeek)
        XCTAssertNil(state.currentVow)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.count, 1)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.vowId, overdrive.id)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.weekStart, state.currentWeekStart)
        XCTAssertEqual(state.pendingVowDebtXP, overdrive.bet.oweXP)
    }

    /// Spec §10 switching grace (Binding Vows v2 Core-2): switching away from an
    /// UNTOUCHED vow is free (mis-tap protection). Both legacy cards carry no
    /// in-app progress, so the repick must NOT owe a stake. (Pre-Core-2 this
    /// penalized unconditionally; the grace rule supersedes that.)
    func testRepickingAfterUntouchedVowIsFree() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        let apex = seedLegacyWeekCard(.apex)
        service.pickVowCard(overdrive, userId: "u-1")

        service.pickVowCard(apex, userId: "u-1")

        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentVow?.id, apex.id)
        XCTAssertTrue(state.weeklyVowPenaltyLedger.isEmpty)
        XCTAssertEqual(state.pendingVowDebtXP, 0)
    }

    // MARK: - trainable vow routing

    func testTrainingDraftForCurrentVowUsesWeeklyVowRouteAndRealWork() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = service.trainingDraftForCurrentVow(userId: "u-1", date: Date(timeIntervalSince1970: 1_700_000_000))

        let unwrapped = try! XCTUnwrap(draft)
        XCTAssertEqual(unwrapped.userId, "u-1")
        XCTAssertEqual(unwrapped.source, .vow)
        XCTAssertEqual(unwrapped.programId, "weekly-vow:\(overdrive.id)")
        XCTAssertFalse(unwrapped.blocks.isEmpty)
        XCTAssertFalse(unwrapped.blocks.flatMap(\.prescriptions).isEmpty)
        XCTAssertTrue(unwrapped.blocks.flatMap(\.prescriptions).allSatisfy { !$0.exerciseName.isEmpty })
        XCTAssertGreaterThan(unwrapped.estimatedMinutes, 0)
    }

    func testTrainingDraftPrescriptionsCarryMovementCatalogMetadataAndVowCopy() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")

        for card in service.state(userId: "u-1").currentWeekCards {
            let vow = WeeklyVow(
                id: card.id,
                userId: "u-1",
                weekStart: service.state(userId: "u-1").currentWeekStart!,
                chosenCard: card,
                capstoneState: .pending,
                completedAt: nil
            )
            let draft = service.trainingDraft(for: vow, date: Date(timeIntervalSince1970: 1_700_000_000))
            let prescriptions = draft.blocks.flatMap(\.prescriptions)

            XCTAssertFalse(prescriptions.isEmpty)
            assertNoLegacyWeeklyCopy(
                [draft.title] +
                draft.blocks.flatMap { [$0.title, $0.subtitle ?? "", $0.notes ?? ""] } +
                prescriptions.flatMap { [$0.exerciseName, $0.notes ?? ""] }
            )

            for prescription in prescriptions {
                let movementId = try! XCTUnwrap(prescription.movementId)
                let definition = try! XCTUnwrap(MovementCatalog.definition(for: movementId))

                XCTAssertEqual(prescription.rankStandardMovementId, definition.rankStandardMovementId)
                XCTAssertEqual(prescription.exerciseName, definition.displayName)
                XCTAssertEqual(prescription.muscleGroups, definition.muscleGroups)
                XCTAssertFalse(movementId.hasPrefix("unresolved."))

                if definition.role == .canonicalExercise {
                    XCTAssertTrue(
                        MovementCatalog.isProgramCompatible(definition, style: .hybrid, userEquipment: [.fullGym]),
                        "\(definition.displayName) should remain full-gym compatible."
                    )
                }
            }
        }
    }

    func testExplosivenessOverdriveUsesSameSlotCatalogFallbackForBoxJumpIntent() {
        let card = WeeklyVowCard(
            id: "weekly-vow-W5-overdrive",
            kind: .overdrive,
            theme: .axis(.explosiveness),
            displayName: "One Strike",
            blurb: "A controlled finisher after training.",
            capstone: WeeklyVowProof(
                displayName: "Output Proof",
                description: "8 max-effort box jumps.",
                evaluation: .autoFromLog(.reps(8, exerciseName: "box jump"))
            ),
            prescription: WeeklyVowPrescription(
                placement: .afterWorkout,
                minMinutes: 6,
                maxMinutes: 12,
                minRPE: 7,
                maxRPE: 8
            )
        )
        let vow = WeeklyVow(
            id: card.id,
            userId: "u-1",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            chosenCard: card,
            capstoneState: .pending,
            completedAt: nil
        )

        let draft = service.trainingDraft(for: vow, date: Date(timeIntervalSince1970: 1_700_000_000))
        let prescription = try! XCTUnwrap(draft.blocks.flatMap(\.prescriptions).first)
        let movementId = try! XCTUnwrap(prescription.movementId)
        let definition = try! XCTUnwrap(MovementCatalog.definition(for: movementId))

        XCTAssertEqual(definition.id, "exercise.jump-squat")
        XCTAssertEqual(definition.movementSlot, .squat)
        XCTAssertEqual(prescription.rankStandardMovementId, definition.rankStandardMovementId)
        XCTAssertEqual(prescription.rpe, 7)
        XCTAssertEqual(draft.estimatedMinutes, 9)
        XCTAssertTrue(MovementCatalog.isProgramCompatible(definition, style: .hybrid, userEquipment: [.bodyweight]))
    }

    func testAxisVowDraftsUseCatalogBackedMultiMovementTemplates() {
        for axis in AttributeKey.allCases {
            for kind in [WeeklyVowKind.ember, .overdrive] {
                let card = makeAxisCard(kind: kind, axis: axis)
                let vow = WeeklyVow(
                    id: card.id,
                    userId: "u-1",
                    weekStart: Date(timeIntervalSince1970: 1_700_000_000),
                    chosenCard: card,
                    capstoneState: .pending,
                    completedAt: nil
                )

                let draft = service.trainingDraft(for: vow, date: Date(timeIntervalSince1970: 1_700_000_000))
                let prescriptions = draft.blocks.flatMap(\.prescriptions)

                XCTAssertGreaterThanOrEqual(prescriptions.count, 2, "\(kind.displayName) \(axis.displayName) should not collapse into one generic movement.")
                XCTAssertLessThanOrEqual(draft.estimatedMinutes, card.prescription?.maxMinutes ?? 60)
                assertNoLegacyWeeklyCopy(
                    [draft.title] +
                    draft.blocks.flatMap { [$0.title, $0.subtitle ?? "", $0.notes ?? ""] } +
                    prescriptions.flatMap { [$0.exerciseName, $0.notes ?? ""] }
                )

                for prescription in prescriptions {
                    let movementId = try! XCTUnwrap(prescription.movementId)
                    let definition = try! XCTUnwrap(MovementCatalog.definition(for: movementId))
                    XCTAssertFalse(definition.id.hasPrefix("unresolved."))
                    XCTAssertEqual(prescription.exerciseName, definition.displayName)
                }
            }
        }
    }

    func testApexDraftsFollowTheRotatingWorkoutInsteadOfOneGenericCircuit() {
        var signatures: Set<String> = []

        for workout in PrestigeCapstoneCatalog.rotation {
            let card = WeeklyVowCard(
                id: "weekly-vow-test-apex-\(workout.displayName)",
                kind: .apex,
                theme: .wildcard,
                displayName: "\(workout.displayName) Standard",
                blurb: "A dedicated weekend workout.",
                capstone: workout,
                prescription: WeeklyVowPrescription(
                    placement: .dedicatedSession,
                    minMinutes: 20,
                    maxMinutes: 45,
                    minRPE: 8,
                    maxRPE: 9
                )
            )
            let vow = WeeklyVow(
                id: card.id,
                userId: "u-1",
                weekStart: Date(timeIntervalSince1970: 1_700_000_000),
                chosenCard: card,
                capstoneState: .pending,
                completedAt: nil
            )

            let draft = service.trainingDraft(for: vow, date: Date(timeIntervalSince1970: 1_700_000_000))
            let prescriptions = draft.blocks.flatMap(\.prescriptions)
            let signature = prescriptions.map(\.exerciseName).joined(separator: "|")
            signatures.insert(signature)

            XCTAssertFalse(prescriptions.isEmpty)
            XCTAssertGreaterThanOrEqual(prescriptions.count, 3)
            XCTAssertEqual(workout.evaluation, .manualClaim)
            XCTAssertFalse(workout.description.localizedCaseInsensitiveContains("proof"))
            for prescription in prescriptions {
                let movementId = try! XCTUnwrap(prescription.movementId)
                XCTAssertNotNil(MovementCatalog.definition(for: movementId), "Missing catalog definition for \(prescription.exerciseName)")
            }
        }

        XCTAssertGreaterThanOrEqual(signatures.count, 4)
    }

    func testRecordCompletedVowWorkWaitsForSavedPerformanceLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)

        var unsavedResult = TrainingCompletionResult()
        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: unsavedResult))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

        openCurrentVow()
        let exp = expectation(forNotification: .weeklyVowCompleted, object: nil)
        unsavedResult.savedPerformanceLogId = log.id
        unsavedResult.bodyweightKg = 70
        let completed = service.recordCompletedVowWork(performanceLog: log, completionResult: unsavedResult)
        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertEqual(completed?.vow.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.completedAt, log.completedAt)
        XCTAssertEqual(service.state(userId: "u-1").completionsByCardKind[.overdrive], 1)
        XCTAssertEqual(service.state(userId: "u-1").completionsByAxis[.power], 1)
    }

    func testRecordCompletedVowWorkRequiresOpenWindowBeforeSavedWorkCanSeal() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkOpensWindowForSavedLogAfterSaturday() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        let weekStart = Date(timeIntervalSince1970: 1_700_000_000)
        let completedAt = weekStart.addingTimeInterval((5 * 86_400) + 60)
        var state = WeeklyVowsState.empty
        state.currentWeekStart = weekStart
        state.currentWeekCards = [overdrive]
        state.currentVow = WeeklyVow(
            id: overdrive.id,
            userId: "u-1",
            weekStart: weekStart,
            chosenCard: overdrive,
            capstoneState: .pending,
            completedAt: nil
        )
        store.save(state, userId: "u-1")

        let vow = try! XCTUnwrap(service.state(userId: "u-1").currentVow)
        let draft = service.trainingDraft(for: vow, date: completedAt)
        let log = makePerformanceLog(from: draft, completedAt: completedAt)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        let receipt = service.recordCompletedVowWork(performanceLog: log, completionResult: result)

        XCTAssertEqual(receipt?.vow.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.performanceLogId, log.id)
    }

    func testRecordCompletedVowWorkRejectsAutoLogProofMiss() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        var log = makePerformanceLog(from: draft)
        for setIndex in log.blocks[0].exercises[0].sets.indices {
            log.blocks[0].exercises[0].sets[setIndex].reps = 1
            log.blocks[0].exercises[0].sets[setIndex].weightKg = 5
            log.blocks[0].exercises[0].sets[setIndex].holdSeconds = 1
            log.blocks[0].exercises[0].sets[setIndex].durationSeconds = 1
            log.blocks[0].exercises[0].sets[setIndex].distanceMeters = 1
            log.blocks[0].exercises[0].sets[setIndex].calories = 1
        }
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkReturnsReceiptBasedVowBonusForMatchingSavedLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        let receipt = service.recordCompletedVowWork(performanceLog: log, completionResult: result)

        let unwrapped = try! XCTUnwrap(receipt)
        XCTAssertEqual(unwrapped.vow.id, overdrive.id)
        XCTAssertEqual(unwrapped.vow.capstoneState, .completed)
        XCTAssertEqual(unwrapped.performanceLogId, log.id)
        XCTAssertEqual(unwrapped.callout.vowId, overdrive.id)
        XCTAssertEqual(unwrapped.callout.performanceLogId, log.id)
        XCTAssertEqual(unwrapped.callout.cardKind, .overdrive)
        XCTAssertEqual(unwrapped.callout.title, "\(overdrive.displayName) Cleared")
        XCTAssertEqual(unwrapped.callout.shareTitle, "Binding Vow Cleared")
        XCTAssertEqual(unwrapped.callout.shareSubtitle, "\(overdrive.displayName) - \(overdrive.capstone.displayName)")
        XCTAssertEqual(unwrapped.callout.proofName, overdrive.capstone.displayName)
        XCTAssertEqual(unwrapped.callout.completionBonus, unwrapped.completionBonus)
        assertNoLegacyWeeklyCopy([
            unwrapped.callout.title,
            unwrapped.callout.subtitle,
            unwrapped.callout.proofName,
            unwrapped.callout.shareTitle,
            unwrapped.callout.shareSubtitle
        ])
        XCTAssertEqual(unwrapped.completionBonus.overallLevelXP, overdrive.bet.winXP)
        XCTAssertEqual(unwrapped.completionBonus.badgeProgress.displayText, "Finisher Vow I 1/3")
        XCTAssertEqual(unwrapped.completionBonus.cosmeticProgress.displayText, "Finisher Vow Mark 1/5")
        XCTAssertNil(unwrapped.completionBonus.shareCard)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.count, 1)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.performanceLogId, log.id)

        let summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: result,
            sourceName: "Binding Vow",
            weeklyVowCallout: unwrapped.callout
        )
        XCTAssertEqual(summary.weeklyVowCallout, unwrapped.callout)
        XCTAssertFalse(summary.hasShareableMoment)
        XCTAssertTrue(summary.attributeDeltas.isEmpty)
    }

    func testRecordCompletedApexVowCarriesShareCardMetadataOnlyAfterSavedLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let apex = seedLegacyWeekCard(.apex)
        service.pickVowCard(apex, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: result))

        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70
        let receipt = service.recordCompletedVowWork(performanceLog: log, completionResult: result)

        let unwrapped = try! XCTUnwrap(receipt)
        let shareCard = try! XCTUnwrap(unwrapped.completionBonus.shareCard)
        XCTAssertEqual(unwrapped.completionBonus.overallLevelXP, 240)
        XCTAssertEqual(unwrapped.callout.shareSubtitle, "\(apex.displayName) - \(apex.capstone.displayName)")
        XCTAssertEqual(shareCard.title, "\(apex.displayName) Cleared")
        XCTAssertEqual(shareCard.subtitle, "Binding Vow - \(apex.capstone.displayName)")
        XCTAssertEqual(shareCard.metadata["performanceLogId"], log.id)
        XCTAssertEqual(shareCard.metadata["cardKind"], "apex")
        assertNoLegacyWeeklyCopy([
            unwrapped.callout.title,
            unwrapped.callout.shareTitle,
            unwrapped.callout.shareSubtitle,
            shareCard.title,
            shareCard.subtitle
        ])

        let summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: result,
            sourceName: "Binding Vow",
            weeklyVowCallout: unwrapped.callout
        )
        XCTAssertTrue(summary.hasShareableMoment)
    }

    func testRecordCompletedApexVowRequiresRealSavedWorkBeforeShareCard() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let apex = seedLegacyWeekCard(.apex)
        service.pickVowCard(apex, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let emptyLog = makeEmptyPerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = emptyLog.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: emptyLog, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)

        let summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: emptyLog,
            completionResult: result,
            sourceName: "Binding Vow",
            weeklyVowCallout: nil
        )
        XCTAssertFalse(summary.hasShareableMoment)
    }

    func testRecordCompletedApexVowRequiresEveryPrescribedMovement() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let apex = seedLegacyWeekCard(.apex)
        service.pickVowCard(apex, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        var partialLog = makePerformanceLog(from: draft)
        partialLog.blocks[0].exercises.removeLast()
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = partialLog.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: partialLog, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedApexVowRequiresPrescribedSetVolume() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let apex = seedLegacyWeekCard(.apex)
        service.pickVowCard(apex, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        var partialLog = makePerformanceLog(from: draft)
        for exerciseIndex in partialLog.blocks[0].exercises.indices {
            partialLog.blocks[0].exercises[exerciseIndex].sets = Array(partialLog.blocks[0].exercises[exerciseIndex].sets.prefix(1))
        }
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = partialLog.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: partialLog, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkIgnoresUnrelatedPerformanceLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        var unrelated = makePerformanceLog(from: draft)
        unrelated.programId = "custom-workout"
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = unrelated.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: unrelated, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertNil(service.state(userId: "u-1").completionsByCardKind[.overdrive])
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkIgnoresSavedLogWithoutActualCompletedWork() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makeEmptyPerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkDoesNotDuplicateCompletionOrBonusForSameReceipt() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        let first = service.recordCompletedVowWork(performanceLog: log, completionResult: result)
        var duplicateResult = result
        duplicateResult.wasAlreadyCompleted = true
        let duplicate = service.recordCompletedVowWork(performanceLog: log, completionResult: duplicateResult)

        XCTAssertNotNil(first)
        XCTAssertNil(duplicate)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").completionsByCardKind[.overdrive], 1)
        XCTAssertEqual(service.state(userId: "u-1").completionsByAxis[.power], 1)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.count, 1)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.bonus.overallLevelXP, overdrive.bet.winXP)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.bonus, first?.completionBonus)
    }

    func testMissedPickedVowAddsPenaltyThatTaxesNextVowBonus() async {
        seedAttribute()
        // EXPAND step (Core-1): debt now comes from the card's VowBet, not the
        // legacy kind. Give the missed card an explicit large bet.
        let missedCard = WeeklyVowCard(
            id: "weekly-vow-W1-apex",
            kind: .apex,
            theme: .wildcard,
            displayName: "Gauntlet Vow",
            blurb: "A hard standalone workout.",
            capstone: WeeklyVowProof(
                displayName: "Iron Gauntlet",
                description: "A hard full-body workout.",
                evaluation: .manualClaim
            ),
            prescription: WeeklyVowPrescription(
                placement: .dedicatedSession,
                minMinutes: 20,
                maxMinutes: 45,
                minRPE: 8,
                maxRPE: 9
            ),
            lane: .engine,
            bet: .large,
            target: VowTarget(count: 1, noun: "session")
        )
        var stale = WeeklyVowsState.empty
        stale.currentWeekStart = Date(timeIntervalSince1970: 0)
        stale.currentVow = WeeklyVow(
            id: missedCard.id,
            userId: "u-1",
            weekStart: stale.currentWeekStart!,
            chosenCard: missedCard,
            capstoneState: .windowOpen,
            completedAt: nil
        )
        store.save(stale, userId: "u-1")

        await service.ensureCurrentWeek(userId: "u-1")

        var state = service.state(userId: "u-1")
        XCTAssertNil(state.currentVow)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.count, 1)
        XCTAssertEqual(state.weeklyVowPenaltyLedger.first?.penaltyXP, VowBet.large.oweXP)
        XCTAssertEqual(state.pendingVowDebtXP, VowBet.large.oweXP)

        // The generator's overdrive card carries the default medium bet.
        let overdrive = seedLegacyWeekCard(.overdrive)
        service.pickVowCard(overdrive, userId: "u-1")
        openCurrentVow()

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id
        result.bodyweightKg = 70

        let receipt = try! XCTUnwrap(service.recordCompletedVowWork(performanceLog: log, completionResult: result))

        // v2: win pays the card's bet winXP in full; debt is NOT deducted from the
        // win (cleared only by earned training XP).
        XCTAssertNil(receipt.completionBonus.baseOverallLevelXP)
        XCTAssertNil(receipt.completionBonus.penaltyAppliedXP)
        XCTAssertEqual(receipt.completionBonus.overallLevelXP, overdrive.bet.winXP)
        state = service.state(userId: "u-1")
        XCTAssertEqual(state.pendingVowDebtXP, VowBet.large.oweXP)
    }

    func testPenaltyDedupeIncludesVowWeekStart() async {
        seedAttribute()
        let card = WeeklyVowCard(
            id: "weekly-vow-W1-apex",
            kind: .apex,
            theme: .wildcard,
            displayName: "Gauntlet Vow",
            blurb: "A hard standalone workout.",
            capstone: WeeklyVowProof(
                displayName: "Iron Gauntlet",
                description: "A hard full-body workout.",
                evaluation: .manualClaim
            ),
            prescription: WeeklyVowPrescription(
                placement: .dedicatedSession,
                minMinutes: 20,
                maxMinutes: 45,
                minRPE: 8,
                maxRPE: 9
            )
        )
        var stale = WeeklyVowsState.empty
        let priorWeekStart = Date(timeIntervalSince1970: 0)
        let repeatedWeekStart = Date(timeIntervalSince1970: 1_000)
        stale.currentWeekStart = repeatedWeekStart
        stale.currentVow = WeeklyVow(
            id: card.id,
            userId: "u-1",
            weekStart: repeatedWeekStart,
            chosenCard: card,
            capstoneState: .windowOpen,
            completedAt: nil
        )
        stale.weeklyVowPenaltyLedger = [
            WeeklyVowPenaltyLedgerEntry(
                vowId: card.id,
                cardKind: card.kind,
                weekStart: priorWeekStart,
                missedAt: priorWeekStart,
                penaltyXP: card.bet.oweXP
            )
        ]
        stale.pendingVowDebtXP = card.bet.oweXP
        store.save(stale, userId: "u-1")

        await service.ensureCurrentWeek(userId: "u-1")

        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.weeklyVowPenaltyLedger.count, 2)
        XCTAssertEqual(state.pendingVowDebtXP, card.bet.oweXP * 2)
    }

    // MARK: - evaluateVowProofFromLog + checkVowWindow

    func testEvaluateCapstoneFromLogNoOpWhenPending() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        // Force the Overdrive card to use a known autoFromLog criterion.
        var overdrive = seedLegacyWeekCard(.overdrive)
        overdrive = WeeklyVowCard(
            id: overdrive.id, kind: overdrive.kind, theme: overdrive.theme,
            displayName: overdrive.displayName, blurb: overdrive.blurb,
            capstone: TrialCapstone(
                displayName: "Test",
                description: "Test",
                evaluation: .autoFromLog(.reps(5, exerciseName: "pullup"))
            ),
            prescription: overdrive.prescription
        )
        service.pickVowCard(overdrive, userId: "u-1")
        // currentVow.capstoneState is .pending, so this should not fire.
        let history = [
            ExerciseLogEntry(
                id: "e1", exerciseName: "pullup",
                plannedSets: 1, plannedReps: "10",
                sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 10, rpe: nil, isWarmup: false)],
                skipped: false, notes: nil
            )
        ]
        await service.evaluateVowProofFromLog(userId: "u-1", history: history, bodyweightKg: 70)
        XCTAssertNotEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
    }

    // MARK: - Task 1.4: broken vow writes debt; completion no longer pays debt

    func testBrokenVowAddsDebtNotNextVowPenalty() {
        // Pick a vow, then roll the week without completing → debt accrues.
        let card = makeAxisCard(kind: .apex, axis: .power)
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: "u-1")
        service.pickVowCard(card, userId: "u-1")

        // Force a stale week so ensureCurrentWeek rolls + marks missed.
        var picked = service.state(userId: "u-1")
        picked.currentWeekStart = Date(timeIntervalSince1970: 1) // ancient
        store.save(picked, userId: "u-1")

        let exp = expectation(description: "rolled")
        Task { await service.ensureCurrentWeek(userId: "u-1"); exp.fulfill() }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(
            service.state(userId: "u-1").pendingVowDebtXP,
            card.bet.oweXP
        )
    }

    // MARK: - Core-1: broken-vow debt comes from the bet, not the kind

    func testBrokenVowDebtUsesBetOweXP() {
        let card = makeVowCard(lane: .engine, bet: .large)
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: "u-1")
        service.pickVowCard(card, userId: "u-1")
        var picked = service.state(userId: "u-1")
        picked.currentWeekStart = Date(timeIntervalSince1970: 1)
        store.save(picked, userId: "u-1")
        let exp = expectation(description: "rolled")
        Task { await service.ensureCurrentWeek(userId: "u-1"); exp.fulfill() }
        wait(for: [exp], timeout: 5)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.large.oweXP) // 300
    }

    func testEvaluateCapstoneFromLogDoesNotCompleteWhenWindowOpenWithoutSavedReceipt() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        var overdrive = seedLegacyWeekCard(.overdrive)
        overdrive = WeeklyVowCard(
            id: overdrive.id, kind: overdrive.kind, theme: overdrive.theme,
            displayName: overdrive.displayName, blurb: overdrive.blurb,
            capstone: TrialCapstone(
                displayName: "Test",
                description: "Test",
                evaluation: .autoFromLog(.reps(5, exerciseName: "pullup"))
            ),
            prescription: overdrive.prescription
        )
        service.pickVowCard(overdrive, userId: "u-1")

        // Force vow window open by directly mutating state.
        var state = service.state(userId: "u-1")
        state.currentVow?.capstoneState = .windowOpen
        store.save(state, userId: "u-1")

        let history = [
            ExerciseLogEntry(
                id: "e1", exerciseName: "pullup",
                plannedSets: 1, plannedReps: "10",
                sets: [SetLog(id: "s1", setNumber: 1, weightKg: nil, reps: 10, rpe: nil, isWarmup: false)],
                skipped: false, notes: nil
            )
        ]
        await service.evaluateVowProofFromLog(userId: "u-1", history: history, bodyweightKg: 70)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .windowOpen)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    // MARK: - T6.6 equipTitle

    func testEquipTitleSetsEquippedField() {
        var state = WeeklyVowsState.empty
        let titleId = TitleID(path: .axis(.power), tier: .bronze)
        state.unlockedTitles = [titleId]
        store.save(state, userId: "u-1")

        service.equipTitle(titleId, userId: "u-1")
        XCTAssertEqual(service.state(userId: "u-1").equippedTitle, titleId)
    }

    func testEquipNilUnequips() {
        var state = WeeklyVowsState.empty
        let titleId = TitleID(path: .axis(.power), tier: .bronze)
        state.unlockedTitles = [titleId]
        state.equippedTitle = titleId
        store.save(state, userId: "u-1")

        service.equipTitle(nil, userId: "u-1")
        XCTAssertNil(service.state(userId: "u-1").equippedTitle)
    }

    func testCannotEquipUnUnlockedTitle() {
        let titleId = TitleID(path: .axis(.power), tier: .gold)
        service.equipTitle(titleId, userId: "u-1")
        XCTAssertNil(service.state(userId: "u-1").equippedTitle)
    }

    // MARK: - Core-2: lane completion (seal / fuel / auto-verify / switching grace)

    /// Seed the given card as the current week's offer and commit it.
    private func pickLaneVow(_ card: WeeklyVowCard, userId: String = "u-1") {
        var state = service.state(userId: userId)
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: userId)
        service.pickVowCard(card, userId: userId)
    }

    func testFuelTapIncrementsAndSealsAtTarget() {
        let card = makeVowCard(lane: .fuel, bet: .small, target: VowTarget(count: 3, noun: "fuel anchor"))
        pickLaneVow(card)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 1)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 2)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").completionsByLane[.fuel], 1)
    }

    func testFuelTapDoesNothingForNonFuelVow() {
        let card = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)

        service.logFuelAnchor(userId: "u-1")
        XCTAssertEqual(service.fuelAnchorCount(userId: "u-1"), 0)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)
    }

    func testSealVowPaysBetWinAndMarksCompleted() {
        let card = makeVowCard(lane: .recovery, bet: .medium, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)
        guard let vow = service.state(userId: "u-1").currentVow else {
            return XCTFail("expected a current vow")
        }

        service.sealVow(userId: "u-1", vow: vow, at: Date(timeIntervalSince1970: 1_700_001_000))
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.currentVow?.capstoneState, .completed)
        XCTAssertNotNil(state.currentVow?.completedAt)
        XCTAssertEqual(state.completionsByLane[.recovery], 1)
    }

    func testSealVowIsIdempotent() {
        let card = makeVowCard(lane: .recovery, bet: .medium, target: VowTarget(count: 1, noun: "recovery reset"))
        pickLaneVow(card)
        guard let vow = service.state(userId: "u-1").currentVow else {
            return XCTFail("expected a current vow")
        }
        service.sealVow(userId: "u-1", vow: vow, at: Date())
        service.sealVow(userId: "u-1", vow: vow, at: Date())
        XCTAssertEqual(service.state(userId: "u-1").completionsByLane[.recovery], 1)
    }

    func testRefreshAutoVerifiedVowSealsWhenLogsQualify() {
        let recoveryLog = WorkoutLog(
            id: "rec-1", userId: "u-1", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Recovery Reset",
            startedAt: Date(timeIntervalSince1970: 1_700_000_300),
            completedAt: Date(timeIntervalSince1970: 1_700_000_900),
            exerciseEntries: [], overallNotes: nil, overallRPE: 3, durationMinutes: 10
        )
        let autoService = WeeklyVowsService(
            store: store,
            attribute: attribute,
            recentLogsProvider: { _ in [recoveryLog] }
        )
        let card = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        var state = autoService.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: "u-1")
        autoService.pickVowCard(card, userId: "u-1")

        let exp = expectation(description: "auto-verify")
        Task { await autoService.refreshAutoVerifiedVow(userId: "u-1"); exp.fulfill() }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(autoService.state(userId: "u-1").currentVow?.capstoneState, .completed)
        XCTAssertEqual(autoService.state(userId: "u-1").completionsByLane[.recovery], 1)
    }

    func testRefreshAutoVerifiedVowDoesNotSealBelowTarget() {
        let recoveryLog = WorkoutLog(
            id: "rec-1", userId: "u-1", programId: "p", dayNumber: 1,
            plannedWorkoutName: "Recovery Reset",
            startedAt: Date(timeIntervalSince1970: 1_700_000_300),
            completedAt: Date(timeIntervalSince1970: 1_700_000_900),
            exerciseEntries: [], overallNotes: nil, overallRPE: 3, durationMinutes: 10
        )
        let autoService = WeeklyVowsService(
            store: store,
            attribute: attribute,
            recentLogsProvider: { _ in [recoveryLog] }  // only 1 log, target needs 2
        )
        let card = makeVowCard(lane: .recovery, bet: .medium, target: VowTarget(count: 2, noun: "recovery reset"))
        var state = autoService.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [card]
        store.save(state, userId: "u-1")
        autoService.pickVowCard(card, userId: "u-1")

        let exp = expectation(description: "auto-verify-below")
        Task { await autoService.refreshAutoVerifiedVow(userId: "u-1"); exp.fulfill() }
        wait(for: [exp], timeout: 5)

        XCTAssertEqual(autoService.state(userId: "u-1").currentVow?.capstoneState, .pending)
    }

    func testSwitchingBeforeProgressIsFree() {
        // Distinct ids: makeVowCard keys id on lane+bet.
        let a = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        let b = makeVowCard(lane: .engine, bet: .large, target: VowTarget(count: 1, noun: "easy cardio session"))
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [a, b]
        store.save(state, userId: "u-1")

        service.pickVowCard(a, userId: "u-1")
        service.pickVowCard(b, userId: "u-1")  // no progress on A → free switch

        XCTAssertEqual(service.state(userId: "u-1").currentVow?.id, b.id)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, 0)
    }

    func testSwitchingAfterProgressOwesStake() {
        // Distinct ids: makeVowCard keys id on lane+bet.
        let a = makeVowCard(lane: .fuel, bet: .medium, target: VowTarget(count: 5, noun: "fuel anchor"))
        let b = makeVowCard(lane: .recovery, bet: .small, target: VowTarget(count: 1, noun: "recovery reset"))
        var state = service.state(userId: "u-1")
        state.currentWeekStart = Date(timeIntervalSince1970: 1_700_000_000)
        state.currentWeekCards = [a, b]
        store.save(state, userId: "u-1")

        service.pickVowCard(a, userId: "u-1")
        service.logFuelAnchor(userId: "u-1")  // progress on A
        service.pickVowCard(b, userId: "u-1") // bound switch → owes A's stake

        XCTAssertEqual(service.state(userId: "u-1").currentVow?.id, b.id)
        XCTAssertEqual(service.state(userId: "u-1").pendingVowDebtXP, VowBet.medium.oweXP) // 250
    }

}
