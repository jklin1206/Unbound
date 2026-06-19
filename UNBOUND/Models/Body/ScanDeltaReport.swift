import Foundation

// MARK: - ScanDeltaReport
//
// Legacy checkpoint recap shape between two scans. New scans derive this
// from `ScanCheckpoint` and earned attribute deltas, not from photo scoring.
// It is kept so older rollover/share/coach surfaces can keep reading a
// compact progress payload while the app moves away from body grades.
//
// `BodyPartDelta` is retained for persistence compatibility. Current
// checkpoint reports keep these neutral; user-facing progress should come
// from `improvements`, `recommendedFocus`, and `ScanCheckpoint.deltaFromPrior`.
//
// `laggingAreas` remains only for old saved reports. New reports leave it
// empty because monthly scans must not identify "weak body parts" from photos
// or use that as hidden programming input.

struct BodyPartDelta: Codable, Equatable {
    let before: Int   // 1-10
    let after: Int    // 1-10
    var delta: Int { after - before }
}

struct ScanDeltaReport: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let baselineScanId: String     // onboarding scan id
    let comparisonScanId: String   // checkpoint id
    let createdAt: Date

    // Legacy before/after slots kept for decoding older reports.
    let shoulders: BodyPartDelta
    let chest: BodyPartDelta
    let arms: BodyPartDelta
    let core: BodyPartDelta
    let legs: BodyPartDelta
    let overall: BodyPartDelta

    // Coach-facing summary.
    let narrative: String           // 2-3 sentences, human-readable
    let improvements: [String]      // e.g. ["power", "control"]
    let laggingAreas: [String]      // Legacy decode only; new reports leave empty.
    let recommendedFocus: String    // one-line coaching note
}
