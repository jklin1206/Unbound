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
//  - Profile color — rank-tinted wash layered over the Profile screen
//    and header card.
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
    private static let colorKeyPrefix = "unbound.profileCosmetics.color."

    /// Returns the frame asset name (in Assets.xcassets/Cosmetics) for
    /// the given tier, or nil if no frame is shipped for it.
    static func avatarFrameAsset(for tier: RankTitle) -> String? {
        let name = "avatar_frame_\(tier.rawValue)"
        return UIImage(named: name) != nil ? name : nil
    }

    /// Returns the profile background asset name, or nil if not shipped.
    static func profileBackgroundAsset(for tier: RankTitle) -> String? {
        let name = "profile_bg_\(tier.rawValue)"
        return UIImage(named: name) != nil ? name : nil
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

    static func recordUnlockedTier(userId: String, currentTier: SkillTier) -> SkillTier {
        let key = highestKeyPrefix + userId
        let stored = UserDefaults.standard.integer(forKey: key)
        let highest = max(stored, currentTier.rawValue)
        UserDefaults.standard.set(highest, forKey: key)
        return SkillTier(rawValue: highest) ?? currentTier
    }

    static func unlockedTiers(userId: String, currentTier: SkillTier) -> [SkillTier] {
        let highest = recordUnlockedTier(userId: userId, currentTier: currentTier)
        return SkillTier.allCases.filter { $0.rawValue <= highest.rawValue }
    }

    static func equippedFrameTier(userId: String, currentTier: SkillTier) -> RankTitle {
        equippedTier(keyPrefix: frameKeyPrefix, userId: userId, currentTier: currentTier)
    }

    static func equippedBackgroundTier(userId: String, currentTier: SkillTier) -> RankTitle {
        equippedTier(keyPrefix: backgroundKeyPrefix, userId: userId, currentTier: currentTier)
    }

    static func equippedProfileColorTier(userId: String, currentTier: SkillTier) -> RankTitle {
        equippedTier(keyPrefix: colorKeyPrefix, userId: userId, currentTier: currentTier)
    }

    static func setEquippedFrameTier(_ tier: SkillTier, userId: String, currentTier: SkillTier) {
        setEquippedTier(tier, keyPrefix: frameKeyPrefix, userId: userId, currentTier: currentTier)
    }

    static func setEquippedBackgroundTier(_ tier: SkillTier, userId: String, currentTier: SkillTier) {
        setEquippedTier(tier, keyPrefix: backgroundKeyPrefix, userId: userId, currentTier: currentTier)
    }

    static func setEquippedProfileColorTier(_ tier: SkillTier, userId: String, currentTier: SkillTier) {
        setEquippedTier(tier, keyPrefix: colorKeyPrefix, userId: userId, currentTier: currentTier)
    }

    private static func equippedTier(keyPrefix: String, userId: String, currentTier: SkillTier) -> RankTitle {
        let unlocked = unlockedTiers(userId: userId, currentTier: currentTier)
        let fallback = unlocked.last ?? currentTier
        guard let raw = UserDefaults.standard.string(forKey: keyPrefix + userId),
              let storedTitle = RankTitle.storedRawValue(raw),
              let tier = SkillTier.allCases.first(where: { $0.rankTitle == storedTitle }),
              unlocked.contains(tier)
        else { return fallback.rankTitle }
        return tier.rankTitle
    }

    private static func setEquippedTier(_ tier: SkillTier, keyPrefix: String, userId: String, currentTier: SkillTier) {
        guard unlockedTiers(userId: userId, currentTier: currentTier).contains(tier) else { return }
        UserDefaults.standard.set(tier.rankTitle.rawValue, forKey: keyPrefix + userId)
    }
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

    var body: some View {
        ZStack {
            // Inner core — sized to sit inside the transparent center while
            // still letting large profile photos read loudly.
            innerCore
                .frame(width: size * 0.60, height: size * 0.60)

            // Cosmetic frame border, always-on. Frame asset is a
            // transparent ring so the inner core shows through cleanly.
            frameBorder
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
    private var frameBorder: some View {
        // The avatar_frame_<rank>.png assets were post-processed:
        // luminance-keyed for alpha + per-rank tint. If a future asset
        // is missing or unkeyed, fall back to the code-drawn ring so
        // the avatar never goes naked.
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
// Code-drawn rank-themed border for the avatar. Pure SwiftUI shapes —
// guaranteed transparent center, scales cleanly at any size, and the
// stroke style escalates with rank tier.

private struct AvatarFrameRing: View {
    let tier: RankTitle

    var body: some View {
        ZStack {
            // Outer ring — primary border for every tier.
            Circle()
                .strokeBorder(tint, lineWidth: lineWidth)

            // Inner secondary ring for higher tiers.
            if tier.ordinal >= 4 {
                Circle()
                    .strokeBorder(tint.opacity(0.55), lineWidth: 0.75)
                    .padding(4.5)
            }

            // Cardinal ornaments — diamonds at top/right/bottom/left.
            // Lower tiers stay clean; master+ get the ornament treatment.
            if tier.ordinal >= 5 {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(tint)
                        .frame(width: ornamentSize, height: ornamentSize)
                        .offset(y: -ornamentRadius)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }

            // Brand-tier crown decorations (Vessel / Unbound / Ascendant).
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

    // MARK: Tier styling

    private var tint: Color {
        tier.rewardTint
    }

    private var lineWidth: CGFloat {
        switch tier.ordinal {
        case 1...3: return 1.5
        case 4...5: return 2.0
        case 6...7: return 2.5
        default:    return 3.0
        }
    }

    private var ornamentSize: CGFloat {
        tier.deservesCinematic ? 5 : 3.5
    }

    /// Radius from center to where ornaments sit. Stays just inside
    /// the outer stroke so they read as part of the ring.
    private var ornamentRadius: CGFloat {
        // 50% of canvas diameter is the outer edge — pull in slightly.
        // The actual rendered size comes from the parent's frame, but
        // SwiftUI's coordinate space lets us use a relative offset.
        // Using a GeometryReader would be more precise; for the
        // standard 44/104pt avatar sizes this offset reads correctly.
        return 48
    }

}

/// Backdrop — soft top-of-screen image with a vertical fade. Wrapped in
/// an explicit GeometryReader-fed frame so a high-resolution source PNG
/// can never inflate parent layout.
struct CosmeticBackdrop: View {
    let tier: RankTitle
    var colorTier: RankTitle? = nil
    var maxHeight: CGFloat = 320

    var body: some View {
        let washTier = colorTier ?? tier

        GeometryReader { geo in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: washTier.rewardGlowColors.map { $0.opacity(0.16) } + [.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let asset = RankCosmetics.profileBackgroundAsset(for: tier),
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
                                    .init(color: Color.unbound.bg.opacity(0.06), location: 0),
                                    .init(color: Color.unbound.bg.opacity(0.44), location: 0.68),
                                    .init(color: Color.unbound.bg.opacity(0.96), location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RadialGradient(
                                colors: washTier.rewardGlowColors.map { $0.opacity(0.18) } + [.clear],
                                center: .topTrailing,
                                startRadius: 12,
                                endRadius: max(260, geo.size.width * 0.85)
                            )
                            .blendMode(.screen)
                        )
                        .opacity(0.88)
                }
            }
            .frame(width: geo.size.width, height: maxHeight, alignment: .top)
        }
        .frame(height: maxHeight)
        .allowsHitTesting(false)
    }
}
