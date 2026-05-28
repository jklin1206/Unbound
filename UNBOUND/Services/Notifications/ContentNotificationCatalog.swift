import Foundation

// MARK: - ContentNotificationCatalog
//
// Curated lock-screen notification copy used for marketing screenshots
// (TikTok carousel slide-3 "payoff" frame, IG story stickers, etc).
// Tone: ambiguous, in-character, never preachy — the streak / rank / hex
// shift quietly tells the story. The viewer connects the dots.
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

    // MARK: Streak — milestones that read like a quiet flex
    static let streak: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "streak.day-7",
            category: .streak,
            title: "7-day streak",
            body: "One full week. The hard part is starting it again tomorrow."
        ),
        ContentNotificationPreset(
            id: "streak.day-30",
            category: .streak,
            title: "30-day streak",
            body: "A month with zero skipped sessions. You stopped negotiating with yourself."
        ),
        ContentNotificationPreset(
            id: "streak.day-60",
            category: .streak,
            title: "60-day streak",
            body: "Two months. Everyone who started with you quit weeks ago."
        ),
        ContentNotificationPreset(
            id: "streak.day-100",
            category: .streak,
            title: "100-day streak",
            body: "Triple digits. The body that watches anime is gone."
        ),
        ContentNotificationPreset(
            id: "streak.day-184",
            category: .streak,
            title: "184-day streak",
            body: "Six months. You're not the person who downloaded this anymore."
        ),
        ContentNotificationPreset(
            id: "streak.day-365",
            category: .streak,
            title: "365-day streak",
            body: "A full year. No off days. No exceptions. Unbound."
        ),
        ContentNotificationPreset(
            id: "streak.locked-in",
            category: .streak,
            title: "Streak locked in",
            body: "Session logged. Day 47 of the arc. Don't break it now."
        ),
    ]

    // MARK: Rank Up — tier crossings (Initiate → Unbound)
    static let rankUp: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "rank.initiate-to-novice",
            category: .rankUp,
            title: "Rank up — NOVICE",
            body: "You crossed the line everyone hesitates at. Initiate → Novice."
        ),
        ContentNotificationPreset(
            id: "rank.novice-to-apprentice",
            category: .rankUp,
            title: "Rank up — APPRENTICE",
            body: "Novice → Apprentice. The reps started building someone new."
        ),
        ContentNotificationPreset(
            id: "rank.apprentice-to-forged",
            category: .rankUp,
            title: "Rank up — FORGED",
            body: "Apprentice → Forged. This is where the people who quit stop reading."
        ),
        ContentNotificationPreset(
            id: "rank.forged-to-honed",
            category: .rankUp,
            title: "Rank up — HONED",
            body: "Forged → Honed. Sharper, leaner, harder to break."
        ),
        ContentNotificationPreset(
            id: "rank.honed-to-ascendant",
            category: .rankUp,
            title: "Rank up — ASCENDANT",
            body: "Honed → Ascendant. Top 5% of everyone who started this app."
        ),
        ContentNotificationPreset(
            id: "rank.ascendant-to-unbound",
            category: .rankUp,
            title: "Rank up — UNBOUND",
            body: "Ascendant → UNBOUND. There is no rank above this one."
        ),
    ]

    // MARK: Hex Shift — attribute crossings (PULL/PUSH/CORE/LEGS/EXPLOSIVE/MOBILITY)
    static let hexShift: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "hex.pull-ascendant",
            category: .hexShift,
            title: "PULL → ASCENDANT",
            body: "Your hex just shifted. Weighted pull-ups crossed top 5%."
        ),
        ContentNotificationPreset(
            id: "hex.push-honed",
            category: .hexShift,
            title: "PUSH → HONED",
            body: "Push axis advanced. Dips and presses are no longer the bottleneck."
        ),
        ContentNotificationPreset(
            id: "hex.core-forged",
            category: .hexShift,
            title: "CORE → FORGED",
            body: "Core just hit forged. L-sit holds are getting boring — time to load them."
        ),
        ContentNotificationPreset(
            id: "hex.legs-ascendant",
            category: .hexShift,
            title: "LEGS → ASCENDANT",
            body: "Pistols at bodyweight × 8. Lower body crossed Ascendant tonight."
        ),
        ContentNotificationPreset(
            id: "hex.explosive-unbound",
            category: .hexShift,
            title: "EXPLOSIVE → UNBOUND",
            body: "Clap pullups · 6 clean. The explosive axis has no ceiling left."
        ),
        ContentNotificationPreset(
            id: "hex.mobility-honed",
            category: .hexShift,
            title: "MOBILITY → HONED",
            body: "Pancake at depth. Your mobility just stopped being a weak link."
        ),
        ContentNotificationPreset(
            id: "hex.full-radar",
            category: .hexShift,
            title: "Hex radar updated",
            body: "All six axes moved this week. The build is closing the gap on the goal."
        ),
    ]

    // MARK: Identity — the quiet "you're someone else now" framing
    static let identity: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "identity.not-the-same",
            category: .identity,
            title: "Profile updated",
            body: "You're not the same person who downloaded this 184 days ago."
        ),
        ContentNotificationPreset(
            id: "identity.title-unlocked",
            category: .identity,
            title: "Title unlocked — The Quiet One",
            body: "Six months. No streak resets. No public posting. Just the work."
        ),
        ContentNotificationPreset(
            id: "identity.becoming",
            category: .identity,
            title: "Becoming",
            body: "Your build percentile crossed 92%. The before-photo is unrecognizable now."
        ),
        ContentNotificationPreset(
            id: "identity.arc-complete",
            category: .identity,
            title: "Arc complete",
            body: "The Forged Protocol — 12 weeks done. Time to pick the next one."
        ),
        ContentNotificationPreset(
            id: "identity.before-after",
            category: .identity,
            title: "Before/After ready",
            body: "Your scan delta is in. The comparison everyone asks about is on your profile."
        ),
    ]

    // MARK: Comeback — re-engagement that doesn't shame
    static let callBack: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "callback.three-days",
            category: .callBack,
            title: "3 days off",
            body: "You earned the rest. The streak resets at midnight — get one in."
        ),
        ContentNotificationPreset(
            id: "callback.one-week",
            category: .callBack,
            title: "A week away",
            body: "The arc is still here. One session today and you're back on the ladder."
        ),
        ContentNotificationPreset(
            id: "callback.return",
            category: .callBack,
            title: "Welcome back",
            body: "Picked up where you left off. The protocol remembers your numbers."
        ),
    ]

    // MARK: Session — short, punchy, in-character
    static let session: [ContentNotificationPreset] = [
        ContentNotificationPreset(
            id: "session.window-open",
            category: .session,
            title: "Training window open",
            body: "Pull day. 4 lifts. Twenty-eight minutes. Lock in."
        ),
        ContentNotificationPreset(
            id: "session.everyone-asleep",
            category: .session,
            title: "Late-night session",
            body: "Everyone you compare yourself to is asleep. You're building."
        ),
        ContentNotificationPreset(
            id: "session.empty-gym",
            category: .session,
            title: "Empty-gym window",
            body: "First one in. The reps are yours before anyone else's day starts."
        ),
        ContentNotificationPreset(
            id: "session.pr-ready",
            category: .session,
            title: "PR window detected",
            body: "Your last 3 weighted pull-ups says today's the day. Don't waste the curve."
        ),
    ]
}
