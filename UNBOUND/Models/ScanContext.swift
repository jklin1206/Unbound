import Foundation

// MARK: - ScanContext
//
// Payload sent to Claude for the bi-weekly scan. Combines the current
// scan photo with the previous scan (if any, within 60 days) + the user's
// biometrics + the last 14 days of training signal. Assembled by
// `ScanContextBuilder` and handed to `BodyAnalysisService.analyzeScan`.
//
// We deliberately DO NOT include LiftRank — rank-per-lift is a strength
// proxy, not a development signal. Volume per muscle group is the direct
// training input we want Claude to cross-reference against the photo.
//
// This is NOT persisted; it's a transient build-and-send struct.

struct ScanContext: Sendable {
    // Photos (raw JPEG bytes ready for upload)
    var currentScanJPEG: Data
    var previousScanJPEG: Data?
    var daysSinceLastScan: Int?

    // Biometrics
    var heightCm: Double?
    var bodyweightKg: Double?
    var age: Int?
    var biologicalSex: String?          // "male" / "female" / nil
    var archetype: String               // e.g. "v-taper"

    // Training signal over the last 14 days. Keys are `MuscleHeatGroup.rawValue`
    // (chest, shoulders, biceps, triceps, forearms, traps, back, core, legs,
    // hamstrings, glutes, calves) so Claude sees our internal taxonomy.
    var sessionCount: Int
    var setsByMuscleGroup: [String: Int]
    var stalledExercises: [String]

    // User's stated focus areas from onboarding. Surfaced separately so
    // Claude can take them into account when picking its one focus-area
    // suggestion.
    var focusAreas: [String]
}
