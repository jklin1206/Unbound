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
            // Inner core — sized to fit INSIDE the frame's transparent
            // center (the ring eats ~10% of canvas on each side).
            innerCore
                .frame(width: size * 0.72, height: size * 0.72)

            // Cosmetic frame border, always-on. Frame asset is a
            // transparent ring so the inner core shows through cleanly.
            frameBorder
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .clipped()
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
                Text(letterFallback.uppercased().prefix(1))
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
            }
        }
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
            // Lower tiers stay clean; honed+ get the ornament treatment.
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
                // Outer halo for Ascendant only.
                if tier == .ascendant {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 4)
                        .blur(radius: 4)
                }
            }
        }
        .shadow(color: tint.opacity(glowOpacity), radius: glowRadius)
    }

    // MARK: Tier styling

    private var tint: Color {
        switch tier {
        case .initiate:   return Color.unbound.textSecondary
        case .novice:     return Color(red: 0.95, green: 0.45, blue: 0.55)  // coral
        case .apprentice: return Color(red: 0.95, green: 0.65, blue: 0.30)  // amber
        case .forged:     return Color(red: 0.85, green: 0.55, blue: 0.30)  // copper
        case .veteran:    return Color(red: 0.40, green: 0.80, blue: 0.65)  // teal
        case .honed:      return Color.unbound.accent                       // violet brand
        case .vessel:     return Color.unbound.accent
        case .unbound:    return Color.unbound.accent
        case .ascendant:  return Color(red: 0.95, green: 0.78, blue: 0.40)  // gold
        }
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

    private var glowOpacity: Double {
        switch tier.ordinal {
        case 1...4: return 0
        case 5...6: return 0.25
        case 7:     return 0.40
        default:    return 0.55
        }
    }

    private var glowRadius: CGFloat {
        switch tier.ordinal {
        case 1...4: return 0
        case 5...6: return 6
        case 7:     return 10
        default:    return 14
        }
    }
}

/// Backdrop — soft top-of-screen image with a vertical fade. Wrapped in
/// an explicit GeometryReader-fed frame so a high-resolution source PNG
/// can never inflate parent layout.
struct CosmeticBackdrop: View {
    let tier: RankTitle
    var maxHeight: CGFloat = 320

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if let asset = RankCosmetics.profileBackgroundAsset(for: tier),
                   let ui = UIImage(named: asset) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: maxHeight)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: Color.unbound.bg.opacity(0.7), location: 0.7),
                                    .init(color: Color.unbound.bg, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(0.75)
                }
            }
            .frame(width: geo.size.width, height: maxHeight, alignment: .top)
        }
        .frame(height: maxHeight)
        .allowsHitTesting(false)
    }
}
