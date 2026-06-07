import Foundation

extension SkillTrainingPlanLibrary {
    static func armBalancePlan(skillId: String) -> SkillTrainingPlan {
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

    static let pseudoPlanchePushupPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let tuckPlanchePlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let fullPlanchePlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static func intermediatePlanchePlan(skillId: String) -> SkillTrainingPlan {
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

    static let bentArmPlanchePlan = SkillTrainingPlan(
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
}
