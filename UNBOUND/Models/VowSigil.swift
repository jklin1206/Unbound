import Foundation

/// The profile oath-mark (spec §8): one sealed segment per kept vow.
struct VowSigil: Equatable, Sendable {
    let keptVows: Int
    var sealedSegments: Int { max(0, keptVows) }
}
