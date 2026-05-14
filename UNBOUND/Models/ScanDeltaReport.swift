import Foundation

// MARK: - ScanDeltaReport
//
// Visual delta between two body scans (typically the onboarding scan and a
// rescan ~30 days later). Produced by `ScanComparisonService` via Gemini.
// Injected into the coach's PT context so the coach can reference real,
// scored visible progress instead of guessing.
//
// Scores are 1-10 integers, Gemini-judged. `delta = after - before`.
//
// `laggingAreas` is INTERNAL (used to seed Block 2 generation + coach-only
// prompts). Per `project_unbound_scans_never_show_setbacks`, lagging copy
// must NOT surface in user-facing UI as a regression — only as positive
// "focus area" framing. The coach can lean on it; the home/profile screens
// must not.

struct BodyPartDelta: Codable, Equatable {
    let before: Int   // 1-10
    let after: Int    // 1-10
    var delta: Int { after - before }
}

struct ScanDeltaReport: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let baselineScanId: String     // onboarding scan id
    let comparisonScanId: String   // rescan id
    let createdAt: Date

    // Per-body-part before/after, Gemini-scored 1-10.
    let shoulders: BodyPartDelta
    let chest: BodyPartDelta
    let arms: BodyPartDelta
    let core: BodyPartDelta
    let legs: BodyPartDelta
    let overall: BodyPartDelta

    // Coach-facing summary.
    let narrative: String           // 2-3 sentences, human-readable
    let improvements: [String]      // e.g. ["shoulders", "arms"]
    let laggingAreas: [String]      // INTERNAL — for coach + Block 2 only
    let recommendedFocus: String    // one-line coaching note
}
