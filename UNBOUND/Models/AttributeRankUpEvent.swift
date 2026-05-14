// UNBOUND/Models/AttributeRankUpEvent.swift
import Foundation

struct AttributeRankUpEvent: Equatable, Sendable {
    enum Level: Equatable, Sendable {
        /// Sub-rank step (e.g. E- → E). Silent per cinematic-asymmetry rule.
        case subRank
        /// Tier crossing within E/D/C/B/S buckets (e.g. Apprentice → Forged).
        case tier
        /// Crossing into Vessel / Unbound / Ascendant (A-tier band).
        case aTier
    }

    let axis: AttributeKey
    let fromTitle: RankTitle
    let toTitle: RankTitle
    let fromSubRank: SubRank
    let toSubRank: SubRank
    let level: Level
    let timestamp: Date
}

extension Notification.Name {
    static let attributeRankUp = Notification.Name("unbound.attributeRankUp")
}
