import Foundation

struct CustomExercise: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var displayName: String
    var pattern: MovementPattern
    var classification: ExerciseClassification
    var defaultRepMin: Int
    var defaultRepMax: Int
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
        self.notes = notes
        self.videoURL = videoURL
        self.createdAt = createdAt
        self.userId = userId
    }
}

