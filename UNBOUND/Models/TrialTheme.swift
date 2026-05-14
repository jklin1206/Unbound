import Foundation

/// The axis or wildcard flavor that defines a trial.
enum TrialTheme: Codable, Hashable, Sendable {
    case axis(AttributeKey)
    case wildcard
}
