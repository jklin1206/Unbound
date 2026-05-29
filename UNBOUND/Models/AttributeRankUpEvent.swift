// UNBOUND/Models/AttributeRankUpEvent.swift
import Foundation

struct AttributeRankUpEvent: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        /// Intra-tier step. With the 9-tier RankTier ladder this no longer
        /// fires (every rank change is a tier crossing); retained for the
        /// silent cinematic-asymmetry contract.
        case subRank
        /// Tier crossing below the crown band (e.g. Apprentice → Forged).
        case tier
        /// Crossing into Vessel / Unbound / Ascendant (crown band).
        case aTier
    }

    let axis: AttributeKey
    let fromTitle: RankTitle
    let toTitle: RankTitle
    let fromSubRank: RankTier
    let toSubRank: RankTier
    let level: Level
    let timestamp: Date
}

extension Notification.Name {
    static let attributeRankUp = Notification.Name("unbound.attributeRankUp")
    static let requestNavigateToProfileTab = Notification.Name("unbound.requestNavigateToProfileTab")
    static let requestNavigateToProfileRankGate = Notification.Name("unbound.requestNavigateToProfileRankGate")
    static let requestOpenProfileRankInfo = Notification.Name("unbound.requestOpenProfileRankInfo")
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
}
