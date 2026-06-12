import Foundation

extension SkillTrainingPlanLibrary {
    static let plankPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static let lSitPlan: SkillTrainingPlan = SkillTrainingPlan(
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
                notes: "Stop at the first form break. Accumulate 30-60s of clean total time."
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

    static let hollowBodyPlan: SkillTrainingPlan = SkillTrainingPlan(
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

    static func coreFlexionPlan(skillId: String) -> SkillTrainingPlan {
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

    static func plankControlPlan(skillId: String) -> SkillTrainingPlan {
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

    static func rolloutPlan(skillId: String) -> SkillTrainingPlan {
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

    static func coreRaisePlan(skillId: String) -> SkillTrainingPlan {
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

    static func lSitFamilyPlan(skillId: String) -> SkillTrainingPlan {
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

    static func frontLeverPlan(skillId: String) -> SkillTrainingPlan {
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

    static func backLeverPlan(skillId: String) -> SkillTrainingPlan {
        let name = skillName(for: skillId)
        if skillId == "cl.german-hang" {
            return SkillTrainingPlan(
                skillId: skillId,
                regressions: [
                    TrainingExercise(name: "Feet-Assisted German Hang", cues: ["Dose shoulder extension", "No sharp pain"]),
                    TrainingExercise(name: "Box-Assisted Skin the Cat", cues: ["Use feet to control depth", "Reverse the path slowly"]),
                    TrainingExercise(name: "Reverse Plank Shoulder Extension", cues: ["Open chest", "Do not force range"])
                ],
                mainSets: [
                    TrainingPrescription(exerciseName: "German Hang Hold", sets: 4, target: .hold(seconds: 10), restSeconds: 120, notes: "Use assisted depth until the shoulders feel open, not jammed. No dropping into the bottom."),
                    TrainingPrescription(exerciseName: "Assisted German Hang Depth", sets: 3, target: .hold(seconds: 10), restSeconds: 90, notes: "Increase range only if you can reverse out smoothly.")
                ],
                accessories: [
                    TrainingExercise(name: "Ring Support and Reverse Plank", cues: ["Shoulder-extension prep", "2-3 sets"]),
                    TrainingExercise(name: "Shoulder Dislocates (band/dowel)", cues: ["Gentle range", "Straight arms"]),
                    TrainingExercise(name: "Active Bar Hang", cues: ["Shoulders organized", "20-30s x 3"])
                ]
            )
        }

        if skillId == "cl.skin-the-cat" {
            return SkillTrainingPlan(
                skillId: skillId,
                regressions: [
                    TrainingExercise(name: "Box-Assisted Skin the Cat", cues: ["Feet keep the path slow", "No shoulder drop"]),
                    TrainingExercise(name: "Tuck Pass-Through", cues: ["Tight tuck", "Straight arms"]),
                    TrainingExercise(name: "Feet-Assisted German Hang", cues: ["Own the bottom", "Reverse with control"])
                ],
                mainSets: [
                    TrainingPrescription(exerciseName: "Skin the Cat", sets: 4, target: .repsRange(2, 4), restSeconds: 120, notes: "Controlled pass-through and controlled return. The rep fails if you drop into the German hang."),
                    TrainingPrescription(exerciseName: "German Hang Hold", sets: 3, target: .hold(seconds: 8), restSeconds: 90, notes: "Short holds teach the shoulder-extension endpoint without turning it into a pain stretch.")
                ],
                accessories: [
                    TrainingExercise(name: "Ring Support and Reverse Plank", cues: ["Shoulder-extension prep", "2-3 sets"]),
                    TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down", "20-40s x 3"]),
                    TrainingExercise(name: "Active Bar Hang", cues: ["Shoulders organized", "20-30s x 3"])
                ]
            )
        }

        return SkillTrainingPlan(
            skillId: skillId,
            regressions: [
                TrainingExercise(name: "Feet-Assisted German Hang", cues: ["Dose shoulder extension", "No sharp pain"]),
                TrainingExercise(name: "Tuck Back Lever", cues: ["Straight arms", "Move slowly"]),
                TrainingExercise(name: "Skin the Cat Negative", cues: ["Control into and out of range", "Use low rings"])
            ],
            mainSets: [
                TrainingPrescription(exerciseName: name, sets: 6, target: .hold(seconds: 5), restSeconds: 120, notes: "Shoulder extension is earned. No dropping into German hang, no pain holds."),
                TrainingPrescription(exerciseName: "Back Lever Negative", sets: 3, target: .tempo(reps: 2, eccentric: 4, hold: 1, concentric: 0), restSeconds: 120, notes: "Use assisted range that can be reversed cleanly.")
            ],
            accessories: [
                TrainingExercise(name: "Ring Support and Reverse Plank", cues: ["Shoulder-extension prep", "2-3 sets"]),
                TrainingExercise(name: "Hollow Body Hold", cues: ["Ribs down", "20-40s x 3"]),
                TrainingExercise(name: "Active Bar Hang", cues: ["Shoulders organized", "20-30s x 3"])
            ]
        )
    }

    static let threeSixtyPullPlan = SkillTrainingPlan(
        skillId: "cl.three-sixty-pulls",
        regressions: [
            TrainingExercise(name: "Skin the Cat", cues: ["Controlled pass-through", "Reverse slowly"]),
            TrainingExercise(name: "Front Lever Pull", cues: ["Straight arms", "Lift through the lats"]),
            TrainingExercise(name: "Assisted 360 Ring Arc", cues: ["Feet or band assist", "No release"])
        ],
        mainSets: [
            TrainingPrescription(exerciseName: "360 Ring Pull", sets: 5, target: .reps(1), restSeconds: 180, notes: "Move through front-lever and back-lever lanes with straight arms. Do not release the rings."),
            TrainingPrescription(exerciseName: "Partial 360 Ring Arc", sets: 4, target: .repsRange(1, 3), restSeconds: 150, notes: "Use only the arc length you can reverse under control.")
        ],
        accessories: [
            TrainingExercise(name: "German Hang Hold", cues: ["Shoulder-extension ownership", "Short pain-free holds"]),
            TrainingExercise(name: "Tuck Front Lever Hold", cues: ["Ribs down", "Lats on"]),
            TrainingExercise(name: "Tuck Back Lever", cues: ["Straight arms", "Pelvis tucked"])
        ]
    )

    static func dragonFlagPlan(skillId: String) -> SkillTrainingPlan {
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
}
