import Foundation

/// One of the 3 weekly trial cards offered to the user.
/// Static once generated for the week.
struct TrialCard: Codable, Identifiable, Equatable, Sendable {
    let id: String              // e.g. "trial-W19-aligned"
    let kind: TrialCardKind
    let theme: TrialTheme
    let displayName: String     // "Power Focus"
    let blurb: String           // 1-sentence narrative
    let capstone: TrialCapstone
}
