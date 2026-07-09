import SwiftUI

// MARK: - Program focus switch

struct ProgramFocusSwitchPresentation: Identifiable {
    let id = UUID()
    let currentStyle: TrainingStyle
    let currentEquipment: [Equipment]
    let currentExperience: Experience?
    let activeContext: ProgramTrainingContextOverride?
    let pendingContext: ProgramTrainingContextOverride?
}

enum ProgramFocusSwitchClearTarget {
    case daily(ProgramTrainingContextOverride)
    case pendingNextBlock(ProgramTrainingContextOverride)
}

enum ProgramFocusSwitchGear: String, CaseIterable, Identifiable {
    case fullGym
    case barbell
    case dumbbells
    case bench
    case machines
    case pullupBar
    case bands
    case dipStation
    case rings

    var id: String { rawValue }

    var equipment: Equipment {
        switch self {
        case .fullGym: return .fullGym
        case .barbell: return .barbell
        case .dumbbells: return .dumbbells
        case .bench: return .bench
        case .machines: return .machines
        case .pullupBar: return .pullupBar
        case .bands: return .bands
        case .dipStation: return .dipStation
        case .rings: return .rings
        }
    }

    var title: String {
        switch self {
        case .fullGym: return "Full gym"
        case .barbell: return "Barbell + rack"
        case .dumbbells: return "Dumbbells"
        case .bench: return "Bench"
        case .machines: return "Cables / machines"
        case .pullupBar: return "Pull-up bar"
        case .bands: return "Bands"
        case .dipStation: return "Dip station"
        case .rings: return "Rings"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGym: return "Unlocks the full loaded and machine catalog."
        case .barbell: return "Squat, bench, deadlift, overhead press, rows."
        case .dumbbells: return "Presses, rows, split squats, hinges, isolation."
        case .bench: return "Pressing, supported rows, step-ups, incline work."
        case .machines: return "Cable, machine, and selectorized substitutions."
        case .pullupBar: return "Pullups, hangs, leg raises, bar skills."
        case .bands: return "Assistance, rows, warmups, joint-friendly scaling."
        case .dipStation: return "Dips, supports, knee raises. Not implied by a pull-up bar."
        case .rings: return "Ring rows, supports, ring dips, ring skill work."
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbells: return "dumbbell"
        case .bench: return "rectangle.compress.vertical"
        case .machines: return "gearshape.fill"
        case .pullupBar: return "figure.play"
        case .bands: return "line.diagonal"
        case .dipStation: return "figure.strengthtraining.functional"
        case .rings: return "link.circle"
        }
    }

    var assetName: String {
        switch self {
        case .fullGym: return "exercise_visual_exercise_back-squat"
        case .barbell: return "exercise_visual_exercise_back-squat"
        case .dumbbells: return "exercise_visual_exercise_dumbbell-overhead-press"
        case .bench: return "exercise_visual_exercise_bench-press"
        case .machines: return "exercise_visual_exercise_lat-pulldown"
        case .pullupBar: return "exercise_visual_exercise_pullup"
        case .bands: return "exercise_visual_exercise_assisted-pullup-band"
        case .dipStation: return "exercise_visual_exercise_dip"
        case .rings: return "exercise_visual_exercise_ring-dip"
        }
    }
}

enum ProgramFocusSwitchModeChoice: String, CaseIterable, Identifiable {
    case calisthenics
    case lifting
    case hybrid

    var id: String { rawValue }

    var contextMode: ProgramTrainingContextMode {
        switch self {
        case .calisthenics: return .calisthenics
        case .lifting: return .lifting
        case .hybrid: return .hybrid
        }
    }

    var title: String {
        switch self {
        case .calisthenics: return "Calisthenics"
        case .lifting: return "Lifting"
        case .hybrid: return "Hybrid"
        }
    }

    var subtitle: String {
        switch self {
        case .calisthenics: return "Bodyweight-first progressions and skill work."
        case .lifting: return "Weights, cables, and machines based on available gear."
        case .hybrid: return "Skills plus weights in the same arc."
        }
    }

    var icon: String {
        switch self {
        case .calisthenics: return "figure.gymnastics"
        case .lifting: return "figure.strengthtraining.traditional"
        case .hybrid: return "arrow.triangle.2.circlepath"
        }
    }

    var assetName: String? {
        switch self {
        case .calisthenics: return "exercise_visual_exercise_pullup"
        case .lifting: return "exercise_visual_exercise_back-squat"
        case .hybrid: return "exercise_visual_exercise_weighted-pullup"
        }
    }

    var needsAbility: Bool {
        self == .calisthenics || self == .hybrid
    }

    var gearOptions: [ProgramFocusSwitchGear] {
        switch self {
        case .calisthenics:
            return [.pullupBar, .bands, .dipStation, .rings]
        case .lifting:
            return [.fullGym, .barbell, .dumbbells, .bench, .machines]
        case .hybrid:
            return [.fullGym, .barbell, .dumbbells, .bench, .machines, .pullupBar, .bands, .dipStation, .rings]
        }
    }

    static func defaultChoice(for style: TrainingStyle) -> ProgramFocusSwitchModeChoice {
        switch style {
        case .bodyweight: return .calisthenics
        case .freeWeights: return .lifting
        case .hybrid: return .hybrid
        case .machines: return .lifting
        }
    }
}

enum ProgramFocusSwitchScopeChoice: String, CaseIterable, Identifiable {
    case todayOnly
    case thisWeek
    case nextBlock
    case ongoing

    var id: String { rawValue }

    var scope: ProgramTrainingContextScope {
        switch self {
        case .todayOnly: return .todayOnly
        case .thisWeek: return .thisWeek
        case .nextBlock: return .nextBlock
        case .ongoing: return .ongoing
        }
    }

    var title: String {
        switch self {
        case .todayOnly: return "Today"
        case .thisWeek: return "Week"
        case .nextBlock: return "Next arc"
        case .ongoing: return "Active arc"
        }
    }

    var icon: String {
        switch self {
        case .todayOnly: return "sun.max.fill"
        case .thisWeek: return "calendar"
        case .nextBlock: return "calendar.badge.plus"
        case .ongoing: return "arrow.triangle.2.circlepath"
        }
    }
}

enum ProgramFocusSwitchAbilityLevel: String, CaseIterable, Identifiable {
    case foundation
    case baseStrength
    case skillReady

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundation: return "Foundation"
        case .baseStrength: return "Base strength"
        case .skillReady: return "Skill-ready"
        }
    }

    var subtitle: String {
        switch self {
        case .foundation:
            return "No strict pullups yet, pushups still building, joints need easy volume."
        case .baseStrength:
            return "Some strict pushups, assisted or negative pullups, basic holds."
        case .skillReady:
            return "Strict reps are owned; skills can enter as serious practice."
        }
    }

    var icon: String {
        switch self {
        case .foundation: return "figure.core.training"
        case .baseStrength: return "figure.strengthtraining.functional"
        case .skillReady: return "figure.gymnastics"
        }
    }

    var assetName: String {
        switch self {
        case .foundation: return "exercise_visual_exercise_bodyweight-squat"
        case .baseStrength: return "exercise_visual_exercise_assisted-pullup-band"
        case .skillReady: return "exercise_visual_exercise_straddle-planche"
        }
    }

    var experience: Experience {
        switch self {
        case .foundation: return .never
        case .baseStrength: return .tried
        case .skillReady: return .current
        }
    }

    var programmingCopy: String {
        switch self {
        case .foundation:
            return "Programs beginner progressions only. No dips, muscle-ups, lever work, or handstand pressure unless the catalog has a true entry path."
        case .baseStrength:
            return "Allows beginner and intermediate progressions. Advanced skills stay out until logs prove the base."
        case .skillReady:
            return "Allows advanced calisthenics progressions when your equipment supports them. Elite work still stays gated."
        }
    }

    static func defaultLevel(for experience: Experience?) -> ProgramFocusSwitchAbilityLevel {
        switch experience {
        case .never, .none:
            return .foundation
        case .tried, .used:
            return .baseStrength
        case .current:
            return .skillReady
        }
    }
}

struct ProgramFocusSwitchSelection {
    let mode: ProgramTrainingContextMode
    let scope: ProgramTrainingContextScope
    let equipment: Set<Equipment>
    let abilityLevel: ProgramFocusSwitchAbilityLevel
    let selectedExperience: Experience?

    var sortedEquipment: [Equipment] {
        ProgramTrainingContextResolver.sortedEquipment(equipment)
    }

    var contextSelection: ProgramTrainingContextSelection {
        ProgramTrainingContextSelection(
            scope: scope,
            mode: mode,
            equipment: equipment,
            experience: selectedExperience
        )
    }
}
