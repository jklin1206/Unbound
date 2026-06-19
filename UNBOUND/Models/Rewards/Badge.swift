import Foundation
import SwiftUI

// MARK: - Badge

struct Badge: Identifiable, Codable, Sendable, Hashable {
    let id: String
    var displayName: String
    var description: String
    /// Exact player-facing unlock instructions. Keep this in sync with
    /// `BadgeService` evaluators and `BadgeStandards`.
    var unlockCriteria: String
    /// The vow-style reward copy shown when the achievement is earned. The
    /// concrete reward today is the wearable badge title unlocked by
    /// `WeeklyVowsService.unlockBadgeTitle`.
    var vowReward: String
    var iconSystemName: String
    var rarity: Rarity
    var unlockedAt: Date?

    init(
        id: String,
        displayName: String,
        description: String,
        unlockCriteria: String,
        vowReward: String,
        iconSystemName: String,
        rarity: Rarity,
        unlockedAt: Date?
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.unlockCriteria = unlockCriteria
        self.vowReward = vowReward
        self.iconSystemName = iconSystemName
        self.rarity = rarity
        self.unlockedAt = unlockedAt
    }

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

    var assetName: String {
        let normalized = id
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return "badge_art_\(normalized)"
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, description, unlockCriteria, vowReward, iconSystemName, rarity, unlockedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decode(String.self, forKey: .description)
        unlockCriteria = try container.decodeIfPresent(String.self, forKey: .unlockCriteria) ?? description
        vowReward = try container.decodeIfPresent(String.self, forKey: .vowReward) ?? "Unlocks the \(displayName) title."
        iconSystemName = try container.decode(String.self, forKey: .iconSystemName)
        rarity = try container.decode(Rarity.self, forKey: .rarity)
        unlockedAt = try container.decodeIfPresent(Date.self, forKey: .unlockedAt)
    }
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
    /// A monthly checkpoint successfully completed (distinct from onboarding
    /// `scanComplete`). Fires the checkpoint-cadence badges.
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
