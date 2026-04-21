import Foundation

protocol CalibrationServiceProtocol: Sendable {
    func save(_ baselines: [CalibrationBaseline], userId: String) async throws
    func fetchAll(userId: String) async -> [CalibrationBaseline]
    func hasCompleted(userId: String) -> Bool
    func markCompleted(userId: String)
    /// Ratio of baselines where `isKnown == false`, in 0...1. Returns 0 if none stored.
    func skipRatio(userId: String) -> Double
}
