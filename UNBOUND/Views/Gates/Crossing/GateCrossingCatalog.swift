import Foundation

/// One `GateCrossing` per gate. Reads `GateWorldCatalog` (Plan 2) for the world,
/// adds the Crossing dwell line. Copy is brand-safe and non-negging (world
/// language, never "limiter/weak link"; CLAUDE.md Brand Language Guardrail).
enum GateCrossingCatalog {
    static func crossing(for format: RankTrialFormat) -> GateCrossing {
        let world = GateWorldCatalog.world(for: format)
        return GateCrossing(world: world, dwellLine: dwellLine(for: format))
    }

    static var all: [GateCrossing] { RankTrialFormat.allCases.map { crossing(for: $0) } }

    private static func dwellLine(for format: RankTrialFormat) -> String {
        switch format {
        case .firstLight:   return "The courtyard is yours now."
        case .theCount:     return "You move with the bell now."
        case .theForging:   return "You were made in the fire."
        case .deckOfProof:  return "You cleared the whole deck."
        case .theAscent:    return "You stand above the clouds."
        case .sevenSeals:   return "Every part of you is sealed."
        case .theThreshold: return "You held the line. The way is open."
        case .theLastGate:  return "Nothing holds you now."
        }
    }
}
