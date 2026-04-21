import Foundation

enum AnalyticsEvent {
    case appOpen
    case screenView(screenName: String)
    case onboardingStarted
    case onboardingStepViewed(step: Int, screenName: String)
    case onboardingCompleted
    case onboardingSkipped(atStep: Int)
    case signInStarted(method: String)
    case signInCompleted(method: String)
    case signInFailed(method: String, error: String)
    case signOut
    case accountDeleted
    case scanStarted
    case scanPhotoTaken(angle: ScanAngle)
    case scanPhotosCompleted
    case scanArchetypeSelected(archetype: Archetype)
    case scanAnalysisStarted
    case scanAnalysisCompleted(score: Int, archetype: Archetype)
    case scanAnalysisFailed(error: String)
    case reportViewed(scanId: String, score: Int)
    case reportShared(scanId: String)
    case reportShareCompleted(scanId: String, destination: String)
    case programUnlocked(scanId: String)
    case programViewed(programId: String)
    case programDayViewed(programId: String, dayNumber: Int)
    case workoutStarted(programId: String, dayNumber: Int)
    case workoutCompleted(programId: String, dayNumber: Int)
    case paywallTriggered(placement: String)
    case paywallPresented(placement: String)
    case paywallDismissed(placement: String)
    case paywallConverted(placement: String, productId: String)
    case subscriptionStarted(productId: String, isTrialPeriod: Bool)
    case subscriptionRenewed(productId: String)
    case subscriptionCancelled(productId: String)
    case subscriptionRestored
    case rescanStarted(previousScanId: String)
    case progressViewed(currentScore: Int, previousScore: Int)
    // Exercise Preferences
    case exercisePreferenceSet(exerciseName: String, status: String)
    case exerciseLibraryViewed

    // Workout Logging
    case workoutLoggingStarted(programId: String, dayNumber: Int)
    case workoutLoggingCompleted(programId: String, dayNumber: Int, durationMinutes: Int, totalSets: Int)
    case workoutLoggingAbandoned(programId: String, dayNumber: Int)

    // Working Weights
    case workingWeightUpdated(exerciseName: String, newWeightKg: Double)
    case progressionSuggestionShown(exerciseName: String, suggestedIncrease: Double)

    // Swap / Coach
    case exerciseSwapped(from: String, to: String)
    case coachMessageSent(promptKind: String)
    case coachActionApplied(action: String)
    case coachActionUndone(action: String)

    case errorOccurred(domain: String, message: String, screen: String)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .screenView: return "screen_view"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingStepViewed: return "onboarding_step_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingSkipped: return "onboarding_skipped"
        case .signInStarted: return "sign_in_started"
        case .signInCompleted: return "sign_in_completed"
        case .signInFailed: return "sign_in_failed"
        case .signOut: return "sign_out"
        case .accountDeleted: return "account_deleted"
        case .scanStarted: return "scan_started"
        case .scanPhotoTaken: return "scan_photo_taken"
        case .scanPhotosCompleted: return "scan_photos_completed"
        case .scanArchetypeSelected: return "scan_archetype_selected"
        case .scanAnalysisStarted: return "scan_analysis_started"
        case .scanAnalysisCompleted: return "scan_analysis_completed"
        case .scanAnalysisFailed: return "scan_analysis_failed"
        case .reportViewed: return "report_viewed"
        case .reportShared: return "report_shared"
        case .reportShareCompleted: return "report_share_completed"
        case .programUnlocked: return "program_unlocked"
        case .programViewed: return "program_viewed"
        case .programDayViewed: return "program_day_viewed"
        case .workoutStarted: return "workout_started"
        case .workoutCompleted: return "workout_completed"
        case .paywallTriggered: return "paywall_triggered"
        case .paywallPresented: return "paywall_presented"
        case .paywallDismissed: return "paywall_dismissed"
        case .paywallConverted: return "paywall_converted"
        case .subscriptionStarted: return "subscription_started"
        case .subscriptionRenewed: return "subscription_renewed"
        case .subscriptionCancelled: return "subscription_cancelled"
        case .subscriptionRestored: return "subscription_restored"
        case .rescanStarted: return "rescan_started"
        case .progressViewed: return "progress_viewed"
        case .exercisePreferenceSet: return "exercise_preference_set"
        case .exerciseLibraryViewed: return "exercise_library_viewed"
        case .workoutLoggingStarted: return "workout_logging_started"
        case .workoutLoggingCompleted: return "workout_logging_completed"
        case .workoutLoggingAbandoned: return "workout_logging_abandoned"
        case .workingWeightUpdated: return "working_weight_updated"
        case .progressionSuggestionShown: return "progression_suggestion_shown"
        case .exerciseSwapped: return "exercise_swapped"
        case .coachMessageSent: return "coach_message_sent"
        case .coachActionApplied: return "coach_action_applied"
        case .coachActionUndone: return "coach_action_undone"
        case .errorOccurred: return "error_occurred"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .appOpen, .signOut, .accountDeleted, .onboardingStarted, .onboardingCompleted,
             .scanStarted, .scanPhotosCompleted, .subscriptionRestored, .scanAnalysisStarted:
            return [:]
        case .screenView(let name):
            return ["screen_name": name]
        case .onboardingStepViewed(let step, let name):
            return ["step": step, "screen_name": name]
        case .onboardingSkipped(let step):
            return ["at_step": step]
        case .signInStarted(let method), .signInCompleted(let method):
            return ["method": method]
        case .signInFailed(let method, let error):
            return ["method": method, "error": error]
        case .scanPhotoTaken(let angle):
            return ["angle": angle.rawValue]
        case .scanArchetypeSelected(let archetype):
            return ["archetype": archetype.rawValue]
        case .scanAnalysisCompleted(let score, let archetype):
            return ["score": score, "archetype": archetype.rawValue]
        case .scanAnalysisFailed(let error):
            return ["error": error]
        case .reportViewed(let scanId, let score):
            return ["scan_id": scanId, "score": score]
        case .reportShared(let scanId):
            return ["scan_id": scanId]
        case .reportShareCompleted(let scanId, let destination):
            return ["scan_id": scanId, "destination": destination]
        case .programUnlocked(let scanId):
            return ["scan_id": scanId]
        case .programViewed(let programId):
            return ["program_id": programId]
        case .programDayViewed(let programId, let dayNumber):
            return ["program_id": programId, "day_number": dayNumber]
        case .workoutStarted(let programId, let dayNumber), .workoutCompleted(let programId, let dayNumber):
            return ["program_id": programId, "day_number": dayNumber]
        case .paywallTriggered(let placement), .paywallPresented(let placement), .paywallDismissed(let placement):
            return ["placement": placement]
        case .paywallConverted(let placement, let productId):
            return ["placement": placement, "product_id": productId]
        case .subscriptionStarted(let productId, let isTrial):
            return ["product_id": productId, "is_trial": isTrial]
        case .subscriptionRenewed(let productId), .subscriptionCancelled(let productId):
            return ["product_id": productId]
        case .rescanStarted(let previousScanId):
            return ["previous_scan_id": previousScanId]
        case .progressViewed(let current, let previous):
            return ["current_score": current, "previous_score": previous]
        case .exercisePreferenceSet(let exerciseName, let status):
            return ["exercise_name": exerciseName, "status": status]
        case .exerciseLibraryViewed:
            return [:]
        case .workoutLoggingStarted(let programId, let dayNumber):
            return ["program_id": programId, "day_number": dayNumber]
        case .workoutLoggingCompleted(let programId, let dayNumber, let durationMinutes, let totalSets):
            return ["program_id": programId, "day_number": dayNumber, "duration_minutes": durationMinutes, "total_sets": totalSets]
        case .workoutLoggingAbandoned(let programId, let dayNumber):
            return ["program_id": programId, "day_number": dayNumber]
        case .workingWeightUpdated(let exerciseName, let newWeightKg):
            return ["exercise_name": exerciseName, "new_weight_kg": newWeightKg]
        case .progressionSuggestionShown(let exerciseName, let suggestedIncrease):
            return ["exercise_name": exerciseName, "suggested_increase": suggestedIncrease]
        case .exerciseSwapped(let from, let to):
            return ["from": from, "to": to]
        case .coachMessageSent(let kind):
            return ["prompt_kind": kind]
        case .coachActionApplied(let action):
            return ["action": action]
        case .coachActionUndone(let action):
            return ["action": action]
        case .errorOccurred(let domain, let message, let screen):
            return ["domain": domain, "message": message, "screen": screen]
        }
    }
}
