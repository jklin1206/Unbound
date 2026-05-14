import Foundation

// MARK: - PlateauFixService
//
// One-shot AI diagnosis for a stalled lift. Returns a structured result:
// diagnosis sentence + 3-week prescription. No back-and-forth. Called
// from PlateauFixSheet — result shown as a card, no chat box.

@MainActor
final class PlateauFixService {
    static let shared = PlateauFixService()
    private let claude = ClaudeClient.shared
    private let database = DatabaseService.shared
    private init() {}

    struct PlateauFix {
        let exerciseName: String
        let diagnosis: String          // 1-2 sentences — why it's stalled
        let weeks: [FixWeek]
    }

    struct FixWeek {
        let label: String              // "WEEK 1", "WEEK 2", "WEEK 3"
        let focus: String              // "Volume drop", "Technique reset", etc.
        let instruction: String        // Concrete single-sentence directive
    }

    func generate(for plateau: PlateauedExercise, userId: String) async throws -> PlateauFix {
        let states: [ProgressionState] = (try? await database.query(
            collection: "progression_states",
            field: "userId",
            isEqualTo: userId,
            orderBy: "updatedAt",
            descending: true,
            limit: 20
        )) ?? []

        let matchedState = states.first {
            $0.exerciseKey.contains(plateau.exerciseKey.lowercased())
        }

        let context = buildContext(plateau: plateau, state: matchedState)

        let payload: PlateauFixPayload = try await claude.sendStructured(
            PlateauFixPayload.self,
            model: .sonnet46,
            system: systemPrompt,
            userText: context,
            tool: fixTool,
            maxTokens: 512
        )

        return PlateauFix(
            exerciseName: plateau.displayName,
            diagnosis: payload.diagnosis,
            weeks: payload.weeks.map {
                FixWeek(label: $0.label, focus: $0.focus, instruction: $0.instruction)
            }
        )
    }

    // MARK: - Context builder

    private func buildContext(plateau: PlateauedExercise, state: ProgressionState?) -> String {
        var ctx = "Stalled lift: \(plateau.displayName)\n"
        ctx += "Sessions without progression: \(plateau.stalledSessions)\n"
        if let s = state {
            ctx += "Current working weight: \(s.currentWorkingWeightKg)kg\n"
            ctx += "Target rep range: \(s.targetRepMin)–\(s.targetRepMax)\n"
            ctx += "Target RPE: \(s.targetRPE)\n"
            ctx += "Block: \(s.blockType.rawValue), week \(s.weekInBlock)\n"
        }
        ctx += "\nDiagnose why this lift is stuck and give a 3-week fix plan."
        return ctx
    }

    // MARK: - Prompt

    private let systemPrompt = """
    You are a direct, evidence-based strength coach. No fluff.
    Diagnose plateau causes from the data (insufficient volume, too high RPE, \
    frequency, technique breakdown, fatigue, etc.). Give a concrete 3-week \
    prescription. Each week = one clear directive.
    """

    // MARK: - Tool

    private var fixTool: ClaudeClient.Tool {
        ClaudeClient.Tool(
            name: "plateau_fix",
            description: "Plateau diagnosis and 3-week fix",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "diagnosis": .object(["type": .string("string")]),
                    "weeks": .object([
                        "type": .string("array"),
                        "minItems": .integer(3),
                        "maxItems": .integer(3),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object([
                                "label": .object(["type": .string("string")]),
                                "focus": .object(["type": .string("string")]),
                                "instruction": .object(["type": .string("string")])
                            ]),
                            "required": .array([.string("label"), .string("focus"), .string("instruction")])
                        ])
                    ])
                ]),
                "required": .array([.string("diagnosis"), .string("weeks")])
            ])
        )
    }
}

// MARK: - Decodable payload

private struct PlateauFixPayload: Decodable {
    struct WeekPayload: Decodable {
        let label: String
        let focus: String
        let instruction: String
    }
    let diagnosis: String
    let weeks: [WeekPayload]
}
