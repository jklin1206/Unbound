// UNBOUND/Services/Trials/TrialsService.swift
import Foundation

@MainActor
final class TrialsService: TrialsServiceProtocol {
    static let shared = TrialsService()

    private let store: TrialsStore
    private let attribute: AttributeServiceProtocol
    private let recentLogsProvider: (String) async -> [WorkoutLog]

    init(
        store: TrialsStore = .shared,
        attribute: AttributeServiceProtocol = AttributeService.shared,
        recentLogsProvider: ((String) async -> [WorkoutLog])? = nil
    ) {
        self.store = store
        self.attribute = attribute
        // Default closure forwards to WorkoutLogService.shared.fetchRecentLogs(userId:limit:).
        // WorkoutLogServiceProtocol: fetchRecentLogs(userId:limit:) async throws -> [WorkoutLog]
        // Tests inject a stub closure that returns canned data.
        if let recentLogsProvider {
            self.recentLogsProvider = recentLogsProvider
        } else {
            self.recentLogsProvider = { userId in
                (try? await WorkoutLogService.shared.fetchRecentLogs(userId: userId, limit: 30)) ?? []
            }
        }
    }

    // MARK: - T6.2 ensureCurrentWeek

    func ensureCurrentWeek(userId: String) async {
        let now = Date()
        let newWeekStart = mostRecentMondayMidnight(now: now)
        var state = store.load(userId: userId)

        if state.currentWeekStart == newWeekStart {
            return
        }

        // Roll prior week. Mark uncompleted trial as missed.
        if var trial = state.currentTrial, trial.capstoneState != .completed {
            trial.capstoneState = .missed
            state.currentTrial = trial
        }

        // Snapshot the user's profile + history for card generation.
        let profile = attribute.snapshot(userId: userId, asOf: now)
        let history = await recentLogsProvider(userId)
        let weekNumber = isoWeekNumber(for: newWeekStart)

        let cards = TrialGenerator.cards(
            profile: profile,
            history: history,
            weekStart: newWeekStart,
            weekNumber: weekNumber
        )

        state.currentWeekStart = newWeekStart
        state.currentWeekCards = cards
        state.currentTrial = nil
        state.skippedCurrentWeek = false

        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .trialWeekRolled, object: nil)

        // Reschedule local notifications for the new week.
        if let weekStart = state.currentWeekStart {
            Task {
                await TrialsNotificationScheduler.reschedule(for: userId, weekStart: weekStart)
            }
        }
    }

    /// Returns the most recent Monday 00:00 local time at or before `now`.
    private func mostRecentMondayMidnight(now: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2  // Monday in Gregorian calendar
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    private func isoWeekNumber(for date: Date) -> Int {
        Calendar.current.component(.weekOfYear, from: date)
    }

    // MARK: - T6.3 pickCard + skipThisWeek

    func pickCard(_ card: TrialCard, userId: String) {
        var state = store.load(userId: userId)
        let trial = Trial(
            id: card.id,
            userId: userId,
            weekStart: state.currentWeekStart ?? Date(),
            chosenCard: card,
            capstoneState: .pending,
            completedAt: nil
        )
        state.currentTrial = trial
        state.skippedCurrentWeek = false
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .trialPicked, object: trial)
    }

    func skipThisWeek(userId: String) {
        var state = store.load(userId: userId)
        state.skippedCurrentWeek = true
        state.currentTrial = nil
        store.save(state, userId: userId)
        TrialsNotificationScheduler.cancelAll()
    }

    // MARK: - T6.4 completeCapstone

    func completeCapstone(userId: String, at date: Date) {
        var state = store.load(userId: userId)
        guard var trial = state.currentTrial else { return }
        guard trial.capstoneState != .completed else { return }

        let prior = state

        trial.capstoneState = .completed
        trial.completedAt = date
        state.currentTrial = trial

        // Increment axis counter (only for axis-themed cards, not wildcard prestige).
        if case .axis(let axis) = trial.chosenCard.theme {
            state.completionsByAxis[axis, default: 0] += 1
        }
        state.completionsByCardKind[trial.chosenCard.kind, default: 0] += 1

        // Title threshold detection — fires .titleUnlocked per crossing.
        let crossings = TitleThresholdEvaluator.crossings(prior: prior, current: state)
        for titleId in crossings {
            if !state.unlockedTitles.contains(titleId) {
                state.unlockedTitles.append(titleId)
            }
        }

        store.save(state, userId: userId)

        for titleId in crossings {
            NotificationCenter.default.post(name: .titleUnlocked, object: titleId)
        }
        NotificationCenter.default.post(name: .trialCompleted, object: trial)
    }

    // MARK: - T6.5 evaluateCapstoneFromLog + checkCapstoneWindow

    func evaluateCapstoneFromLog(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) async {
        let state = store.load(userId: userId)
        guard let trial = state.currentTrial else { return }
        guard trial.capstoneState == .windowOpen else { return }
        guard case .autoFromLog(let criterion) = trial.chosenCard.capstone.evaluation else { return }

        if TierCriterionEvaluator.satisfied(
            criterion: criterion,
            history: history,
            bodyweightKg: bodyweightKg
        ) {
            completeCapstone(userId: userId, at: .now)
        }
    }

    func checkCapstoneWindow(userId: String, now: Date = .now) {
        var state = store.load(userId: userId)
        guard var trial = state.currentTrial else { return }
        guard trial.capstoneState == .pending else { return }
        guard let weekStart = state.currentWeekStart else { return }
        // Saturday = weekStart + 5 days
        let saturdayMidnight = weekStart.addingTimeInterval(5 * 86_400)
        guard now >= saturdayMidnight else { return }

        trial.capstoneState = .windowOpen
        state.currentTrial = trial
        store.save(state, userId: userId)
        NotificationCenter.default.post(name: .trialCapstoneWindowOpen, object: nil)
    }

    // MARK: - T6.6 equipTitle

    func equipTitle(_ titleId: TitleID?, userId: String) {
        var state = store.load(userId: userId)
        if let titleId, !state.unlockedTitles.contains(titleId) {
            return  // Reject unequipped titles
        }
        state.equippedTitle = titleId
        store.save(state, userId: userId)
    }

    // MARK: - state

    func state(userId: String) -> TrialsState {
        store.load(userId: userId)
    }
}

extension Notification.Name {
    static let trialWeekRolled         = Notification.Name("unbound.trialWeekRolled")
    static let trialPicked             = Notification.Name("unbound.trialPicked")
    static let trialCapstoneWindowOpen = Notification.Name("unbound.trialCapstoneWindowOpen")
    static let trialCompleted          = Notification.Name("unbound.trialCompleted")
    static let titleUnlocked           = Notification.Name("unbound.titleUnlocked")
}
