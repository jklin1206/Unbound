import Foundation

// MARK: - ScanComparisonService
//
// Legacy bridge from the old two-photo comparison surface to the current
// checkpoint system. Photos are never sent to an AI model and never scored.
// The persisted `ScanDeltaReport` shape is kept only so older rollover and
// coach surfaces can read a compact checkpoint recap while the canonical
// source remains `ScanCheckpoint`.

final class ScanComparisonService: @unchecked Sendable {
    static let shared = ScanComparisonService()

    private let database = DatabaseService.shared
    private let logger = LoggingService.shared

    /// Local + Supabase collection / table names.
    static let localCollection = "scanDeltaReports"
    static let supabaseTable = "scan_delta_reports"

    private init() {}

    // MARK: - Public

    /// Compare two scan sessions and return a checkpoint-derived report.
    /// Never throws — failures surface as `nil`.
    func compare(
        baseline: ScanSession,
        comparison: ScanSession,
        userId: String
    ) async -> ScanDeltaReport? {
        guard let report = makeCheckpointReport(userId: userId) else {
            logger.log("ScanComparison: missing checkpoint history", level: .info,
                       context: ["baselineScanId": baseline.id, "comparisonScanId": comparison.id])
            return nil
        }

        await persist(report)
        return report
    }

    /// Convenience for the scan completion flow. Looks up the user's
    /// scan history and runs a comparison if there's a baseline + a
    /// checkpoint AND we haven't already produced a report for that pair.
    /// Fire-and-forget — do not await before dismissing the UI.
    func triggerComparisonIfNeeded(userId: String) async {
        guard let report = makeCheckpointReport(userId: userId) else { return }

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
            $0.baselineScanId == report.baselineScanId && $0.comparisonScanId == report.comparisonScanId
        }) {
            return
        }

        await persist(report)
    }

    // MARK: - Checkpoint bridge

    private func makeCheckpointReport(userId: String) -> ScanDeltaReport? {
        let history = (try? ScanCheckpointStore.shared.history(userId: userId)) ?? []
        guard history.count >= 2,
              let current = history.last
        else { return nil }
        let prior = history[history.count - 2]
        guard prior.id != current.id else { return nil }

        let positives = current.deltaFromPrior?.positiveDeltas
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key.rawValue < rhs.key.rawValue
            }
            .map { $0.key.buildVocab.lowercased() } ?? []

        let improvementText = positives.isEmpty
            ? "training consistency"
            : positives.prefix(3).joined(separator: ", ")
        let recommendedFocus: String = {
            if let region = current.completedCheckpointSignals?.weakRegions.first {
                return "Watch \(region.displayName.lowercased()) only if logged performance agrees."
            }
            return "Let completed sessions, RPE, equipment, and recovery drive the next block."
        }()

        let neutral = BodyPartDelta(before: 5, after: 5)
        return ScanDeltaReport(
            id: "checkpoint-delta-\(prior.id)-\(current.id)",
            userId: userId,
            baselineScanId: prior.id,
            comparisonScanId: current.id,
            createdAt: current.createdAt,
            shoulders: neutral,
            chest: neutral,
            arms: neutral,
            core: neutral,
            legs: neutral,
            overall: neutral,
            narrative: current.narrative.isEmpty
                ? "Checkpoint logged. \(improvementText.capitalized) is the current proof signal."
                : current.narrative,
            improvements: positives,
            laggingAreas: [],
            recommendedFocus: recommendedFocus
        )
    }

    private func persist(_ report: ScanDeltaReport) async {
        do {
            try await database.create(
                report,
                collection: Self.localCollection,
                documentId: report.id
            )
        } catch {
            logger.log("ScanComparison: local save failed: \(error)", level: .error)
        }

        let row = ScanDeltaReportRow(from: report)
        do {
            try await SupabaseDatabase.shared.upsert(row, into: Self.supabaseTable)
        } catch {
            logger.log("ScanComparison: Supabase upsert failed: \(error)", level: .warning)
        }

        logger.log("ScanComparison: checkpoint report generated", level: .info, context: [
            "userId": report.userId,
            "baselineScanId": report.baselineScanId,
            "comparisonScanId": report.comparisonScanId
        ])
    }
}

// MARK: - Supabase row shape
//
// The Swift `ScanDeltaReport` model carries legacy nested delta structs.
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
