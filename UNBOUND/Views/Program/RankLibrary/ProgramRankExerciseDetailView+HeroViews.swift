import SwiftUI
import UIKit

extension ProgramRankExerciseDetailView {

    func hero(_ definition: MovementDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heroArtwork(definition)
                .frame(maxWidth: .infinity)
                .aspectRatio(1.08, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                Text(definition.displayName.uppercased())
                    .font(Font.unbound.titleM)
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func heroArtwork(_ definition: MovementDefinition) -> some View {
        if let assetName = row.visualAssetName {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(heroArtworkBackground(for: assetName))

                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(assetName.hasSuffix("_highlight") ? 1.18 : 1.0)
                    .padding(heroArtworkPadding(for: assetName))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityLabel("\(definition.displayName) visual")
        } else {
            ExerciseVisualView(definition: definition, size: .hero)
        }
    }

    func heroArtworkBackground(for assetName: String) -> AnyShapeStyle {
        if shouldUseWhiteArtworkStage(for: assetName) {
            return AnyShapeStyle(Color.white)
        }
        if assetName.hasSuffix("_highlight") {
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
        return AnyShapeStyle(Color.unbound.surfaceElevated.opacity(0.28))
    }

    func shouldUseWhiteArtworkStage(for assetName: String) -> Bool {
        assetName.hasPrefix("exercise_visual_")
            && row.source == .exercise
            && !row.id.hasPrefix("movement-detail-")
    }

    func heroArtworkPadding(for assetName: String) -> CGFloat {
        if assetName.hasPrefix("exercise_visual_") { return 6 }
        return assetName.hasSuffix("_highlight") ? 0 : 14
    }

    var progressSummary: some View {
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            Text(displayedTier.displayName.uppercased())
                .font(Font.unbound.titleS.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            Text(bestSummary)
                .font(Font.unbound.bodyS.weight(.bold))
                .foregroundStyle(Color.unbound.coachCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var bestSummary: String {
        if let progress {
            return ProgramRankExerciseFormatter.bestSummary(progress)
        }
        return row.detail
    }

    func targetMapSection(_ definition: MovementDefinition) -> some View {
        let targetRegions = ProgramRankTargetRegionSet.regions(for: definition)

        return detailSection(
            title: "TARGET MAP",
            subtitle: targetRegions.isEmpty ? "No catalog body regions for this standard" : nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgramRankTargetBodyFigure(
                        side: .front,
                        targetRegions: targetRegions,
                        tint: tint
                    )
                    ProgramRankTargetBodyFigure(
                        side: .back,
                        targetRegions: targetRegions,
                        tint: tint
                    )
                }

                ProgramRankTargetRegionStrip(
                    regions: targetRegions,
                    tint: tint
                )
            }
        }
    }
}
