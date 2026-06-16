// UNBOUND/Services/Trials/TrialsService.swift
import Foundation

@MainActor
final class WeeklyVowsService: WeeklyVowsServiceProtocol {
    static let shared = WeeklyVowsService()

    private let store: WeeklyVowsStore
    // Read-only auto-detection sources (Core-3). Recovery reads routine-sourced
    // PerformanceLogs; engine reads CardioSessions. Both default to the existing
    // read APIs; tests inject stub closures returning canned data.
    private let recoveryCompletionsProvider: (String) async -> [PerformanceLog]
    private let cardioSessionsProvider: (String) async -> [CardioSession]

    convenience init() {
        self.init(
            store: .shared,
            recoveryCompletionsProvider: nil,
            cardioSessionsProvider: nil
        )
    }

    init(
        store: WeeklyVowsStore,
        recoveryCompletionsProvider: ((String) async -> [PerformanceLog])? = nil,
        cardioSessionsProvider: ((String) async -> [CardioSession])? = nil
    ) {
        self.store = store
        // Recovery: read routine-sourced PerformanceLogs from the shared
        // `performanceLogs` collection (read-only — never a write path).
        self.recoveryCompletionsProvider = recoveryCompletionsProvider ?? { userId in
            let logs: [PerformanceLog] = (try? await DatabaseService.shared.query(
                collection: "performanceLogs",
                field: "userId",
                isEqualTo: userId,
                orderBy: "completedAt",
                descending: true,
                limit: nil
            )) ?? []
            return logs.filter { $0.source == .routine }
        }
        // Engine: read standalone cardio from CardioLogService (read-only).
        self.cardioSessionsProvider = cardioSessionsProvider ?? { userId in
            await CardioLogService.shared.all(userId: userId)
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

        // Cards come from the curated bank pool draw, seeded by the lane the user
        // has kept least. Auto-detection (recovery/engine) seals elsewhere.
        let weekNumber = isoWeekNumber(for: newWeekStart)
        let yearForWeekOfYear = Calendar.current.component(.yearForWeekOfYear, from: newWeekStart)
        let cards = VowWeeklyDraw.cards(
            weekNumber: weekNumber,
            yearForWeekOfYear: yearForWeekOfYear,
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
        // Skip grace (spec §10): consistent with pickVowCard — skipping an
        // untouched vow is free (mis-tap protection). Only a vow with progress
        // is bound, so abandoning it owes the stake.
        if let existingVow = state.currentVow, hasProgress(existingVow, in: state) {
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
        let priorKept = VowBadgeTrack.totalKept(state.completionsByLane)
        state.completionsByLane[current.chosenCard.lane, default: 0] += 1
        let currentKept = VowBadgeTrack.totalKept(state.completionsByLane)
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
        for milestone in VowBadgeTrack.crossings(priorKept: priorKept, currentKept: currentKept) {
            NotificationCenter.default.post(name: .vowBadgeUnlocked, object: milestone)
        }
        AnalyticsService.shared.track(.bindingVowCleared(vowId: current.id))
    }

    /// Auto-complete an auto-verified vow when enough qualifying sessions are
    /// logged in-week. Reads the lane's read-only completion source (recovery →
    /// routine-sourced PerformanceLogs; engine → CardioSessions). No-op for Fuel
    /// (self-report) vows.
    func refreshAutoVerifiedVow(userId: String) async {
        let state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen,
              vow.chosenCard.lane.verification == .autoFromLog,
              let weekStart = state.currentWeekStart
        else { return }

        let count: Int
        switch vow.chosenCard.lane {
        case .recovery:
            let recoveryLogs = await recoveryCompletionsProvider(userId)
            count = VowLogMatcher.qualifyingRecoveryCount(
                weekStart: weekStart,
                recoveryLogs: recoveryLogs
            )
        case .engine:
            let cardioSessions = await cardioSessionsProvider(userId)
            count = VowLogMatcher.qualifyingCardioCount(
                weekStart: weekStart,
                cardioSessions: cardioSessions
            )
        case .fuel:
            return  // self-report; never auto-sealed
        }

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

    // MARK: - checkVowWindow

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
