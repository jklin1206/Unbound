import Foundation

struct CheckpointSignalDraft: Equatable, Sendable {
    var recoveryStateHint: RecoveryState?
    var weakRegionIDs: [String]
    var skillFocusHints: [String]
    var nutrition: NutritionContext?
    var freeTextSummary: String?
    /// Kept only so AI/direct callers can be safely ignored. Load bias must be
    /// computed by `CheckpointValidator` from structured checkpoint signals.
    var attemptedLoadAdjustmentBias: Double?

    init(
        recoveryStateHint: RecoveryState? = nil,
        weakRegionIDs: [String] = [],
        skillFocusHints: [String] = [],
        nutrition: NutritionContext? = nil,
        freeTextSummary: String? = nil,
        attemptedLoadAdjustmentBias: Double? = nil
    ) {
        self.recoveryStateHint = recoveryStateHint
        self.weakRegionIDs = weakRegionIDs
        self.skillFocusHints = skillFocusHints
        self.nutrition = nutrition
        self.freeTextSummary = freeTextSummary
        self.attemptedLoadAdjustmentBias = attemptedLoadAdjustmentBias
    }
}

struct CheckpointStandardsCheck: Codable, Equatable, Sendable {
    var attemptedCount: Int
    var clearedCount: Int
    var painFlagged: Bool
    var formBreakdownFlagged: Bool

    init(
        attemptedCount: Int = 0,
        clearedCount: Int = 0,
        painFlagged: Bool = false,
        formBreakdownFlagged: Bool = false
    ) {
        self.attemptedCount = max(0, attemptedCount)
        self.clearedCount = min(max(0, clearedCount), max(0, attemptedCount))
        self.painFlagged = painFlagged
        self.formBreakdownFlagged = formBreakdownFlagged
    }

    static let none = CheckpointStandardsCheck()

    var clearRate: Double? {
        guard attemptedCount > 0 else { return nil }
        return Double(clearedCount) / Double(attemptedCount)
    }
}

enum MissedSessionSignal: String, Codable, Sendable {
    case onTrack
    case softCheckIn
    case resetRecommended

    static func fromScheduledSessions(scheduled: Int, missed: Int) -> MissedSessionSignal {
        guard scheduled > 0 else { return .onTrack }
        let ratio = Double(max(0, missed)) / Double(scheduled)
        if ratio >= 0.8 { return .resetRecommended }
        if ratio >= 0.25 { return .softCheckIn }
        return .onTrack
    }
}

struct CheckpointValidationInput: Equatable, Sendable {
    var draft: CheckpointSignalDraft
    var standardsCheck: CheckpointStandardsCheck
    var missedSessionSignal: MissedSessionSignal
    var cardioMinutesLastWeek: Int

    init(
        draft: CheckpointSignalDraft,
        standardsCheck: CheckpointStandardsCheck = .none,
        missedSessionSignal: MissedSessionSignal = .onTrack,
        cardioMinutesLastWeek: Int = 0
    ) {
        self.draft = draft
        self.standardsCheck = standardsCheck
        self.missedSessionSignal = missedSessionSignal
        self.cardioMinutesLastWeek = max(0, cardioMinutesLastWeek)
    }
}

struct CheckpointValidationResult: Equatable, Sendable {
    var signals: CheckpointSignals
    var droppedWeakRegionIDs: [String]
    var ignoredAttemptedLoadAdjustmentBias: Double?
}

struct CheckpointValidator: Sendable {
    func validate(_ input: CheckpointValidationInput) -> CheckpointValidationResult {
        let regionResolution = resolveWeakRegions(input.draft.weakRegionIDs)
        if !regionResolution.dropped.isEmpty {
            LoggingService.shared.log(
                "Checkpoint dropped unknown weak region ids",
                level: .warning,
                context: ["ids": regionResolution.dropped]
            )
        }

        let resolvedRecoveryState = recoveryStateAdjustedForCardio(
            input.draft.recoveryStateHint,
            cardioMinutesLastWeek: input.cardioMinutesLastWeek
        )
        let bias = computeLoadAdjustmentBias(
            recoveryState: resolvedRecoveryState,
            standardsCheck: input.standardsCheck,
            missedSessionSignal: input.missedSessionSignal,
            cardioMinutesLastWeek: input.cardioMinutesLastWeek
        )

        return CheckpointValidationResult(
            signals: CheckpointSignals(
                loadAdjustmentBias: bias,
                recoveryStateHint: resolvedRecoveryState,
                weakRegions: regionResolution.regions,
                skillFocusHints: input.draft.skillFocusHints,
                nutrition: input.draft.nutrition,
                freeTextSummary: input.draft.freeTextSummary
            ),
            droppedWeakRegionIDs: regionResolution.dropped,
            ignoredAttemptedLoadAdjustmentBias: input.draft.attemptedLoadAdjustmentBias
        )
    }

    func normalize(_ signals: CheckpointSignals) -> CheckpointSignals {
        CheckpointSignals(
            loadAdjustmentBias: signals.loadAdjustmentBias,
            recoveryStateHint: signals.recoveryStateHint,
            weakRegions: signals.weakRegions,
            skillFocusHints: signals.skillFocusHints,
            nutrition: signals.nutrition,
            freeTextSummary: signals.freeTextSummary
        )
    }

    private func computeLoadAdjustmentBias(
        recoveryState: RecoveryState?,
        standardsCheck: CheckpointStandardsCheck,
        missedSessionSignal: MissedSessionSignal,
        cardioMinutesLastWeek: Int
    ) -> Double {
        var bias = 0.0

        switch recoveryState {
        case .wellRecovered:
            bias += 0.12
        case .normal, .none:
            break
        case .accumulated:
            bias -= 0.16
        case .flagged:
            bias -= 0.32
        }

        switch missedSessionSignal {
        case .onTrack:
            break
        case .softCheckIn:
            bias -= 0.08
        case .resetRecommended:
            bias -= 0.22
        }

        switch cardioMinutesLastWeek {
        case 181...:
            bias -= 0.12
        case 60...180:
            bias -= 0.04
        default:
            break
        }

        if standardsCheck.painFlagged || standardsCheck.formBreakdownFlagged {
            bias -= 0.16
        } else if let clearRate = standardsCheck.clearRate {
            if clearRate >= 0.85 {
                bias += 0.05
            } else if clearRate < 0.5 {
                bias -= 0.08
            }
        }

        return CheckpointSignals.clampedLoadAdjustmentBias(bias)
    }

    private func recoveryStateAdjustedForCardio(
        _ state: RecoveryState?,
        cardioMinutesLastWeek minutes: Int
    ) -> RecoveryState? {
        switch minutes {
        case 181...:
            switch state {
            case .flagged:
                return .flagged
            case .accumulated:
                return .flagged
            case .wellRecovered, .normal, .none:
                return .accumulated
            }
        case 60...180:
            if state == .wellRecovered {
                return .normal
            }
            return state
        default:
            return state
        }
    }

    private func resolveWeakRegions(_ rawIDs: [String]) -> (regions: [BodyRegion], dropped: [String]) {
        var regions: [BodyRegion] = []
        var dropped: [String] = []
        var seen = Set<BodyRegion>()

        for rawID in rawIDs {
            let normalized = rawID
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")

            guard !normalized.isEmpty else { continue }

            if let region = BodyRegion.allCases.first(where: {
                $0.rawValue.lowercased().replacingOccurrences(of: "_", with: "") == normalized
                    || $0.displayName.lowercased().replacingOccurrences(of: " ", with: "") == normalized
            }) {
                if seen.insert(region).inserted {
                    regions.append(region)
                }
            } else {
                dropped.append(rawID)
            }
        }

        return (regions, dropped)
    }
}
