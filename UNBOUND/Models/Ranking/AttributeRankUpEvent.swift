// UNBOUND/Models/AttributeRankUpEvent.swift
import Foundation

struct AttributeRankUpEvent: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        /// Tier crossing below the crown band (e.g. Apprentice → Forged).
        case tier
        /// Crossing into Vessel / Unbound / Ascendant (crown band).
        case aTier
    }

    let axis: AttributeKey
    let fromTitle: RankTitle
    let toTitle: RankTitle
    let level: Level
    let timestamp: Date

    static var placeholder: AttributeRankUpEvent {
        AttributeRankUpEvent(
            axis: .power,
            fromTitle: .initiate,
            toTitle: .initiate,
            level: .tier,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}

extension Notification.Name {
    static let attributeRankUp = Notification.Name("unbound.attributeRankUp")
    static let requestNavigateToProfileTab = Notification.Name("unbound.requestNavigateToProfileTab")
    /// Opens the rank-trial info sheet on the HOME tab (it lived on the
    /// profile behind an ⓘ before; the gate details are Home's concern now).
    static let requestOpenRankInfo = Notification.Name("unbound.requestOpenRankInfo")
    static let requestNavigateToProgramTab = Notification.Name("unbound.requestNavigateToProgramTab")
    static let trialCapstoneCompleted = Notification.Name("unbound.trialCapstoneCompleted")
    static let trialExpired = Notification.Name("unbound.trialExpired")
    // Squad notification names
    static let squadStateChanged       = Notification.Name("unbound.squadStateChanged")
    static let squadPresenceChanged    = Notification.Name("unbound.squadPresenceChanged")
    static let squadActivityRecorded   = Notification.Name("unbound.squadActivityRecorded")
    static let linkedSessionDetected   = Notification.Name("unbound.linkedSessionDetected")
    static let squadStreakExtended     = Notification.Name("unbound.squadStreakExtended")
    static let squadTitleUnlocked      = Notification.Name("unbound.squadTitleUnlocked")
    /// Posted by the universal-link handler when a /squad/<code> URL is opened. Object is invite code (String).
    static let squadInviteCodeReceived = Notification.Name("unbound.squadInviteCodeReceived")
    static let squadMissionCompleted   = Notification.Name("unbound.squadMissionCompleted")
    static let weeklyHonorReceived     = Notification.Name("unbound.weeklyHonorReceived")
    static let friendChallengeExpired  = Notification.Name("unbound.friendChallengeExpired")
    static let friendChallengeAccepted = Notification.Name("unbound.friendChallengeAccepted")
    static let squadRoutineDropShared  = Notification.Name("unbound.squadRoutineDropShared")
    static let savedWorkoutScheduleTodayRequested = Notification.Name("unbound.savedWorkoutScheduleTodayRequested")
}
