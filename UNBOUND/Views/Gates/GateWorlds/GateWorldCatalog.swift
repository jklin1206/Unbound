import Foundation

/// One `GateWorld` per `RankTrialFormat`. Values: spec §3 (world↔banner) + §5 (ladder).
/// Copy is brand-safe and non-negging (CLAUDE.md Brand Language Guardrail).
enum GateWorldCatalog {
    /// All eight worlds in gate order (I…VIII) — used by the finale flashback montage.
    static var allOrdered: [GateWorld] {
        RankTrialFormat.allCases.map { world(for: $0) }.sorted { $0.order < $1.order }
    }

    static func world(for format: RankTrialFormat) -> GateWorld {
        switch format {
        case .firstLight:
            return GateWorld(format: .firstLight, numeral: "I", order: 1,
                promise: "Light the courtyard.",
                beatVerb: "lit", destinationRank: .novice, element: .lanterns)
        case .theCount:
            return GateWorld(format: .theCount, numeral: "II", order: 2,
                promise: "Move with the bell.",
                beatVerb: "counted", destinationRank: .apprentice, element: .bell)
        case .theForging:
            return GateWorld(format: .theForging, numeral: "III", order: 3,
                promise: "The steel doesn't rush.",
                beatVerb: "struck", destinationRank: .forged, element: .forge)
        case .deckOfProof:
            return GateWorld(format: .deckOfProof, numeral: "IV", order: 4,
                promise: "Clear the whole deck.",
                beatVerb: "drawn", destinationRank: .veteran, element: .deck)
        case .theAscent:
            return GateWorld(format: .theAscent, numeral: "V", order: 5,
                promise: "Climb to the temple.",
                beatVerb: "climbed", destinationRank: .master, element: .ascent)
        case .sevenSeals:
            return GateWorld(format: .sevenSeals, numeral: "VI", order: 6,
                promise: "One seal for each part of you.",
                beatVerb: "sealed", destinationRank: .vessel, element: .seals)
        case .theThreshold:
            return GateWorld(format: .theThreshold, numeral: "VII", order: 7,
                promise: "Hold until the portal opens.",
                beatVerb: "breached", destinationRank: .ascendant, element: .siege)
        case .theLastGate:
            return GateWorld(format: .theLastGate, numeral: "VIII", order: 8,
                promise: "Every gate, one last time.",
                beatVerb: "answered", destinationRank: .unbound, element: .landings)
        }
    }
}
