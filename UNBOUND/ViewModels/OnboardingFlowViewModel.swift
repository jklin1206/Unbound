import Foundation
import Observation
import os.log
#if canImport(UIKit)
import UIKit
#endif

// MARK: - OnboardingFlowViewModel
//
// Drives the new 30-step UNBOUND onboarding flow. Lives alongside the legacy
// `OnboardingViewModel` — we haven't deleted that yet so legacy auth/flow
// gating keeps working. Day 2/3 will retire the legacy one.
//
// Holds the full answer model, step enum, navigation helpers, and `finish()`
// which writes everything to `UserService.updateProfile(userId:fields:)` in
// one shot.

enum OnboardingStep: Int, CaseIterable, Identifiable {
    // MARK: Hook / pitch — anime-arc opening trilogy
    case arc01Opening = 0
    case arc02Problem
    case arc03Path

    // MARK: Life-change hook slides — 5 "why working out matters" beats
    case lifeChangeEnergy
    case lifeChangeStrength
    case lifeChangeConfidence
    case lifeChangeSleep
    case lifeChangeLooksFeel

    // MARK: Chapter II — "THE MAPPING" cinematic interstitial
    case chapterMapping

    // MARK: Why (moved earlier — targets motivation + struggle upfront)
    case goals
    case obstacles           // moved up: what's been getting in the way

    // MARK: Profile answers
    case archetype
    case targetAreas         // where to focus
    case motivation          // why it matters (emotional driver)
    case age
    case gender
    case height
    case weight
    case experience
    case targetFrequency
    case trainingDays        // which weekdays to train (count must match targetFrequency)
    case workoutTime         // when in the day
    case equipment
    case exerciseStyle       // what kinds of exercises they enjoy
    case sessionLength
    case diet
    case sleep
    case stress
    case priorAttempts
    case commitment
    case name
    case notifications

    // MARK: Chapter III — "THE SCAN" cinematic interstitial
    case chapterScan

    // MARK: Real body scan (before profile is built)
    //
    // V1 = 1 front photo pre-paywall, captured via a single live-preview screen
    // with auto-snap on alignment. Side + back are V1.1 as a post-paywall
    // "complete your 3D scan" feature. The merged scanLive screen replaced the
    // old scanPrep + scanCaptureFront split — instructions live ON the live
    // preview so users line themselves up while reading.
    case scanLive
    case scanReview
    case scanAnalyzing      // cinematic 6s animation

    // MARK: Post-scan reveals (sell the product)
    case verdict            // rank + photo + soft quote + plan preview
    case trajectory         // 12-month projection chart
    case skillTreePreview   // archetype skill tree — the gamification sell

    // MARK: Chapter IV — "THE PATH" cinematic interstitial
    case chapterPath

    case whyThisProgram     // rationale reveal — names the user's choices back to them
    case socialProofGallery // testimonials

    // MARK: Commitment vision — final emotional push pre-paywall
    case commitDay30
    case commitDay90
    case commitToday

    case paywall            // blurred protocol + hard CTA

    var id: Int { rawValue }

    static var total: Int { allCases.count }

    /// Whether the progress bar should render. Hidden on hero frames.
    var showsProgressBar: Bool {
        switch self {
        case .arc01Opening, .arc02Problem, .arc03Path,
             .chapterMapping, .chapterScan, .chapterPath,
             .scanLive, .scanAnalyzing, .verdict, .paywall:
            return false
        default:
            return true
        }
    }

    /// Whether the back chevron should render.
    var showsBackButton: Bool {
        switch self {
        case .arc01Opening, .arc02Problem, .arc03Path,
             .chapterMapping, .chapterScan, .chapterPath,
             .scanAnalyzing, .verdict, .paywall:
            return false
        default:
            return true
        }
    }

    /// Identifies scan capture step for the parametric camera view.
    /// Only the live front-camera screen captures a photo; review just renders it.
    var scanAngle: ScanAngle? {
        switch self {
        case .scanLive: return .front
        default: return nil
        }
    }

    /// Logical grouping for the HUD progress-bar eyebrow.
    var category: StepCategory {
        switch self {
        case .arc01Opening, .arc02Problem, .arc03Path,
             .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence,
             .lifeChangeSleep, .lifeChangeLooksFeel, .socialProofGallery:
            return .intro
        case .chapterMapping, .chapterScan, .chapterPath:
            return .chapter
        case .goals, .obstacles, .archetype, .targetAreas, .motivation,
             .commitDay30, .commitDay90, .commitToday:
            return .profile
        case .experience, .targetFrequency, .trainingDays, .workoutTime,
             .equipment, .exerciseStyle, .sessionLength:
            return .training
        case .age, .gender, .height, .weight:
            return .body
        case .diet, .sleep, .stress, .priorAttempts, .commitment,
             .notifications, .name:
            return .lifestyle
        case .scanLive, .scanReview, .scanAnalyzing:
            return .scan
        case .verdict, .trajectory, .skillTreePreview, .whyThisProgram:
            return .reveal
        case .paywall:
            return .paywall
        }
    }
}

enum StepCategory: String {
    case intro, chapter, profile, training, body, lifestyle, scan, reveal, commit, paywall
    var displayName: String { rawValue.uppercased() }
}

@Observable
@MainActor
final class OnboardingFlowViewModel {

    // MARK: Current step

    var currentStep: OnboardingStep = .arc01Opening

    /// 0 ... 1 fraction of flow complete — feeds `OnboardingProgressBar`.
    var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.total - 1)
    }

    // MARK: Answer model

    var archetype: Archetype? = nil
    var motivations: Set<Motivation> = []
    var goals: Set<Goal> = []
    var targetAreas: Set<TargetArea> = []
    var workoutTime: WorkoutTime? = nil
    var age: Int = 22
    var gender: Gender = .unspecified
    var heightCm: Double = 175
    var weightKg: Double = 72
    var useMetricHeight: Bool = false   // iOS default to imperial for US-first audience
    var useMetricWeight: Bool = false
    var experience: Experience? = nil
    var exerciseStyles: Set<ExerciseStyle> = []
    var currentFrequency: Frequency? = nil
    var targetFrequency: TargetFrequency? = nil
    var trainingDays: Set<Weekday> = []
    var equipment: Set<Equipment> = []
    var obstacles: Set<Obstacle> = []
    var sessionLength: SessionLength? = nil
    var dietQuality: Int = 5
    var sleepQuality: Int = 5
    var stressLevel: Int = 5
    var priorAttempts: Set<PriorAttempt> = []
    var commitment: Int = 8
    var displayHandle: String = ""

    /// Max reps of a standard pushup — mapped to starting push tier on finish().
    var calisthenicPushReps: Int = 3
    /// Max reps of a standard pullup — mapped to starting pull tier on finish().
    var calisthenicPullReps: Int = 0

    // MARK: Scan captures

    /// Captured photos keyed by angle. Populated during scanCapture{Front/Side/Back}.
    var capturedPhotos: [ScanAngle: UIImage] = [:]

    /// JPEG thumbnail (lower-res) of the front photo — used as the user's
    /// profile pic on the verdict screen.
    var profilePhoto: UIImage? { capturedPhotos[.front] }

    /// Derived rank — computed post-scan. In Day 1.5 stub this is keyed off
    /// the user's chosen archetype + commitment. V1.1 swaps in real vision AI.
    var derivedRank: String {
        let score = Int(Double(commitment) + Double(dietQuality) / 2)
        switch score {
        case ..<6: return "E"
        case 6..<9: return "D"
        case 9..<12: return "C"
        case 12..<14: return "B"
        default: return "A"
        }
    }

    /// Set false to allow "Continue" while empty on screens where nothing
    /// else needs to validate. Default true means the scaffold enforces
    /// completeness. Each screen can override per its own rules.
    var notificationsRequested: Bool = false

    // MARK: Services

    private let userService: UserServiceProtocol
    private let logger = Logger(subsystem: "com.unbound.app", category: "onboarding")

    /// Explicit DI only — OnboardingContainerView passes `UserService.shared`.
    /// Keeps this module loosely coupled from Firebase for testing + preview.
    init(userService: UserServiceProtocol) {
        self.userService = userService
    }

    #if DEBUG
    /// Preview-only convenience init. Uses a no-op user service that simply
    /// succeeds every call — previews never actually hit Firestore.
    convenience init() {
        self.init(userService: PreviewUserService())
    }
    #endif

    // MARK: Navigation

    func advance() {
        var next = currentStep.rawValue + 1
        while next < OnboardingStep.total,
              let step = OnboardingStep(rawValue: next),
              shouldSkip(step) {
            next += 1
        }
        guard next < OnboardingStep.total else { return }
        currentStep = OnboardingStep(rawValue: next) ?? currentStep
    }

    func back() {
        var prev = currentStep.rawValue - 1
        while prev >= 0,
              let step = OnboardingStep(rawValue: prev),
              shouldSkip(step) {
            prev -= 1
        }
        guard prev >= 0 else { return }
        currentStep = OnboardingStep(rawValue: prev) ?? currentStep
    }

    private func shouldSkip(_ step: OnboardingStep) -> Bool {
        return false
    }

    func jump(to step: OnboardingStep) {
        currentStep = step
    }

    // MARK: Validation (per-screen Continue-enabled rules)

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .arc01Opening, .arc02Problem, .arc03Path,
             .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence,
             .lifeChangeSleep, .lifeChangeLooksFeel,
             .chapterMapping, .chapterScan, .chapterPath:
            return true
        case .goals:
            return !goals.isEmpty
        case .archetype:
            return archetype != nil
        case .targetAreas:
            return !targetAreas.isEmpty
        case .motivation:
            return !motivations.isEmpty
        case .workoutTime:
            return workoutTime != nil
        case .age, .height, .weight:
            return true  // scroll pickers always have a value
        case .gender:
            return true
        case .experience:
            return experience != nil
        case .targetFrequency:
            return targetFrequency != nil
        case .trainingDays:
            return !trainingDays.isEmpty && trainingDays.count == (targetFrequency?.numericCount ?? 3)
        case .equipment:
            return !equipment.isEmpty
        case .exerciseStyle:
            return !exerciseStyles.isEmpty
        case .obstacles:
            return !obstacles.isEmpty
        case .sessionLength:
            return sessionLength != nil
        case .diet, .sleep, .stress, .commitment:
            return true
        case .priorAttempts:
            return !priorAttempts.isEmpty
        case .name:
            return !displayHandle.trimmingCharacters(in: .whitespaces).isEmpty
        case .notifications, .scanAnalyzing,
             .verdict, .trajectory, .skillTreePreview, .whyThisProgram,
             .socialProofGallery, .commitDay30, .commitDay90, .commitToday, .paywall:
            return true
        case .scanLive, .scanReview:
            return capturedPhotos[.front] != nil
        }
    }

    // MARK: Finish — persist answers

    /// Called from Screen 30 (scan prep). Writes answers to Firestore and
    /// sets the legacy onboardingCompleted flag so the existing route gate
    /// advances to HomeTabView.
    ///
    /// Returns `true` on success. Throws nothing — network errors are logged
    /// but don't block the user from proceeding (answers retry on next app
    /// open via the legacy UserDefaults flag).
    @discardableResult
    func finish(userId: String) async -> Bool {
        let fields: [String: Any] = buildFirestorePayload()
        let chosenArchetype = archetype
        do {
            try await userService.updateProfile(userId: userId, fields: fields)
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            if let chosenArchetype {
                await MainActor.run {
                    BadgeService.shared.bind(userId: userId)
                }
                _ = await BadgeService.shared.evaluate(trigger: .archetypeChosen(chosenArchetype))
            }
            logger.info("Onboarding answers persisted for user \(userId, privacy: .private)")
            return true
        } catch {
            logger.error("Failed to persist onboarding answers: \(String(describing: error))")
            // Still flip the local flag so the user isn't trapped
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            return false
        }
    }

    func buildFirestorePayload() -> [String: Any] {
        var fields: [String: Any] = [
            "onboardingCompleted": true,
            "displayHandle": displayHandle,
            "age": age,
            "heightCm": heightCm,
            "weightKg": weightKg,
            "gender": gender.rawValue,
            "dietQuality": dietQuality,
            "sleepQuality": sleepQuality,
            "stressLevel": stressLevel,
            "commitment": commitment,
            "motivations": motivations.map(\.rawValue),
            "goals": goals.map(\.rawValue),
            "targetAreas": targetAreas.map(\.rawValue),
            "equipment": equipment.map(\.rawValue),
            "exerciseStyles": exerciseStyles.map(\.rawValue),
            "obstacles": obstacles.map(\.rawValue),
            "priorAttempts": priorAttempts.map(\.rawValue)
        ]
        if let workoutTime { fields["workoutTime"] = workoutTime.rawValue }
        if let archetype { fields["preferredArchetype"] = archetype.rawValue }
        if let experience { fields["experience"] = experience.rawValue }
        if let currentFrequency { fields["currentFrequency"] = currentFrequency.rawValue }
        if let targetFrequency { fields["targetFrequency"] = targetFrequency.rawValue }
        if !trainingDays.isEmpty { fields["trainingDays"] = trainingDays.map(\.rawValue) }
        if let sessionLength { fields["sessionLength"] = sessionLength.rawValue }
        return fields
    }
}
