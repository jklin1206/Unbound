import SwiftUI

@MainActor
final class ServiceContainer: ObservableObject {
    let auth: any AuthServiceProtocol
    let database: any DatabaseServiceProtocol
    let analytics: any AnalyticsServiceProtocol
    let subscription: any SubscriptionServiceProtocol
    let paywall: any PaywallServiceProtocol
    let user: any UserServiceProtocol
    let storage: any StorageServiceProtocol
    let network: any NetworkServiceProtocol
    let logging: LoggingService
    let bodyAnalysis: any BodyAnalysisServiceProtocol
    let programGeneration: any ProgramGenerationServiceProtocol
    let imageCapture: any ImageCaptureServiceProtocol
    let exercisePreference: any ExercisePreferenceServiceProtocol
    let customExercise: any CustomExerciseStoreProtocol
    let workoutLog: any WorkoutLogServiceProtocol
    let workingWeight: any WorkingWeightServiceProtocol
    let cardioLog: any CardioLogServiceProtocol
    let calibration: any CalibrationServiceProtocol
    let entitlement: EntitlementService
    let rank: any RankServiceProtocol
    let skin: any SkinServiceProtocol
    let sessionXP: any SessionXPServiceProtocol
    let badges: any BadgeServiceProtocol
    let programPhase: any ProgramPhaseEngineProtocol
    let attribute: any AttributeServiceProtocol
    let photoXP: any PhotoXPServiceProtocol
    let userSkillTier: UserSkillTierStore
    let liftTier: LiftTierService
    let scanCheckpointStore: ScanCheckpointStore
    let scanCheckpointService: ScanCheckpointService

    init() {
        self.logging = LoggingService.shared
        self.auth = AuthService.shared
        self.database = DatabaseService.shared
        self.analytics = AnalyticsService.shared
        self.subscription = SubscriptionService.shared
        self.paywall = PaywallService.shared
        self.network = NetworkService.shared
        self.storage = StorageService.shared
        self.user = SupabaseUserService.shared
        self.bodyAnalysis = BodyAnalysisService.shared
        self.programGeneration = ProgramGenerationService.shared
        self.imageCapture = ImageCaptureService()
        self.exercisePreference = ExercisePreferenceService.shared
        self.customExercise = CustomExerciseStore.shared
        self.workoutLog = SupabaseWorkoutLogService.shared
        self.workingWeight = WorkingWeightService.shared
        self.cardioLog = CardioLogService.shared
        self.calibration = CalibrationService.shared
        self.entitlement = EntitlementService.shared
        self.rank = RankService.shared
        self.skin = SkinService.shared
        self.sessionXP = SessionXPService.shared
        self.badges = BadgeService.shared
        self.programPhase = ProgramPhaseEngine.shared
        self.attribute = AttributeService.shared
        self.photoXP = PhotoXPService.shared
        self.userSkillTier = UserSkillTierStore.shared
        self.liftTier = LiftTierService.shared
        self.scanCheckpointStore = ScanCheckpointStore.shared
        self.scanCheckpointService = ScanCheckpointService.shared
    }

    init(
        auth: any AuthServiceProtocol,
        database: any DatabaseServiceProtocol,
        analytics: any AnalyticsServiceProtocol,
        subscription: any SubscriptionServiceProtocol,
        paywall: any PaywallServiceProtocol,
        user: any UserServiceProtocol,
        storage: any StorageServiceProtocol,
        network: any NetworkServiceProtocol,
        bodyAnalysis: any BodyAnalysisServiceProtocol,
        programGeneration: any ProgramGenerationServiceProtocol,
        imageCapture: any ImageCaptureServiceProtocol,
        exercisePreference: any ExercisePreferenceServiceProtocol,
        customExercise: any CustomExerciseStoreProtocol,
        workoutLog: any WorkoutLogServiceProtocol,
        workingWeight: any WorkingWeightServiceProtocol,
        cardioLog: any CardioLogServiceProtocol,
        calibration: any CalibrationServiceProtocol,
        entitlement: EntitlementService,
        rank: any RankServiceProtocol,
        skin: any SkinServiceProtocol,
        sessionXP: any SessionXPServiceProtocol,
        badges: any BadgeServiceProtocol,
        programPhase: any ProgramPhaseEngineProtocol,
        attribute: any AttributeServiceProtocol,
        photoXP: any PhotoXPServiceProtocol
    ) {
        self.logging = LoggingService.shared
        self.auth = auth
        self.database = database
        self.analytics = analytics
        self.subscription = subscription
        self.paywall = paywall
        self.user = user
        self.storage = storage
        self.network = network
        self.bodyAnalysis = bodyAnalysis
        self.programGeneration = programGeneration
        self.imageCapture = imageCapture
        self.exercisePreference = exercisePreference
        self.customExercise = customExercise
        self.workoutLog = workoutLog
        self.workingWeight = workingWeight
        self.cardioLog = cardioLog
        self.calibration = calibration
        self.entitlement = entitlement
        self.rank = rank
        self.skin = skin
        self.sessionXP = sessionXP
        self.badges = badges
        self.programPhase = programPhase
        self.attribute = attribute
        self.photoXP = photoXP
        self.userSkillTier = UserSkillTierStore.shared
        self.liftTier = LiftTierService.shared
        self.scanCheckpointStore = ScanCheckpointStore.shared
        self.scanCheckpointService = ScanCheckpointService.shared
    }

    static var mock: ServiceContainer {
        ServiceContainer(
            auth: MockAuthService(),
            database: MockDatabaseService(),
            analytics: AnalyticsService.shared,
            subscription: MockSubscriptionService(),
            paywall: MockPaywallService(),
            user: UserService.shared,
            storage: StorageService.shared,
            network: NetworkService.shared,
            bodyAnalysis: MockBodyAnalysisService(),
            programGeneration: MockProgramGenerationService(),
            imageCapture: MockImageCaptureService(),
            exercisePreference: MockExercisePreferenceService(),
            customExercise: MockCustomExerciseStore(),
            workoutLog: MockWorkoutLogService(),
            workingWeight: MockWorkingWeightService(),
            cardioLog: MockCardioLogService(),
            calibration: MockCalibrationService(),
            entitlement: EntitlementService.shared,
            rank: MockRankService(),
            skin: MockSkinService(),
            sessionXP: MockSessionXPService(),
            badges: MockBadgeService(),
            programPhase: MockProgramPhaseEngine(),
            attribute: MockAttributeService(),
            photoXP: MockPhotoXPService()
        )
    }
}
