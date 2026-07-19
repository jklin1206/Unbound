import Foundation

// MARK: - ContentNotificationCatalog
//
// Curated lock-screen notification copy used for marketing screenshots
// (TikTok carousel slide-3 "payoff" frame, IG story stickers, etc).
// Tone: concise, readable, and in-character. Every title should feel like a
// System event while the body immediately explains what changed.
//
// Each preset is a (title, body) pair shaped to read well on a lock screen
// when previewed via the Dev Player Tools "Notification Preview" section.
// IDs are stable so they can be triggered from launch args or analytics.

struct ContentNotificationPreset: Identifiable, Hashable {
    let id: String
    let category: Category
    let title: String
    let body: String

    enum Category: String, CaseIterable, Identifiable, Hashable {
        case streak
        case rankUp
        case hexShift
        case identity
        case callBack
        case session

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .streak:    return "Streak"
            case .rankUp:    return "Rank Up"
            case .hexShift:  return "Hex Shift"
            case .identity:  return "Identity"
            case .callBack:  return "Comeback"
            case .session:   return "Session"
            }
        }
    }
}

enum ContentNotificationCatalog {
    static let all: [ContentNotificationPreset] = streak + rankUp + hexShift + identity + callBack + session

    static func preset(id: String) -> ContentNotificationPreset? {
        all.first { $0.id == id }
    }

    static func presets(in category: ContentNotificationPreset.Category) -> [ContentNotificationPreset] {
        all.filter { $0.category == category }
    }

    // MARK: Streak
    static let streak: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "streak.day-7",
            category: .streak,
            title: "[ SYSTEM ] 7-DAY STREAK",
            body: "One week confirmed. Return tomorrow to extend the Arc."
        ),
        ContentNotificationPreset(
            id: "streak.day-30",
            category: .streak,
            title: "[ SYSTEM ] 30-DAY STREAK",
            body: "Thirty days confirmed. Your Arc is holding."
        ),
        ContentNotificationPreset(
            id: "streak.day-60",
            category: .streak,
            title: "[ SYSTEM ] 60-DAY STREAK",
            body: "Two months confirmed. The pattern is now part of your build."
        ),
        ContentNotificationPreset(
            id: "streak.day-100",
            category: .streak,
            title: "[ SYSTEM ] 100-DAY STREAK",
            body: "Triple digits confirmed. Your proof archive keeps growing."
        ),
        ContentNotificationPreset(
            id: "streak.day-184",
            category: .streak,
            title: "[ SYSTEM ] 184-DAY STREAK",
            body: "Six months confirmed. Your build has changed."
        ),
        ContentNotificationPreset(
            id: "streak.day-365",
            category: .streak,
            title: "[ SYSTEM ] 365-DAY STREAK",
            body: "One year confirmed. The Arc is complete."
        ),
        ContentNotificationPreset(
            id: "streak.locked-in",
            category: .streak,
            title: "[ SYSTEM ] STREAK SECURED",
            body: "Session logged. Day 47 is complete."
        ),
    ]

    // MARK: Rank Up
    static let rankUp: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "rank.initiate-to-novice",
            category: .rankUp,
            title: "[ SYSTEM ] RANK ADVANCED",
            body: "Initiate → Novice. Your next gate is open."
        ),
        ContentNotificationPreset(
            id: "rank.novice-to-apprentice",
            category: .rankUp,
            title: "[ SYSTEM ] RANK ADVANCED",
            body: "Novice → Apprentice. New trials are available."
        ),
        ContentNotificationPreset(
            id: "rank.apprentice-to-forged",
            category: .rankUp,
            title: "[ SYSTEM ] RANK ADVANCED",
            body: "A new rank is active. Your next gate is open."
        ),
        ContentNotificationPreset(
            id: "rank.forged-to-honed",
            category: .rankUp,
            title: "[ SYSTEM ] RANK ADVANCED",
            body: "Another rank cleared. Your build has advanced."
        ),
        ContentNotificationPreset(
            id: "rank.honed-to-ascendant",
            category: .rankUp,
            title: "[ SYSTEM ] RANK ADVANCED",
            body: "Ascendant reached. You entered the top band."
        ),
        ContentNotificationPreset(
            id: "rank.ascendant-to-unbound",
            category: .rankUp,
            title: "[ SYSTEM ] FINAL RANK",
            body: "Unbound reached. Final rank confirmed."
        ),
    ]

    // MARK: Build Shift
    static let hexShift: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "hex.pull-ascendant",
            category: .hexShift,
            title: "[ SYSTEM ] PULL ADVANCED",
            body: "Weighted pull-ups moved your Pull axis to Ascendant."
        ),
        ContentNotificationPreset(
            id: "hex.push-honed",
            category: .hexShift,
            title: "[ SYSTEM ] PUSH ADVANCED",
            body: "Dips and presses moved your Push axis forward."
        ),
        ContentNotificationPreset(
            id: "hex.core-forged",
            category: .hexShift,
            title: "[ SYSTEM ] CORE ADVANCED",
            body: "L-sit proof moved your Core axis into a new rank."
        ),
        ContentNotificationPreset(
            id: "hex.legs-ascendant",
            category: .hexShift,
            title: "[ SYSTEM ] LEGS ADVANCED",
            body: "Eight pistol squats moved your Legs axis to Ascendant."
        ),
        ContentNotificationPreset(
            id: "hex.explosive-unbound",
            category: .hexShift,
            title: "[ SYSTEM ] EXPLOSIVE ADVANCED",
            body: "Six clean clap pull-ups moved this axis to Unbound."
        ),
        ContentNotificationPreset(
            id: "hex.mobility-honed",
            category: .hexShift,
            title: "[ SYSTEM ] MOBILITY ADVANCED",
            body: "New range proof moved your Mobility axis forward."
        ),
        ContentNotificationPreset(
            id: "hex.full-radar",
            category: .hexShift,
            title: "[ SYSTEM ] BUILD UPDATED",
            body: "All six axes advanced this week."
        ),
    ]

    // MARK: Identity
    static let identity: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "identity.not-the-same",
            category: .identity,
            title: "[ SYSTEM ] PROFILE UPDATED",
            body: "Your current build no longer matches Day Zero."
        ),
        ContentNotificationPreset(
            id: "identity.title-unlocked",
            category: .identity,
            title: "[ SYSTEM ] TITLE UNLOCKED",
            body: "The Quiet One is ready to equip."
        ),
        ContentNotificationPreset(
            id: "identity.becoming",
            category: .identity,
            title: "[ SYSTEM ] BUILD ADVANCED",
            body: "Your build percentile crossed 92%."
        ),
        ContentNotificationPreset(
            id: "identity.arc-complete",
            category: .identity,
            title: "[ SYSTEM ] ARC COMPLETE",
            body: "Twelve weeks complete. Select your next path."
        ),
        ContentNotificationPreset(
            id: "identity.before-after",
            category: .identity,
            title: "[ SYSTEM ] PROOF READY",
            body: "Your scan comparison is ready on your profile."
        ),
    ]

    // MARK: Comeback
    static let callBack: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "callback.three-days",
            category: .callBack,
            title: "[ SYSTEM ] ARC PAUSED",
            body: "Three days away. One session restarts your momentum."
        ),
        ContentNotificationPreset(
            id: "callback.one-week",
            category: .callBack,
            title: "[ SYSTEM ] PATH REMAINS",
            body: "Your Arc is waiting. Complete one session to return."
        ),
        ContentNotificationPreset(
            id: "callback.return",
            category: .callBack,
            title: "[ SYSTEM ] ARC RESUMED",
            body: "Your plan and previous numbers are ready."
        ),
    ]

    // MARK: Session
    static let session: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "session.window-open",
            category: .session,
            title: "[ SYSTEM ] DIRECTIVE ISSUED",
            body: "Pull day. Four movements. Twenty-eight minutes."
        ),
        ContentNotificationPreset(
            id: "session.everyone-asleep",
            category: .session,
            title: "[ SYSTEM ] NIGHT DIRECTIVE",
            body: "Your night training window is open."
        ),
        ContentNotificationPreset(
            id: "session.empty-gym",
            category: .session,
            title: "[ SYSTEM ] DAWN DIRECTIVE",
            body: "Your early training window is open."
        ),
        ContentNotificationPreset(
            id: "session.pr-ready",
            category: .session,
            title: "[ SYSTEM ] PR WINDOW",
            body: "Your last three pull sessions support a new attempt."
        ),
    ]
}
