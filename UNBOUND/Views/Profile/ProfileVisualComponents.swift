import SwiftUI
import PhotosUI

struct ProfileHeroAvatar: View {
    let cosmeticTier: RankTitle
    let glowTier: RankTitle
    let profileTint: Color
    let skillTier: SkillTier
    let level: Int
    let tint: Color
    let image: UIImage?
    let letterFallback: String
    let shopBorder: ShopProfileBorderID?
    let size: CGFloat
    var defaultPortrait: DefaultPortrait = .masculine

    var body: some View {
        let glowSize = size * 1.08

        ZStack {
            // Dark seat: lets the framed avatar read cleanly on any banner art
            // (bright halls were washing the frame out and making it float).
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: glowSize * 1.2, height: glowSize * 1.2)
                .blur(radius: size * 0.3)
            Circle()
                .fill(profileTint.opacity(0.16))
                .frame(width: glowSize, height: glowSize)
                .blur(radius: size * 0.15)

            CosmeticAvatar(
                tier: cosmeticTier,
                size: size,
                image: image,
                letterFallback: letterFallback,
                shopBorder: shopBorder,
                defaultPortrait: defaultPortrait
            )
            .shadow(color: profileTint.opacity(frameGlowOpacity), radius: frameGlowRadius)

            Text("LVL \(level)")
                .font(.system(size: max(8, size * 0.057), weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.top, 5)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(tint.opacity(0.72))
                        .frame(height: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: 8)
        }
        .frame(width: size + 12, height: size + 26)
    }

    private var frameGlowOpacity: Double {
        switch glowTier.ordinal {
        case 1...4: return 0
        case 5...6: return 0.24
        case 7: return 0.34
        default: return 0.44
        }
    }

    private var frameGlowRadius: CGFloat {
        switch glowTier.ordinal {
        case 1...4: return 0
        case 5...6: return 6
        case 7: return 10
        default: return 14
        }
    }
}

struct ProgressJourneySection: View {
    let dayZero: ProgressPhoto
    let now: ProgressPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BODY TIMELINE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text("DAY 0 → NOW")
                        .font(Font.unbound.titleS)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                Text(deltaCopy)
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
            }

            HStack(spacing: 10) {
                timelineImage(photo: dayZero, label: "DAY 0", tint: Color.unbound.textSecondary)
                timelineImage(photo: now, label: "NOW", tint: Color.unbound.impact)
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) {
            UnboundNativeDivider(opacity: 0.50)
        }
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.34)
        }
    }

    private func timelineImage(photo: ProgressPhoto, label: String, tint: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = UIImage(contentsOfFile: photo.storageUrl) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.unbound.bg)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    )
            }

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.58)))
                .overlay(Capsule().strokeBorder(tint.opacity(0.7), lineWidth: 1))
                .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 218)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.44), lineWidth: 1)
        )
    }

    private var deltaCopy: String {
        let days = Calendar.current.dateComponents([.day], from: dayZero.capturedAt, to: now.capturedAt).day ?? 0
        if days >= 60 { return "\(max(1, days / 30)) MO" }
        if days > 0 { return "\(days) D" }
        return "NOW"
    }
}

struct RankTitlePlate: View {
    let tier: SkillTier
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)

            Text(tier.displayName.uppercased())
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(Color.unbound.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .allowsTightening(true)
                .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(tint.opacity(0.42))
                .frame(height: 0.5)
        }
        .accessibilityIdentifier("profile.rankInfoPlate")
    }
}

struct LevelProgressPlate: View {
    let currentXP: Int
    let xpPerLevel: Int
    let lastXPGain: Int
    let progress: Double
    let tint: Color
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(currentXP)/\(xpPerLevel) XP")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.50)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(detail)
                    .font(Font.unbound.monoS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.unbound.borderSubtle)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint, Color.unbound.textPrimary.opacity(0.74)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(7, proxy.size.width * progress))
                        .shadow(color: tint.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 6)

            if lastXPGain > 0 {
                Text("+\(compactNumber(lastXPGain)) \(detail) LAST")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            UnboundNativeDivider(opacity: 0.48)
        }
    }

    private func compactNumber(_ value: Int) -> String {
        let clamped = max(0, value)
        if clamped >= 1_000_000 {
            return String(format: "%.1fM", Double(clamped) / 1_000_000)
        }
        if clamped >= 10_000 {
            return "\(clamped / 1_000)K"
        }
        if clamped >= 1_000 {
            return String(format: "%.1fK", Double(clamped) / 1_000)
        }
        return "\(clamped)"
    }
}

struct TrophyShowcaseRow: View {
    let label: String
    let value: String
    let systemImage: String
    let badgeTier: SkillTier

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(badgeTier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .shadow(color: badgeTier.rewardTint.opacity(0.20), radius: 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(badgeTier.rewardTint)
                        .frame(width: 13, alignment: .leading)
                    Text(label)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(value)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.46)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospacedDigit()
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 2)
    }
}

struct DossierLinework: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.58, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.44))
                    path.move(to: CGPoint(x: width * 0.72, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height * 0.24))
                    path.move(to: CGPoint(x: width * 0.05, y: height * 0.72))
                    path.addLine(to: CGPoint(x: width * 0.42, y: height))
                }
                .stroke(color.opacity(0.26), lineWidth: 1)

                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(Color.unbound.borderSubtle.opacity(0.42))
                            .frame(width: width * CGFloat(0.14 + Double(index) * 0.035), height: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
        }
        .allowsHitTesting(false)
    }
}
