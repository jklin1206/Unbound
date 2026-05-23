import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    var email: String?
    var displayName: String?
    var createdAt: Date
    var onboardingCompleted: Bool
    var totalScans: Int
    var currentProgramId: String?
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var biologicalSex: BiologicalSex?

    // MARK: UNBOUND onboarding answers (all optional, additive to schema)
    var displayHandle: String?
    var gender: Gender?
    var motivations: [Motivation]?
    var currentBodyType: BodyType?
    var experience: Experience?
    var currentFrequency: Frequency?
    var targetFrequency: TargetFrequency?
    var equipment: [Equipment]?
    var obstacles: [Obstacle]?
    var sessionLength: SessionLength?
    var priorAttempts: [PriorAttempt]?
    var dietQuality: Int?
    var sleepQuality: Int?
    var stressLevel: Int?
    var commitment: Int?
    var goals: [Goal]?
    var targetAreas: [TargetArea]?
    var workoutTime: WorkoutTime?
    var exerciseStyles: [ExerciseStyle]?

    // MARK: Program Redesign (2026-04-20)
    var trainingFeedbackMode: TrainingFeedbackMode?
    var trainingStyleOverride: TrainingStyle?
    var trainingDays: Set<Weekday>?
    var cutMode: CutMode = CutMode()

    // MARK: Initializers
    //
    // Swift stops synthesizing the memberwise init once any explicit init
    // is declared. The existing call sites (UserService, PreviewUserService,
    // LocalToSupabaseMigration, UnboundHomeView) rely on a 12-argument
    // memberwise constructor through `biologicalSex`, so we preserve that
    // shape explicitly. The onboarding and program-redesign fields stay as
    // property assignments after init.

    init(
        id: String,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date,
        onboardingCompleted: Bool,
        totalScans: Int,
        currentProgramId: String? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        age: Int? = nil,
        biologicalSex: BiologicalSex? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.onboardingCompleted = onboardingCompleted
        self.totalScans = totalScans
        self.currentProgramId = currentProgramId
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.age = age
        self.biologicalSex = biologicalSex
    }

    // MARK: Codable
    //
    // A custom `init(from:)` is required so legacy profiles persisted before
    // this redesign (which lack `cutMode`) still decode cleanly. Optional
    // fields decode to nil for free when keys are absent, but `cutMode` is
    // non-optional with a default, which Swift's synthesized decoder does not
    // handle — we fall back to `CutMode()` explicitly.

    private enum CodingKeys: String, CodingKey {
        case id, email, displayName, createdAt, onboardingCompleted, totalScans
        case currentProgramId, heightCm, weightKg, age, biologicalSex
        case displayHandle, gender, motivations, currentBodyType, experience
        case currentFrequency, targetFrequency, equipment, obstacles, sessionLength
        case priorAttempts, dietQuality, sleepQuality, stressLevel, commitment
        case goals, targetAreas, workoutTime, exerciseStyles
        case trainingFeedbackMode, trainingStyleOverride, trainingDays, cutMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.email = try c.decodeIfPresent(String.self, forKey: .email)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.onboardingCompleted = try c.decode(Bool.self, forKey: .onboardingCompleted)
        self.totalScans = try c.decode(Int.self, forKey: .totalScans)
        self.currentProgramId = try c.decodeIfPresent(String.self, forKey: .currentProgramId)
        // Legacy field `preferredArchetype` may exist in persisted JSON — silently discard.
        self.heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm)
        self.weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        self.age = try c.decodeIfPresent(Int.self, forKey: .age)
        self.biologicalSex = try c.decodeIfPresent(BiologicalSex.self, forKey: .biologicalSex)

        self.displayHandle = try c.decodeIfPresent(String.self, forKey: .displayHandle)
        self.gender = try c.decodeIfPresent(Gender.self, forKey: .gender)
        self.motivations = try c.decodeIfPresent([Motivation].self, forKey: .motivations)
        self.currentBodyType = try c.decodeIfPresent(BodyType.self, forKey: .currentBodyType)
        self.experience = try c.decodeIfPresent(Experience.self, forKey: .experience)
        self.currentFrequency = try c.decodeIfPresent(Frequency.self, forKey: .currentFrequency)
        self.targetFrequency = try c.decodeIfPresent(TargetFrequency.self, forKey: .targetFrequency)
        self.equipment = try c.decodeIfPresent([Equipment].self, forKey: .equipment)
        self.obstacles = try c.decodeIfPresent([Obstacle].self, forKey: .obstacles)
        self.sessionLength = try c.decodeIfPresent(SessionLength.self, forKey: .sessionLength)
        self.priorAttempts = try c.decodeIfPresent([PriorAttempt].self, forKey: .priorAttempts)
        self.dietQuality = try c.decodeIfPresent(Int.self, forKey: .dietQuality)
        self.sleepQuality = try c.decodeIfPresent(Int.self, forKey: .sleepQuality)
        self.stressLevel = try c.decodeIfPresent(Int.self, forKey: .stressLevel)
        self.commitment = try c.decodeIfPresent(Int.self, forKey: .commitment)
        self.goals = try c.decodeIfPresent([Goal].self, forKey: .goals)
        self.targetAreas = try c.decodeIfPresent([TargetArea].self, forKey: .targetAreas)
        self.workoutTime = try c.decodeIfPresent(WorkoutTime.self, forKey: .workoutTime)
        self.exerciseStyles = try c.decodeIfPresent([ExerciseStyle].self, forKey: .exerciseStyles)

        self.trainingFeedbackMode = try c.decodeIfPresent(TrainingFeedbackMode.self, forKey: .trainingFeedbackMode)
        self.trainingStyleOverride = try c.decodeIfPresent(TrainingStyle.self, forKey: .trainingStyleOverride)
        self.trainingDays = try c.decodeIfPresent(Set<Weekday>.self, forKey: .trainingDays)
        self.cutMode = (try c.decodeIfPresent(CutMode.self, forKey: .cutMode)) ?? CutMode()
    }
}

enum BiologicalSex: String, Codable {
    case male, female
}
