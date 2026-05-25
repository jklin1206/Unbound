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

struct LocalCheckpointSummarizer: CheckpointSummarizing {
    var validator: CheckpointValidator = CheckpointValidator()

    func summarize(_ input: CheckpointSummaryInput) async -> CheckpointSummaryResult {
        let draft = CheckpointSignalDraft(
            recoveryStateHint: recoveryHint(from: input.freeText),
            weakRegionIDs: weakRegionIDs(from: input.freeText),
            skillFocusHints: skillHints(from: input.freeText),
            nutrition: input.nutrition,
            freeTextSummary: narrative(from: input.freeText)
        )
        let validated = validator.validate(
            CheckpointValidationInput(
                draft: draft,
                standardsCheck: input.standardsCheck,
                missedSessionSignal: input.missedSessionSignal
            )
        )
        return CheckpointSummaryResult(
            signals: validated.signals,
            narrative: validated.signals.freeTextSummary ?? fallbackNarrative,
            droppedWeakRegionIDs: validated.droppedWeakRegionIDs,
            ignoredAttemptedLoadAdjustmentBias: validated.ignoredAttemptedLoadAdjustmentBias
        )
    }

    private var fallbackNarrative: String {
        "Checkpoint saved. Your next Arc will use the logged training signals and keep changes conservative."
    }

    private func recoveryHint(from text: String) -> RecoveryState? {
        let normalized = text.lowercased()
        if normalized.contains("pain") || normalized.contains("injur") || normalized.contains("burnt") {
            return .flagged
        }
        if normalized.contains("tired") || normalized.contains("sore") || normalized.contains("drained") {
            return .accumulated
        }
        if normalized.contains("great") || normalized.contains("fresh") || normalized.contains("recovered") {
            return .wellRecovered
        }
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .normal
    }

    private func weakRegionIDs(from text: String) -> [String] {
        let normalized = text.lowercased()
        return BodyRegion.allCases.compactMap { region in
            let raw = region.rawValue.lowercased()
            let display = region.displayName.lowercased()
            return normalized.contains(raw) || normalized.contains(display) ? region.rawValue : nil
        }
    }

    private func skillHints(from text: String) -> [String] {
        let normalized = text.lowercased()
        let hints: [(needle: String, skillID: String)] = [
            ("pull", "strict_pull_up"),
            ("chin", "strict_pull_up"),
            ("handstand", "handstand"),
            ("dip", "dip"),
            ("l-sit", "l_sit"),
            ("lsit", "l_sit"),
            ("front lever", "front_lever"),
            ("muscle up", "muscle_up"),
            ("muscle-up", "muscle_up")
        ]
        var seen = Set<String>()
        return hints.compactMap { hint in
            guard normalized.contains(hint.needle), seen.insert(hint.skillID).inserted else {
                return nil
            }
            return hint.skillID
        }
    }

    private func narrative(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallbackNarrative }
        if trimmed.count <= 220 {
            return "Arc note: \(trimmed)"
        }
        return "Arc note: \(String(trimmed.prefix(220)))"
    }
}
