import Foundation

// MARK: - AISessionGeneratorService
//
// Generates one skill-training session per day via Claude with same-day
// caching. The 12 keystone skills feed their authored static plan in as a
// reference methodology so day-to-day variation feels fresh while the
// methodology stays sound. The other 122 skills generate from scratch using
// node metadata only.
//
// Falls back to the authored static plan from `SkillTrainingPlanLibrary` (or
// a minimal AMRAP shell) if the API call or decode fails — so the user
// always gets a workable session.

@MainActor
final class AISessionGeneratorService {

    // MARK: Singleton

    static let shared = AISessionGeneratorService()

    // MARK: Configuration

    private let cacheKeyPrefix = "unbound.aiSession."
    private let defaultEquipment: [String] = ["bodyweight", "pull-up bar", "rings", "parallettes"]
    private let defaultTimeBudgetMinutes = 25

    // MARK: Dependencies

    private var logger: LoggingService { LoggingService.shared }
    private var database: DatabaseServiceProtocol { DatabaseService.shared }

    private init() {}

    // MARK: Public API

    /// Returns an AI-generated session for the given skill. Same-day cached
    /// in UserDefaults under key "<prefix><skillId>.<yyyy-mm-dd>".
    /// - Parameters:
    ///   - skillId: the skill being trained
    ///   - userId: current user (for log context + cache scoping safety)
    ///   - forceRefresh: bypass cache and regenerate
    func session(forSkillId skillId: String,
                 userId: String,
                 forceRefresh: Bool = false) async throws -> AISession {
        let key = cacheKey(skillId: skillId, day: Date())
        if !forceRefresh, let cached = loadCached(key: key) {
            return cached
        }

        let ctx = await buildContext(skillId: skillId, userId: userId)

        do {
            let session = try await generateViaClaude(context: ctx)
            saveCached(key: key, session: session)
            return session
        } catch {
            logger.log("AISessionGenerator: Claude call failed (\(error.localizedDescription)) — falling back",
                       level: .warning)
            let fallback = fallbackSession(for: skillId, context: ctx)
            // Don't cache a failure — if the API recovers later today the user
            // should get the AI version on next open.
            return fallback
        }
    }

    // MARK: - V4: Suggest weekly schedule

    /// V4 — Generates a 7-day weekly category split tailored to the user's
    /// active goals via Claude. Returns a Mon=0..Sun=6 array of `DayCategory`.
    /// Caller should populate the editor's draft state and let the user
    /// review + commit (we don't auto-save).
    func suggestWeeklySchedule(
        activeGoalIds: Set<String>,
        userId: String
    ) async throws -> [DayCategory] {
        let graph = SkillGraph.shared
        let goalSummaries: [String] = activeGoalIds.compactMap { id in
            guard let node = graph.node(id: id) else { return nil }
            return "\(node.title) (\(node.cluster.displayName))"
        }

        let system = """
        You are a calisthenics coach designing a weekly training split. Given the user's active skill goals (each with a body-part category), produce a 7-day schedule that distributes work intelligently — typically 1 rest day, often 1-2 conditioning days, with body-part splits aligning to active goals. Avoid back-to-back same-category days unless necessary. Return exactly 7 entries, indexed Mon=0..Sun=6.

        Allowed values for each entry (DayCategory.rawValue):
        - "push" — pressing strength
        - "pull" — pulling strength + back / pull-up family
        - "legs" — squat / lunge / leg drive
        - "core" — core + lever family
        - "skills" — handstand / planche / static skill work
        - "conditioning" — cardio / metcons / work capacity
        - "rest" — full recovery
        """

        let userText: String = {
            if goalSummaries.isEmpty {
                return "Active goals: (none yet — design a balanced general split)\n\nSuggest a 7-day weekly split."
            }
            let list = goalSummaries.joined(separator: ", ")
            return "Active goals: \(list).\n\nSuggest a 7-day weekly split."
        }()

        let tool = scheduleSuggestionTool

        let payload: ClaudeSchedulePayload = try await ClaudeClient.shared.sendStructured(
            ClaudeSchedulePayload.self,
            model: .sonnet46,
            system: system,
            userText: userText,
            tool: tool,
            maxTokens: 512
        )

        // Decode + sanitize. Anything we can't map falls back to .rest.
        let mapped: [DayCategory] = payload.schedule.prefix(7).map { raw in
            DayCategory(rawValue: raw.lowercased()) ?? .rest
        }

        // Pad to exactly 7 if Claude returned fewer (defensive).
        var out = mapped
        while out.count < 7 { out.append(.rest) }
        return Array(out.prefix(7))
    }

    private struct ClaudeSchedulePayload: Decodable {
        let schedule: [String]
    }

    private var scheduleSuggestionTool: ClaudeClient.Tool {
        let allowed: [JSONValue] = DayCategory.allCases.map { .string($0.rawValue) }
        let schema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "schedule": .object([
                    "type": .string("array"),
                    "description": .string("Exactly 7 day-categories, indexed Mon=0..Sun=6"),
                    "items": .object([
                        "type": .string("string"),
                        "enum": .array(allowed)
                    ])
                ])
            ]),
            "required": .array([.string("schedule")])
        ])
        return ClaudeClient.Tool(
            name: "submit_schedule",
            description: "Submit a 7-day weekly training split as a structured JSON array.",
            inputSchema: schema
        )
    }

    // MARK: - Context build

    fileprivate struct SessionContext {
        let skill: ContextSkill
        let userLevel: Int
        let levelTarget: String
        let recentSessions: [ContextSession]
        let equipment: [String]
        let timeBudgetMinutes: Int
        let staticPlanReference: String?
        let daysSinceLastSession: Int?
        let weekPhase: WeekPhase
    }

    fileprivate struct ContextSkill {
        let id: String
        let title: String
        let cluster: String
        let formCues: [String]
        let commonMistakes: [String]
        let levels: [(level: Int, criterion: String)]
    }

    fileprivate struct ContextSession {
        let date: Date
        let exercises: [(name: String, sets: Int, totalReps: Int, avgRPE: Int?)]
    }

    private func buildContext(skillId: String, userId: String) async -> SessionContext {
        let node = SkillGraph.shared.node(id: skillId)

        let title = node?.title ?? skillId
        let cluster = node?.cluster.displayName ?? "—"
        let formCues = node?.formCues ?? []
        let commonMistakes = node?.commonMistakes ?? []
        let levelPairs: [(Int, String)] = (node?.levels ?? []).map { ($0.level, $0.criterion) }

        let progress = SkillProgressService.shared.currentSkillProgress(for: skillId)
        let userLevel = progress.currentLevel

        let levelTarget: String = {
            // Next-target criterion = the level the user is currently working on.
            // SkillProgress.currentLevel is the level they've already cleared,
            // so the active target is the next one (clamped to 5).
            let target = min(max(userLevel, 1), 5)
            if let match = levelPairs.first(where: { $0.0 == target }) {
                return match.1
            }
            return "Earn the next rank"
        }()

        let recent = await fetchRecentSessions(skillId: skillId, userId: userId, limit: 5)
        let daysSinceLast: Int? = {
            guard let mostRecent = recent.first?.date else { return nil }
            let secs = Date().timeIntervalSince(mostRecent)
            return Int(secs / 86_400)
        }()

        let staticPlanReference = serializeStaticPlan(skillId: skillId)
        let weekPhase = SkillProgressService.shared.currentWeekPhase

        return SessionContext(
            skill: ContextSkill(
                id: skillId,
                title: title,
                cluster: cluster,
                formCues: formCues,
                commonMistakes: commonMistakes,
                levels: levelPairs
            ),
            userLevel: userLevel,
            levelTarget: levelTarget,
            recentSessions: recent,
            equipment: defaultEquipment,
            timeBudgetMinutes: defaultTimeBudgetMinutes,
            staticPlanReference: staticPlanReference,
            daysSinceLastSession: daysSinceLast,
            weekPhase: weekPhase
        )
    }

    private func fetchRecentSessions(skillId: String, userId: String, limit: Int) async -> [ContextSession] {
        do {
            let logs: [SessionLog] = try await database.query(
                collection: "sessionLogs",
                field: "skillId",
                isEqualTo: skillId,
                orderBy: "createdAt",
                descending: true,
                limit: limit
            )
            return logs
                .filter { $0.userId == userId }
                .map { log in
                    let exes: [(name: String, sets: Int, totalReps: Int, avgRPE: Int?)] = log.exercises.map { ex in
                        let totalReps = ex.sets.reduce(0) { $0 + $1.reps }
                        let rpes = ex.sets.compactMap(\.rpe)
                        let avgRPE: Int? = rpes.isEmpty ? nil : Int((rpes.reduce(0, +) / max(rpes.count, 1)))
                        return (ex.name, ex.sets.count, totalReps, avgRPE)
                    }
                    return ContextSession(date: log.createdAt, exercises: exes)
                }
        } catch {
            logger.log("AISessionGenerator: failed to read recent sessions: \(error.localizedDescription)",
                       level: .warning)
            return []
        }
    }

    private func serializeStaticPlan(skillId: String) -> String? {
        guard let plan = SkillTrainingPlanLibrary.plan(for: skillId) else { return nil }
        var lines: [String] = []
        lines.append("Main work:")
        for rx in plan.mainSets {
            lines.append("  - \(rx.exerciseName) — \(rx.sets) × \(rx.targetDescription) (rest \(rx.restSeconds)s)\(rx.notes.map { " — \($0)" } ?? "")")
        }
        if !plan.regressions.isEmpty {
            lines.append("Regressions (for users below Lv1):")
            for r in plan.regressions {
                lines.append("  - \(r.name): \(r.cues.joined(separator: "; "))")
            }
        }
        if !plan.accessories.isEmpty {
            lines.append("Accessories (optional supporting work):")
            for a in plan.accessories {
                lines.append("  - \(a.name): \(a.cues.joined(separator: "; "))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Claude call

    private func generateViaClaude(context ctx: SessionContext) async throws -> AISession {
        let system = systemPrompt
        let userText = userPrompt(for: ctx)
        let tool = sessionTool

        let raw: ClaudeSessionPayload = try await ClaudeClient.shared.sendStructured(
            ClaudeSessionPayload.self,
            model: .sonnet46,
            system: system,
            userText: userText,
            tool: tool,
            maxTokens: 2048
        )

        return decode(payload: raw, skillId: ctx.skill.id)
    }

    private var systemPrompt: String {
        """
        You are a calisthenics + bodyweight strength coach. You generate ONE skill-specific training session as a structured JSON object via the provided tool. Your sessions:

        1. Are FOCUSED — 3 to 5 exercises, no more. A workout is one cluster of work, not a buffet.
        2. Match the user's current level. If they're brand new, prescribe regressions and form drills. If advanced, prescribe heavier or harder variants.
        3. Avoid prescribing other named skill-tree milestones as drills. Use generic drill names (e.g., "Scapular Pulls", "Australian Pull-Up", "Negative Pull-Up", "Band-Assisted Pull-Up", "Hollow Body Hold") — NOT "Weighted Pull-Up" or "Strict Muscle-Up" if those are separate skills the user is working toward.
        4. Include 2-3 short form cues per exercise.
        5. Vary day-to-day — don't repeat the exact same prescription as recent sessions. Rotate volume / strength / tempo emphasis.
        6. Stay within the user's time budget. Estimate honest duration.
        7. If the user has missed a session for >7 days, prescribe a slightly lighter "ramp-back" session.
        8. NEVER prescribe more than 5 working sets across all exercises in a single session.
        9. SCALE prescriptions to the user's WEEK PHASE:
           - Heavy: lean into strength/load — lower reps, harder progressions, longer rest.
           - Moderate: balanced volume + intensity — default behavior.
           - Light: tempo work, technique focus, lower-intensity drills, mid-range reps.
           - Deload: substitute mobility / light skill drills only — no max-effort sets.

        The 'is_accessory' flag marks supplementary work the user can skip if pressed for time. Mark 1-2 accessories per session.
        """
    }

    private func userPrompt(for ctx: SessionContext) -> String {
        var parts: [String] = []
        parts.append("Generate today's training session for the user.")
        parts.append("")
        parts.append("SKILL: \(ctx.skill.title)")
        parts.append("TREE: \(ctx.skill.cluster)")
        parts.append("USER LEVEL: Lv \(ctx.userLevel) / 5")
        parts.append("NEXT TARGET: \(ctx.levelTarget)")
        parts.append("USER WEEK PHASE: \(ctx.weekPhase.displayName) — \(ctx.weekPhase.description)")

        if !ctx.skill.formCues.isEmpty {
            parts.append("FORM PRIORITIES (from skill metadata):")
            parts.append("- " + ctx.skill.formCues.joined(separator: "\n- "))
        }
        if !ctx.skill.commonMistakes.isEmpty {
            parts.append("COMMON MISTAKES:")
            parts.append("- " + ctx.skill.commonMistakes.joined(separator: "\n- "))
        }

        parts.append("")
        if ctx.recentSessions.isEmpty {
            parts.append("RECENT SESSIONS (most recent first):")
            parts.append("No recent sessions")
        } else {
            parts.append("RECENT SESSIONS (most recent first):")
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            for s in ctx.recentSessions {
                let day = dateFmt.string(from: s.date)
                let exParts = s.exercises.map { ex -> String in
                    let avgReps = ex.sets > 0 ? ex.totalReps / max(ex.sets, 1) : 0
                    return "\(ex.name) \(ex.sets)×\(avgReps)"
                }
                parts.append("\(day): \(exParts.joined(separator: ", "))")
            }
        }

        if let days = ctx.daysSinceLastSession, days > 7 {
            parts.append("")
            parts.append("USER HAS NOT TRAINED THIS SKILL IN \(days) DAYS — prescribe a slightly lighter ramp-back session.")
        }

        parts.append("")
        parts.append("EQUIPMENT AVAILABLE: \(ctx.equipment.joined(separator: ", "))")
        parts.append("TIME BUDGET: \(ctx.timeBudgetMinutes) minutes")

        if let ref = ctx.staticPlanReference {
            parts.append("")
            parts.append("REFERENCE METHODOLOGY (anchor your session in this proven structure but vary day-to-day):")
            parts.append(ref)
        }

        parts.append("")
        parts.append("Generate the session now using the `submit_session` tool. Return 3-5 exercises total, focused work, varied from recent history.")

        return parts.joined(separator: "\n")
    }

    private var sessionTool: ClaudeClient.Tool {
        let schema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "summary": .object([
                    "type": .string("string"),
                    "description": .string("One sentence overview of today's session emphasis")
                ]),
                "estimated_duration_minutes": .object([
                    "type": .string("integer")
                ]),
                "exercises": .object([
                    "type": .string("array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object(["type": .string("string")]),
                            "description": .object([
                                "type": .string("string"),
                                "description": .string("One-sentence plain-language description of what this exercise is")
                            ]),
                            "cues": .object([
                                "type": .string("array"),
                                "items": .object(["type": .string("string")]),
                                "description": .string("2-3 form cues")
                            ]),
                            "sets_count": .object(["type": .string("integer")]),
                            "target_kind": .object([
                                "type": .string("string"),
                                "enum": .array([
                                    .string("reps"),
                                    .string("reps_range"),
                                    .string("amrap"),
                                    .string("hold"),
                                    .string("tempo")
                                ])
                            ]),
                            "target_reps": .object([
                                "type": .string("integer"),
                                "description": .string("Required if target_kind = reps, omit otherwise")
                            ]),
                            "target_reps_lo": .object(["type": .string("integer")]),
                            "target_reps_hi": .object(["type": .string("integer")]),
                            "target_hold_seconds": .object(["type": .string("integer")]),
                            "target_tempo_reps": .object(["type": .string("integer")]),
                            "target_tempo_eccentric": .object(["type": .string("integer")]),
                            "target_tempo_hold": .object(["type": .string("integer")]),
                            "target_tempo_concentric": .object(["type": .string("integer")]),
                            "rest_seconds": .object(["type": .string("integer")]),
                            "notes": .object([
                                "type": .string("string"),
                                "description": .string("Optional 1-line note about progression or scaling")
                            ]),
                            "is_accessory": .object(["type": .string("boolean")])
                        ]),
                        "required": .array([
                            .string("name"),
                            .string("description"),
                            .string("cues"),
                            .string("sets_count"),
                            .string("target_kind"),
                            .string("rest_seconds"),
                            .string("is_accessory")
                        ])
                    ])
                ])
            ]),
            "required": .array([
                .string("summary"),
                .string("estimated_duration_minutes"),
                .string("exercises")
            ])
        ])

        return ClaudeClient.Tool(
            name: "submit_session",
            description: "Submit the generated training session as structured JSON.",
            inputSchema: schema
        )
    }

    // MARK: - Decode

    /// Tool-call payload matching the schema above.
    private struct ClaudeSessionPayload: Decodable {
        let summary: String
        let estimated_duration_minutes: Int
        let exercises: [ClaudeExercisePayload]
    }

    private struct ClaudeExercisePayload: Decodable {
        let name: String
        let description: String
        let cues: [String]
        let sets_count: Int
        let target_kind: String
        let target_reps: Int?
        let target_reps_lo: Int?
        let target_reps_hi: Int?
        let target_hold_seconds: Int?
        let target_tempo_reps: Int?
        let target_tempo_eccentric: Int?
        let target_tempo_hold: Int?
        let target_tempo_concentric: Int?
        let rest_seconds: Int
        let notes: String?
        let is_accessory: Bool
    }

    private func decode(payload: ClaudeSessionPayload, skillId: String) -> AISession {
        let exercises: [AIExercise] = payload.exercises.map { ex in
            let target: AIPrescriptionTarget = {
                switch ex.target_kind.lowercased() {
                case "reps":
                    return .reps(ex.target_reps ?? 5)
                case "reps_range":
                    let lo = ex.target_reps_lo ?? 5
                    let hi = ex.target_reps_hi ?? max(lo, 8)
                    return .repsRange(lo, hi)
                case "amrap":
                    return .amrap
                case "hold":
                    return .hold(seconds: ex.target_hold_seconds ?? 30)
                case "tempo":
                    return .tempo(
                        reps: ex.target_tempo_reps ?? 5,
                        eccentric: ex.target_tempo_eccentric ?? 3,
                        hold: ex.target_tempo_hold ?? 1,
                        concentric: ex.target_tempo_concentric ?? 1
                    )
                default:
                    return .reps(ex.target_reps ?? 5)
                }
            }()

            return AIExercise(
                name: ex.name,
                description: ex.description,
                cues: ex.cues,
                setsCount: max(1, ex.sets_count),
                target: target,
                restSeconds: max(15, ex.rest_seconds),
                notes: (ex.notes?.isEmpty ?? true) ? nil : ex.notes,
                isAccessory: ex.is_accessory
            )
        }

        return AISession(
            skillId: skillId,
            generatedAt: Date(),
            summary: payload.summary,
            estimatedDurationMinutes: payload.estimated_duration_minutes,
            exercises: exercises,
            isAIGenerated: true
        )
    }

    // MARK: - Fallback

    private func fallbackSession(for skillId: String, context ctx: SessionContext) -> AISession {
        if let plan = SkillTrainingPlanLibrary.plan(for: skillId) {
            let mainExercises: [AIExercise] = plan.mainSets.map { rx in
                AIExercise(
                    name: rx.exerciseName,
                    description: ExerciseExplainerLibrary.description(for: rx.exerciseName)
                        ?? "Today's main work for \(ctx.skill.title).",
                    cues: [],
                    setsCount: rx.sets,
                    target: legacyToAITarget(rx.target),
                    restSeconds: rx.restSeconds,
                    notes: rx.notes,
                    isAccessory: false
                )
            }
            let accessoryExercises: [AIExercise] = plan.accessories.prefix(2).map { ex in
                AIExercise(
                    name: ex.name,
                    description: ExerciseExplainerLibrary.description(for: ex.name)
                        ?? "Optional supporting work.",
                    cues: ex.cues,
                    setsCount: 1,
                    target: .amrap,
                    restSeconds: 60,
                    notes: nil,
                    isAccessory: true
                )
            }
            return AISession(
                skillId: skillId,
                generatedAt: Date(),
                summary: "Today's plan: \(ctx.skill.title) — keystone methodology.",
                estimatedDurationMinutes: ctx.timeBudgetMinutes,
                exercises: mainExercises + accessoryExercises,
                isAIGenerated: false
            )
        }

        // No authored plan — minimal default.
        let single = AIExercise(
            name: ctx.skill.title,
            description: "Train today's skill — quality reps over volume.",
            cues: ctx.skill.formCues.prefix(3).map { $0 },
            setsCount: 3,
            target: .amrap,
            restSeconds: 90,
            notes: "Stop each set when form breaks. Log what you hit.",
            isAccessory: false
        )
        return AISession(
            skillId: skillId,
            generatedAt: Date(),
            summary: "Today's plan: \(ctx.skill.title).",
            estimatedDurationMinutes: ctx.timeBudgetMinutes,
            exercises: [single],
            isAIGenerated: false
        )
    }

    private func legacyToAITarget(_ t: PrescriptionTarget) -> AIPrescriptionTarget {
        switch t {
        case .reps(let r):                       return .reps(r)
        case .repsRange(let lo, let hi):         return .repsRange(lo, hi)
        case .amrap:                             return .amrap
        case .hold(let s):                       return .hold(seconds: s)
        case .tempo(let r, let e, let h, let c): return .tempo(reps: r, eccentric: e, hold: h, concentric: c)
        }
    }

    // MARK: - Cache

    private func cacheKey(skillId: String, day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return cacheKeyPrefix + skillId + "." + formatter.string(from: day)
    }

    private func loadCached(key: String) -> AISession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AISession.self, from: data)
    }

    private func saveCached(key: String, session: AISession) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

