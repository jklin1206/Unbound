// UNBOUND/Services/Trials/TrialsServiceProtocol.swift
import Foundation

@MainActor
protocol WeeklyVowsServiceProtocol: AnyObject {
    /// If currentWeekStart is stale or absent, roll the week and generate
    /// 3 fresh cards. Marks prior vow as .missed if uncompleted.
    /// Posts .weeklyVowWeekRolled.
    func ensureCurrentWeek(userId: String) async

    /// User picks one of the 3 cards. Persists as currentVow. Abandoning a
    /// touched prior vow docks its stake off XP.
    func pickVowCard(_ card: WeeklyVowCard, userId: String)

    /// User skipped the pick this week. No vow active; no chip. Abandoning a
    /// touched vow docks its stake off XP.
    func skipThisWeek(userId: String)

    /// Caller invokes from app foreground / home appear to transition
    /// pending -> windowOpen when Saturday 00:00 has elapsed.
    func checkVowWindow(userId: String, now: Date)

    /// Equip an unlocked Title as the user's profile headline. Pass nil to unequip.
    func equipTitle(_ titleId: TitleID?, userId: String)

    /// Grant a wearable title. Idempotent; posts `.titleUnlocked` when newly
    /// earned and `announce` is true. Announcements publish to the squad
    /// activity feed, so retroactive backfills must pass `announce: false`.
    func unlockTitle(_ titleId: TitleID, userId: String, announce: Bool)

    /// Read current state for UI.
    func state(userId: String) -> WeeklyVowsState

    /// Seal a vow as cleared: pay the bet's win token (flat XP), increment the
    /// lane counter, and notify. Idempotent against an already-closed vow.
    func sealVow(userId: String, vow: WeeklyVow, at date: Date) async

    /// Self-report tap for the active vow (any lane). Seals at target. Gated to
    /// once per calendar day.
    func logVowProgress(userId: String, at date: Date) async

    /// Current self-report tally for the active vow (0 if none).
    func vowProgressCount(userId: String) -> Int

    /// True if the active vow can still be logged today (once-a-day gate).
    func canLogVowToday(userId: String, now: Date) -> Bool
}

extension WeeklyVowsServiceProtocol {
    /// Announced grant — the default for titles earned by a live event.
    func unlockTitle(_ titleId: TitleID, userId: String) {
        unlockTitle(titleId, userId: userId, announce: true)
    }
}

typealias TrialsServiceProtocol = WeeklyVowsServiceProtocol
