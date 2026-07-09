import SwiftUI
import UIKit

// MARK: - RankCosmetics
//
// Maps each rank tier (Initiate → Ascendant) to the cosmetic assets
// that unlock when the user crosses into that tier:
//
//  - Avatar frame  — circular ornamental ring rendered around the
//    profile photo. Wraps the avatar on Home + Profile screens.
//  - Profile background — atmospheric texture rendered behind the
//    Profile header card.
//
// Asset names match the imagesets seeded under
// `Assets.xcassets/Cosmetics/`. The mapping is intentionally a static
// lookup — no DB row, no per-user state. The user's *currently equipped*
// cosmetic is derived from their highest cleared rank tier across the
// skill collection (`RankCosmetics.equipped(for:)`).
//
// When a tier doesn't have an asset shipped yet, the helpers return nil
// and views fall back to the existing plain ring / solid bg.

enum RankCosmetics {
    private static let highestKeyPrefix = "unbound.profileCosmetics.highest."
    private static let frameKeyPrefix = "unbound.profileCosmetics.frame."
    private static let backgroundKeyPrefix = "unbound.profileCosmetics.background."

    /// Returns the rank-frame badge asset name (in Assets.xcassets/Cosmetics)
    /// for the given tier, or nil if no frame is shipped for it.
    static func avatarFrameAsset(for tier: RankTitle) -> String? {
        let name = "avatar_frame_\(tier.token)"
        return UIImage(named: name) != nil ? name : nil
    }

    /// Returns the profile background asset name, or nil if not shipped.
    static func profileBackgroundAsset(for tier: RankTitle) -> String? {
        let name = "profile_bg_\(tier.token)"
        return UIImage(named: name) != nil ? name : nil
    }

    /// The landscape header banner for a tier. Prefers the authored
    /// `profile_banner_<tier>` cinematic banner (composed with a side core +
    /// dead space for the overlaid avatar/identity); falls back to the legacy
    /// portrait `profile_bg_<tier>` only where no banner is shipped. This is
    /// the single source the profile header and the cosmetics preview share so
    /// the equip preview matches what actually renders.
    static func profileHeaderBannerAsset(for tier: RankTitle) -> String? {
        let banner = "profile_banner_\(tier.token)"
        if UIImage(named: banner) != nil {
            return banner
        }
        return profileBackgroundAsset(for: tier)
    }

    /// The cosmetic tier currently equipped by the user. Equals the
    /// highest tier reached on any single skill in the user's collection.
    /// Falls back to `.initiate` when no skills have been advanced yet
    /// so the user always has SOME cosmetic surface to look at.
    ///
    /// Inputs are kept loose so this is callable from any view without
    /// pulling the whole SkillProgressService graph.
    static func equipped(highestRank: RankTitle?) -> RankTitle {
        highestRank ?? .initiate
    }

    static func recordUnlockedTier(userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) -> SkillTier {
        let key = highestKeyPrefix + userId
        let stored = defaults.integer(forKey: key)
        let highest = max(stored, currentTier.rawValue)
        defaults.set(highest, forKey: key)
        return SkillTier(rawValue: highest) ?? currentTier
    }

    static func unlockedTiers(userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) -> [SkillTier] {
        rankUnlockedTiers(userId: userId, currentTier: currentTier, defaults: defaults)
    }

    static func unlockedFrameTiers(userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) -> [SkillTier] {
        rankUnlockedTiers(userId: userId, currentTier: currentTier, defaults: defaults)
    }

    static func unlockedBackgroundTiers(userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) -> [SkillTier] {
        rankUnlockedTiers(userId: userId, currentTier: currentTier, defaults: defaults)
    }

    private static func rankUnlockedTiers(userId: String, currentTier: SkillTier, defaults: UserDefaults) -> [SkillTier] {
        let highest = recordUnlockedTier(userId: userId, currentTier: currentTier, defaults: defaults)
        return SkillTier.allCases.filter { $0.rawValue <= highest.rawValue }
    }

    static func equippedFrameTier(userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) -> RankTitle {
        equippedTier(
            keyPrefix: frameKeyPrefix,
            userId: userId,
            currentTier: currentTier,
            unlocked: unlockedFrameTiers(userId: userId, currentTier: currentTier, defaults: defaults),
            defaults: defaults
        )
    }

    static func equippedBackgroundTier(userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) -> RankTitle {
        equippedTier(
            keyPrefix: backgroundKeyPrefix,
            userId: userId,
            currentTier: currentTier,
            unlocked: unlockedBackgroundTiers(userId: userId, currentTier: currentTier, defaults: defaults),
            defaults: defaults
        )
    }

    static func setEquippedFrameTier(_ tier: SkillTier, userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) {
        setEquippedTier(
            tier,
            keyPrefix: frameKeyPrefix,
            userId: userId,
            currentTier: currentTier,
            unlocked: unlockedFrameTiers(userId: userId, currentTier: currentTier, defaults: defaults),
            defaults: defaults
        )
    }

    static func setEquippedBackgroundTier(_ tier: SkillTier, userId: String, currentTier: SkillTier, defaults: UserDefaults = .standard) {
        setEquippedTier(
            tier,
            keyPrefix: backgroundKeyPrefix,
            userId: userId,
            currentTier: currentTier,
            unlocked: unlockedBackgroundTiers(userId: userId, currentTier: currentTier, defaults: defaults),
            defaults: defaults
        )
    }

    // MARK: - Cloud backup seams

    /// Raw persisted values for `RewardsCloudBackup` — nil when the user never
    /// touched the slot, which is exactly what the restore's adopt-when-unset
    /// checks key off (the guarded getters above always fall back).
    static func persistedHighestTierRawValue(userId: String, defaults: UserDefaults = .standard) -> Int? {
        defaults.object(forKey: highestKeyPrefix + userId) as? Int
    }

    static func persistedEquippedFrameTier(userId: String, defaults: UserDefaults = .standard) -> SkillTier? {
        persistedEquippedTier(keyPrefix: frameKeyPrefix, userId: userId, defaults: defaults)
    }

    static func persistedEquippedBackgroundTier(userId: String, defaults: UserDefaults = .standard) -> SkillTier? {
        persistedEquippedTier(keyPrefix: backgroundKeyPrefix, userId: userId, defaults: defaults)
    }

    private static func persistedEquippedTier(keyPrefix: String, userId: String, defaults: UserDefaults) -> SkillTier? {
        guard let raw = defaults.string(forKey: keyPrefix + userId) else { return nil }
        // Same tolerant decode as `equippedTier` (Int rawValue, legacy token fallback).
        return Int(raw).flatMap(RankTier.init(rawValue:)) ?? RankTier.fromLegacyToken(raw)
    }

    private static func equippedTier(
        keyPrefix: String,
        userId: String,
        currentTier: SkillTier,
        unlocked: [SkillTier],
        defaults: UserDefaults
    ) -> RankTitle {
        let fallback = unlocked.last ?? currentTier
        guard let raw = defaults.string(forKey: keyPrefix + userId)
        else { return fallback }
        // New writes store the Int rawValue; older builds stored the case-name
        // token (crown tokens carry their pre-rename meanings).
        let tier = Int(raw).flatMap(RankTier.init(rawValue:)) ?? RankTier.fromLegacyToken(raw)
        guard unlocked.contains(tier) else { return fallback }
        return tier
    }

    private static func setEquippedTier(
        _ tier: SkillTier,
        keyPrefix: String,
        userId: String,
        currentTier: SkillTier,
        unlocked: [SkillTier],
        defaults: UserDefaults
    ) {
        guard unlocked.contains(tier) else { return }
        // Persist the Int rawValue (stable across the 2026-06 crown rename);
        // reads stay tolerant of the older token form via fromLegacyToken.
        defaults.set(String(tier.rawValue), forKey: keyPrefix + userId)
        NotificationCenter.default.post(
            name: .profileCosmeticsChanged,
            object: nil,
            userInfo: ["userId": userId]
        )
    }
}

extension Notification.Name {
    static let profileCosmeticsChanged = Notification.Name("unbound.profileCosmeticsChanged")
}

// MARK: - SwiftUI helpers

/// Avatar wrapper — composes a profile photo (or letter fallback) inside
/// the rank-frame ring. Frame falls back to the existing violet stroke
/// when no asset exists for the tier.
struct CosmeticAvatar: View {
    let tier: RankTitle
    let size: CGFloat
    var image: UIImage? = nil
    var letterFallback: String = "U"
    var shopBorder: ShopProfileBorderID? = nil

    var body: some View {
        ZStack {
            // Inner core — sized to sit inside the transparent center while
            // still letting large profile photos read loudly.
            innerCore
                .frame(width: size * 0.60, height: size * 0.60)

            // Cosmetic frame border, always-on. Frame asset is a
            // transparent ring so the inner core shows through cleanly.
            activeFrameBorder
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var innerCore: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.unbound.accent.opacity(0.32),
                            Color.unbound.surfaceElevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.unbound.accent)
                if avatarFallbackText.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                } else {
                    Text(avatarFallbackText)
                        .font(.system(size: fallbackFontSize, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
            }
        }
    }

    private var avatarFallbackText: String {
        String(
            letterFallback
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .prefix(2)
        )
    }

    private var fallbackFontSize: CGFloat {
        avatarFallbackText.count > 1 ? size * 0.18 : size * 0.24
    }

    @ViewBuilder
    private var activeFrameBorder: some View {
        if let shopBorder,
           let ui = UIImage(named: shopBorder.assetName) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            frameBorder
        }
    }

    @ViewBuilder
    private var frameBorder: some View {
        // The avatar_frame_<rank>.png rank badges are the real art. Fall back
        // to the code-drawn ring only if a tier's asset is ever missing.
        if let asset = RankCosmetics.avatarFrameAsset(for: tier),
           let ui = UIImage(named: asset) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            AvatarFrameRing(tier: tier)
        }
    }
}

// MARK: - AvatarFrameRing
//
// Code-drawn rank-frame fallback (used only when a shipped
// avatar_frame_<rank>.png is missing). Pure SwiftUI shapes — transparent
// center, scales cleanly, escalates by tier.

private struct AvatarFrameRing: View {
    let tier: RankTitle

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(tint, lineWidth: lineWidth)

            if tier.ordinal >= 4 {
                Circle()
                    .strokeBorder(tint.opacity(0.55), lineWidth: 0.75)
                    .padding(4.5)
            }

            if tier.ordinal >= 5 {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(tint)
                        .frame(width: ornamentSize, height: ornamentSize)
                        .offset(y: -ornamentRadius)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }

            if tier.deservesCinematic {
                ForEach(0..<8) { i in
                    Capsule()
                        .fill(tint.opacity(0.35))
                        .frame(width: 2, height: 4)
                        .offset(y: -(ornamentRadius - 6))
                        .rotationEffect(.degrees(Double(i) * 45 + 22.5))
                }
            }
        }
    }

    private var tint: Color { tier.rewardTint }

    private var lineWidth: CGFloat {
        switch tier.ordinal {
        case 1...3: return 1.5
        case 4...5: return 2.0
        case 6...7: return 2.5
        default:    return 3.0
        }
    }

    private var ornamentSize: CGFloat { tier.deservesCinematic ? 5 : 3.5 }
    private var ornamentRadius: CGFloat { 48 }
}

/// Backdrop — soft top-of-screen image with a vertical fade. Wrapped in
/// an explicit GeometryReader-fed frame so a high-resolution source PNG
/// can never inflate parent layout.
struct CosmeticBackdrop: View {
    let tier: RankTitle
    var shopBackground: ShopProfileBackgroundID? = nil
    var shopBackdropAssetName: String? = nil
    var maxHeight: CGFloat = 320

    var body: some View {
        let isUsingShopBackdrop = activeShopAssetName != nil

        GeometryReader { geo in
            ZStack(alignment: .top) {
                if !isUsingShopBackdrop {
                    LinearGradient(
                        colors: tier.rewardGlowColors.map { $0.opacity(0.16) } + [.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                if let asset = activeAssetName,
                   let ui = UIImage(named: asset) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: maxHeight, alignment: .top)
                        .clipped()
                        .saturation(1.12)
                        .contrast(1.08)
                        .overlay(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.unbound.bg.opacity(isUsingShopBackdrop ? 0.16 : 0.10), location: 0),
                                    .init(color: Color.unbound.bg.opacity(isUsingShopBackdrop ? 0.58 : 0.52), location: 0.56),
                                    .init(color: Color.unbound.bg.opacity(isUsingShopBackdrop ? 0.96 : 0.98), location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Group {
                                if !isUsingShopBackdrop {
                                    RadialGradient(
                                        colors: tier.rewardGlowColors.map { $0.opacity(0.18) } + [.clear],
                                        center: .topTrailing,
                                        startRadius: 12,
                                        endRadius: max(260, geo.size.width * 0.85)
                                    )
                                    .blendMode(.screen)
                                }
                            }
                        )
                        .opacity(isUsingShopBackdrop ? 1.0 : 0.88)
                }
            }
            .frame(width: geo.size.width, height: maxHeight, alignment: .top)
        }
        .frame(height: maxHeight)
        .allowsHitTesting(false)
    }

    private var activeAssetName: String? {
        if let activeShopAssetName {
            return activeShopAssetName
        }
        return RankCosmetics.profileBackgroundAsset(for: tier)
    }

    private var activeShopAssetName: String? {
        if let shopBackdropAssetName,
           UIImage(named: shopBackdropAssetName) != nil {
            return shopBackdropAssetName
        }
        guard let shopBackground,
              UIImage(named: shopBackground.assetName) != nil else {
            return nil
        }
        return shopBackground.assetName
    }
}
