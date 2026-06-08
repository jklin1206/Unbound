import Foundation

extension SkillTrainingPlanLibrary {
    static let pushUpPlan: SkillTrainingPlan = SkillTrainingPlan(
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
                notes: "Add a light backpack load — keep body line tight"
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

    static func pushUpVariantPlan(skillId: String) -> SkillTrainingPlan {
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

    static func closeGripPushPlan(skillId: String) -> SkillTrainingPlan {
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

    static func pikePushPlan(skillId: String) -> SkillTrainingPlan {
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

    static let handstandPushPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let clappingHandstandPushPlan = SkillTrainingPlan(
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

    static let ninetyDegreePushPlan = SkillTrainingPlan(
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

    static let bentArmPressPlan = SkillTrainingPlan(
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

    static func planchePushPlan(skillId: String) -> SkillTrainingPlan {
        let isTuck = skillId == "cal.tuck-planche-pushup"
        if isTuck {
            return SkillTrainingPlan(
                skillId: skillId,
                regressions: [
                    TrainingExercise(name: "Tuck Planche Hold", cues: [
                        "Own the float before bending the elbows",
                        "Locked elbows, protracted shoulders"
                    ]),
                    TrainingExercise(name: "Band-Assisted Tuck Planche Push-Up", cues: [
                        "Band supports hips, not feet",
                        "Same tuck line on every inch"
                    ]),
                    TrainingExercise(name: "Tuck Planche Negative", cues: [
                        "Lower 3-5s without feet touching",
                        "Step down before the tuck collapses"
                    ])
                ],
                mainSets: [
                    TrainingPrescription(
                        exerciseName: "Tuck Planche Push-Up",
                        sets: 6,
                        target: .repsRange(1, 3),
                        restSeconds: 180,
                        notes: "Feet never touch. Keep the same tuck planche lean through the descent and press."
                    ),
                    TrainingPrescription(
                        exerciseName: "Tuck Planche Hold",
                        sets: 5,
                        target: .hold(seconds: 5),
                        restSeconds: 120,
                        notes: "Rebuild the straight-arm float between bent-arm sets."
                    )
                ],
                accessories: [
                    TrainingExercise(name: "Pseudo-Planche Lean", cues: [
                        "Measurable forward lean",
                        "Wrists warmed first"
                    ]),
                    TrainingExercise(name: "Scapular Push-Up", cues: [
                        "Straight-arm protraction strength"
                    ]),
                    TrainingExercise(name: "Hollow Body Hold", cues: [
                        "Ribs down, pelvis tucked"
                    ])
                ]
            )
        }

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

    static func unilateralPushPlan(skillId: String) -> SkillTrainingPlan {
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

    static func explosivePushPlan(skillId: String) -> SkillTrainingPlan {
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
                    sets: isTriple ? 6 : 5,
                    target: isTriple ? .reps(1) : .repsRange(3, 5),
                    restSeconds: isTriple ? 150 : 120,
                    notes: isTriple ? "Singles only. Full reset between attempts; stop when airtime or landing quality drops." : "Power only. Stop when airtime or landing quality drops."
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

    static let dipPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let benchDipPlan: SkillTrainingPlan = SkillTrainingPlan(
        skillId: "cal.bench-dip",
        regressions: [
            TrainingExercise(name: "Assisted Bench Dip", cues: [
                "Feet close, legs help only as needed",
                "Shoulders stay down and back"
            ]),
            TrainingExercise(name: "Short-Range Bench Dip", cues: [
                "Pain-free depth first",
                "Add range slowly"
            ]),
            TrainingExercise(name: "Bench Support Hold", cues: [
                "Arms straight, hips close to bench",
                "Hold without shoulder roll"
            ])
        ],
        mainSets: [
            TrainingPrescription(
                exerciseName: "Bench Dip",
                sets: 4,
                target: .repsRange(6, 10),
                restSeconds: 75,
                notes: "Keep hips close to the bench. Descend only as far as the shoulders stay controlled and pain-free."
            ),
            TrainingPrescription(
                exerciseName: "Tempo Bench Dip",
                sets: 3,
                target: .tempo(reps: 5, eccentric: 3, hold: 1, concentric: 1),
                restSeconds: 75,
                notes: "Tempo exposes shoulder roll and leg push before they become habits."
            )
        ],
        accessories: [
            TrainingExercise(name: "Close-Grip Push-Up", cues: [
                "Elbows track back",
                "Lockout strength"
            ]),
            TrainingExercise(name: "Band Tricep Extension", cues: [
                "Elbows still",
                "Full lockout"
            ]),
            TrainingExercise(name: "Scapular Push-Up", cues: [
                "Shoulder control",
                "10-15 clean reps"
            ])
        ]
    )

    // MARK: - 6. Ring Dip

    static let ringDipPlan: SkillTrainingPlan = SkillTrainingPlan(
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
}
