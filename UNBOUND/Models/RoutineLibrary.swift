import Foundation

// MARK: - SideQuestLibrary

enum SideQuestLibrary {
    static let all: [SideQuest] = [
        pushProtocol, pullProtocol, coreCircuit,
        shoulderBurn, morningMobility, zone2Walk,
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
