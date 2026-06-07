import Foundation

extension SkillTrainingPlanLibrary {
    static let wallHandstandPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let handstandPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let wallPlankPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let headstandPlan: SkillTrainingPlan = SkillTrainingPlan(
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
                notes: "Palms carry active pressure, head contact stays light, neck long, legs lift slowly from tuck."
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

    static let tuckHandstandPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static func pressHandstandPlan(skillId: String) -> SkillTrainingPlan {
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

    static let wallSupportedOahPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "hs.wall-supported-oah",
        regressions: [
            TrainingExercise(name: "Wall Handstand 60s", cues: ["Tight two-hand line first", "Breathe without rib flare"]),
            TrainingExercise(name: "Close-Hand Straddle Handstand", cues: ["Hands closer than normal", "Open legs before shifting"]),
            TrainingExercise(name: "One-Arm Handstand Weight Shift", cues: ["Shift fully before tapping", "No shoulder sink"])
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
                exerciseName: "One-Arm Handstand Weight Shift",
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

    static func oneArmHandstandPlan(skillId: String) -> SkillTrainingPlan {
        let full = skillId == "oah.full-one-arm-handstand"
        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Straddle Handstand Hold", cues: ["Stable two-hand balance", "Legs quiet"]),
                TrainingExercise(name: "Close-Hand Straddle Handstand", cues: ["Hands close enough to make shifting honest", "Keep both shoulders tall"]),
                TrainingExercise(name: "Two-Finger Tent", cues: ["Free hand helps lightly", "Build time without shoulder sink"]),
                TrainingExercise(name: "One-Finger Tent", cues: ["Less off-hand pressure", "Same body line as the real hold"]),
                TrainingExercise(name: "Off-Hand Float", cues: ["Brief fingertip lift", "Exit before the working shoulder drops"])
            ],
            mainSets: [
                TrainingPrescription(
                    exerciseName: full ? "Full One-Arm Handstand" : "One-Arm Handstand",
                    sets: full ? 8 : 5,
                    target: .hold(seconds: full ? 5 : 3),
                    restSeconds: 180,
                    notes: "Advanced skill practice only: fresh attempts, long rest, no bent-arm saves."
                ),
                TrainingPrescription(
                    exerciseName: full ? "One-Arm Handstand Assisted Hold" : "Off-Hand Float",
                    sets: 4,
                    target: .hold(seconds: full ? 8 : 5),
                    restSeconds: 150,
                    notes: full ? "Use wall or fingertip support to keep the line clean after max attempts." : "Free hand floats briefly; log assisted or form-break context honestly."
                ),
                TrainingPrescription(
                    exerciseName: full ? "One-Finger Tent" : "Two-Finger Tent",
                    sets: 4,
                    target: .hold(seconds: 10),
                    restSeconds: 120,
                    notes: "Accumulate clean time under balance before chasing longer unsupported holds."
                )
            ],
            accessories: [
                TrainingExercise(name: "One-Arm Handstand Weight Shift", cues: ["3-5 clean shifts per side", "No hip dump"]),
                TrainingExercise(name: "Freestanding Handstand Attempts", cues: ["Maintain two-hand base", "Stop before fatigue"]),
                TrainingExercise(name: "Wrist Conditioning", cues: ["One-arm load prep", "Daily if tolerated"])
            ]
        )
    }

}
