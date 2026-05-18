import Foundation

// MARK: - CoachNotesService
//
// Generates one `CoachNote` per user per calendar day. Hits Claude once
// on first home-appear of a new day; subsequent same-day calls hit the
// cached row in `coach_notes`. Deterministic id (`userId:yyyy-MM-dd`)
// makes the dedup trivial.
//
// Context fed to Claude is a tight summary of recent training signal
// (session count last 14 days, streak, plateaus, rank letter, archetype).
// Intentionally narrow — the note is a single-line mentor check-in, not
// a deep program analysis.

@MainActor
final class CoachNotesService {
    static let shared = CoachNotesService()

    private let database: DatabaseServiceProtocol
    private let user: UserServiceProtocol
    private let workoutLog: WorkoutLogServiceProtocol
    private let sessionXP: SessionXPServiceProtocol
    private let plateauDetector = PlateauDetector.shared
    private let progressionStore = ProgressionStateStore.shared
    private let logger = LoggingService.shared

    private init(
        database: DatabaseServiceProtocol = DatabaseService.shared,
        user: UserServiceProtocol = UserService.shared,
        workoutLog: WorkoutLogServiceProtocol = WorkoutLogService.shared,
        sessionXP: SessionXPServiceProtocol = SessionXPService.shared
    ) {
        self.database = database
        self.user = user
        self.workoutLog = workoutLog
        self.sessionXP = sessionXP
    }

    /// Returns today's note — hits cache if already generated today, else
    /// asks Claude. Returns nil on any failure so callers can hide the
    /// card gracefully.
    func todaysNote(userId: String) async -> CoachNote? {
        let todayKey = CoachNote.dayKey(for: Date())
        let id = "\(userId):\(todayKey)"

        if let cached: CoachNote = try? await database.read(
            collection: "coach_notes",
            documentId: id
        ) {
            return cached
        }

        return await generate(userId: userId, id: id)
    }

    // MARK: - Generation

    private func generate(userId: String, id: String) async -> CoachNote? {
        let context = await buildContext(userId: userId)

        let systemPrompt = """
        You are UNBOUND's coach. Write ONE short check-in sentence (max 25
        words) for the user based on their recent training signal. Voice:
        anime-inflected mentor — direct, confident, not corny. NEVER:
        - Recommend deloads, swaps, or program changes.
        - Mention numbers the user didn't log themselves.
        - Frame anything as a regression / setback.

        Output JSON only with { "text": "..." }.
        """

        let userPrompt = """
        ARCHETYPE: \(context.archetype)
        AGGREGATE RANK: \(context.rankLetter)
        CURRENT STREAK: \(context.currentStreak) days
        SESSIONS LAST 14 DAYS: \(context.sessions14d)
        STALLED LIFTS: \(context.stalls.isEmpty ? "none" : context.stalls.joined(separator: ", "))
        LAST SESSION: \(context.lastSessionLabel)

        Write today's note.
        """

        let schemaJSON = """
        { "type": "object", "properties": { "text": { "type": "string" } }, "required": ["text"] }
        """

        do {
            let schema = try JSONValue.fromJSONString(schemaJSON)
            let out: CoachNoteLLM = try await ClaudeClient.shared.sendStructured(
                CoachNoteLLM.self,
                model: .haiku45,
                system: systemPrompt,
                userText: userPrompt,
                tool: ClaudeClient.Tool(
                    name: "coach_note",
                    description: "Return today's one-sentence coach note.",
                    inputSchema: schema
                ),
                maxTokens: 128,
                temperature: 0.55
            )
            let trimmed = out.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let note = CoachNote(userId: userId, text: trimmed)
            try? await database.create(note, collection: "coach_notes", documentId: id)
            logger.log("Coach note generated", level: .debug)
            return note
        } catch {
            logger.log("Coach note generation failed: \(error)", level: .warning)
            return nil
        }
    }

    // MARK: - Context

    private struct NoteContext {
        let archetype: String
        let rankLetter: String
        let currentStreak: Int
        let sessions14d: Int
        let stalls: [String]
        let lastSessionLabel: String
    }

    private func buildContext(userId: String) async -> NoteContext {
        let xp = sessionXP.record(userId: userId)
        let streak = xp.currentStreak

        let logs = (try? await workoutLog.fetchRecentLogs(userId: userId, limit: 40)) ?? []
        let cutoff = Date().addingTimeInterval(-14 * 24 * 3600)
        let recent = logs.filter { $0.startedAt >= cutoff }

        let progressionStates = await progressionStore.fetchAll(userId: userId)
        let plateaus = await plateauDetector.detect(userId: userId, states: progressionStates)

        let rankLetter = "—"

        let lastSessionLabel: String = {
            guard let last = logs.first else { return "none logged yet" }
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: last.startedAt),
                to: Calendar.current.startOfDay(for: Date())
            ).day ?? 0
            if days == 0 { return "earlier today · \(last.plannedWorkoutName)" }
            if days == 1 { return "yesterday · \(last.plannedWorkoutName)" }
            return "\(days) days ago · \(last.plannedWorkoutName)"
        }()

        return NoteContext(
            archetype: "build",
            rankLetter: rankLetter,
            currentStreak: streak,
            sessions14d: recent.count,
            stalls: plateaus.map(\.displayName),
            lastSessionLabel: lastSessionLabel
        )
    }
}

private struct CoachNoteLLM: Decodable {
    let text: String
}
