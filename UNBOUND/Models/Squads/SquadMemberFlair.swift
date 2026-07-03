import Foundation

/// A squad member's public profile "flair" — the equipped cosmetics + featured
/// showcase + rank + attribute snapshot needed to render their profile the same
/// way they see it themselves.
///
/// Every field is a value the owner already resolved on their own Profile screen
/// (`ProfileView`), which publishes this to `squad_member_flair`. Squadmates read
/// it through the gated `squad_member_flair_for_squad` RPC — the per-user profile
/// cosmetics are otherwise device-local and unreadable cross-user.
struct SquadMemberFlair: Codable, Sendable, Equatable {
    /// Equipped profile banner asset (shop backdrop or rank-tier banner).
    var backdropAssetName: String?
    /// Equipped shop profile border, if any.
    var borderId: ShopProfileBorderID?
    /// Cosmetic avatar frame tier.
    var frameTier: RankTier
    /// Aggregate rank tier (drives the rank plate + glow).
    var rankTier: RankTier
    /// Featured skill.
    var showcaseSkillName: String
    var showcaseSkillTier: RankTier
    /// Featured lift.
    var showcaseLiftName: String
    var showcaseLiftTier: RankTier
    /// The 6-axis attribute profile powering the build hex.
    var attributeProfile: AttributeProfile
}
