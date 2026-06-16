import Foundation

/// One of the 3 weekly vow cards offered to the user.
/// Static once generated for the week.
///
/// Binding Vows v2: the card is fully described by lane/bet/target. The legacy
/// kind/theme/capstone/prescription model was retired in Core-3.
struct WeeklyVowCard: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let lane: VowLane
    let bet: VowBet
    let displayName: String
    let blurb: String
    let target: VowTarget

    init(
        id: String,
        lane: VowLane,
        bet: VowBet,
        displayName: String,
        blurb: String,
        target: VowTarget
    ) {
        self.id = id
        self.lane = lane
        self.bet = bet
        self.displayName = displayName
        self.blurb = blurb
        self.target = target
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case lane
        case bet
        case displayName
        case blurb
        case target
    }

    // Tolerant decode: a half-migrated pre-v2 blob may be missing lane/bet/target.
    // Fill with the same defaults Core-1 used so any stray card still decodes
    // instead of throwing (the state migration in WeeklyVowsState then discards
    // pre-v2 in-flight vows entirely).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        blurb = try container.decode(String.self, forKey: .blurb)
        lane = try container.decodeIfPresent(VowLane.self, forKey: .lane) ?? .fuel
        bet = try container.decodeIfPresent(VowBet.self, forKey: .bet) ?? .medium
        target = try container.decodeIfPresent(VowTarget.self, forKey: .target)
            ?? VowTarget(count: 1, noun: "session")
    }
}

typealias TrialCard = WeeklyVowCard
