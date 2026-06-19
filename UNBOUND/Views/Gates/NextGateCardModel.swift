import Foundation

/// Pure presentation derivation for `NextGateCard` (spec §6.1). Three states:
/// **sealed** (accumulating — quest items + key fragments), **open** (eligible —
/// BEGIN), **cleared** (no next gate / already passed).
struct NextGateCardModel: Equatable {
    enum Presentation: Equatable { case sealed, open, cleared }

    struct QuestItem: Identifiable, Equatable { let id: String; let label: String; let isMet: Bool }
    struct KeyFragment: Identifiable, Equatable { let id: String; let label: String; let isLit: Bool }

    let presentation: Presentation
    let numeral: String
    let trialName: String
    let promise: String
    let transitionLabel: String
    let questItems: [QuestItem]
    let keyFragments: [KeyFragment]
    let ctaTitle: String?

    init(readiness: OverallRankTrialReadiness, world: GateWorld) {
        numeral = world.numeral
        trialName = world.trialName
        promise = world.promise
        transitionLabel = world.transitionLabel(from: readiness.currentRank)

        let keyLines = readiness.requirements.filter { $0.kind == .gateKey }
        keyFragments = keyLines.map { .init(id: $0.id, label: $0.label, isLit: $0.isMet) }
        questItems = readiness.requirements
            .filter { $0.kind != .gateKey }
            .map { .init(id: $0.id, label: $0.label, isMet: $0.isMet) }

        if readiness.definition == nil {
            presentation = .cleared
            ctaTitle = nil
        } else if readiness.isReady {       // .ready || .failed
            presentation = .open
            ctaTitle = (readiness.status == .failed) ? "ENTER AGAIN" : "OPEN THE GATE"
        } else {
            presentation = .sealed
            ctaTitle = nil
        }
    }
}
