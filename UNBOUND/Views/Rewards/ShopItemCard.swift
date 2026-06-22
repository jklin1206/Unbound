import SwiftUI

struct ShopItemCard: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            preview
                .aspectRatio(previewAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Text(item.rarity.uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(item.rarityTint)
                        .lineLimit(1)
                    if isOwned {
                        Image(systemName: isEquipped ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isEquipped ? Color.unbound.rankGold : item.accent)
                    }
                }

                Text(item.name)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    if isOwned {
                        Text(isEquipped ? "ACTIVE" : "OWNED")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isEquipped ? Color.unbound.rankGold : item.accent)
                    } else {
                        ArcCurrencyAmount(
                            amount: item.price,
                            label: nil,
                            iconSize: 17,
                            spacing: 4,
                            iconPlacement: .trailing,
                            valueFont: .system(size: 16, weight: .black, design: .rounded),
                            valueColor: canAfford ? Color.unbound.rankGold : Color.unbound.textTertiary
                        )
                    }
                }

                Spacer(minLength: 0)

                Button(action: action) {
                    Text(actionTitle.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(buttonForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 12)
                        .frame(minWidth: 72, minHeight: 32)
                        .background(Capsule().fill(buttonBackground))
                }
                .buttonStyle(.plain)
                .disabled(isEquipped)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 286, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(isEquipped ? 0.96 : 0.88))
        )
        .shadow(color: item.accent.opacity(isEquipped ? 0.20 : 0.08), radius: isEquipped ? 14 : 8, y: 6)
    }

    private var previewAspectRatio: CGFloat {
        switch item.reward {
        case .homeBackground:
            return ShopBackdropArtworkPreview.homePosterAspectRatio
        case .profileBackground:
            return ShopBackdropArtworkPreview.profileBannerAspectRatio
        default:
            return 1
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.reward {
        case .homeBackground(let background):
            // Show the real backdrop art, not a generic house glyph over a dark
            // scrim — the category tabs already say what surface this is, so the
            // preview's job is to accurately render the scene you're buying.
            ShopBackdropArtworkPreview(
                assetName: background.assetName,
                accent: background.accent,
                role: .homePoster,
                symbolName: nil,
                scrimOpacity: 0.16
            )
        case .skillTreeSkin(let skin):
            ShopSkillTreeMapPreview(skin: skin, compact: true)
        case .profileBorder(let border):
            ZStack {
                // Calm dark tile (no colourful gradient) + the code-drawn ring
                // shown on a sample avatar, matching the cosmetics picker.
                Color.unbound.bg.opacity(0.55)
                ShopPreviewLinework(color: border.accent)
                    .opacity(0.12)
                CosmeticAvatar(
                    tier: .initiate,
                    size: 104,
                    letterFallback: "U",
                    shopBorder: border
                )
            }
        case .profileBackground(let background):
            ShopBackdropArtworkPreview(
                assetName: background.assetName,
                accent: background.accent,
                role: .profileBanner,
                symbolName: nil,
                scrimOpacity: 0.52
            )
        case .profileTitle(let titleID):
            ZStack {
                itemGradient
                ShopPreviewLinework(color: item.accent)
                    .opacity(0.20)
                VStack(spacing: 6) {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.unbound.textPrimary)
                    Text(TitleCatalog.displayName(for: titleID).uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .padding(.horizontal, 6)
                }
            }
        }
    }

    private var itemGradient: LinearGradient {
        LinearGradient(
            colors: item.colors.map { $0.opacity(0.82) } + [Color.unbound.surfaceElevated],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var buttonBackground: Color {
        if isEquipped { return Color.unbound.rankGold.opacity(0.20) }
        if isOwned { return item.accent.opacity(0.22) }
        return canAfford ? item.accent.opacity(0.90) : Color.unbound.surfaceElevated
    }

    private var buttonForeground: Color {
        if isEquipped { return Color.unbound.rankGold }
        if isOwned { return Color.unbound.textPrimary }
        return canAfford ? Color.black.opacity(0.78) : Color.unbound.textTertiary
    }
}

struct ShopBackdropArtworkPreview: View {
    static let homePosterAspectRatio: CGFloat = UnboundBackdropAspect.homePoster
    static let profileBannerAspectRatio: CGFloat = UnboundBackdropAspect.profileBanner

    let assetName: String?
    let accent: Color
    var role: BackdropPresentationRole = .thumbnail
    var symbolName: String?
    var symbolSize: CGFloat = 22
    var isMuted: Bool = false
    var scrimOpacity: Double = 0.54

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let assetName,
                   let ui = UIImage(named: assetName) {
                    previewImage(ui, in: proxy.size)
                } else {
                    LinearGradient(
                        colors: [accent.opacity(0.78), Color.unbound.surfaceElevated],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    ShopPreviewLinework(color: accent)
                        .opacity(0.24)
                }

                // Dissolve the bottom of the scene into the card surface instead of
                // a hard rectangular crop — the backdrop fades out rather than getting
                // chopped off. (Profile banners keep their own full-bleed treatment.)
                if role != .profileBanner {
                    LinearGradient(
                        colors: [Color.clear, Color.unbound.surface],
                        startPoint: UnitPoint(x: 0.5, y: 0.58),
                        endPoint: .bottom
                    )
                }

                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: symbolSize, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .shadow(color: accent.opacity(0.54), radius: 9)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func previewImage(_ ui: UIImage, in size: CGSize) -> some View {
        switch role {
        case .profileBanner:
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height, alignment: .trailing)
                .clipped()
                .saturation(1)
                .contrast(1)
        case .homePoster, .thumbnail:
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .saturation(isMuted ? 0.35 : 1.08)
                .contrast(1.05)
        }
    }

}

struct ArcCurrencyAmount: View {
    enum IconPlacement: Equatable {
        case leading
        case trailing
    }

    let amount: Int
    var label: String? = nil
    var iconSize: CGFloat = 18
    var spacing: CGFloat = 5
    var compact: Bool = false
    var showsIcon: Bool = true
    var iconPlacement: IconPlacement = .leading
    var valueFont: Font = .system(size: 16, weight: .black, design: .rounded)
    var valueColor: Color = Color.unbound.textPrimary
    var labelFont: Font = .system(size: 8, weight: .black, design: .monospaced)
    var labelColor: Color = Color.unbound.impact

    private var formattedAmount: String {
        compact ? Self.compactText(for: amount) : amount.formatted()
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            if showsIcon, iconPlacement == .leading {
                coinIcon
            }

            Text(formattedAmount)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let label {
                Text(label)
                    .font(labelFont)
                    .tracking(1.0)
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            if showsIcon, iconPlacement == .trailing {
                coinIcon
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount.formatted()) Arcs")
    }

    private var coinIcon: some View {
        Image("shop_currency_arc")
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .shadow(color: Color.unbound.impact.opacity(0.24), radius: 4)
            .accessibilityHidden(true)
    }

    static func compactText(for amount: Int) -> String {
        if amount >= 1_000_000 {
            let value = Double(amount) / 1_000_000.0
            if value >= 10 {
                return "\(Int(value.rounded()))M"
            }
            let formatted = String(format: "%.1f", value)
            return formatted.hasSuffix(".0")
                ? "\(Int(value))M"
                : "\(formatted)M"
        }

        guard amount >= 1_000 else { return "\(amount)" }
        let value = Double(amount) / 1_000.0
        if value >= 10 {
            return "\(Int(value.rounded()))K"
        }
        let formatted = String(format: "%.1f", value)
        return formatted.hasSuffix(".0")
            ? "\(Int(value))K"
            : "\(formatted)K"
    }
}
