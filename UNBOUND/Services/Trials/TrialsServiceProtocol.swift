// UNBOUND/Services/Trials/TrialsServiceProtocol.swift
import Foundation

@MainActor
protocol WeeklyVowsServiceProtocol: AnyObject {
    /// If currentWeekStart is stale or absent, roll the week and generate
    /// 3 fresh cards. Marks prior vow as .missed if uncompleted.
    /// Posts .weeklyVowWeekRolled.
    func ensureCurrentWeek(userId: String) async

    /// User picks one of the 3 cards. Persists as currentVow.
    func pickVowCard(_ card: WeeklyVowCard, userId: String)

    /// User skipped the pick this week. No vow active; no chip; no penalty.
    func skipThisWeek(userId: String)

    /// Caller invokes from app foreground / home appear to transition
    /// pending -> windowOpen when Saturday 00:00 has elapsed.
    func checkVowWindow(userId: String, now: Date)

    /// Equip an unlocked Title as the user's profile headline. Pass nil to unequip.
    func equipTitle(_ titleId: TitleID?, userId: String)

    /// Grant a wearable title. Idempotent; posts `.titleUnlocked` when newly earned.
    func unlockTitle(_ titleId: TitleID, userId: String)

    /// Read current state for UI.
    func state(userId: String) -> WeeklyVowsState

    /// Seal a vow as cleared: pay the bet's win token (flat XP), increment the
    /// lane counter, and notify. Idempotent against an already-closed vow.
    func sealVow(userId: String, vow: WeeklyVow, at date: Date) async

    /// Auto-complete an auto-verified (recovery/engine) vow when enough
    /// qualifying sessions are logged in-week. No-op for Fuel vows.
    func refreshAutoVerifiedVow(userId: String) async

    /// Self-report tap for a Fuel vow. Increments the vow-scoped anchor tally
    /// and seals the vow at target.
    func logFuelAnchor(userId: String) async

    /// Current Fuel anchor tally for the active vow (0 for non-Fuel vows).
    func fuelAnchorCount(userId: String) -> Int
}

typealias TrialsServiceProtocol = WeeklyVowsServiceProtocol
