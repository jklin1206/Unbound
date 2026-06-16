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

        checkVowWindow(userId: performanceLog.userId, now: performanceLog.completedAt)
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
            completionCountAfter: completionCountAfter
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

        CurrencyWalletStore.shared.bind(userId: performanceLog.userId)
        CurrencyWalletStore.shared.grant(
            250 + max(0, bonus.overallLevelXP / 2),
            sourceId: "weeklyVow:\(performanceLog.id)"
        )

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
        unlockTitle(.badge(badgeId), userId: userId)
    }

    /// Grant any wearable title through the shared profile title store.
    /// Idempotent; fires `.titleUnlocked` for the new title so the UI can
    /// surface it.
    func unlockTitle(_ titleId: TitleID, userId: String) {
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
