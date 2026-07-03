import Foundation
import Observation
import os.log
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - OnboardingFlowViewModel
//
// Drives the UNBOUND onboarding flow. The legacy `OnboardingViewModel` step
// counter has been removed; this is the only onboarding flow VM.
//
// Holds the full answer model, step enum, navigation helpers, and `finish()`
// which writes everything to `UserService.updateProfile(userId:fields:)` in
// one shot.

@Observable
@MainActor
final class OnboardingFlowViewModel {

    // MARK: Current step

    var currentStep: OnboardingStep = .arc01Opening

    /// 0 ... 1 fraction of flow complete — feeds `OnboardingProgressBar`.
    var progress: Double {
        let index = OnboardingStep.flowOrder.firstIndex(of: currentStep) ?? 0
        return Double(index) / Double(max(1, OnboardingStep.total - 1))
    }

    // MARK: Answer model

    // Archetype is inferred from goals/styles instead of a separate build-pick screen.
    var motivations: Set<Motivation> = []
    var goals: Set<Goal> = []
    var targetAreas: Set<TargetArea> = []
    var workoutTime: WorkoutTime? = nil
    var workoutMinuteOfDay: Int? = nil
    var age: Int = 22
    var gender: Gender = .unspecified
    var heightCm: Double = 175
    var weightKg: Double = 72
    // Derived from the device's regional settings at init — US / Liberia /
    // Myanmar get imperial defaults, everyone else gets metric. No HealthKit
    // permission prompt, no personal data read; just the region the phone
    // is already registered to. User can flip the toggle on screen.
    var useMetricHeight: Bool = Locale.current.measurementSystem == .metric
    var useMetricWeight: Bool = TrainingWeightUnit.localeDefault == .kilograms
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

    /// Finger-signed pact strokes (normalized 0...1), captured at the commitment
    /// ritual just before the paywall. Persisted so the signature can be
    /// re-surfaced later (profile, vow surfaces).
    var pactSignatureStrokes: [[CGPoint]] = []

    /// Max reps of a standard pushup — mapped to starting push tier on finish().
    var calisthenicPushReps: Int = 3
    /// Max reps of a standard pullup — mapped to starting pull tier on finish().
    var calisthenicPullReps: Int = 0

    /// Attribute seed survey — Task 1a.12. Up to 2 attributes get +15 prefill via AttributeService.applySeed.
    var seededAttributes: Set<AttributeKey> = []

    /// The onboarding reveal should feel like UNBOUND is spotting potential,
    /// not making the user self-label a stat build. If an old/debug flow has
    /// explicit seeds, keep them; otherwise infer the first sparks from intent.
    var effectiveSeededAttributes: Set<AttributeKey> {
        if !seededAttributes.isEmpty {
            return seededAttributes
        }

        var scores: [AttributeKey: Int] = Dictionary(uniqueKeysWithValues: AttributeKey.allCases.map { ($0, 0) })
        func add(_ key: AttributeKey, _ amount: Int = 1) {
            scores[key, default: 0] += amount
        }

        for goal in goals {
            switch goal {
            case .buildMuscle:
                add(.power, 2)
                add(.control)
            case .loseFat:
                add(.endurance, 2)
                add(.vitality)
            case .getDefined:
                add(.control, 2)
                add(.power)
            case .getStronger:
                add(.power, 3)
            case .athletic:
                add(.explosiveness, 2)
                add(.endurance, 2)
            case .feelBetter:
                add(.vitality, 2)
                add(.mobility)
            }
        }

        for area in targetAreas {
            switch area {
            case .chest, .shoulders, .arms:
                add(.power)
                add(.control)
            case .back, .core:
                add(.control, 2)
            case .legs, .glutes:
                add(.power)
                add(.explosiveness)
            case .fullBody:
                add(.vitality)
                add(.control)
            }
        }

        for style in exerciseStyles {
            switch style {
            case .compoundLifts, .olympicLifts:
                add(.power, 2)
            case .isolation:
                add(.control)
            case .calisthenics:
                add(.control, 2)
            case .cardioIntervals, .steadyCardio:
                add(.endurance, 2)
            case .mobility:
                add(.mobility, 2)
            case .sports:
                add(.vitality)
                add(.explosiveness)
            case .plyometrics:
                add(.explosiveness, 2)
            case .machines:
                add(.power)
            }
        }

        let ranked = AttributeKey.allCases.sorted {
            let lhs = scores[$0, default: 0]
            let rhs = scores[$1, default: 0]
            if lhs == rhs {
                return $0.shortCode < $1.shortCode
            }
            return lhs > rhs
        }

        let selected = ranked.prefix(2).filter { scores[$0, default: 0] > 0 }
        return selected.isEmpty ? [.power, .control] : Set(selected)
    }

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
    /// Derived starting tier — computed post-scan. In Day 1.5 stub this is
    /// keyed off the user's chosen archetype + commitment. V1.1 swaps in
    /// real vision AI.
    var derivedRank: RankTitle {
        let score = Int(Double(commitment) + Double(dietQuality) / 2)
        switch score {
        case ..<6: return .initiate
        case 6..<9: return .novice
        case 9..<12: return .apprentice
        case 12..<14: return .forged
        default: return .veteran
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
        // Onboarding runs BEFORE sign-in, so `userId` is usually the "anonymous"
        // placeholder and this write only reaches the local store. Stash the
        // payload so it is replayed onto the real account at sign-in (cleared
        // there once it lands). Without this, the authed user starts blank and
        // program generation runs on defaults.
        PendingOnboardingProfile.stash(fields)
        do {
            // Materialize a COMPLETE profile doc first. `updateProfile` is a blind
            // field-merge: on a user with no doc yet it creates one containing only
            // these answer keys — with no `id` — which then fails to decode on every
            // later `fetchProfile`, silently blocking first-run program generation
            // (the user lands on a permanent "No program"). `createUserIfNeeded`
            // writes a full `UserProfile` (with `id`) so the merge below lands on a
            // decodable doc. Best-effort: if it throws, the Home self-heal recovers.
            _ = try? await userService.createUserIfNeeded(userId: userId, email: nil)
            try await userService.updateProfile(userId: userId, fields: fields)
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            await MainActor.run {
                BadgeService.shared.bind(userId: userId)
            }
            await scheduleNotifications()
            AnalyticsService.shared.track(.onboardingCompleted)
            logger.info("Onboarding answers persisted for user \(userId, privacy: .private)")
            return true
        } catch {
            logger.error("Failed to persist onboarding answers: \(String(describing: error))")
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            await scheduleNotifications()
            AnalyticsService.shared.track(.onboardingCompleted)
            return false
        }
    }

    private func scheduleNotifications() async {
        guard notificationsRequested, let workoutTime else { return }
        await NotificationService.scheduleWorkoutReminders(
            workoutTime: workoutTime,
            trainingDays: trainingDays,
            minuteOfDay: workoutMinuteOfDay
        )
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
        if let workoutMinuteOfDay { fields["workoutMinuteOfDay"] = workoutMinuteOfDay }
        fields["seededAttributes"] = effectiveSeededAttributes.map(\.rawValue)
        // preferredArchetype field removed — inferred attribute sparks drive Build instead
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
        if !pactSignatureStrokes.isEmpty,
           let data = try? JSONEncoder().encode(pactSignatureStrokes),
           let json = String(data: data, encoding: .utf8) {
            fields["pactSignature"] = json
        }
        return fields
    }
}
