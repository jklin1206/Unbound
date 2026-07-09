import UIKit

enum SkillTraditionalVisualResolver {
    static func assetName(for node: SkillNode) -> String? {
        if let generatedSkillIcon = generatedSkillIconAssetName(for: node) {
            return generatedSkillIcon
        }

        for slug in candidateSlugs(for: node) {
            let candidate = "exercise_visual_exercise_\(slug)"
            if let resolved = preferredAssetName(forBaseAssetName: candidate) {
                return resolved
            }
        }
        return nil
    }

    private static func generatedSkillIconAssetName(for node: SkillNode) -> String? {
        guard generatedSkillIconNodeIds.contains(node.id) else { return nil }

        let baseName = node.id.replacingOccurrences(of: ".", with: "_")
        for candidate in [baseName, "\(baseName)_f2"] where UIImage(named: candidate) != nil {
            return candidate
        }
        return nil
    }

    private static func preferredAssetName(forBaseAssetName baseAssetName: String) -> String? {
        if ExerciseVisualAssetSet.active == .jot,
           jotSkillTreeAssetsNeedingLegacyFallback.contains(baseAssetName) {
            let legacyCandidate = ExerciseVisualAsset.setScopedAssetName(baseAssetName, in: .legacy)
            if UIImage(named: legacyCandidate) != nil {
                return legacyCandidate
            }
        }

        if ExerciseVisualAssetSet.active != .current,
           let aliasBaseAssetName = legacySkillTreeAliasBaseAssetNames[baseAssetName] {
            let legacyCandidate = ExerciseVisualAsset.setScopedAssetName(aliasBaseAssetName, in: .legacy)
            if UIImage(named: legacyCandidate) != nil {
                return legacyCandidate
            }
        }

        return ExerciseVisualAsset.existingAssetName(forBaseAssetName: baseAssetName)
    }

    private static func candidateSlugs(for node: SkillNode) -> [String] {
        var slugs: [String] = []

        if let mapped = manualSlugMap[node.id] {
            slugs.append(contentsOf: mapped)
        }

        slugs.append(MovementCatalog.slug(node.title))
        slugs.append(node.id.components(separatedBy: ".").last ?? node.id)

        for criterion in node.tierCriteria.values {
            slugs.append(contentsOf: exerciseSlugs(in: criterion))
        }

        return slugs.reduce(into: []) { result, slug in
            let normalized = MovementCatalog.slug(slug)
            guard !normalized.isEmpty, !result.contains(normalized) else { return }
            result.append(normalized)
        }
    }

    private static func exerciseSlugs(in criterion: TierCriterion) -> [String] {
        switch criterion {
        case .reps(_, let exerciseName):
            return [exerciseName]
        case .exerciseSeconds(_, let exerciseName):
            return [exerciseName]
        case .exerciseWeightKg(_, let exerciseName):
            return [exerciseName]
        case .exerciseBodyweightRatio(_, let exerciseName):
            return [exerciseName]
        case .variant(let name):
            return [name]
        case .compound(let criteria):
            return criteria.flatMap(exerciseSlugs)
        case .seconds, .weightKg, .bodyweightRatio:
            return []
        }
    }

    private static let manualSlugMap: [String: [String]] = [
        "cal.5-dips": ["dip"],
        "cal.clapping-handstand-pushup": ["clapping-handstand-pushup", "handstand-pushup"],
        "cal.l-sit-10": ["l-sit"],
        "cal.plank-30": ["plank"],
        "hs.freestanding-hs-30": ["freestanding-handstand"],
        "cl.hollow-body-30": ["hollow-hold"],
        "cl.tuck-front-lever": ["tuck-front-lever"],
        "cl.straddle-front-lever": ["straddle-front-lever"],
        "cl.full-front-lever": ["full-front-lever"],
        "cl.tuck-back-lever": ["tuck-back-lever"],
        "cl.straddle-back-lever": ["straddle-back-lever"],
        "cl.full-back-lever": ["full-back-lever"],
        "cl.dragon-flag": ["dragon-flag"],
        "ld.single-leg-glute-bridge": ["single-leg-glute-bridge"],
        "ld.nordic-curl": ["nordic-curl"],
        "pp.incline-row": ["incline-row"],
        "pp.row": ["inverted-row"],
        "pp.strict-pullup": ["pullup"],
        "pp.weighted-pullup": ["weighted-pullup"],
        "pp.wide-pullup": ["wide-grip-pullup"],
        "pp.strict-chin-up": ["chin-up"],
        "pp.oap-negative": ["negative-pullup"],
        "pp.one-arm-chin-up": ["one-arm-chin-up"],
        "pp.one-arm-pullup": ["one-arm-pullup"],
        "pp.decline-row": ["decline-row"],
        "pp.one-arm-row": ["one-arm-row", "one-arm-inverted-row"],
        "pp.tuck-row": ["tuck-row"],
        "pp.straddle-row": ["straddle-row"],
        "pp.tuck-front-lever-pullup": ["tuck-front-lever-pull-up", "tuck-front-lever-pullup"],
        "pp.muscle-up": ["muscle-up"]
    ]

    private static let generatedSkillIconNodeIds: Set<String> = [
        "cal.l-sit-10",
        "pl.tuck-planche",
        "pl.bent-arm-planche",
        "pl.straddle-planche",
        "pl.full-planche",
        "pp.muscle-up",
        "pp.ring-muscle-up",
        "pp.strict-muscle-up",
        "pp.straddle-row",
        "pp.tuck-front-lever-pullup",
        "hs.elbow-lever",
        "oah.one-arm-handstand-5s",
        "cl.tuck-front-lever",
        "cl.tuck-back-lever",
        "cl.full-front-lever",
        "cl.full-back-lever",
        "hs.wall-handstand-30",
        "hs.freestanding-hs-30",
        "cl.straddle-front-lever",
        "cl.straddle-back-lever"
    ]

    private static let jotSkillTreeAssetsNeedingLegacyFallback: Set<String> = [
        "exercise_visual_exercise_advanced-tuck-front-lever",
        "exercise_visual_exercise_full-back-lever",
        "exercise_visual_exercise_full-front-lever",
        "exercise_visual_exercise_incline-row",
        "exercise_visual_exercise_inverted-row",
        "exercise_visual_exercise_one-arm-inverted-row",
        "exercise_visual_exercise_one-arm-row",
        "exercise_visual_exercise_straddle-back-lever",
        "exercise_visual_exercise_straddle-front-lever",
        "exercise_visual_exercise_tuck-front-lever",
        "exercise_visual_exercise_tuck-front-lever-pull-up",
        "exercise_visual_exercise_tuck-front-lever-pullup",
        "exercise_visual_exercise_tuck-row"
    ]

    private static let legacySkillTreeAliasBaseAssetNames: [String: String] = [
        "exercise_visual_exercise_straddle-row": "exercise_visual_exercise_inverted-row",
        "exercise_visual_exercise_tuck-back-lever": "exercise_visual_exercise_straddle-back-lever"
    ]
}
