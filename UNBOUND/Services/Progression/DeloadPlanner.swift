import Foundation

@MainActor
final class DeloadPlanner {
    static let shared = DeloadPlanner()
    private init() {}

    func shouldDeload(states: [ProgressionState], plateauCount: Int) -> Bool {
        if plateauCount >= 2 { return true }
        if let maxWeek = states.map(\.weekInBlock).max(), maxWeek >= 4 { return true }
        return false
    }

    func planDeload(for states: [ProgressionState]) -> [ProgressionState] {
        states.map { state in
            var next = state
            next.blockType = .deload
            next.weekInBlock = 1
            next.targetRPE = BlockType.deload.targetRPE
            let deloadRange = state.classification.defaultRepRange(for: .deload)
            next.targetRepMin = deloadRange.lowerBound
            next.targetRepMax = deloadRange.upperBound
            next.consecutiveSessionsAtTarget = 0
            next.updatedAt = Date()
            return next
        }
    }
}
