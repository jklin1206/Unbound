import Foundation

enum ABRotationGuard {
    enum RejectionReason: Equatable, Sendable {
        case missingRole
        case differentRole(String, String)

        var displayText: String {
            switch self {
            case .missingRole:
                return "Both Saved Workouts need a role before they can rotate."
            case .differentRole(let lhs, let rhs):
                return "\(lhs.capitalized) and \(rhs.capitalized) workouts cannot rotate together."
            }
        }
    }

    struct Result: Equatable, Sendable {
        let canPair: Bool
        let reason: RejectionReason?
    }

    static func canPair(_ lhs: SavedWorkout, with rhs: SavedWorkout) -> Bool {
        validate(lhs, with: rhs).canPair
    }

    static func validate(_ lhs: SavedWorkout, with rhs: SavedWorkout) -> Result {
        guard let lhsRole = SavedWorkout.normalizedSessionRole(lhs.sessionRole),
              let rhsRole = SavedWorkout.normalizedSessionRole(rhs.sessionRole)
        else {
            return Result(canPair: false, reason: .missingRole)
        }

        guard lhsRole == rhsRole else {
            return Result(canPair: false, reason: .differentRole(lhsRole, rhsRole))
        }

        return Result(canPair: true, reason: nil)
    }
}
