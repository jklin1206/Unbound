import Foundation

extension Notification.Name {
    static let weeklyVowWeekRolled     = Notification.Name("unbound.weeklyVowWeekRolled")
    static let weeklyVowPicked         = Notification.Name("unbound.weeklyVowPicked")
    static let weeklyVowWindowOpen     = Notification.Name("unbound.weeklyVowWindowOpen")
    static let weeklyVowCompleted      = Notification.Name("unbound.weeklyVowCompleted")

    // Temporary adapters for existing observers and stored tests.
    static let trialWeekRolled         = Notification.Name("unbound.trialWeekRolled")
    static let trialPicked             = Notification.Name("unbound.trialPicked")
    static let trialCapstoneWindowOpen = Notification.Name("unbound.trialCapstoneWindowOpen")
    static let trialCompleted          = Notification.Name("unbound.trialCompleted")
    static let titleUnlocked           = Notification.Name("unbound.titleUnlocked")
}

typealias TrialsService = WeeklyVowsService
