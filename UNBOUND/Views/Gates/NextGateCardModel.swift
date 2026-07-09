import Foundation

/// Pure presentation derivation for `NextGateCard` (spec §6.1). Three states:
/// **sealed** (accumulating — quest items + key fragments), **open** (eligible —
/// BEGIN), **cleared** (no next gate / already passed).
struct NextGateCardModel: Equatable {
    enum Presentation: Equatable { case sealed, open, cleared }

    struct QuestItem: Identifiable, Equatable {
        let id: String
        let label: String
        let isMet: Bool
        /// The concrete requirement, trailing the label — "LVL 3 / LVL 8",
        /// "Needs Pull-up Bar" — so the card answers "what do I need?" at a glance.
        let detail: String?
    }
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
            .filter { line in
                if line.kind == .gateKey { return false }  // rendered as key fragments
                // Equipment is never a satisfied checkmark - gear resolving a
                // runnable loadout is table stakes, and a permanent green
                // check reads as filler next to the real requirements. It
                // surfaces only while it is the blocker.
                if line.kind == .equipment { return !line.isMet }
                return true
            }
            .map { .init(id: $0.id, label: $0.label, isMet: $0.isMet, detail: Self.detail(for: $0)) }

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

    /// What to show after the label so the requirement is concrete, per kind.
    private static func detail(for line: OverallRankTrialRequirementLine) -> String? {
        switch line.kind {
        case .overallLevel:
            guard !line.required.isEmpty, !line.current.isEmpty else { return nil }
            return line.isMet ? line.current : "\(line.current) / \(line.required)"
        case .equipment:
            // Met: your gear covers it — the check says enough (the full owned
            // list is long). Unmet: `required` is exactly what's missing.
            return line.isMet || line.required.isEmpty ? nil : "Needs \(line.required)"
        case .rank:
            // Synthesized future-gate line ("Build to X") — show where you stand.
            guard !line.isMet, !line.current.isEmpty else { return nil }
            return "Now \(line.current)"
        case .gateKey:
            return nil    // rendered as key fragments; the label is the requirement
        }
    }
}
