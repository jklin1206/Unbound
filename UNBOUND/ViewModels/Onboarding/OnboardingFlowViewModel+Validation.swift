import Foundation
import Observation
import os.log
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension OnboardingFlowViewModel {

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
        case .notifications, .scanAnalyzing,
             .verdict, .appPainSolution, .workoutPreviewDemo,
             .workoutLogDemo, .workoutRewardDemo, .appRatingPrompt,
             .trajectory, .obstacleFix, .whyThisProgram,
             .socialProofGallery, .commitDay30, .commitDay90, .commitToday, .planReady, .paywall:
            return true
        case .scanLive, .scanReview:
            return capturedPhotos[.front] != nil
        }
    }
}
