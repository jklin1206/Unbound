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

        // EXPAND step (Binding Vows v2 Core-1): cards now come from the curated
        // bank pool draw. `attribute`/`recentLogsProvider` are kept (Core-2 uses
        // the logs provider for auto-detection; Core-3 cleans up any leftover).
        let weekNumber = isoWeekNumber(for: newWeekStart)
        let cards = VowWeeklyDraw.cards(
            weekNumber: weekNumber,
            completionsByLane: state.completionsByLane
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
            // Switching grace (spec §10): switching away from an untouched vow is
            // free (mis-tap protection). A vow with progress is bound — abandoning
            // it owes the stake.
            if hasProgress(existingVow, in: state) {
                WeeklyVowPenaltyCatalog.applyMissedPenaltyIfNeeded(
                    for: existingVow,
                    missedAt: Date(),
                    state: &state
                )
            }
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

    /// True if a picked vow has any progress that binds the stake on a switch.
    /// Auto-verified lanes (recovery/engine) have no in-app counter, so this is
    /// false for them — switching a recovery/engine pick is always free (a
    /// qualifying session logged elsewhere still counts toward whichever vow is
    /// bound at week close). See spec §10.
    private func hasProgress(_ vow: WeeklyVow, in state: WeeklyVowsState) -> Bool {
        if vow.capstoneState == .completed { return true }
        if (state.fuelAnchorsByVowId[vow.id] ?? 0) > 0 { return true }
        return false
    }

    // MARK: - Lane completion (spec §5/§7)

    /// Seal a vow as cleared: increment the lane counter, pay the bet's win token
    /// (flat XP, never garnished — spec §5), and notify. Idempotent against an
    /// already-completed/missed vow.
    func sealVow(userId: String, vow: WeeklyVow, at date: Date) {
        var state = store.load(userId: userId)
        guard var current = state.currentVow, current.id == vow.id,
              current.capstoneState != .completed, current.capstoneState != .missed
        else { return }
        current.capstoneState = .completed
        current.completedAt = date
        state.currentVow = current
        state.completionsByLane[current.chosenCard.lane, default: 0] += 1
        store.save(state, userId: userId)

        // Token win — paid in full, never garnished (spec §5).
        Task {
            try? await OverallLevelService.shared.grantFlatXPStrict(
                amount: current.chosenCard.bet.winXP,
                sourceId: "weeklyVowWin:\(current.id)",
                userId: userId,
                at: date
            )
        }
        NotificationCenter.default.post(name: .weeklyVowCompleted, object: current)
        AnalyticsService.shared.track(.bindingVowCleared(vowId: current.id))
    }

    /// Auto-complete an auto-verified vow when enough qualifying sessions are
    /// logged in-week. No-op for Fuel (self-report) vows.
    func refreshAutoVerifiedVow(userId: String) async {
        let state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen,
              vow.chosenCard.lane.verification == .autoFromLog,
              let weekStart = state.currentWeekStart
        else { return }
        let logs = await recentLogsProvider(userId)
        let count = VowLogMatcher.qualifyingCount(
            lane: vow.chosenCard.lane,
            weekStart: weekStart,
            logs: logs
        )
        guard count >= vow.chosenCard.target.count else { return }
        sealVow(userId: userId, vow: vow, at: Date())
    }

    /// Self-report tap for a Fuel vow. Increments the vow-scoped anchor tally
    /// (never XP/rank/attributes — spec §7 guardrail) and seals at target.
    func logFuelAnchor(userId: String) {
        var state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.chosenCard.lane == .fuel,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen
        else { return }
        let next = (state.fuelAnchorsByVowId[vow.id] ?? 0) + 1
        state.fuelAnchorsByVowId[vow.id] = next
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowProgressUpdated, object: vow)
        if next >= vow.chosenCard.target.count {
            sealVow(userId: userId, vow: vow, at: Date())
        }
    }

    /// Current Fuel anchor tally for the active vow (0 for non-Fuel vows).
    func fuelAnchorCount(userId: String) -> Int {
        let state = store.load(userId: userId)
        guard let vow = state.currentVow, vow.chosenCard.lane == .fuel else { return 0 }
        return state.fuelAnchorsByVowId[vow.id] ?? 0
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
