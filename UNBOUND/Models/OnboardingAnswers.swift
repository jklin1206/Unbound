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
        case .male: return L10n.onboardingAnswer(group: "gender", id: rawValue, field: "displayName", defaultValue: "Male")
        case .female: return L10n.onboardingAnswer(group: "gender", id: rawValue, field: "displayName", defaultValue: "Female")
        case .unspecified: return L10n.onboardingAnswer(group: "gender", id: rawValue, field: "displayName", defaultValue: "Prefer not to say")
        }
    }
}

// MARK: Body type (Screen 10)

enum BodyType: String, Codable, CaseIterable, Identifiable {
    case skinny, skinnyFat, alreadyLifting
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .skinny: return L10n.onboardingAnswer(group: "bodyType", id: rawValue, field: "displayName", defaultValue: "Skinny")
        case .skinnyFat: return L10n.onboardingAnswer(group: "bodyType", id: rawValue, field: "displayName", defaultValue: "Skinny-fat")
        case .alreadyLifting: return L10n.onboardingAnswer(group: "bodyType", id: rawValue, field: "displayName", defaultValue: "Already lifting")
        }
    }
    var subtitle: String {
        switch self {
        case .skinny: return L10n.onboardingAnswer(group: "bodyType", id: rawValue, field: "subtitle", defaultValue: "Lean frame, low muscle")
        case .skinnyFat: return L10n.onboardingAnswer(group: "bodyType", id: rawValue, field: "subtitle", defaultValue: "Soft look without density")
        case .alreadyLifting: return L10n.onboardingAnswer(group: "bodyType", id: rawValue, field: "subtitle", defaultValue: "Training experience present")
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
        case .never: return L10n.onboardingAnswer(group: "experience", id: rawValue, field: "displayName", defaultValue: "Never trained")
        case .tried: return L10n.onboardingAnswer(group: "experience", id: rawValue, field: "displayName", defaultValue: "Tried once")
        case .used: return L10n.onboardingAnswer(group: "experience", id: rawValue, field: "displayName", defaultValue: "Used to train")
        case .current: return L10n.onboardingAnswer(group: "experience", id: rawValue, field: "displayName", defaultValue: "Currently training")
        }
    }
}

// MARK: Training frequency (Screens 12, 13)

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case zero, oneToTwo, threeToFour, fivePlus
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .zero: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "displayName", defaultValue: "0 days")
        case .oneToTwo: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "displayName", defaultValue: "1–2 days")
        case .threeToFour: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "displayName", defaultValue: "3–4 days")
        case .fivePlus: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "displayName", defaultValue: "5+ days")
        }
    }
    var subtitle: String {
        switch self {
        case .zero: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "subtitle", defaultValue: "Starting fresh")
        case .oneToTwo: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "subtitle", defaultValue: "Occasional")
        case .threeToFour: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "subtitle", defaultValue: "Consistent")
        case .fivePlus: return L10n.onboardingAnswer(group: "frequency", id: rawValue, field: "subtitle", defaultValue: "Heavy volume")
        }
    }
}

enum TargetFrequency: String, Codable, CaseIterable, Identifiable {
    case three, four, five, six
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .three: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "displayName", defaultValue: "3 days / week")
        case .four: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "displayName", defaultValue: "4 days / week")
        case .five: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "displayName", defaultValue: "5 days / week")
        case .six: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "displayName", defaultValue: "6 days / week")
        }
    }
    var subtitle: String {
        switch self {
        case .three: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "subtitle", defaultValue: "Balanced baseline")
        case .four: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "subtitle", defaultValue: "Recommended")
        case .five: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "subtitle", defaultValue: "Aggressive")
        case .six: return L10n.onboardingAnswer(group: "targetFrequency", id: rawValue, field: "subtitle", defaultValue: "Elite volume")
        }
    }
}

extension TargetFrequency {
    /// Integer count used for schedule planning (number of training days per week).
    var numericCount: Int {
        switch self {
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        }
    }
}

// MARK: Equipment (Screen 14)

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case fullGym
    case machines         // cables and machines (includes gym but without barbell)
    case barbell          // barbell + rack
    case dumbbells
    case bench
    case pullupBar
    case bodyweight
    case bands
    // Legacy — kept for backward compat with pre-redesign stored profiles:
    case homeWeights

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullGym: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Full gym")
        case .machines: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Cables / machines")
        case .barbell: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Barbell + rack")
        case .dumbbells: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Dumbbells")
        case .bench: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Bench")
        case .pullupBar: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Pull-up bar")
        case .bodyweight: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Bodyweight only")
        case .bands: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Resistance bands")
        case .homeWeights: return L10n.onboardingAnswer(group: "equipment", id: rawValue, field: "displayName", defaultValue: "Home weights")
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .machines: return "gearshape.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbells: return "dumbbell"
        case .bench: return "bed.double.fill"
        case .pullupBar: return "figure.play"
        case .bodyweight: return "figure.arms.open"
        case .bands: return "line.diagonal"
        case .homeWeights: return "house.fill"
        }
    }
}

// MARK: Exercise styles — what types of training the user enjoys

enum ExerciseStyle: String, Codable, CaseIterable, Identifiable {
    case compoundLifts, isolation, calisthenics, olympicLifts, cardioIntervals, steadyCardio, mobility, sports, plyometrics, machines
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .compoundLifts: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Compound lifts")
        case .isolation: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Isolation work")
        case .calisthenics: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Calisthenics")
        case .olympicLifts: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Olympic lifts")
        case .cardioIntervals: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Cardio intervals")
        case .steadyCardio: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Steady-state cardio")
        case .mobility: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Mobility & stretching")
        case .sports: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Sports & drills")
        case .plyometrics: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Plyometrics")
        case .machines: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "displayName", defaultValue: "Machine work")
        }
    }
    var subtitle: String {
        switch self {
        case .compoundLifts: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Bench, squat, deadlift, row")
        case .isolation: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Curls, flies, raises, extensions")
        case .calisthenics: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Pullups, pushups, dips, L-sits")
        case .olympicLifts: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Cleans, snatches, jerks")
        case .cardioIntervals: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "HIIT, sprints, rounds")
        case .steadyCardio: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Running, cycling, swimming")
        case .mobility: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Yoga, stretching, recovery")
        case .sports: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Basketball, soccer, climbing")
        case .plyometrics: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Jumps, explosive movement")
        case .machines: return L10n.onboardingAnswer(group: "exerciseStyle", id: rawValue, field: "subtitle", defaultValue: "Cable machines, hammer strength")
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
        case .unsure: return L10n.onboardingAnswer(group: "obstacle", id: rawValue, field: "displayName", defaultValue: "Don't know what to do")
        case .consistency: return L10n.onboardingAnswer(group: "obstacle", id: rawValue, field: "displayName", defaultValue: "Can't stay consistent")
        case .plateau: return L10n.onboardingAnswer(group: "obstacle", id: rawValue, field: "displayName", defaultValue: "Hit a plateau")
        case .time: return L10n.onboardingAnswer(group: "obstacle", id: rawValue, field: "displayName", defaultValue: "Time")
        case .motivation: return L10n.onboardingAnswer(group: "obstacle", id: rawValue, field: "displayName", defaultValue: "Motivation")
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
        case .thirty: return L10n.onboardingAnswer(group: "sessionLength", id: rawValue, field: "displayName", defaultValue: "30 minutes")
        case .fortyFive: return L10n.onboardingAnswer(group: "sessionLength", id: rawValue, field: "displayName", defaultValue: "45 minutes")
        case .sixty: return L10n.onboardingAnswer(group: "sessionLength", id: rawValue, field: "displayName", defaultValue: "60 minutes")
        case .ninetyPlus: return L10n.onboardingAnswer(group: "sessionLength", id: rawValue, field: "displayName", defaultValue: "90+ minutes")
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
        case .otherApps: return L10n.onboardingAnswer(group: "priorAttempt", id: rawValue, field: "displayName", defaultValue: "Other fitness apps")
        case .trainer: return L10n.onboardingAnswer(group: "priorAttempt", id: rawValue, field: "displayName", defaultValue: "Personal trainer")
        case .youtube: return L10n.onboardingAnswer(group: "priorAttempt", id: rawValue, field: "displayName", defaultValue: "YouTube workouts")
        case .onlinePrograms: return L10n.onboardingAnswer(group: "priorAttempt", id: rawValue, field: "displayName", defaultValue: "Online programs")
        case .nothing: return L10n.onboardingAnswer(group: "priorAttempt", id: rawValue, field: "displayName", defaultValue: "This is my first try")
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
        case .buildMuscle: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "displayName", defaultValue: "Build muscle")
        case .loseFat: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "displayName", defaultValue: "Lose fat")
        case .getDefined: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "displayName", defaultValue: "Get defined")
        case .getStronger: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "displayName", defaultValue: "Get stronger")
        case .athletic: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "displayName", defaultValue: "Become athletic")
        case .feelBetter: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "displayName", defaultValue: "Feel better in my body")
        }
    }
    var subtitle: String {
        switch self {
        case .buildMuscle: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "subtitle", defaultValue: "Gain size. Fill out your frame.")
        case .loseFat: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "subtitle", defaultValue: "Cut the layer. See your shape.")
        case .getDefined: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "subtitle", defaultValue: "Carve detail and hardness.")
        case .getStronger: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "subtitle", defaultValue: "Lift more. Move more weight.")
        case .athletic: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "subtitle", defaultValue: "Speed, explosiveness, conditioning.")
        case .feelBetter: return L10n.onboardingAnswer(group: "goal", id: rawValue, field: "subtitle", defaultValue: "Confidence, energy, presence.")
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
        case .chest: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Chest")
        case .back: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Back")
        case .shoulders: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Shoulders")
        case .arms: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Arms")
        case .core: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Core")
        case .legs: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Legs")
        case .glutes: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Glutes")
        case .fullBody: return L10n.onboardingAnswer(group: "targetArea", id: rawValue, field: "displayName", defaultValue: "Full body")
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
        case .earlyMorning: return L10n.string(.workoutTimeEarlyMorningDisplayName, defaultValue: "Early morning")
        case .morning: return L10n.string(.workoutTimeMorningDisplayName, defaultValue: "Morning")
        case .lunch: return L10n.string(.workoutTimeLunchDisplayName, defaultValue: "Lunchtime")
        case .afternoon: return L10n.string(.workoutTimeAfternoonDisplayName, defaultValue: "Afternoon")
        case .evening: return L10n.string(.workoutTimeEveningDisplayName, defaultValue: "Evening")
        case .lateNight: return L10n.string(.workoutTimeLateNightDisplayName, defaultValue: "Late night")
        case .varies: return L10n.string(.workoutTimeVariesDisplayName, defaultValue: "Different each day")
        }
    }
    var subtitle: String {
        switch self {
        case .earlyMorning: return L10n.string(.workoutTimeEarlyMorningSubtitle, defaultValue: "5–7 am")
        case .morning: return L10n.string(.workoutTimeMorningSubtitle, defaultValue: "7–10 am")
        case .lunch: return L10n.string(.workoutTimeLunchSubtitle, defaultValue: "11 am – 2 pm")
        case .afternoon: return L10n.string(.workoutTimeAfternoonSubtitle, defaultValue: "2–5 pm")
        case .evening: return L10n.string(.workoutTimeEveningSubtitle, defaultValue: "5–9 pm")
        case .lateNight: return L10n.string(.workoutTimeLateNightSubtitle, defaultValue: "9 pm – midnight")
        case .varies: return L10n.string(.workoutTimeVariesSubtitle, defaultValue: "We'll stay flexible")
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

    /// Hour (24h) to fire the workout reminder for this time preference.
    var notificationHour: Int {
        switch self {
        case .earlyMorning: return 6
        case .morning:      return 8
        case .lunch:        return 12
        case .afternoon:    return 15
        case .evening:      return 18
        case .lateNight:    return 21
        case .varies:       return 8
        }
    }
}

// MARK: Motivation (Screen 5)

enum Motivation: String, Codable, CaseIterable, Identifiable {
    case discipline, aesthetic, strength, confidence, recognition
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .discipline: return L10n.onboardingAnswer(group: "motivation", id: rawValue, field: "displayName", defaultValue: "Discipline")
        case .aesthetic: return L10n.onboardingAnswer(group: "motivation", id: rawValue, field: "displayName", defaultValue: "Aesthetic")
        case .strength: return L10n.onboardingAnswer(group: "motivation", id: rawValue, field: "displayName", defaultValue: "Strength")
        case .confidence: return L10n.onboardingAnswer(group: "motivation", id: rawValue, field: "displayName", defaultValue: "Confidence")
        case .recognition: return L10n.onboardingAnswer(group: "motivation", id: rawValue, field: "displayName", defaultValue: "Recognition")
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
