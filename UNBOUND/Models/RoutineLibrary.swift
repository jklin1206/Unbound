import Foundation

// MARK: - SideQuestLibrary

enum SideQuestLibrary {
    static let all: [SideQuest] = [
        pushProtocol, pullProtocol, coreCircuit,
        shoulderBurn, morningMobility, hipReset,
        shoulderSpineReset, ankleSquatPrep, eveningStretch, zone2Walk,
    ]

    static let pushProtocol = SideQuest(
        id: "push-protocol-v1",
        title: "Push Protocol",
        subtitle: "5 exercises · 15 sets · ~25 min",
        category: .circuit,
        estimatedMinutes: 25,
        spReward: 40,
        exercises: [
            SideQuestExercise(
                id: "pp-pushups", name: "Push-Ups", sets: 4, reps: "12", restSeconds: 60,
                cue: "Chest to floor. Elbows 45°. Full lock at the top — don't half-rep it.",
                muscleGroups: ["chest", "triceps", "shoulders"]
            ),
            SideQuestExercise(
                id: "pp-pike", name: "Pike Push-Ups", sets: 3, reps: "8", restSeconds: 75,
                cue: "Hips high. Head pushes through at the bottom. Press straight up.",
                muscleGroups: ["shoulders", "triceps"]
            ),
            SideQuestExercise(
                id: "pp-diamond", name: "Diamond Push-Ups", sets: 3, reps: "10", restSeconds: 60,
                cue: "Thumbs and index fingers touch. Elbows track back, not out.",
                muscleGroups: ["triceps", "chest"]
            ),
            SideQuestExercise(
                id: "pp-dips", name: "Bench Dips", sets: 3, reps: "12", restSeconds: 60,
                cue: "Lower until elbows hit 90°. Drive through palms to full lockout.",
                muscleGroups: ["triceps", "chest", "shoulders"]
            ),
            SideQuestExercise(
                id: "pp-wide", name: "Wide Push-Ups", sets: 2, reps: "AMRAP", restSeconds: 90,
                cue: "Hands wider than shoulders. Go to failure with clean form.",
                muscleGroups: ["chest", "shoulders"]
            ),
        ]
    )

    static let pullProtocol = SideQuest(
        id: "pull-protocol-v1",
        title: "Pull Protocol",
        subtitle: "4 exercises · 14 sets · ~30 min",
        category: .circuit,
        estimatedMinutes: 30,
        spReward: 45,
        exercises: [
            SideQuestExercise(
                id: "pull-deadhang", name: "Dead Hang", sets: 3, reps: "30s", restSeconds: 60,
                cue: "Full grip, shoulders packed into lats. Breathe. Pure hang.",
                muscleGroups: ["forearms", "lats", "shoulders"]
            ),
            SideQuestExercise(
                id: "pull-scapular", name: "Scapular Pull-Ups", sets: 4, reps: "8", restSeconds: 60,
                cue: "Arms stay straight. Depress and retract the shoulder blades. Slow both ways.",
                muscleGroups: ["lats", "rhomboids", "lower traps"]
            ),
            SideQuestExercise(
                id: "pull-inverted", name: "Inverted Rows", sets: 4, reps: "10", restSeconds: 75,
                cue: "Body stays plank. Pull chest to bar. One-count squeeze at the top.",
                muscleGroups: ["back", "biceps", "rear delts"]
            ),
            SideQuestExercise(
                id: "pull-negatives", name: "Negative Pull-Ups", sets: 3, reps: "5", restSeconds: 90,
                cue: "Jump to top position. Lower over a full 5 seconds. That is one rep.",
                muscleGroups: ["lats", "biceps", "back"]
            ),
        ]
    )

    static let coreCircuit = SideQuest(
        id: "core-circuit-v1",
        title: "Core Circuit",
        subtitle: "4 exercises · 13 sets · ~20 min",
        category: .circuit,
        estimatedMinutes: 20,
        spReward: 35,
        exercises: [
            SideQuestExercise(
                id: "core-hollow", name: "Hollow Body Hold", sets: 4, reps: "30s", restSeconds: 45,
                cue: "Lower back pressed flat to floor. Arms overhead, legs low. Brace everything.",
                muscleGroups: ["abs", "hip flexors"]
            ),
            SideQuestExercise(
                id: "core-plank", name: "Plank", sets: 3, reps: "45s", restSeconds: 45,
                cue: "Neutral spine, glutes squeezed, quads tight. Don't let hips pike or sag.",
                muscleGroups: ["core", "shoulders", "glutes"]
            ),
            SideQuestExercise(
                id: "core-legraise", name: "Hanging Leg Raises", sets: 3, reps: "10", restSeconds: 60,
                cue: "No swing. Tuck and lift. Extend back down slowly. The descent is the work.",
                muscleGroups: ["abs", "hip flexors"]
            ),
            SideQuestExercise(
                id: "core-vup", name: "V-Ups", sets: 3, reps: "12", restSeconds: 60,
                cue: "Lift legs and torso simultaneously. Controlled descent.",
                muscleGroups: ["abs", "hip flexors"]
            ),
        ]
    )

    static let shoulderBurn = SideQuest(
        id: "shoulder-burn-v1",
        title: "Shoulder Burn",
        subtitle: "4 exercises · 12 sets · ~20 min",
        category: .circuit,
        estimatedMinutes: 20,
        spReward: 35,
        exercises: [
            SideQuestExercise(
                id: "sh-wallhandstand", name: "Wall Handstand Hold", sets: 3, reps: "20s", restSeconds: 75,
                cue: "Face the wall. Kick up. Squeeze everything — hands, arms, core, legs.",
                muscleGroups: ["shoulders", "triceps", "core"]
            ),
            SideQuestExercise(
                id: "sh-pike", name: "Elevated Pike Push-Ups", sets: 3, reps: "8", restSeconds: 90,
                cue: "Feet on chair. Hips above head. Lower crown toward floor. Press up hard.",
                muscleGroups: ["shoulders", "triceps"]
            ),
            SideQuestExercise(
                id: "sh-lateral", name: "Side Lateral Raises", sets: 3, reps: "15", restSeconds: 45,
                cue: "Lead with elbows. Slight forward lean. Control the way down.",
                muscleGroups: ["lateral delts"]
            ),
            SideQuestExercise(
                id: "sh-facepull", name: "Band Face Pulls", sets: 3, reps: "15", restSeconds: 45,
                cue: "Pull to face level. Elbows high. External rotate at end. Squeeze rear delts.",
                muscleGroups: ["rear delts", "external rotators"]
            ),
        ]
    )

    static let morningMobility = SideQuest(
        id: "morning-mobility-v1",
        title: "Morning Mobility",
        subtitle: "4 exercises · 8 sets · ~15 min",
        category: .mobility,
        estimatedMinutes: 15,
        spReward: 20,
        exercises: [
            SideQuestExercise(
                id: "mob-catcow", name: "Cat-Cow", sets: 2, reps: "10", restSeconds: 20,
                cue: "Exhale into cat, round the back. Inhale into cow, arch. One vertebra at a time.",
                muscleGroups: ["spine", "core"]
            ),
            SideQuestExercise(
                id: "mob-hipflexor", name: "Hip Flexor Stretch", sets: 2, reps: "30s each", restSeconds: 15,
                cue: "Back knee down. Tuck the pelvis under. Drive hip forward.",
                muscleGroups: ["hip flexors", "quads"]
            ),
            SideQuestExercise(
                id: "mob-thoracic", name: "Thoracic Rotation", sets: 2, reps: "10 each", restSeconds: 20,
                cue: "Side lying, top knee grounded. Rotate shoulder blade to the floor.",
                muscleGroups: ["thoracic spine", "chest"]
            ),
            SideQuestExercise(
                id: "mob-worlds", name: "World's Greatest Stretch", sets: 2, reps: "5 each", restSeconds: 15,
                cue: "Lunge, hand inside foot, opposite arm to sky. Rotate slowly.",
                muscleGroups: ["hip flexors", "thoracic", "hamstrings"]
            ),
        ]
    )

    static let hipReset = SideQuest(
        id: "hip-reset-v1",
        title: "Hip Reset",
        subtitle: "5 exercises · 10 sets · ~15 min",
        category: .mobility,
        estimatedMinutes: 15,
        spReward: 22,
        exercises: [
            SideQuestExercise(
                id: "mob-9090", name: "90-90 Hip Switch", sets: 2, reps: "8 each", restSeconds: 15,
                cue: "Sit tall. Rotate both knees side to side without collapsing the chest.",
                muscleGroups: ["hips", "glutes"]
            ),
            SideQuestExercise(
                id: "mob-couch", name: "Couch Stretch", sets: 2, reps: "45s each", restSeconds: 15,
                cue: "Rear glute on, ribs down. Back out if the low back takes over.",
                muscleGroups: ["quads", "hip flexors"]
            ),
            SideQuestExercise(
                id: "mob-frog", name: "Frog Stretch", sets: 2, reps: "45s", restSeconds: 20,
                cue: "Knees wide, shins roughly parallel. Rock back gently.",
                muscleGroups: ["adductors", "hips"]
            ),
            SideQuestExercise(
                id: "mob-figure4", name: "Figure-4 Stretch", sets: 2, reps: "45s each", restSeconds: 15,
                cue: "Cross ankle above the knee. Pull only until the glute lights up.",
                muscleGroups: ["glutes", "hips"]
            ),
            SideQuestExercise(
                id: "mob-glutebridge", name: "Glute Bridge", sets: 2, reps: "12", restSeconds: 20,
                cue: "Ribs down. Drive through heels and stop before the low back arches.",
                muscleGroups: ["glutes", "hamstrings"]
            ),
        ]
    )

    static let shoulderSpineReset = SideQuest(
        id: "shoulder-spine-reset-v1",
        title: "Shoulder + Spine Reset",
        subtitle: "5 exercises · 10 sets · ~12 min",
        category: .mobility,
        estimatedMinutes: 12,
        spReward: 20,
        exercises: [
            SideQuestExercise(
                id: "mob-shouldercars", name: "Shoulder CARs", sets: 2, reps: "5 each", restSeconds: 15,
                cue: "Make the biggest pain-free circle while the ribs stay stacked.",
                muscleGroups: ["shoulders", "upper back"]
            ),
            SideQuestExercise(
                id: "mob-threadneedle", name: "Thread the Needle", sets: 2, reps: "8 each", restSeconds: 15,
                cue: "Reach under the chest, then open through the ribs.",
                muscleGroups: ["thoracic spine", "shoulders"]
            ),
            SideQuestExercise(
                id: "mob-latprayer", name: "Lat Prayer Stretch", sets: 2, reps: "45s", restSeconds: 15,
                cue: "Hips back, arms long, ribs down.",
                muscleGroups: ["lats", "shoulders"]
            ),
            SideQuestExercise(
                id: "mob-wallpec", name: "Wall Pec Stretch", sets: 2, reps: "35s each", restSeconds: 15,
                cue: "Shoulder down. Turn the chest away gently.",
                muscleGroups: ["chest", "front delts"]
            ),
            SideQuestExercise(
                id: "mob-wristrocks", name: "Wrist Rocks", sets: 2, reps: "12", restSeconds: 15,
                cue: "Small rocks with full palm contact. No sharp pressure.",
                muscleGroups: ["wrists", "forearms"]
            ),
        ]
    )

    static let ankleSquatPrep = SideQuest(
        id: "ankle-squat-prep-v1",
        title: "Ankle + Squat Prep",
        subtitle: "4 exercises · 8 sets · ~10 min",
        category: .mobility,
        estimatedMinutes: 10,
        spReward: 18,
        exercises: [
            SideQuestExercise(
                id: "mob-anklerock", name: "Knee-to-Wall Ankle Rock", sets: 2, reps: "10 each", restSeconds: 15,
                cue: "Heel stays down. Knee tracks over the middle toes.",
                muscleGroups: ["ankles", "calves"]
            ),
            SideQuestExercise(
                id: "mob-calfpedal", name: "Calf Pedal", sets: 2, reps: "45s", restSeconds: 15,
                cue: "Alternate heels down while pressing the floor away.",
                muscleGroups: ["calves", "hamstrings"]
            ),
            SideQuestExercise(
                id: "mob-squathold", name: "Deep Squat Hold", sets: 2, reps: "45s", restSeconds: 20,
                cue: "Tripod feet, knees track toes, chest open.",
                muscleGroups: ["ankles", "hips", "adductors"]
            ),
            SideQuestExercise(
                id: "mob-hamrock", name: "Hamstring Rock", sets: 2, reps: "10 each", restSeconds: 15,
                cue: "Rock back until the stretch appears. Return smooth.",
                muscleGroups: ["hamstrings", "calves"]
            ),
        ]
    )

    static let eveningStretch = SideQuest(
        id: "evening-stretch-v1",
        title: "Evening Stretch",
        subtitle: "5 exercises · 10 sets · ~12 min",
        category: .mobility,
        estimatedMinutes: 12,
        spReward: 18,
        exercises: [
            SideQuestExercise(
                id: "mob-hamfold", name: "Hamstring Fold", sets: 2, reps: "45s each", restSeconds: 15,
                cue: "Hinge from the hips. Soft knees, no bouncing.",
                muscleGroups: ["hamstrings", "calves"]
            ),
            SideQuestExercise(
                id: "mob-pigeon", name: "Pigeon Pose", sets: 2, reps: "45s each", restSeconds: 15,
                cue: "Square enough to feel glute, never knee pain.",
                muscleGroups: ["glutes", "hips"]
            ),
            SideQuestExercise(
                id: "mob-forwardfold", name: "Seated Forward Fold", sets: 2, reps: "45s", restSeconds: 15,
                cue: "Reach long first, then fold without yanking.",
                muscleGroups: ["hamstrings", "back"]
            ),
            SideQuestExercise(
                id: "mob-spinaltwist", name: "Spinal Twist", sets: 2, reps: "35s each", restSeconds: 15,
                cue: "Rotate gradually and keep the breath easy.",
                muscleGroups: ["spine", "hips"]
            ),
            SideQuestExercise(
                id: "mob-childreach", name: "Child's Pose Reach", sets: 2, reps: "45s", restSeconds: 15,
                cue: "Walk hands long and breathe into the lats.",
                muscleGroups: ["lats", "spine"]
            ),
        ]
    )

    static let zone2Walk = SideQuest(
        id: "zone2-walk-v1",
        title: "Zone 2 Walk",
        subtitle: "Cardio · 20–40 min sustained",
        category: .cardio,
        estimatedMinutes: 30,
        spReward: 25,
        exercises: [
            SideQuestExercise(
                id: "z2-walk", name: "Sustained Walk", sets: 1, reps: "20-40 min", restSeconds: 0,
                cue: "Pace where you can hold a full conversation. Brisk but never breathless.",
                muscleGroups: ["cardiovascular", "legs"]
            ),
        ]
    )
}
