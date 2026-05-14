// UNBOUND/Services/Trials/TrialsServiceProtocol.swift
import Foundation

@MainActor
protocol TrialsServiceProtocol: AnyObject {
    /// If currentWeekStart is stale or absent, roll the week and generate
    /// 3 fresh cards. Marks prior trial as .missed if uncompleted.
    /// Posts .trialWeekRolled.
    func ensureCurrentWeek(userId: String) async

    /// User picks one of the 3 cards. Persists as currentTrial.
    func pickCard(_ card: TrialCard, userId: String)

    /// User skipped the pick this week. No trial active; no chip; no penalty.
    func skipThisWeek(userId: String)

    /// Mark the current trial's capstone complete. Increments Title counters,
    /// unlocks Titles at threshold crossings, posts .trialCompleted (and
    /// .titleUnlocked per crossing).
    func completeCapstone(userId: String, at date: Date)

    /// Re-evaluate the active capstone against new log history. Only acts
    /// when capstoneState == .windowOpen and evaluation == .autoFromLog.
    func evaluateCapstoneFromLog(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) async

    /// Caller invokes from app foreground / home appear to transition
    /// pending → windowOpen when Saturday 00:00 has elapsed.
    func checkCapstoneWindow(userId: String, now: Date)

    /// Equip an unlocked Title as the user's profile headline. Pass nil to unequip.
    func equipTitle(_ titleId: TitleID?, userId: String)

    /// Read current state for UI.
    func state(userId: String) -> TrialsState
}
