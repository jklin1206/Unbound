import SwiftUI
import UIKit

struct ProgramRankLibraryRowView: View {
    let row: ProgramRankLibraryRow
    var showsDisclosure: Bool = false

    private var tint: Color { row.tier.rewardTextTint }
    private var usesHighlightArt: Bool {
        row.visualAssetName?.hasSuffix("_highlight") == true
    }
    private var usesTraditionalExerciseArt: Bool {
        row.visualAssetName?.hasPrefix("exercise_visual_") == true
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: row.source.systemImage)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(tint)
                        Text(row.source.displayName.uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(Color.unbound.textTertiary)
                        Spacer(minLength: 0)
                        Text(row.metric)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(tint.opacity(row.isEarned ? 0.95 : 0.58))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        if showsDisclosure {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.unbound.textTertiary)
                        }
                    }

                    Text(row.title.uppercased())
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text("\(row.subtitle) - \(row.detail)")
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 11)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity, alignment: .leading)

            rankBand
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(row.isEarned ? 0.22 : 0.10), lineWidth: 1)
        )
        .opacity(row.isEarned ? 1 : 0.68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("\(row.title), \(row.tier.displayName), \(row.metric)")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(showsDisclosure ? "Opens full screen detail" : "")
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(artworkBackground)

            if let assetName = row.visualAssetName {
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(assetName.hasSuffix("_highlight") ? 1.34 : 1.0)
                    .padding((row.source == .exercise || usesTraditionalExerciseArt) ? 5 : (assetName.hasSuffix("_highlight") ? 0 : 4))
                    .opacity(row.isEarned ? 1.0 : 0.52)
            } else {
                Image(systemName: row.source.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint.opacity(row.isEarned ? 0.9 : 0.46))
            }
        }
        .frame(width: 58, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(row.isEarned ? 0.30 : 0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var artworkBackground: some ShapeStyle {
        if row.source == .exercise || usesTraditionalExerciseArt {
            return AnyShapeStyle(Color.white)
        }
        if usesHighlightArt {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.25, blue: 0.15),
                        Color(red: 0.18, green: 0.13, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(tint.opacity(row.isEarned ? 0.16 : 0.08))
    }

    private var rankBand: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if row.isRankHidden {
                // not-yet feat — no earned rank badge to show
                Text("—")
                    .font(Font.unbound.titleM)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(width: 35, height: 35)
            } else {
                Image(row.tier.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35, height: 35)
                    .opacity(row.isEarned ? 1.0 : 0.42)
                    .shadow(color: tint.opacity(row.isEarned ? 0.35 : 0.12), radius: 8)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                tint.opacity(row.isEarned ? 0.16 : 0.06)
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint.opacity(row.isEarned ? 0.22 : 0.10))
                .frame(width: 1)
        }
    }
}
