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

@MainActor
final class SkinService: SkinServiceProtocol, ObservableObject {
    static let shared = SkinService()

    private let currentKey = "unbound.skin.current"
    private let unlockedKey = "unbound.skin.unlocked"
    private let logger = LoggingService.shared

    @Published private(set) var currentSkin: SkillTreeSkin
    @Published private(set) var unlockedSkins: [SkillTreeSkin]

    private init() {
        let current = UserDefaults.standard.string(forKey: currentKey)
            .flatMap(SkillTreeSkin.init(rawValue:)) ?? .violet
        self.currentSkin = current

        let stored = UserDefaults.standard.stringArray(forKey: unlockedKey) ?? []
        var unlocked = stored.compactMap(SkillTreeSkin.init(rawValue:))
        if !unlocked.contains(.violet) { unlocked.insert(.violet, at: 0) }
        if !unlocked.contains(.graphite) { unlocked.append(.graphite) }
        if !unlocked.contains(current) { unlocked.append(current) }
        self.unlockedSkins = unlocked
    }

    func setCurrent(_ skin: SkillTreeSkin) throws {
        guard unlockedSkins.contains(skin) else {
            throw SkinServiceError.skinLocked(skin)
        }
        currentSkin = skin
        UserDefaults.standard.set(skin.rawValue, forKey: currentKey)
        NotificationCenter.default.post(name: .skinChanged, object: nil, userInfo: ["skin": skin])
        logger.log("Skin switched to \(skin.rawValue)", level: .info)
    }

    @discardableResult
    func evaluateUnlocks(userId: String) async -> [SkillTreeSkin] {
        let aggregateTier = await RankService.shared.aggregateTier(userId: userId)

        var newlyUnlocked: [SkillTreeSkin] = []
        for skin in SkillTreeSkin.allCases {
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

    private func persistUnlocked() {
        UserDefaults.standard.set(unlockedSkins.map(\.rawValue), forKey: unlockedKey)
    }

    #if DEBUG
    func debugUnlockAllSkins(select skin: SkillTreeSkin = .ascendant) {
        unlockedSkins = SkillTreeSkin.allCases
        persistUnlocked()
        try? setCurrent(skin)
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
