import Foundation

// MARK: - ArcRecapSummary
//
// Everything the end-of-Arc recap sequence shows: the before/after photo
// pair, what the block built (hex shift + compact stats), a short list of
// NOTABLE highlights (never the full log), and the next Arc's framing.
// Assembled by ArcRecapBuilder at the block-complete boundary; rendered by
// ArcRecapSequenceView.

struct ArcRecapSummary: Identifiable {
    let id: String
    let userId: String
    let programId: String
    let blockNumber: Int
    let windowStart: Date
    let windowEnd: Date

    /// Most recent progress photo at/before block start (last recap's photo),
    /// else the earliest one inside the block — the BEFORE pane.
    let beforePhotoPath: String?
    let beforePhotoDate: Date?

    let trainedSessions: Int
    let totalVolumeKg: Double
    let xpGained: Double

    /// Hex fill values (0...100 per axis) at block start; nil when no
    /// snapshot exists (blocks created before recap shipped).
    let attributeHexBefore: [AttributeKey: Double]?
    let attributeHexAfter: [AttributeKey: Double]
    /// Per-axis level gained this block; only present alongside a before-snapshot.
    let attributeLevelDeltas: [AttributeKey: Int]?

    let highlights: [ArcRecapHighlight]

    var nextArcNumber: Int { blockNumber + 1 }
}

// MARK: - ArcRecapHighlight

struct ArcRecapHighlight: Identifiable, Equatable {
    enum Kind: Equatable {
        case trialPassed
        case loadUp
        case repUp
        case streak
    }

    let id: String
    let kind: Kind
    /// Short headline, e.g. "Barbell Bench Press".
    let title: String
    /// The notable delta, e.g. "+10 kg" or "8 → 12 reps".
    let detail: String

    var icon: String {
        switch kind {
        case .trialPassed: return "seal.fill"
        case .loadUp: return "arrow.up.right"
        case .repUp: return "repeat"
        case .streak: return "flame.fill"
        }
    }
}
