import Foundation

final class CalibrationService: CalibrationServiceProtocol, @unchecked Sendable {
    static let shared = CalibrationService()

    private let database = DatabaseService.shared
    private let logger = LoggingService.shared
    private let completedFlagKey = "unbound.calibration.completed"

    private init() {}

    func save(_ baselines: [CalibrationBaseline], userId: String) async throws {
        for baseline in baselines {
            try await database.create(
                baseline,
                collection: "calibration_baselines",
                documentId: baseline.id.uuidString
            )
        }
        await seedProgressionStates(from: baselines, userId: userId)
        await seedFamilyStates(from: baselines, userId: userId)
        markCompleted(userId: userId)
        await MainActor.run {
            BadgeService.shared.bind(userId: userId)
        }
        _ = await BadgeService.shared.evaluate(trigger: .calibrationComplete)
        logger.log(
            "Calibration saved: \(baselines.count) baselines (\(baselines.filter(\.isKnown).count) known)",
            level: .info
        )
    }

    func fetchAll(userId: String) async -> [CalibrationBaseline] {
        do {
            let items: [CalibrationBaseline] = try await database.query(
                collection: "calibration_baselines",
                field: "userId",
                isEqualTo: userId,
                orderBy: "capturedAt",
                descending: true,
                limit: nil
            )
            return items
        } catch {
            logger.log("CalibrationService fetchAll failed: \(error)", level: .warning)
            return []
        }
    }

    func hasCompleted(userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: completedKey(for: userId))
    }

    func markCompleted(userId: String) {
        UserDefaults.standard.set(true, forKey: completedKey(for: userId))
        UserDefaults.standard.set(true, forKey: completedFlagKey)
    }

    func skipRatio(userId: String) -> Double {
        let key = skipRatioKey(for: userId)
        let raw = UserDefaults.standard.double(forKey: key)
        return max(0, min(1, raw))
    }

    // MARK: - Seeding

    private func seedProgressionStates(from baselines: [CalibrationBaseline], userId: String) async {
        let store = await MainActor.run { ProgressionStateStore.shared }
        for baseline in baselines where baseline.kind == .weight {
            guard baseline.isKnown, let kg = baseline.weightInKg, kg > 0 else { continue }
            let state = ProgressionState.seed(
                userId: userId,
                exercise: baseline.exerciseKey,
                startingWeightKg: kg
            )
            await store.save(state)
        }
    }

    private func seedFamilyStates(from baselines: [CalibrationBaseline], userId: String) async {
        let store = await MainActor.run { ProgressionStateStore.shared }
        let families: [(String, [String])] = [
            ("push", ["pushup", "push-up", "dip"]),
            ("pull", ["pullup", "pull-up", "chinup", "chin-up"]),
            ("legs-single", ["pistol squat", "pistol"]),
            ("core-lever", ["l-sit", "lsit", "dragon flag", "hanging leg raise"])
        ]

        for (family, keywords) in families {
            let match = baselines.first { baseline in
                baseline.kind == .reps && keywords.contains { baseline.exerciseKey.contains($0) }
            }
            guard let baseline = match, let tier = baseline.repTier else { continue }
            await store.saveFamilyState(.init(
                userId: userId,
                family: family,
                unlockedTier: tier,
                currentTier: tier,
                updatedAt: Date()
            ))
        }

        let total = Double(baselines.count)
        let skipped = Double(baselines.filter { !$0.isKnown }.count)
        let ratio = total > 0 ? skipped / total : 0
        UserDefaults.standard.set(ratio, forKey: skipRatioKey(for: userId))
    }

    // MARK: - Keys

    private func completedKey(for userId: String) -> String {
        "unbound.calibration.completed.\(userId)"
    }

    private func skipRatioKey(for userId: String) -> String {
        "unbound.calibration.skipRatio.\(userId)"
    }
}
