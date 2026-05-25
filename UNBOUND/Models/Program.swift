import Foundation

struct TrainingProgram: Codable, Identifiable {
    let id: String
    let scanId: String
    let analysisId: String
    let userId: String
    let createdAt: Date
    var name: String
    var description: String
    var durationDays: Int = 28
    var days: [ProgramDay]
    var nutritionPlan: NutritionPlan
    var recoveryPlan: RecoveryPlan
    var difficultyLevel: DifficultyLevel
    var requiredEquipment: [String]
    var estimatedDailyMinutes: Int
    var rationale: ProgramRationale?
    var arcs: [Arc]
    var currentArcId: String?

    var currentArc: Arc? {
        guard let currentArcId else { return arcs.last }
        return arcs.first { $0.id == currentArcId } ?? arcs.last
    }

    init(
        id: String,
        scanId: String,
        analysisId: String,
        userId: String,
        createdAt: Date,
        name: String,
        description: String,
        durationDays: Int = 28,
        days: [ProgramDay],
        nutritionPlan: NutritionPlan,
        recoveryPlan: RecoveryPlan,
        difficultyLevel: DifficultyLevel,
        requiredEquipment: [String],
        estimatedDailyMinutes: Int,
        rationale: ProgramRationale? = nil,
        arcs: [Arc] = [],
        currentArcId: String? = nil
    ) {
        self.id = id
        self.scanId = scanId
        self.analysisId = analysisId
        self.userId = userId
        self.createdAt = createdAt
        self.name = name
        self.description = description
        self.durationDays = durationDays
        self.days = days
        self.nutritionPlan = nutritionPlan
        self.recoveryPlan = recoveryPlan
        self.difficultyLevel = difficultyLevel
        self.requiredEquipment = requiredEquipment
        self.estimatedDailyMinutes = estimatedDailyMinutes
        self.rationale = rationale
        self.arcs = arcs
        self.currentArcId = currentArcId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case scanId
        case analysisId
        case userId
        case createdAt
        case name
        case description
        case durationDays
        case days
        case nutritionPlan
        case recoveryPlan
        case difficultyLevel
        case requiredEquipment
        case estimatedDailyMinutes
        case rationale
        case arcs
        case currentArcId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        scanId = try c.decode(String.self, forKey: .scanId)
        analysisId = try c.decode(String.self, forKey: .analysisId)
        userId = try c.decode(String.self, forKey: .userId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        durationDays = try c.decodeIfPresent(Int.self, forKey: .durationDays) ?? 28
        days = try c.decode([ProgramDay].self, forKey: .days)
        nutritionPlan = try c.decode(NutritionPlan.self, forKey: .nutritionPlan)
        recoveryPlan = try c.decode(RecoveryPlan.self, forKey: .recoveryPlan)
        difficultyLevel = try c.decode(DifficultyLevel.self, forKey: .difficultyLevel)
        requiredEquipment = try c.decode([String].self, forKey: .requiredEquipment)
        estimatedDailyMinutes = try c.decode(Int.self, forKey: .estimatedDailyMinutes)
        rationale = try c.decodeIfPresent(ProgramRationale.self, forKey: .rationale)
        arcs = try c.decodeIfPresent([Arc].self, forKey: .arcs) ?? []
        currentArcId = try c.decodeIfPresent(String.self, forKey: .currentArcId)
    }
}

enum DifficultyLevel: String, Codable {
    case beginner, intermediate, advanced
}

struct ProgramDay: Codable, Identifiable, Hashable {
    let id: String
    let dayNumber: Int
    var label: String
    var isRestDay: Bool
    var workout: Workout?
    var sessionRole: SessionRole
    var savedWorkoutId: UUID?
    var nutritionOverride: DayNutrition?
    var recoveryActivities: [RecoveryActivity]

    init(
        id: String,
        dayNumber: Int,
        label: String,
        isRestDay: Bool,
        workout: Workout?,
        sessionRole: SessionRole? = nil,
        savedWorkoutId: UUID? = nil,
        nutritionOverride: DayNutrition?,
        recoveryActivities: [RecoveryActivity]
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.label = label
        self.isRestDay = isRestDay
        self.workout = workout
        self.sessionRole = sessionRole ?? (isRestDay ? .rest : .custom("unspecified"))
        self.savedWorkoutId = savedWorkoutId
        self.nutritionOverride = nutritionOverride
        self.recoveryActivities = recoveryActivities
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case dayNumber
        case label
        case isRestDay
        case workout
        case sessionRole
        case savedWorkoutId
        case nutritionOverride
        case recoveryActivities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        dayNumber = try c.decode(Int.self, forKey: .dayNumber)
        label = try c.decode(String.self, forKey: .label)
        isRestDay = try c.decode(Bool.self, forKey: .isRestDay)
        workout = try c.decodeIfPresent(Workout.self, forKey: .workout)
        sessionRole = try c.decodeIfPresent(SessionRole.self, forKey: .sessionRole)
            ?? (isRestDay ? .rest : .custom("unspecified"))
        savedWorkoutId = try c.decodeIfPresent(UUID.self, forKey: .savedWorkoutId)
        nutritionOverride = try c.decodeIfPresent(DayNutrition.self, forKey: .nutritionOverride)
        recoveryActivities = try c.decode([RecoveryActivity].self, forKey: .recoveryActivities)
    }
}

enum Wave: String, Codable, Hashable, Sendable {
    case wave1
    case wave2
}

enum ArcState: String, Codable, Hashable, Sendable {
    case planned
    case active
    case checkpointDue
    case complete
}

struct Arc: Codable, Identifiable, Hashable, Sendable {
    static let durationDays = 28
    static let waveLengthDays = 14

    let id: String
    let programId: String
    let startDate: Date
    var state: ArcState
    let sourceArcID: String?

    var endDate: Date {
        Calendar.gregorianArc.date(byAdding: .day, value: Self.durationDays, to: startDate) ?? startDate
    }

    var wave1Range: ClosedRange<Int> { 1...Self.waveLengthDays }
    var wave2Range: ClosedRange<Int> { (Self.waveLengthDays + 1)...Self.durationDays }

    init(
        id: String = UUID().uuidString,
        programId: String,
        startDate: Date,
        state: ArcState = .active,
        sourceArcID: String? = nil
    ) {
        self.id = id
        self.programId = programId
        self.startDate = startDate
        self.state = state
        self.sourceArcID = sourceArcID
    }

    func dayNumber(asOf date: Date, calendar: Calendar = .gregorianArc) -> Int? {
        let start = calendar.startOfDay(for: startDate)
        let target = calendar.startOfDay(for: date)
        let elapsed = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        guard elapsed >= 0, elapsed < Self.durationDays else { return nil }
        return elapsed + 1
    }

    func currentWave(asOf date: Date, calendar: Calendar = .gregorianArc) -> Wave? {
        guard let day = dayNumber(asOf: date, calendar: calendar) else { return nil }
        return day <= Self.waveLengthDays ? .wave1 : .wave2
    }
}

enum ProgramBodyRegion: Hashable, Sendable {
    case pull
    case push
    case legs
    case core
    case posterior
    case shoulders
    case other(String)

    var storageValue: String {
        switch self {
        case .pull: return "pull"
        case .push: return "push"
        case .legs: return "legs"
        case .core: return "core"
        case .posterior: return "posterior"
        case .shoulders: return "shoulders"
        case .other(let value): return "other:\(value)"
        }
    }

    var displayName: String {
        switch self {
        case .pull: return "Pull"
        case .push: return "Push"
        case .legs: return "Legs"
        case .core: return "Core"
        case .posterior: return "Posterior Chain"
        case .shoulders: return "Shoulders"
        case .other(let value): return value.capitalized
        }
    }

    static func from(muscleGroup: MuscleGroup) -> ProgramBodyRegion {
        switch muscleGroup {
        case .back, .lats, .traps, .forearms:
            return .pull
        case .chest, .arms:
            return .push
        case .legs, .calves:
            return .legs
        case .glutes:
            return .posterior
        case .core:
            return .core
        case .shoulders:
            return .shoulders
        case .neck:
            return .other("neck")
        }
    }

}

extension ProgramBodyRegion: Codable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "pull": self = .pull
        case "push": self = .push
        case "legs": self = .legs
        case "core": self = .core
        case "posterior": self = .posterior
        case "shoulders": self = .shoulders
        default:
            if value.hasPrefix("other:") {
                self = .other(String(value.dropFirst("other:".count)))
            } else {
                self = .other(value)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

struct RegionLoad: Codable, Equatable, Sendable {
    private(set) var loads: [ProgramBodyRegion: Double]

    init(_ loads: [ProgramBodyRegion: Double] = [:]) {
        self.loads = loads.filter { $0.value != 0 }
    }

    subscript(region: ProgramBodyRegion) -> Double {
        get { loads[region] ?? 0 }
        set {
            if newValue == 0 {
                loads.removeValue(forKey: region)
            } else {
                loads[region] = newValue
            }
        }
    }

    mutating func add(_ amount: Double, to region: ProgramBodyRegion) {
        self[region] = self[region] + amount
    }

    func adding(_ amount: Double, to region: ProgramBodyRegion) -> RegionLoad {
        var copy = self
        copy.add(amount, to: region)
        return copy
    }

    func trimRecommendations(over budget: RegionLoad) -> [ProgramBodyRegion: Double] {
        loads.reduce(into: [:]) { result, entry in
            let excess = entry.value - budget[entry.key]
            if excess > 0 {
                result[entry.key] = excess
            }
        }
    }
}

enum SessionRole: Hashable, Sendable {
    case rest
    case pull
    case push
    case legs
    case upper
    case lower
    case fullBody
    case squatFocus
    case pullFocus
    case pushVertical
    case pushHorizontal
    case broChest
    case broBack
    case broShoulders
    case broArms
    case cardio
    case skillOnly
    case custom(String)

    var storageValue: String {
        switch self {
        case .rest: return "rest"
        case .pull: return "pull"
        case .push: return "push"
        case .legs: return "legs"
        case .upper: return "upper"
        case .lower: return "lower"
        case .fullBody: return "full_body"
        case .squatFocus: return "squat_focus"
        case .pullFocus: return "pull_focus"
        case .pushVertical: return "push_vertical"
        case .pushHorizontal: return "push_horizontal"
        case .broChest: return "bro_chest"
        case .broBack: return "bro_back"
        case .broShoulders: return "bro_shoulders"
        case .broArms: return "bro_arms"
        case .cardio: return "cardio"
        case .skillOnly: return "skill_only"
        case .custom(let value): return "custom:\(value)"
        }
    }

    var displayName: String {
        switch self {
        case .rest: return "Rest"
        case .pull: return "Pull"
        case .push: return "Push"
        case .legs: return "Legs"
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .fullBody: return "Full Body"
        case .squatFocus: return "Squat Focus"
        case .pullFocus: return "Pull Focus"
        case .pushVertical: return "Vertical Push"
        case .pushHorizontal: return "Horizontal Push"
        case .broChest: return "Chest"
        case .broBack: return "Back"
        case .broShoulders: return "Shoulders"
        case .broArms: return "Arms"
        case .cardio: return "Cardio"
        case .skillOnly: return "Skill"
        case .custom(let value): return value.capitalized
        }
    }

    static func fromStorageValue(_ raw: String?) -> SessionRole? {
        guard let raw else { return nil }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "rest": return .rest
        case "pull": return .pull
        case "push": return .push
        case "legs", "leg": return .legs
        case "upper": return .upper
        case "lower": return .lower
        case "full_body", "fullbody": return .fullBody
        case "squat_focus": return .squatFocus
        case "pull_focus": return .pullFocus
        case "push_vertical": return .pushVertical
        case "push_horizontal": return .pushHorizontal
        case "bro_chest": return .broChest
        case "bro_back": return .broBack
        case "bro_shoulders": return .broShoulders
        case "bro_arms": return .broArms
        case "cardio": return .cardio
        case "skill_only": return .skillOnly
        default:
            if normalized.hasPrefix("custom:") {
                return .custom(String(normalized.dropFirst("custom:".count)))
            }
            return .custom(normalized)
        }
    }
}

extension SessionRole: Codable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "rest": self = .rest
        case "pull": self = .pull
        case "push": self = .push
        case "legs": self = .legs
        case "upper": self = .upper
        case "lower": self = .lower
        case "full_body": self = .fullBody
        case "squat_focus": self = .squatFocus
        case "pull_focus": self = .pullFocus
        case "push_vertical": self = .pushVertical
        case "push_horizontal": self = .pushHorizontal
        case "bro_chest": self = .broChest
        case "bro_back": self = .broBack
        case "bro_shoulders": self = .broShoulders
        case "bro_arms": self = .broArms
        case "cardio": self = .cardio
        case "skill_only": self = .skillOnly
        default:
            if value.hasPrefix("custom:") {
                self = .custom(String(value.dropFirst("custom:".count)))
            } else {
                self = .custom(value)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

private extension Calendar {
    static var gregorianArc: Calendar {
        Calendar(identifier: .gregorian)
    }
}
