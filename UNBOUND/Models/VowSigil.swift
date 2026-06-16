import Foundation

/// The evolving profile oath-mark (spec §8). One sealed segment per kept vow;
/// each broken vow leaves a fracture that self-heals after `healAfterKept`
/// subsequent keeps so it never tips into negging.
struct VowSigil: Equatable, Sendable {
    let keptVows: Int
    let brokenVows: Int
    static let healAfterKept = 3
    var sealedSegments: Int { max(0, keptVows) }
    var activeFractures: Int {
        let healed = keptVows / Self.healAfterKept
        return max(0, brokenVows - healed)
    }
}
