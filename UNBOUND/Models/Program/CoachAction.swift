import Foundation

enum CoachAction: Codable, Identifiable, Hashable {
    case swapExercise(from: String, to: String, scope: SwapScope)
    case insertDeload(week: Int)
    case adjustRepRange(exerciseKey: String, newMin: Int, newMax: Int)
    case acknowledgePlateau(exerciseKey: String)

    enum SwapScope: String, Codable { case session, week, programme }

    var id: String {
        switch self {
        case .swapExercise(let from, let to, let scope):
            return "swap:\(from)->\(to):\(scope.rawValue)"
        case .insertDeload(let week):
            return "deload:\(week)"
        case .adjustRepRange(let key, let min, let max):
            return "rep:\(key):\(min)-\(max)"
        case .acknowledgePlateau(let key):
            return "plateau:\(key)"
        }
    }

    var description: String {
        switch self {
        case .swapExercise(let from, let to, let scope):
            return "Swap \(from) → \(to) (\(scope.rawValue))"
        case .insertDeload(let week):
            return "Insert deload week at week \(week)"
        case .adjustRepRange(let key, let min, let max):
            return "Adjust \(key) reps → \(min)-\(max)"
        case .acknowledgePlateau(let key):
            return "Acknowledge plateau on \(key)"
        }
    }

    /// Inverse of the action — what the executor should apply on undo.
    /// `acknowledgePlateau` is a pure log entry with no state mutation, so its
    /// inverse is itself (undo is a no-op that still pops the undo stack).
    var inverse: CoachAction {
        switch self {
        case .swapExercise(let from, let to, let scope):
            return .swapExercise(from: to, to: from, scope: scope)
        case .insertDeload(let week):
            return .adjustRepRange(exerciseKey: "__revert_deload_\(week)__", newMin: 0, newMax: 0)
        case .adjustRepRange(let key, let min, let max):
            return .adjustRepRange(exerciseKey: key, newMin: min, newMax: max)
        case .acknowledgePlateau:
            return self
        }
    }
}
