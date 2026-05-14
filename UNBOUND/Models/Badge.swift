import Foundation
import SwiftUI

// MARK: - Badge

struct Badge: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var displayName: String
    var description: String
    var iconSystemName: String
    var rarity: Rarity
    var unlockedAt: Date?

    enum Rarity: String, Codable, Sendable, CaseIterable {
        case common, rare, legendary

        var displayName: String {
            switch self {
            case .common: return "Common"
            case .rare: return "Rare"
            case .legendary: return "Legendary"
            }
        }

        var tint: Color {
            switch self {
            case .common: return Color.unbound.textSecondary
            case .rare: return Color.unbound.accent
            case .legendary: return Color.unbound.impact
            }
        }
    }

    var isUnlocked: Bool { unlockedAt != nil }
}

// MARK: - BadgeTrigger
//
// What happened that might unlock badges. Passed into BadgeService.evaluate.
// Kept light — evaluators pull richer context from services as needed.

enum BadgeTrigger: Sendable {
    case sessionLogged(WorkoutLog)
    case rankAdvanced(RankAdvance)
    case streakUpdated(Int)
    case scanComplete
    case calibrationComplete
    case firstBuildIdentityResolved(BuildIdentity)
    case setCompleted(exerciseKey: String, reps: Int)
    /// A plain progress photo was captured (no scan analysis). Fires
    /// the photo-ritual streak/consistency badges.
    case photoCaptured
    /// A bi-weekly scan successfully completed (distinct from onboarding
    /// `scanComplete`). Fires the scan-cadence badges.
    case scanCompleted
}

// MARK: - Notification

struct BadgeUnlockEvent: Sendable, Identifiable {
    let id: UUID
    let badge: Badge
    init(badge: Badge) {
        self.id = UUID()
        self.badge = badge
    }
}

extension Notification.Name {
    static let badgeUnlocked = Notification.Name("unbound.badgeUnlocked")
}
