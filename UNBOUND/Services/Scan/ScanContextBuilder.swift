import Foundation
import UIKit

// MARK: - ScanContextBuilder
//
// Legacy builder for the removed photo-analysis payload. Active scan flow
// uses `ScanCheckpointService`; this remains only for migration references
// and older tests.
//
// Critically: volume-per-muscle-group comes from actual logged sets joined
// against `MovementCatalog` muscle groups, not from LiftRank. Per plan, we
// want direct training signal, not a strength proxy.

@MainActor
final class ScanContextBuilder {
    static let shared = ScanContextBuilder()

    private let user: UserServiceProtocol
    private let workoutLog: WorkoutLogServiceProtocol
    private let database: DatabaseServiceProtocol
    private let progressionStore = ProgressionStateStore.shared
    private let plateauDetector = PlateauDetector.shared

    private convenience init() {
        self.init(
            user: UserService.shared,
            workoutLog: WorkoutLogService.shared,
            database: DatabaseService.shared
        )
    }

    init(
        user: UserServiceProtocol,
        workoutLog: WorkoutLogServiceProtocol,
        database: DatabaseServiceProtocol
    ) {
        self.user = user
        self.workoutLog = workoutLog
        self.database = database
    }

    /// Build the payload for a freshly-captured scan image.
    /// `currentImage` should be the raw UIImage from `ImageCaptureService`.
    /// Returns nil if the image fails to JPEG-compress (extreme edge case).
    func build(userId: String, currentImage: UIImage) async -> ScanContext? {
        guard let currentJPEG = currentImage.jpegData(compressionQuality: 0.82) else {
            return nil
        }

        let profile = try? await user.fetchProfile(userId: userId)

        // Previous scan photo — only if within 60 days. The comparison signal
        // drops off fast after two months; a year-old photo is noise.
        let (prevJPEG, daysSince) = await previousScan(userId: userId)

        // Training signal over the last 14 days.
        let logs = (try? await workoutLog.fetchRecentLogs(userId: userId, limit: 80)) ?? []
        let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)
        let recent = logs.filter { $0.startedAt >= cutoff }

        let (sessionCount, volume) = aggregateVolume(from: recent)

        // Stalled lifts — PlateauDetector returns exercises with 3+
        // stagnant sessions.
        let progressionStates = await progressionStore.fetchAll(userId: userId)
        let stalls = await plateauDetector.detect(userId: userId, states: progressionStates)
        let stalledNames = stalls.map { $0.displayName }

        return ScanContext(
            currentScanJPEG: currentJPEG,
            previousScanJPEG: prevJPEG,
            daysSinceLastScan: daysSince,
            heightCm: profile?.heightCm,
            bodyweightKg: profile?.weightKg,
            age: profile?.age,
            biologicalSex: profile?.biologicalSex?.rawValue,
            archetype: "athlete",
            sessionCount: sessionCount,
            setsByMuscleGroup: volume,
            stalledExercises: stalledNames,
            focusAreas: (profile?.targetAreas ?? []).map(\.rawValue)
        )
    }

    // MARK: - Previous scan lookup

    private func previousScan(userId: String) async -> (Data?, Int?) {
        do {
            let photos: [ProgressPhoto] = try await database.query(
                collection: "progressPhotos",
                field: "userId",
                isEqualTo: userId,
                orderBy: "capturedAt",
                descending: true,
                limit: 10
            )
            let cutoff = Date().addingTimeInterval(-60 * 24 * 3600)
            guard let prev = photos.first(where: {
                $0.source == .scan && $0.capturedAt >= cutoff
            }) else {
                return (nil, nil)
            }
            // Previous photo URL is a local file path until StorageService
            // → Supabase (task #44) ships. If the file is gone (reinstall,
            // cleanup), gracefully return nil.
            let url = URL(fileURLWithPath: prev.storageUrl)
            let data = try? Data(contentsOf: url)
            let days = Calendar.current.dateComponents([.day], from: prev.capturedAt, to: Date()).day
            return (data, days)
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - Volume aggregation

    /// Walks every logged working set in the window, joins the exercise name
    /// to `MovementDefinition.muscleGroups`, and rolls the contributions
    /// into `MuscleHeatGroup` buckets. Returns (sessionCount, map).
    private func aggregateVolume(from logs: [WorkoutLog]) -> (Int, [String: Int]) {
        var counts: [MuscleHeatGroup: Int] = [:]
        for log in logs {
            for entry in log.exerciseEntries where !entry.skipped {
                let workingSets = entry.sets.filter { !$0.isWarmup }.count
                guard workingSets > 0,
                      let movement = MovementCatalog.resolvedTrainingMovement(
                        name: entry.exerciseName,
                        movementId: entry.movementId,
                        rankStandardMovementId: entry.rankStandardMovementId
                      ) else {
                    continue
                }

                let muscleGroups = movement.exact.muscleGroups.isEmpty
                    ? (movement.standard?.muscleGroups ?? [])
                    : movement.exact.muscleGroups
                for group in muscleGroups.compactMap({ heatGroup(for: $0) }) {
                    counts[group, default: 0] += workingSets
                }
            }
        }
        let map = counts.reduce(into: [String: Int]()) { acc, pair in
            acc[pair.key.rawValue] = pair.value
        }
        return (logs.count, map)
    }

    /// Maps `ExerciseCatalog.MuscleGroup` (12 coarse tags) to our
    /// `MuscleHeatGroup` taxonomy (12 coarse buckets). `.arms` lands on
    /// `.biceps` for simplicity because the heat-map buckets are coarser
    /// than the exercise catalog. `.neck` is dropped (not in the taxonomy).
    private func heatGroup(for group: MuscleGroup) -> MuscleHeatGroup? {
        switch group {
        case .chest:     return .chest
        case .back:      return .back
        case .lats:      return .back
        case .shoulders: return .shoulders
        case .arms:      return .biceps   // see comment above
        case .forearms:  return .forearms
        case .legs:      return .legs
        case .glutes:    return .glutes
        case .core:      return .core
        case .traps:     return .traps
        case .calves:    return .calves
        case .neck:      return nil
        }
    }
}
