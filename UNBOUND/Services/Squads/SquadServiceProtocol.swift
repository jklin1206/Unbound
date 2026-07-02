// UNBOUND/Services/Squads/SquadServiceProtocol.swift
import Foundation

// MARK: - SquadServiceProtocol

@MainActor
protocol SquadServiceProtocol: AnyObject {
    func loadCurrentSquad(userId: String) async
    @discardableResult
    func createSquad(name: String, userId: String) async throws -> Squad
    @discardableResult
    func joinSquad(inviteCode: String, userId: String) async throws -> Squad
    func leaveSquad(userId: String) async throws
    func setAffinity(_ axis: AttributeKey?, userId: String) async throws
    func setLogo(_ logoId: String, userId: String) async throws
    func state(userId: String) -> SquadState
    func aggregateBuildHexValues(userId: String) -> [AttributeKey: Double]
}

extension SquadServiceProtocol {
    func setLogo(_ logoId: String, userId: String) async throws {}
}

// MARK: - SquadError

enum SquadError: Error, Equatable {
    case invalidName
    case alreadyInSquad
    case squadFull
    case invalidInviteCode
    /// The generated invite code collided with an existing squad (unique
    /// violation on insert) — the only insertSquad failure worth retrying.
    case inviteCodeCollision
    case notInSquad
    case notCaptain
    case backendUnavailable
    case unsupportedChallengeKind
}

// NOTE: Notification.Name squad extensions are defined in AttributeRankUpEvent.swift (Phase 7.2).
