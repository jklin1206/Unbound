// UNBOUND/Services/Trials/TrialsService.swift
import Foundation

@MainActor
final class WeeklyVowsService: WeeklyVowsServiceProtocol {
    static let shared = WeeklyVowsService()

    /// Vitality granted on sealing a vow (every lane is vitality-flavored). Tunable.
    private static let vowVitalityXP: Double = 50

    private let store: WeeklyVowsStore

    convenience init() {
        self.init(store: .shared)
    }

    init(store: WeeklyVowsStore) {
        self.store = store
    }

    // MARK: - ensureCurrentWeek

    func ensureCurrentWeek(userId: String) async {
        let now = Date()
        let newWeekStart = mostRecentMondayMidnight(now: now)
        var state = store.load(userId: userId)

        if state.currentWeekStart == newWeekStart {
            return
        }

        // Roll prior week. Mark uncompleted picked vows as missed and dock the stake.
        var rolledStake: BrokenStake?
        if var vow = state.currentVow, vow.capstoneState != .completed {
            let owed = WeeklyVowPenaltyCatalog.recordBreakIfNeeded(for: vow, missedAt: now, state: &state)
            if owed > 0 { rolledStake = BrokenStake(amount: owed, vowId: vow.id) }
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
        await dockStake(rolledStake, userId: userId, at: now)
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
        let now = Date()
        var stake: BrokenStake?
        if let existingVow = state.currentVow {
            guard existingVow.id != card.id else { return }
            // Switching grace (spec §10): switching away from an untouched vow is
            // free (mis-tap protection). A vow with progress is bound — abandoning
            // it owes the stake.
            if hasProgress(existingVow, in: state) {
                let owed = WeeklyVowPenaltyCatalog.recordBreakIfNeeded(for: existingVow, missedAt: now, state: &state)
                if owed > 0 { stake = BrokenStake(amount: owed, vowId: existingVow.id) }
            }
        }
        let vow = WeeklyVow(
            id: card.id,
            userId: userId,
            weekStart: state.currentWeekStart ?? now,
            chosenCard: card,
            capstoneState: .pending,
            completedAt: nil
        )
        state.currentVow = vow
        state.skippedCurrentWeek = false
        store.save(state, userId: userId)
        dockStakeSoon(stake, userId: userId, at: now)
        NotificationCenter.default.post(name: .weeklyVowPicked, object: vow)
        NotificationCenter.default.post(name: .trialPicked, object: vow)
    }

    func skipThisWeek(userId: String) {
        var state = store.load(userId: userId)
        let now = Date()
        var stake: BrokenStake?
        // Skip grace (spec §10): consistent with pickVowCard — skipping an
        // untouched vow is free (mis-tap protection). Only a vow with progress
        // is bound, so abandoning it owes the stake.
        if let existingVow = state.currentVow, hasProgress(existingVow, in: state) {
            let owed = WeeklyVowPenaltyCatalog.recordBreakIfNeeded(for: existingVow, missedAt: now, state: &state)
            if owed > 0 { stake = BrokenStake(amount: owed, vowId: existingVow.id) }
        }
        state.skippedCurrentWeek = true
        state.currentVow = nil
        store.save(state, userId: userId)
        dockStakeSoon(stake, userId: userId, at: now)
        WeeklyVowsNotificationScheduler.cancelAll()
    }

    /// A recorded broken-vow stake awaiting an XP dock.
    private struct BrokenStake { let amount: Int; let vowId: String }

    /// Dock a broken vow's stake straight off the user's XP (clamped so it never
    /// de-levels). Awaited at the reliable week-roll site; idempotent by vow id.
    private func dockStake(_ stake: BrokenStake?, userId: String, at date: Date) async {
        guard let stake else { return }
        await OverallLevelService.shared.dockXP(
            amount: stake.amount,
            sourceId: "weeklyVowMiss:\(stake.vowId)",
            userId: userId,
            at: date
        )
    }

    /// Fire the dock without blocking the synchronous pick/skip. Best-effort +
    /// idempotent, so a dropped dock just means no XP lost (user-favourable).
    private func dockStakeSoon(_ stake: BrokenStake?, userId: String, at date: Date) {
        guard stake != nil else { return }
        Task { await dockStake(stake, userId: userId, at: date) }
    }

    /// True if a picked vow has any progress that binds the stake on a switch:
    /// it's sealed, or at least one self-report tap has been logged. An untouched
    /// vow switches for free (mis-tap grace, spec §10).
    private func hasProgress(_ vow: WeeklyVow, in state: WeeklyVowsState) -> Bool {
        if vow.capstoneState == .completed { return true }
        if (state.fuelAnchorsByVowId[vow.id] ?? 0) > 0 { return true }
        return false
    }

    // MARK: - Lane completion (spec §5/§7)

    /// Seal a vow as cleared: increment the lane counter, pay the bet's win token
    /// (flat XP, never garnished — spec §5), and notify. Idempotent against an
    /// already-completed/missed vow.
    func sealVow(userId: String, vow: WeeklyVow, at date: Date) async {
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
        state.keptVows.append(KeptVow(
            vowId: current.id,
            name: current.chosenCard.displayName,
            lane: current.chosenCard.lane,
            completedAt: date
        ))
        if state.keptVows.count > 100 {
            state.keptVows.removeFirst(state.keptVows.count - 100)
        }
        store.save(state, userId: userId)

        // Token win — paid in full, never garnished (spec §5). Awaited (not a
        // detached Task) so the grant is part of the seal's completion path and
        // isn't dropped if the app backgrounds immediately after sealing. The
        // grant is idempotent by sourceId.
        try? await OverallLevelService.shared.grantFlatXPStrict(
            amount: current.chosenCard.bet.winXP,
            sourceId: "weeklyVowWin:\(current.id)",
            userId: userId,
            at: date
        )
        // Every vow lane (REST / FUEL / CARDIO) is vitality-flavored, so sealing one
        // feeds the vitality axis — the §7 "no attributes" guardrail is overridden for
        // vitality only (never strength XP/rank), and only at the seal, never per tap.
        // Runs once: the guard above prevents re-sealing a completed vow.
        AttributeService.shared.applyBoost(axis: .vitality, amount: Self.vowVitalityXP, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowCompleted, object: current)
        for milestone in VowBadgeTrack.crossings(priorKept: priorKept, currentKept: currentKept) {
            NotificationCenter.default.post(name: .vowBadgeUnlocked, object: milestone)
        }
        AnalyticsService.shared.track(.bindingVowCleared(vowId: current.id))
    }

    /// Self-report tap for the active vow (any lane). Increments the vow-scoped
    /// tally (never XP/rank/attributes — spec §7 guardrail) and seals at target.
    /// Gated to once per calendar day — a vow is a slow weekly commitment.
    func logVowProgress(userId: String, at date: Date = Date()) async {
        var state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen
        else { return }
        if let last = state.lastVowLogByVowId[vow.id],
           Calendar.current.isDate(last, inSameDayAs: date) {
            return  // already logged today
        }
        let next = (state.fuelAnchorsByVowId[vow.id] ?? 0) + 1
        state.fuelAnchorsByVowId[vow.id] = next
        state.lastVowLogByVowId[vow.id] = date
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .weeklyVowProgressUpdated, object: vow)
        if next >= vow.chosenCard.target.count {
            await sealVow(userId: userId, vow: vow, at: date)
        }
    }

    /// Current self-report tally for the active vow (0 if none).
    func vowProgressCount(userId: String) -> Int {
        let state = store.load(userId: userId)
        guard let vow = state.currentVow else { return 0 }
        return state.fuelAnchorsByVowId[vow.id] ?? 0
    }

    /// True if the active vow can still be logged today (once-a-day gate).
    func canLogVowToday(userId: String, now: Date = Date()) -> Bool {
        let state = store.load(userId: userId)
        guard let vow = state.currentVow,
              vow.capstoneState == .pending || vow.capstoneState == .windowOpen
        else { return false }
        guard let last = state.lastVowLogByVowId[vow.id] else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: now)
    }

    /// Grant the wearable title earned by unlocking a badge. Idempotent; fires
    /// `.titleUnlocked` for the new title so the UI can surface it.
    func unlockBadgeTitle(badgeId: String, userId: String) {
        unlockTitle(.badge(badgeId), userId: userId)
    }

    /// Grant any wearable title through the shared profile title store.
    /// Idempotent; when `announce` is true, fires `.titleUnlocked` for the new
    /// title so the UI (and squad feed) can surface it. Quiet grants exist for
    /// retroactive backfills, which must not spam the feed.
    func unlockTitle(_ titleId: TitleID, userId: String, announce: Bool) {
        var state = store.load(userId: userId)
        guard !state.unlockedTitles.contains(titleId) else { return }
        state.unlockedTitles.append(titleId)
        store.save(state, userId: userId)
        if announce {
            NotificationCenter.default.post(name: .titleUnlocked, object: titleId)
        }
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
