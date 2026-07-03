import Foundation
import Observation
import os.log
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    case sessionLength
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
    case verdict            // profile-built reveal: rank + photo + projection to Unbound
    case workoutLogDemo     // taste logging on the REAL active-workout surface (rehearsal)
    case workoutRewardDemo  // shows progress/rank reward after logging
    case appRatingPrompt    // archived; native Apple prompt now fires from reward completion
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

    case pact               // sign the pact — finger-signed commitment ritual

    case paywall            // trial timeline + RC package picker (hard gate)

    // MARK: Cinematic pain beat — the cost of the restart loop, words punch in
    case painCost

    var id: Int { rawValue }

    /// Official production onboarding path.
    ///
    /// Keep deprecated/experimental cases in the enum only while old previews
    /// or launch arguments still reference them. Production navigation and
    /// the primary dev jump menu should use this list, not `allCases`.
    static let flowOrder: [OnboardingStep] = [
        .arc01Opening,
        .painCost,         // the cost of the restart loop — pain lands first
        .problemFrame,
        .restartLoop,      // the answer: what you train becomes your build...
        .arc03Path,        // ...and the build climbs the ranks
        .chapterMapping,
        .goals,
        .obstacles,
        .targetAreas,
        .name,
        .motivation,
        .age,
        .gender,
        .height,
        .weight,
        .experience,
        .targetFrequency,
        .trainingDays,
        .workoutTime,
        .equipment,
        .sessionLength,
        .diet,
        .sleep,
        .stress,
        .priorAttempts,
        .commitment,
        .notifications,
        .chapterScan,
        .scanLive,
        .scanReview,
        .scanAnalyzing,
        .verdict,
        .workoutLogDemo,
        .workoutRewardDemo,
        .pact,             // sign at the sealed gate — the signature is what opens it
        .chapterPath,      // ...and the gate answers by opening
        .whyThisProgram,
        .socialProofGallery,
        .obstacleFix,      // names the user's confessed blocker + the system's counter
        .commitDay90,
        .paywall
    ]

    static var total: Int { flowOrder.count }

    /// Whether the progress bar should render. Hidden on hero frames.
    var showsProgressBar: Bool {
        switch self {
        case .problemFrame, .painCost, .restartLoop,
             .arc01Opening, .arc03Path,
             .chapterMapping, .chapterScan, .chapterPath,
             .scanLive, .scanAnalyzing, .verdict, .obstacleFix, .pact, .paywall:
            return false
        default:
            return true
        }
    }

    /// Whether the back chevron should render.
    var showsBackButton: Bool {
        switch self {
        case .problemFrame, .painCost, .restartLoop,
             .arc01Opening, .arc03Path,
             .chapterMapping, .chapterScan, .chapterPath,
             .scanAnalyzing, .verdict, .obstacleFix, .pact, .paywall:
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
        case .problemFrame, .painCost, .restartLoop,
             .arc01Opening, .arc03Path,
             .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence,
             .lifeChangeSleep, .lifeChangeLooksFeel, .socialProofGallery:
            return .intro
        case .chapterMapping, .chapterScan, .chapterPath:
            return .chapter
        case .goals, .obstacles, .targetAreas, .name, .motivation,
             .commitDay30, .commitDay90, .commitToday:
            return .profile
        case .pact:
            return .commit
        case .experience, .targetFrequency, .trainingDays, .workoutTime,
             .equipment, .exerciseStyle, .sessionLength:
            return .training
        case .age, .gender, .height, .weight:
            return .body
        case .diet, .sleep, .stress, .priorAttempts, .commitment,
             .notifications:
            return .lifestyle
        case .scanLive, .scanReview, .scanAnalyzing:
            return .scan
        case .verdict, .workoutLogDemo, .workoutRewardDemo, .appRatingPrompt,
             .obstacleFix, .whyThisProgram:
            return .reveal
        case .planReady:
            return .reveal
        case .paywall:
            return .paywall
        }
    }
}

extension OnboardingStep {
    var analyticsName: String {
        String(describing: self)
    }
}

#if DEBUG
extension OnboardingStep {
    var debugDisplayName: String {
        switch self {
        case .arc01Opening: return "01 Opening"
        case .painCost: return "01b The Cost"
        case .problemFrame: return "02 Pain Frame"
        case .restartLoop: return "03 Build Preview"
        case .arc03Path: return "04 Rank Orbit"
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
        case .sessionLength: return "21 Session Length"
        case .diet: return "23 Diet"
        case .sleep: return "24 Sleep"
        case .stress: return "25 Stress"
        case .priorAttempts: return "26 Prior Attempts"
        case .commitment: return "27 Commitment"
        case .notifications: return "28 Notifications"
        case .chapterScan: return "29 Chapter Scan"
        case .scanLive: return "30 Arc Entry"
        case .scanReview: return "31 Scan Review"
        case .scanAnalyzing: return "32 Scan Analyzing"
        case .verdict: return "33 Verdict"
        case .workoutLogDemo: return "34 Log Workout"
        case .workoutRewardDemo: return "35 Reward"
        case .pact: return "36 The Pact"
        case .chapterPath: return "37 Gate Open"
        case .whyThisProgram: return "38 Path Benefits"
        case .socialProofGallery: return "39 Climbers"
        case .obstacleFix: return "39b Obstacle Fix"
        case .commitDay90: return "40 Staircase"
        case .paywall: return "41 Paywall"
        case .appRatingPrompt: return "ARCHIVED · Apple Rating"
        case .lifeChangeEnergy: return "ARCHIVED · Energy"
        case .lifeChangeStrength: return "ARCHIVED · Strength"
        case .lifeChangeConfidence: return "ARCHIVED · Confidence"
        case .lifeChangeSleep: return "ARCHIVED · Sleep"
        case .lifeChangeLooksFeel: return "ARCHIVED · Looks/Feel"
        case .commitDay30: return "ARCHIVED · Day 30"
        case .commitToday: return "ARCHIVED · Commit Today"
        case .planReady: return "ARCHIVED · Arc Ready"
        }
    }

    static var archivedDebugSteps: [OnboardingStep] {
        allCases.filter { !flowOrder.contains($0) }
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
