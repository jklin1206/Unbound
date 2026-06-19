import Foundation

/// Deterministic catalog of weekly mission templates.
/// `generate(for:weekIso:)` picks a template seeded by squad id + week.
///
/// PARITY: The template order and target formula MUST stay identical across three places:
///   1. This file (Swift client)
///   2. supabase/functions/evaluate_squad_mission/index.ts (edge function)
///   3. supabase/migrations/20260611120000_squad_mission_kinds_v2.sql (SQL fallback, mod 5)
enum SquadMissionCatalog {
    struct Template {
        let kind: SquadMission.Kind
    }

    // Hash order: idx 0..4 — must match SQL `case v_template_idx` and TS MISSION_TEMPLATES array.
    static let templates: [Template] = [
        Template(kind: .totalWeight),
        Template(kind: .totalSessions),
        Template(kind: .totalReps),
        Template(kind: .crewCoverage),
        Template(kind: .trainTogether),
    ]

    /// Returns the target for a given kind and member count.
    /// Synced with the SQL `v_target` case block and the TS target formula.
    static func target(for kind: SquadMission.Kind, memberCount: Int) -> Int {
        switch kind {
        case .totalWeight:   return 8000 * memberCount
        case .totalSessions: return 4 * memberCount
        case .totalReps:     return 600 * memberCount
        case .crewCoverage:  return memberCount
        case .trainTogether: return 3
        }
    }

    static func generate(squadId: UUID, weekIso: String, memberCount: Int) -> (kind: SquadMission.Kind, target: Int) {
        let idx = templateIndex(squadId: squadId, weekIso: weekIso)
        let t = templates[idx]
        return (t.kind, target(for: t.kind, memberCount: memberCount))
    }

    private static func templateIndex(squadId: UUID, weekIso: String) -> Int {
        // Keep this in parity with the SQL/Edge Function simpleHash(squad_id || week_iso).
        let seed = squadId.uuidString.lowercased() + weekIso
        var hash: Int32 = 0
        for byte in seed.utf8 {
            hash = hash &* 31 &+ Int32(byte)
        }
        return Int(hash.magnitude) % templates.count
    }
}
