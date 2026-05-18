import Foundation

// MARK: - ScanComparisonService
//
// Compares two `ScanSession`s — typically the onboarding scan and the first
// rescan ~30 days later — and produces a structured `ScanDeltaReport` via
// Gemini. The report is persisted locally (and best-effort to Supabase) so
// `PTContextBuilder` can surface it to the coach on every message.
//
// Reality check: in the current codebase, `ScanSession.photos` is empty
// (the bi-weekly scan flow stores photos as `ProgressPhoto` rows with
// `source: .scan`, not on the session). This service prefers
// `session.photos[.front]` when present, otherwise falls back to looking
// up the closest-in-time `ProgressPhoto` for that user with `source: .scan`.
//
// Never throws to the caller. Returns nil if either photo is missing or
// Gemini fails — the coach simply skips the delta section in that case.

final class ScanComparisonService: @unchecked Sendable {
    static let shared = ScanComparisonService()

    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    /// Local + Supabase collection / table names.
    static let localCollection = "scanDeltaReports"
    static let supabaseTable = "scan_delta_reports"

    /// Tolerance window for matching a `ScanSession` to its `ProgressPhoto`
    /// when the session has no embedded photos. Scans + photos are saved
    /// in the same flow so they're nearly simultaneous; 24h is generous.
    private let photoMatchWindow: TimeInterval = 24 * 3600

    private init() {}

    // MARK: - Public

    /// Compare two scan sessions and return a structured delta report.
    /// Never throws — failures surface as `nil`.
    func compare(
        baseline: ScanSession,
        comparison: ScanSession,
        userId: String
    ) async -> ScanDeltaReport? {
        guard let baselineJPEG = await loadFrontPhotoData(for: baseline, userId: userId) else {
            logger.log("ScanComparison: missing baseline photo data", level: .warning,
                       context: ["scanId": baseline.id])
            return nil
        }
        guard let comparisonJPEG = await loadFrontPhotoData(for: comparison, userId: userId) else {
            logger.log("ScanComparison: missing comparison photo data", level: .warning,
                       context: ["scanId": comparison.id])
            return nil
        }

        let schema: JSONValue
        do {
            schema = try JSONValue.fromJSONString(Self.responseSchemaJSON)
        } catch {
            logger.log("ScanComparison: schema parse failed: \(error)", level: .error)
            return nil
        }

        let llm: ScanComparisonLLMOutput
        do {
            llm = try await ClaudeClient.shared.sendStructuredWithImages(
                ScanComparisonLLMOutput.self,
                model: .sonnet46,
                system: Self.systemPrompt,
                userText: Self.userPrompt,
                jpegImages: [baselineJPEG, comparisonJPEG],
                tool: ClaudeClient.Tool(
                    name: "scan_comparison",
                    description: "Return the structured scan comparison delta.",
                    inputSchema: schema
                ),
                maxTokens: 1024,
                temperature: 0.3
            )
        } catch {
            logger.log("ScanComparison: Claude failed: \(error)", level: .warning,
                       context: ["userId": userId])
            return nil
        }

        let report = ScanDeltaReport(
            id: UUID().uuidString,
            userId: userId,
            baselineScanId: baseline.id,
            comparisonScanId: comparison.id,
            createdAt: Date(),
            shoulders: clamp(llm.shoulders),
            chest:     clamp(llm.chest),
            arms:      clamp(llm.arms),
            core:      clamp(llm.core),
            legs:      clamp(llm.legs),
            overall:   clamp(llm.overall),
            narrative: llm.narrative,
            improvements: llm.improvements,
            laggingAreas: llm.laggingAreas,
            recommendedFocus: llm.recommendedFocus
        )

        // Local persistence — primary source of truth for the coach context.
        do {
            try await database.create(report,
                                      collection: Self.localCollection,
                                      documentId: report.id)
        } catch {
            logger.log("ScanComparison: local save failed: \(error)", level: .error)
        }

        // Supabase upsert — best-effort. Flat row shape for Postgres columns.
        let row = ScanDeltaReportRow(from: report)
        try? await SupabaseDatabase.shared.upsert(row, into: Self.supabaseTable)

        logger.log("ScanComparison: report generated", level: .info, context: [
            "userId": userId,
            "baselineScanId": baseline.id,
            "comparisonScanId": comparison.id,
            "overallDelta": "\(report.overall.delta)"
        ])

        return report
    }

    /// Convenience for the scan completion flow. Looks up the user's
    /// scan history and runs a comparison if there's a baseline + a
    /// rescan AND we haven't already produced a report for that pair.
    /// Fire-and-forget — do not await before dismissing the UI.
    ///
    /// Resolution order for "scan history":
    ///   1. `ScanSession` rows in `scans` collection (onboarding flow).
    ///   2. `ProgressPhoto` rows with `source: .scan` — the bi-weekly
    ///      rescan flow stores photos this way without creating a
    ///      `ScanSession`. We synthesize sessions from them.
    /// We merge both, sort by date, and take oldest as baseline + newest
    /// as comparison.
    func triggerComparisonIfNeeded(userId: String) async {
        let sessions = await fetchAllScanSessions(userId: userId)

        guard sessions.count >= 2 else { return }
        let comparison = sessions.last!         // newest
        let baseline = sessions.first!          // oldest

        guard baseline.id != comparison.id else { return }

        // De-dupe — skip if we've already produced a report for this pair.
        let existing: [ScanDeltaReport] = (try? await database.query(
            collection: Self.localCollection,
            field: "userId",
            isEqualTo: userId,
            orderBy: "createdAt",
            descending: true,
            limit: 50
        )) ?? []
        if existing.contains(where: {
            $0.baselineScanId == baseline.id && $0.comparisonScanId == comparison.id
        }) {
            return
        }

        _ = await compare(baseline: baseline, comparison: comparison, userId: userId)
    }

    /// Returns the user's full scan history sorted ascending (oldest first).
    /// Merges `ScanSession` rows + synthesized sessions from
    /// `ProgressPhoto`s tagged `source: .scan`. Photos within the same
    /// `photoMatchWindow` of an existing session are treated as that
    /// session's photo and not duplicated.
    private func fetchAllScanSessions(userId: String) async -> [ScanSession] {
        let sessionRows: [ScanSession] = (try? await database.query(
            collection: "scans",
            field: "userId",
            isEqualTo: userId,
            orderBy: "createdAt",
            descending: false,
            limit: nil
        )) ?? []

        let photos: [ProgressPhoto] = (try? await database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: userId,
            orderBy: "capturedAt",
            descending: false,
            limit: nil
        )) ?? []
        let scanPhotos = photos.filter { $0.source == .scan }

        // Synthesize a ScanSession for any scan photo NOT already covered by
        // an existing session row.
        var synthesized: [ScanSession] = []
        for photo in scanPhotos {
            let alreadyCovered = sessionRows.contains {
                abs($0.createdAt.timeIntervalSince(photo.capturedAt)) <= photoMatchWindow
            }
            if alreadyCovered { continue }

            synthesized.append(ScanSession(
                id: photo.id,
                userId: userId,
                createdAt: photo.capturedAt,
                photos: [ScanPhoto(
                    angle: photo.angle ?? .front,
                    storageUrl: photo.storageUrl,
                    capturedAt: photo.capturedAt
                )],
                analysisId: nil,
                programId: nil,
                status: .complete,
                heightCm: nil,
                weightKg: nil,
                trainingExperience: nil
            ))
        }

        let merged = (sessionRows + synthesized).sorted { $0.createdAt < $1.createdAt }
        return merged
    }

    // MARK: - Photo lookup

    /// Resolve a usable JPEG `Data` for the front-facing photo of a session.
    /// Order:
    ///   1. `session.photos[.front].storageUrl` → load from disk.
    ///   2. Fallback: closest `ProgressPhoto` (source: .scan) in time.
    private func loadFrontPhotoData(for session: ScanSession, userId: String) async -> Data? {
        if let front = session.photos.first(where: { $0.angle == .front }),
           let data = readJPEG(at: front.storageUrl) {
            return data
        }

        // Fallback — find a ProgressPhoto created within `photoMatchWindow`
        // of this session.
        let candidates: [ProgressPhoto]
        do {
            candidates = try await database.query(
                collection: "progressPhotos",
                field: "userId",
                isEqualTo: userId,
                orderBy: "capturedAt",
                descending: true,
                limit: 200
            )
        } catch {
            return nil
        }

        let target = session.createdAt
        let match = candidates
            .filter { $0.source == .scan }
            .min(by: {
                abs($0.capturedAt.timeIntervalSince(target))
                    < abs($1.capturedAt.timeIntervalSince(target))
            })

        guard let photo = match else { return nil }
        guard abs(photo.capturedAt.timeIntervalSince(target)) <= photoMatchWindow
                || candidates.filter({ $0.source == .scan }).count == 1 else {
            // If only one scan photo exists ever, accept it regardless of
            // window (handles back-dated onboarding scans).
            return nil
        }
        return readJPEG(at: photo.storageUrl)
    }

    /// Reads JPEG `Data` from a stored path string. Accepts either a raw
    /// filesystem path or a `file://` URL.
    private func readJPEG(at path: String) -> Data? {
        if path.hasPrefix("local://") { return nil }
        let url: URL = {
            if let u = URL(string: path), u.isFileURL { return u }
            return URL(fileURLWithPath: path)
        }()
        return try? Data(contentsOf: url)
    }

    // MARK: - Score clamping

    private func clamp(_ d: BodyPartDelta) -> BodyPartDelta {
        BodyPartDelta(
            before: max(1, min(10, d.before)),
            after:  max(1, min(10, d.after))
        )
    }
}

// MARK: - Gemini IO

private struct ScanComparisonLLMOutput: Decodable {
    let shoulders: BodyPartDelta
    let chest: BodyPartDelta
    let arms: BodyPartDelta
    let core: BodyPartDelta
    let legs: BodyPartDelta
    let overall: BodyPartDelta
    let narrative: String
    let improvements: [String]
    let laggingAreas: [String]
    let recommendedFocus: String
}

extension ScanComparisonService {
    static let systemPrompt: String = """
    You are a physique assessment AI for a fitness app. Compare two
    front-facing body photos of the same person, taken roughly 30 days
    apart. Your job is to score visible development per body part on a
    1-10 scale and identify what changed.

    SCORING CALIBRATION (1-10 integers):
    - 9-10  Elite, competition-ready, immediately striking
    - 7-8   Advanced, clearly above average, visible gains
    - 5-6   Solid, intermediate development
    - 3-4   Early stage, limited visible muscle / conditioning
    - 1-2   Beginner, very early
    Most untrained people score 3-6. Do NOT inflate scores to be kind.

    BODY PARTS (score each before AND after):
    - shoulders, chest, arms, core, legs, overall

    DELTA RULES:
    1. Score what you SEE in each photo independently. The "before"
       score for photo 1 should not be biased by photo 2.
    2. Genuine 30-day change is usually +0 to +1 on most parts. A +2 is
       notable. +3 or more across multiple parts is suspicious — only
       award if the photos clearly support it.
    3. If photo angle / lighting differs significantly, note that in the
       narrative and stay conservative on deltas.

    OUTPUT FIELDS:
    - improvements: lowercase body-part names that genuinely got better
    - laggingAreas: lowercase body-part names that did NOT progress
      (this is INTERNAL — used to seed the next training block, never
      shown to the user as a regression)
    - narrative: 2-3 sentences, direct coach voice, no fluff. Lead with
      the most visible improvement. Mention one honest focus area.
    - recommendedFocus: ONE line, what the next 30 days should target.

    Return strict JSON. Never fabricate measurements, body fat %, or cm.
    """

    static let userPrompt: String = """
    Photo 1 is the BASELINE (older). Photo 2 is the CURRENT scan (newer,
    ~30 days later). Score each body part for both photos and provide the
    delta assessment. Output JSON only.
    """

    static let responseSchemaJSON: String = """
    {
      "type": "object",
      "properties": {
        "shoulders": {
          "type": "object",
          "properties": {
            "before": { "type": "integer" },
            "after":  { "type": "integer" }
          },
          "required": ["before", "after"]
        },
        "chest": {
          "type": "object",
          "properties": {
            "before": { "type": "integer" },
            "after":  { "type": "integer" }
          },
          "required": ["before", "after"]
        },
        "arms": {
          "type": "object",
          "properties": {
            "before": { "type": "integer" },
            "after":  { "type": "integer" }
          },
          "required": ["before", "after"]
        },
        "core": {
          "type": "object",
          "properties": {
            "before": { "type": "integer" },
            "after":  { "type": "integer" }
          },
          "required": ["before", "after"]
        },
        "legs": {
          "type": "object",
          "properties": {
            "before": { "type": "integer" },
            "after":  { "type": "integer" }
          },
          "required": ["before", "after"]
        },
        "overall": {
          "type": "object",
          "properties": {
            "before": { "type": "integer" },
            "after":  { "type": "integer" }
          },
          "required": ["before", "after"]
        },
        "narrative":        { "type": "string" },
        "improvements":     { "type": "array", "items": { "type": "string" } },
        "laggingAreas":     { "type": "array", "items": { "type": "string" } },
        "recommendedFocus": { "type": "string" }
      },
      "required": [
        "shoulders", "chest", "arms", "core", "legs", "overall",
        "narrative", "improvements", "laggingAreas", "recommendedFocus"
      ]
    }
    """
}

// MARK: - Supabase row shape
//
// The Swift `ScanDeltaReport` model carries nested `BodyPartDelta` structs.
// Postgres stores them as flat columns (shoulders_before / shoulders_after,
// …). `ScanDeltaReportRow` is the wire shape used only for the Supabase
// upsert — the in-memory and local-disk shape stays nested.

struct ScanDeltaReportRow: Codable, Sendable {
    let id: String
    let userId: String
    let baselineScanId: String?
    let comparisonScanId: String?
    let createdAt: Date

    let shouldersBefore: Int
    let shouldersAfter: Int
    let chestBefore: Int
    let chestAfter: Int
    let armsBefore: Int
    let armsAfter: Int
    let coreBefore: Int
    let coreAfter: Int
    let legsBefore: Int
    let legsAfter: Int
    let overallBefore: Int
    let overallAfter: Int

    let narrative: String
    let improvements: [String]
    let laggingAreas: [String]
    let recommendedFocus: String

    init(from report: ScanDeltaReport) {
        self.id = report.id
        self.userId = report.userId
        self.baselineScanId = report.baselineScanId
        self.comparisonScanId = report.comparisonScanId
        self.createdAt = report.createdAt
        self.shouldersBefore = report.shoulders.before
        self.shouldersAfter  = report.shoulders.after
        self.chestBefore     = report.chest.before
        self.chestAfter      = report.chest.after
        self.armsBefore      = report.arms.before
        self.armsAfter       = report.arms.after
        self.coreBefore      = report.core.before
        self.coreAfter       = report.core.after
        self.legsBefore      = report.legs.before
        self.legsAfter       = report.legs.after
        self.overallBefore   = report.overall.before
        self.overallAfter    = report.overall.after
        self.narrative       = report.narrative
        self.improvements    = report.improvements
        self.laggingAreas    = report.laggingAreas
        self.recommendedFocus = report.recommendedFocus
    }
}
