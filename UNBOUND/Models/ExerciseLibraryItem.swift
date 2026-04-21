import Foundation

enum ExerciseCategory: String, CaseIterable, Codable {
    case compound
    case isolation
    case bodyweight
    case machine
    case cable

    var displayName: String {
        rawValue.capitalized
    }
}

struct ExerciseLibraryItem: Identifiable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let muscleGroups: [MuscleGroup]
    let equipment: [String]
    let isCompound: Bool

    var normalizedName: String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}

enum ExerciseLibrary {
    static let all: [ExerciseLibraryItem] = [
        // LOWER BODY — QUAD DOMINANT
        ExerciseLibraryItem(id: "barbell_back_squat", name: "Barbell Back Squat", category: .compound, muscleGroups: [.legs, .glutes, .core], equipment: ["Barbell", "Squat Rack"], isCompound: true),
        ExerciseLibraryItem(id: "barbell_front_squat", name: "Barbell Front Squat", category: .compound, muscleGroups: [.legs, .core], equipment: ["Barbell", "Squat Rack"], isCompound: true),
        ExerciseLibraryItem(id: "hack_squat", name: "Hack Squat", category: .machine, muscleGroups: [.legs, .glutes], equipment: ["Hack Squat Machine"], isCompound: true),
        ExerciseLibraryItem(id: "leg_press", name: "Leg Press", category: .machine, muscleGroups: [.legs, .glutes], equipment: ["Leg Press Machine"], isCompound: true),
        ExerciseLibraryItem(id: "bulgarian_split_squat", name: "Bulgarian Split Squat", category: .compound, muscleGroups: [.legs, .glutes], equipment: ["Dumbbells", "Bench"], isCompound: true),
        ExerciseLibraryItem(id: "lunges", name: "Lunges", category: .compound, muscleGroups: [.legs, .glutes], equipment: ["Dumbbells"], isCompound: true),
        ExerciseLibraryItem(id: "goblet_squat", name: "Goblet Squat", category: .compound, muscleGroups: [.legs, .core], equipment: ["Dumbbell"], isCompound: true),
        ExerciseLibraryItem(id: "leg_extension", name: "Leg Extension", category: .machine, muscleGroups: [.legs], equipment: ["Leg Extension Machine"], isCompound: false),

        // LOWER BODY — POSTERIOR CHAIN
        ExerciseLibraryItem(id: "conventional_deadlift", name: "Conventional Deadlift", category: .compound, muscleGroups: [.back, .legs, .glutes, .core], equipment: ["Barbell"], isCompound: true),
        ExerciseLibraryItem(id: "sumo_deadlift", name: "Sumo Deadlift", category: .compound, muscleGroups: [.legs, .glutes, .back], equipment: ["Barbell"], isCompound: true),
        ExerciseLibraryItem(id: "romanian_deadlift", name: "Romanian Deadlift", category: .compound, muscleGroups: [.legs, .glutes, .back], equipment: ["Barbell"], isCompound: true),
        ExerciseLibraryItem(id: "hip_thrust_barbell", name: "Hip Thrust (Barbell)", category: .compound, muscleGroups: [.glutes, .legs], equipment: ["Barbell", "Bench"], isCompound: true),
        ExerciseLibraryItem(id: "leg_curl_lying", name: "Leg Curl (Lying)", category: .machine, muscleGroups: [.legs], equipment: ["Leg Curl Machine"], isCompound: false),
        ExerciseLibraryItem(id: "leg_curl_seated", name: "Leg Curl (Seated)", category: .machine, muscleGroups: [.legs], equipment: ["Seated Leg Curl Machine"], isCompound: false),
        ExerciseLibraryItem(id: "good_morning", name: "Good Morning", category: .compound, muscleGroups: [.back, .legs, .glutes], equipment: ["Barbell"], isCompound: true),

        // UPPER BODY — PUSH (HORIZONTAL)
        ExerciseLibraryItem(id: "barbell_bench_press", name: "Barbell Bench Press", category: .compound, muscleGroups: [.chest, .shoulders, .arms], equipment: ["Barbell", "Bench"], isCompound: true),
        ExerciseLibraryItem(id: "dumbbell_bench_press", name: "Dumbbell Bench Press", category: .compound, muscleGroups: [.chest, .shoulders, .arms], equipment: ["Dumbbells", "Bench"], isCompound: true),
        ExerciseLibraryItem(id: "incline_barbell_press", name: "Incline Barbell Press", category: .compound, muscleGroups: [.chest, .shoulders], equipment: ["Barbell", "Incline Bench"], isCompound: true),
        ExerciseLibraryItem(id: "incline_dumbbell_press", name: "Incline Dumbbell Press", category: .compound, muscleGroups: [.chest, .shoulders], equipment: ["Dumbbells", "Incline Bench"], isCompound: true),
        ExerciseLibraryItem(id: "machine_chest_press", name: "Machine Chest Press", category: .machine, muscleGroups: [.chest, .shoulders, .arms], equipment: ["Chest Press Machine"], isCompound: true),
        ExerciseLibraryItem(id: "cable_fly", name: "Cable Fly", category: .cable, muscleGroups: [.chest], equipment: ["Cable Machine"], isCompound: false),
        ExerciseLibraryItem(id: "dumbbell_fly", name: "Dumbbell Fly", category: .isolation, muscleGroups: [.chest], equipment: ["Dumbbells", "Bench"], isCompound: false),
        ExerciseLibraryItem(id: "pec_dec", name: "Pec Dec", category: .machine, muscleGroups: [.chest], equipment: ["Pec Dec Machine"], isCompound: false),

        // UPPER BODY — PUSH (VERTICAL)
        ExerciseLibraryItem(id: "barbell_ohp", name: "Barbell OHP", category: .compound, muscleGroups: [.shoulders, .arms], equipment: ["Barbell"], isCompound: true),
        ExerciseLibraryItem(id: "dumbbell_ohp", name: "Dumbbell OHP", category: .compound, muscleGroups: [.shoulders, .arms], equipment: ["Dumbbells"], isCompound: true),
        ExerciseLibraryItem(id: "arnold_press", name: "Arnold Press", category: .compound, muscleGroups: [.shoulders, .arms], equipment: ["Dumbbells"], isCompound: true),
        ExerciseLibraryItem(id: "seated_machine_press", name: "Seated Machine Press", category: .machine, muscleGroups: [.shoulders], equipment: ["Shoulder Press Machine"], isCompound: true),
        ExerciseLibraryItem(id: "lateral_raise_db", name: "Lateral Raise (DB)", category: .isolation, muscleGroups: [.shoulders], equipment: ["Dumbbells"], isCompound: false),
        ExerciseLibraryItem(id: "lateral_raise_cable", name: "Lateral Raise (Cable)", category: .cable, muscleGroups: [.shoulders], equipment: ["Cable Machine"], isCompound: false),
        ExerciseLibraryItem(id: "rear_delt_fly_db", name: "Rear Delt Fly (DB)", category: .isolation, muscleGroups: [.shoulders], equipment: ["Dumbbells"], isCompound: false),
        ExerciseLibraryItem(id: "rear_delt_fly_machine", name: "Rear Delt Fly (Machine)", category: .machine, muscleGroups: [.shoulders], equipment: ["Reverse Pec Dec"], isCompound: false),
        ExerciseLibraryItem(id: "face_pull", name: "Face Pull", category: .cable, muscleGroups: [.shoulders, .back], equipment: ["Cable Machine"], isCompound: false),

        // UPPER BODY — PULL (HORIZONTAL)
        ExerciseLibraryItem(id: "barbell_bent_over_row", name: "Barbell Bent Over Row", category: .compound, muscleGroups: [.back, .arms], equipment: ["Barbell"], isCompound: true),
        ExerciseLibraryItem(id: "dumbbell_row", name: "Dumbbell Row", category: .compound, muscleGroups: [.back, .arms], equipment: ["Dumbbell", "Bench"], isCompound: true),
        ExerciseLibraryItem(id: "cable_row_seated", name: "Cable Row (Seated)", category: .cable, muscleGroups: [.back, .arms], equipment: ["Cable Machine"], isCompound: true),
        ExerciseLibraryItem(id: "machine_row", name: "Machine Row", category: .machine, muscleGroups: [.back], equipment: ["Row Machine"], isCompound: true),
        ExerciseLibraryItem(id: "chest_supported_row", name: "Chest Supported Row", category: .compound, muscleGroups: [.back, .arms], equipment: ["Dumbbells", "Incline Bench"], isCompound: true),

        // UPPER BODY — PULL (VERTICAL)
        ExerciseLibraryItem(id: "pull_up", name: "Pull Up", category: .bodyweight, muscleGroups: [.back, .arms, .lats], equipment: ["Pull-up Bar"], isCompound: true),
        ExerciseLibraryItem(id: "chin_up", name: "Chin Up", category: .bodyweight, muscleGroups: [.back, .arms, .lats], equipment: ["Pull-up Bar"], isCompound: true),
        ExerciseLibraryItem(id: "lat_pulldown", name: "Lat Pulldown", category: .cable, muscleGroups: [.back, .lats, .arms], equipment: ["Lat Pulldown Machine"], isCompound: true),
        ExerciseLibraryItem(id: "lat_pulldown_neutral", name: "Lat Pulldown (Neutral)", category: .cable, muscleGroups: [.back, .lats, .arms], equipment: ["Lat Pulldown Machine"], isCompound: true),
        ExerciseLibraryItem(id: "straight_arm_pulldown", name: "Straight Arm Pulldown", category: .cable, muscleGroups: [.lats, .back], equipment: ["Cable Machine"], isCompound: false),

        // ARMS
        ExerciseLibraryItem(id: "barbell_curl", name: "Barbell Curl", category: .isolation, muscleGroups: [.arms], equipment: ["Barbell"], isCompound: false),
        ExerciseLibraryItem(id: "dumbbell_curl", name: "Dumbbell Curl", category: .isolation, muscleGroups: [.arms], equipment: ["Dumbbells"], isCompound: false),
        ExerciseLibraryItem(id: "incline_dumbbell_curl", name: "Incline Dumbbell Curl", category: .isolation, muscleGroups: [.arms], equipment: ["Dumbbells", "Incline Bench"], isCompound: false),
        ExerciseLibraryItem(id: "cable_curl", name: "Cable Curl", category: .cable, muscleGroups: [.arms], equipment: ["Cable Machine"], isCompound: false),
        ExerciseLibraryItem(id: "hammer_curl", name: "Hammer Curl", category: .isolation, muscleGroups: [.arms, .forearms], equipment: ["Dumbbells"], isCompound: false),
        ExerciseLibraryItem(id: "preacher_curl", name: "Preacher Curl", category: .machine, muscleGroups: [.arms], equipment: ["Preacher Curl Machine"], isCompound: false),
        ExerciseLibraryItem(id: "tricep_pushdown", name: "Tricep Pushdown", category: .cable, muscleGroups: [.arms], equipment: ["Cable Machine"], isCompound: false),
        ExerciseLibraryItem(id: "overhead_tricep_ext", name: "Overhead Tricep Extension", category: .cable, muscleGroups: [.arms], equipment: ["Cable Machine"], isCompound: false),
        ExerciseLibraryItem(id: "skull_crushers", name: "Skull Crushers", category: .isolation, muscleGroups: [.arms], equipment: ["Barbell", "Bench"], isCompound: false),
        ExerciseLibraryItem(id: "dips_tricep", name: "Dips (Tricep)", category: .bodyweight, muscleGroups: [.arms, .chest], equipment: ["Dip Station"], isCompound: true),
        ExerciseLibraryItem(id: "close_grip_bench", name: "Close Grip Bench Press", category: .compound, muscleGroups: [.arms, .chest], equipment: ["Barbell", "Bench"], isCompound: true),

        // CORE
        ExerciseLibraryItem(id: "plank", name: "Plank", category: .bodyweight, muscleGroups: [.core], equipment: [], isCompound: false),
        ExerciseLibraryItem(id: "cable_crunch", name: "Cable Crunch", category: .cable, muscleGroups: [.core], equipment: ["Cable Machine"], isCompound: false),
        ExerciseLibraryItem(id: "hanging_leg_raise", name: "Hanging Leg Raise", category: .bodyweight, muscleGroups: [.core], equipment: ["Pull-up Bar"], isCompound: false),
        ExerciseLibraryItem(id: "ab_wheel", name: "Ab Wheel", category: .bodyweight, muscleGroups: [.core], equipment: ["Ab Wheel"], isCompound: false),
        ExerciseLibraryItem(id: "pallof_press", name: "Pallof Press", category: .cable, muscleGroups: [.core], equipment: ["Cable Machine"], isCompound: false),

        // CALVES
        ExerciseLibraryItem(id: "standing_calf_raise", name: "Standing Calf Raise", category: .machine, muscleGroups: [.calves], equipment: ["Calf Raise Machine"], isCompound: false),
        ExerciseLibraryItem(id: "seated_calf_raise", name: "Seated Calf Raise", category: .machine, muscleGroups: [.calves], equipment: ["Seated Calf Machine"], isCompound: false),
        ExerciseLibraryItem(id: "leg_press_calf_raise", name: "Leg Press Calf Raise", category: .machine, muscleGroups: [.calves], equipment: ["Leg Press Machine"], isCompound: false),

        // TRAPS / NECK
        ExerciseLibraryItem(id: "barbell_shrug", name: "Barbell Shrug", category: .isolation, muscleGroups: [.traps], equipment: ["Barbell"], isCompound: false),
        ExerciseLibraryItem(id: "dumbbell_shrug", name: "Dumbbell Shrug", category: .isolation, muscleGroups: [.traps], equipment: ["Dumbbells"], isCompound: false),
        ExerciseLibraryItem(id: "farmers_walk", name: "Farmer's Walk", category: .compound, muscleGroups: [.traps, .forearms, .core], equipment: ["Dumbbells"], isCompound: true),

        // FOREARMS
        ExerciseLibraryItem(id: "wrist_curl", name: "Wrist Curl", category: .isolation, muscleGroups: [.forearms], equipment: ["Barbell"], isCompound: false),
        ExerciseLibraryItem(id: "reverse_curl", name: "Reverse Curl", category: .isolation, muscleGroups: [.forearms, .arms], equipment: ["Barbell"], isCompound: false),
    ]

    static func grouped() -> [(String, [ExerciseLibraryItem])] {
        let groups: [(String, [ExerciseLibraryItem])] = [
            ("Lower Body — Quad Dominant", all.filter { $0.id.contains("squat") || $0.id.contains("leg_press") || $0.id.contains("leg_extension") || $0.id.contains("lunge") || $0.id.contains("step_up") }),
            ("Lower Body — Posterior Chain", all.filter { $0.id.contains("deadlift") || $0.id.contains("hip_thrust") || $0.id.contains("leg_curl") || $0.id.contains("good_morning") }),
            ("Chest", all.filter { $0.muscleGroups.contains(.chest) && !$0.muscleGroups.contains(.arms) || $0.id.contains("bench_press") || $0.id.contains("fly") || $0.id.contains("pec") }),
            ("Shoulders", all.filter { ($0.muscleGroups.first == .shoulders || $0.id.contains("ohp") || $0.id.contains("lateral") || $0.id.contains("rear_delt") || $0.id.contains("face_pull") || $0.id.contains("arnold")) && !$0.id.contains("bench") }),
            ("Back", all.filter { ($0.muscleGroups.first == .back || $0.id.contains("row") || $0.id.contains("pull")) && !$0.id.contains("curl") && !$0.id.contains("pushdown") }),
            ("Arms", all.filter { $0.muscleGroups.first == .arms || $0.id.contains("curl") || $0.id.contains("tricep") || $0.id.contains("skull") || $0.id.contains("close_grip") || $0.id.contains("dips") }),
            ("Core", all.filter { $0.muscleGroups.first == .core }),
            ("Calves", all.filter { $0.muscleGroups.contains(.calves) }),
            ("Traps & Forearms", all.filter { $0.muscleGroups.contains(.traps) || $0.muscleGroups.contains(.forearms) }),
        ]
        return groups.filter { !$0.1.isEmpty }
    }
}
