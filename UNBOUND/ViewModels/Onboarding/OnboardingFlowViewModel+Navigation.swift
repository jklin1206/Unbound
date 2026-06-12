import Foundation
import Observation
import os.log
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension OnboardingFlowViewModel {

    // MARK: Navigation

    func advance() {
        AnalyticsService.shared.track(.onboardingStepCompleted(step: currentStep.analyticsName))
        guard let index = OnboardingStep.flowOrder.firstIndex(of: currentStep) else { return }
        let nextIndex = index + 1
        guard OnboardingStep.flowOrder.indices.contains(nextIndex) else { return }
        currentStep = OnboardingStep.flowOrder[nextIndex]
    }

    func back() {
        guard let index = OnboardingStep.flowOrder.firstIndex(of: currentStep) else { return }
        let previousIndex = index - 1
        guard OnboardingStep.flowOrder.indices.contains(previousIndex) else { return }
        currentStep = OnboardingStep.flowOrder[previousIndex]
    }

    private func shouldSkip(_ step: OnboardingStep) -> Bool {
        switch step {
        case .lifeChangeEnergy, .lifeChangeStrength, .lifeChangeConfidence, .lifeChangeSleep, .lifeChangeLooksFeel:
            return true
        default:
            return false
        }
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
        workoutMinuteOfDay = 19 * 60
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
}
