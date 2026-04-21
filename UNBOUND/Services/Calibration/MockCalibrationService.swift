import Foundation

final class MockCalibrationService: CalibrationServiceProtocol, @unchecked Sendable {
    private var store: [String: [CalibrationBaseline]] = [:]
    private var completed: Set<String> = []

    func save(_ baselines: [CalibrationBaseline], userId: String) async throws {
        store[userId] = baselines
        completed.insert(userId)
    }

    func fetchAll(userId: String) async -> [CalibrationBaseline] {
        store[userId] ?? []
    }

    func hasCompleted(userId: String) -> Bool {
        completed.contains(userId)
    }

    func markCompleted(userId: String) {
        completed.insert(userId)
    }

    func skipRatio(userId: String) -> Double {
        let baselines = store[userId] ?? []
        guard !baselines.isEmpty else { return 0 }
        let skipped = Double(baselines.filter { !$0.isKnown }.count)
        return skipped / Double(baselines.count)
    }
}
