import Foundation
import SwiftUI

// MARK: - SkinServiceProtocol

@MainActor
protocol SkinServiceProtocol: AnyObject {
    /// Currently active skin (persisted in UserDefaults).
    var currentSkin: SkillTreeSkin { get }

    /// All skins the user has unlocked (always includes `.violet`).
    var unlockedSkins: [SkillTreeSkin] { get }

    /// Switch the active skin. Throws if not unlocked.
    func setCurrent(_ skin: SkillTreeSkin) throws

    /// Recompute unlock state from the user's aggregate named skill tier.
    /// Returns the skins that flipped from locked → unlocked this call.
    @discardableResult
    func evaluateUnlocks(userId: String) async -> [SkillTreeSkin]
}

// MARK: - SkinServiceError

enum SkinServiceError: LocalizedError {
    case skinLocked(SkillTreeSkin)

    var errorDescription: String? {
        switch self {
        case .skinLocked(let skin):
            return "\(skin.displayName) is locked. \(skin.unlockHintCopy)"
        }
    }
}

// MARK: - SkinService

/// Global (not per-user) persistence keys. File-scope so the nonisolated
/// cloud-backup accessor below can share them with the MainActor service.
private let skinCurrentDefaultsKey = "unbound.skin.current"
private let skinUnlockedDefaultsKey = "unbound.skin.unlocked"

@MainActor
final class SkinService: SkinServiceProtocol, ObservableObject {
    static let shared = SkinService()

    private let logger = LoggingService.shared
    private let defaults: UserDefaults

    @Published private(set) var currentSkin: SkillTreeSkin
    @Published private(set) var unlockedSkins: [SkillTreeSkin]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let current = defaults.string(forKey: skinCurrentDefaultsKey)
            .flatMap(SkillTreeSkin.init(rawValue:)) ?? .violet
        self.currentSkin = current

        let stored = defaults.stringArray(forKey: skinUnlockedDefaultsKey) ?? []
        var unlocked = stored.compactMap(SkillTreeSkin.init(rawValue:))
        if !unlocked.contains(.violet) { unlocked.insert(.violet, at: 0) }
        if !unlocked.contains(.graphite) { unlocked.append(.graphite) }
        if !unlocked.contains(current) { unlocked.append(current) }
        self.unlockedSkins = unlocked
    }

    /// Raw persisted skin selection for `RewardsCloudBackup` — nil when the
    /// user never chose a skin (the restore adopts the cloud pick only then).
    /// Only the CURRENT selection is mirrored; unlocked skins are recomputed
    /// from rank (`evaluateUnlocks`) plus restored shop purchases.
    nonisolated static func persistedCurrentSkinRawValue(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: skinCurrentDefaultsKey)
    }

    func setCurrent(_ skin: SkillTreeSkin) throws {
        guard unlockedSkins.contains(skin) else {
            throw SkinServiceError.skinLocked(skin)
        }
        currentSkin = skin
        defaults.set(skin.rawValue, forKey: skinCurrentDefaultsKey)
        NotificationCenter.default.post(name: .skinChanged, object: nil, userInfo: ["skin": skin])
        logger.log("Skin switched to \(skin.rawValue)", level: .info)
    }

    @discardableResult
    func evaluateUnlocks(userId: String) async -> [SkillTreeSkin] {
        let aggregateTier = await RankService.shared.aggregateTier(userId: userId)

        var newlyUnlocked: [SkillTreeSkin] = []
        for skin in SkillTreeSkin.allCases {
            if skin.isShopExclusive { continue }
            if let req = skin.unlockRequirement, aggregateTier < req { continue }
            if !unlockedSkins.contains(skin) {
                unlockedSkins.append(skin)
                newlyUnlocked.append(skin)
            }
        }

        if !newlyUnlocked.isEmpty {
            persistUnlocked()
            for skin in newlyUnlocked {
                let event = SkinUnlock(skin: skin)
                NotificationCenter.default.post(name: .skinUnlocked, object: nil, userInfo: ["event": event])
                logger.log("Skin unlocked: \(skin.rawValue)", level: .info)
            }
        }
        return newlyUnlocked
    }

    func unlockPurchasedSkin(_ skin: SkillTreeSkin) {
        guard !unlockedSkins.contains(skin) else { return }
        unlockedSkins.append(skin)
        persistUnlocked()
        let event = SkinUnlock(skin: skin)
        NotificationCenter.default.post(name: .skinUnlocked, object: nil, userInfo: ["event": event])
        logger.log("Purchased skin unlocked: \(skin.rawValue)", level: .info)
    }

    private func persistUnlocked() {
        defaults.set(unlockedSkins.map(\.rawValue), forKey: skinUnlockedDefaultsKey)
    }

    #if DEBUG
    func debugUnlockAllSkins(select skin: SkillTreeSkin = .ascendant) {
        unlockedSkins = SkillTreeSkin.allCases
        persistUnlocked()
        try? setCurrent(skin)
    }

    func debugResetToFreshDefaults() {
        currentSkin = .violet
        unlockedSkins = [.violet, .graphite]
        defaults.set(currentSkin.rawValue, forKey: skinCurrentDefaultsKey)
        persistUnlocked()
        NotificationCenter.default.post(name: .skinChanged, object: nil, userInfo: ["skin": currentSkin])
    }
    #endif
}

// MARK: - MockSkinService

@MainActor
final class MockSkinService: SkinServiceProtocol, ObservableObject {
    @Published private(set) var currentSkin: SkillTreeSkin = .violet
    @Published private(set) var unlockedSkins: [SkillTreeSkin] = [.violet, .graphite]

    func setCurrent(_ skin: SkillTreeSkin) throws {
        guard unlockedSkins.contains(skin) else { throw SkinServiceError.skinLocked(skin) }
        currentSkin = skin
    }

    func evaluateUnlocks(userId: String) async -> [SkillTreeSkin] {
        []
    }
}
