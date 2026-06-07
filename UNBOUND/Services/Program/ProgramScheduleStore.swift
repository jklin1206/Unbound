import Foundation

enum ProgramScheduleOccurrenceKind: String, Codable, Hashable, Sendable {
    case saved
    case built
    case extra
}

struct ProgramScheduleOccurrence: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var userId: String
    var programId: String?
    var date: Date
    var kind: ProgramScheduleOccurrenceKind
    var title: String
    var savedWorkoutId: UUID?
    var draft: TrainingSessionDraft?
    var attachScheduledSkills: Bool
    var adaptsWithProgression: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: String,
        programId: String?,
        date: Date,
        kind: ProgramScheduleOccurrenceKind,
        title: String,
        savedWorkoutId: UUID? = nil,
        draft: TrainingSessionDraft? = nil,
        attachScheduledSkills: Bool = true,
        adaptsWithProgression: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.date = Calendar.current.startOfDay(for: date)
        self.kind = kind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.savedWorkoutId = savedWorkoutId
        self.draft = draft
        self.attachScheduledSkills = attachScheduledSkills
        self.adaptsWithProgression = adaptsWithProgression
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isExtraSession: Bool {
        kind == .extra
    }

    var displayTitle: String {
        title.isEmpty ? "Workout" : title
    }

    func resolvedDraft(userId: String, programId: String?, dayNumber: Int?, date: Date) -> TrainingSessionDraft? {
        if let savedWorkoutId,
           let saved = SavedWorkoutStore.shared.get(id: savedWorkoutId) {
            return saved.asDraft(
                userId: userId,
                date: date,
                programId: isExtraSession ? nil : programId,
                dayNumber: isExtraSession ? nil : dayNumber
            )
        }

        guard var draft else { return nil }
        draft.date = date
        draft.programId = isExtraSession ? nil : programId
        draft.dayNumber = isExtraSession ? nil : dayNumber
        return draft
    }
}

@MainActor
final class ProgramScheduleStore {
    static let shared = ProgramScheduleStore()

    private let fileURL: URL
    private var occurrences: [ProgramScheduleOccurrence] = []
    private var didLoad = false

    private struct Cache: Codable {
        var occurrences: [ProgramScheduleOccurrence]
    }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent("program-schedule-store.json")
    }

    func all(userId: String, programId: String? = nil) -> [ProgramScheduleOccurrence] {
        loadIfNeeded()
        return occurrences
            .filter { occurrence in
                occurrence.userId == userId
                    && (programId == nil || occurrence.programId == nil || occurrence.programId == programId)
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func occurrences(
        on date: Date,
        userId: String,
        programId: String? = nil,
        includeExtra: Bool = true
    ) -> [ProgramScheduleOccurrence] {
        let day = Calendar.current.startOfDay(for: date)
        return all(userId: userId, programId: programId)
            .filter { occurrence in
                Calendar.current.isDate(occurrence.date, inSameDayAs: day)
                    && (includeExtra || !occurrence.isExtraSession)
            }
    }

    func primaryOccurrence(
        on date: Date,
        userId: String,
        programId: String? = nil
    ) -> ProgramScheduleOccurrence? {
        occurrences(on: date, userId: userId, programId: programId, includeExtra: false)
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    func upsert(_ occurrence: ProgramScheduleOccurrence) {
        loadIfNeeded()
        if let index = occurrences.firstIndex(where: { $0.id == occurrence.id }) {
            occurrences[index] = occurrence
        } else {
            occurrences.append(occurrence)
        }
        save()
    }

    func replacePrimary(
        on date: Date,
        userId: String,
        programId: String?,
        with occurrence: ProgramScheduleOccurrence
    ) {
        loadIfNeeded()
        let day = Calendar.current.startOfDay(for: date)
        occurrences.removeAll { existing in
            existing.userId == userId
                && !existing.isExtraSession
                && Calendar.current.isDate(existing.date, inSameDayAs: day)
                && (programId == nil || existing.programId == nil || existing.programId == programId)
        }
        occurrences.append(occurrence)
        save()
    }

    func clear(userId: String? = nil) {
        loadIfNeeded()
        if let userId {
            occurrences.removeAll { $0.userId == userId }
        } else {
            occurrences = []
        }
        save()
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let cache = try? JSONDecoder.unbound.decode(Cache.self, from: data) {
            occurrences = cache.occurrences
        } else if let cache = try? JSONDecoder().decode(Cache.self, from: data) {
            occurrences = cache.occurrences
        }
    }

    private func save() {
        let cache = Cache(occurrences: occurrences)
        guard let data = try? JSONEncoder.unbound.encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
