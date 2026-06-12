import Foundation

// MARK: - ScanContext
//
// Legacy payload shape from the removed photo-analysis pipeline. Kept only
// for migration/decoding references; active scan flow uses `ScanCheckpoint`.
//
// We deliberately DO NOT include LiftRank — rank-per-lift is a strength
// proxy, not a development signal. Volume per muscle group is the direct
// training input for deterministic checkpoint summaries.
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

    // Training signal over the last 14 days. Keys are `MuscleHeatGroup.rawValue`.
    var sessionCount: Int
    var setsByMuscleGroup: [String: Int]
    var stalledExercises: [String]

    // User's stated focus areas from onboarding.
    var focusAreas: [String]
}
