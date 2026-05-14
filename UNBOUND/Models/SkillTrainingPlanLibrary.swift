import Foundation

// MARK: - SkillTrainingPlanLibrary
//
// Authored, hand-tuned training plans for keystone skills. Each plan owns
// regressions (for users below Lv1), main sets (the prescription), and
// accessories (supporting work).
//
// Coverage in V1: 12 keystone plans. Skills without authored content fall
// back to the generic "log a session" path in SkillSessionView.
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
        case "pp.pullup":            return pullUpPlan
        case "pp.strict-pullup":     return strictPullUpPlan
        case "pp.muscle-up":         return muscleUpPlan
        case "cal.pushup":           return pushUpPlan
        case "cal.5-dips":           return dipPlan
        case "cal.ring-dip":         return ringDipPlan
        case "ld.pistol-squat":      return pistolSquatPlan
        case "cal.plank-30":         return plankPlan
        case "cal.l-sit-10":         return lSitPlan
        case "cl.hollow-body-30":    return hollowBodyPlan
        case "hs.wall-handstand-30": return wallHandstandPlan
        case "hs.freestanding-hs-30": return handstandPlan
        default:                     return nil
        }
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
                exerciseName: "Hollow Rocks",
                sets: 3,
                target: .reps(10),
                restSeconds: 60,
                notes: "Stay tight — small range, big tension"
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

    // MARK: - 11. Wall Handstand

    private static let wallHandstandPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.wall-handstand-30",
        regressions: [
            TrainingExercise(name: "Wrist Conditioning", cues: [
                "Knuckle push-ups, wrist circles, daily"
            ]),
            TrainingExercise(name: "Pike Hold (hips high)", cues: [
                "Pike position, head between hands, 20s × 5"
            ]),
            TrainingExercise(name: "Crow Pose", cues: [
                "Knees on triceps, balance on hands, 10-15s × 5"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Wall Handstand (chest-to-wall)",
                sets: 5,
                target: .hold(seconds: 30),
                restSeconds: 60,
                notes: "Chest-to-wall preferred. Target 30s+."
            ),
            TrainingPrescription(
                exerciseName: "Wall Walk",
                sets: 3,
                target: .reps(3),
                restSeconds: 90,
                notes: "Feet up, walk hands toward wall"
            )
        ],
        accessories: [
            TrainingExercise(name: "Shoulder Dislocates (band/dowel)", cues: [
                "10-15 reps × 3"
            ]),
            TrainingExercise(name: "Hollow Body Hold", cues: [
                "30-60s × 3"
            ]),
            TrainingExercise(name: "Pike Compression", cues: [
                "Seated fold, 10 × 3"
            ])
        ]
    )

    // MARK: - 12. Freestanding Handstand

    private static let handstandPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.freestanding-hs-30",
        regressions: [
            TrainingExercise(name: "Wall Handstand 60s", cues: [
                "Confidence in inverted position, must own first"
            ]),
            TrainingExercise(name: "Kick-Up Practice (against wall)", cues: [
                "Find the balance point",
                "5-10 attempts"
            ]),
            TrainingExercise(name: "Wall Shoulder Tap", cues: [
                "From wall HS, shift weight, tap shoulder",
                "5 per side × 3"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Freestanding Handstand Attempts",
                sets: 5,
                target: .hold(seconds: 30),
                restSeconds: 90,
                notes: "Target 30s+ free. Keep failed attempts in count, but stop when shoulders fatigue."
            ),
            TrainingPrescription(
                exerciseName: "Heel Pull (kick-up + balance)",
                sets: 3,
                target: .reps(5),
                restSeconds: 60,
                notes: "Kick to balance point, hold what you can"
            )
        ],
        accessories: [
            TrainingExercise(name: "Wall Walk", cues: [
                "3 reps × 3, builds inverted strength"
            ]),
            TrainingExercise(name: "Tuck Handstand Drill", cues: [
                "Pull legs in mid-handstand, 5 × 3 sets"
            ]),
            TrainingExercise(name: "Single-Arm Bear Walk", cues: [
                "Builds shoulder stability, 30s × 3"
            ])
        ]
    )
}
