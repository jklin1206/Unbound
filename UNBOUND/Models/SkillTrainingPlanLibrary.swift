import Foundation

// MARK: - SkillTrainingPlanLibrary
//
// Authored, hand-tuned training plans for keystone skills. Each plan owns
// regressions (for users below Lv1), main sets (the prescription), and
// accessories (supporting work).
//
// Coverage: every live skill routes to an authored keystone or family plan.
// Family plans keep related progressions consistent without duplicating the
// same coaching structure across dozens of sibling nodes.
//
// CONTENT RULE — Plan exercises MUST be either:
//   1. Drills (movements that aren't a tree node — band assists, scapular
//      pulls, holds, eccentrics, modifiers like tempo/pause, etc.), OR
//   2. The skill's own milestone (only inside the OWNING plan), OR
//      a clearly upstream skill the user almost certainly already has.
// Never reference downstream/parallel tree nodes (e.g. don't put "Weighted
// Pull-Up" inside the Pull-Up plan — it's a separate tree node the user
// hasn't unlocked yet).

enum SkillTrainingPlanLibrary {
    /// Returns the authored plan for a skill, or nil if no plan exists yet.
    /// Skills without a plan should fall back to a generic "do reps and progress" UX.
    static func plan(for skillId: String) -> SkillTrainingPlan? {
        switch skillId {
        case "pp.dead-hang":
            return hangPlan(skillId: skillId)
        case "pp.pullup":            return pullUpPlan
        case "pp.strict-pullup":     return strictPullUpPlan
        case "pp.chin-up", "pp.strict-chin-up", "pp.wide-pullup":
            return verticalPullPlan(skillId: skillId)
        case "pp.weighted-pullup", "pp.weighted-chin-up":
            return weightedPullPlan(skillId: skillId)
        case "pp.explosive-pullup", "pp.clapping-pullup":
            return explosivePullingPlan(skillId: skillId)
        case "pp.archer-pullup":
            return archerPullingPlan(skillId: skillId)
        case "pp.oap-negative", "pp.heighted-chin-up", "pp.one-arm-pullup", "pp.one-arm-chin-up":
            return soloArmPullPlan(skillId: skillId)
        case "pp.l-sit-chin-up":
            return lSitChinPlan
        case "pp.incline-row", "pp.row", "pp.decline-row", "pp.one-arm-row", "pp.tuck-row", "pp.straddle-row", "pp.tuck-front-lever-pullup":
            return rowFamilyPlan(skillId: skillId)
        case "pp.muscle-up":         return muscleUpPlan
        case "pp.ring-muscle-up", "pp.strict-muscle-up":
            return advancedMuscleUpPlan(skillId: skillId)
        case "hs.crow-pose", "hs.crane-pose", "hs.flying-crow", "hs.elbow-lever", "hs.one-arm-elbow-lever":
            return armBalancePlan(skillId: skillId)
        case "cal.pseudo-planche-pushup": return pseudoPlanchePushupPlan
        case "pl.tuck-planche":      return tuckPlanchePlan
        case "pl.straddle-planche", "pl.half-lay-planche":
            return intermediatePlanchePlan(skillId: skillId)
        case "pl.full-planche":      return fullPlanchePlan
        case "pl.bent-arm-planche":
            return bentArmPlanchePlan
        case "cal.incline-pushup", "cal.decline-pushup":
            return pushUpVariantPlan(skillId: skillId)
        case "cal.pushup":           return pushUpPlan
        case "cal.diamond-pushup", "cal.sphinx-pushup": return closeGripPushPlan(skillId: skillId)
        case "cal.pike-pushup", "cal.elevated-pike-pushup", "cal.floating-pike-pushup":
            return pikePushPlan(skillId: skillId)
        case "cal.tuck-planche-pushup":
            return planchePushPlan(skillId: skillId)
        case "cal.archer-pushup", "cal.one-arm-pushup":
            return unilateralPushPlan(skillId: skillId)
        case "cal.explosive-pushup", "cal.clapping-pushup", "cal.triple-clap-pushup":
            return explosivePushPlan(skillId: skillId)
        case "cal.handstand-pushup": return handstandPushPlan
        case "cal.clapping-handstand-pushup":
            return clappingHandstandPushPlan
        case "cal.ninety-degree-pushup":
            return ninetyDegreePushPlan
        case "cal.bent-arm-press":
            return bentArmPressPlan
        case "cal.5-dips":         return dipPlan
        case "cal.bench-dip":      return benchDipPlan
        case "cal.ring-dip":         return ringDipPlan
        case "ld.pistol-squat":      return pistolSquatPlan
        case "ld.shrimp-squat":      return shrimpSquatPlan
        case "ld.weighted-pistol":   return weightedPistolPlan
        case "ld.nordic-curl":       return nordicCurlPlan
        case let id where id.hasPrefix("ld."):
            return legBranchPlan(skillId: id)
        case "cal.plank-30":         return plankPlan
        case "cal.l-sit-10":         return lSitPlan
        case "cl.hollow-body-30":    return hollowBodyPlan
        case "cl.crunch", "cl.reverse-crunch", "cl.levitation-crunch", "cl.inverted-situp", "cl.decline-situp":
            return coreFlexionPlan(skillId: skillId)
        case "cl.bird-dog-plank", "cl.superman-plank", "cl.extended-plank":
            return plankControlPlan(skillId: skillId)
        case "cl.knee-ab-rollout", "cl.standing-ab-rollout":
            return rolloutPlan(skillId: skillId)
        case "cl.knee-raise", "cl.leg-raise", "cl.hanging-knee-raise", "cl.hanging-leg-raise", "cl.toes-to-bar":
            return coreRaisePlan(skillId: skillId)
        case "cl.semi-straddle-l-sit", "cl.straddle-l-sit", "cl.v-sit", "cl.vertical-l-sit":
            return lSitFamilyPlan(skillId: skillId)
        case "cl.tuck-front-lever", "cl.straddle-front-lever", "cl.full-front-lever":
            return frontLeverPlan(skillId: skillId)
        case "cl.german-hang", "cl.skin-the-cat", "cl.tuck-back-lever", "cl.straddle-back-lever", "cl.full-back-lever":
            return backLeverPlan(skillId: skillId)
        case "cl.three-sixty-pulls":
            return threeSixtyPullPlan
        case "cl.dragon-flag-hip-raise", "cl.dragon-flag":
            return dragonFlagPlan(skillId: skillId)
        case "hs.wall-plank":        return wallPlankPlan
        case "hs.wall-handstand-30": return wallHandstandPlan
        case "hs.freestanding-hs-30": return handstandPlan
        case "hs.headstand":         return headstandPlan
        case "hs.tuck-handstand":    return tuckHandstandPlan
        case "hs.tuck-press", "hs.straddle-press", "hs.press-to-handstand":
            return pressHandstandPlan(skillId: skillId)
        case "hs.wall-supported-oah": return wallSupportedOahPlan
        case "oah.one-arm-handstand-5s", "oah.full-one-arm-handstand":
            return oneArmHandstandPlan(skillId: skillId)
        default:                     return nil
        }
    }

    static func skillName(for skillId: String) -> String {
        switch skillId {
        case "pp.dead-hang": return "Dead Hang"
        case "pp.chin-up": return "Chin-Up"
        case "pp.strict-chin-up": return "Strict Chin-Up"
        case "pp.wide-pullup": return "Wide Pull-Up"
        case "pp.weighted-pullup": return "Weighted Pull-Up"
        case "pp.weighted-chin-up": return "Weighted Chin-Up"
        case "pp.explosive-pullup": return "Explosive Pull-Up"
        case "pp.clapping-pullup": return "Clapping Pull-Up"
        case "pp.archer-pullup": return "Archer Pull-Up"
        case "pp.oap-negative": return "One-Arm Pull-Up Negative"
        case "pp.heighted-chin-up": return "Heighted Chin-Up"
        case "pp.one-arm-pullup": return "One-Arm Pull-Up"
        case "pp.one-arm-chin-up": return "One-Arm Chin-Up"
        case "pp.l-sit-chin-up": return "L-Sit Chin-Up"
        case "pp.incline-row": return "Incline Row"
        case "pp.row": return "Inverted Row"
        case "pp.decline-row": return "Decline Row"
        case "pp.one-arm-row": return "One-Arm Row"
        case "pp.tuck-row": return "Tuck Front Lever Row"
        case "pp.straddle-row": return "Straddle Front Lever Row"
        case "pp.tuck-front-lever-pullup": return "Tuck Front Lever Pull-Up"
        case "pp.ring-muscle-up": return "Ring Muscle-Up"
        case "pp.strict-muscle-up": return "Strict Muscle-Up"
        case "cal.incline-pushup": return "Incline Push-Up"
        case "cal.decline-pushup": return "Decline Push-Up"
        case "cal.sphinx-pushup": return "Sphinx Push-Up"
        case "cal.triple-clap-pushup": return "Triple-Clap Push-Up"
        case "cal.clapping-handstand-pushup": return "Clapping Handstand Push-Up"
        case "cal.ninety-degree-pushup": return "90-Degree Push-Up"
        case "cal.bent-arm-press": return "Bent-Arm Press"
        case "cal.bench-dip": return "Bench Dip"
        case "pl.straddle-planche": return "Straddle Planche"
        case "pl.half-lay-planche": return "Half-Lay Planche"
        case "pl.bent-arm-planche": return "Bent-Arm Planche"
        case "cl.crunch": return "Crunch"
        case "cl.reverse-crunch": return "Reverse Crunch"
        case "cl.levitation-crunch": return "Levitation Crunch"
        case "cl.inverted-situp": return "Inverted Sit-Up"
        case "cl.decline-situp": return "Decline Sit-Up"
        case "cl.bird-dog-plank": return "Bird Dog Plank"
        case "cl.superman-plank": return "Superman Plank"
        case "cl.extended-plank": return "Extended Plank"
        case "cl.knee-ab-rollout": return "Knee Ab Rollout"
        case "cl.standing-ab-rollout": return "Standing Ab Rollout"
        case "cl.knee-raise": return "Knee Raise"
        case "cl.leg-raise": return "Leg Raise"
        case "cl.hanging-knee-raise": return "Hanging Knee Raise"
        case "cl.hanging-leg-raise": return "Hanging Leg Raise"
        case "cl.toes-to-bar": return "Toes-to-Bar"
        case "cl.semi-straddle-l-sit": return "Semi-Straddle L-Sit"
        case "cl.straddle-l-sit": return "Straddle L-Sit"
        case "cl.v-sit": return "V-Sit"
        case "cl.vertical-l-sit": return "Vertical L-Sit"
        case "cl.tuck-front-lever": return "Tuck Front Lever"
        case "cl.straddle-front-lever": return "Straddle Front Lever"
        case "cl.full-front-lever": return "Full Front Lever"
        case "cl.german-hang": return "German Hang"
        case "cl.skin-the-cat": return "Skin the Cat"
        case "cl.tuck-back-lever": return "Tuck Back Lever"
        case "cl.straddle-back-lever": return "Straddle Back Lever"
        case "cl.full-back-lever": return "Full Back Lever"
        case "cl.three-sixty-pulls": return "360 Ring Pull"
        case "cl.dragon-flag-hip-raise": return "Dragon Flag Hip Raise"
        case "cl.dragon-flag": return "Dragon Flag"
        default:
            return skillId
                .split(separator: ".").last
                .map { $0.replacingOccurrences(of: "-", with: " ").capitalized } ?? skillId
        }
    }


    // MARK: - 3b. Planche


    // MARK: - 4. Push-Up


    // MARK: - 7. Pistol Squat


    // MARK: - 8. Plank


    // MARK: - 11. Wall Handstand

}
