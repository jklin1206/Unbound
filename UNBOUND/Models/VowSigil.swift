import Foundation

/// The evolving profile oath-mark (spec §8). One sealed segment per kept vow;
/// each broken vow leaves a fracture that self-heals after `healAfterKept`
/// subsequent keeps so it never tips into negging.
struct VowSigil: Equatable, Sendable {
    let keptVows: Int
    /// Lifetime kept-vow count captured at the moment of each broken vow. A
    /// fracture mends once `healAfterKept` further keeps accrue past its
    /// snapshot — so healing is measured from the break, not from lifetime keeps.
    let breakKeptSnapshots: [Int]
    static let healAfterKept = 3
    var sealedSegments: Int { max(0, keptVows) }
    var activeFractures: Int {
        breakKeptSnapshots.filter { keptVows - max(0, $0) < Self.healAfterKept }.count
    }
}
