import Foundation

struct WeeklyVowPrescription: Codable, Equatable, Sendable {
    enum Placement: String, Codable, Sendable {
        case recoveryDay
        case afterWorkout
        case dedicatedSession
    }

    let placement: Placement
    let minMinutes: Int
    let maxMinutes: Int
    let minRPE: Int
    let maxRPE: Int

    var summary: String {
        "\(minMinutes)-\(maxMinutes)m · RPE \(minRPE)-\(maxRPE)"
    }
}

/// One of the 3 weekly vow cards offered to the user.
/// Static once generated for the week.
///
/// EXPAND step (Binding Vows v2 Core-1): carries the new lane/bet/target model
/// ALONGSIDE the legacy kind/theme/capstone/prescription. Old fields are retired
/// in Core-3; they remain here so every existing call site keeps compiling.
struct WeeklyVowCard: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let kind: WeeklyVowKind
    let theme: WeeklyVowTheme
    let displayName: String
    let blurb: String
    let capstone: WeeklyVowProof
    let prescription: WeeklyVowPrescription?
    let lane: VowLane
    let bet: VowBet
    let target: VowTarget

    init(
        id: String,
        kind: WeeklyVowKind,
        theme: WeeklyVowTheme,
        displayName: String,
        blurb: String,
        capstone: WeeklyVowProof,
        prescription: WeeklyVowPrescription? = nil,
        lane: VowLane = .fuel,
        bet: VowBet = .medium,
        target: VowTarget = VowTarget(count: 1, noun: "session")
    ) {
        self.id = id
        self.kind = kind
        self.theme = theme
        self.displayName = displayName
        self.blurb = blurb
        self.capstone = capstone
        self.prescription = prescription
        self.lane = lane
        self.bet = bet
        self.target = target
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case theme
        case displayName
        case blurb
        case capstone
        case prescription
        case lane
        case bet
        case target
    }

    // Custom decode so old persisted cards (no lane/bet/target) decode tolerantly
    // with sensible defaults. Old cards are being retired in Core-3.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(WeeklyVowKind.self, forKey: .kind)
        theme = try container.decode(WeeklyVowTheme.self, forKey: .theme)
        displayName = try container.decode(String.self, forKey: .displayName)
        blurb = try container.decode(String.self, forKey: .blurb)
        capstone = try container.decode(WeeklyVowProof.self, forKey: .capstone)
        prescription = try container.decodeIfPresent(WeeklyVowPrescription.self, forKey: .prescription)
        lane = try container.decodeIfPresent(VowLane.self, forKey: .lane) ?? .fuel
        bet = try container.decodeIfPresent(VowBet.self, forKey: .bet) ?? .medium
        target = try container.decodeIfPresent(VowTarget.self, forKey: .target)
            ?? VowTarget(count: 1, noun: "session")
    }
}

typealias TrialCard = WeeklyVowCard
