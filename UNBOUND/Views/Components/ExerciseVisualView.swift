import SwiftUI
import UIKit

enum ExerciseVisualAssetSet: String, CaseIterable, Identifiable {
    case jot
    case legacy
    case current

    static let userDefaultsKey = "UNBOUNDExerciseVisualAssetSet"
    static let environmentKey = "UNBOUND_EXERCISE_VISUAL_SET"
    static let defaultSet: ExerciseVisualAssetSet = .current

    var id: String { rawValue }

    static var active: ExerciseVisualAssetSet {
        if let override = ProcessInfo.processInfo.environment[environmentKey],
           let set = ExerciseVisualAssetSet(rawValue: override.lowercased()) {
            return set
        }

        if let stored = UserDefaults.standard.string(forKey: userDefaultsKey),
           let set = ExerciseVisualAssetSet(rawValue: stored.lowercased()) {
            if set == .jot {
                return .legacy
            }
            return set
        }

        return defaultSet
    }

    var displayName: String {
        switch self {
        case .jot: return "JOT"
        case .legacy: return "Legacy"
        case .current: return "Current"
        }
    }

    fileprivate var assetPrefixComponent: String? {
        switch self {
        case .jot: return "jot"
        case .legacy: return "legacy"
        case .current: return nil
        }
    }
}

enum ExerciseVisualAsset {
    static let prefix = "exercise_visual_"

    private static let visualAliasBaseAssetNames: [String: [String]] = [
        "assisted-squat": ["exercise_visual_exercise_bodyweight-squat"],
        "parallel-squat": ["exercise_visual_exercise_bodyweight-squat"],
        "deep-step-up": ["exercise_visual_exercise_step-up"],
        "partial-pistol-squat": [
            "exercise_visual_exercise_assisted-pistol-squat",
            "exercise_visual_exercise_pistol-squat"
        ],
        "beginner-shrimp-squat": ["exercise_visual_exercise_shrimp-squat"],
        "intermediate-shrimp-squat": ["exercise_visual_exercise_shrimp-squat"],
        "two-hand-shrimp-squat": ["exercise_visual_exercise_shrimp-squat"],
        "elevated-two-hand-shrimp-squat": ["exercise_visual_exercise_shrimp-squat"],
        "nordic-curl-negative": ["exercise_visual_exercise_nordic-curl"],
        "nordic-curl-arms-overhead": ["exercise_visual_exercise_nordic-curl"],
        "tuck-one-leg-nordic-curl": ["exercise_visual_exercise_nordic-curl"],
        "one-leg-nordic-curl": ["exercise_visual_exercise_nordic-curl"],
        "bodyweight-leg-extension": ["exercise_visual_exercise_leg-extensions"],
        "pp-dead-hang": ["exercise_visual_exercise_dead-hang"],
        "skill-drill-wall-handstand": ["exercise_visual_exercise_wall-handstand"],
        "skill-drill-freestanding-handstand": ["exercise_visual_exercise_freestanding-handstand"],
        "skill-drill-crow-pose": ["exercise_visual_exercise_crow-pose"],
        "skill-drill-headstand": ["exercise_visual_exercise_headstand"],
        "skill-drill-tuck-l-sit": ["exercise_visual_exercise_l-sit-tucked"]
    ]

    private static let preferredVisualBaseAssetNames: [String: [String]] = [
        "band-row": ["exercise_visual_jot_exercise_band-row"],
        "band-lat-pull": ["exercise_visual_exercise_assisted-pullup-band"]
    ]

    static func assetName(for definition: MovementDefinition) -> String {
        assetNameCandidates(forMovementId: definition.id).first ?? prefix + sanitized(definition.id)
    }

    static func existingAssetName(for definition: MovementDefinition) -> String? {
        existingAssetName(forMovementId: definition.id)
    }

    static func existingAssetName(forMovementId movementId: String) -> String? {
        let candidates = assetNameCandidates(forMovementId: movementId)

        if movementId.hasPrefix("carry.") {
            for candidate in candidates where UIImage(named: candidate) != nil {
                return candidate
            }
        }

        for candidate in candidates {
            if let existing = existingAssetName(forBaseAssetName: candidate) {
                return existing
            }
        }
        return nil
    }

    static func existingAssetName(forBaseAssetName baseAssetName: String) -> String? {
        assetNameCandidates(forBaseAssetName: baseAssetName).first { UIImage(named: $0) != nil }
    }

    static func image(named assetName: String) -> UIImage? {
        guard let resolved = existingAssetName(forBaseAssetName: assetName) else {
            return nil
        }
        return UIImage(named: resolved)
    }

    static func setScopedAssetName(_ baseAssetName: String, in set: ExerciseVisualAssetSet) -> String {
        assetName(baseAssetName, in: set)
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar).lowercased() : "_"
        }.joined()
    }

    private static func assetNameCandidates(forMovementId movementId: String) -> [String] {
        let direct = prefix + sanitized(movementId)
        let rawName = movementId
            .replacingOccurrences(of: "exercise.", with: "")
            .replacingOccurrences(of: "exercise_", with: "")
        let rawSlug = MovementCatalog.slug(rawName)
        let slugged = "\(prefix)exercise_\(MovementCatalog.slug(rawName))"
        let underscored = "\(prefix)exercise_\(MovementCatalog.normalized(rawName).replacingOccurrences(of: " ", with: "_"))"

        var candidates: [String] = []
        if movementId.hasPrefix("carry.") {
            let carryName = movementId.replacingOccurrences(of: "carry.", with: "")
            let carrySlug = MovementCatalog.slug(carryName)
            candidates.append("\(prefix)exercise_\(carrySlug)")
            if carrySlug == "farmer-carry" {
                candidates.append("\(prefix)exercise_heavy-farmer-carry")
            }
            candidates.append("\(prefix)carry_\(carrySlug)")
        }

        if let preferred = preferredVisualBaseAssetNames[rawSlug] {
            candidates.append(contentsOf: preferred)
        }
        candidates.append(contentsOf: [direct, slugged, underscored])
        if let aliases = visualAliasBaseAssetNames[rawSlug] {
            candidates.append(contentsOf: aliases)
        }

        return candidates.reduce(into: []) { result, candidate in
            guard !result.contains(candidate) else { return }
            result.append(candidate)
        }
    }

    private static func assetNameCandidates(forBaseAssetName baseAssetName: String) -> [String] {
        guard baseAssetName.hasPrefix(prefix) else {
            return [baseAssetName]
        }

        let activeSet = ExerciseVisualAssetSet.active
        let candidates: [String]
        switch activeSet {
        case .jot:
            candidates = [assetName(baseAssetName, in: .jot), baseAssetName]
        case .legacy:
            candidates = [assetName(baseAssetName, in: .legacy), baseAssetName]
        case .current:
            candidates = [baseAssetName]
        }

        return candidates.reduce(into: []) { result, candidate in
            guard !result.contains(candidate) else { return }
            result.append(candidate)
        }
    }

    private static func assetName(_ baseAssetName: String, in set: ExerciseVisualAssetSet) -> String {
        guard let component = set.assetPrefixComponent,
              baseAssetName.hasPrefix(prefix)
        else { return baseAssetName }

        let suffix = baseAssetName.dropFirst(prefix.count)
        return "\(prefix)\(component)_\(suffix)"
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
                    .padding(visualPadding(for: shippedAssetName))
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

    private func visualPadding(for assetName: String) -> CGFloat {
        guard assetName.hasPrefix(ExerciseVisualAsset.prefix) else {
            return size == .hero ? 12 : 6
        }
        return size == .hero ? 6 : 2
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
