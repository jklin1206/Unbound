// UNBOUND/Services/Trials/TrialsServiceProtocol.swift
import Foundation

struct WeeklyVowCompletionReceipt: Equatable, Sendable {
    let vow: WeeklyVow
    let performanceLogId: String
    let completedAt: Date
    let callout: WeeklyVowRewardCallout
    let completionBonus: WeeklyVowCompletionBonus

    init(
        vow: WeeklyVow,
        performanceLog: PerformanceLog,
        completionBonus: WeeklyVowCompletionBonus
    ) {
        self.vow = vow
        self.performanceLogId = performanceLog.id
        self.completedAt = performanceLog.completedAt
        self.completionBonus = completionBonus
        self.callout = WeeklyVowRewardCallout(
            id: "weekly-vow-\(vow.id)-\(performanceLog.id)",
            vowId: vow.id,
            performanceLogId: performanceLog.id,
            cardKind: vow.chosenCard.kind,
            theme: vow.chosenCard.theme,
            title: "\(vow.chosenCard.displayName) Cleared",
            subtitle: vow.chosenCard.displayName,
            proofName: vow.chosenCard.capstone.displayName,
            receiptLine: "Receipt \(Self.shortReceiptId(performanceLog.id))",
            shareTitle: "Binding Vow Cleared",
            shareSubtitle: "\(vow.chosenCard.displayName) - \(vow.chosenCard.capstone.displayName)",
            completedAt: performanceLog.completedAt,
            completionBonus: completionBonus
        )
    }

    private static func shortReceiptId(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "SAVED" }
        return String(trimmed.prefix(8)).uppercased()
    }
}

@MainActor
protocol WeeklyVowsServiceProtocol: AnyObject {
    /// If currentWeekStart is stale or absent, roll the week and generate
    /// 3 fresh cards. Marks prior vow as .missed if uncompleted.
    /// Posts .weeklyVowWeekRolled.
    func ensureCurrentWeek(userId: String) async

    /// User picks one of the 3 cards. Persists as currentVow.
    func pickVowCard(_ card: WeeklyVowCard, userId: String)

    /// User skipped the pick this week. No vow active; no chip; no penalty.
    func skipThisWeek(userId: String)

    /// Build real trainable work for a committed vow. The returned draft is
    /// routed through Workout Ready and the active logger.
    func trainingDraft(for vow: WeeklyVow, date: Date) -> TrainingSessionDraft

    /// Build real trainable work for the user's current vow, if one exists.
    func trainingDraftForCurrentVow(userId: String, date: Date) -> TrainingSessionDraft?

    /// Legacy adapter retained for older callers. Binding vows now complete
    /// only through `recordCompletedVowWork` after a saved routed workout.
    func completeVow(userId: String, at date: Date)

    /// Mark the current vow complete only after its routed PerformanceLog was
    /// accepted by TrainingCompletionService.
    @discardableResult
    func recordCompletedVowWork(
        performanceLog: PerformanceLog,
        completionResult: TrainingCompletionResult
    ) -> WeeklyVowCompletionReceipt?

    /// Legacy adapter retained for older callers. Raw history can no longer
    /// seal vows; saved routed workout receipts are required.
    func evaluateVowProofFromLog(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) async

    /// Caller invokes from app foreground / home appear to transition
    /// pending -> windowOpen when Saturday 00:00 has elapsed.
    func checkVowWindow(userId: String, now: Date)

    /// Equip an unlocked Title as the user's profile headline. Pass nil to unequip.
    func equipTitle(_ titleId: TitleID?, userId: String)

    /// Read current state for UI.
    func state(userId: String) -> WeeklyVowsState
}

extension WeeklyVowsServiceProtocol {
    func trainingDraft(for vow: WeeklyVow) -> TrainingSessionDraft {
        trainingDraft(for: vow, date: Date())
    }

    func trainingDraftForCurrentVow(userId: String) -> TrainingSessionDraft? {
        trainingDraftForCurrentVow(userId: userId, date: Date())
    }

    // Temporary Trial* adapters while callers migrate.
    func pickCard(_ card: TrialCard, userId: String) {
        pickVowCard(card, userId: userId)
    }

    func completeCapstone(userId: String, at date: Date) {
        completeVow(userId: userId, at: date)
    }

    func evaluateCapstoneFromLog(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) async {
        await evaluateVowProofFromLog(userId: userId, history: history, bodyweightKg: bodyweightKg)
    }

    func checkCapstoneWindow(userId: String, now: Date) {
        checkVowWindow(userId: userId, now: now)
    }
}

typealias TrialsServiceProtocol = WeeklyVowsServiceProtocol
