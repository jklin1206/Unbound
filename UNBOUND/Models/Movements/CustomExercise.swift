import Foundation

/// How a custom exercise is measured: rep counts or a timed hold.
/// Older saved rows have no stored value and decode as `.reps`.
enum CustomExerciseMeasure: String, Codable, Sendable, Hashable {
    case reps
    case hold
}

struct CustomExercise: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var displayName: String
    var pattern: MovementPattern
    var classification: ExerciseClassification
    var defaultRepMin: Int
    var defaultRepMax: Int
    var measure: CustomExerciseMeasure
    var defaultHoldSeconds: Int
    var notes: String?
    var videoURL: URL?
    var createdAt: Date
    var userId: String

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        pattern: MovementPattern,
        classification: ExerciseClassification,
        defaultRepMin: Int,
        defaultRepMax: Int,
        measure: CustomExerciseMeasure = .reps,
        defaultHoldSeconds: Int = 30,
        notes: String? = nil,
        videoURL: URL? = nil,
        createdAt: Date = Date(),
        userId: String
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.pattern = pattern
        self.classification = classification
        self.defaultRepMin = defaultRepMin
        self.defaultRepMax = defaultRepMax
        self.measure = measure
        self.defaultHoldSeconds = defaultHoldSeconds
        self.notes = notes
        self.videoURL = videoURL
        self.createdAt = createdAt
        self.userId = userId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        displayName = try container.decode(String.self, forKey: .displayName)
        pattern = try container.decode(MovementPattern.self, forKey: .pattern)
        classification = try container.decode(ExerciseClassification.self, forKey: .classification)
        defaultRepMin = try container.decode(Int.self, forKey: .defaultRepMin)
        defaultRepMax = try container.decode(Int.self, forKey: .defaultRepMax)
        measure = try container.decodeIfPresent(CustomExerciseMeasure.self, forKey: .measure) ?? .reps
        defaultHoldSeconds = try container.decodeIfPresent(Int.self, forKey: .defaultHoldSeconds) ?? 30
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        videoURL = try container.decodeIfPresent(URL.self, forKey: .videoURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userId = try container.decode(String.self, forKey: .userId)
    }

    /// The target a fresh prescription of this exercise starts from.
    var defaultTarget: TrainingTarget {
        switch measure {
        case .reps:
            return .repsRange(defaultRepMin, defaultRepMax)
        case .hold:
            return .holdSeconds(defaultHoldSeconds)
        }
    }
}

