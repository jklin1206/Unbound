import Foundation

struct CheckpointSummaryInput: Equatable, Sendable {
    var freeText: String
    var standardsCheck: CheckpointStandardsCheck
    var nutrition: NutritionContext?
    var missedSessionSignal: MissedSessionSignal

    init(
        freeText: String = "",
        standardsCheck: CheckpointStandardsCheck = .none,
        nutrition: NutritionContext? = nil,
        missedSessionSignal: MissedSessionSignal = .onTrack
    ) {
        self.freeText = freeText
        self.standardsCheck = standardsCheck
        self.nutrition = nutrition
        self.missedSessionSignal = missedSessionSignal
    }
}

struct CheckpointSummaryResult: Equatable, Sendable {
    var signals: CheckpointSignals
    var narrative: String
    var droppedWeakRegionIDs: [String]
    var ignoredAttemptedLoadAdjustmentBias: Double?
}

protocol CheckpointSummarizing: Sendable {
    func summarize(_ input: CheckpointSummaryInput) async -> CheckpointSummaryResult
}

extension CheckpointSignals {
    static func normalizedRecap(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= maxSummaryLength { return trimmed }
        return String(trimmed.prefix(maxSummaryLength))
    }
}

protocol CheckpointRecapGenerating: Sendable {
    func recap(input: CheckpointSummaryInput, signals: CheckpointSignals) async -> String?
}

struct LocalCheckpointRecapGenerator: CheckpointRecapGenerating {
    func recap(input: CheckpointSummaryInput, signals: CheckpointSignals) async -> String? {
        Self.deterministicNarrative(input: input, signals: signals)
    }

    static func deterministicNarrative(
        input: CheckpointSummaryInput,
        signals: CheckpointSignals
    ) -> String {
        var parts: [String] = []

        if input.standardsCheck.attemptedCount > 0 {
            parts.append(
                "You cleared \(input.standardsCheck.clearedCount) of \(input.standardsCheck.attemptedCount) standards."
            )
        } else {
            parts.append("Checkpoint saved.")
        }

        if input.standardsCheck.painFlagged {
            parts.append("Pain was flagged, so the next Arc will stay conservative.")
        } else if input.standardsCheck.formBreakdownFlagged {
            parts.append("Form breakdown was flagged, so the next Arc will keep pressure controlled.")
        } else {
            switch input.missedSessionSignal {
            case .onTrack:
                parts.append("Attendance stayed on track.")
            case .softCheckIn:
                parts.append("A few missed sessions point to a softer ramp.")
            case .resetRecommended:
                parts.append("Missed-session volume points to a reset-style ramp.")
            }
        }

        if let nutrition = signals.nutrition {
            parts.append("Protein target: \(nutrition.protein.displayText).")
        }

        let note = input.freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            parts.append("Your note: \(String(note.prefix(180)))")
        }

        parts.append("Training changes still come from validated rules, not the recap.")
        return CheckpointSignals.normalizedRecap(parts.joined(separator: " "))
    }
}

struct AIMonthlyCheckpointRecapGenerator: CheckpointRecapGenerating {
    private struct Payload: Decodable {
        let narrative: String
    }

    private static let toolName = "write_checkpoint_recap"
    private static let schemaJSON = """
    {
      "type": "object",
      "properties": {
        "narrative": {
          "type": "string",
          "description": "One polished end-of-Arc recap paragraph, 45-90 words."
        }
      },
      "required": ["narrative"],
      "additionalProperties": false
    }
    """

    var client: ClaudeClient
    var networkEnabled: Bool

    init(client: ClaudeClient = .shared, networkEnabled: Bool? = nil) {
        self.client = client
        self.networkEnabled = networkEnabled ?? !Self.isRunningUnderXCTest
    }

    func recap(input: CheckpointSummaryInput, signals: CheckpointSignals) async -> String? {
        guard networkEnabled else {
            return LocalCheckpointRecapGenerator.deterministicNarrative(input: input, signals: signals)
        }

        do {
            let schema = try JSONValue.fromJSONString(Self.schemaJSON)
            let tool = ClaudeClient.Tool(
                name: Self.toolName,
                description: "Writes one safe monthly/Arc recap paragraph from validated training facts.",
                inputSchema: schema
            )
            let payload: Payload = try await client.sendStructured(
                Payload.self,
                model: .haiku45,
                system: Self.systemPrompt,
                userText: Self.composedPrompt(input: input, signals: signals),
                tool: tool,
                maxTokens: 320,
                temperature: 0.35
            )
            let normalized = CheckpointSignals.normalizedRecap(payload.narrative)
            return normalized.isEmpty
                ? LocalCheckpointRecapGenerator.deterministicNarrative(input: input, signals: signals)
                : normalized
        } catch {
            LoggingService.shared.log(
                "AI checkpoint recap failed; using deterministic recap",
                level: .warning,
                context: ["error": "\(error)"]
            )
            return LocalCheckpointRecapGenerator.deterministicNarrative(input: input, signals: signals)
        }
    }

    static let systemPrompt = """
    You write the single end-of-Arc recap paragraph for UNBOUND, a fitness app.

    Hard boundary:
    - Do not choose exercises, sets, reps, loads, swaps, deloads, progressions, or skill placement.
    - Do not invent facts or infer body composition.
    - Do not grade, rate, or judge the user's body.
    - Do not promise results.
    - Use the user note only as subjective context.
    - The recap may explain the validated facts, but training changes come from deterministic rules.

    Style:
    - Grounded, premium, concise.
    - One paragraph, 45-90 words.
    - Address the user directly.
    - No hashtags, emojis, markdown, or generic hype.
    """

    static func composedPrompt(
        input: CheckpointSummaryInput,
        signals: CheckpointSignals
    ) -> String {
        """
        Write the end-of-Arc recap from these approved facts only.

        Standards attempted: \(input.standardsCheck.attemptedCount)
        Standards cleared: \(input.standardsCheck.clearedCount)
        Pain flagged: \(input.standardsCheck.painFlagged)
        Form breakdown flagged: \(input.standardsCheck.formBreakdownFlagged)
        Missed session signal: \(input.missedSessionSignal.rawValue)
        Validated load pressure: \(loadPressureText(signals.loadAdjustmentBias))
        Validated recovery signal: \(recoveryText(signals.recoveryStateHint))
        Validated weak regions: \(regionText(signals.weakRegions))
        Validated skill focus: \(skillText(signals.skillFocusHints))
        Nutrition context: \(nutritionText(signals.nutrition))
        User note for recap only: \(sanitizedNote(input.freeText))

        Reminder: the recap is language only. Do not create or imply new training decisions.
        """
    }

    private static func loadPressureText(_ bias: Double?) -> String {
        guard let bias else { return "neutral" }
        if bias > 0.05 { return "slight push" }
        if bias < -0.05 { return "softer" }
        return "neutral"
    }

    private static func recoveryText(_ state: RecoveryState?) -> String {
        switch state {
        case .wellRecovered: return "fresh"
        case .normal: return "normal"
        case .accumulated: return "accumulated fatigue"
        case .flagged: return "flagged"
        case .none: return "none"
        }
    }

    private static func regionText(_ regions: [BodyRegion]) -> String {
        regions.isEmpty ? "none" : regions.map(\.displayName).joined(separator: ", ")
    }

    private static func skillText(_ ids: [String]) -> String {
        ids.isEmpty ? "none" : ids.joined(separator: ", ")
    }

    private static func nutritionText(_ nutrition: NutritionContext?) -> String {
        guard let nutrition else { return "none" }
        return "\(nutrition.protein.displayText); \(nutrition.hydration.displayText)"
    }

    private static func sanitizedNote(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "none" }
        return String(trimmed.prefix(500))
    }

    private static var isRunningUnderXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

struct CheckpointSummarizer: CheckpointSummarizing {
    var validator: CheckpointValidator = CheckpointValidator()
    private let recapGenerator: any CheckpointRecapGenerating

    init(
        validator: CheckpointValidator = CheckpointValidator(),
        recapGenerator: any CheckpointRecapGenerating = AIMonthlyCheckpointRecapGenerator()
    ) {
        self.validator = validator
        self.recapGenerator = recapGenerator
    }

    func summarize(_ input: CheckpointSummaryInput) async -> CheckpointSummaryResult {
        let draft = deterministicDraft(from: input)
        let validated = validator.validate(
            CheckpointValidationInput(
                draft: draft,
                standardsCheck: input.standardsCheck,
                missedSessionSignal: input.missedSessionSignal
            )
        )
        let narrative = await recapGenerator.recap(input: input, signals: validated.signals)
            ?? LocalCheckpointRecapGenerator.deterministicNarrative(input: input, signals: validated.signals)
        let signals = CheckpointSignals(
            loadAdjustmentBias: validated.signals.loadAdjustmentBias,
            recoveryStateHint: validated.signals.recoveryStateHint,
            weakRegions: validated.signals.weakRegions,
            skillFocusHints: validated.signals.skillFocusHints,
            nutrition: validated.signals.nutrition,
            freeTextSummary: narrative
        )
        return CheckpointSummaryResult(
            signals: signals,
            narrative: narrative,
            droppedWeakRegionIDs: validated.droppedWeakRegionIDs,
            ignoredAttemptedLoadAdjustmentBias: validated.ignoredAttemptedLoadAdjustmentBias
        )
    }

    private func deterministicDraft(from input: CheckpointSummaryInput) -> CheckpointSignalDraft {
        CheckpointSignalDraft(
            recoveryStateHint: recoveryHint(from: input.standardsCheck),
            weakRegionIDs: [],
            skillFocusHints: [],
            nutrition: input.nutrition,
            freeTextSummary: nil
        )
    }

    private func recoveryHint(from standards: CheckpointStandardsCheck) -> RecoveryState? {
        if standards.painFlagged || standards.formBreakdownFlagged {
            return .flagged
        }
        return nil
    }
}

struct LocalCheckpointSummarizer: CheckpointSummarizing {
    var validator: CheckpointValidator = CheckpointValidator()

    func summarize(_ input: CheckpointSummaryInput) async -> CheckpointSummaryResult {
        await CheckpointSummarizer(
            validator: validator,
            recapGenerator: LocalCheckpointRecapGenerator()
        ).summarize(input)
    }
}
