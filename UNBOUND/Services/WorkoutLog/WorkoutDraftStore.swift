import Foundation

/// Local autosave of an in-progress workout. Survives app kill / network drop.
/// Supabase save still happens only on COMPLETE (via WorkoutLogService).
///
/// Multi-slot: a program-day draft and a custom / Quick-Log draft live in
/// separate files so neither can clobber the other. Non-resumable live sessions
/// (rank trials, skill / cardio / routine drills) share a third "other" slot,
/// kept only for crash recovery and never surfaced as a resume affordance.
@MainActor
final class WorkoutDraftStore {
    /// One isolated draft file. The slot a session lands in is derived from its
    /// TrainingSessionSource, so save / clear always route to the right file and
    /// finishing one draft can never delete another.
    enum Slot: String, CaseIterable {
        case program
        case custom
        case other

        init(source: TrainingSessionSource) {
            switch source {
            case .program:
                self = .program
            case .custom:
                self = .custom
            case .skill, .cardio, .routine, .vow, .overallRankTrial:
                self = .other
            }
        }

        var fileName: String { "workout-draft-\(rawValue).json" }
    }

    /// The pre-multi-slot single file. Read once on init into the slot its
    /// payload identifies, then deleted, so an in-progress draft survives the
    /// app update instead of being stranded.
    private static let legacyFileName = "workout-draft.json"

    private let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UNBOUND", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.directory = base
        migrateLegacyDraftIfNeeded()
    }

    func hasDraft(in slot: Slot) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: slot).path)
    }

    func save(_ session: ActiveWorkoutSession) throws {
        try write(session.snapshot(), to: Slot(source: session.source))
    }

    func load(_ slot: Slot) -> ActiveWorkoutSession? {
        guard let snapshot = read(slot) else { return nil }
        return ActiveWorkoutSession(snapshot: snapshot)
    }

    /// Clear a session's OWN slot on completion, so finishing one draft never
    /// deletes a coexisting draft in another slot.
    func clear(for session: ActiveWorkoutSession) {
        clear(Slot(source: session.source))
    }

    func clear(_ slot: Slot) {
        try? FileManager.default.removeItem(at: fileURL(for: slot))
    }

    /// Wipe every slot - used only by dev-tools state resets.
    func clearAll() {
        for slot in Slot.allCases { clear(slot) }
    }

    // MARK: - File IO

    private func fileURL(for slot: Slot) -> URL {
        directory.appendingPathComponent(slot.fileName)
    }

    private func write(_ snapshot: ActiveWorkoutSession.Snapshot, to slot: Slot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL(for: slot), options: .atomic)
    }

    private func read(_ slot: Slot) -> ActiveWorkoutSession.Snapshot? {
        guard let data = try? Data(contentsOf: fileURL(for: slot)) else { return nil }
        return try? JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
    }

    // MARK: - Legacy migration

    /// One-time: fold a pre-multi-slot workout-draft.json into the slot its
    /// payload identifies, then delete it. Idempotent - the legacy file is gone
    /// after the first store is constructed post-update, and a slot already
    /// written post-update is never clobbered.
    private func migrateLegacyDraftIfNeeded() {
        let legacyURL = directory.appendingPathComponent(Self.legacyFileName)
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }
        defer { try? FileManager.default.removeItem(at: legacyURL) }
        guard let data = try? Data(contentsOf: legacyURL),
              let snapshot = try? JSONDecoder().decode(ActiveWorkoutSession.Snapshot.self, from: data)
        else { return }
        let slot = Slot(source: snapshot.source ?? .program)
        guard !hasDraft(in: slot) else { return }
        try? write(snapshot, to: slot)
    }
}
