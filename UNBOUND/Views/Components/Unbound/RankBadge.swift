import SwiftUI
import UIKit

// MARK: - RankBadge
//
// DEPRECATED. All call sites migrated to TierBadge(tier: SkillTier).
// This file is retained only for the #Preview block.
// Scheduled for deletion after xcodebuild confirms BUILD SUCCEEDED.
//
// Hexagon shape moved to Views/Components/Hexagon.swift.

enum RankBadgeSize {
    case small, medium, large

    var side: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 72
        case .large: return 120
        }
    }
    var font: Font {
        switch self {
        case .small: return Font.unbound.monoM
        case .medium: return Font.unbound.monoL
        case .large: return Font.unbound.monoXL
        }
    }
    var strokeWidth: CGFloat {
        switch self {
        case .small: return 1.5
        case .medium: return 2
        case .large: return 2.5
        }
    }
}

struct RankBadge: View {
    let letter: String
    var size: RankBadgeSize = .medium
    var accentOverride: Color? = nil
    private var title: RankTitle?

    init(letter: String, size: RankBadgeSize = .medium, accentOverride: Color? = nil) {
        self.letter = letter
        self.size = size
        self.accentOverride = accentOverride
        self.title = RankTitle.legacyLetterFallback(letter)
    }

    init(rank: SubRank, size: RankBadgeSize = .medium, accentOverride: Color? = nil) {
        self.letter = rank.title.displayName
        self.size = size
        self.accentOverride = accentOverride
        self.title = rank.title
    }

    var body: some View {
        let tint = accentOverride ?? assetTint
        Group {
            if let title, let image = UIImage(named: title.assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.side, height: size.side)
                    .clipped()
            } else {
                ZStack {
                    Hexagon()
                        .fill(tint.opacity(0.12))
                    Hexagon()
                        .inset(by: size.strokeWidth / 2)
                        .strokeBorder(tint, lineWidth: size.strokeWidth)
                    Text(letter.uppercased().prefix(1))
                        .font(size.font)
                        .foregroundStyle(tint)
                }
            }
        }
        .shadow(
            color: tint.opacity(size == .small ? 0.28 : 0.42),
            radius: size == .small ? 8 : 14
        )
        .frame(width: size.side, height: size.side)
    }

    private var assetTint: Color {
        switch title ?? RankTitle.legacyLetterFallback(letter) {
        case .initiate: return Color.unbound.textSecondary
        case .novice: return Color.unbound.rankRed
        case .apprentice: return Color.unbound.rankOrange
        case .forged: return Color.unbound.rankAmber
        case .veteran: return Color.unbound.rankGreen
        case .honed: return Color.unbound.accent
        case .vessel: return Color.unbound.impact
        case .unbound: return Color.unbound.impact
        case .ascendant: return Color.unbound.rankGold
        }
    }
}

#Preview("Ranks") {
    HStack(spacing: 24) {
        RankBadge(letter: "E", size: .small)
        RankBadge(letter: "D", size: .medium)
        RankBadge(letter: "C", size: .medium)
        RankBadge(letter: "S", size: .large)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.unbound.bg)
}
