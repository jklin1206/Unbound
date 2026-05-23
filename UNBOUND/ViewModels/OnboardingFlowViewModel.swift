import Foundation
import Observation
import os.log
import SwiftUI
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
    // MARK: Cinematic cold open — the first frame should feel like the game starting
    case arc01Opening = 0

    // MARK: System tutorial — baseline, rank orbit, then archetype/Hex possibilities
    case problemFrame
    case arc03Path
    case restartLoop

    // MARK: Chapter II — "THE MAPPING" cinematic interstitial
    case chapterMapping

    // MARK: Why (moved earlier — targets motivation + struggle upfront)
    case goals
    case obstacles           // moved up: what's been getting in the way

    // MARK: Profile answers
    case targetAreas         // where to focus
    case name                // handle / identity
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
    case buildSeed           // attribute system seed survey (sub-project #1, Task 1a.12)
    case sessionLength
    case resultsSnapshot     // early personalized checkpoint
    case diet
    case sleep
    case stress
    case priorAttempts
    case commitment
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
    case obstacleFix         // names the user's obstacle and maps UNBOUND's fix

    // MARK: Chapter IV — "THE PATH" cinematic interstitial
    case chapterPath

    case whyThisProgram     // rationale reveal — names the user's choices back to them
    case socialProofGallery // testimonials

    // MARK: Life-change + commitment vision — final emotional push pre-paywall
    case lifeChangeEnergy
    case lifeChangeStrength
    case lifeChangeConfidence
    case lifeChangeSleep
    case lifeChangeLooksFeel
    case commitDay30
    case commitDay90
    case commitToday
    case planReady           // custom-plan reveal right before pricing

    case paywall            // blurred protocol + hard CTA

    var id: Int { rawValue }

    static var total: Int { allCases.count }

    /// Whether the progress bar should render. Hidden on hero frames.
    var showsProgressBar: Bool {
        switch self {
        case .problemFrame, .restartLoop,
             .arc01Opening, .arc03Path,
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
        case .problemFrame, .restartLoop,
             .arc01Opening, .arc03Path,
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
        case .problemFrame, .restartLoop,
             .arc01Opening, .arc03Path,
             .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence,
             .lifeChangeSleep, .lifeChangeLooksFeel, .socialProofGallery:
            return .intro
        case .chapterMapping, .chapterScan, .chapterPath:
            return .chapter
        case .goals, .obstacles, .targetAreas, .name, .motivation,
             .commitDay30, .commitDay90, .commitToday:
            return .profile
        case .experience, .targetFrequency, .trainingDays, .workoutTime,
             .equipment, .exerciseStyle, .buildSeed, .sessionLength:
            return .training
        case .age, .gender, .height, .weight:
            return .body
        case .diet, .sleep, .stress, .priorAttempts, .commitment,
             .notifications:
            return .lifestyle
        case .scanLive, .scanReview, .scanAnalyzing:
            return .scan
        case .verdict, .trajectory, .obstacleFix, .whyThisProgram:
            return .reveal
        case .resultsSnapshot, .planReady:
            return .reveal
        case .paywall:
            return .paywall
        }
    }
}

#if DEBUG
extension OnboardingStep {
    var debugDisplayName: String {
        switch self {
        case .arc01Opening: return "01 Opening"
        case .problemFrame: return "02 Pain Frame"
        case .arc03Path: return "03 Rank Orbit"
        case .restartLoop: return "04 Build Preview"
        case .chapterMapping: return "05 Chapter Mapping"
        case .goals: return "06 Goals"
        case .obstacles: return "07 Obstacles"
        case .targetAreas: return "08 Target Areas"
        case .name: return "09 Handle"
        case .motivation: return "10 Motivation"
        case .age: return "11 Age"
        case .gender: return "12 Gender"
        case .height: return "13 Height"
        case .weight: return "14 Weight"
        case .experience: return "15 Experience"
        case .targetFrequency: return "16 Frequency"
        case .trainingDays: return "17 Training Days"
        case .workoutTime: return "18 Workout Time"
        case .equipment: return "19 Equipment"
        case .exerciseStyle: return "20 Exercise Style"
        case .buildSeed: return "21 Build Seed"
        case .sessionLength: return "22 Session Length"
        case .resultsSnapshot: return "23 Entry Map"
        case .diet: return "24 Diet"
        case .sleep: return "25 Sleep"
        case .stress: return "26 Stress"
        case .priorAttempts: return "27 Prior Attempts"
        case .commitment: return "28 Commitment"
        case .notifications: return "29 Notifications"
        case .chapterScan: return "30 Chapter Scan"
        case .scanLive: return "31 Arc Entry"
        case .scanReview: return "32 Scan Review"
        case .scanAnalyzing: return "33 Scan Analyzing"
        case .verdict: return "34 Verdict"
        case .trajectory: return "35 Trajectory"
        case .obstacleFix: return "36 Obstacle Fix"
        case .chapterPath: return "37 Chapter Path"
        case .whyThisProgram: return "38 Path Locked"
        case .socialProofGallery: return "39 Social Proof"
        case .lifeChangeEnergy: return "40 Energy"
        case .lifeChangeStrength: return "41 Strength"
        case .lifeChangeConfidence: return "42 Confidence"
        case .lifeChangeSleep: return "43 Sleep"
        case .lifeChangeLooksFeel: return "44 Looks/Feel"
        case .commitDay30: return "45 Day 30"
        case .commitDay90: return "46 Day 90"
        case .commitToday: return "47 Commit Today"
        case .planReady: return "48 Arc Ready"
        case .paywall: return "49 Paywall"
        }
    }

    static func debugStep(matching identifier: String) -> OnboardingStep? {
        let normalized = identifier
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        return allCases.first { step in
            let caseName = String(describing: step)
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
            let displayName = step.debugDisplayName
                .lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
            return caseName == normalized || displayName.contains(normalized)
        }
    }
}
#endif

enum StepCategory: String {
    case intro, chapter, profile, training, body, lifestyle, scan, reveal, commit, paywall
    var displayName: String {
        switch self {
        case .scan: return "DAY ZERO"
        default: return rawValue.uppercased()
        }
    }
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

    // archetype property removed — BuildSeed is the only path (Phase 11)
    var motivations: Set<Motivation> = []
    var goals: Set<Goal> = []
    var targetAreas: Set<TargetArea> = []
    var workoutTime: WorkoutTime? = nil
    var age: Int = 22
    var gender: Gender = .unspecified
    var heightCm: Double = 175
    var weightKg: Double = 72
    // Derived from the device's regional settings at init — US / Liberia /
    // Myanmar get imperial defaults, everyone else gets metric. No HealthKit
    // permission prompt, no personal data read; just the region the phone
    // is already registered to. User can flip the toggle on screen.
    var useMetricHeight: Bool = Locale.current.measurementSystem == .metric
    var useMetricWeight: Bool = Locale.current.measurementSystem == .metric
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

    /// Attribute seed survey — Task 1a.12. Up to 2 attributes get +15 prefill via AttributeService.applySeed.
    var seededAttributes: Set<AttributeKey> = []

    // MARK: Scan captures

    /// Captured photos keyed by angle. Populated during scanCapture{Front/Side/Back}.
    var capturedPhotos: [ScanAngle: UIImage] = [:]

    /// JPEG thumbnail (lower-res) of the front photo — used as the user's
    /// profile pic on the verdict screen.
    var profilePhoto: UIImage? { capturedPhotos[.front] }

    /// On-device Vision-derived body-shape insights from the front scan
    /// photo. Populated by `LocalBodyInsightsService` during the 6s
    /// analyzing screen. `nil` if scan was skipped or Vision couldn't
    /// detect a usable body pose — Verdict gracefully omits the scan
    /// insight card in that case.
    var scanInsights: BodyScanInsights? = nil

    /// AI aesthetic scores from the onboarding photo. Populated
    /// concurrently during the 6s analyzing screen — usually ready by
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

    #if DEBUG
    func seedDebugAnswers() {
        motivations = [.confidence, .strength]
        goals = [.buildMuscle, .getStronger]
        targetAreas = [.fullBody, .back]
        workoutTime = .evening
        age = 23
        gender = .male
        heightCm = 178
        weightKg = 76
        experience = .used
        exerciseStyles = [.compoundLifts, .calisthenics, .mobility]
        currentFrequency = .oneToTwo
        targetFrequency = .four
        trainingDays = [.monday, .tuesday, .thursday, .saturday]
        equipment = [.fullGym, .pullupBar]
        obstacles = [.consistency]
        sessionLength = .fortyFive
        dietQuality = 6
        sleepQuality = 6
        stressLevel = 5
        priorAttempts = [.otherApps, .youtube]
        commitment = 8
        displayHandle = "unbound"
        seededAttributes = [.power, .mobility]
        notificationsRequested = true
    }

    func applyDebugLaunchStepIfPresent() {
        let args = ProcessInfo.processInfo.arguments
        let keys = ["--onboarding-step", "-OnboardingStep"]
        let requested = keys.compactMap { key -> String? in
            guard let index = args.firstIndex(of: key), args.indices.contains(index + 1) else { return nil }
            return args[index + 1]
        }.first ?? UserDefaults.standard.string(forKey: "debug.onboardingStep")

        guard let requested, let step = OnboardingStep.debugStep(matching: requested) else { return }
        seedDebugAnswers()
        seedDebugDayZeroPhotoIfNeeded(for: step)
        jump(to: step)
    }

    private func seedDebugDayZeroPhotoIfNeeded(for step: OnboardingStep) {
        guard [.scanReview, .scanAnalyzing, .verdict].contains(step),
              capturedPhotos[.front] == nil
        else { return }

        #if canImport(UIKit)
        let size = CGSize(width: 512, height: 768)
        let renderer = UIGraphicsImageRenderer(size: size)
        capturedPhotos[.front] = renderer.image { context in
            UIColor(Color.unbound.bg).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let bounds = CGRect(origin: .zero, size: size)
            let glow = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(Color.unbound.accent.opacity(0.46)).cgColor,
                    UIColor.clear.cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            )
            if let glow {
                context.cgContext.drawRadialGradient(
                    glow,
                    startCenter: CGPoint(x: bounds.midX, y: bounds.midY - 40),
                    startRadius: 16,
                    endCenter: CGPoint(x: bounds.midX, y: bounds.midY - 40),
                    endRadius: 360,
                    options: []
                )
            }

            UIColor(Color.unbound.textPrimary.opacity(0.1)).setStroke()
            context.cgContext.setLineWidth(1)
            for x in stride(from: CGFloat(0), through: size.width, by: 52) {
                context.cgContext.move(to: CGPoint(x: x, y: 0))
                context.cgContext.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: 52) {
                context.cgContext.move(to: CGPoint(x: 0, y: y))
                context.cgContext.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.cgContext.strokePath()

            let torso = UIBezierPath()
            torso.move(to: CGPoint(x: 256, y: 156))
            torso.addCurve(to: CGPoint(x: 166, y: 360), controlPoint1: CGPoint(x: 204, y: 184), controlPoint2: CGPoint(x: 170, y: 260))
            torso.addCurve(to: CGPoint(x: 210, y: 560), controlPoint1: CGPoint(x: 158, y: 438), controlPoint2: CGPoint(x: 176, y: 510))
            torso.addLine(to: CGPoint(x: 302, y: 560))
            torso.addCurve(to: CGPoint(x: 346, y: 360), controlPoint1: CGPoint(x: 336, y: 510), controlPoint2: CGPoint(x: 354, y: 438))
            torso.addCurve(to: CGPoint(x: 256, y: 156), controlPoint1: CGPoint(x: 342, y: 260), controlPoint2: CGPoint(x: 308, y: 184))
            torso.close()

            UIColor(Color.unbound.textPrimary.opacity(0.18)).setFill()
            torso.fill()
            UIColor(Color.unbound.accent.opacity(0.78)).setStroke()
            torso.lineWidth = 3
            torso.stroke()
        }
        #endif
    }
    #endif

    // MARK: Validation (per-screen Continue-enabled rules)

    func canAdvance(from step: OnboardingStep) -> Bool {
        switch step {
        case .problemFrame, .restartLoop,
             .arc01Opening, .arc03Path,
             .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence,
             .lifeChangeSleep, .lifeChangeLooksFeel,
             .chapterMapping, .chapterScan, .chapterPath:
            return true
        case .goals:
            return !goals.isEmpty
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
        case .resultsSnapshot:
            return true
        case .diet, .sleep, .stress, .commitment:
            return true
        case .priorAttempts:
            return !priorAttempts.isEmpty
        case .name:
            return !displayHandle.trimmingCharacters(in: .whitespaces).isEmpty
        case .buildSeed:
            return true  // 0–2 selections allowed — always advanceable
        case .notifications, .scanAnalyzing,
             .verdict, .trajectory, .obstacleFix, .whyThisProgram,
             .socialProofGallery, .commitDay30, .commitDay90, .commitToday, .planReady, .paywall:
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
        do {
            try await userService.updateProfile(userId: userId, fields: fields)
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            await MainActor.run {
                BadgeService.shared.bind(userId: userId)
            }
            await scheduleNotifications()
            logger.info("Onboarding answers persisted for user \(userId, privacy: .private)")
            return true
        } catch {
            logger.error("Failed to persist onboarding answers: \(String(describing: error))")
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            await scheduleNotifications()
            return false
        }
    }

    private func scheduleNotifications() async {
        guard let workoutTime else { return }
        await NotificationService.scheduleWorkoutReminders(
            workoutTime: workoutTime,
            trainingDays: trainingDays
        )
        await NotificationService.scheduleRescanReminder()
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
        // preferredArchetype field removed — seededAttributes drive Build instead
        if let experience { fields["experience"] = experience.rawValue }
        // Auto-default training feedback mode from experience level.
        // Beginner-equivalent (never/tried) → silent; active (used/current) → quick.
        // User can promote to .detailed in Settings.
        if fields["trainingFeedbackMode"] == nil, let exp = experience {
            fields["trainingFeedbackMode"] = TrainingFeedbackMode.default(for: exp).rawValue
        }
        if let currentFrequency { fields["currentFrequency"] = currentFrequency.rawValue }
        if let targetFrequency { fields["targetFrequency"] = targetFrequency.rawValue }
        if !trainingDays.isEmpty { fields["trainingDays"] = trainingDays.map(\.rawValue) }
        if let sessionLength { fields["sessionLength"] = sessionLength.rawValue }
        return fields
    }
}
