import Foundation

struct CheckpointFlow: Equatable, Sendable {
    enum Step: Equatable, Sendable {
        case entry
        case bodyCapture
        case standardsCheck
        case freeText
        case nutritionCheck
        case summarizing
        case review(CheckpointSignals)
        case commit(CheckpointOutcome)
        case cancelled
    }

    var step: Step = .entry
    var standardsCheck: CheckpointStandardsCheck = .none
    var freeText: String = ""
    var nutrition: NutritionContext?

    var outcome: CheckpointOutcome? {
        if case .commit(let outcome) = step { return outcome }
        return nil
    }

    mutating func begin() {
        guard step == .entry else { return }
        step = .bodyCapture
    }

    mutating func skip() {
        step = .commit(.skipped)
    }

    mutating func cancel() {
        step = .cancelled
        standardsCheck = .none
        freeText = ""
        nutrition = nil
    }

    mutating func advance() {
        switch step {
        case .entry:
            step = .bodyCapture
        case .bodyCapture:
            step = .standardsCheck
        case .standardsCheck:
            step = .freeText
        case .freeText:
            step = .nutritionCheck
        case .nutritionCheck:
            step = .summarizing
        case .summarizing, .review, .commit, .cancelled:
            break
        }
    }

    mutating func setStandardsCheck(_ check: CheckpointStandardsCheck) {
        standardsCheck = check
    }

    mutating func setFreeText(_ text: String) {
        freeText = String(text.prefix(1_000))
    }

    mutating func setNutrition(_ context: NutritionContext?) {
        nutrition = context
    }

    mutating func presentReview(signals: CheckpointSignals) {
        step = .review(signals)
    }

    mutating func commitReviewedSignals() {
        guard case .review(let signals) = step else { return }
        step = .commit(.completed(signals))
    }

    mutating func expireIfPastGraceWindow(
        arcEndedAt: Date,
        now: Date,
        graceHours: Int = 24,
        calendar: Calendar = .current
    ) {
        guard step == .entry else { return }
        let expiry = calendar.date(byAdding: .hour, value: graceHours, to: arcEndedAt) ?? arcEndedAt
        if now >= expiry {
            skip()
        }
    }
}
