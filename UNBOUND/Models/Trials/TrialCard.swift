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
struct WeeklyVowCard: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let kind: WeeklyVowKind
    let theme: WeeklyVowTheme
    let displayName: String
    let blurb: String
    let capstone: WeeklyVowProof
    let prescription: WeeklyVowPrescription?

    init(
        id: String,
        kind: WeeklyVowKind,
        theme: WeeklyVowTheme,
        displayName: String,
        blurb: String,
        capstone: WeeklyVowProof,
        prescription: WeeklyVowPrescription? = nil
    ) {
        self.id = id
        self.kind = kind
        self.theme = theme
        self.displayName = displayName
        self.blurb = blurb
        self.capstone = capstone
        self.prescription = prescription
    }
}

typealias TrialCard = WeeklyVowCard
