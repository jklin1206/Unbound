import Foundation

enum TrainingSessionSource: String, Codable, Hashable, Sendable {
    case program
    case skill
    case cardio
    case custom
    case routine
    case vow
    case overallRankTrial
}

enum TrainingBlockKind: String, Codable, CaseIterable, Hashable, Sendable {
    case strength
    case bodyweight
    case skill
    case cardio
    case carry
    case routine
    case custom
}

enum TrainingSide: String, Codable, Hashable, Sendable {
    case left
    case right
    case both
}

enum TrainingMetricKind: String, Codable, Hashable, Sendable {
    case reps
    case holdSeconds
    case durationSeconds
    case distanceMeters
    case calories
}

struct TrainingSessionDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    var source: TrainingSessionSource
    var title: String
    var date: Date
    var estimatedMinutes: Int
    var programId: String?
    var dayNumber: Int?
    var referenceExerciseName: String?
    var blocks: [TrainingBlock]

    init(
        id: String = UUID().uuidString,
        userId: String,
        source: TrainingSessionSource,
        title: String,
        date: Date = Date(),
        estimatedMinutes: Int,
        programId: String? = nil,
        dayNumber: Int? = nil,
        referenceExerciseName: String? = nil,
        blocks: [TrainingBlock]
    ) {
        self.id = id
        self.userId = userId
        self.source = source
        self.title = title
        self.date = date
        self.estimatedMinutes = estimatedMinutes
        self.programId = programId
        self.dayNumber = dayNumber
        self.referenceExerciseName = Self.cleanedReferenceExerciseName(referenceExerciseName, in: blocks)
        self.blocks = blocks
    }
}

extension TrainingSessionDraft {
    static let weeklyVowProgramIdPrefix = "weekly-vow:"

    var weeklyVowId: String? {
        guard let programId,
              programId.hasPrefix(Self.weeklyVowProgramIdPrefix)
        else { return nil }

        let id = String(programId.dropFirst(Self.weeklyVowProgramIdPrefix.count))
        return id.isEmpty ? nil : id
    }

    var isWeeklyVowDraft: Bool {
        source == .vow || weeklyVowId != nil || id.hasPrefix("weekly-vow-draft-")
    }

    var referenceExerciseOptions: [String] {
        Self.referenceExerciseOptions(in: blocks)
    }

    var effectiveReferenceExerciseName: String? {
        Self.effectiveReferenceExerciseName(referenceExerciseName, in: blocks)
    }

    mutating func normalizeReferenceExerciseName() {
        referenceExerciseName = Self.cleanedReferenceExerciseName(referenceExerciseName, in: blocks)
    }

    static func referenceExerciseOptions(in blocks: [TrainingBlock]) -> [String] {
        var seen: Set<String> = []
        var names: [String] = []
        for block in blocks {
            for prescription in block.prescriptions {
                let name = prescription.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let key = normalizedExerciseName(name)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                names.append(name)
            }
        }
        return names
    }

    static func effectiveReferenceExerciseName(
        _: String?,
        in blocks: [TrainingBlock]
    ) -> String? {
        firstMainExerciseName(in: blocks)
    }

    static func firstMainExerciseName(in blocks: [TrainingBlock]) -> String? {
        let mainBlocks = blocks.filter { block in
            !isSupportBlock(block)
        }
        if let name = firstExerciseName(in: mainBlocks) {
            return name
        }
        return firstExerciseName(in: blocks)
    }

    private static func firstExerciseName(in blocks: [TrainingBlock]) -> String? {
        for block in blocks {
            for prescription in block.prescriptions {
                let name = prescription.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    return name
                }
            }
        }
        return nil
    }

    private static func isSupportBlock(_ block: TrainingBlock) -> Bool {
        let title = normalizedExerciseName(block.title)
        let supportTokens = [
            "warmup",
            "warm up",
            "cooldown",
            "cool down",
            "mobility",
            "activation",
            "recovery"
        ]
        return supportTokens.contains { token in
            title == token || title.hasPrefix("\(token) ") || title.hasSuffix(" \(token)")
        }
    }

    static func cleanedReferenceExerciseName(
        _ storedName: String?,
        in blocks: [TrainingBlock]
    ) -> String? {
        guard let storedName else { return nil }
        let trimmed = storedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let key = normalizedExerciseName(trimmed)
        return referenceExerciseOptions(in: blocks).first {
            normalizedExerciseName($0) == key
        }
    }

    static func normalizedExerciseName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}
