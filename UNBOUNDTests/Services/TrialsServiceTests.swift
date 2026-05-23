// UNBOUNDTests/Services/TrialsServiceTests.swift
import XCTest
@testable import UNBOUND

@MainActor
final class WeeklyVowsServiceTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: WeeklyVowsStore!
    private var attribute: MockAttributeService!
    private var service: WeeklyVowsService!

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

    private func seedAttribute(power: Double = 70, control: Double = 30) {
        var profile = AttributeProfile.empty(userId: "u-1", at: .now)
        for axis in AttributeKey.allCases {
            let value: Double = {
                switch axis {
                case .power: return power
                case .control: return control
                default: return 50
                }
            }()
            profile.set(axis, AttributeValue(peak: value, current: value, lastContributionAt: .now))
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
        let cards = service.state(userId: "u-1").currentWeekCards
        let overdrive = cards.first(where: { $0.kind == .overdrive })!

        service.pickVowCard(overdrive, userId: "u-1")
        let state = service.state(userId: "u-1")

        XCTAssertNotNil(state.currentVow)
        XCTAssertEqual(state.currentVow?.chosenCard.id, overdrive.id)
        XCTAssertEqual(state.currentVow?.capstoneState, .pending)
    }

    func testPickCardFiresNotification() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let cards = service.state(userId: "u-1").currentWeekCards
        let overdrive = cards.first(where: { $0.kind == .overdrive })!

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
    }

    // MARK: - completeVow

    func testCompleteVowIncrementsAxisCounter() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")
        service.completeVow(userId: "u-1", at: .now)
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.completionsByAxis[.power], 1)
    }

    func testCompleteVowIncrementsCardKindCounter() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")
        service.completeVow(userId: "u-1", at: .now)
        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.completionsByCardKind[.overdrive], 1)
    }

    func testCompleteVowSetsStateAndFiresNotification() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")
        let exp = expectation(forNotification: .weeklyVowCompleted, object: nil)
        service.completeVow(userId: "u-1", at: .now)
        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
    }

    func testCompleteVowUnlocksTitleAtThreshold() async {
        seedAttribute()
        // Pre-seed 2 completions on power axis (just below bronze threshold)
        var initial = WeeklyVowsState.empty
        initial.completionsByAxis[.power] = 2
        initial.completionsByCardKind[.overdrive] = 2
        store.save(initial, userId: "u-1")

        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let titleExp = expectation(forNotification: .titleUnlocked, object: nil)
        titleExp.expectedFulfillmentCount = 2  // axis + cardKind cross simultaneously
        service.completeVow(userId: "u-1", at: .now)
        await fulfillment(of: [titleExp], timeout: 1.0)

        let state = service.state(userId: "u-1")
        XCTAssertEqual(state.unlockedTitles.count, 2)
        XCTAssertTrue(state.unlockedTitles.contains(TitleID(path: .axis(.power), tier: .bronze)))
        XCTAssertTrue(state.unlockedTitles.contains(TitleID(path: .cardKind(.overdrive), tier: .bronze)))
    }

    // MARK: - trainable vow routing

    func testTrainingDraftForCurrentVowUsesWeeklyVowRouteAndRealWork() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = service.trainingDraftForCurrentVow(userId: "u-1", date: Date(timeIntervalSince1970: 1_700_000_000))

        let unwrapped = try! XCTUnwrap(draft)
        XCTAssertEqual(unwrapped.userId, "u-1")
        XCTAssertEqual(unwrapped.source, .custom)
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
            displayName: "Overdrive · Explosiveness Finisher",
            blurb: "Attach a sharp finisher after training and push your explosiveness output.",
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

    func testRecordCompletedVowWorkWaitsForSavedPerformanceLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)

        var unsavedResult = TrainingCompletionResult()
        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: unsavedResult))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)

        let exp = expectation(forNotification: .weeklyVowCompleted, object: nil)
        unsavedResult.savedPerformanceLogId = log.id
        let completed = service.recordCompletedVowWork(performanceLog: log, completionResult: unsavedResult)
        await fulfillment(of: [exp], timeout: 1.0)

        XCTAssertEqual(completed?.vow.capstoneState, .completed)
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.completedAt, log.completedAt)
        XCTAssertEqual(service.state(userId: "u-1").completionsByCardKind[.overdrive], 1)
        XCTAssertEqual(service.state(userId: "u-1").completionsByAxis[.power], 1)
    }

    func testRecordCompletedVowWorkReturnsReceiptBasedVowBonusForMatchingSavedLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id

        let receipt = service.recordCompletedVowWork(performanceLog: log, completionResult: result)

        let unwrapped = try! XCTUnwrap(receipt)
        XCTAssertEqual(unwrapped.vow.id, overdrive.id)
        XCTAssertEqual(unwrapped.vow.capstoneState, .completed)
        XCTAssertEqual(unwrapped.performanceLogId, log.id)
        XCTAssertEqual(unwrapped.callout.vowId, overdrive.id)
        XCTAssertEqual(unwrapped.callout.performanceLogId, log.id)
        XCTAssertEqual(unwrapped.callout.cardKind, .overdrive)
        XCTAssertEqual(unwrapped.callout.title, "Overdrive Vow Sealed")
        XCTAssertEqual(unwrapped.callout.shareTitle, "Weekly Vow Complete")
        XCTAssertEqual(unwrapped.callout.shareSubtitle, "Overdrive Vow - \(overdrive.capstone.displayName)")
        XCTAssertEqual(unwrapped.callout.proofName, overdrive.capstone.displayName)
        XCTAssertEqual(unwrapped.callout.completionBonus, unwrapped.completionBonus)
        assertNoLegacyWeeklyCopy([
            unwrapped.callout.title,
            unwrapped.callout.subtitle,
            unwrapped.callout.proofName,
            unwrapped.callout.shareTitle,
            unwrapped.callout.shareSubtitle
        ])
        XCTAssertEqual(unwrapped.completionBonus.overallLevelXP, 120)
        XCTAssertEqual(unwrapped.completionBonus.badgeProgress.displayText, "Overdrive Vow I 1/3")
        XCTAssertEqual(unwrapped.completionBonus.cosmeticProgress.displayText, "Overdrive Vow Finish 1/5")
        XCTAssertNil(unwrapped.completionBonus.shareCard)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.count, 1)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.performanceLogId, log.id)

        let summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: log,
            completionResult: result,
            sourceName: "Weekly Vow",
            weeklyVowCallout: unwrapped.callout
        )
        XCTAssertEqual(summary.weeklyVowCallout, unwrapped.callout)
        XCTAssertFalse(summary.hasShareableMoment)
        XCTAssertTrue(summary.attributeDeltas.isEmpty)
    }

    func testRecordCompletedApexVowCarriesShareCardMetadataOnlyAfterSavedLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let apex = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .apex })!
        service.pickVowCard(apex, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: result))

        result.savedPerformanceLogId = log.id
        let receipt = service.recordCompletedVowWork(performanceLog: log, completionResult: result)

        let unwrapped = try! XCTUnwrap(receipt)
        let shareCard = try! XCTUnwrap(unwrapped.completionBonus.shareCard)
        XCTAssertEqual(unwrapped.completionBonus.overallLevelXP, 240)
        XCTAssertEqual(unwrapped.callout.shareSubtitle, "Apex Vow - \(apex.capstone.displayName)")
        XCTAssertEqual(shareCard.title, "Apex Vow Cleared")
        XCTAssertEqual(shareCard.subtitle, "Apex Vow - \(apex.capstone.displayName)")
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
            sourceName: "Weekly Vow",
            weeklyVowCallout: unwrapped.callout
        )
        XCTAssertTrue(summary.hasShareableMoment)
    }

    func testRecordCompletedApexVowRequiresRealSavedWorkBeforeShareCard() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let apex = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .apex })!
        service.pickVowCard(apex, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let emptyLog = makeEmptyPerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = emptyLog.id

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: emptyLog, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)

        let summary = WorkoutRewardSequenceSummary.trainingReceipt(
            performanceLog: emptyLog,
            completionResult: result,
            sourceName: "Weekly Vow",
            weeklyVowCallout: nil
        )
        XCTAssertFalse(summary.hasShareableMoment)
    }

    func testRecordCompletedVowWorkIgnoresUnrelatedPerformanceLog() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        var unrelated = makePerformanceLog(from: draft)
        unrelated.programId = "custom-workout"
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = unrelated.id

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: unrelated, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)
        XCTAssertNil(service.state(userId: "u-1").completionsByCardKind[.overdrive])
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkIgnoresSavedLogWithoutActualCompletedWork() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makeEmptyPerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id

        XCTAssertNil(service.recordCompletedVowWork(performanceLog: log, completionResult: result))
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .pending)
        XCTAssertTrue(service.state(userId: "u-1").weeklyVowCompletionLedger.isEmpty)
    }

    func testRecordCompletedVowWorkDoesNotDuplicateCompletionOrBonusForSameReceipt() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        let overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
        service.pickVowCard(overdrive, userId: "u-1")

        let draft = try! XCTUnwrap(service.trainingDraftForCurrentVow(userId: "u-1", date: .now))
        let log = makePerformanceLog(from: draft)
        var result = TrainingCompletionResult()
        result.savedPerformanceLogId = log.id

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
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.bonus.overallLevelXP, 120)
        XCTAssertEqual(service.state(userId: "u-1").weeklyVowCompletionLedger.first?.bonus, first?.completionBonus)
    }

    // MARK: - evaluateVowProofFromLog + checkVowWindow

    func testEvaluateCapstoneFromLogNoOpWhenPending() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        // Force the Overdrive card to use a known autoFromLog criterion.
        var overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
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

    func testEvaluateCapstoneFromLogCompletesWhenWindowOpen() async {
        seedAttribute()
        await service.ensureCurrentWeek(userId: "u-1")
        var overdrive = service.state(userId: "u-1").currentWeekCards.first(where: { $0.kind == .overdrive })!
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
        XCTAssertEqual(service.state(userId: "u-1").currentVow?.capstoneState, .completed)
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

    private func makePerformanceLog(from draft: TrainingSessionDraft) -> PerformanceLog {
        let block = draft.blocks[0]
        let prescription = block.prescriptions[0]
        let completedAt = Date(timeIntervalSince1970: 1_700_000_600)
        return PerformanceLog(
            id: "weekly-vow-log-\(UUID().uuidString)",
            userId: draft.userId,
            draftId: draft.id,
            source: draft.source,
            title: draft.title,
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt,
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: block.kind,
                    title: block.title,
                    skillId: block.skillId,
                    exercises: [
                        PerformanceExercise(
                            id: prescription.id,
                            name: prescription.exerciseName,
                            movementId: prescription.movementId,
                            rankStandardMovementId: prescription.rankStandardMovementId,
                            plannedSets: prescription.sets,
                            plannedTarget: prescription.target.displayText,
                            sets: [
                                PerformanceSet(
                                    setNumber: 1,
                                    reps: 8,
                                    weightKg: 20,
                                    rpe: prescription.rpe
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    }

    private func makeEmptyPerformanceLog(from draft: TrainingSessionDraft) -> PerformanceLog {
        let block = draft.blocks[0]
        let prescription = block.prescriptions[0]
        let completedAt = Date(timeIntervalSince1970: 1_700_000_600)
        return PerformanceLog(
            id: "weekly-vow-empty-log-\(UUID().uuidString)",
            userId: draft.userId,
            draftId: draft.id,
            source: draft.source,
            title: draft.title,
            startedAt: completedAt.addingTimeInterval(-600),
            completedAt: completedAt,
            programId: draft.programId,
            dayNumber: draft.dayNumber,
            blocks: [
                PerformanceBlock(
                    kind: block.kind,
                    title: block.title,
                    skillId: block.skillId,
                    exercises: [
                        PerformanceExercise(
                            id: prescription.id,
                            name: prescription.exerciseName,
                            movementId: prescription.movementId,
                            rankStandardMovementId: prescription.rankStandardMovementId,
                            plannedSets: prescription.sets,
                            plannedTarget: prescription.target.displayText,
                            sets: []
                        )
                    ]
                )
            ]
        )
    }

    private func assertNoLegacyWeeklyCopy(
        _ copy: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for text in copy {
            XCTAssertFalse(text.localizedCaseInsensitiveContains("trial"), "Unexpected legacy copy: \(text)", file: file, line: line)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("challenge"), "Unexpected legacy copy: \(text)", file: file, line: line)
        }
    }
}
