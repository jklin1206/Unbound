import Foundation

extension SkillTrainingPlanLibrary {
    static func hangPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        let seconds = 30
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

    static func verticalPullPlan(skillId: String) -> SkillTrainingPlan {
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

    static func weightedPullPlan(skillId: String) -> SkillTrainingPlan {
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

    static func explosivePullingPlan(skillId: String) -> SkillTrainingPlan {
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

    static func archerPullingPlan(skillId: String) -> SkillTrainingPlan {
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

    static func soloArmPullPlan(skillId: String) -> SkillTrainingPlan {
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

    static let lSitChinPlan = SkillTrainingPlan(
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

    static func rowFamilyPlan(skillId: String) -> SkillTrainingPlan {
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

    static func advancedMuscleUpPlan(skillId: String) -> SkillTrainingPlan {
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

    static let pullUpPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let strictPullUpPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let muscleUpPlan: SkillTrainingPlan = SkillTrainingPlan(
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
}
