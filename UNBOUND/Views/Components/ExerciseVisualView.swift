import SwiftUI
import UIKit

enum ExerciseVisualAsset {
    static let prefix = "exercise_visual_"

    static func assetName(for definition: MovementDefinition) -> String {
        prefix + sanitized(definition.id)
    }

    static func existingAssetName(for definition: MovementDefinition) -> String? {
        let name = assetName(for: definition)
        return UIImage(named: name) == nil ? nil : name
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar).lowercased() : "_"
        }.joined()
    }
}

struct ExerciseVisualView: View {
    enum Size {
        case thumbnail
        case hero

        var cornerRadius: CGFloat {
            switch self {
            case .thumbnail: return 10
            case .hero: return 18
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .thumbnail: return 24
            case .hero: return 54
            }
        }
    }

    let definition: MovementDefinition
    var size: Size = .thumbnail

    private var shippedAssetName: String? {
        ExerciseVisualAsset.existingAssetName(for: definition)
    }

    private var tint: Color {
        switch definition.movementSlot {
        case .squat, .hinge: return Color.unbound.warnOrange
        case .horizontalPush, .verticalPush: return Color.unbound.emberGlow
        case .horizontalPull, .verticalPull: return Color.rewardBlue
        case .core: return Color.unbound.rankGold
        case .mobility: return Color.rewardTeal
        case .cardio, .carry: return Color.unbound.impact
        case .arms, .calves, .routine, .skill: return Color.unbound.accent
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(Color.white)

            if let shippedAssetName {
                Image(shippedAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(size == .hero ? 12 : 6)
            } else {
                placeholder
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        .accessibilityLabel("\(definition.displayName) visual")
    }

    private var placeholder: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                stylizedFigure(in: proxy.size)

                Circle()
                    .fill(tint.opacity(0.78))
                    .frame(width: side * 0.22, height: side * 0.22)
                    .offset(x: side * 0.12, y: -side * 0.04)
                    .blur(radius: side * 0.015)
                    .blendMode(.multiply)

                Image(systemName: placeholderIcon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .offset(x: -side * 0.22, y: side * 0.2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(size == .hero ? 18 : 8)
    }

    private func stylizedFigure(in size: CGSize) -> some View {
        let width = min(size.width, size.height) * 0.46
        return ZStack {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: width * 0.34, height: width * 0.86)
                .rotationEffect(.degrees(-26))
            Capsule()
                .fill(Color.black.opacity(0.16))
                .frame(width: width * 0.18, height: width * 0.72)
                .rotationEffect(.degrees(38))
                .offset(x: width * 0.28, y: width * 0.04)
            Capsule()
                .fill(Color.black.opacity(0.16))
                .frame(width: width * 0.16, height: width * 0.62)
                .rotationEffect(.degrees(-52))
                .offset(x: -width * 0.2, y: width * 0.22)
            Circle()
                .fill(Color.black.opacity(0.18))
                .frame(width: width * 0.22, height: width * 0.22)
                .offset(x: -width * 0.18, y: -width * 0.48)
        }
        .offset(x: width * 0.16, y: -width * 0.02)
    }

    private var placeholderIcon: String {
        switch definition.movementSlot {
        case .squat, .hinge, .calves:
            return "figure.strengthtraining.traditional"
        case .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .arms:
            return "dumbbell.fill"
        case .core:
            return "figure.core.training"
        case .mobility:
            return "figure.flexibility"
        case .cardio:
            return "figure.run"
        case .carry:
            return "figure.walk"
        case .routine, .skill:
            return "figure.strengthtraining.functional"
        }
    }
}
