import SwiftUI
import UIKit

// MARK: - RoutineExerciseVisualCard

struct RoutineExerciseVisualCard: View {
    let assetName: String
    let title: String
    let accent: Color
    var compact: Bool = false

    private var image: UIImage? {
        ExerciseVisualAsset.image(named: assetName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 8)

                Text("FORM")
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(accent)
            }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(compact ? 10 : 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                    )
                    .frame(height: compact ? 152 : 190)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.26), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) form reference")
    }
}

// MARK: - MobilityReferenceCard

struct MobilityReferenceCard: View {
    let reference: MobilityReference
    let accent: Color
    var compact: Bool = false
    var framed: Bool = true

    private var shippedImages: [UIImage] {
        if let singleImage = UIImage(named: reference.assetName) {
            return [singleImage]
        }

        return [reference.startAssetName, reference.endAssetName].compactMap { assetName in
            UIImage(named: assetName)
        }
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reference.title.uppercased())
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                Text(reference.targetArea.uppercased())
                    .font(Font.unbound.monoS.weight(.heavy))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if !shippedImages.isEmpty {
                referenceMedia(images: shippedImages)
                    .frame(height: compact ? 156 : 196)
            }

            Text(reference.cue)
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
                .lineLimit(compact ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
        }

        Group {
            if framed {
                content
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.unbound.surfaceElevated.opacity(0.82))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(accent.opacity(0.26), lineWidth: 1)
                    )
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reference.title) reference. \(reference.cue)")
    }

    @ViewBuilder
    private func referenceMedia(images: [UIImage]) -> some View {
        if images.count == 1, let image = images.first {
            referenceImage(image)
        } else {
            HStack(spacing: 8) {
                ForEach(Array(images.prefix(2).enumerated()), id: \.offset) { index, image in
                    referenceImage(image, label: index == 0 ? "START" : "END")
                }
            }
        }
    }

    private func referenceImage(_ image: UIImage, label: String? = nil) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topLeading) {
                if let label {
                    Text(label)
                        .font(Font.unbound.monoS.weight(.heavy))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.72))
                        )
                        .padding(7)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(accent.opacity(0.18), lineWidth: 1)
            )
    }
}
