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
        case "cal.5-dips", "cal.bench-dip": return dipPlan
        case "cal.ring-dip":         return ringDipPlan
        case "ld.pistol-squat":      return pistolSquatPlan
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
        case "cl.german-hang", "cl.skin-the-cat", "cl.straddle-back-lever", "cl.full-back-lever":
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
        case let id where id.hasPrefix("co."):
            return conditioningPlan(skillId: id)
        default:                     return nil
        }
    }

    private static func skillName(for skillId: String) -> String {
        switch skillId {
        case "pp.dead-hang", "co.dead-hang-60": return "Dead Hang"
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
        case "cl.straddle-back-lever": return "Straddle Back Lever"
        case "cl.full-back-lever": return "Full Back Lever"
        case "cl.three-sixty-pulls": return "360 Pull"
        case "cl.dragon-flag-hip-raise": return "Dragon Flag Hip Raise"
        case "cl.dragon-flag": return "Dragon Flag"
        case "co.bw-farmer-carry": return "Bodyweight Farmer Carry"
        case "co.1.5x-farmer-carry": return "1.5x Bodyweight Farmer Carry"
        case "co.2x-farmer-carry": return "2x Bodyweight Farmer Carry"
        case "co.sled-push": return "Sled Push"
        case "co.400m-row": return "400m Row"
        case "co.mile-sub-7": return "Sub-7 Mile"
        case "co.5k-sub-22": return "Sub-22 5K"
        case "co.assault-bike-30": return "30-Calorie Assault Bike"
        default:
            return skillId
                .split(separator: ".").last
                .map { $0.replacingOccurrences(of: "-", with: " ").capitalized } ?? skillId
        }
    }

    private static func hangPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let seconds = skillId == "co.dead-hang-60" ? 60 : 30
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Foot-Assisted Hang", cues: ["Toes on a box", "Keep shoulders pain-free and controlled"]),
                TrainingExercise(name: "Active Scap Hang", cues: ["Long elbows", "Pull shoulders slightly away from ears"]),
                TrainingExercise(name: "Cluster Hang", cues: ["Accumulate time in clean chunks", "Step down before grip peels open"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 4, target: .hold(seconds: seconds), restSeconds: 90, notes: "Quiet body, wrapped grip, no elbow bend. Break into clusters until one clean hold is realistic."),
                TrainingPrescription(exerciseName: "Active Scap Hang", sets: 3, target: .hold(seconds: 12), restSeconds: 60, notes: "Use this as shoulder-control volume after the timed hold.")
            ],
            accessories: [
                TrainingExercise(name: "Scapular Pulls", cues: ["8-12 reps x 3", "Elbows stay locked"]),
                TrainingExercise(name: "Farmer Hold", cues: ["Heavy but still", "10-20s x 3"]),
                TrainingExercise(name: "Forearm Extensor Opens", cues: ["Open fingers against a band", "Balance gripping volume"])
            ]
        )
    }

    private static func verticalPullPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let isStrict = skillId.contains("strict")
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Active Bar Hang", cues: ["30s quiet hang", "Ribs tucked, shoulders controlled"]),
                TrainingExercise(name: "Band-Assisted \(name)", cues: ["Use just enough band", "Same top and bottom as the real rep"]),
                TrainingExercise(name: "Negative \(name)", cues: ["3-5s descent", "No drop through the bottom"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: isStrict ? 5 : 4, target: .repsRange(isStrict ? 3 : 5, isStrict ? 6 : 10), restSeconds: 120, notes: "Full extension to clear top. Stop with 1-2 clean reps in reserve."),
                TrainingPrescription(exerciseName: "Tempo \(name)", sets: 3, target: .tempo(reps: 4, eccentric: 3, hold: 1, concentric: 1), restSeconds: 90, notes: "Tempo work keeps range honest and builds control.")
            ],
            accessories: [
                TrainingExercise(name: "Scapular Pulls", cues: ["Straight arms", "8-12 x 3"]),
                TrainingExercise(name: "Inverted Row", cues: ["Chest to bar or rings", "10-12 x 3"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down", "20-40s x 3"])
            ]
        )
    }

    private static func weightedPullPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Strict Bodyweight Pull", cues: ["Own 5-8 clean reps first", "No kip or shortened bottom"]),
                TrainingExercise(name: "Light Vest Pull", cues: ["Small load jump", "Plate or vest stays quiet"]),
                TrainingExercise(name: "Weighted Negative", cues: ["Tiny load", "3-5s controlled lower"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 5, target: .repsRange(2, 5), restSeconds: 180, notes: "Heavy strength work. Add load only when every rep keeps full range."),
                TrainingPrescription(exerciseName: "Back-Off Bodyweight Pull", sets: 3, target: .repsRange(5, 8), restSeconds: 120, notes: "Keep the pattern and elbows happy after loaded work.")
            ],
            accessories: [
                TrainingExercise(name: "Weighted Hang", cues: ["10-20s x 3", "Start still before timing"]),
                TrainingExercise(name: "Chest-Supported Row", cues: ["8-12 x 3", "No body swing"]),
                TrainingExercise(name: "Hammer Curl", cues: ["8-12 x 2-3", "Slow lower for elbow tolerance"])
            ]
        )
    }

    private static func explosivePullingPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Fast Assisted Pull-Up", cues: ["Light band", "Same strict start"]),
                TrainingExercise(name: "Chest-to-Bar Pull-Up", cues: ["Pull to upper chest", "Lower under control"]),
                TrainingExercise(name: "Jumping Pull + Negative", cues: ["Jump to height", "Own the landing side"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 6, target: .repsRange(1, 3), restSeconds: 150, notes: "Power quality. End the set when height or catch quality drops."),
                TrainingPrescription(exerciseName: "Explosive Chest-to-Bar Pull-Up", sets: 4, target: .repsRange(2, 4), restSeconds: 120, notes: "Build launch height before release complexity.")
            ],
            accessories: [
                TrainingExercise(name: "Active Bar Hang", cues: ["Catch with active shoulders", "20-30s x 3"]),
                TrainingExercise(name: "Tempo Pull-Up", cues: ["3s lower", "3-5 reps x 3"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Keep lower body from kipping", "20-40s x 3"])
            ]
        )
    }

    private static func archerPullingPlan(skillId: String) -> SkillTrainingPlan {
        SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Archer Ring Row", cues: ["Working arm bends", "Guide arm stays long"]),
                TrainingExercise(name: "Band-Assisted Archer Pull-Up", cues: ["Finish chest near one hand", "Use the band to preserve range"]),
                TrainingExercise(name: "Typewriter Top Hold", cues: ["Shift side to side at the top", "Lower under control"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: "Archer Pull-Up", sets: 5, target: .repsRange(2, 4), restSeconds: 150, notes: "Train weaker side first and match the stronger side to it."),
                TrainingPrescription(exerciseName: "Archer Ring Row", sets: 3, target: .repsRange(6, 10), restSeconds: 90, notes: "Back-off volume with the same side-to-side path.")
            ],
            accessories: [
                TrainingExercise(name: "One-Arm Isometric", cues: ["Top or mid hold", "5-8s per side"]),
                TrainingExercise(name: "Scapular Pulls", cues: ["Straight arms", "8-12 x 3"]),
                TrainingExercise(name: "Side Plank", cues: ["Anti-rotation", "20-40s per side"])
            ]
        )
    }

    private static func soloArmPullPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let isNegative = skillId == "pp.oap-negative"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Assisted One-Arm Pull", cues: ["Free hand low on towel, band, or strap", "Reduce assistance gradually"]),
                TrainingExercise(name: "One-Arm Active Hang", cues: ["Shoulder packed", "Short pain-free holds"]),
                TrainingExercise(name: "Archer Pull-Up", cues: ["Shift load to one side", "Full bottom each rep"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: isNegative ? 5 : 6, target: isNegative ? .tempo(reps: 1, eccentric: 5, hold: 0, concentric: 0) : .repsRange(1, 2), restSeconds: 180, notes: "Very low volume. Stop on elbow pain, shoulder shrug, or uncontrolled rotation."),
                TrainingPrescription(exerciseName: "Assisted One-Arm Pull", sets: 4, target: .repsRange(2, 4), restSeconds: 150, notes: "Use assistance to make every inch deliberate.")
            ],
            accessories: [
                TrainingExercise(name: "One-Arm Isometric", cues: ["Top, middle, or low angle", "5s x 3 per side"]),
                TrainingExercise(name: "Hammer Curl", cues: ["Slow eccentric", "8-10 x 2"]),
                TrainingExercise(name: "Scapular Pulls", cues: ["Control before elbow bend", "8-12 x 3"])
            ]
        )
    }

    private static let lSitChinPlan = SkillTrainingPlan(
        skillId: "pp.l-sit-chin-up",
        regressions: [
            TrainingExercise(name: "Tuck Chin-Up", cues: ["Knees high", "Still hang before pulling"]),
            TrainingExercise(name: "Hanging Knee Raise", cues: ["Posterior pelvic tilt", "No swing"]),
            TrainingExercise(name: "One-Leg L Pull", cues: ["One leg straight", "Other tucked"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "L-Sit Chin-Up", sets: 5, target: .repsRange(2, 5), restSeconds: 150, notes: "Legs stay lifted through the bottom. Lower the leg difficulty before cutting pull range."),
            TrainingPrescription(exerciseName: "L-Sit Hold", sets: 4, target: .hold(seconds: 10), restSeconds: 90, notes: "Compression support volume for cleaner reps.")
        ],
        accessories: [
            TrainingExercise(name: "Pike Compression", cues: ["10 reps x 3", "Lift heels if possible"]),
            TrainingExercise(name: "Strict Chin-Up", cues: ["Keep pulling strength alive", "3-6 reps x 3"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down", "20-40s x 3"])
        ]
    )

    private static func rowFamilyPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let lever = skillId.contains("front-lever") || skillId.contains("tuck") || skillId.contains("straddle")
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "High Ring Row", cues: ["Raise handles", "Chest reaches rings"]),
                TrainingExercise(name: lever ? "Tuck Front Lever Hold" : "Bent-Knee Row", cues: [lever ? "Short lever first" : "Bend knees to reduce load", "Ribs down and shoulders active"]),
                TrainingExercise(name: "Top-Pause Row", cues: ["1-2s at top", "No hip sag"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 4, target: lever ? .repsRange(2, 5) : .repsRange(6, 12), restSeconds: lever ? 150 : 90, notes: lever ? "Keep the lever shape. Regress before the hips drop." : "Full reach at bottom, chest to implement at top."),
                TrainingPrescription(exerciseName: "Tempo Row", sets: 3, target: .tempo(reps: 6, eccentric: 3, hold: 1, concentric: 1), restSeconds: 75, notes: "Tempo exposes shoulder shrug and hip sag.")
            ],
            accessories: [
                TrainingExercise(name: "Active Bar Hang", cues: ["Shoulder control", "20-30s x 3"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Lever trunk shape", "20-40s x 3"]),
                TrainingExercise(name: "Face Pull", cues: ["Upper-back balance", "12-15 x 2-3"])
            ]
        )
    }

    private static func advancedMuscleUpPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let ring = skillId == "pp.ring-muscle-up"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: ring ? "False-Grip Ring Hang" : "High Strict Pull", cues: [ring ? "Wrists over rings" : "Pull toward lower chest", "Short quality sets"]),
                TrainingExercise(name: ring ? "Low-Ring Transition" : "Slow Transition Negative", cues: ["Elbows close", "Feet assist only as needed"]),
                TrainingExercise(name: ring ? "Ring Dip Negative" : "Straight-Bar Dip", cues: ["Own the press-out", "No shoulder collapse"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 6, target: .reps(1), restSeconds: 180, notes: "Fresh singles only. Use assistance before practicing chicken-wing or low catches."),
                TrainingPrescription(exerciseName: ring ? "Low-Ring Transition" : "Slow Transition Negative", sets: 4, target: .repsRange(2, 4), restSeconds: 120, notes: "Technique volume for the hardest part of the skill.")
            ],
            accessories: [
                TrainingExercise(name: ring ? "False-Grip Hang" : "Explosive Chest-to-Bar Pull-Up", cues: [ring ? "20-30s total" : "2-4 reps x 4", "Keep wrists and elbows happy"]),
                TrainingExercise(name: ring ? "Ring Support Hold (RTO)" : "Straight-Bar Dip", cues: ["Stable support", "10-20s or 5-8 reps"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["No hidden kip", "20-40s x 3"])
            ]
        )
    }

    // MARK: - 1. Pull-Up

    private static let pullUpPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "pp.pullup",
        regressions: [
            TrainingExercise(name: "Active Bar Hang", cues: [
                "Shoulders packed down, ribs tucked",
                "30s+ unbroken"
            ]),
            TrainingExercise(name: "Scapular Pulls", cues: [
                "Hang straight, pull shoulder blades down without bending elbows",
                "8-12 reps"
            ]),
            TrainingExercise(name: "Australian Row", cues: [
                "Body straight under bar",
                "Chest to bar at top, full extension at bottom"
            ]),
            TrainingExercise(name: "Negative Pull-Up", cues: [
                "Jump or step to top, lower 5+ seconds",
                "Stay tight throughout"
            ]),
            TrainingExercise(name: "Band-Assisted Pull-Up", cues: [
                "Use lightest band that lets you complete reps",
                "Drop band thickness over weeks"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Pull-Up AMRAP",
                sets: 4,
                target: .amrap,
                restSeconds: 120,
                notes: "Strict only. Stop the set when the next rep won't be clean."
            ),
            TrainingPrescription(
                exerciseName: "Tempo Pull-Up",
                sets: 3,
                target: .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1),
                restSeconds: 90,
                notes: "3-second descent, 1s hang, 1s pull. Builds the strict rep."
            )
        ],
        accessories: [
            TrainingExercise(name: "Lat Pulldown (if equipped)", cues: [
                "Heavy, 8-12 reps × 3"
            ]),
            TrainingExercise(name: "Inverted Row", cues: [
                "Volume horizontal pull, 10-12 × 3"
            ])
        ]
    )

    // MARK: - 2. Strict Pull-Up

    private static let strictPullUpPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "pp.strict-pullup",
        regressions: [
            TrainingExercise(name: "Pull-Up AMRAP", cues: [
                "5 strict bodyweight reps minimum before chasing strict-pullup"
            ]),
            TrainingExercise(name: "Tempo Pull-Up", cues: [
                "3-1-3 tempo",
                "Builds time-under-tension"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Strict Pull-Up",
                sets: 5,
                target: .reps(5),
                restSeconds: 120,
                notes: "No kip, no swing, full ROM"
            ),
            TrainingPrescription(
                exerciseName: "Pause Pull-Up (3s top)",
                sets: 3,
                target: .reps(3),
                restSeconds: 90,
                notes: "Hold 3s at top of every rep"
            )
        ],
        accessories: [
            TrainingExercise(name: "Backpack-Loaded Hang", cues: [
                "Add load via backpack, 30s × 3"
            ]),
            TrainingExercise(name: "Bent-Arm Hang", cues: [
                "Hold at top of pull-up for 5-10s × 5 sets"
            ]),
            TrainingExercise(name: "Banana Hold", cues: [
                "Hollow-line core, 60s × 3"
            ])
        ]
    )

    // MARK: - 3. Muscle-Up

    private static let muscleUpPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "pp.muscle-up",
        regressions: [
            TrainingExercise(name: "10 Strict Pull-Ups", cues: [
                "Foundation: must own this first"
            ]),
            TrainingExercise(name: "10 Strict Dips", cues: [
                "Catch position strength"
            ]),
            TrainingExercise(name: "False-Grip Hang", cues: [
                "Wrists over the bar, 30s+",
                "Builds the grip you'll need at transition"
            ]),
            TrainingExercise(name: "Chest-to-Bar Pull-Up", cues: [
                "Pull explosively until upper chest contacts the bar",
                "5 reps minimum"
            ]),
            TrainingExercise(name: "Russian Dip", cues: [
                "Lower into deep elbow-shelf position, press out",
                "Builds catch transition"
            ]),
            TrainingExercise(name: "Banded Muscle-Up", cues: [
                "Use heavy band for assistance, work the full motion"
            ]),
            TrainingExercise(name: "Jumping Muscle-Up (low bar)", cues: [
                "Bar at chest height, jump-pull-press through transition"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Muscle-Up Singles",
                sets: 5,
                target: .reps(1),
                restSeconds: 180,
                notes: "Skill — fresh attempts only, stop when form degrades"
            ),
            TrainingPrescription(
                exerciseName: "Explosive Chest-to-Bar Pull-Up",
                sets: 4,
                target: .reps(3),
                restSeconds: 120,
                notes: "Pull as high as possible — sternum to bar. Builds the launch."
            ),
            TrainingPrescription(
                exerciseName: "Ring Transitions (low / band-assisted)",
                sets: 3,
                target: .reps(3),
                restSeconds: 90,
                notes: "Drill the catch — slow and clean"
            )
        ],
        accessories: [
            TrainingExercise(name: "False-Grip Hang", cues: [
                "30s × 3",
                "Wrist conditioning"
            ]),
            TrainingExercise(name: "Close-Grip Push-Up", cues: [
                "Hands inside shoulders, lockout focus, 12-15 × 3"
            ]),
            TrainingExercise(name: "Banana Hold", cues: [
                "Body line through transition",
                "60s × 3"
            ])
        ]
    )

    // MARK: - 3b. Planche

    private static func armBalancePlan(skillId: String) -> SkillTrainingPlan {
        let isCrane = skillId == "hs.crane-pose"
        let isFlying = skillId == "hs.flying-crow"
        let isElbow = skillId == "hs.elbow-lever"
        let isOneArmElbow = skillId == "hs.one-arm-elbow-lever"
        let skillName: String = {
            switch skillId {
            case "hs.crane-pose": return "Crane Pose"
            case "hs.flying-crow": return "Flying Crow Hold"
            case "hs.elbow-lever": return "Elbow Lever Hold"
            case "hs.one-arm-elbow-lever": return "One-Arm Elbow Lever Hold"
            default: return "Crow Pose"
            }
        }()
        let mainSetNotes: String = {
            if isCrane {
                return "Count only straight-arm time. Return to crow when elbows rebend."
            }
            if isFlying {
                return "Support knee stays high on the arm while the back leg reaches long."
            }
            if isElbow || isOneArmElbow {
                return "Elbow shelf stays anchored; feet float by lean, not kick."
            }
            return "Knees high, hips lifted, feet float from control."
        }()

        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Wrist Prep Flow", cues: [
                    "Palm rocks, finger pulses, and gentle wrist circles",
                    "Use parallettes if wrist extension is the limiter"
                ]),
                TrainingExercise(name: isElbow || isOneArmElbow ? "Tuck Elbow Lever" : "One-Foot Crow Float", cues: [
                    isElbow || isOneArmElbow ? "Elbows anchored into lower abdomen" : "Lift one foot at a time",
                    "Lean until balance lifts the feet, do not jump"
                ]),
                TrainingExercise(name: isCrane ? "Crow-To-Crane Press" : (isFlying ? "Back-Leg Slide" : (isOneArmElbow ? "Two-Arm Elbow Lever Shift" : "Finger Pressure Rock")), cues: [
                    isCrane ? "Press toward straight arms without losing knee contact" : (isFlying ? "Slide one toe back before lifting it" : (isOneArmElbow ? "Make the free hand light before releasing" : "Small forward and backward pressure shifts")),
                    "Keep shoulders active and breathing steady"
                ])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: skillName,
                    sets: isOneArmElbow ? 8 : 6,
                    target: .hold(seconds: isFlying || isOneArmElbow ? 5 : 10),
                    restSeconds: isOneArmElbow ? 150 : 120,
                    notes: mainSetNotes
                ),
                TrainingPrescription(
                    exerciseName: isElbow || isOneArmElbow ? "Elbow Shelf Balance Drill" : "Crow Balance Drill",
                    sets: 4,
                    target: .hold(seconds: 12),
                    restSeconds: 90,
                    notes: "Back-off balance volume. Stop each set before wrist pressure gets noisy."
                )
            ],
            accessories: [
                TrainingExercise(name: "Scapular Push-Up Plus", cues: [
                    "Elbows locked",
                    "Round upper back without shrugging"
                ]),
                TrainingExercise(name: "Hollow Body Hold", cues: [
                    "Ribs down, pelvis tucked",
                    "20-40s × 3"
                ]),
                TrainingExercise(name: "Finger Pressure Rocks", cues: [
                    "Fingertips brake forward tip",
                    "Heel of hand shifts weight back"
                ])
            ]
        )
    }

    private static let pseudoPlanchePushupPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.pseudo-planche-pushup",
        regressions: [
            TrainingExercise(name: "Wrist Prep Flow", cues: [
                "Palm rocks, fist rocks, and gentle finger pulses",
                "Stop if wrist pain sharpens"
            ]),
            TrainingExercise(name: "Scapular Push-Up Plus", cues: [
                "Elbows locked",
                "Push floor away until upper back rounds"
            ]),
            TrainingExercise(name: "Planche Lean", cues: [
                "Shoulders past wrists",
                "Ribs down, glutes on, elbows locked"
            ]),
            TrainingExercise(name: "Feet-Elevated Planche Lean", cues: [
                "Feet on box, body near horizontal",
                "Keep protraction before adding more lean"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Pseudo-Planche Push-Up",
                sets: 4,
                target: .repsRange(3, 6),
                restSeconds: 120,
                notes: "Shoulders stay forward for every rep. Stop when lean disappears."
            ),
            TrainingPrescription(
                exerciseName: "Planche Lean Hold",
                sets: 5,
                target: .hold(seconds: 12),
                restSeconds: 120,
                notes: "Straight arms, protracted shoulders, posterior pelvic tilt."
            )
        ],
        accessories: [
            TrainingExercise(name: "Hollow Body Hold", cues: [
                "Ribs down, pelvis tucked",
                "30-45s × 3"
            ]),
            TrainingExercise(name: "Serratus Wall Slide", cues: [
                "Reach long at the top",
                "2-3 slow sets"
            ]),
            TrainingExercise(name: "Reverse Wrist Stretch", cues: [
                "Gentle pressure only",
                "30s each side"
            ])
        ]
    )

    private static let tuckPlanchePlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "pl.tuck-planche",
        regressions: [
            TrainingExercise(name: "Planche Lean Hold", cues: [
                "Shoulders past hands",
                "Elbows locked, scapulae protracted"
            ]),
            TrainingExercise(name: "Raised Planche Lean", cues: [
                "Feet on box",
                "Body near horizontal, hips not sagging"
            ]),
            TrainingExercise(name: "Crane One-Knee Float", cues: [
                "Lift one knee off the arm briefly",
                "Keep shoulders forward"
            ]),
            TrainingExercise(name: "Band-Assisted Tuck Planche", cues: [
                "Band supports hips",
                "Practice the same straight-arm shape"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Tuck Planche Attempts",
                sets: 6,
                target: .hold(seconds: 5),
                restSeconds: 150,
                notes: "Fresh short holds only. Knees float free; elbows stay locked."
            ),
            TrainingPrescription(
                exerciseName: "Planche Lean Hold",
                sets: 4,
                target: .hold(seconds: 20),
                restSeconds: 120,
                notes: "Fallback volume after attempts. Keep the exact shoulder position."
            )
        ],
        accessories: [
            TrainingExercise(name: "Scapular Push-Up Plus", cues: [
                "Straight elbows",
                "10-15 × 3"
            ]),
            TrainingExercise(name: "Tuck L-Sit", cues: [
                "Compress knees high",
                "10-20s × 4"
            ]),
            TrainingExercise(name: "Wrist Prep Flow", cues: [
                "5 minutes before planche work"
            ])
        ]
    )

    private static let fullPlanchePlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "pl.full-planche",
        regressions: [
            TrainingExercise(name: "Advanced Tuck Planche", cues: [
                "Open knees away from chest",
                "Same protraction as tuck"
            ]),
            TrainingExercise(name: "Straddle Planche Hold", cues: [
                "Wide legs, hips level",
                "Short clean holds"
            ]),
            TrainingExercise(name: "Half-Lay Planche Hold", cues: [
                "Narrow the straddle gradually",
                "No hip drop"
            ]),
            TrainingExercise(name: "Band-Assisted Full Planche", cues: [
                "Band at hips",
                "Rehearse the full straight line"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Full Planche Attempts",
                sets: 8,
                target: .hold(seconds: 3),
                restSeconds: 180,
                notes: "Only fresh proof holds. Stop attempts when elbows soften or hips drop."
            ),
            TrainingPrescription(
                exerciseName: "Band-Assisted Full Planche",
                sets: 4,
                target: .hold(seconds: 8),
                restSeconds: 150,
                notes: "Use just enough assistance to keep hollow line and locked elbows."
            ),
            TrainingPrescription(
                exerciseName: "Straddle Planche Volume Hold",
                sets: 4,
                target: .hold(seconds: 10),
                restSeconds: 150,
                notes: "Back-off work at the hardest lever you can keep clean."
            )
        ],
        accessories: [
            TrainingExercise(name: "Planche Lean Hold", cues: [
                "Heavy straight-arm lean",
                "10-20s × 4"
            ]),
            TrainingExercise(name: "Pseudo-Planche Push-Up", cues: [
                "3-6 clean reps × 3",
                "Shoulders stay forward"
            ]),
            TrainingExercise(name: "Hollow Body Hold", cues: [
                "45-60s × 3",
                "Ribs down, glutes tight"
            ])
        ]
    )

    private static func intermediatePlanchePlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let isHalfLay = skillId == "pl.half-lay-planche"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Planche Lean Hold", cues: ["Shoulders forward", "Elbows locked, scapulae protracted"]),
                TrainingExercise(name: isHalfLay ? "Straddle Planche Hold" : "Advanced Tuck Planche", cues: [isHalfLay ? "Narrow slowly from straddle" : "Open knees away from chest", "Keep hips level"]),
                TrainingExercise(name: "Band-Assisted \(name)", cues: ["Band at hips", "Same straight-arm line"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 6, target: .hold(seconds: isHalfLay ? 4 : 6), restSeconds: 180, notes: "Short proof holds. End the set when elbows soften, hips drop, or protraction disappears."),
                TrainingPrescription(exerciseName: isHalfLay ? "Narrow-Straddle Planche Hold" : "Advanced Tuck Planche", sets: 4, target: .hold(seconds: 8), restSeconds: 150, notes: "Back-off volume at the hardest lever that stays clean.")
            ],
            accessories: [
                TrainingExercise(name: "Planche Lean Hold", cues: ["10-20s x 4", "Measure shoulder travel"]),
                TrainingExercise(name: "Pseudo-Planche Push-Up", cues: ["3-6 reps x 3", "Lean survives the rep"]),
                TrainingExercise(name: "Wrist Prep Flow", cues: ["Before every session", "Use parallettes if needed"])
            ]
        )
    }

    private static let bentArmPlanchePlan = SkillTrainingPlan(
        skillId: "pl.bent-arm-planche",
        regressions: [
            TrainingExercise(name: "Elbow Lever", cues: ["Find the horizontal body line", "Do not confuse elbow shelf with final standard"]),
            TrainingExercise(name: "Planche Lean Push-Up", cues: ["Shoulders forward", "Elbows bend back"]),
            TrainingExercise(name: "Band-Assisted Bent-Arm Hold", cues: ["Band supports hips", "Chest stays forward"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "Bent-Arm Planche Hold", sets: 6, target: .hold(seconds: 5), restSeconds: 150, notes: "Body horizontal, no elbow shelf wedged into the hips. Use very short high-quality attempts."),
            TrainingPrescription(exerciseName: "Planche Lean Negative", sets: 4, target: .tempo(reps: 2, eccentric: 4, hold: 1, concentric: 0), restSeconds: 120, notes: "Step down before collapse, then reset.")
        ],
        accessories: [
            TrainingExercise(name: "Pseudo-Planche Push-Up", cues: ["3-6 reps x 3", "Lean stays forward"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down, glutes tight", "30-45s x 3"]),
            TrainingExercise(name: "Wrist Prep Flow", cues: ["Palms and fingers ready", "2-4 minutes"])
        ]
    )

    // MARK: - 4. Push-Up

    private static let pushUpPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.pushup",
        regressions: [
            TrainingExercise(name: "Wall Push-Up", cues: [
                "Hands on wall, body angled, push",
                "12+ reps clean"
            ]),
            TrainingExercise(name: "Incline Push-Up (bench/box)", cues: [
                "Hands on bench, build to lower angles"
            ]),
            TrainingExercise(name: "Knee Push-Up", cues: [
                "Knees down, full body line",
                "12+ clean reps"
            ]),
            TrainingExercise(name: "Negative Push-Up", cues: [
                "5s descent, knees down to recover"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Push-Up AMRAP",
                sets: 4,
                target: .amrap,
                restSeconds: 90,
                notes: "Push form to failure, no half-reps"
            ),
            TrainingPrescription(
                exerciseName: "Backpack Push-Up",
                sets: 4,
                target: .reps(8),
                restSeconds: 90,
                notes: "Load 5-10kg in a backpack — keep body line tight"
            ),
            TrainingPrescription(
                exerciseName: "Tempo Push-Up",
                sets: 3,
                target: .tempo(reps: 8, eccentric: 3, hold: 1, concentric: 1),
                restSeconds: 60,
                notes: "Slow eccentric builds the strict rep"
            )
        ],
        accessories: [
            TrainingExercise(name: "Hollow Body Hold", cues: [
                "60-90s × 3 — locks the body line"
            ]),
            TrainingExercise(name: "Pseudo-Planche Lean", cues: [
                "Hands by hips, lean forward, 20s × 5"
            ]),
            TrainingExercise(name: "Knuckle Push-Up", cues: [
                "Wrist conditioning, 8-10 × 3"
            ])
        ]
    )

    private static func pushUpVariantPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let decline = skillId == "cal.decline-pushup"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: decline ? "Push-Up" : "Wall Push-Up", cues: [decline ? "Own floor reps first" : "Same plank line", "Full controlled range"]),
                TrainingExercise(name: decline ? "Low Decline Push-Up" : "Higher Incline Push-Up", cues: [decline ? "Small foot elevation" : "Raise hands until depth is clean", "No hip sag"]),
                TrainingExercise(name: "Tempo Push-Up", cues: ["3s lower", "Pause without collapsing"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 4, target: .repsRange(6, 12), restSeconds: 90, notes: "Use the angle that keeps full range and one head-to-heel line."),
                TrainingPrescription(exerciseName: "Tempo \(name)", sets: 3, target: .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1), restSeconds: 75, notes: "Tempo exposes depth, elbow flare, and trunk leaks.")
            ],
            accessories: [
                TrainingExercise(name: "Hollow Body Hold", cues: ["Moving plank line", "30-45s x 3"]),
                TrainingExercise(name: "Scapular Push-Up Plus", cues: ["Straight elbows", "10-15 x 3"]),
                TrainingExercise(name: "Inverted Row", cues: ["Balance pressing volume", "8-12 x 3"])
            ]
        )
    }

    private static func closeGripPushPlan(skillId: String) -> SkillTrainingPlan {
        let isSphinx = skillId == "cal.sphinx-pushup"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: isSphinx ? "Forearm Plank" : "Incline Push-Up (bench/box)", cues: [
                    isSphinx ? "Ribs down, glutes on" : "Close hands, full depth, no elbow flare"
                ]),
                TrainingExercise(name: isSphinx ? "Partial Sphinx Press" : "Negative Push-Up", cues: [
                    "3-5s lower through close-grip path",
                    "Reset from knees if needed"
                ])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: isSphinx ? "Sphinx Push-Up" : "Close-Grip Push-Up",
                    sets: 4,
                    target: isSphinx ? .repsRange(4, 8) : .repsRange(6, 12),
                    restSeconds: 90,
                    notes: isSphinx ? "Press from forearms to hands without piking the hips." : "Hands under sternum, elbows track back, full lockout"
                ),
                TrainingPrescription(
                    exerciseName: isSphinx ? "Tempo Sphinx Push-Up" : "Tempo Push-Up",
                    sets: 3,
                    target: .tempo(reps: 6, eccentric: 3, hold: 1, concentric: 1),
                    restSeconds: 75,
                    notes: "Use close hand placement; stop before hips pike"
                )
            ],
            accessories: [
                TrainingExercise(name: "Tricep Extension (band or DB)", cues: [
                    "8-12 × 3, controlled elbows"
                ]),
                TrainingExercise(name: "Scapular Push-Up", cues: [
                    "Straight arms, spread shoulder blades, 10-15 × 3"
                ]),
                TrainingExercise(name: "Hollow Body Hold", cues: [
                    "30-60s × 3 for body line"
                ])
            ]
        )
    }

    private static func pikePushPlan(skillId: String) -> SkillTrainingPlan {
        let isElevated = skillId == "cal.elevated-pike-pushup"
        let isFloating = skillId == "cal.floating-pike-pushup"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Pike Hold (hips high)", cues: [
                    "Hips stacked, shoulders active, 20-30s"
                ]),
                TrainingExercise(name: "Partial Pike Push-Up", cues: [
                    "Small range, tripod head path",
                    "Add depth only when clean"
                ]),
                TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: [
                    "Line drill, ribs tucked, shoulders tall"
                ])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: isFloating ? "Floating Pike Push-Up" : (isElevated ? "Elevated Pike Push-Up" : "Pike Push-Up"),
                    sets: isFloating ? 5 : 4,
                    target: isFloating ? .repsRange(2, 5) : .repsRange(4, 10),
                    restSeconds: isFloating ? 150 : 120,
                    notes: "Head travels between hands; press up, not backward"
                ),
                TrainingPrescription(
                    exerciseName: isElevated ? "Pike Push-Up" : "Tempo Pike Push-Up",
                    sets: 3,
                    target: .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1),
                    restSeconds: 90,
                    notes: "Slow lower exposes elbow flare and lost hip height"
                )
            ],
            accessories: [
                TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: [
                    "20-40s × 3, shoulders elevated"
                ]),
                TrainingExercise(name: "Hollow Body Hold", cues: [
                    "Ribs down for HSPU line"
                ]),
                TrainingExercise(name: "Wrist Conditioning", cues: [
                    "Circles, pulses, palm lifts before pressing"
                ])
            ]
        )
    }

    private static let handstandPushPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.handstand-pushup",
        regressions: [
            TrainingExercise(name: "Elevated Pike Push-Up", cues: [
                "Own 8-10 clean reps first",
                "Head travels into tripod"
            ]),
            TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: [
                "30-60s line hold",
                "Ribs down, shoulders tall"
            ]),
            TrainingExercise(name: "Wall HSPU Negative", cues: [
                "3-5s lower to pad",
                "No head crash"
            ]),
            TrainingExercise(name: "Partial ROM HSPU", cues: [
                "Use pads, remove height slowly"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Wall Handstand Push-Up",
                sets: 5,
                target: .repsRange(1, 5),
                restSeconds: 150,
                notes: "Strict only. Head touches lightly; full lockout."
            ),
            TrainingPrescription(
                exerciseName: "Wall HSPU Negative",
                sets: 4,
                target: .tempo(reps: 2, eccentric: 5, hold: 0, concentric: 0),
                restSeconds: 120,
                notes: "Come down safely after each negative"
            )
        ],
        accessories: [
            TrainingExercise(name: "Pike Push-Up", cues: [
                "Volume patterning, 6-10 × 3"
            ]),
            TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: [
                "Line and shoulder elevation"
            ]),
            TrainingExercise(name: "Wrist Conditioning", cues: [
                "Daily prep before inverted pressing"
            ])
        ]
    )

    private static let clappingHandstandPushPlan = SkillTrainingPlan(
        skillId: "cal.clapping-handstand-pushup",
        regressions: [
            TrainingExercise(name: "Strict Wall HSPU", cues: ["Stable reps first", "No head bounce"]),
            TrainingExercise(name: "Explosive Pike Push-Up", cues: ["Hands may get light", "Soft catch"]),
            TrainingExercise(name: "Partial ROM Power HSPU", cues: ["Use pads", "Same handstand line"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "Clapping Handstand Push-Up", sets: 6, target: .reps(1), restSeconds: 180, notes: "Release skill. Singles only until launch and catch are boringly controlled."),
            TrainingPrescription(exerciseName: "Handstand Pop-Off", sets: 4, target: .repsRange(1, 3), restSeconds: 150, notes: "Pop both hands lightly, catch with soft elbows, then push tall.")
        ],
        accessories: [
            TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: ["Line under fatigue", "20-40s x 3"]),
            TrainingExercise(name: "Pike Push-Up", cues: ["Strict volume", "5-8 x 3"]),
            TrainingExercise(name: "Wrist Conditioning", cues: ["Before release work", "No rushed catches"])
        ]
    )

    private static let ninetyDegreePushPlan = SkillTrainingPlan(
        skillId: "cal.ninety-degree-pushup",
        regressions: [
            TrainingExercise(name: "Deep HSPU Negative", cues: ["Lean forward", "Step down before collapse"]),
            TrainingExercise(name: "Bent-Arm Planche Hold", cues: ["Horizontal bottom shape", "Short holds"]),
            TrainingExercise(name: "Wall-Assisted 90-Degree Negative", cues: ["Control line", "No kick back up"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "90-Degree Push-Up", sets: 6, target: .reps(1), restSeconds: 180, notes: "Count only reps that pass through a clear horizontal bent-arm line and press back without a kick."),
            TrainingPrescription(exerciseName: "90-Degree Negative", sets: 4, target: .tempo(reps: 1, eccentric: 5, hold: 1, concentric: 0), restSeconds: 150, notes: "Negatives build the path without hiding the bottom.")
        ],
        accessories: [
            TrainingExercise(name: "Bent-Arm Planche Hold", cues: ["3-6s x 4", "No hip shelf"]),
            TrainingExercise(name: "Handstand Push-Up", cues: ["Strict strength", "1-4 reps x 3"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["One-piece line", "30-45s x 3"])
        ]
    )

    private static let bentArmPressPlan = SkillTrainingPlan(
        skillId: "cal.bent-arm-press",
        regressions: [
            TrainingExercise(name: "Tripod Press Negative", cues: ["Lower from handstand slowly", "Hands carry weight"]),
            TrainingExercise(name: "Wall-Assisted Press", cues: ["Wall is a line guide", "No leg jump"]),
            TrainingExercise(name: "Tuck Press Drill", cues: ["Hips rise before legs", "Open late"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "Bent-Arm Press", sets: 6, target: .repsRange(1, 2), restSeconds: 150, notes: "Float hips and press. A kick-up or neck-loaded headstand jump does not count."),
            TrainingPrescription(exerciseName: "Tripod Press Negative", sets: 4, target: .tempo(reps: 2, eccentric: 4, hold: 1, concentric: 0), restSeconds: 120, notes: "Control the descent so the positive has a real path to learn.")
        ],
        accessories: [
            TrainingExercise(name: "Pike Compression", cues: ["10 reps x 3", "Active fold"]),
            TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: ["Finish line", "20-40s x 3"]),
            TrainingExercise(name: "Wrist Conditioning", cues: ["Press prep", "2-4 minutes"])
        ]
    )

    private static func planchePushPlan(skillId: String) -> SkillTrainingPlan {
        let isTuck = skillId == "cal.tuck-planche-pushup"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Pseudo-Planche Lean", cues: [
                    "Shoulders forward of wrists, protract hard",
                    "10-20s holds"
                ]),
                TrainingExercise(name: "Incline Pseudo-Planche Push-Up", cues: [
                    "Hands elevated, keep forward lean"
                ]),
                TrainingExercise(name: "Planche Lean Negative", cues: [
                    "Slow lower without drifting back"
                ])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: isTuck ? "Tuck Planche Push-Up" : "Pseudo-Planche Push-Up",
                    sets: isTuck ? 5 : 4,
                    target: isTuck ? .repsRange(1, 3) : .repsRange(3, 8),
                    restSeconds: isTuck ? 180 : 120,
                    notes: "Keep the same lean through the whole rep"
                ),
                TrainingPrescription(
                    exerciseName: "Pseudo-Planche Lean",
                    sets: 5,
                    target: .hold(seconds: 15),
                    restSeconds: 60,
                    notes: "Straight arms, scapulae protracted, wrists warmed"
                )
            ],
            accessories: [
                TrainingExercise(name: "Scapular Push-Up", cues: [
                    "Straight-arm protraction strength"
                ]),
                TrainingExercise(name: "Hollow Body Hold", cues: [
                    "Ribs down, glutes tight"
                ]),
                TrainingExercise(name: "Wrist Conditioning", cues: [
                    "Progress lean only after wrists feel ready"
                ])
            ]
        )
    }

    private static func unilateralPushPlan(skillId: String) -> SkillTrainingPlan {
        let isOneArm = skillId == "cal.one-arm-pushup"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Incline Archer Push-Up", cues: [
                    "Full depth, support arm light"
                ]),
                TrainingExercise(name: "Typewriter Push-Up", cues: [
                    "Shift side to side under control"
                ]),
                TrainingExercise(name: "One-Arm Push-Up Negative", cues: [
                    "3-5s lower, quiet hips"
                ])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: isOneArm ? "One-Arm Push-Up" : "Archer Push-Up",
                    sets: isOneArm ? 6 : 4,
                    target: isOneArm ? .repsRange(1, 3) : .repsRange(3, 8),
                    restSeconds: isOneArm ? 150 : 120,
                    notes: "Train weaker side first; full depth beats ugly reps"
                ),
                TrainingPrescription(
                    exerciseName: isOneArm ? "Incline One-Arm Push-Up" : "Archer Push-Up",
                    sets: 3,
                    target: .repsRange(4, 8),
                    restSeconds: 90,
                    notes: "Use a height where torso rotation stays quiet"
                )
            ],
            accessories: [
                TrainingExercise(name: "One-Arm Plank", cues: [
                    "Anti-rotation, 15-30s per side"
                ]),
                TrainingExercise(name: "Weighted Push-Up", cues: [
                    "Strength base, 5-8 × 3"
                ]),
                TrainingExercise(name: "Inverted Row", cues: [
                    "Balance pressing volume with pulling"
                ])
            ]
        )
    }

    private static func explosivePushPlan(skillId: String) -> SkillTrainingPlan {
        let isClap = skillId == "cal.clapping-pushup"
        let isTriple = skillId == "cal.triple-clap-pushup"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Incline Explosive Push-Up", cues: [
                    "Hands leave surface, soft catch"
                ]),
                TrainingExercise(name: "Fast Push-Up", cues: [
                    "No airtime yet, just max intent"
                ]),
                TrainingExercise(name: "Hand-Release Push-Up", cues: [
                    "Reset plank each rep"
                ])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: isTriple ? "Triple-Clap Push-Up" : (isClap ? "Clapping Push-Up" : "Explosive Push-Up"),
                    sets: 5,
                    target: isTriple ? .repsRange(1, 3) : .repsRange(3, 5),
                    restSeconds: isTriple ? 150 : 120,
                    notes: "Power only. Stop when airtime or landing quality drops."
                ),
                TrainingPrescription(
                    exerciseName: "Tempo Push-Up",
                    sets: 3,
                    target: .tempo(reps: 5, eccentric: 2, hold: 1, concentric: 1),
                    restSeconds: 90,
                    notes: "Strength base for a cleaner launch"
                )
            ],
            accessories: [
                TrainingExercise(name: "Push-Up AMRAP", cues: [
                    "Strict strength volume on separate sets"
                ]),
                TrainingExercise(name: "Scapular Push-Up", cues: [
                    "Landing control, 10-15 × 3"
                ]),
                TrainingExercise(name: "Hollow Body Hold", cues: [
                    "Body line during launch"
                ])
            ]
        )
    }

    // MARK: - 5. Dip

    private static let dipPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.5-dips",
        regressions: [
            TrainingExercise(name: "Bench Tricep Dip", cues: [
                "Hands on bench behind you, push out of bottom"
            ]),
            TrainingExercise(name: "Negative Dip", cues: [
                "Lower 5s, step or jump to recover"
            ]),
            TrainingExercise(name: "Band-Assisted Dip", cues: [
                "Band looped on bars, knees on band"
            ]),
            TrainingExercise(name: "Bar Support Hold", cues: [
                "30s × 3, builds the lockout"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Dip AMRAP",
                sets: 5,
                target: .amrap,
                restSeconds: 90,
                notes: "Strict, full ROM, no shrugging"
            ),
            TrainingPrescription(
                exerciseName: "Tempo Dip",
                sets: 3,
                target: .tempo(reps: 6, eccentric: 3, hold: 1, concentric: 1),
                restSeconds: 75,
                notes: "Control the descent — 3s down, 1s pause, 1s press"
            )
        ],
        accessories: [
            TrainingExercise(name: "Tricep Extension (band or DB)", cues: [
                "Heavy, 8-10 × 3"
            ]),
            TrainingExercise(name: "Front-Leaning Ring Support", cues: [
                "Lean forward in support, 15s × 3"
            ]),
            TrainingExercise(name: "Pseudo-Planche Lean", cues: [
                "20s × 3"
            ])
        ]
    )

    // MARK: - 6. Ring Dip

    private static let ringDipPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.ring-dip",
        regressions: [
            TrainingExercise(name: "Bar Dip — 5 Strict", cues: [
                "Foundation"
            ]),
            TrainingExercise(name: "Ring Support Hold (RTO)", cues: [
                "Rings turned out, 30s × 3"
            ]),
            TrainingExercise(name: "Ring Tucks", cues: [
                "From support, tuck legs to chest, 8-10 × 3"
            ]),
            TrainingExercise(name: "Top-of-Dip Lockout Hold", cues: [
                "Hold at top of ring dip 5-10s × 5"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Strict Ring Dip",
                sets: 5,
                target: .reps(3),
                restSeconds: 120,
                notes: "Rings stable — no swinging"
            ),
            TrainingPrescription(
                exerciseName: "RTO Tempo Ring Dip",
                sets: 3,
                target: .tempo(reps: 3, eccentric: 3, hold: 1, concentric: 1),
                restSeconds: 90,
                notes: "Rings turned out throughout"
            )
        ],
        accessories: [
            TrainingExercise(name: "Front-Leaning Ring Support", cues: [
                "20s × 5"
            ]),
            TrainingExercise(name: "Ring Push-Up", cues: [
                "10-12 × 3"
            ]),
            TrainingExercise(name: "Pseudo-Planche Lean", cues: [
                "20s × 3"
            ])
        ]
    )

    // MARK: - 7. Pistol Squat

    private static func legBranchPlan(skillId: String) -> SkillTrainingPlan {
        let isWeighted = skillId.contains("weighted")
        let isHold = skillId == "ld.deep-squat"
        let isPower = skillId == "ld.box-jump" || skillId == "ld.jumping-squat" || skillId == "ld.floor-to-ceiling-squat"
        let isNordic = skillId == "ld.nordic-hip-hinge" || skillId == "ld.advancing-nordic-curl" || skillId == "ld.nordic-curl"
        let isAccessory = skillId == "ld.fire-hydrant" || skillId == "ld.flying-kickback"

        let skillName: String = {
            switch skillId {
            case "ld.goblet-20": return "Goblet Squat"
            case "ld.step-up": return "Step-Up"
            case "ld.deep-squat": return "Deep Squat Hold"
            case "ld.glute-bridge": return "Glute Bridge"
            case "ld.calf-raise": return "Calf Raise"
            case "ld.split-squat": return "Split Squat"
            case "ld.bulgarian-split-squat": return "Bulgarian Split Squat"
            case "ld.weighted-split-squat": return "Weighted Split Squat"
            case "ld.weighted-bss": return "Weighted Bulgarian Split Squat"
            case "ld.shrimp-squat": return "Shrimp Squat"
            case "ld.weighted-pistol": return "Weighted Pistol Squat"
            case "ld.weighted-sl-calf": return "Weighted Single-Leg Calf Raise"
            case "ld.box-jump": return "Box Jump"
            case "ld.jumping-squat": return "Jumping Squat"
            case "ld.fire-hydrant": return "Fire Hydrant"
            case "ld.single-leg-glute-bridge": return "Single-Leg Glute Bridge"
            case "ld.flying-kickback": return "Flying Kickback"
            case "ld.leg-extensions": return "Bodyweight Leg Extension"
            case "ld.sissy-squat": return "Sissy Squat"
            case "ld.nordic-hip-hinge": return "Nordic Hip Hinge"
            case "ld.advancing-nordic-curl": return "Advanced Nordic Hip Hinge"
            case "ld.nordic-curl": return "Nordic Curl"
            case "ld.floor-to-ceiling-squat": return "Floor to Ceiling Squat"
            default: return "Leg Skill"
            }
        }()

        let regressions: [TrainingExercise] = {
            switch skillId {
            case "ld.goblet-20":
                return [
                    TrainingExercise(name: "Box Squat", cues: ["Pause on a box without rocking", "Lower the box as control improves"]),
                    TrainingExercise(name: "Counterbalance Squat", cues: ["Hold a light plate forward", "Feet flat, knees track toes"]),
                    TrainingExercise(name: "Tempo Bodyweight Squat", cues: ["3s down, 1s pause", "No knee cave"])
                ]
            case "ld.step-up":
                return [
                    TrainingExercise(name: "Low Step-Up", cues: ["Whole foot on the step", "No push-off from the floor leg"]),
                    TrainingExercise(name: "Hand-Supported Step-Up", cues: ["Light wall touch only", "Lead leg does the work"]),
                    TrainingExercise(name: "Eccentric Step-Down", cues: ["Lower slowly from the box", "Knee tracks over toes"])
                ]
            case "ld.deep-squat":
                return [
                    TrainingExercise(name: "Heel-Elevated Squat Hold", cues: ["Small wedge under heels", "Reduce elevation over time"]),
                    TrainingExercise(name: "Counterbalance Squat Hold", cues: ["Light weight forward", "Breathe in the bottom"]),
                    TrainingExercise(name: "Squat Pry", cues: ["Gentle side-to-side shifts", "No sharp knee or hip pain"])
                ]
            case "ld.glute-bridge", "ld.single-leg-glute-bridge":
                return [
                    TrainingExercise(name: "Short-Lever Bridge", cues: ["Heels closer to hips", "Ribs down before lifting"]),
                    TrainingExercise(name: "Bridge Top Hold", cues: ["3-5s glute squeeze", "No lumbar arch"]),
                    TrainingExercise(name: "Marching Bridge", cues: ["Alternate feet briefly", "Pelvis stays level"])
                ]
            case "ld.calf-raise", "ld.weighted-sl-calf":
                return [
                    TrainingExercise(name: "Assisted Calf Raise", cues: ["Use wall balance", "Full stretch to high top"]),
                    TrainingExercise(name: "Two-Up One-Down", cues: ["Rise with both feet", "Lower slowly on one side"]),
                    TrainingExercise(name: "Tempo Calf Raise", cues: ["2s rise, 1s pause, 3s lower", "Ankle stays vertical"])
                ]
            case "ld.split-squat", "ld.bulgarian-split-squat", "ld.weighted-split-squat", "ld.weighted-bss":
                return [
                    TrainingExercise(name: "Supported Split Squat", cues: ["Light hand support", "Front foot rooted"]),
                    TrainingExercise(name: "Short-Range Split Squat", cues: ["Pain-free depth first", "Add range slowly"]),
                    TrainingExercise(name: "Paused Split Squat", cues: ["1-2s bottom pause", "Rear leg stays quiet"])
                ]
            case "ld.shrimp-squat", "ld.weighted-pistol":
                return [
                    TrainingExercise(name: "Assisted Single-Leg Squat", cues: ["Use rail or strap lightly", "Working heel stays down"]),
                    TrainingExercise(name: "Box Single-Leg Squat", cues: ["Sit to a target", "Pause before standing"]),
                    TrainingExercise(name: "Counterweight Single-Leg Squat", cues: ["Light load held forward", "Control beats depth"])
                ]
            case "ld.box-jump", "ld.jumping-squat", "ld.floor-to-ceiling-squat":
                return [
                    TrainingExercise(name: "Snap-Down Landing", cues: ["Land softly in quarter squat", "Knees track toes"]),
                    TrainingExercise(name: "Squat To Calf Raise", cues: ["Triple extension rehearsal", "Quiet feet"]),
                    TrainingExercise(name: "Low Jump Target", cues: ["Small jump, perfect landing", "Stop on noisy reps"])
                ]
            case "ld.fire-hydrant", "ld.flying-kickback":
                return [
                    TrainingExercise(name: "Quadruped Brace", cues: ["Hands under shoulders", "Ribs down, pelvis square"]),
                    TrainingExercise(name: "Short-Range Hip Rep", cues: ["Move only where hips stay quiet", "Pause at top"]),
                    TrainingExercise(name: "Forearm-Supported Rep", cues: ["Use forearms if wrists complain", "No low-back swing"])
                ]
            case "ld.leg-extensions", "ld.sissy-squat":
                return [
                    TrainingExercise(name: "Supported Quad Lean", cues: ["Hold a rack or pole", "Hips stay open"]),
                    TrainingExercise(name: "Partial Reverse Nordic", cues: ["Short pain-free range", "Slow eccentric"]),
                    TrainingExercise(name: "Heel-Elevated Tall Squat", cues: ["Quads loaded", "No hip hinge escape"])
                ]
            case "ld.nordic-hip-hinge", "ld.advancing-nordic-curl", "ld.nordic-curl":
                return [
                    TrainingExercise(name: "Band-Assisted Nordic", cues: ["Band reduces hardest range", "Same body line"]),
                    TrainingExercise(name: "Elevated Hand Catch", cues: ["Catch before control fails", "Lower the target over time"]),
                    TrainingExercise(name: "Short-Range Eccentric", cues: ["Own every inch", "No sudden drop"])
                ]
            default:
                return [
                    TrainingExercise(name: "Assisted Range", cues: ["Use support to keep alignment", "Progress depth slowly"]),
                    TrainingExercise(name: "Tempo Rep", cues: ["Slow eccentric", "Pause before returning"]),
                    TrainingExercise(name: "Mobility Prep", cues: ["Warm ankles, hips, and knees", "No sharp pain"])
                ]
            }
        }()

        let mainTarget: PrescriptionTarget = {
            if isHold { return .hold(seconds: 60) }
            if isPower { return .repsRange(2, 5) }
            if isNordic { return .repsRange(3, 6) }
            if isAccessory { return .repsRange(10, 15) }
            if isWeighted { return .repsRange(5, 8) }
            return .repsRange(6, 12)
        }()

        let mainNotes: String = {
            if isHold { return "Count only foot-flat, pain-free time with steady breathing." }
            if isPower { return "Power quality only. Stop when jump height or landing shape fades." }
            if isNordic { return "Low volume at first. Hamstrings adapt better to gradual exposure than heroic drops." }
            if isAccessory { return "Move from the hip while ribs and pelvis stay quiet." }
            if isWeighted { return "Load must not change depth, balance, or knee tracking." }
            return "Use the deepest controlled range. Leave 1-3 clean reps in reserve."
        }()

        return SkillTrainingPlan(
            skillId: skillId,
            regressions: regressions,
            mainSets: [
                TrainingPrescription(
                    exerciseName: skillName,
                    sets: isPower ? 5 : (isNordic ? 3 : 4),
                    target: mainTarget,
                    restSeconds: isPower || isNordic ? 150 : 90,
                    notes: mainNotes
                ),
                TrainingPrescription(
                    exerciseName: isHold ? "Deep Squat Pry" : (isPower ? "Landing Practice" : "Tempo \(skillName)"),
                    sets: 3,
                    target: isHold ? .hold(seconds: 30) : (isPower ? .repsRange(3, 5) : .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1)),
                    restSeconds: isPower ? 120 : 75,
                    notes: isPower ? "Keep contacts quiet and aligned." : "Tempo exposes compensation before volume hides it."
                )
            ],
            accessories: [
                TrainingExercise(name: "Ankle And Hip Prep", cues: [
                    "2-4 minutes before leg work",
                    "Use range that improves the main skill"
                ]),
                TrainingExercise(name: "Single-Leg Balance", cues: [
                    "Tripod foot",
                    "Knee tracks over toes"
                ]),
                TrainingExercise(name: isNordic ? "Glute Bridge" : "Calf Raise", cues: [
                    isNordic ? "Posterior chain warm-up" : "Full range, no bounce",
                    "2-3 clean sets"
                ])
            ]
        )
    }

    private static let pistolSquatPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "ld.pistol-squat",
        regressions: [
            TrainingExercise(name: "Deep Goblet Squat Hold", cues: [
                "KB or DB at chest, 60s × 3, build mobility"
            ]),
            TrainingExercise(name: "Rear-Foot Elevated Lunge", cues: [
                "Rear foot on bench, 8-10 per leg × 3"
            ]),
            TrainingExercise(name: "Skater Squat", cues: [
                "Single leg, opposite leg back not forward",
                "5-8 per leg × 3"
            ]),
            TrainingExercise(name: "Box Pistol (sit-to-stand)", cues: [
                "Sit to box on one leg, stand without using other",
                "5 per leg × 3"
            ]),
            TrainingExercise(name: "Counterbalance Pistol (KB held forward)", cues: [
                "Hold 5-10kg straight out — easier, not harder",
                "3-5 per leg × 3"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Pistol Squat (per leg)",
                sets: 5,
                target: .reps(3),
                restSeconds: 120,
                notes: "Heel down, full depth, controlled descent"
            ),
            TrainingPrescription(
                exerciseName: "Tempo Pistol (per leg)",
                sets: 3,
                target: .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1),
                restSeconds: 90,
                notes: "Control the bottom"
            )
        ],
        accessories: [
            TrainingExercise(name: "Calf Raise", cues: [
                "20-25 reps × 3"
            ]),
            TrainingExercise(name: "Single-Leg RDL", cues: [
                "Hip hinge balance, 8 per leg × 3"
            ]),
            TrainingExercise(name: "Cossack Squat", cues: [
                "Lateral mobility, 5 per side × 3"
            ])
        ]
    )

    // MARK: - 8. Plank

    private static let plankPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.plank-30",
        regressions: [
            TrainingExercise(name: "Knee Plank", cues: [
                "Knees down, body straight head to knees"
            ]),
            TrainingExercise(name: "Wall Plank", cues: [
                "Hands on wall, body angled, build the brace"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Plank Max Hold",
                sets: 3,
                target: .hold(seconds: 60),
                restSeconds: 60,
                notes: "Stop when hips drop or you lose tension. Target 60-90s by Lv5."
            ),
            TrainingPrescription(
                exerciseName: "Perfect Plank",
                sets: 3,
                target: .hold(seconds: 30),
                restSeconds: 30,
                notes: "Drilling form, not pushing limit"
            )
        ],
        accessories: [
            TrainingExercise(name: "Dead Bug", cues: [
                "Anti-extension, 8-10 per side × 3"
            ]),
            TrainingExercise(name: "Bird Dog", cues: [
                "Anti-rotation, 8-10 per side × 3"
            ]),
            TrainingExercise(name: "Side Plank", cues: [
                "30-45s per side × 3"
            ])
        ]
    )

    // MARK: - 9. L-Sit

    private static let lSitPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.l-sit-10",
        regressions: [
            TrainingExercise(name: "Tuck L-Sit", cues: [
                "Knees in, hips up, 10s × 5"
            ]),
            TrainingExercise(name: "Single-Leg L-Sit", cues: [
                "One leg out, one tucked, 10s per leg × 4"
            ]),
            TrainingExercise(name: "Floor L-Sit on Parallettes", cues: [
                "Hips up off ground, full position"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "L-Sit Max Hold",
                sets: 5,
                target: .hold(seconds: 10),
                restSeconds: 90,
                notes: "Push to break in form. Total time-under-tension target 30-60s."
            ),
            TrainingPrescription(
                exerciseName: "L-Sit Cluster (5s on / 5s off)",
                sets: 3,
                target: .hold(seconds: 5),
                restSeconds: 60,
                notes: "Inside the cluster: 5s hold, 5s rest, repeat. 60s rest between clusters."
            )
        ],
        accessories: [
            TrainingExercise(name: "Compression Sit", cues: [
                "Legs straight, fold over, 10 reps × 3"
            ]),
            TrainingExercise(name: "Pike Compression", cues: [
                "Seated, fold forward, 10 reps × 3"
            ]),
            TrainingExercise(name: "Toe-Touch Crunch", cues: [
                "Direct compression, 10-12 × 3"
            ])
        ]
    )

    // MARK: - 10. Hollow Body

    private static let hollowBodyPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cl.hollow-body-30",
        regressions: [
            TrainingExercise(name: "Tuck Hollow", cues: [
                "Knees in, hands at sides, 30s × 3"
            ]),
            TrainingExercise(name: "Banana (single-arm-leg)", cues: [
                "Less aggressive, 30s × 3"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Hollow Body Hold",
                sets: 5,
                target: .hold(seconds: 20),
                restSeconds: 60,
                notes: "Primary standard work. Progress tuck to one-leg to full overhead; stop the set when low back contact or breathing breaks."
            ),
            TrainingPrescription(
                exerciseName: "Hollow + Arch Superset",
                sets: 3,
                target: .hold(seconds: 10),
                restSeconds: 60,
                notes: "10s hollow + 10s arch back-to-back. Builds both ends of the brace."
            )
        ],
        accessories: [
            TrainingExercise(name: "Dead Bug", cues: [
                "8-10 per side × 3"
            ]),
            TrainingExercise(name: "Toe-Touch Crunch", cues: [
                "Direct compression, 8-10 × 3"
            ]),
            TrainingExercise(name: "V-Up", cues: [
                "Dynamic core, 8-10 × 3"
            ])
        ]
    )

    private static func coreFlexionPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let hard = skillId == "cl.inverted-situp" || skillId == "cl.decline-situp"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Small Curl Crunch", cues: ["Ribs toward pelvis", "Neck stays quiet"]),
                TrainingExercise(name: skillId == "cl.reverse-crunch" ? "Foot Tap Reverse Crunch" : "Arms-Forward Crunch", cues: [skillId == "cl.reverse-crunch" ? "Reset momentum each rep" : "Shorten the lever", "Slow lower"]),
                TrainingExercise(name: hard ? "Low Decline Sit-Up" : "Dead Bug", cues: [hard ? "Modest angle first" : "Low back stays down", "Breathe behind the brace"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 4, target: hard ? .repsRange(5, 8) : .repsRange(8, 15), restSeconds: 60, notes: "Controlled spinal flexion. Do not yank the neck or swing the legs."),
                TrainingPrescription(exerciseName: "Tempo \(name)", sets: 3, target: .tempo(reps: 6, eccentric: 3, hold: 1, concentric: 1), restSeconds: 60, notes: "Tempo keeps the rep abdominal instead of momentum-driven.")
            ],
            accessories: [
                TrainingExercise(name: "Hollow Body Hold", cues: ["10-30s x 3", "Lumbar contact"]),
                TrainingExercise(name: "Dead Bug", cues: ["8-10 per side", "No rib flare"]),
                TrainingExercise(name: "Hip Flexor Stretch", cues: ["Gentle after work", "Do not force range"])
            ]
        )
    }

    private static func plankControlPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let advanced = skillId == "cl.extended-plank"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Perfect Plank", cues: ["Ribs down", "Glutes and quads on"]),
                TrainingExercise(name: "Short Lever \(name)", cues: ["Reduce reach or extension", "No hip sway"]),
                TrainingExercise(name: "Dead Bug", cues: ["Anti-extension practice", "Slow exhales"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 4, target: .hold(seconds: advanced ? 20 : 30), restSeconds: 60, notes: "Stop when hips sag, pike, or rotate. Quality time beats survival time."),
                TrainingPrescription(exerciseName: "Plank Shoulder Shift", sets: 3, target: .repsRange(8, 12), restSeconds: 60, notes: "Shift without changing rib or pelvis position.")
            ],
            accessories: [
                TrainingExercise(name: "Side Plank", cues: ["20-40s per side", "Shoulders stacked"]),
                TrainingExercise(name: "Bird Dog", cues: ["8-10 per side", "Hips quiet"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs-to-pelvis carryover", "20-30s x 3"])
            ]
        )
    }

    private static func rolloutPlan(skillId: String) -> SkillTrainingPlan {
        let standing = skillId == "cl.standing-ab-rollout"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Stability-Ball Rollout", cues: ["Short range", "Ribs stay down"]),
                TrainingExercise(name: standing ? "Incline Standing Rollout" : "Kneeling Partial Rollout", cues: [standing ? "Hands on elevated wheel path" : "Stop before back arches", "Pull back with lats and abs"]),
                TrainingExercise(name: "Eccentric Rollout", cues: ["Slow out", "Reset instead of yanking back"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: standing ? "Standing Ab Rollout" : "Knee Ab Rollout", sets: 4, target: standing ? .repsRange(1, 4) : .repsRange(5, 10), restSeconds: standing ? 120 : 90, notes: "Only roll as far as the pelvis stays tucked. Low-back extension ends the rep."),
                TrainingPrescription(exerciseName: "Rollout Eccentric", sets: 3, target: .tempo(reps: 3, eccentric: 4, hold: 1, concentric: 0), restSeconds: 90, notes: "Use eccentric range to build the full rep without lumbar dumping.")
            ],
            accessories: [
                TrainingExercise(name: "Hollow Body Hold", cues: ["30s x 3", "Same anti-extension shape"]),
                TrainingExercise(name: "Straight-Arm Pulldown", cues: ["Lat connection", "8-12 x 3"]),
                TrainingExercise(name: "Dead Bug", cues: ["Slow reaches", "8-10 per side"])
            ]
        )
    }

    private static func coreRaisePlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let hanging = skillId.contains("hanging") || skillId == "cl.toes-to-bar"
        let toes = skillId == "cl.toes-to-bar"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Posterior Pelvic Tilt Drill", cues: ["Curl tailbone toward ribs", "No leg swing"]),
                TrainingExercise(name: hanging ? "Captain Chair Knee Raise" : "Bent-Knee Raise", cues: [hanging ? "Back supported if needed" : "Hands anchored lightly", "Slow lower"]),
                TrainingExercise(name: toes ? "Hanging Leg Raise" : "Negative \(name)", cues: [toes ? "Build straight-leg height first" : "3s lower", "Quiet ribs"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 4, target: toes ? .repsRange(2, 6) : .repsRange(6, 12), restSeconds: hanging ? 90 : 60, notes: "Start each rep still. Raise by curling pelvis, not by swinging the legs."),
                TrainingPrescription(exerciseName: "Tempo \(name)", sets: 3, target: .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1), restSeconds: 75, notes: "Tempo catches hip-flexor swing and low-back arch.")
            ],
            accessories: [
                TrainingExercise(name: "Active Bar Hang", cues: ["If hanging", "20-30s x 3"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down", "20-40s x 3"]),
                TrainingExercise(name: "Compression Sit", cues: ["10 reps x 3", "Active hip flexion"])
            ]
        )
    }

    private static func lSitFamilyPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let advanced = skillId == "cl.v-sit" || skillId == "cl.vertical-l-sit"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Tuck L-Sit", cues: ["Push shoulders down", "Knees tight"]),
                TrainingExercise(name: advanced ? "Straddle L-Sit" : "Single-Leg L-Sit", cues: [advanced ? "Open legs to reduce lever" : "Alternate straight leg", "Hips stay lifted"]),
                TrainingExercise(name: "Compression Lift", cues: ["Active pike or straddle", "Small heel lifts count"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 6, target: .hold(seconds: advanced ? 5 : 10), restSeconds: 90, notes: "Accumulate clean support time. Regress before hips drag or elbows bend."),
                TrainingPrescription(exerciseName: "L-Sit Cluster", sets: 3, target: .hold(seconds: 5), restSeconds: 60, notes: "Repeat short holds with brief intra-set rests for total quality time.")
            ],
            accessories: [
                TrainingExercise(name: "Pike Compression", cues: ["10 reps x 3", "Hands by knees or shins"]),
                TrainingExercise(name: "Support Hold", cues: ["Shoulders depressed", "20-30s x 3"]),
                TrainingExercise(name: "Hanging Knee Raise", cues: ["Compression endurance", "8-12 x 3"])
            ]
        )
    }

    private static func frontLeverPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let advanced = skillId != "cl.tuck-front-lever"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Active Bar Hang", cues: ["Depress shoulders", "No elbow bend"]),
                TrainingExercise(name: advanced ? "Advanced Tuck Front Lever" : "Tuck Front Lever", cues: [advanced ? "Open hips gradually" : "Knees tight", "Ribs down"]),
                TrainingExercise(name: "Front Lever Negative", cues: ["Lower by degrees", "Stop before line breaks"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 6, target: .hold(seconds: advanced ? 5 : 10), restSeconds: 150, notes: "Rank by shape and seconds: tuck, advanced tuck, one-leg/straddle, then full. Do not replace line quality with toes-to-bar reps."),
                TrainingPrescription(exerciseName: "Front Lever Negative", sets: 4, target: .tempo(reps: 2, eccentric: 4, hold: 1, concentric: 0), restSeconds: 120, notes: "Slow lever-specific strength at the hardest shape you can control.")
            ],
            accessories: [
                TrainingExercise(name: "Tuck Front Lever Row", cues: ["2-5 reps x 3", "Hips stay high"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Same rib position", "30-45s x 3"]),
                TrainingExercise(name: "Scapular Pulls", cues: ["Straight arms", "8-12 x 3"])
            ]
        )
    }

    private static func backLeverPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let passThrough = skillId == "cl.german-hang" || skillId == "cl.skin-the-cat"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Feet-Assisted German Hang", cues: ["Dose shoulder extension", "No sharp pain"]),
                TrainingExercise(name: passThrough ? "Tuck Pass-Through" : "Tuck Back Lever", cues: ["Straight arms", "Move slowly"]),
                TrainingExercise(name: "Skin the Cat Negative", cues: ["Control into and out of range", "Use low rings"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: passThrough ? 4 : 6, target: passThrough ? .repsRange(2, 5) : .hold(seconds: 5), restSeconds: 120, notes: "Shoulder extension is earned. No dropping into German hang, no pain holds."),
                TrainingPrescription(exerciseName: passThrough ? "German Hang Hold" : "Back Lever Negative", sets: 3, target: passThrough ? .hold(seconds: 10) : .tempo(reps: 2, eccentric: 4, hold: 1, concentric: 0), restSeconds: 120, notes: "Use assisted range that can be reversed cleanly.")
            ],
            accessories: [
                TrainingExercise(name: "Ring Support and Reverse Plank", cues: ["Shoulder-extension prep", "2-3 sets"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down", "20-40s x 3"]),
                TrainingExercise(name: "Active Bar Hang", cues: ["Shoulders organized", "20-30s x 3"])
            ]
        )
    }

    private static let threeSixtyPullPlan = SkillTrainingPlan(
        skillId: "cl.three-sixty-pulls",
        regressions: [
            TrainingExercise(name: "Explosive Chest-to-Bar Pull-Up", cues: ["Height before rotation", "Full rest"]),
            TrainingExercise(name: "Bar Release Drill", cues: ["Small release", "Active re-catch"]),
            TrainingExercise(name: "Tuck Rotation Practice", cues: ["Spot the landing", "Use mats and supervision"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "360 Pull", sets: 6, target: .reps(1), restSeconds: 180, notes: "Elite release practice only with safe landing space. Stop on blind catches or shoulder shock."),
            TrainingPrescription(exerciseName: "Bar Release Re-Grip", sets: 4, target: .repsRange(1, 3), restSeconds: 150, notes: "Own the catch before adding rotation.")
        ],
        accessories: [
            TrainingExercise(name: "Active Bar Hang", cues: ["Catch prepared", "20-30s x 3"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Tuck control", "30s x 3"]),
            TrainingExercise(name: "Scapular Pulls", cues: ["Shoulder readiness", "8-12 x 3"])
        ]
    )

    private static func dragonFlagPlan(skillId: String) -> SkillTrainingPlan {
        let full = skillId == "cl.dragon-flag"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Reverse Crunch", cues: ["Pelvis curls first", "No swing"]),
                TrainingExercise(name: "Tuck Dragon Flag", cues: ["Short lever", "Shoulders anchored"]),
                TrainingExercise(name: "Dragon Flag Negative", cues: ["3-5s lower", "Reset at top"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: full ? "Dragon Flag" : "Dragon Flag Hip Raise", sets: 5, target: full ? .repsRange(1, 4) : .repsRange(3, 8), restSeconds: 120, notes: "One rigid line. Regress to tuck or one-leg when hips pike or low back arches."),
                TrainingPrescription(exerciseName: "Dragon Flag Negative", sets: 3, target: .tempo(reps: 2, eccentric: 5, hold: 1, concentric: 0), restSeconds: 120, notes: "Controlled lowers build the standard faster than bounced reps.")
            ],
            accessories: [
                TrainingExercise(name: "Hollow Body Hold", cues: ["Anti-extension line", "30-45s x 3"]),
                TrainingExercise(name: "Straight-Arm Pulldown", cues: ["Anchor with lats", "8-12 x 3"]),
                TrainingExercise(name: "Reverse Crunch", cues: ["Pelvic curl volume", "8-12 x 3"])
            ]
        )
    }

    // MARK: - 11. Wall Handstand

    private static let wallHandstandPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.wall-handstand-30",
        regressions: [
            TrainingExercise(name: "Wrist Conditioning", cues: [
                "Wrist rocks, palm lifts, fingertip pulses",
                "2-4 minutes before every handstand session"
            ]),
            TrainingExercise(name: "Pike Hold (hips high)", cues: [
                "Hips high, head between arms",
                "Push floor away, 20s x 5"
            ]),
            TrainingExercise(name: "Crow Pose", cues: [
                "Knees on triceps, eyes forward",
                "Finger pressure controls the tilt, 10-15s x 5"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Wall Handstand (chest-to-wall)",
                sets: 5,
                target: .hold(seconds: 30),
                restSeconds: 60,
                notes: "Chest-to-wall. Hands shoulder-width, elbows locked, shoulders by ears, ribs down, toes light. Stop the set when the line breaks."
            ),
            TrainingPrescription(
                exerciseName: "Wall Walk",
                sets: 3,
                target: .reps(3),
                restSeconds: 90,
                notes: "Walk up and down in small hand steps. No belly sag, no rushed descent, no collapsing onto the wall."
            )
        ],
        accessories: [
            TrainingExercise(name: "Shoulder Dislocates (band/dowel)", cues: [
                "Straight arms, slow range",
                "10-15 reps x 3"
            ]),
            TrainingExercise(name: "Hollow Body Hold", cues: [
                "Low back pressed down, ribs tucked",
                "30-60s x 3"
            ]),
            TrainingExercise(name: "Pike Compression", cues: [
                "Seated fold, lift heels if possible",
                "10 reps x 3"
            ])
        ]
    )

    // MARK: - 12. Freestanding Handstand

    private static let handstandPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.freestanding-hs-30",
        regressions: [
            TrainingExercise(name: "Wall Handstand 60s", cues: [
                "Chest-to-wall line first",
                "60s while breathing before max free attempts"
            ]),
            TrainingExercise(name: "Kick-Up Practice (against wall)", cues: [
                "Kick softly to the balance point",
                "Use the wall as a quiet target, 5-10 attempts"
            ]),
            TrainingExercise(name: "Wall Shoulder Tap", cues: [
                "Shift weight before the hand lifts",
                "Hips stay stacked, 5 per side x 3"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Freestanding Handstand Attempts",
                sets: 5,
                target: .hold(seconds: 30),
                restSeconds: 90,
                notes: "Target 30s+ free. Count only stacked time with locked elbows, quiet legs, and hand-pressure balance. Stop when shoulders fatigue enough to change the skill."
            ),
            TrainingPrescription(
                exerciseName: "Heel Pull (kick-up + balance)",
                sets: 3,
                target: .reps(5),
                restSeconds: 60,
                notes: "From a wall line, peel heels off, catch overbalance with fingertips, then return lightly to the wall."
            )
        ],
        accessories: [
            TrainingExercise(name: "Wall Walk", cues: [
                "Controlled ascent and descent",
                "3 reps x 3"
            ]),
            TrainingExercise(name: "Tuck Handstand Drill", cues: [
                "Pull knees in without losing shoulder push",
                "5 reps x 3 sets"
            ]),
            TrainingExercise(name: "Single-Arm Bear Walk", cues: [
                "Slow shifts, hips level",
                "30s x 3"
            ])
        ]
    )

    private static let wallPlankPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.wall-plank",
        regressions: [
            TrainingExercise(name: "Wrist Conditioning", cues: ["Palm rocks and fingertip pulses", "2-4 minutes"]),
            TrainingExercise(name: "Bear Hold Shoulder Shift", cues: ["Knees low, shoulders over hands", "10 shifts per side x 3"]),
            TrainingExercise(name: "Box Pike Hold", cues: ["Feet elevated, hips high", "Push floor away, 15-25s x 4"])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Wall Plank",
                sets: 5,
                target: .hold(seconds: 30),
                restSeconds: 60,
                notes: "Feet on wall, elbows locked, shoulders pushed tall, ribs tucked. Stop before the low back sags."
            ),
            TrainingPrescription(
                exerciseName: "Partial Wall Walk",
                sets: 3,
                target: .reps(3),
                restSeconds: 90,
                notes: "Walk only as high as the line stays controlled; walk down slowly."
            )
        ],
        accessories: [
            TrainingExercise(name: "Scapular Push-Up Plus", cues: ["Straight arms", "Push upper back tall, 10-15 x 3"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down, glutes on", "20-40s x 3"]),
            TrainingExercise(name: "Reverse Wrist Stretch", cues: ["Gentle pressure", "30s each side"])
        ]
    )

    private static let headstandPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.headstand",
        regressions: [
            TrainingExercise(name: "Tripod Base Hold", cues: ["Hands and head form triangle", "Press through palms, 10s x 5"]),
            TrainingExercise(name: "Tripod Knee Shelf", cues: ["Knees rest high on arms", "One foot light at a time"]),
            TrainingExercise(name: "Tuck Headstand", cues: ["Knees close, hips stacked", "No kicking"])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Headstand Hold",
                sets: 5,
                target: .hold(seconds: 20),
                restSeconds: 75,
                notes: "Weight shared through hands, neck long, legs lift slowly from tuck."
            ),
            TrainingPrescription(
                exerciseName: "Headstand Tuck Extension",
                sets: 3,
                target: .reps(3),
                restSeconds: 90,
                notes: "Tuck, extend one or both legs, then return to tuck before exiting."
            )
        ],
        accessories: [
            TrainingExercise(name: "Wall Handstand (chest-to-wall)", cues: ["Build shoulder loading separately", "Short clean holds"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Control ribs and pelvis", "20-40s x 3"]),
            TrainingExercise(name: "Wrist Conditioning", cues: ["Palms and fingers active", "2-4 minutes"])
        ]
    )

    private static let tuckHandstandPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.tuck-handstand",
        regressions: [
            TrainingExercise(name: "Wall Tuck Handstand", cues: ["Bend knees only as far as shoulders stay tall", "5-10s x 5"]),
            TrainingExercise(name: "Box Tuck Handstand", cues: ["Feet on box, hips over hands", "20s x 4"]),
            TrainingExercise(name: "Tuck Handstand Negative", cues: ["Lower from wall line into tuck", "Slow and controlled"])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Tuck Handstand Hold",
                sets: 6,
                target: .hold(seconds: 5),
                restSeconds: 90,
                notes: "Hips stay over hands; elbows locked; balance through fingers."
            ),
            TrainingPrescription(
                exerciseName: "Tuck Handstand Drill",
                sets: 4,
                target: .reps(3),
                restSeconds: 90,
                notes: "From handstand, pull knees in and re-extend without losing shoulder push."
            )
        ],
        accessories: [
            TrainingExercise(name: "Pike Compression", cues: ["Lift heels if possible", "10 reps x 3"]),
            TrainingExercise(name: "Crow Pose", cues: ["Finger-pressure balance", "10s x 5"]),
            TrainingExercise(name: "Wall Shoulder Tap", cues: ["Weight shift before hand lifts", "5 per side x 3"])
        ]
    )

    private static func pressHandstandPlan(skillId: String) -> SkillTrainingPlan {
        let isTuck = skillId == "hs.tuck-press"
        let isStraddle = skillId == "hs.straddle-press"
        let skillName = isTuck ? "Tuck Press to Handstand" : (isStraddle ? "Straddle Press to Handstand" : "Press to Handstand")
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Elevated-Hand Press Drill", cues: ["Hands on blocks or parallettes", "Float feet, do not hop"]),
                TrainingExercise(name: isTuck ? "Crow to Tuck Float" : "Compression Lift", cues: [isTuck ? "Knees tight, feet lift quietly" : "Lift heels from pike or straddle", "Keep arms straight"]),
                TrainingExercise(name: "Wall Press Negative", cues: ["Lower from wall handstand", "Slow hip path"])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: skillName,
                    sets: 6,
                    target: isTuck ? .reps(2) : .reps(1),
                    restSeconds: 150,
                    notes: "Straight arms, shoulders forward, no jump. Stop when elbows bend or feet start hopping."
                ),
                TrainingPrescription(
                    exerciseName: "Press Negative",
                    sets: 4,
                    target: .reps(2),
                    restSeconds: 120,
                    notes: isStraddle ? "Keep legs wide until hips descend past shoulders." : "Move slowly through compression without collapsing shoulders."
                )
            ],
            accessories: [
                TrainingExercise(name: "Pike Compression", cues: ["Active fold", "10 reps x 3"]),
                TrainingExercise(name: "Planche Lean Hold", cues: ["Straight arms, shoulders forward", "10-20s x 4"]),
                TrainingExercise(name: "Shoulder Dislocates (band/dowel)", cues: ["Straight arms, slow range", "10-15 x 3"])
            ]
        )
    }

    private static let wallSupportedOahPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.wall-supported-oah",
        regressions: [
            TrainingExercise(name: "Wall Handstand 60s", cues: ["Tight two-hand line first", "Breathe without rib flare"]),
            TrainingExercise(name: "Wall Shoulder Tap", cues: ["Shift fully before tapping", "5 per side x 3"]),
            TrainingExercise(name: "Fingertip Weight Shift", cues: ["Free hand gets lighter", "No shoulder sink"])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Wall-Supported One-Arm Handstand",
                sets: 5,
                target: .hold(seconds: 5),
                restSeconds: 150,
                notes: "Working arm straight, shoulder tall, free hand light. Wall is feedback, not a crutch."
            ),
            TrainingPrescription(
                exerciseName: "Wall One-Arm Weight Shift",
                sets: 4,
                target: .hold(seconds: 10),
                restSeconds: 120,
                notes: "Straddle legs, shift slowly, reduce free-hand pressure."
            )
        ],
        accessories: [
            TrainingExercise(name: "Side Plank", cues: ["Side-body support", "30s per side x 3"]),
            TrainingExercise(name: "Wrist Conditioning", cues: ["Extra care before one-arm load", "3-5 minutes"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down under fatigue", "30-45s x 3"])
        ]
    )

    private static func oneArmHandstandPlan(skillId: String) -> SkillTrainingPlan {
        let full = skillId == "oah.full-one-arm-handstand"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Straddle Handstand Hold", cues: ["Stable two-hand balance", "Legs quiet"]),
                TrainingExercise(name: "Wall-Supported One-Arm Handstand", cues: ["Free hand on fingertips", "Shoulder tall"]),
                TrainingExercise(name: "One-Arm Fingertip Hover", cues: ["Lift free hand briefly", "Exit before shoulder sinks"])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: full ? "Full One-Arm Handstand" : "One-Arm Handstand",
                    sets: 8,
                    target: .hold(seconds: full ? 5 : 3),
                    restSeconds: 180,
                    notes: "Advanced skill practice only: fresh attempts, long rest, no bent-arm saves."
                ),
                TrainingPrescription(
                    exerciseName: "One-Arm Handstand Assisted Hold",
                    sets: 4,
                    target: .hold(seconds: 8),
                    restSeconds: 150,
                    notes: "Use wall or fingertip support to keep the line clean after max attempts."
                )
            ],
            accessories: [
                TrainingExercise(name: "Wall One-Arm Weight Shift", cues: ["3-5 clean shifts per side", "No hip dump"]),
                TrainingExercise(name: "Freestanding Handstand Attempts", cues: ["Maintain two-hand base", "Stop before fatigue"]),
                TrainingExercise(name: "Wrist Conditioning", cues: ["One-arm load prep", "Daily if tolerated"])
            ]
        )
    }

    private static func conditioningPlan(skillId: String) -> SkillTrainingPlan {
        switch skillId {
        case "co.bw-farmer-carry", "co.1.5x-farmer-carry", "co.2x-farmer-carry":
            return carryPlan(skillId: skillId)
        case "co.sled-push":
            return sledPushPlan
        case "co.400m-row":
            return rowSprintPlan
        case "co.mile-sub-7", "co.5k-sub-22":
            return runPlan(skillId: skillId)
        case "co.dead-hang-60":
            return hangPlan(skillId: skillId)
        default:
            return assaultBikePlan
        }
    }

    private static func carryPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let heavy = skillId != "co.bw-farmer-carry"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Suitcase Carry", cues: ["One side at a time", "Do not lean away"]),
                TrainingExercise(name: "Farmer Hold", cues: ["Stand tall first", "10-20s before walking"]),
                TrainingExercise(name: heavy ? "Previous-Load Farmer Carry" : "Half-Bodyweight Farmer Carry", cues: ["Perfect posture", "Short courses"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: heavy ? 5 : 4, target: .hold(seconds: heavy ? 20 : 40), restSeconds: heavy ? 150 : 90, notes: "Use load plus distance/time as the real standard. Shoulders level, small steps, clean set-down."),
                TrainingPrescription(exerciseName: "Farmer Carry Intervals", sets: 4, target: .hold(seconds: 30), restSeconds: 90, notes: "Walk briskly without swinging the handles into the legs.")
            ],
            accessories: [
                TrainingExercise(name: "Trap Bar Deadlift or Hinge", cues: ["Clean pickup pattern", "3-5 reps x 3"]),
                TrainingExercise(name: "Side Plank", cues: ["Anti-lateral flexion", "20-40s per side"]),
                TrainingExercise(name: "Forearm Extensor Opens", cues: ["Balance grip work", "15-25 x 2"])
            ]
        )
    }

    private static let sledPushPlan = SkillTrainingPlan(
        skillId: "co.sled-push",
        regressions: [
            TrainingExercise(name: "Wall Lean March", cues: ["Strong forward angle", "Drive floor back"]),
            TrainingExercise(name: "Light Sled March", cues: ["Smooth first steps", "No upright collapse"]),
            TrainingExercise(name: "Short Sled Intervals", cues: ["10-15m repeats", "Same body angle every rep"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "Sled Push", sets: 6, target: .hold(seconds: 15), restSeconds: 120, notes: "Load should allow continuous motion, braced spine, and short powerful steps."),
            TrainingPrescription(exerciseName: "Sled Push Tempo Course", sets: 4, target: .hold(seconds: 20), restSeconds: 90, notes: "Submaximal pacing for posture and repeatability.")
        ],
        accessories: [
            TrainingExercise(name: "Split Squat", cues: ["Leg drive base", "6-10 per side"]),
            TrainingExercise(name: "Plank Max Hold", cues: ["Brace under drive", "30-60s x 3"]),
            TrainingExercise(name: "Calf Raise", cues: ["Ankle stiffness", "12-20 x 3"])
        ]
    )

    private static let rowSprintPlan = SkillTrainingPlan(
        skillId: "co.400m-row",
        regressions: [
            TrainingExercise(name: "Technique Row", cues: ["Legs, body, arms", "Recover arms, body, legs"]),
            TrainingExercise(name: "100m Row Repeat", cues: ["Sprint rhythm", "Do not shorten stroke"]),
            TrainingExercise(name: "Rate-Cap Row", cues: ["20-24 spm", "Powerful drive"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "400m Row", sets: 3, target: .reps(1), restSeconds: 240, notes: "Use a familiar drag setting. Full strokes beat frantic half-strokes."),
            TrainingPrescription(exerciseName: "100m Row Repeat", sets: 6, target: .reps(1), restSeconds: 90, notes: "Practice sprint output while keeping sequence intact.")
        ],
        accessories: [
            TrainingExercise(name: "Hip Hinge Drill", cues: ["Torso swing without rounding", "8-10 x 2"]),
            TrainingExercise(name: "Hollow Body Hold", cues: ["Brace under fatigue", "20-40s x 3"]),
            TrainingExercise(name: "Easy Technique Row", cues: ["5-10 minutes", "Nasal or relaxed breathing"])
        ]
    )

    private static func runPlan(skillId: String) -> SkillTrainingPlan {
        let is5k = skillId == "co.5k-sub-22"
        let name = skillName(for: skillId)
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Easy Base Run", cues: ["Conversational effort", "Build weekly consistency"]),
                TrainingExercise(name: is5k ? "Goal-Pace 1K Repeat" : "Goal-Pace 400", cues: [is5k ? "Around 4:24/km" : "Around 1:45/lap", "Recover enough to keep form"]),
                TrainingExercise(name: "Relaxed Strides", cues: ["Fast but smooth", "10-20s reps"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 1, target: .reps(1), restSeconds: 0, notes: is5k ? "Test on a measured 5K route or calibrated treadmill. Start controlled so kilometers 3-4 do not collapse." : "Test on a measured mile. First lap near goal pace, then protect lap three before the kick."),
                TrainingPrescription(exerciseName: is5k ? "5 x 1K Goal-Pace Repeats" : "4 x 400m Goal-Pace Repeats", sets: is5k ? 5 : 4, target: .reps(1), restSeconds: is5k ? 150 : 120, notes: "Keep at least 48h between hard run sessions. This is pace rehearsal, not all-out racing.")
            ],
            accessories: [
                TrainingExercise(name: "Tempo Run", cues: ["Comfortably hard", is5k ? "12-20 minutes" : "8-12 minutes"]),
                TrainingExercise(name: "Easy Run", cues: ["Aerobic base", "20-40 minutes"]),
                TrainingExercise(name: "Calf Raise", cues: ["Lower-leg durability", "12-20 x 3"])
            ]
        )
    }

    private static let assaultBikePlan = SkillTrainingPlan(
        skillId: "co.assault-bike-30",
        regressions: [
            TrainingExercise(name: "Smooth RPM Ride", cues: ["Find rhythm", "Arms and legs share work"]),
            TrainingExercise(name: "10-Cal Assault Bike Repeat", cues: ["Controlled launch", "No early redline"]),
            TrainingExercise(name: "Arms/Legs Practice", cues: ["Short arms-only and legs-only blocks", "Stable torso"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "30-Calorie Assault Bike", sets: 2, target: .reps(1), restSeconds: 300, notes: "Set seat first. Hard start, quick settle, push through the final calories without coasting."),
            TrainingPrescription(exerciseName: "10-Cal Assault Bike Repeat", sets: 5, target: .reps(1), restSeconds: 90, notes: "Repeatable power. Stop if output collapses into sloppy survival pacing.")
        ],
        accessories: [
            TrainingExercise(name: "Easy Bike Flush", cues: ["5-10 minutes", "Nasal or relaxed breathing"]),
            TrainingExercise(name: "Goblet Squat", cues: ["Leg drive base", "8-12 x 3"]),
            TrainingExercise(name: "Plank Max Hold", cues: ["Stable trunk", "30-60s x 3"])
        ]
    )
}
