// UNBOUND/Services/Trials/TrialsService.swift
import Foundation

@MainActor
final class WeeklyVowsService: WeeklyVowsServiceProtocol {
    static let shared = WeeklyVowsService()

    private let store: WeeklyVowsStore
    private let attribute: AttributeServiceProtocol
    private let recentLogsProvider: (String) async -> [WorkoutLog]

    convenience init() {
        self.init(
            store: .shared,
            attribute: AttributeService.shared,
            recentLogsProvider: nil
        )
    }

    init(
        store: WeeklyVowsStore,
        attribute: AttributeServiceProtocol,
        recentLogsProvider: ((String) async -> [WorkoutLog])?
    ) {
        self.store = store
        self.attribute = attribute
        // Default closure forwards to WorkoutLogService.shared.fetchRecentLogs(userId:limit:).
        // WorkoutLogServiceProtocol: fetchRecentLogs(userId:limit:) async throws -> [WorkoutLog]
        // Tests inject a stub closure that returns canned data.
        if let recentLogsProvider {
            self.recentLogsProvider = recentLogsProvider
        } else {
            self.recentLogsProvider = { userId in
                (try? await WorkoutLogService.shared.fetchRecentLogs(userId: userId, limit: 30)) ?? []
            }
        }
    }

    // MARK: - ensureCurrentWeek

    func ensureCurrentWeek(userId: String) async {
        let now = Date()
        let newWeekStart = mostRecentMondayMidnight(now: now)
        var state = store.load(userId: userId)

        if state.currentWeekStart == newWeekStart {
            return
        }

        // Roll prior week. Mark uncompleted picked vows as missed and bind the miss penalty.
        if var vow = state.currentVow, vow.capstoneState != .completed {
            WeeklyVowPenaltyCatalog.applyMissedPenaltyIfNeeded(for: vow, missedAt: now, state: &state)
            vow.capstoneState = .missed
            state.currentVow = vow
        }

        // Snapshot the user's profile + history for card generation.
        let profile = attribute.snapshot(userId: userId, asOf: now)
        let history = await recentLogsProvider(userId)
        let weekNumber = isoWeekNumber(for: newWeekStart)

        let cards = WeeklyVowGenerator.cards(
            profile: profile,
            history: history,
            weekStart: newWeekStart,
            weekNumber: weekNumber
        )

        state.currentWeekStart = newWeekStart
        state.currentWeekCards = cards
        state.currentTrial = nil
        state.skippedCurrentWeek = false

        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowWeekRolled, object: nil)
        NotificationCenter.default.post(name: .trialWeekRolled, object: nil)

        // Reschedule local notifications for the new week.
        if let weekStart = state.currentWeekStart {
            Task {
                await WeeklyVowsNotificationScheduler.reschedule(for: userId, weekStart: weekStart)
            }
        }
    }

    /// Returns the most recent Monday 00:00 local time at or before `now`.
    private func mostRecentMondayMidnight(now: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2  // Monday in Gregorian calendar
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    private func isoWeekNumber(for date: Date) -> Int {
        Calendar.current.component(.weekOfYear, from: date)
    }

    // MARK: - Pick + skip

    func pickVowCard(_ card: WeeklyVowCard, userId: String) {
        var state = store.load(userId: userId)
        if let existingVow = state.currentVow {
            guard existingVow.id != card.id else { return }
            WeeklyVowPenaltyCatalog.applyMissedPenaltyIfNeeded(
                for: existingVow,
                missedAt: Date(),
                state: &state
            )
        }
        let vow = WeeklyVow(
            id: card.id,
            userId: userId,
            weekStart: state.currentWeekStart ?? Date(),
            chosenCard: card,
            capstoneState: .pending,
            completedAt: nil
        )
        state.currentVow = vow
        state.skippedCurrentWeek = false
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowPicked, object: vow)
        NotificationCenter.default.post(name: .trialPicked, object: vow)
    }

    func skipThisWeek(userId: String) {
        var state = store.load(userId: userId)
        if let existingVow = state.currentVow {
            WeeklyVowPenaltyCatalog.applyMissedPenaltyIfNeeded(
                for: existingVow,
                missedAt: Date(),
                state: &state
            )
        }
        state.skippedCurrentWeek = true
        state.currentVow = nil
        store.save(state, userId: userId)
        WeeklyVowsNotificationScheduler.cancelAll()
    }

    // MARK: - Trainable vow work

    func trainingDraft(for vow: WeeklyVow, date: Date) -> TrainingSessionDraft {
        WeeklyVowTrainingBuilder.draft(for: vow, date: date)
    }

    func trainingDraftForCurrentVow(userId: String, date: Date) -> TrainingSessionDraft? {
        guard let vow = store.load(userId: userId).currentVow,
              vow.capstoneState != .completed,
              vow.capstoneState != .missed
        else { return nil }
        return trainingDraft(for: vow, date: date)
    }

    @discardableResult
    func recordCompletedVowWork(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult
    ) -> WeeklyVowCompletionReceipt? {
        guard completionResult.savedPerformanceLogId == performanceLog.id else { return nil }
        guard WeeklyVowTrainingRoute.hasCompletedWork(performanceLog) else { return nil }
        guard let vowId = WeeklyVowTrainingRoute.vowId(from: performanceLog.programId) else { return nil }

        let state = store.load(userId: performanceLog.userId)
        guard !state.weeklyVowCompletionLedger.contains(where: { $0.performanceLogId == performanceLog.id }) else {
            return nil
        }
        guard let vow = state.currentVow,
              vow.id == vowId,
              vow.capstoneState == .windowOpen,
              Self.savedWorkSatisfiesProof(
                performanceLog,
                vow: vow,
                bodyweightKg: completionResult.bodyweightKg
              )
        else { return nil }

        let completionCountAfter = (state.completionsByCardKind[vow.chosenCard.kind] ?? 0) + 1
        let bonus = WeeklyVowCompletionBonusCatalog.bonus(
            for: vow,
            performanceLog: performanceLog,
            completionCountAfter: completionCountAfter,
            pendingPenaltyXP: state.pendingVowPenaltyXP
        )
        let ledgerEntry = WeeklyVowCompletionLedgerEntry(
            vowId: vow.id,
            performanceLogId: performanceLog.id,
            completedAt: performanceLog.completedAt,
            bonus: bonus
        )

        guard let completedVow = sealCompletedVow(
            userId: performanceLog.userId,
            at: performanceLog.completedAt,
            ledgerEntry: ledgerEntry
        ) else { return nil }

        return WeeklyVowCompletionReceipt(
            vow: completedVow,
            performanceLog: performanceLog,
            completionBonus: bonus
        )
    }

    // MARK: - Complete vow

    func completeVow(userId: String, at date: Date) {
        // Completion is intentionally sealed only by recordCompletedVowWork(_:completionResult:).
        // Legacy callers cannot bypass the saved-work receipt requirement.
    }

    @discardableResult
    private func sealCompletedVow(
        userId: String,
        at date: Date,
        ledgerEntry: WeeklyVowCompletionLedgerEntry
    ) -> WeeklyVow? {
        var state = store.load(userId: userId)
        guard var vow = state.currentVow else { return nil }
        guard vow.id == ledgerEntry.vowId else { return nil }
        guard vow.capstoneState == .windowOpen else { return nil }
        if state.weeklyVowCompletionLedger.contains(where: { $0.performanceLogId == ledgerEntry.performanceLogId }) {
            return nil
        }

        let prior = state

        vow.capstoneState = .completed
        vow.completedAt = date
        state.currentVow = vow

        // Increment axis counter (only for axis-themed cards, not wildcard Apex).
        if case .axis(let axis) = vow.chosenCard.theme {
            state.completionsByAxis[axis, default: 0] += 1
        }
        state.completionsByCardKind[vow.chosenCard.kind, default: 0] += 1

        // Title threshold detection — fires .titleUnlocked per crossing.
        let crossings = TitleThresholdEvaluator.crossings(prior: prior, current: state)
        for titleId in crossings {
            if !state.unlockedTitles.contains(titleId) {
                state.unlockedTitles.append(titleId)
            }
        }
        state.weeklyVowCompletionLedger.append(ledgerEntry)
        state.pendingVowPenaltyXP = WeeklyVowPenaltyCatalog.remainingPenaltyXP(
            afterApplying: ledgerEntry.bonus.penaltyAppliedXP ?? 0,
            to: state.pendingVowPenaltyXP
        )
        if state.weeklyVowCompletionLedger.count > 100 {
            state.weeklyVowCompletionLedger.removeFirst(state.weeklyVowCompletionLedger.count - 100)
        }

        store.save(state, userId: userId)

        for titleId in crossings {
            NotificationCenter.default.post(name: .titleUnlocked, object: titleId)
        }
        NotificationCenter.default.post(name: .weeklyVowCompleted, object: vow)
        NotificationCenter.default.post(name: .trialCompleted, object: vow)
        AnalyticsService.shared.track(.bindingVowCleared(vowId: vow.id))
        return vow
    }

    /// Grant the wearable title earned by unlocking a badge. Idempotent; fires
    /// `.titleUnlocked` for the new title so the UI can surface it.
    func unlockBadgeTitle(badgeId: String, userId: String) {
        let titleId = TitleID.badge(badgeId)
        var state = store.load(userId: userId)
        guard !state.unlockedTitles.contains(titleId) else { return }
        state.unlockedTitles.append(titleId)
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .titleUnlocked, object: titleId)
    }

    // MARK: - evaluateVowProofFromLog + checkVowWindow

    func evaluateVowProofFromLog(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) async {
        // Raw history can hint at readiness, but it cannot seal a vow. The
        // saved PerformanceLog route is the single completion authority.
    }

    func checkVowWindow(userId: String, now: Date = .now) {
        var state = store.load(userId: userId)
        guard var vow = state.currentVow else { return }
        guard vow.capstoneState == .pending else { return }
        guard let weekStart = state.currentWeekStart else { return }
        // Saturday = weekStart + 5 days
        let saturdayMidnight = weekStart.addingTimeInterval(5 * 86_400)
        guard now >= saturdayMidnight else { return }

        vow.capstoneState = .windowOpen
        state.currentVow = vow
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowWindowOpen, object: nil)
        NotificationCenter.default.post(name: .trialCapstoneWindowOpen, object: nil)
    }

    // MARK: - T6.6 equipTitle

    func equipTitle(_ titleId: TitleID?, userId: String) {
        var state = store.load(userId: userId)
        if let titleId, !state.unlockedTitles.contains(titleId) {
            return  // Reject unequipped titles
        }
        state.equippedTitle = titleId
        store.save(state, userId: userId)
    }

    // MARK: - state

    func state(userId: String) -> WeeklyVowsState {
        store.load(userId: userId)
    }
}

private enum WeeklyVowTrainingRoute {
    private static let programIdPrefix = TrainingSessionDraft.weeklyVowProgramIdPrefix

    static func programId(for vow: WeeklyVow) -> String {
        "\(programIdPrefix)\(vow.id)"
    }

    static func vowId(from programId: String?) -> String? {
        guard let programId,
              programId.hasPrefix(programIdPrefix)
        else { return nil }
        let id = String(programId.dropFirst(programIdPrefix.count))
        return id.isEmpty ? nil : id
    }

    static func hasCompletedWork(_ performanceLog: PerformanceLog) -> Bool {
        performanceLog.blocks.contains { block in
            if block.exercises.contains(where: hasCompletedExercise) {
                return true
            }

            return (block.durationSeconds ?? 0) > 0
                || (block.distanceMeters ?? 0) > 0
                || (block.calories ?? 0) > 0
        }
    }

    static func satisfiesApexWorkoutCompletion(
        _ performanceLog: PerformanceLog,
        card: WeeklyVowCard
    ) -> Bool {
        let prescriptions = WeeklyVowTrainingBuilder.prescriptions(for: card)
        guard !prescriptions.isEmpty else { return false }
        let exercises = performanceLog.blocks.flatMap(\.exercises)
        guard !exercises.contains(where: \.skipped) else { return false }
        return prescriptions.allSatisfy { prescription in
            exercises.contains { exercise in
                exercise.matches(prescription)
                    && hasCompletedExercise(exercise, satisfying: prescription.target)
            }
        }
    }

    private static func hasCompletedExercise(_ exercise: PerformanceExercise) -> Bool {
        guard !exercise.skipped else { return false }
        return exercise.sets.contains { set in
            guard !set.isWarmup else { return false }
            return (set.reps ?? 0) > 0
                || (set.holdSeconds ?? 0) > 0
                || (set.durationSeconds ?? 0) > 0
                || (set.distanceMeters ?? 0) > 0
                || (set.calories ?? 0) > 0
                || (set.weightKg ?? 0) > 0
        }
    }

    private static func hasCompletedExercise(
        _ exercise: PerformanceExercise,
        satisfying target: TrainingTarget
    ) -> Bool {
        guard !exercise.skipped else { return false }
        return exercise.sets.contains { set in
            guard !set.isWarmup else { return false }
            switch target {
            case .reps(let count):
                return (set.reps ?? 0) >= count
            case .repsRange(let low, _):
                return (set.reps ?? 0) >= low
            case .amrap:
                return (set.reps ?? 0) > 0
                    || (set.holdSeconds ?? 0) > 0
                    || (set.durationSeconds ?? 0) > 0
                    || (set.distanceMeters ?? 0) > 0
                    || (set.calories ?? 0) > 0
            case .holdSeconds(let seconds):
                return max(set.holdSeconds ?? 0, set.durationSeconds ?? 0) >= seconds
            case .distanceMeters(let meters):
                return (set.distanceMeters ?? 0) >= meters
            case .calories(let calories):
                return (set.calories ?? 0) >= calories
            case .timedSeconds(let seconds):
                return max(set.durationSeconds ?? 0, set.holdSeconds ?? 0) >= seconds
            }
        }
    }
}

private extension PerformanceExercise {
    func matches(_ prescription: TrainingBlockPrescription) -> Bool {
        if let movementId, let prescriptionMovementId = prescription.movementId, movementId == prescriptionMovementId {
            return true
        }
        if let rankStandardMovementId,
           let prescriptionRankStandardMovementId = prescription.rankStandardMovementId,
           rankStandardMovementId == prescriptionRankStandardMovementId {
            return true
        }
        return MovementCatalog.normalized(name) == MovementCatalog.normalized(prescription.exerciseName)
    }
}

private extension WeeklyVowsService {
    static func savedWorkSatisfiesProof(
        _ performanceLog: PerformanceLog,
        vow: WeeklyVow,
        bodyweightKg: Double
    ) -> Bool {
        if vow.chosenCard.kind == .apex {
            return WeeklyVowTrainingRoute.satisfiesApexWorkoutCompletion(
                performanceLog,
                card: vow.chosenCard
            )
        }

        switch vow.chosenCard.capstone.evaluation {
        case .manualClaim, .liveTimer:
            return true
        case .autoFromLog(let criterion):
            return TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: performanceLog.weeklyVowExerciseHistory,
                bodyweightKg: bodyweightKg
            )
        }
    }
}

private extension PerformanceLog {
    var weeklyVowExerciseHistory: [ExerciseLogEntry] {
        blocks.flatMap { block in
            block.exercises.map { exercise in
                ExerciseLogEntry(
                    id: exercise.id,
                    exerciseName: exercise.name,
                    movementId: exercise.movementId,
                    rankStandardMovementId: exercise.rankStandardMovementId,
                    plannedSets: exercise.plannedSets,
                    plannedReps: exercise.plannedTarget,
                    sets: exercise.sets.map { set in
                        SetLog(
                            id: set.id,
                            setNumber: set.setNumber,
                            weightKg: set.weightKg,
                            reps: set.reps ?? 0,
                            rpe: set.rpe,
                            isWarmup: set.isWarmup,
                            durationSeconds: set.holdSeconds ?? set.durationSeconds,
                            qualityFlags: set.qualityFlags,
                            notes: set.notes
                        )
                    },
                    skipped: exercise.skipped,
                    notes: exercise.notes
                )
            }
        }
    }
}

private enum WeeklyVowPenaltyCatalog {
    private static let maxPendingPenaltyXP = 240
    private static let maxLedgerEntries = 100

    static func applyMissedPenaltyIfNeeded(
        for vow: WeeklyVow,
        missedAt: Date,
        state: inout WeeklyVowsState
    ) {
        guard vow.capstoneState != .completed, vow.capstoneState != .missed else { return }
        guard !state.weeklyVowPenaltyLedger.contains(where: { $0.vowId == vow.id && $0.weekStart == vow.weekStart }) else { return }

        let penaltyXP = vow.chosenCard.kind.missedPenaltyOverallLevelXP
        guard penaltyXP > 0 else { return }

        state.weeklyVowPenaltyLedger.append(
            WeeklyVowPenaltyLedgerEntry(
                vowId: vow.id,
                cardKind: vow.chosenCard.kind,
                weekStart: vow.weekStart,
                missedAt: missedAt,
                penaltyXP: penaltyXP
            )
        )
        if state.weeklyVowPenaltyLedger.count > maxLedgerEntries {
            state.weeklyVowPenaltyLedger.removeFirst(state.weeklyVowPenaltyLedger.count - maxLedgerEntries)
        }
        state.pendingVowPenaltyXP = min(maxPendingPenaltyXP, state.pendingVowPenaltyXP + penaltyXP)
    }

    static func remainingPenaltyXP(afterApplying appliedXP: Int, to pendingXP: Int) -> Int {
        max(0, pendingXP - max(0, appliedXP))
    }
}

private enum WeeklyVowCompletionBonusCatalog {
    static func bonus(
        for vow: WeeklyVow,
        performanceLog: PerformanceLog,
        completionCountAfter: Int,
        pendingPenaltyXP: Int
    ) -> WeeklyVowCompletionBonus {
        let kind = vow.chosenCard.kind
        let baseOverallLevelXP = kind.completionBonusOverallLevelXP
        let penaltyAppliedXP = min(max(0, pendingPenaltyXP), baseOverallLevelXP)
        let awardedOverallLevelXP = max(0, baseOverallLevelXP - penaltyAppliedXP)
        let badgeTarget = 3
        let cosmeticTarget = 5
        let badgeProgress = min(badgeTarget, ((completionCountAfter - 1) % badgeTarget) + 1)
        let cosmeticProgress = min(cosmeticTarget, ((completionCountAfter - 1) % cosmeticTarget) + 1)
        let shareCard: WeeklyVowShareCardDescriptor?

        if kind == .apex {
            shareCard = WeeklyVowShareCardDescriptor(
                id: "apex-vow-share-\(vow.id)-\(performanceLog.id)",
                title: "\(vow.chosenCard.displayName) Cleared",
                subtitle: "Binding Vow - \(vow.chosenCard.capstone.displayName)",
                metadata: [
                    "vowId": vow.id,
                    "performanceLogId": performanceLog.id,
                    "cardKind": kind.vowIdComponent,
                    "completedAt": ISO8601DateFormatter().string(from: performanceLog.completedAt)
                ]
            )
        } else {
            shareCard = nil
        }

        return WeeklyVowCompletionBonus(
            overallLevelXP: awardedOverallLevelXP,
            badgeProgress: WeeklyVowProgressDescriptor(
                title: "\(kind.displayName) I",
                current: badgeProgress,
                target: badgeTarget
            ),
            cosmeticProgress: WeeklyVowProgressDescriptor(
                title: "\(kind.displayName) Mark",
                current: cosmeticProgress,
                target: cosmeticTarget
            ),
            shareCard: shareCard,
            baseOverallLevelXP: penaltyAppliedXP > 0 ? baseOverallLevelXP : nil,
            penaltyAppliedXP: penaltyAppliedXP > 0 ? penaltyAppliedXP : nil
        )
    }
}

private enum WeeklyVowTrainingBuilder {
    static func draft(for vow: WeeklyVow, date: Date) -> TrainingSessionDraft {
        let card = vow.chosenCard
        let prescriptions = prescriptions(for: card)
        let block = TrainingBlock(
            kind: blockKind(for: card),
            title: blockTitle(for: card),
            subtitle: blockSubtitle(for: card),
            skillId: skillId(for: card),
            prescriptions: prescriptions,
            notes: card.capstone.description
        )

        return TrainingSessionDraft(
            id: "weekly-vow-draft-\(vow.id)",
            userId: vow.userId,
            source: .vow,
            title: "Binding Vow - \(card.displayName)",
            date: date,
            estimatedMinutes: estimatedMinutes(for: card, prescriptions: prescriptions),
            programId: WeeklyVowTrainingRoute.programId(for: vow),
            dayNumber: 0,
            blocks: [block]
        )
    }

    static func prescriptions(for card: WeeklyVowCard) -> [TrainingBlockPrescription] {
        if case .autoFromLog(let criterion) = card.capstone.evaluation {
            return prescriptions(for: criterion, card: card)
        }

        switch card.theme {
        case .axis(let axis):
            return axisPrescriptions(axis: axis, card: card)
        case .wildcard:
            return apexCircuit(card: card)
        }
    }

    private static func prescriptions(
        for criterion: TierCriterion,
        card: WeeklyVowCard
    ) -> [TrainingBlockPrescription] {
        switch criterion {
        case .reps(let count, let exerciseName):
            let primary = makePrescription(
                exerciseName: exerciseName,
                sets: sets(for: card, fallback: 3),
                target: .reps(max(1, count)),
                restSeconds: restSeconds(for: card, fallback: 120),
                rpe: rpe(for: card),
                notes: "Log clean reps that satisfy the proof."
            )
            guard card.kind == .apex else { return [primary] }
            return ([primary] + apexSupport(for: exerciseName, card: card)).prefixArray(4)

        case .seconds(let seconds):
            return [
                makePrescription(
                    exerciseName: "Plank",
                    sets: sets(for: card, fallback: 3),
                    target: .holdSeconds(max(10, seconds)),
                    restSeconds: restSeconds(for: card, fallback: 75),
                    rpe: rpe(for: card),
                    notes: "Hold strict form for the proof duration."
                )
            ]

        case .exerciseSeconds(let seconds, let exerciseName):
            return [
                makePrescription(
                    exerciseName: displayExerciseName(exerciseName),
                    sets: sets(for: card, fallback: 3),
                    target: .holdSeconds(max(10, seconds)),
                    restSeconds: restSeconds(for: card, fallback: 75),
                    rpe: rpe(for: card),
                    notes: "Hold this movement strictly for the proof duration."
                )
            ]

        case .weightKg(let target):
            return [
                makePrescription(
                    exerciseName: "Bench Press",
                    sets: sets(for: card, fallback: 4),
                    target: .reps(1),
                    restSeconds: restSeconds(for: card, fallback: 180),
                    rpe: rpe(for: card),
                    notes: "Build toward \(Int(target.rounded()))kg or higher."
                )
            ]

        case .exerciseWeightKg(let target, let exerciseName):
            let primary = makePrescription(
                exerciseName: exerciseName,
                sets: sets(for: card, fallback: 4),
                target: .reps(1),
                restSeconds: restSeconds(for: card, fallback: 180),
                rpe: rpe(for: card),
                notes: "Build toward \(Int(target.rounded()))kg or higher on this lift."
            )
            guard card.kind == .apex else { return [primary] }
            return ([primary] + apexSupport(for: exerciseName, card: card)).prefixArray(4)

        case .bodyweightRatio(let target):
            return [
                makePrescription(
                    exerciseName: "weighted pullup",
                    sets: sets(for: card, fallback: 4),
                    target: .reps(1),
                    restSeconds: restSeconds(for: card, fallback: 180),
                    rpe: rpe(for: card),
                    notes: "Log load for a \(String(format: "%.2f", target))x bodyweight proof."
                )
            ]

        case .exerciseBodyweightRatio(let target, let exerciseName):
            return [
                makePrescription(
                    exerciseName: exerciseName,
                    sets: sets(for: card, fallback: 4),
                    target: .reps(1),
                    restSeconds: restSeconds(for: card, fallback: 180),
                    rpe: rpe(for: card),
                    notes: "Log load for a \(String(format: "%.2f", target))x bodyweight proof."
                )
            ]

        case .variant(let name):
            let primary = makePrescription(
                exerciseName: displayExerciseName(name),
                sets: sets(for: card, fallback: 3),
                target: .amrap,
                restSeconds: restSeconds(for: card, fallback: 120),
                rpe: rpe(for: card),
                notes: "Log the named movement variant for this proof."
            )
            guard card.kind == .apex else { return [primary] }
            return ([primary] + apexSupport(for: name, card: card)).prefixArray(4)

        case .compound(let criteria):
            let compound = criteria.flatMap { prescriptions(for: $0, card: card) }
            return Array(compound.prefix(4)).nilIfEmpty ?? apexCircuit(card: card)
        }
    }

    private static func axisPrescriptions(
        axis: AttributeKey,
        card: WeeklyVowCard
    ) -> [TrainingBlockPrescription] {
        let easy = card.kind == .ember
        switch axis {
        case .power:
            return easy
                ? [
                    makePrescription(exerciseName: "Pushup", sets: 2, target: .repsRange(6, 10), restSeconds: 60, rpe: rpe(for: card), notes: "Easy pressing volume; leave plenty in reserve."),
                    makePrescription(exerciseName: "Plank", sets: 2, target: .holdSeconds(25), restSeconds: 45, rpe: rpe(for: card), notes: "Brace and keep the shoulders packed.")
                ]
                : [
                    makePrescription(exerciseName: "Bench Press", sets: 3, target: .repsRange(3, 5), restSeconds: 150, rpe: rpe(for: card), notes: "Crisp reps; stop before form slows."),
                    makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Heavy walk, tall posture, no rushing.")
                ]
        case .vitality:
            return easy
                ? [
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(600), restSeconds: 0, rpe: rpe(for: card), notes: "Keep it nasal-breathing easy; this is recovery, not conditioning."),
                    makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: rpe(for: card), notes: "Easy range only; leave fresher than you started.")
                ]
                : [
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(720), restSeconds: 0, rpe: rpe(for: card), notes: "Steady recovery pace before any harder work."),
                    makePrescription(exerciseName: "World's Greatest Stretch", sets: 2, target: .timedSeconds(60), restSeconds: 15, rpe: rpe(for: card), notes: "Move slowly and keep the session restorative.")
                ]
        case .control:
            return [
                makePrescription(exerciseName: easy ? "Plank" : "L-Sit (Tucked)", sets: easy ? 2 : 3, target: .holdSeconds(easy ? 30 : 20), restSeconds: easy ? 45 : 75, rpe: rpe(for: card), notes: "No position drift; stop before shape breaks."),
                makePrescription(exerciseName: "Hollow Hold", sets: easy ? 2 : 3, target: .holdSeconds(easy ? 20 : 30), restSeconds: easy ? 45 : 60, rpe: rpe(for: card), notes: "Ribs down, low back quiet.")
            ]
        case .endurance:
            return easy
                ? [
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(8 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Easy nasal pace."),
                    makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(40), restSeconds: 15, rpe: rpe(for: card), notes: "Open the stride without forcing range.")
                ]
                : [
                    makePrescription(exerciseName: "Run", sets: 1, target: .timedSeconds(10 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Sustained effort without sprinting."),
                    makePrescription(exerciseName: "Farmer Carry", sets: 2, target: .distanceMeters(40), restSeconds: 75, rpe: rpe(for: card), notes: "Finish with steady loaded breathing.")
                ]
        case .mobility:
            return [
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: easy ? 2 : 3, target: .timedSeconds(easy ? 45 : 60), restSeconds: 15, rpe: rpe(for: card), notes: "Stay in pain-free range."),
                makePrescription(exerciseName: "Thoracic Rotation", sets: easy ? 2 : 3, target: .timedSeconds(easy ? 45 : 60), restSeconds: 15, rpe: rpe(for: card), notes: "Slow reps, full breath."),
                makePrescription(exerciseName: easy ? "Hamstring Fold" : "Frog Stretch", sets: easy ? 1 : 2, target: .timedSeconds(easy ? 45 : 60), restSeconds: 15, rpe: rpe(for: card), notes: "Long exhale into the end range.")
            ]
        case .explosiveness:
            return easy
                ? [
                    makePrescription(exerciseName: "Jump Squat", sets: 3, target: .reps(4), restSeconds: 75, rpe: rpe(for: card), notes: "Low volume, every rep sharp."),
                    makePrescription(exerciseName: "Walk", sets: 1, target: .timedSeconds(3 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Flush out between power exposures.")
                ]
                : [
                    makePrescription(exerciseName: "Jump Squat", sets: 4, target: .reps(3), restSeconds: 105, rpe: rpe(for: card), notes: "Reset completely between sets."),
                    makePrescription(exerciseName: "Kettlebell Swing", sets: 3, target: .repsRange(8, 10), restSeconds: 90, rpe: rpe(for: card), notes: "Hips snap, arms stay quiet.")
                ]
        }
    }

    private static func apexCircuit(card: WeeklyVowCard) -> [TrainingBlockPrescription] {
        switch card.capstone.displayName {
        case "Iron Gauntlet":
            return [
                makePrescription(exerciseName: "Bench Press", sets: 4, target: .repsRange(3, 5), restSeconds: 150, rpe: rpe(for: card), notes: "Heavy, clean reps; leave no grindy misses."),
                makePrescription(exerciseName: "Goblet Squat", sets: 4, target: .repsRange(8, 10), restSeconds: 90, rpe: rpe(for: card), notes: "Deep range, upright torso, steady tempo."),
                makePrescription(exerciseName: "Farmer Carry", sets: 4, target: .distanceMeters(40), restSeconds: 90, rpe: rpe(for: card), notes: "Heavy brace under fatigue."),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(45), restSeconds: 45, rpe: rpe(for: card), notes: "Finish with a quiet trunk.")
            ]
        case "Engine Breaker":
            return [
                makePrescription(exerciseName: "Run", sets: 1, target: .timedSeconds(15 * 60), restSeconds: 0, rpe: rpe(for: card), notes: "Hard steady effort; do not turn it into a sprint."),
                makePrescription(exerciseName: "Kettlebell Swing", sets: 4, target: .repsRange(12, 15), restSeconds: 75, rpe: rpe(for: card), notes: "Snap the hips and keep breathing controlled."),
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(40), restSeconds: 90, rpe: rpe(for: card), notes: "Loaded breathing after the engine work."),
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Cooldown and restore stride length.")
            ]
        case "Pull Crucible":
            return [
                makePrescription(exerciseName: "Pullup", sets: 5, target: .repsRange(3, 8), restSeconds: 120, rpe: rpe(for: card), notes: "Strict reps; stop each set before shape breaks."),
                makePrescription(exerciseName: "Inverted Row", sets: 4, target: .repsRange(8, 12), restSeconds: 75, rpe: rpe(for: card), notes: "Chest to handle/bar every rep."),
                makePrescription(exerciseName: "Hollow Hold", sets: 4, target: .holdSeconds(30), restSeconds: 45, rpe: rpe(for: card), notes: "Ribs down, pelvis tucked."),
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Grip finish. Walk tall.")
            ]
        case "Static Furnace":
            return [
                makePrescription(exerciseName: "L-Sit (Tucked)", sets: 5, target: .holdSeconds(15), restSeconds: 75, rpe: rpe(for: card), notes: "Accumulate clean holds with locked shoulders."),
                makePrescription(exerciseName: "Hollow Hold", sets: 4, target: .holdSeconds(35), restSeconds: 60, rpe: rpe(for: card), notes: "No rib flare, no low-back arch."),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(60), restSeconds: 60, rpe: rpe(for: card), notes: "Hard brace, quiet hips."),
                makePrescription(exerciseName: "Thoracic Rotation", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Bring the system down with clean rotation.")
            ]
        case "Impact Ladder":
            return [
                makePrescription(exerciseName: "Jump Squat", sets: 6, target: .reps(3), restSeconds: 105, rpe: rpe(for: card), notes: "Max intent; reset fully each set."),
                makePrescription(exerciseName: "Kettlebell Swing", sets: 5, target: .repsRange(8, 10), restSeconds: 90, rpe: rpe(for: card), notes: "Powerful hip snap, no soft reps."),
                makePrescription(exerciseName: "Walking Lunge", sets: 4, target: .repsRange(10, 12), restSeconds: 75, rpe: rpe(for: card), notes: "Own the landing positions under fatigue."),
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Rigid trunk to close.")
            ]
        case "Volume Blackout":
            return [
                makePrescription(exerciseName: "Pushup", sets: 5, target: .repsRange(10, 15), restSeconds: 45, rpe: rpe(for: card), notes: "Short rests. Every rep locked out."),
                makePrescription(exerciseName: "Inverted Row", sets: 5, target: .repsRange(8, 12), restSeconds: 45, rpe: rpe(for: card), notes: "Pull with the back, no hip drive."),
                makePrescription(exerciseName: "Goblet Squat", sets: 5, target: .repsRange(10, 15), restSeconds: 45, rpe: rpe(for: card), notes: "Stay tall and keep the pace honest."),
                makePrescription(exerciseName: "Plank", sets: 4, target: .holdSeconds(45), restSeconds: 45, rpe: rpe(for: card), notes: "Finish braced. No sagging.")
            ]
        default:
            return [
                makePrescription(exerciseName: "Pushup", sets: 3, target: .repsRange(8, 12), restSeconds: 45, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Inverted Row", sets: 3, target: .repsRange(6, 10), restSeconds: 45, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Goblet Squat", sets: 3, target: .repsRange(8, 12), restSeconds: 45, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(40), restSeconds: 45, rpe: rpe(for: card))
            ]
        }
    }

    private static func apexSupport(
        for proofExerciseName: String,
        card: WeeklyVowCard
    ) -> [TrainingBlockPrescription] {
        switch MovementCatalog.normalized(proofExerciseName) {
        case let name where name.contains("pullup") || name.contains("pull up"):
            return [
                makePrescription(exerciseName: "Inverted Row", sets: 3, target: .repsRange(8, 12), restSeconds: 60, rpe: rpe(for: card), notes: "Build pulling volume without burning the proof set."),
                makePrescription(exerciseName: "Hollow Hold", sets: 3, target: .holdSeconds(25), restSeconds: 45, rpe: rpe(for: card), notes: "Keep the trunk locked for strict reps.")
            ]
        case let name where name.contains("muscle up"):
            return [
                makePrescription(exerciseName: "Pull-Up", sets: 3, target: .repsRange(3, 5), restSeconds: 105, rpe: rpe(for: card), notes: "Strict pull height, no kip."),
                makePrescription(exerciseName: "Dip", sets: 3, target: .repsRange(4, 6), restSeconds: 90, rpe: rpe(for: card), notes: "Own the press-out position."),
                makePrescription(exerciseName: "Hollow Hold", sets: 2, target: .holdSeconds(30), restSeconds: 45, rpe: rpe(for: card), notes: "Keep the body line quiet.")
            ]
        case let name where name.contains("bench") || name.contains("squat") || name.contains("deadlift") || name.contains("press"):
            return [
                makePrescription(exerciseName: "Farmer Carry", sets: 3, target: .distanceMeters(30), restSeconds: 90, rpe: rpe(for: card), notes: "Heavy brace after the top set."),
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Bring the system back down.")
            ]
        case let name where name.contains("run"):
            return [
                makePrescription(exerciseName: "Hip Flexor Stretch", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Cooldown and restore stride length."),
                makePrescription(exerciseName: "Thoracic Rotation", sets: 2, target: .timedSeconds(45), restSeconds: 15, rpe: 4, notes: "Easy breathing, no forcing.")
            ]
        default:
            return [
                makePrescription(exerciseName: "Goblet Squat", sets: 3, target: .repsRange(8, 12), restSeconds: 60, rpe: rpe(for: card)),
                makePrescription(exerciseName: "Plank", sets: 3, target: .holdSeconds(35), restSeconds: 45, rpe: rpe(for: card))
            ]
        }
    }

    private static func makePrescription(
        exerciseName: String,
        sets: Int,
        target: TrainingTarget,
        restSeconds: Int,
        rpe: Int?,
        notes: String? = nil
    ) -> TrainingBlockPrescription {
        let definition = catalogDefinition(named: exerciseName)
        return TrainingBlockPrescription(
            exerciseName: definition?.displayName ?? exerciseName,
            movementId: definition?.id,
            rankStandardMovementId: definition?.rankStandardMovementId,
            sets: max(1, sets),
            target: target,
            restSeconds: max(0, restSeconds),
            muscleGroups: definition?.muscleGroups ?? [],
            rpe: rpe,
            notes: notes
        )
    }

    private static func catalogDefinition(named exerciseName: String) -> MovementDefinition? {
        let normalized = MovementCatalog.normalized(exerciseName)
        let candidates = [
            catalogFallbackName(for: normalized),
            exerciseName
        ].compactMap { $0 }

        for candidate in candidates {
            let resolved = MovementResolver.resolve(candidate)
            guard let definition = MovementCatalog.definition(for: resolved.movementId),
                  !definition.id.hasPrefix("unresolved.")
            else { continue }
            return definition
        }

        return nil
    }

    private static func catalogFallbackName(for normalizedName: String) -> String? {
        // Keep Vow proof intent trainable when legacy proof names have no
        // first-class catalog row yet.
        switch normalizedName {
        case "box jump", "jumping squat":
            return "jump squat"
        case "weighted pull up":
            return "weighted pullup"
        case "strict muscle up":
            return "muscle-up"
        case "run 5k", "5k run", "5k sub 25":
            return "run"
        case "deep squat", "deep squat hold":
            return "bodyweight squat"
        case "mobility flow":
            return "hip flexor stretch"
        default:
            return nil
        }
    }

    private static func estimatedMinutes(
        for card: WeeklyVowCard,
        prescriptions: [TrainingBlockPrescription]
    ) -> Int {
        if let prescription = card.prescription {
            return max(5, (prescription.minMinutes + prescription.maxMinutes) / 2)
        }

        let seconds = prescriptions.reduce(0) { total, prescription in
            total + max(1, prescription.sets) * (45 + prescription.restSeconds)
        }
        return max(10, Int(ceil(Double(seconds) / 60.0)))
    }

    private static func blockKind(for card: WeeklyVowCard) -> TrainingBlockKind {
        if case .axis(.control) = card.theme {
            return .skill
        }
        return .custom
    }

    private static func skillId(for card: WeeklyVowCard) -> String? {
        if case .axis(.control) = card.theme {
            return "cl.hollow-body-30"
        }
        return nil
    }

    private static func blockTitle(for card: WeeklyVowCard) -> String {
        switch card.kind {
        case .ember:
            return "Recovery Vow Work"
        case .overdrive:
            return "Finisher Vow Work"
        case .apex:
            return "Limit Vow Circuit"
        }
    }

    private static func blockSubtitle(for card: WeeklyVowCard) -> String? {
        guard let prescription = card.prescription else { return card.capstone.displayName }
        return "\(prescription.summary) · \(card.capstone.displayName)"
    }

    private static func rpe(for card: WeeklyVowCard) -> Int? {
        guard let prescription = card.prescription else { return nil }
        return max(1, min(10, (prescription.minRPE + prescription.maxRPE) / 2))
    }

    private static func restSeconds(for card: WeeklyVowCard, fallback: Int) -> Int {
        switch card.kind {
        case .ember:
            return min(fallback, 75)
        case .overdrive:
            return fallback
        case .apex:
            return max(fallback, 90)
        }
    }

    private static func sets(for card: WeeklyVowCard, fallback: Int) -> Int {
        switch card.kind {
        case .ember:
            return min(fallback, 2)
        case .overdrive:
            return fallback
        case .apex:
            return max(fallback, 4)
        }
    }

    private static func displayExerciseName(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

private extension Array {
    var nilIfEmpty: [Element]? {
        isEmpty ? nil : self
    }

    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}

extension Notification.Name {
    static let weeklyVowWeekRolled     = Notification.Name("unbound.weeklyVowWeekRolled")
    static let weeklyVowPicked         = Notification.Name("unbound.weeklyVowPicked")
    static let weeklyVowWindowOpen     = Notification.Name("unbound.weeklyVowWindowOpen")
    static let weeklyVowCompleted      = Notification.Name("unbound.weeklyVowCompleted")

    // Temporary adapters for existing observers and stored tests.
    static let trialWeekRolled         = Notification.Name("unbound.trialWeekRolled")
    static let trialPicked             = Notification.Name("unbound.trialPicked")
    static let trialCapstoneWindowOpen = Notification.Name("unbound.trialCapstoneWindowOpen")
    static let trialCompleted          = Notification.Name("unbound.trialCompleted")
    static let titleUnlocked           = Notification.Name("unbound.titleUnlocked")
}

typealias TrialsService = WeeklyVowsService
