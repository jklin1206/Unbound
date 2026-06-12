import Foundation

extension SkillTrainingPlanLibrary {
    static func legBranchPlan(skillId: String) -> SkillTrainingPlan {
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
            if isPower { return .repsRange(1, 3) }
            if isNordic { return .repsRange(1, 3) }
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
                    target: isHold ? .hold(seconds: 30) : (isPower ? .repsRange(2, 3) : (isNordic ? .tempo(reps: 3, eccentric: 4, hold: 1, concentric: 1) : .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1))),
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

    static let pistolSquatPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "ld.pistol-squat",
        regressions: [
            TrainingExercise(name: "Parallel Squat", cues: [
                "Own flat-foot depth",
                "Knees track over toes"
            ]),
            TrainingExercise(name: "Cossack Squat", cues: [
                "Shift hips side to side",
                "Keep the working foot rooted"
            ]),
            TrainingExercise(name: "Partial Pistol Squat", cues: [
                "Use a box or target",
                "Pause before standing"
            ]),
            TrainingExercise(name: "Assisted Pistol Squat", cues: [
                "Use rail or strap lightly",
                "Same knee path as the strict rep"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Pistol Squat",
                sets: 5,
                target: .reps(3),
                restSeconds: 120,
                notes: "Heel down, full depth, controlled descent"
            ),
            TrainingPrescription(
                exerciseName: "Tempo Pistol Squat",
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

    static let shrimpSquatPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "ld.shrimp-squat",
        regressions: [
            TrainingExercise(name: "Assisted Shrimp Squat", cues: [
                "Use a light hand assist",
                "Rear knee touches softly"
            ]),
            TrainingExercise(name: "Beginner Shrimp Squat", cues: [
                "Keep one hand free for balance",
                "Own the eccentric before adding depth"
            ]),
            TrainingExercise(name: "Intermediate Shrimp Squat", cues: [
                "Less assistance, same knee line",
                "Working heel stays down"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Shrimp Squat",
                sets: 5,
                target: .repsRange(1, 3),
                restSeconds: 150,
                notes: "Rear knee kisses the floor; no bounce, no heel lift."
            ),
            TrainingPrescription(
                exerciseName: "Two-Hand Shrimp Squat",
                sets: 4,
                target: .repsRange(1, 3),
                restSeconds: 150,
                notes: "Treat this as the advanced shrimp line after strict reps are controlled."
            ),
            TrainingPrescription(
                exerciseName: "Elevated Two-Hand Shrimp Squat",
                sets: 3,
                target: .repsRange(1, 2),
                restSeconds: 180,
                notes: "Use only when the two-hand version is smooth and pain-free."
            )
        ],
        accessories: [
            TrainingExercise(name: "Pistol Squat", cues: [
                "Keep single-leg strength fresh",
                "2-3 controlled back-off sets"
            ]),
            TrainingExercise(name: "Bulgarian Split Squat", cues: [
                "Front heel rooted",
                "8-10 reps per side"
            ]),
            TrainingExercise(name: "Ankle And Hip Prep", cues: [
                "2-4 minutes before attempts",
                "No sharp knee sensation"
            ])
        ]
    )

    static let weightedPistolPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "ld.weighted-pistol",
        regressions: [
            TrainingExercise(name: "Pistol Squat", cues: [
                "Own clean bodyweight reps first",
                "No bounce at the bottom"
            ]),
            TrainingExercise(name: "Light Weighted Pistol Squat", cues: [
                "Hold a small kettlebell at chest",
                "Load stays quiet"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Weighted Pistol Squat",
                sets: 5,
                target: .repsRange(1, 3),
                restSeconds: 180,
                notes: "Add load only if the rep still looks like a bodyweight pistol."
            ),
            TrainingPrescription(
                exerciseName: "Pistol Squat",
                sets: 3,
                target: .repsRange(3, 5),
                restSeconds: 120,
                notes: "Back-off volume keeps depth and balance honest."
            )
        ],
        accessories: [
            TrainingExercise(name: "Deep Step Up", cues: [
                "High box, full foot planted",
                "Control the eccentric"
            ]),
            TrainingExercise(name: "Cossack Squat", cues: [
                "Keep lateral range alive",
                "5 reps per side"
            ])
        ]
    )

    static let nordicCurlPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "ld.nordic-curl",
        regressions: [
            TrainingExercise(name: "Nordic Curl Negative", cues: [
                "Lower slowly",
                "Hands catch before collapse"
            ]),
            TrainingExercise(name: "Nordic Curl", cues: [
                "Pull back up without pushing",
                "Body stays one line"
            ]),
            TrainingExercise(name: "Nordic Curl Arms Overhead", cues: [
                "Arms stay long",
                "Same strict body line"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Nordic Curl",
                sets: 4,
                target: .repsRange(1, 3),
                restSeconds: 180,
                notes: "Quality reps only; stop before the catch becomes a fall."
            ),
            TrainingPrescription(
                exerciseName: "Tuck One-Leg Nordic Curl",
                sets: 3,
                target: .repsRange(1, 2),
                restSeconds: 180,
                notes: "Use after full Nordic reps are repeatable."
            ),
            TrainingPrescription(
                exerciseName: "One-Leg Nordic Curl",
                sets: 3,
                target: .reps(1),
                restSeconds: 210,
                notes: "Peak variation. Keep range tiny until control is real."
            )
        ],
        accessories: [
            TrainingExercise(name: "Glute Bridge", cues: [
                "Posterior chain warm-up",
                "2-3 clean sets"
            ]),
            TrainingExercise(name: "Leg Curl (Lying)", cues: [
                "Hamstring volume without max tension",
                "8-12 reps"
            ]),
            TrainingExercise(name: "Hip Hinge Mobility", cues: [
                "Easy range",
                "No hamstring cramp chasing"
            ])
        ]
    )
}
