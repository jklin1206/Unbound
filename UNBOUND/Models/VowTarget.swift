import Foundation

/// A count-based weekly commitment, e.g. "3 fuel anchors" or "1 recovery reset".
struct VowTarget: Codable, Equatable, Sendable {
    let count: Int
    /// Singular noun; pluralized by appending "s" when count != 1.
    let noun: String

    var displayText: String {
        count == 1 ? "\(count) \(noun)" : "\(count) \(noun)s"
    }
}
