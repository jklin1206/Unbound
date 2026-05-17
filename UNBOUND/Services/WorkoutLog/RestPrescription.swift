import Foundation

/// Default rest after a logged set. Honors the program's explicit
/// Exercise.restSeconds when sane; otherwise classifies compound vs isolation.
enum RestPrescription {
    static let compoundRest = 150
    static let isolationRest = 90
    private static let saneRange = 20...600

    private static let compoundKeywords = [
        "squat", "deadlift", "bench", "press", "row", "pull-up", "pullup",
        "chin-up", "chinup", "clean", "snatch", "thruster", "lunge", "dip"
    ]

    static func restSeconds(for exercise: Exercise) -> Int {
        if saneRange.contains(exercise.restSeconds) { return exercise.restSeconds }
        return isCompound(exercise) ? compoundRest : isolationRest
    }

    private static func isCompound(_ e: Exercise) -> Bool {
        if e.muscleGroups.count >= 2 { return true }
        let n = e.name.lowercased()
        return compoundKeywords.contains { n.contains($0) }
    }
}
