import Foundation

// MARK: - Onboarding answer enums
//
// Codable + Firestore-friendly. Each maps to a dropdown/chip/selection screen
// in the 30-step onboarding flow. Kept small and additive so they round-trip
// through UserService.updateProfile cleanly.

// MARK: Identity

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, unspecified
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .unspecified: return "Prefer not to say"
        }
    }
}

// MARK: Body type (Screen 10)

enum BodyType: String, Codable, CaseIterable, Identifiable {
    case skinny, skinnyFat, alreadyLifting
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .skinny: return "Skinny"
        case .skinnyFat: return "Skinny-fat"
        case .alreadyLifting: return "Already lifting"
        }
    }
    var subtitle: String {
        switch self {
        case .skinny: return "Lean frame, low muscle"
        case .skinnyFat: return "Soft look without density"
        case .alreadyLifting: return "Training experience present"
        }
    }
    var imageName: String {
        switch self {
        case .skinny: return "BodyType_Skinny"
        case .skinnyFat: return "BodyType_SkinnyFat"
        case .alreadyLifting: return "BodyType_AlreadyLifting"
        }
    }
}

// MARK: Experience (Screen 11)

enum Experience: String, Codable, CaseIterable, Identifiable {
    case never, tried, used, current
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .never: return "Never trained"
        case .tried: return "Tried once"
        case .used: return "Used to train"
        case .current: return "Currently training"
        }
    }
}

// MARK: Training frequency (Screens 12, 13)

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case zero, oneToTwo, threeToFour, fivePlus
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .zero: return "0 days"
        case .oneToTwo: return "1–2 days"
        case .threeToFour: return "3–4 days"
        case .fivePlus: return "5+ days"
        }
    }
    var subtitle: String {
        switch self {
        case .zero: return "Starting fresh"
        case .oneToTwo: return "Occasional"
        case .threeToFour: return "Consistent"
        case .fivePlus: return "Heavy volume"
        }
    }
}

enum TargetFrequency: String, Codable, CaseIterable, Identifiable {
    case three, four, five, six
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .three: return "3 days / week"
        case .four: return "4 days / week"
        case .five: return "5 days / week"
        case .six: return "6 days / week"
        }
    }
    var subtitle: String {
        switch self {
        case .three: return "Balanced baseline"
        case .four: return "Recommended"
        case .five: return "Aggressive"
        case .six: return "Elite volume"
        }
    }
}

// MARK: Equipment (Screen 14)

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case fullGym, homeWeights, bodyweight, bands
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullGym: return "Full gym"
        case .homeWeights: return "Home weights"
        case .bodyweight: return "Bodyweight only"
        case .bands: return "Resistance bands"
        }
    }
    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .homeWeights: return "house.fill"
        case .bodyweight: return "figure.strengthtraining.functional"
        case .bands: return "line.diagonal"
        }
    }
}

// MARK: Exercise styles — what types of training the user enjoys

enum ExerciseStyle: String, Codable, CaseIterable, Identifiable {
    case compoundLifts, isolation, calisthenics, olympicLifts, cardioIntervals, steadyCardio, mobility, sports, plyometrics, machines
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .compoundLifts: return "Compound lifts"
        case .isolation: return "Isolation work"
        case .calisthenics: return "Calisthenics"
        case .olympicLifts: return "Olympic lifts"
        case .cardioIntervals: return "Cardio intervals"
        case .steadyCardio: return "Steady-state cardio"
        case .mobility: return "Mobility & stretching"
        case .sports: return "Sports & drills"
        case .plyometrics: return "Plyometrics"
        case .machines: return "Machine work"
        }
    }
    var subtitle: String {
        switch self {
        case .compoundLifts: return "Bench, squat, deadlift, row"
        case .isolation: return "Curls, flies, raises, extensions"
        case .calisthenics: return "Pullups, pushups, dips, L-sits"
        case .olympicLifts: return "Cleans, snatches, jerks"
        case .cardioIntervals: return "HIIT, sprints, rounds"
        case .steadyCardio: return "Running, cycling, swimming"
        case .mobility: return "Yoga, stretching, recovery"
        case .sports: return "Basketball, soccer, climbing"
        case .plyometrics: return "Jumps, explosive movement"
        case .machines: return "Cable machines, hammer strength"
        }
    }
    var icon: String {
        switch self {
        case .compoundLifts: return "figure.strengthtraining.traditional"
        case .isolation: return "dumbbell.fill"
        case .calisthenics: return "figure.strengthtraining.functional"
        case .olympicLifts: return "figure.highintensity.intervaltraining"
        case .cardioIntervals: return "bolt.heart"
        case .steadyCardio: return "figure.run"
        case .mobility: return "figure.cooldown"
        case .sports: return "sportscourt"
        case .plyometrics: return "figure.jumprope"
        case .machines: return "gearshape.2"
        }
    }
}

// MARK: Obstacles (Screen 15)

enum Obstacle: String, Codable, CaseIterable, Identifiable {
    case unsure, consistency, plateau, time, motivation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .unsure: return "Don't know what to do"
        case .consistency: return "Can't stay consistent"
        case .plateau: return "Hit a plateau"
        case .time: return "Time"
        case .motivation: return "Motivation"
        }
    }
    var icon: String {
        switch self {
        case .unsure: return "questionmark.circle"
        case .consistency: return "calendar"
        case .plateau: return "chart.line.flattrend.xyaxis"
        case .time: return "clock"
        case .motivation: return "flame"
        }
    }
}

// MARK: Session length (Screen 16)

enum SessionLength: String, Codable, CaseIterable, Identifiable {
    case thirty, fortyFive, sixty, ninetyPlus
    var id: String { rawValue }
    var minutes: Int {
        switch self {
        case .thirty: return 30
        case .fortyFive: return 45
        case .sixty: return 60
        case .ninetyPlus: return 90
        }
    }
    var displayName: String {
        switch self {
        case .thirty: return "30 minutes"
        case .fortyFive: return "45 minutes"
        case .sixty: return "60 minutes"
        case .ninetyPlus: return "90+ minutes"
        }
    }
}

// MARK: Prior attempts (Screen 20)

enum PriorAttempt: String, Codable, CaseIterable, Identifiable {
    // Intentional ordering: positive/specific options first, "Nothing" last
    // so users don't accidentally tap it as the first visible option.
    case otherApps, trainer, youtube, onlinePrograms, nothing
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .otherApps: return "Other fitness apps"
        case .trainer: return "Personal trainer"
        case .youtube: return "YouTube workouts"
        case .onlinePrograms: return "Online programs"
        case .nothing: return "This is my first try"
        }
    }
    var icon: String {
        switch self {
        case .otherApps: return "square.grid.2x2"
        case .trainer: return "person.fill"
        case .youtube: return "play.rectangle"
        case .onlinePrograms: return "globe"
        case .nothing: return "sparkle"
        }
    }
}

// MARK: Goals — what the user wants to build

enum Goal: String, Codable, CaseIterable, Identifiable {
    case buildMuscle, loseFat, getDefined, getStronger, athletic, feelBetter
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .buildMuscle: return "Build muscle"
        case .loseFat: return "Lose fat"
        case .getDefined: return "Get defined"
        case .getStronger: return "Get stronger"
        case .athletic: return "Become athletic"
        case .feelBetter: return "Feel better in my body"
        }
    }
    var subtitle: String {
        switch self {
        case .buildMuscle: return "Gain size. Fill out your frame."
        case .loseFat: return "Cut the layer. See your shape."
        case .getDefined: return "Carve detail and hardness."
        case .getStronger: return "Lift more. Move more weight."
        case .athletic: return "Speed, explosiveness, agility."
        case .feelBetter: return "Confidence, energy, presence."
        }
    }
    var icon: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .loseFat: return "flame"
        case .getDefined: return "square.split.diagonal.fill"
        case .getStronger: return "bolt.fill"
        case .athletic: return "figure.run"
        case .feelBetter: return "heart.fill"
        }
    }
}

// MARK: Target body areas

enum TargetArea: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, arms, core, legs, glutes, fullBody
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .core: return "Core"
        case .legs: return "Legs"
        case .glutes: return "Glutes"
        case .fullBody: return "Full body"
        }
    }
    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.stand.line.dotted.figure.stand"
        case .shoulders: return "figure.wrestling"
        case .arms: return "figure.boxing"
        case .core: return "figure.core.training"
        case .legs: return "figure.strengthtraining.traditional"
        case .glutes: return "figure.pilates"
        case .fullBody: return "figure.stand"
        }
    }
}

// MARK: Workout time — when during the day

enum WorkoutTime: String, Codable, CaseIterable, Identifiable {
    case earlyMorning, morning, lunch, afternoon, evening, lateNight, varies
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .earlyMorning: return "Early morning"
        case .morning: return "Morning"
        case .lunch: return "Lunchtime"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .lateNight: return "Late night"
        case .varies: return "Different each day"
        }
    }
    var subtitle: String {
        switch self {
        case .earlyMorning: return "5–7 am"
        case .morning: return "7–10 am"
        case .lunch: return "11 am – 2 pm"
        case .afternoon: return "2–5 pm"
        case .evening: return "5–9 pm"
        case .lateNight: return "9 pm – midnight"
        case .varies: return "We'll stay flexible"
        }
    }
    var icon: String {
        switch self {
        case .earlyMorning: return "sunrise"
        case .morning: return "sun.max"
        case .lunch: return "fork.knife"
        case .afternoon: return "sun.min"
        case .evening: return "sun.horizon"
        case .lateNight: return "moon.stars"
        case .varies: return "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: Motivation (Screen 5)

enum Motivation: String, Codable, CaseIterable, Identifiable {
    case discipline, aesthetic, strength, confidence, recognition
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .discipline: return "Discipline"
        case .aesthetic: return "Aesthetic"
        case .strength: return "Strength"
        case .confidence: return "Confidence"
        case .recognition: return "Recognition"
        }
    }
    var icon: String {
        switch self {
        case .discipline: return "shield.fill"
        case .aesthetic: return "figure.stand"
        case .strength: return "bolt.fill"
        case .confidence: return "crown.fill"
        case .recognition: return "star.fill"
        }
    }
}
