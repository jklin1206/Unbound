import Foundation

enum TrainingTarget: Codable, Hashable, Sendable {
    case reps(Int)
    case repsRange(Int, Int)
    case amrap
    case holdSeconds(Int)
    case distanceMeters(Int)
    case calories(Int)
    case timedSeconds(Int)

    var displayText: String {
        switch self {
        case .reps(let count): return "\(count) reps"
        // Authored windows (skill plans etc.) show as one number: the bottom
        // of the window is today's ask; progression climbs it via state.
        case .repsRange(let low, _): return "\(low) reps"
        case .amrap: return "AMRAP"
        case .holdSeconds(let seconds): return "\(seconds)s hold"
        case .distanceMeters(let meters): return meters >= 1000 ? String(format: "%.1f km", Double(meters) / 1000.0) : "\(meters)m"
        case .calories(let calories): return "\(calories) cal"
        case .timedSeconds(let seconds): return "\(seconds)s"
        }
    }

    var repsLowerBound: Int? {
        switch self {
        case .reps(let count): return count
        case .repsRange(let low, _): return low
        case .amrap, .holdSeconds, .distanceMeters, .calories, .timedSeconds: return nil
        }
    }

    var metricKind: TrainingMetricKind {
        switch self {
        case .reps, .repsRange, .amrap:
            return .reps
        case .holdSeconds:
            return .holdSeconds
        case .distanceMeters:
            return .distanceMeters
        case .calories:
            return .calories
        case .timedSeconds:
            return .durationSeconds
        }
    }

    var metricLowerBound: Int? {
        switch self {
        case .reps(let count):
            return count
        case .repsRange(let low, _):
            return low
        case .holdSeconds(let seconds):
            return seconds
        case .distanceMeters(let meters):
            return meters
        case .calories(let calories):
            return calories
        case .timedSeconds(let seconds):
            return seconds
        case .amrap:
            return nil
        }
    }

    func metricKind(defaultingTo catalogDefault: TrainingMetricKind?) -> TrainingMetricKind {
        switch self {
        case .amrap:
            return catalogDefault ?? .reps
        case .reps, .repsRange, .holdSeconds, .distanceMeters, .calories, .timedSeconds:
            return metricKind
        }
    }
}

extension TrainingTarget {
    init(_ prescriptionTarget: PrescriptionTarget) {
        switch prescriptionTarget {
        case .reps(let count):
            self = .reps(count)
        case .repsRange(let low, let high):
            self = .repsRange(low, high)
        case .amrap:
            self = .amrap
        case .hold(let seconds):
            self = .holdSeconds(seconds)
        case .tempo(let reps, _, _, _):
            self = .reps(reps)
        }
    }
}
