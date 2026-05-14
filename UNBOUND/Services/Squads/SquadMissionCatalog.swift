import Foundation

/// Deterministic catalog of weekly mission templates.
/// `generate(for:weekIso:)` picks a template seeded by squad id + week.
enum SquadMissionCatalog {
    struct Template {
        let kind: SquadMission.Kind
        let targetMultiplier: Int  // multiplied by member count for final target
    }

    static let templates: [Template] = [
        Template(kind: .alignedSessions, targetMultiplier: 4),
        Template(kind: .capstonesTogether, targetMultiplier: 1),
        Template(kind: .focusSessions, targetMultiplier: 6),
        Template(kind: .tierCrossings, targetMultiplier: 1),
        Template(kind: .linkedSessions, targetMultiplier: 1),  // base 3 (see below)
        Template(kind: .perfectAttendance, targetMultiplier: 1),
    ]

    static func generate(squadId: UUID, weekIso: String, memberCount: Int) -> (kind: SquadMission.Kind, target: Int) {
        var hasher = Hasher()
        hasher.combine(squadId)
        hasher.combine(weekIso)
        let idx = abs(hasher.finalize()) % templates.count
        let t = templates[idx]
        let target: Int
        switch t.kind {
        case .linkedSessions:
            target = 3  // fixed minimum, requires 2+ members
        case .perfectAttendance:
            target = memberCount  // 1 unit per member
        default:
            target = t.targetMultiplier * memberCount
        }
        return (t.kind, target)
    }
}
