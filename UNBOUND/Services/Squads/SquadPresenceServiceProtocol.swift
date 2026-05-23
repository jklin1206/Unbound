// UNBOUND/Services/Squads/SquadPresenceServiceProtocol.swift
import Foundation

@MainActor
protocol SquadPresenceServiceProtocol: AnyObject {
    /// Upsert a squad_presence row indicating the user is currently in a workout.
    /// Sets workout_started_at = now and expires_at = now + 3h.
    func markInWorkout(userId: String, squadId: UUID) async

    /// Delete the user's squad_presence row (workout ended or expired).
    func clearPresence(userId: String) async

    /// Begin listening for presence changes for the given squad.
    /// Posts .squadPresenceChanged with [SquadPresence] when the set changes.
    func subscribeToSquadPresence(squadId: UUID) async

    /// Stop listening and release resources.
    func unsubscribeFromSquadPresence() async
}
